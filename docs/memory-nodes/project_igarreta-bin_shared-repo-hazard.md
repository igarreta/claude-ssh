---
name: project_igarreta-bin_shared-repo-hazard
description: igarreta/bin (~/bin on raspberrypi1, contabo2, raspberrypi2z) is one shared git repo — a host-specific script committed on one host can silently clobber another's on pull
metadata:
  type: project
---

`~/bin` on raspberrypi1, contabo2, and raspberrypi2z is the same checkout of
`github.com/igarreta/bin`, not per-host copies. A script that must differ by
host (e.g. `backup.sh`: raspberrypi1 uses a local NFS mount, contabo2 uses
rclone/SFTP over WAN) needs to branch on `$HOSTNAME` inside one file —
committing a host-specific rewrite as if it were the only truth clobbers the
other host's copy on its next `git pull`. This already happened once: a
2026-09-06 commit meant for contabo2 broke raspberrypi1's 09-07 backup cron.
See [[project_backup_schedule]] and
docs/2026-09-07_raspberrypi1-contabo2_backup-sh-merge.md for the incident
and the fix (merged, hostname-branched `backup.sh`).

**How to apply:** before committing any change to a script under this
`~/bin` repo, check whether the script's behavior needs to differ by host —
if so, branch on `$HOSTNAME` in the same file rather than assuming the
committing host's version is universal. raspberrypi2z's checkout is stale
(commit `cffca02`) and not cron-driven there; don't assume its presence
means raspberrypi2z uses these scripts.
