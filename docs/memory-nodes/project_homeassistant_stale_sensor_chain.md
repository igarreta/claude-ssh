---
name: project_homeassistant_stale_sensor_chain
description: "HA sensor.casa_ext_temp is a staleness-guarded fallback chain (built 2026-08-19); a third local source, casa_ext_zb2_temp, was added 2026-09-13"
metadata:
  node_type: memory
  type: project
---

`sensor.casa_ext_temp` (ex `temperatura_exterior_parque`) froze at a dead-battery sensor's last
numeric value, because **zigbee2mqtt discovery entities never go `unavailable`**. Fixed
2026-08-19 with per-source staleness guards on `last_reported` (**not** `last_changed`), a
`sin_fuente` problem binary_sensor plus Pushover, and met.no as a last-resort fallback.
**2026-09-13: a third local source, `casa_ext_zb2_temp`, was added at priority 3** (100-min
guard, −1.5 °C correction).

**Why:** `last_changed` doesn't move when a sensor keeps reporting the same value, so it
cannot detect staleness. Thresholds must sit *between* quantized heartbeat multiples or they
fire spuriously.

**How to apply:** any *new* source added to this chain needs its own `last_reported` guard,
sized off that device's measured heartbeat — Zigbee battery sensors have no `expire_after`
equivalent, and on the Tuya ZY-ZTH02 the battery/voltage entities are constants, so the daily
battery alarm is no safety net either. Measure a new sensor's offset against the two sources
that already agree before trusting it; the 09-13 one read +1.44 median high.
**Known exception, 2026-09-19: `last_reported` guards do not work on a polled TS011F.** That
device republishes its cached measurement on every state change and every poll, so
`last_reported` refreshes while the *number* is from the previous régime — guard on time since
the switch changed state instead. See [[project_bomba-agua_current-measurement]]. Also relevant
here: `zigbee_temperatura_exterior_alt`, the priority-3 leg added 09-13, **has been off the
network since that same evening** and the chain never noticed, because the primary leg kept
reporting — [[project_docker03_zigbee_rf_degradation]].

Detail: `docs/2026-09-13_homeassistant_exterior-sensor-backup-zb2.md` and
`docs/2026-08-19_homeassistant_temperatura-exterior-parque-stale-chain.md`. Related:
[[project_homeassistant_temperature-sensor-naming]], [[project_homeassistant_config_write_path]],
[[project_docker03_zigbee_rf_degradation]], [[project_docker03_zigbee2mqtt]].
