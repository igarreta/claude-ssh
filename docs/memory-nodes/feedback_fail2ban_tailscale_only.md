---
name: feedback_fail2ban_tailscale_only
description: "fail2ban is not needed on hosts/LXCs reachable only via Tailscale, no public exposure"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 1356fcf0-1541-43c9-828b-537c6dc6ecd9
  modified: 2026-09-06T00:57:18.872Z
---

Don't add fail2ban to a new host/LXC whose only reachability is Tailscale (SSH and any app
frontend both gated behind the tailnet, no public port/tunnel).

**Why:** stated by the user 2026-09-05 while scoping CT207 (rtl_433 test LXC) — Tailscale's
own WireGuard auth means there's no brute-forceable surface for fail2ban to protect.

**How to apply:** when planning new-host checklists (see
[[project_gr-srv03_rtl433-ct207]], [[project_docker03_zigbee_rf_degradation]]'s CT206
sibling), only include fail2ban for hosts with real public/internet exposure — e.g. cygnus,
which still needs it because of the `cloudflaretunnel` public HTTPS route
(`docs/memory_docker03-decommission.md`). Existing fail2ban on already-public-facing hosts
(docker03, etc.) is unaffected by this — this is about not adding it to new Tailscale-only
nodes going forward, not removing it elsewhere.
