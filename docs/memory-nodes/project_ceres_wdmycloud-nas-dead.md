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

**Restore source verified 2026-09-07**: BACKUP_B's `/mnt/backup_b/restic-wdmycloud` is sound —
14 snapshots (2025-12-24 → 2026-09-05) at a consistent 1.450–1.462 TiB, no empties, `restic check`
clean, latest = 117,635 files / 1.462 TiB matching the documented 1.6 TB. **It is the *complete*
copy and therefore the restore source — S3 Glacier is not**, since Glacier excludes ~330 GB
(`Peliculas`, `Copia disco iMac Mantchoff`, `Archivos`, `Shared Music`) and costs 12–48 h plus
retrieval fees. Detail in [[docs/2026-09-07_nas-software-stack.md]].

**BACKUP_A verified 2026-09-10** when it rotated back in — this closes the "offsite and
unverified" second copy. Latest `905e13f3`, 2026-08-31, 1.462 TiB, 6 snapshots, the 08-27→08-31
dailies in a 1.457–1.462 TiB band matching B's. Both local copies are now confirmed intact; the
08-31 vs 09-05 gap is just the rotation, and since the NAS died 09-06 nothing was lost by
disabling the crons. See [[project_backup_a_rotation_check]].

Full writeup: [docs/2026-09-06_ceres_wdmycloud-nas-dead.md](../2026-09-06_ceres_wdmycloud-nas-dead.md).
Related: [[project_ceres_wdmycloud_glacier]] (the S3 Glacier job's exclusion/retention
details, now paused).
