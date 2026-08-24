---
name: project_cygnus_podman_restart_policy
description: "cygnus podman containers only survive reboots if podman-restart.service has a drop-in whose filter matches unless-stopped, not just the default always"
metadata:
  node_type: memory
  type: project
---

cygnus podman containers don't survive reboots unless `podman-restart.service` is enabled
**and** its filter covers the containers' actual restart policy. Enabling it alone
(2026-06-22) was insufficient: the unit's default filter is `restart-policy=always`, but
every cygnus container uses `unless-stopped`. Fixed 2026-07-12 with a drop-in override
matching both.

**Why:** the unit looked enabled and healthy, so the gap was invisible until a reboot
silently left containers down (the tank water-level sensor went unnoticed).

**How to apply:** rootless podman is broken in this LXC — use `sudo podman` (NOPASSWD).
Full chain in `docs/2026-07-12_cygnus_tuya-link-podman-restart-gap.md`; the earlier
`docs/2026-06-22_cygnus_podman-restart-after-reboot.md` is **superseded**, don't act on it.
Related: [[feedback_cygnus_podman_compose]].
