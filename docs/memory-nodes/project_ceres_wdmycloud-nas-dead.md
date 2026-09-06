---
name: project_ceres_wdmycloud-nas-dead
description: WD MyCloud NAS dead/irrecoverable 2026-09-06 — ceres backup crons disabled, configs wiped, existing repos preserved until replacement (>2 months out)
metadata:
  type: project
---

WD MyCloud (192.168.1.54) is confirmed dead and not recoverable; a replacement may take
**more than 2 months**. This blocked ceres from starting (LXC pre-start hook couldn't find
the now-unreachable `/mnt/WDMyCloud` mount).

**Why it matters:** removing the mount to unblock ceres turned `/mnt/WDMyCloud` into an
empty-but-readable directory. Neither `backup-wdmycloud-local.sh` nor
`backup-wdmycloud-s3.sh` checks for that — only for readability/missingness — so the next
scheduled run would have backed up 0 files, "succeeded", and then `restic forget --prune`
would have started rotating real historical snapshots out in favor of the empty one. Over
a >2-month gap this would have progressively destroyed the only remaining copies of the
WDMyCloud data.

**How to apply:** both ceres cron jobs are commented out (not deleted) in its crontab —
do not re-enable until a replacement NAS is remounted at `/mnt/WDMyCloud` with real
content, and only after running the local script manually once to confirm it sees real
files before letting `--prune` run unattended again. Backup scripts, local restic repo,
and S3 Glacier repo are all left in place untouched — only the OS-level mount configs
(gr-srv03 `/etc/fstab`, ceres's LXC `mp3`, `disk-space-monitor.sh`,
`provision-lxc.sh --wdmycloud`) were wiped, since the source is gone for good.

Full writeup: [docs/2026-09-06_ceres_wdmycloud-nas-dead.md](../2026-09-06_ceres_wdmycloud-nas-dead.md).
Related: [[project_ceres_wdmycloud_glacier]] (the S3 Glacier job's exclusion/retention
details, now paused).
