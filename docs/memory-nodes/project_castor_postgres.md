---
name: project_castor_postgres
description: "castor LXC (ID 205) on gr-srv03: PostgreSQL 17 server; must keep 10.0.100.11 (vmbr1) in listen_addresses or cygnus apps break"
metadata: 
  node_type: memory
  type: project
  originSessionId: d2060a05-ffe9-4ed9-8950-115ce1687e67
  modified: 2026-09-05T22:00:11.246Z
---

castor is a dedicated unprivileged LXC (ID 205) on gr-srv03 running PostgreSQL 17, kept
separate so it can be snapshotted independently before schema changes. SSH (`castor`) and
PostgreSQL (`castor-pg`) MCP connectors are both active.

**Why:** castor **must** keep `10.0.100.11` (vmbr1) in `listen_addresses` — the cygnus apps
(data-ingestion-api, grafana) reach it over the internal bridge. Changing it needs a
**restart, not a reload**. Ingestion chain: quetren → data-ingestion-api (:8000) →
castor:homelab.

**How to apply:** `rsi` needs a password for sudo — use `pct exec 205 -- <cmd>` from
gr-srv03. Snapshot before schema changes. Inventory (IPs, UID mapping, data dirs,
connector wiring) in `docs/memory_castor.md` and
`docs/2026-05-29_castor_postgresql-setup.md`. Related:
[[feedback_no_passwordless_sudo_castor]], [[project_castor_tailscale-bind-race]].
