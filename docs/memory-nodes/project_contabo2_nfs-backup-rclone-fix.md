---
name: project_contabo2_nfs-backup-rclone-fix
description: "contabo2's ~/bin/backup.sh migrated from a hanging NFS mount to rclone/SFTP; ceres's \"unreadable file\" warning was the same race, not a separate bug"
metadata: 
  node_type: memory
  type: project
  originSessionId: 901f28bb-fef1-4bad-a420-b89755ab83c5
  modified: 2026-08-18T00:01:54.927Z
---

contabo2's nightly `~/bin/backup.sh` was failing 2 nights running because it wrote
to gr-srv03 over an NFS mount across the contabo2↔home Tailscale WAN link, which
measured ~2.9MB/s and periodically hung indefinitely (reproduced live: `cp -a`
stuck in D-state). ceres's concurrent "some files unreadable" restic warning on
the same tree was a symptom of the same hang (03:00 restic read catching
contabo2's still-in-progress write), not an independent permissions bug.

Fixed 2026-08-17 by replacing the NFS mount with `rclone` over SFTP, writing to a
dedicated chrooted, forced-command (`internal-sftp`-only) account on gr-srv03
(`contabo2backup`, uid 101000 — matches ceres's own LXC subuid mapping so files
stay readable). Full nightly run now takes ~40min (bottlenecked by ~4,926 small
files in `~/bak/openclaw`, mostly `node_modules`, at SFTP's per-file latency, not
bandwidth) but is bounded and reliable, unlike the old mount. Old NFS
export/mount retired on both hosts.

Same investigation also found `~/bak/uptime-kuma.tar.gz` and friends (beszel,
portainer) had been stale since the March 2026 contabo1→contabo2 migration — the
script that refreshed them was dropped from cron and never carried over. Restored
as `refresh_docker_backups()` in the same script.

**Why:** contabo2 is a remote VPS; gr-srv03 is at home. NFS over that WAN link with
default hard-mount semantics (no `soft`/`timeo`) turns any network hiccup into an
indefinite hang instead of a clean error.

**How to apply:** For any future contabo2↔gr-srv03 (or any remote-VPS↔home)
bulk file transfer, prefer rclone/SFTP/rsync over NFS — NFS is a poor fit for
high-latency, less-reliable WAN links. Full incident writeup, including an sshd
chroot gotcha (privilege-drop read of authorized_keys) and a self-inflicted MCP
multi-line-command file deletion (recovered, no data loss), is in
`docs/2026-08-17_contabo2_nfs-backup-hang-rclone-migration.md`.

See also: [[project_backup_schedule]], [[feedback_docker03_sudo]] (contabo2 also
has no passwordless sudo/privileged-command access via this MCP connector —
rclone had to be installed as a static binary, not via apt).
