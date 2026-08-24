---
name: project_comet_tailscale_logout
description: "comet's 2026-07-12 Tailscale logout was tailscaled.state corrupted by an ungraceful LXC kill during a gr-srv03 power outage"
metadata:
  node_type: memory
  type: project
---

comet lost Tailscale on 2026-07-12: a gr-srv03 power outage killed comet's LXC ungracefully
and corrupted `tailscaled.state`.

**Why:** the second lesson matters more than the first — an **unprivileged `journalctl` read
truncates to the user's own messages** and can look like a multi-hour outage that never
happened. Re-check with sudo before concluding a host was down.

**How to apply:** `docs/2026-07-12_comet_tailscale-logout-power-outage.md`. Related:
[[project_gr-srv03_vm100_stopped]], [[feedback_docker03_sudo]].
