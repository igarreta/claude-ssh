---
name: project_docker03_fail2ban
description: "docker03 fail2ban was dead for 2+ weeks because it has no rsyslog; fixed 2026-07-05 with backend = systemd"
metadata:
  node_type: memory
  type: project
---

docker03 fail2ban was down from 2026-06-18: no rsyslog on the host means `/var/log/auth.log`
never exists, the sshd jail's config failed, and exit 255 is in
`RestartPreventExitStatus` — so systemd deliberately never retried. Fixed 2026-07-05 with a
`backend = systemd` override.

**Why:** a config-error exit code blocks auto-restart by design, so the service sat `failed`
silently. Nothing surfaced it until log-monitor's first run against docker03.

**How to apply:** `docs/2026-07-05_docker03_fail2ban-fix.md`. On any Debian host without
rsyslog, use the systemd backend rather than a logpath. Related: [[feedback_docker03_sudo]].
