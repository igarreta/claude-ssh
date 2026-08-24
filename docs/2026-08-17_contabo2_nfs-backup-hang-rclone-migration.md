# contabo2 backup: NFS hang fixed by migrating to rclone/SFTP (2026-08-17)

**Status:** closed
**Host:** contabo2, ceres
**Supersedes:** —
**Superseded-by:** —

## Symptoms reported
- contabo2: `~/bin/backup.sh` — "Failed to copy ~/bak to backup" for 2 consecutive
  nights (08-16, 08-17).
- ceres: `backup-usb1-local.sh` — "some files unreadable" warning on the
  `containers` restic tag (exit 3, non-fatal, floor check still passed).

## Root cause
`~/bin/backup.sh` on contabo2 (a remote Contabo VPS) wrote to `/mnt/backup`, an
NFS mount to gr-srv03 (`100.89.202.69:/mnt/backup_usb1/contabo2`) over Tailscale.
Reproduced live: `cp -a` sat in D-state (uninterruptible I/O sleep) with zero
progress for minutes at a time. gr-srv03 itself was healthy (no disk errors,
nfsd/mountd/lockd all up, low load); a raw `dd` write test measured only
**~2.9MB/s** and the link periodically stalled outright — the WAN path
(contabo2 ↔ home, ~246ms RTT) combined with NFS's default hard-mount semantics
(no `soft`/`timeo`) turned any stall into an indefinite hang.

ceres's "unreadable file" warning was a **symptom, not a separate bug**: ceres's
03:00 restic read caught contabo2's still-in-progress NFS write (which that
night ran 02:07→04:49 before failing) mid-flight on a single file. A live
ownership/permission audit on gr-srv03 found nothing actually wrong — the file
was just transiently open for write by the other side.

## Fix: migrated contabo2 → gr-srv03 backup transport to rclone over SFTP
Replaced the NFS mount entirely. New destination: a dedicated, restricted
account on gr-srv03.

**gr-srv03 side:**
- System user `contabo2backup`, uid/gid **101000** (matches ceres's own LXC
  unprivileged subuid mapping — container uid 1000 → host uid 101000 — so
  files stay readable by ceres's restic read without any special export
  squash).
- Chrooted via `/etc/ssh/sshd_config.d/999-contabo2backup.conf`:
  `ChrootDirectory /mnt/backup_usb1/contabo2`, `ForceCommand internal-sftp`,
  no port/X11 forwarding. Chroot root itself is `root:root 755` (required by
  sshd — chroot root and all its parents must not be group/other-writable);
  the account only has write access to a subdirectory inside it,
  `/mnt/backup_usb1/contabo2/uploads/` (owned by `contabo2backup:contabo2backup`).
  All timestamped `backup_YYYYMMDD_HHMMSS/` dirs now live under `uploads/`.
- `authorized_keys` lives at `/mnt/backup_usb1/contabo2/.ssh/authorized_keys`,
  restricted with `command="internal-sftp",no-port-forwarding,...`.
  **Gotcha:** sshd's privsep monitor drops privileges to the *target user's*
  uid before reading `authorized_keys` (a security check so a user can't trick
  sshd into reading arbitrary root-owned files). Making `.ssh`/`authorized_keys`
  root-owned — done here out of over-caution — broke auth entirely
  (`temporarily_use_uid: 101000/101000` then `ED25519 key is not allowed`,
  logged misleadingly as `Failed publickey`). Fix: own them as the login user
  itself (`contabo2backup`), same as any normal account. Diagnosed by comparing
  against a disposable non-chrooted test account that authenticated fine.
- Old NFS export line for contabo2 removed from `/etc/exports` (was
  `all_squash,anonuid=101000,anongid=101000` — that anonuid fix from 2026-08-15
  is now obsolete/retired along with the export itself).

