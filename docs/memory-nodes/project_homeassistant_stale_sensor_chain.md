---
name: project_homeassistant_stale_sensor_chain
description: "HA sensor.temperatura_exterior_parque froze on a dead-battery sensor; fixed 2026-08-19 with last_reported staleness guards, a problem binary_sensor and a met.no fallback"
metadata:
  node_type: memory
  type: project
---

`sensor.temperatura_exterior_parque` froze at a dead-battery sensor's last numeric value,
because **zigbee2mqtt discovery entities never go `unavailable`**. Fixed 2026-08-19 with
per-source staleness guards on `last_reported` (**not** `last_changed`), a `sin_fuente`
problem binary_sensor plus Pushover, and met.no as a last-resort fallback.

**Why:** `last_changed` doesn't move when a sensor keeps reporting the same value, so it
cannot detect staleness. Thresholds must sit *between* quantized heartbeat multiples or they
fire spuriously.

**How to apply:** `docs/2026-08-19_homeassistant_temperatura-exterior-parque-stale-chain.md`.
**All 3 outdoor sensors are dead and need batteries.** Related:
[[project_docker03_zigbee_rf_degradation]], [[project_docker03_zigbee2mqtt]].
