---
name: feedback_no_alert_escalation_counters
description: don't propose consecutive-failure counters or alert escalation logic; a repeating daily Pushover alert is working as intended
metadata:
  type: feedback
---

Asked 2026-09-13, after three nights of identical ceres backup-failure alerts, whether the
backup health monitor should gain a consecutive-failure counter. Answer: no — "Pushover
alerts worked as intended: a counter makes the monitor more complex and I was aware of the
same alert repeating daily."

**Why:** the user reads the alerts and tracks repetition themselves. An alert firing again
the next day is the system working, not a gap to be engineered around. Extra state in the
monitor buys nothing and is one more thing that can break silently.

**How to apply:** when a fault went unnoticed for several days, fix the fault — don't offer
escalation logic, dedup counters, or "n consecutive failures" thresholds as a follow-up.
Related: [[feedback_pushover_errors_only]], [[project_backup_health_monitor]],
[[project_ceres_restic-lock-deadlock]]. Context in
`docs/2026-09-13_ceres_restic-lock-deadlock.md`.
