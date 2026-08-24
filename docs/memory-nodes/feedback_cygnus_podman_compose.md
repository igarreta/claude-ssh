---
name: feedback_cygnus_podman_compose
description: "On cygnus, use \"sudo podman compose\" (not \"sudo podman-compose\") — it is passwordless"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: aa5f957f-a0f5-4368-9ad8-858ee6409d5a
---

Use `sudo podman compose` on cygnus, not `sudo podman-compose`.

**Why:** `sudo podman compose` is configured as passwordless on cygnus; `podman-compose` is not.

**How to apply:** Any time you need to run compose commands on cygnus (up, down, restart, logs, etc.), use `sudo podman compose <cmd>`.
