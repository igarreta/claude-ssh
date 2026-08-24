---
name: project_gr-srv03_stale-mount-investigation
description: "gr-srv03 ceres bind mount went stale nightly; root-caused 2026-07-14 as inherent LXC mount-propagation behaviour, not a bug — reboot is the correct remediation"
metadata:
  node_type: memory
  type: project
---

The ceres bind mount went stale nightly from 2026-07-10. Root-caused 2026-07-14: LXC
slave mount-propagation **cannot survive a host unmount/remount**, so the container keeps a
dead reference. This is inherent behaviour, not a bug, and `pct reboot` is the correct
remediation.

**Why:** a 07-13 note claiming a "drive missing" was wrong and was corrected 07-15 — one of
BACKUP_A/_B being unmounted is **normal**, they rotate offsite and only one is ever
connected.

**How to apply:** `docs/memory_gr-srv03_stale-mount-investigation.md`. Don't diagnose a
single unmounted backup drive as a fault. Related: [[project_backup_schedule]],
[[project_ceres_empty_snapshots]].
