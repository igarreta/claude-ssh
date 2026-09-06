---
name: project_docker03_uptime-kuma-mqtt-explorer-cloudflare-migration
description: "uptime-kuma + mqtt-explorer moved from docker03 to cygnus 2026-09-05 with secrets intact; cloudflaretunnel's real destination is dedicated LXC CT103, not cygnus"
metadata: 
  node_type: memory
  type: project
  originSessionId: 1356fcf0-1541-43c9-828b-537c6dc6ecd9
  modified: 2026-09-06T01:33:43.582Z
---

uptime-kuma and mqtt-explorer now run on cygnus (podman, `~/uptime-kuma/`, `~/mqtt-explorer/`),
migrated with their real data/secrets (uptime-kuma's full sqlite DB and all 13 monitors;
mqtt-explorer's `settings.json` with live mosquitto broker credentials). Both verified serving
and their DB-encoded secrets confirmed intact, not placeholder.

**Why it matters:** `cloudflaretunnel` does **not** go to cygnus — [[project_docker03_zigbee_rf_degradation]]-adjacent
correction: the user already has a dedicated LXC, **CT103** (`100.100.91.26` Tailscale,
`192.168.1.14` LAN), running `cloudflared` natively via systemd for this. Don't ever plan to
redeploy cloudflaretunnel on cygnus again — [[project_docker03_zigbee_rf_degradation]] sibling
docs may still say otherwise in older text, CT103 is the actual answer. Proxmox access is by
design three-legged: cloudflare tunnel (via CT103), Tailscale direct, and local LAN IP —
cygnus isn't part of that picture at all.

uptime-kuma's old "cloudflare" monitor was a `docker`-type check against
`/var/run/docker.sock`; hitting the public tunnel hostname directly is **not** a valid
substitute (Cloudflare Access returns its login redirect at the edge regardless of whether the
tunnel connector is actually up). Fixed by adding `--metrics 100.100.91.26:2000` to CT103's
`cloudflared` systemd unit (token untouched, inserted with `sed`) and pointing the monitor at
`http://100.100.91.26:2000/ready` — cloudflared's own purpose-built health endpoint. Confirmed
passing.

**How to apply:** full command sequence, the castor `pg_hba.conf` fix needed for the
"PostgreSQL castor" monitor (cygnus's Tailscale IP wasn't allowlisted), and the still-open
cleanup item (stop docker03's originals once replacements have soaked) are in
`docs/memory_docker03-decommission.md`. MCP's sftp tools reject anything over 1 MB — large
transfers between two remote hosts were relayed through comet's own `scp` (both hosts already
trust `~/.ssh/id_ed25519_comet` directly, no new key needed).
