---
name: project_docker03_tailscale-key-expiry-2026-08-17
description: docker03's 2026-08-17 outage was Tailscale node-key expiry, not the USB/Zigbee storm; both fixes applied 08-18 (expiry disabled fleet-wide, container DNS fallback via daemon.json)
metadata:
  type: project
---

Full details in docs/2026-08-17_docker03_tailscale-key-expiry-and-container-dns.md.

2026-08-17: docker03 looked dead from 17:27 because its Tailscale **node key hit the
180-day expiry** (`netmap expiry timer triggered` → `Running -> NeedsLogin` →
`SetPrivateKey called (zeroed)`), *not* the USB-hub/Zigbee disconnect storm that
started two hours later at 19:34 (see [[project_gr-srv03_powered-hub-instability]]).
docker03 never hung — continuous journal, no hung_task/OOM/lockup, sshd up but
receiving zero connections because Tailscale was its only route in.

**Why:** docker03's `/etc/resolv.conf` is Tailscale-managed (`CorpDNS: true`) with
*only* MagicDNS (100.100.100.100) and no LAN fallback, and Docker's embedded resolver
latches those upstreams per container — so losing Tailscale takes DNS from every
container regardless of isolation, including the Pushover alert path. Container
isolation bounds namespace faults, not host-level shared dependencies.

**How to apply:**
- Key expiry was disabled fleet-wide 2026-08-18; only nb-rsigarreta (laptop) still
  expires. living1 is already expired and needs a re-login when next brought online.
- **Fixed 2026-08-18:** `/etc/docker/daemon.json` created on docker03 with
  `"dns": ["100.100.100.100","192.168.1.1","8.8.8.8"]` + `"dns-search": ["tail366c79.ts.net"]`.
  MagicDNS must stay FIRST — Docker's resolver falls through only on timeout/error,
  never on NXDOMAIN, so a LAN-first order would break `*.ts.net` lookups. This
  bypasses `/etc/resolv.conf` entirely, which matters because dhclient and tailscaled
  fight over that file constantly (147 trample events/24h). Host-network containers
  (beszel-agent) are NOT covered by daemon.json.
- Root journal on docker03 without the sudo password — see [[feedback_docker03_sudo]].
