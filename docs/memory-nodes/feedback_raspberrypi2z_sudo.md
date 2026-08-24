---
name: feedback_raspberrypi2z_sudo
description: "How to handle privileged commands on raspberrypi2z (no passwordless sudo, MCP sudo-exec fails)"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 497ade5d-3fb1-41f6-abe0-e8ddb350a216
---

On raspberrypi2z, `sudo` requires a password — `mcp__raspberrypi2z__sudo-exec` always fails.

**Why:** Passwordless sudo was removed during security hardening (Jun 2026). See [[project_raspberrypi2z_setup]].

**How to apply:** When privileged operations are needed:
1. Write the script locally with the Write tool
2. `scp` it to `/tmp/` on the Pi
3. Give the user this command to run **in the Pi's local terminal**: `sudo bash /tmp/script.sh`
Do NOT suggest running it via `! ssh ... sudo bash` — that also requires interactive password and won't work from comet's terminal.