**contabo2 side:**
- Dedicated ed25519 keypair generated for this purpose:
  `~/.ssh/id_ed25519_grsrv03_backup` (not the host's general-purpose key).
- `rclone` installed as a static binary in `~/bin/rclone` (no apt/sudo needed —
  MCP connector policy on this host blocks privileged commands entirely, so
  package-manager installs aren't an option here).
- `~/bin/backup.sh` rewritten: `etc.tar.gz.gpg` is built locally (staged in a
  `mktemp -d`, cleaned via `trap ... EXIT`) then uploaded with
  `rclone copyto`; `~/bak/` is shipped with
  `rclone copy ~/bak/ ... --transfers 32 --checkers 32`. Old NFS mount/fstab
  entry removed.
- Old backup.sh versions kept as `~/bin/backup.sh.pre-docker-restore-20260817`
  and `~/bin/backup.sh.pre-rclone-20260817`.

## Performance
Raw `dd` to NFS: ~2.9MB/s, prone to indefinite stalls.
rclone/SFTP for one large file: ~5MB/s, no stalls.
Full nightly run (dominated by `~/bak/openclaw`, ~4,926 files — almost all
`node_modules`): **~40 minutes** even with `--transfers 32`, because the
bottleneck for that tree is per-file SFTP round-trip latency (~250ms), not
bandwidth. Raising parallelism further hit diminishing returns. 40 minutes
starting at the existing 02:07 cron still finishes well before ceres's 03:00
read (see `docs/memory_backup_schedule.md`), so the original race is gone too.
Possible future optimization (not done): exclude `node_modules` from
`~/bak/openclaw` — it's regenerable from lockfiles and is the overwhelming
majority of both the file count and the transfer time.

## Bonus fix in the same pass: stale docker volume dumps
While investigating, found `~/bak/uptime-kuma.tar.gz`, `beszel_data.tar.gz`,
`portainer_data.tar.gz`, `uptime-kuma-data.tar.gz` and `n8n_n8n_data.tar.gz`
were all dated **March 5** (the day contabo2 was migrated from contabo1). The
old script that refreshed them, `~/etc/backup.sh` (calling
`~/docker-contabo1/uptime-kuma/backup_kuma.sh` etc.), was dropped from cron at
the migration and never ported into the replacement `~/bin/backup.sh` — so for
5+ months the nightly job had just been re-shipping the same stale snapshot.
Fixed: `refresh_docker_backups()` now dumps the `uptime-kuma-data` and
`portainer_data` docker volumes fresh each run, and copies today's dated
beszel backup (beszel produces its own daily zips internally already).
`n8n_n8n_data.tar.gz` and the two "-data" stale files were deleted outright —
n8n has its own independent, active, git-based backup
(`~/n8n/bin/backup.sh`, daily 3:30 cron); the other two had no known
regeneration source at all (one-off manual dumps from migration day).

## Process note: MCP multi-line command corruption (self-inflicted, recovered)
Mid-task, sent a two-line command body (embedded `\n`) to
`mcp__contabo2__run-command` in one call. Per this repo's CLAUDE.md, MCP SSH
tools silently collapse embedded newlines, merging separate lines into one —
here it turned `rm -rf /tmp/rclone.zip /tmp/rclone-*-linux-amd64` + the next
line into a single `rm -rf -v ...` invocation that also matched and deleted
`~/bin/rclone` and `~/bak/uptime-kuma.tar.gz` (both incidentally named on that
merged line). Both were trivially regenerable (redownload the static binary,
re-run the docker volume dump) and were recovered immediately with no lasting
data loss. Reinforces: **always one command per MCP SSH tool call**, no
exceptions, even for "just two quick things."

## Verification
Ran the new `~/bin/backup.sh` for real end-to-end: 40m27s, zero errors. On
gr-srv03, confirmed every file under the new `backup_YYYYMMDD_HHMMSS/` dir is
owned by uid 101000 (`find ... -not -uid 101000` returned nothing) — correct
for ceres's read. Old NFS export removed from `/etc/exports` and old NFS
mount/fstab entry removed from contabo2 (both confirmed clean by the user
afterward).

See also: [[project_backup_schedule]], [[project_mosquitto_broker_migration]]
(unrelated but same "restic squash uid" pattern), `docs/2026-02-24_migration_to_contabo2.md`.
