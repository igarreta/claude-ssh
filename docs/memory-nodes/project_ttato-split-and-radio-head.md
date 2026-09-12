---
name: project_ttato-split-and-radio-head
description: "Long-term plan (2026-09-12, not scheduled): split TTato into a gr-srv03 brain + an ESP32 at the boiler, and make raspberrypi1 a thin radio head running ser2net so z2m's state stays on gr-srv03 while the antenna moves freely"
metadata:
  node_type: memory
  type: project
  modified: 2026-09-12T00:00:00.000Z
---

**Why it matters:** the next "where should z2m / rtl_433 / the boiler logic run?" question has
already been answered, and the answer cost real measurement — both Pis were profiled and TTato's
actual GPIO map was read out of the source. The key insight is non-obvious: **radio placement and
compute placement are separable** (z2m takes `port: tcp://…`), so "gr-srv03 is reliable but bulky
to locate" is a false trade-off. Nothing is built; this is a plan, not a state.

**How to apply:**

- Do **not** re-propose z2m on raspberrypi2z — ARMv6, 297 MB free, one USB port. Settled no.
- Do **not** propose putting z2m's **database** on raspberrypi1. The host is capable (aarch64,
  4 cores); the state is what must stay on gr-srv03. The Pi runs `ser2net` only.
- Before hanging any USB device on raspberrypi1, note `vcgencmd get_throttled` = `0xd0000` —
  under-voltage has already occurred. Same failure shape as
  [[project_gr-srv03_powered-hub-instability]].
- **Do not move the Zigbee coordinator while the LQI degradation is still being measured**
  ([[project_docker03_zigbee_rf_degradation]]) — and measure with the collector, not spot checks
  ([[project_zigbee_lqi_collector]]).
- Relocating the **existing** dongle preserves the mesh; a different coordinator chip means
  re-pairing everything, which a restore does not fix ([[project_zigbee2mqtt_backup]]).
- If the ESP32 half is picked up, design the **failsafe first**: after the split, heat depends on
  gr-srv03 + mosquitto + network, where today the Pi is self-sufficient. Keep the override
  selector electrically upstream of the ESP32.
- Placement of the TTato brain must clear [[project_nas-service-placement-rules]] — and gr-srv03
  has no RAM headroom until [[project_docker03_decommission]] completes.

Detail, including the full GPIO map and the seven open questions:
`docs/2026-09-12_raspberrypi1-gr-srv03_radio-head-and-ttato-split.md`.
Related: [[project_raspberrypi2z_setup]], [[project_raspberrypi1_ttato_manual_heating]],
[[project_raspberrypi1_ttato_mqtt_drop]], [[project_docker03_rtl-test]],
[[project_mosquitto_broker_migration]].
