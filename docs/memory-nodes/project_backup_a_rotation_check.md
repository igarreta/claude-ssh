---
name: project_backup_a_rotation_check
description: BACKUP_A verified healthy 2026-09-10 after rotating back in; how to check a rotated drive and which apparent gaps are just retention
metadata:
  type: project
---

BACKUP_A was checked 2026-09-10 after rotating back in (first run 09-09): mount and slave
propagation into ceres fine, 7/7 tags fresh with floors passed, `restic check` clean, SMART
clean, and its `restic-wdmycloud` copy verified intact — see
[[project_ceres_wdmycloud-nas-dead]].

**Why it matters:** a rotated-in drive is the one moment its repo can be inspected at all, and
two normal things look like failures if you don't expect them. `restic snapshots` will show a
tag *missing* from the previous day (retention retired it — check the log's floor line before
calling it a gap), and long-dead tags linger as relics (`immich`, last seen 2025-12-17, no
longer in the script and its source dir is gone). Judge a run by its floor checks in
`cron-backup.log`, not by counting snapshots per day.

**How to apply:** to inspect a drive outside its mounted window (drives unmount at 15:00,
remount 00:30), run `systemctl start mnt-backup_a.mount` on gr-srv03 as root, query from
ceres, then `systemctl stop` it to restore the scheduled state. Use `restic snapshots`, never
`du` — `du` on the 1.4 TiB repo exceeds the 60 s MCP timeout. `env-wdmycloud-local.sh` and
`env-usb1-local.sh` auto-detect which of A/B is mounted.

Note A and B are **different drives**: A is a WDC WD40NDZW-11BCVS0 (4 TB), B a Toshiba
MQ03UBB300 (3 TB). Both are APM 128, so both need the `wake-backup-disks.sh` 02:25/02:55 cron —
see [[project_backup_schedule]].

Full writeup: [docs/2026-09-10_gr-srv03_backup-a-rotation-check.md](../2026-09-10_gr-srv03_backup-a-rotation-check.md).
