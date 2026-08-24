---
name: project_comet_zed_tmux_claude
description: "comet Zed+tmux+Claude Code workflow working since 2026-08-10 (tmux-claude.sh, terminal-bell notifications, Zed client task)"
metadata:
  node_type: memory
  type: project
---

The Zed + SSH + tmux + Claude Code workflow on comet (`~/bin/tmux-claude.sh`, persistent
per-project tmux session, reattach-or-create, terminal-bell notifications) has been fully
working since 2026-08-10 — merge resolved and pushed, Zed client task added.

**Why:** it is the supported way to launch Claude Code here.

**How to apply:** always launch via `tmux-claude.sh`. Launching from Zed's embedded agent
panel breaks every ssh-mcp connector — see [[feedback_zed-agent-panel-breaks-ssh-mcp]].
Detail in `docs/memory_comet_zed-tmux-claude.md`.
