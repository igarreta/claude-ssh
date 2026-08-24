---
name: project_ceres_empty_snapshots
description: "ceres produced EMPTY backup snapshots for ~7 months with every layer reporting success; pct reboot fixed it but the cause is unproven and the probe reading is overdue"
metadata:
  node_type: memory
  type: project
---

Between ~2026-01-20 and 2026-08-14, every restic tag going from `backup_usb1` to BACKUP_A/B
produced **empty snapshots**, while all layers reported success. `pct reboot 203` fixed it,
but the **cause is unproven**. A probe was installed on ceres (3 cron windows); its reading
was due the night of 2026-08-17 and is still **outstanding as of 2026-08-24**.

**Why:** the highest-stakes open item in the fleet — seven months of believed-good backups
that were empty, with no mechanism understood to stop a recurrence.

**How to apply:** read the probe before trusting ceres→BACKUP_A/B. Detail in
`docs/2026-08-14_ceres-empty-snapshots-probe.md` (**open**). Related:
[[project_backup_health_monitor]], [[project_backup_schedule]],
[[project_gr-srv03_stale-mount-investigation]].
