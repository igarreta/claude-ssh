---
name: feedback_ha-mcp-primary-connector
description: "Use the ha-mcp MCP connector first for Home Assistant work, not the ssh homeassistant connector"
metadata:
  type: feedback
---

For any Home Assistant task, use the **`ha-mcp`** MCP connector first (~87 tools:
entities, services, automations, scripts, dashboards, helpers, areas, history, backups).
Verified working end-to-end 2026-09-27.

**Why:** User asked for it to be set as the main HA connection. It gives semantic
entity/service-level access instead of raw shell, and the `homeassistant` SSH
connector's `/config` write path has been broken since 2026-09-11 anyway.

**How to apply:** Reach for `ha-mcp` tools by default on any HA request. Only use the
`homeassistant` SSH connector as a fallback for shell/log/filesystem-level diagnostics
ha-mcp's tool surface doesn't cover. Detail: `mcp-connectors.md` (repo root, "Home
Assistant MCP Connector" section). The `home-assistant-best-practices` Agent Skill,
installed alongside it (`.claude/skills/`), covers HA automation conventions.
