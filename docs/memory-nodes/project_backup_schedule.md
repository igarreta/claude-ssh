---
name: project_backup_schedule
description: "Nightly backup schedule on gr-srv03 and its LXCs; jobs must start within the 02:25-03:30 disk-wake window"
metadata:
  node_type: memory
  type: project
---

All backup jobs run on gr-srv03 hardware; ceres and cygnus are LXCs sharing the host CPU, so
heavy jobs running simultaneously spike load on both.

**Why:** gr-srv03 spins the backup HDDs up at 02:25 and 02:55 and they spin down after ~10
min idle. A job outside that window runs against a sleeping disk.

**How to apply:** **do not add a backup job outside 02:25–03:30** without adding a matching
wake entry to the gr-srv03 crontab. The full per-job schedule table is in
`docs/memory_backup_schedule.md` — read it before touching any timing. Related:
[[project_backup_health_monitor]], [[project_ceres_empty_snapshots]].
