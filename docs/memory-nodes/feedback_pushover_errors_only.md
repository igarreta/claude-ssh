---
name: feedback_pushover_errors_only
description: Pushover notifications are for errors/issues requiring attention only — never for success or routine status, and never add new ones without express consent
metadata: 
  node_type: memory
  type: feedback
  originSessionId: a3a6cbe8-e8b0-4b6d-9aa2-113785387e32
---

Pushover notifications must only be sent for errors or issues that require the user's attention.

**Why:** User explicitly instructed this after a backup script sent a success notification. Recurred 2026-07-13: `remount-backup.sh` sent two Pushover notifications for a routine event, not a failure.

**How to apply:** When writing or modifying scripts that use Pushover, never add success/completion notifications. Only send notifications for failures, errors, or conditions that need the user to take action. **Never add a Pushover notification to any script without the user's express consent first** — even one that looks like an error/attention case. Ask before adding, don't assume.
