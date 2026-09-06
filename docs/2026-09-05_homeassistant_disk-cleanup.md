# Home Assistant disk cleanup

**Status:** closed
**Host:** homeassistant
**Supersedes:** —
**Superseded-by:** —

## Symptom

User reported high disk usage on the `homeassistant` host. `df -h` showed 22.0G/30.8G (74%)
on `/dev/sda8`, mounted at `/`, `/share`, `/addons`, `/homeassistant`, `/backup`, `/data`,
`/media`, `/addon_configs`, `/ssl` — all the same underlying partition, bind-mounted at
multiple paths inside the SSH session's container.

## Important caveat: restricted view

The `homeassistant` MCP connector's shell lands inside a container (matches the
Supervisor/Terminal-&-SSH add-on's own filesystem view — `/addon_configs`, `/addons`,
`/backup`, `/data`, `/homeassistant`, `/share`, `/ssl`, `/media`, no `/var/lib/docker`,
`/mnt` empty). `du -sh` across every visible top-level dir only accounted for ~2.5G of
the reported 22G used — the remaining ~19.5G (docker/addon image layers, OS partitions)
lives outside this container's mount namespace and is **not inspectable from this
connector**. Don't trust a `du` sweep from this shell to explain the *entire* `df` total.

## What was found and removed

- `/homeassistant/home-assistant.log.1` — 1.0 GB rotated log dated 2025-11-14 (`.log.old`
  and `.log.fault` were tiny/empty by comparison). Deleted by the user as root via the
  Terminal & SSH add-on (the MCP session's `hassio` user got `Permission denied`, and
  `privileged-command` is policy-denied on this connector too — see
  `docs/memory-nodes/feedback_mcp_privileged_policy_denied.md`).
- 8 old full-instance backups in `/backup`, ~700 MB total, dated Oct 2025–Feb 2026
  (`244e2cd7`, `a7002740`, `978dcb81`, `22ef6431`, `71b98d13`, `f9ed6459`, `851ae5ff`,
  `80682d64`). Deleted by the user via **Settings → System → Backups** in the HA UI
  (preferred over raw `rm` so Supervisor's backup index stays in sync with the files
  on disk).

Left alone as not garbage: `home-assistant_v2.db` (135M recorder DB, normal size), the
small per-addon backups (tailscale, studio_code_server, beszel_agent,
advanced_ssh_web_terminal, Samba_share, AppDaemon — all Aug 2026, recent), and ~300KB of
`automations.yaml.bak*`/`configuration.yaml.bak*` clutter in `/homeassistant` (negligible
size, left for the user to tidy manually if wanted).

## Result

Verified via `df -h` after each deletion: 22.0G (74%) → 21.0G (71%) after the log →
20.3G (69%) after the backups. ~1.7GB freed total.
