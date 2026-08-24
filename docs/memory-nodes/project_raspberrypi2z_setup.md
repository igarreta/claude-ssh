---
name: project_raspberrypi2z_setup
description: "raspberrypi2z (100.92.195.47) Pi Zero W added Jun 2026 for 433 MHz sensors; SSH password auth disabled and passwordless sudo removed"
metadata:
  node_type: memory
  type: project
---

raspberrypi2z (`100.92.195.47`), a Pi Zero W, was added 2026-06-25 to receive 433 MHz
temperature sensors. SSH password auth is disabled and passwordless sudo was removed —
`rsi` now needs a password for sudo.

**Why:** hardened deliberately after the initial security review; the sudo change breaks
every MCP privileged-command path to this host.

**How to apply:** see [[feedback_raspberrypi2z_sudo]] for the working pattern (write the
script locally, scp to `/tmp/`, have the user run it). Setup detail in
`docs/2026-06-25_raspberrypi2z_setup-and-security.md`.
