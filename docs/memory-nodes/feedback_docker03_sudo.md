---
name: feedback_docker03_sudo
description: docker03 sudo needs a password and MCP privileged-command is policy-denied; for read-only root diagnostics use `qm guest exec 102` from gr-srv03 instead
metadata: 
  node_type: memory
  type: feedback
  originSessionId: d50d1a52-f033-488a-b9c2-9cc7c9a590c8
  modified: 2026-08-26T22:40:49.815Z
---

`sudo` on docker03 requires a password — `mcp__docker03__sudo-exec` fails with "a password is required" (found 2026-07-05).

**Why:** No passwordless sudoers entry for `rsi` on docker03 (same as raspberrypi2z and castor). See [[project_docker03_fail2ban]].

`mcp__docker03__privileged-command` is also policy-denied outright — see
[[feedback_mcp_privileged_policy_denied]], a fleet-wide "prod" host-group rule, not
specific to docker03.

**How to apply:**
- **Read-only root diagnostics (journals, configs): use the QEMU guest agent from gr-srv03**, whose MCP connector runs as root. docker03 is VM 102 with `agent: enabled=1`:
  `qm guest exec 102 --timeout 60 -- /bin/bash -c "journalctl -b -1 --since '...' --no-pager"`
  Output returns as JSON in `out-data`; watch for `"out-truncated": 1` and narrow with grep rather than paging. Works for any gr-srv03 guest with the agent enabled. Found 2026-08-18 while investigating [[project_docker03_tailscale-key-expiry-2026-08-17]].
- **Resolved 2026-08-26:** `rsi` used to silently see only its own messages via plain `journalctl` (not in `adm`/`systemd-journal`), which could look exactly like a host that froze — this also meant [[project_mosquitto_broker_migration]]'s log-monitor coverage for docker03 had been silently blind since it was added. Fixed with `sudo usermod -aG systemd-journal rsi`; plain `journalctl` as `rsi` now sees everything, no more need to fall back to the guest-agent path for this specific gap (still useful for genuinely root-only diagnostics).
- **Changes that modify the system:** write the file/script locally with `Write`, `scp` it to `/tmp/`, then give the user the bare `sudo` command to run themselves — no `ssh` wrapper, see [[feedback_sudo_commands_no_ssh_wrap]].
