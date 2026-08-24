---
name: project_backup_health_monitor
description: "Backup health monitor implemented and deployed 2026-08-15 (phases 1-3); tests being finished as of 2026-08-24"
metadata:
  node_type: memory
  type: project
---

The backup health monitor is **implemented and deployed 2026-08-15** (phases 1–3), with
**tests being finished as of 2026-08-24**. Design: magnitude verification moved *inside*
ceres's backup with a heartbeat to the contabo2 Uptime Kuma; a weekly Saturday check from
comet inside log-monitor as a later layer; arithmetic produces the verdict and Claude only
narrates it; `forget --prune` moved out of ceres to comet so a broken backup can't erode
history.

**Why:** built in response to [[project_ceres_empty_snapshots]] — every layer reported
success while the snapshots were empty, so the verdict must be arithmetic, not narrative.

**How to apply:** `docs/2026-08-14_backup-health-monitor-design.md`. Related:
[[project_backup_schedule]], [[feedback_pushover_errors_only]].
