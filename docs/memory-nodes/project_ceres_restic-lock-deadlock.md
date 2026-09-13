---
name: project_ceres_restic-lock-deadlock
description: ceres skipped 3 nightly backups on a stale lock whose age always read "3h"; date -d "" returns midnight, not an error
metadata:
  type: project
---

ceres's `backup-usb1-local.sh` lost the 09-11/12/13 nightly backups to a restic lock left
by the 09-10 BACKUP_A rotation check. Fixed 2026-09-13: lock cleared, backup re-run, the
staleness check rewritten. Detail in `docs/2026-09-13_ceres_restic-lock-deadlock.md`.

**Why:** the age check reported exactly `3h` every night and never crossed its 6 h
threshold. Two traps combined: `restic cat lock` **pretty-prints** its JSON (`"time": "…"`,
with a space) so a pattern written for compact `restic snapshots --json` matched nothing,
and **GNU `date -d "" ` returns today at midnight rather than failing** — turning a silent
parse failure into "hours since midnight", smallest precisely during the 00:00–06:00 cron
window. The check had never worked; only a lock that outlived a day exposed it.

**How to apply:** when a backup reports a suspiciously round or constant age/count, compute
it by hand before believing it — see [[feedback_stale_failed_unit_false_positive]]. Never
let a date parse fall through to a default; `|| echo 0` is no better (reads as 1970). And
`/mnt/backup_a` being empty and showing as `pve-root` between 15:00 and 00:30 is the normal
swap window, not the stale bind mount of
[[project_gr-srv03_stale-mount-investigation]] — check the host mount before chasing it.
Related: [[project_backup_a_rotation_check]], [[project_backup_health_monitor]].
