---
name: project_zigbee2mqtt_migration
description: zigbee2mqtt cutover from docker03 to CT206 done 2026-09-05; docker03 kept only as rollback
metadata: 
  node_type: memory
  type: project
  originSessionId: 3a5d59b8-5617-4ea7-8442-e072c0e4686f
  modified: 2026-09-06T19:00:56.303Z
---

zigbee2mqtt now runs live on CT206 (`10.0.100.12`), not docker03 — the dongle physically
moved from VM 102's USB passthrough to a direct gr-srv03 host udev symlink
(`/dev/zigbee`, serial-matched) bind-mounted into the unprivileged LXC. Same PAN ID/network,
no device re-pairing needed.

**Why it matters:** docker03's zigbee2mqtt container and `data/` are being kept, untouched,
as the rollback until a soak period passes — don't delete or "clean up" docker03's zigbee
state casually, and don't be surprised it's still there even though CT206 is the one live.
Anything monitoring docker03's old frontend/URL (e.g. uptime-kuma) needs repointing to CT206.

**How to apply:** before touching docker03's zigbee2mqtt further, check
[docs/memory_zigbee2mqtt-migration.md](../memory_zigbee2mqtt-migration.md) for whether phase
5 (cleanup) has run yet. Manual checks not yet confirmed as of the cutover: Home Assistant
entity states, TTato feed, physical actuator round-trip (`luz exterior garage`) — verify
these before considering the migration fully closed. Related:
[[project_docker03_zigbee_rf_degradation]] — fleet LQI relapsed to ~120-127 within 44
minutes of this cutover (09-05), before any new physical USB event (rtl-433 plug, disk
swap) occurred, and the dongle's own port checked out unchanged (`usb 1-3`). That timing
points at something in the cutover itself (leading candidate: a zigbee-herdsman
version/TX-power default difference vs. docker03's old stack, unverifiable now since
VM 102 is stopped) rather than a physical/environmental coincidence.
