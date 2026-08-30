---
name: project_comet_ssh-mcp-v2-password-flag
description: unpinned npx ssh-mcp auto-updated to v2 and dropped --password, breaking the homeassistant MCP connector
metadata:
  type: project
---

Closed incident, detail in
[docs/2026-08-30_comet_homeassistant-mcp-ssh-mcp-v2-password-flag.md](../2026-08-30_comet_homeassistant-mcp-ssh-mcp-v2-password-flag.md).

**Why it matters:** every SSH MCP connector launches via unpinned `npx -y ssh-mcp` —
a future breaking release can silently take down any connector again, not just
password-based ones. When an SSH connector suddenly shows `CONNECTION_CLOSED` with no
config change on this end, suspect an `ssh-mcp` upgrade before suspecting the
network/host/credentials — verify by running the `npx -y ssh-mcp -- ...` command
directly and reading its actual stdout/stderr, not just the MCP client's generic error.

**How to apply:** `/home/rsi/etc/homeassistant-mcp.sh` now uses `SSH_MCP_PASSWORD` (env
var, v2 syntax) instead of the removed `--password` flag. It is not in a git repo, so
this file itself is the only record of that fix — don't assume it's version-controlled
elsewhere.
