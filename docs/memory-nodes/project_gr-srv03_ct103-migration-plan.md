---
name: project_gr-srv03_ct103-migration-plan
description: CT103 (cloudflaretunnel) is the last non-Turnkey LXC on Debian 12; a clone-and-reinstall migration plan to Debian 13 is sketched but not started
metadata: 
  node_type: memory
  type: project
  originSessionId: a5f49816-150a-44fc-bc20-1d97bb49a93d
  modified: 2026-09-06T20:55:56.227Z
---

CT103 only runs `cloudflared` (token-based, no config.yml) + stock `tailscaled`/`postfix` —
minimal footprint, so migrating off Debian 12 is a clone-CT901 + reinstall-cloudflared job,
not an in-place dist-upgrade. Outbound-only tunnel means no DNS/IP cutover risk; rollback is
just restarting `cloudflared` on the old container.

**Why it matters:** CT103 and CT101 (Samba03, Turnkey — being deprecated outright, not
migrated) are the only LXCs left on Debian 12 across gr-srv03. This is a quick, low-risk
cleanup item, not urgent.

**How to apply:** full step-by-step plan is in
`docs/2026-09-06_gr-srv03_ct103-cloudflare-migration-plan.md` — read it before starting;
estimated well under 30 minutes hands-on. Related: [[project_docker03_uptime-kuma-mqtt-explorer-cloudflare-migration]].
