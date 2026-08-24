# raspberrypi1 TTato: granev/temp/* MQTT integration (2026-07-20)

**Status:** closed
**Host:** raspberrypi1, homeassistant
**Supersedes:** —
**Superseded-by:** —

## Problem
Home Assistant now preprocesses/averages temperature readings and publishes
results to `granev/temp/*` MQTT topics (192.168.1.8:1883), replacing TTato's
old multi-source reliability-selection logic. This migration was never
finished in TTato:
- `HABPRPAL` (granev/temp/hab_prpal) — not updating
- `VARONES_` (granev/temp/hab_chicos) — stuck at 0
- `LIVING00` (granev/temp/living) — appeared to work, but only by coincidence

## Root cause
TTato (`/home/rsi/TTato/bin/GlobalThreads.py` on raspberrypi1, repo
`igarreta/TTato`) never subscribed to any `granev/temp/*` topic — the string
`granev` didn't exist anywhere in the codebase. However `var/config.yaml`
already had sensor entries (`hab_prpl`→`promedio/1`, `living`→`promedio/2`,
`hab_varo`→`promedio/3`, plus `Max_temp`→`max_daily/1`, `Temp_3h_`→`temp_3h/1`)
whose netnames exactly matched the `model`/`id` fields HA publishes, and the
`sensor_groups` (`HABPRPAL`, `LIVING00`, `VARONES_`) already listed these as
first-priority members with old dead rtl_433/zigbee sensors as fallback.
`LIVING00` "worked" only because its legacy fallback sensor was still alive,
not because it consumed HA's data.

HA's `granev/temp/*` payload shape (`{"model":"promedio","id":N,"temperature":...}`)
is identical to the rtl_433 events format, so the existing `_on_message_rtl`
handler (bound to the `_client_rtl` MQTT client) needed no changes — just a
subscription.

## Fix
- `GlobalThreads.py`: added `self._client_rtl.subscribe("granev/temp/#")` in
  `_on_connect_rtl` (one line).
- `config.yaml`: added new sensor `ext_prom` (netname `promedio/4`) for
  `granev/temp/exterior`, inserted as first-priority member of the existing
  `EXTERNAL` sensor group (`[ext_prom, exterior, exteri_z, Aeroparq, Ezeiza__]`).
- `docker restart TTato` after each change (config/sensor reload only happens
  via manual "R" mode, not automatically).
- Verified live via `mosquitto_sub` + TTato's `tmp/sensor_log`: `hab_prpl`,
  `living`, `hab_varo`, `ext_prom` all receiving and channeling correctly.

Committed to `igarreta/TTato` as `5f7616a` (split from unrelated pre-existing
uncommitted changes on the pi — topic rename, LIVING00 schedule split,
MIN_SENSORS 3→2 — committed separately as `c6bfb1a`). Both pushed to origin.

## Known remaining issue (not a TTato bug)
`granev/temp/hab_chicos` publishes `temperature: 0` because the upstream HA
entity `sensor.temperatura_hab_varones` (unique_id `temp_chicos_prom`) is
stuck in state `unknown` — a hardware problem on the HA/sensor side, per user.
TTato is correctly relaying whatever HA sends. `VARONES_` will read 0 until
that sensor is fixed independently.

## Notes for future sessions
- TTato repo: `igarreta/TTato`, lives at `/home/rsi/TTato/` on raspberrypi1,
  runs as Docker container `TTato` (image `python_3_11_gpio:v2`), volume-mounted
  to `/TTato`. Edit on host, `docker restart TTato` to apply.
- `granev/temp/*` topics are published by a HA automation (5-min tick) in
  `/config/automations.yaml` on the homeassistant host — covers hab_prpal,
  living, hab_chicos, exterior (every 5 min) plus forecast_3h, max_today
  (every 30 min, already had matching config.yaml entries pre-existing).
- Sensor-to-group wiring in TTato is entirely config-driven
  (`var/config.yaml` → `sensors:` list with `netname`, and
  `rules.sensor_groups`); no code changes needed for topic mappings that fit
  the existing `model/id` JSON payload shape.
