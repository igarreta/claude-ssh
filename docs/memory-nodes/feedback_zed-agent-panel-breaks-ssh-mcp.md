---
name: feedback_zed-agent-panel-breaks-ssh-mcp
description: "Starting Claude Code from Zed's embedded agent panel breaks every ssh-mcp connector; must launch via tmux-claude.sh instead"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 703f7240-076d-47e1-b117-267c654b87b0
  modified: 2026-08-16T19:09:17.233Z
---

If Claude Code is launched directly from Zed's embedded agent panel (as an ACP agent) rather than through `~/bin/tmux-claude.sh` in a real terminal, the shell inherits Zed's internal npm env vars: `npm_config_prefix` / `npm_config_global_prefix` pointing at `~/.local/share/zed/external_agents/registry/npx/claude-acp` (a flat `node_modules` layout, not a standard npm global prefix) and `npm_config_cache` pointing at Zed's bundled node cache. Every `npx -y ssh-mcp ...` call (all SSH MCP connectors — gr-srv03, docker03, mosquitto, etc., defined in `.mcp.json`) then fails with `ENOENT: no such file or directory, lstat '.../claude-acp/lib'`, and `claude mcp list` shows all of them as `CONNECTION_CLOSED`. Notion/Gmail/Calendar/Drive connectors (HTTP-based, no npx) are unaffected — so a session with working Notion but zero SSH tools is the tell.

**Why:** Diagnosed 2026-08-16 while trying to investigate the mosquitto LXC (105) provisioning — `claude mcp list` showed every `ssh-mcp` entry down, and running `npx -y ssh-mcp -- ...` directly reproduced the ENOENT. `env | grep npm` confirmed the Zed-injected vars. This matches [[project_comet_zed_tmux_claude]] (or `docs/memory_comet_zed-tmux-claude.md`), which documents the correct launch path (`tmux-claude.sh`, Zed task "comet » claude-ssh") as giving a clean shell — this session apparently bypassed that path.

**How to apply:** If a session opens with SSH MCP tools missing entirely (not just one host down, all of them), don't debug the target host — check `claude mcp list` and `env | grep npm_config` first. If `npm_config_prefix` points into `zed/external_agents/registry/npx/claude-acp`, the fix is to close the session and relaunch via `~/bin/tmux-claude.sh <project-dir>` (or the Zed task that wraps it), not to edit any project config — this is a launch-path problem, not a repo or MCP-config problem.
