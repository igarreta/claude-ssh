---
name: project_contabo2_ipv6-accept-ra
description: "contabo2's eth0 permanently shows networkd setup-state 'configuring', never 'configured' — confirmed cosmetic 2026-08-30; IPv6 itself works fine. accept-ra:false fix applied but didn't clear it; don't re-diagnose"
metadata:
  node_type: memory
  type: project
---

contabo2's `eth0` shows `networkctl status` setup-state stuck at **`configuring`** permanently
(never `configured`), which trips `systemd-networkd-wait-online` timeouts ~4x/day from
`apt-daily(-upgrade)`.

**Why:** IPv6 routing on contabo2 is entirely static (link-local on-link gateway, no real router
ever sends RAs), and the netplan source had no `accept-ra` override — a real bug, fixed
2026-08-30 with `/etc/netplan/90-disable-accept-ra.yaml` (`accept-ra: false`), kept as a
separate drop-in rather than editing the cloud-init-owned `50-cloud-init.yaml`, which may get
regenerated. **That fix did not clear the stuck state** — eth0 still reads `configuring`
afterward. Root cause of the setup-state stall itself was never found.

Confirmed the same day this is cosmetic, not a real problem: `curl -6 https://ifconfig.co`
succeeds end-to-end, gateway `fe80::1` shows `REACHABLE` in the neighbor table, and networkd's
own `Online state` already reads `online`. The wait-online/apt-helper log lines are now
suppressed in log-monitor's `hosts/contabo2.conf`.

**How to apply:**
- Don't re-diagnose this if `networkctl status eth0` or old wait-online logs surface again —
  it's known-benign, not a regression.
- If IPv6 ever actually breaks on contabo2, this stuck `configuring` state is a red herring:
  check real connectivity (`curl -6`, `ip -6 neigh show`) rather than trusting the setup-state.
- If touching contabo2's netplan, keep `90-disable-accept-ra.yaml` as its own file — don't fold
  it into the cloud-init-managed one.

Full detail: [[docs/2026-08-30_log-monitor_collect-sigpipe.md]]. Related:
[[project_log-monitor_collect-sigpipe]].
