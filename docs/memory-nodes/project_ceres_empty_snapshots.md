---
name: project_ceres_empty_snapshots
description: "ceres produced EMPTY backup snapshots for ~7 months with every layer reporting success; pct reboot fixed it; cause never reproduced across 3 probe readings; probe closed and removed 2026-08-26"
metadata:
  node_type: memory
  type: project
---

Between ~2026-01-20 and 2026-08-14, every restic tag going from `backup_usb1` to BACKUP_A/B
produced **empty snapshots**, while all layers reported success. `pct reboot 203` fixed it.
The probe ran 8 nights (08-17 → 08-24) and the **source never failed once**, so the cause
remains **unproven** — nothing was ever observed in the broken state.

What *is* proven is separate: BACKUP_A's bind mount goes stale in ceres almost every night it
is connected (self-healed by `check-ceres-mount-sync.sh` at 02:20), BACKUP_B never does. The
2026-08-25→08-26 night — BACKUP_A reconnected 08-25 19:11, the rotation the plan named as the
last chance to reproduce it — went stale at 00:35/02:10, self-healed by 02:59, source never
failed: a third clean instance of the same non-reproduction, and the observation plan is now
exhausted. All 7 backup tags passed their floor check that night.

**Why:** the highest-stakes open item in the fleet — seven months of believed-good backups
that were empty, with no mechanism understood to stop a recurrence.

**How to apply:** closed. The health monitor's arithmetic floor check
([[project_backup_health_monitor]]) is now the permanent safety net for this. If empty
snapshots ever recur, start from `docs/2026-08-14_ceres-empty-snapshots-probe.md`
(**closed**) for the prior investigation trail rather than re-deriving it. Related:
[[project_backup_schedule]], [[project_gr-srv03_stale-mount-investigation]].
