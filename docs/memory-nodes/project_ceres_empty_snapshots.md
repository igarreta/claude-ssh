---
name: project_ceres_empty_snapshots
description: "ceres produced EMPTY backup snapshots for ~7 months with every layer reporting success; pct reboot fixed it, the probe ran 8 nights without reproducing it, and the cause is still unproven"
metadata:
  node_type: memory
  type: project
---

Between ~2026-01-20 and 2026-08-14, every restic tag going from `backup_usb1` to BACKUP_A/B
produced **empty snapshots**, while all layers reported success. `pct reboot 203` fixed it.
The probe ran 8 nights (08-17 → 08-24) and the **source never failed once**, so the cause
remains **unproven** — nothing was ever observed in the broken state.

What *is* proven is separate: BACKUP_A's bind mount goes stale in ceres almost every night it
is connected, BACKUP_B never does. The 08-17 disk swap hid the symptom; it returns with the
next A rotation. The probe is deliberately left installed until the **2026-08-25 BACKUP_A
rotation**, the only run that could still reproduce it.

**Why:** the highest-stakes open item in the fleet — seven months of believed-good backups
that were empty, with no mechanism understood to stop a recurrence.

**How to apply:** read the probe after the next BACKUP_A night before trusting ceres→BACKUP_A.
Detail in `docs/2026-08-14_ceres-empty-snapshots-probe.md` (**open**). Related:
[[project_backup_health_monitor]], [[project_backup_schedule]],
[[project_gr-srv03_stale-mount-investigation]].
