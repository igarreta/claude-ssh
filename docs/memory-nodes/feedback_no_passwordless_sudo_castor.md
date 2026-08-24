---
name: feedback_no_passwordless_sudo_castor
description: User does not want passwordless sudo configured on castor — keep it requiring a password
metadata: 
  node_type: memory
  type: feedback
  originSessionId: af2db5a7-f3a6-477c-889d-155b3d4bf3b8
---

Do not configure passwordless sudo on castor. The user explicitly said they do not like it (2026-05-29).

**Why:** User preference — castor should require a password for sudo.

**How to apply:** If a task on castor requires root, use `pct exec 205 -- <cmd>` from gr-srv03 instead of suggesting `NOPASSWD` sudoers entries. Do not propose passwordless sudo as a convenience improvement on castor.
