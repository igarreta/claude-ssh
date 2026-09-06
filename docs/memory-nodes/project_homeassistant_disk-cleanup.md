---
name: project_homeassistant_disk-cleanup
description: HA disk usage cleanup 2026-09-05 (stale log + old backups); the MCP shell's restricted filesystem view
metadata:
  type: project
---

The `homeassistant` MCP connector's shell only sees a bind-mounted subset of the host
disk (Supervisor/Terminal-&-SSH add-on container view) — a `du` sweep across every
visible top-level dir accounted for only ~2.5G of a 22G `df` total; the rest (docker/addon
image layers) is outside this mount namespace and invisible here.

**Why it matters:** don't trust a `du`-from-this-shell total to explain a `df` number on
this host — flag the gap instead of implying nothing else is using space.

**How to apply:** for a HA disk-usage check, look for garbage in what *is* visible —
rotated `home-assistant.log.*`, old full backups in `/backup` (small per-addon backups
are normal, full-instance tars from months back usually aren't) — and note explicitly
that a large unaccounted remainder is expected, not a sign nothing was found.

`privileged-command` is also policy-denied here, same as every other prod-group
connector ([[feedback_mcp_privileged_policy_denied]]) — deletions of root-owned files
need the user to run them directly (HA terminal for files, Settings → System → Backups
UI for backups, so Supervisor's index stays in sync).

Full write-up: `docs/2026-09-05_homeassistant_disk-cleanup.md`.
