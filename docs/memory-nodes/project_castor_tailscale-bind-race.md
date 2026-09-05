---
name: project_castor_tailscale-bind-race
description: castor PostgreSQL silently loses its Tailscale listener if it starts before tailscale0 has an IP; permanent fix applied 2026-09-05
metadata: 
  node_type: memory
  type: project
  originSessionId: d2060a05-ffe9-4ed9-8950-115ce1687e67
  modified: 2026-09-05T22:00:05.158Z
---

If Uptime Kuma or `castor-pg` MCP can't reach PostgreSQL on castor but the service
looks healthy, check whether it's actually bound to the Tailscale IP
(`100.65.209.119`) — it silently drops that listener if it starts before
`tailscale0` has an address, and keeps running fine on `10.0.100.11`/localhost.

**Why:** recurred twice (2026-05-31 and 2026-09-05, incl. an unattended package
upgrade) — ordering the service `After=tailscaled.service` isn't enough, since
that only waits for the process, not the assigned IP.

**How to apply:** as of 2026-09-05 a `wait-for-tailscale.sh` `ExecStartPre` polls
for the interface before postgres starts (fail-open after 30s), so this should no
longer recur — if it does, check `journalctl` for its warning first. Full incident
+ fix in `docs/2026-09-05_castor_postgresql-tailscale-bind-race.md`. Related:
[[project_castor_postgres]].
