---
name: project_mosquitto_ssh-socket-failed
description: mosquitto ssh.socket failed-unit noise from log-monitor was a harmless ssh.service/ssh.socket port race, not an SSH outage
metadata:
  type: project
---

log-monitor flagged `ssh.socket` as `failed` on mosquitto (important severity). It was
cosmetic: `ssh.service` (daemon mode) had already bound port 22 and was serving
connections the whole time, including the one that collected the digest. `ssh.socket`
lost the race back on 2026-08-16 and sat in `failed` state since.

**Why it matters:** an "important" log-monitor escalation naming `ssh.socket` on any
host is not necessarily an SSH access loss — check whether `ssh.service` is active
before treating it as urgent.

**How to apply:** fix is `systemctl disable --now ssh.socket && systemctl
reset-failed ssh.socket`. mosquitto's MCP connector policy-denies `privileged`
commands ([[feedback_mcp_privileged_policy_denied]]) — the user has to run sudo
commands there themselves.

Full detail: `docs/2026-08-28_mosquitto_ssh-socket-failed.md`.
