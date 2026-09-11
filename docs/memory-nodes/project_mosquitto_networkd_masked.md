---
name: project_mosquitto_networkd_masked
description: systemd-networkd is masked and stopped on mosquitto — ifupdown owns eth0; don't re-enable it to "fix" a network question
metadata:
  node_type: memory
  type: project
---

On mosquitto (CT105), `systemd-networkd`, its socket, `wait-online` and
`persistent-storage` are all **masked and stopped** since 2026-09-11. ifupdown
(`/etc/network/interfaces`, DHCP) owns eth0; tailscaled owns tailscale0.

**Why:** networkd was running but managing zero links, so `apt-daily` → `apt-helper` called
the wait-online binary directly and burned a 30 s timeout plus two warning lines daily, which
log-monitor reported every day. Masking alone did nothing — apt-helper tests
`is-active systemd-networkd` and runs the *binary*, not the unit; the `stop` is the fix.

**How to apply:** don't "restore" networkd on this host when debugging a network question —
it was never configuring anything. Note that contabo2 emits the *identical* two log lines from
a *different* cause (networkd there does manage eth0, but its SETUP state sticks at
`configuring`) and suppresses them via `SUPPRESS_PATTERN`; contabo2's config comment does not
apply here. Stopping a long-lived service leaves failed units behind — see
[[feedback_stale_failed_unit_false_positive]].

Detail: `docs/2026-09-11_mosquitto_networkd-wait-online-timeout.md`.
