# raspberrypi1 backup.sh clobbered by contabo2's commit; merged into one script

**Status:** closed
**Host:** raspberrypi1, contabo2
**Supersedes:** —
**Superseded-by:** —

## What happened

`/home/rsi/bin/` on raspberrypi1 and contabo2 is the same checkout of the shared
`igarreta/bin` GitHub repo. On 2026-09-06 a session committed contabo2's
2026-08-17 rewrite of `backup.sh` (NFS mount → rclone/SFTP to gr-srv03, plus
docker volume dumps for uptime-kuma/portainer/beszel) with the message "Track
backup scripts that were live on the host but uncommitted" — accurate for
contabo2, but the commit landed in the one shared file both hosts pull from.
raspberrypi1 pulled it and its own, unrelated NFS-based `backup.sh` (writes
directly to the `/mnt/backup` NFS mount from gr-srv03, no SFTP/rclone
involved) was silently overwritten.

raspberrypi1's 2026-09-07 02:07 cron run then failed immediately: the
contabo2 script tries `rclone lsd` against gr-srv03's `contabo2backup`
chrooted SFTP account, using a key (`~/.ssh/id_ed25519_grsrv03_backup`) that
only exists on contabo2. Confirmed via byte-identical md5 between both
hosts' `backup.sh` and matching commit timestamp/mtime.

## Fix

Restored raspberrypi1's NFS-based logic from git commit `cffca02` (last
commit before the contabo2 rewrite touched the file) and merged both
versions into one script that branches on `$HOSTNAME`:

- `check_backup_accessibility`, `upload_backup`, `cleanup_old_backups`: NFS
  direct-mount path for raspberrypi1, rclone/SFTP path for contabo2.
- `refresh_docker_backups` (uptime-kuma/portainer/beszel dumps): gated to
  `contabo2` only.

Tested end-to-end on both hosts before committing (raspberrypi1 full run
verified; contabo2's destination-check/docker-dumps/encrypt-upload verified
live, the unchanged `~/bak/` rclone copy step confirmed against the same
day's successful 02:07 cron run using the pre-merge script). Committed as
`b1705ad` in `igarreta/bin`, pushed, both hosts' checkouts fast-forwarded.

Hit the documented MCP multi-line-command-body pitfall while committing: a
`git commit -m "<multi-line message>"` sent as a single MCP command had its
newlines silently collapsed, flattening the commit body onto the subject
line. Fixed by uploading the message to a file via `sftp-upload` and using
`git commit --amend -F <file>`.

## Loose end found, not a bug

raspberrypi2z also has a checkout of `igarreta/bin` at `~/bin`, stale at
commit `cffca02` (predates both the contabo2 rewrite and this merge) and not
referenced by its crontab (which runs `/usr/local/bin/pi-backup.sh`, the
documented monthly SD-image backup — see
[2026-06-27_raspberrypi2z_backup.md](2026-06-27_raspberrypi2z_backup.md)).
Running `backup.sh` manually there correctly errors on a missing
`backup.key` (raspberrypi2z was never provisioned with one) — expected
behavior, not a defect. Left as-is; harmless unless someone runs it there by
hand again.
