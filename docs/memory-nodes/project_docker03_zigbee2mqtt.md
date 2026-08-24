---
name: project_docker03_zigbee2mqtt
description: docker03 zigbee2mqtt outage 2026-07-15 (USB dongle re-enumeration + stale device mapping) and hardening fix
metadata: 
  node_type: memory
  type: project
  originSessionId: 712b5e6c-7773-4adc-a2bd-00d13e710940
---

zigbee2mqtt on docker03 went down 9h (2026-07-15) when the Sonoff Zigbee dongle
re-enumerated on USB and a stale `by-id → /dev/ttyACM0` device mapping in
`compose.yaml` made Docker's restart-always fail at container *start* (not a
normal exit), so it never retried.

Fixed: collapsed to single stable `by-id → /dev/ttyUSB0` device mapping
(`dockerfiles` repo commit `71b4b87`), added `~/bin/zigbee2mqtt-watchdog.sh`
cron-every-5min recovery script on docker03 (`bin` repo commit `d4e14e2`, no
alerting — user has a separate Pushover watchdog).

Full details, root cause chain, and docker03 conventions (cron+`~/bin` not
systemd; `dockerfiles`/`bin` are both git repos; zigbee2mqtt rewrites its own
data files on restart) in `docs/memory_docker03_zigbee2mqtt.md`.
