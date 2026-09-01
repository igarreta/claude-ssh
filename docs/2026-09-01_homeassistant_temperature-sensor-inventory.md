# Home Assistant temperature sensor inventory

**Status:** open
**Host:** homeassistant
**Supersedes:** —
**Superseded-by:** —

Snapshot taken 2026-09-01 by querying `home-assistant_v2.db` (recorder, latest state per
entity) and `configuration.yaml` / `.storage/core.entity_registry` for source-of-truth.
Goal: base for renaming decisions — current naming mixes device brand (`zigbee_`, `wifi_`),
protocol (`rtl_433` implicit), and location inconsistently, and several entities are dead
duplicates left over from hardware swaps.

**2026-09-01 cleanup applied** (tables below still show original findings; superseded rows
marked): user deleted `sensor.sensor_t_h_pinamar_temperatura_pinamar` (+ humedad) via the HA
UI. The rest was scripted — `configuration.yaml`/`automations.yaml` edited to drop dead
`zigbee_temp_exterior_*`/`zigbee_temp_chicos_*` sources and the duplicate
`temperatura_hab_principal_prom` template, the `pruebas` and `pinamar_base` dashboards were
repointed to the live entities, and `pileta_exp32_temperatura_*` (old spelling) +
`temperatura_comedor_pinamar_*` (legacy MQTT duplicates) + `temperatura_hab_principal_prom`
were removed from `core.entity_registry`. Confirmed live after a YAML reload. "RS" in
`temperatura_hab_prpal_rs` = a location marker inside the room, per user.

## 1. Real sensors (physical hardware)

### Casa (Granaderos) — rtl_433 433 MHz, via raspberrypi2z → MQTT, `expire_after` 600–1800s

| entity_id | friendly_name | value | status |
|---|---|---|---|
| `sensor.temperatura_exterior_granaderos` | Temperatura Exterior Oregon Scientific | — | **unavailable** |
| `sensor.temperatura_living_nexus` | Temperatura living Nexus | 21.0°C | alive |
| `sensor.temperatura_hab_principal_nexus` | Temperatura hab principal Nexus | — | **unavailable** |
| `sensor.temperatura_hab_chicos_nexus` | Temperatura hab chicos Nexus | — | **unavailable** |

Each has a paired `sensor.humedad_*` (same alive/unavailable pattern) and a paired
`binary_sensor.*_bateria` (battery-ok, converted from `sensor` per
[2026-08-30_homeassistant_battery-binary-sensors-and-exterior-zigbee-swap.md](2026-08-30_homeassistant_battery-binary-sensors-and-exterior-zigbee-swap.md)).

### Casa (Granaderos) — Zigbee, via z2m → MQTT discovery

| entity_id | friendly_name | value | status |
|---|---|---|---|
| `sensor.zigbee_temperatura_exterior_temperature` | zigbee_temperatura_exterior Temperature | 20.1°C | alive — this is the swapped exterior sensor (new device `0xa4c1380a7834ffff`) |
| `sensor.zigbee_temp_living_temperature` | zigbee_temp_living Temperature | 20.19°C | alive |
| `sensor.zigbee_temp_chicos_temperature` | — | — | **orphaned**, no longer referenced anywhere (unwired from `temperatura_hab_varones` 2026-09-01) |
| `sensor.zigbee_temp_exterior_temperature` | — | — | **orphaned**, no longer referenced anywhere (unwired from all 3 fallback chains + 1 automation 2026-09-01) |
| `sensor.0xa4c1380a7834ffff_temperature` / `_humidity` | — | `None` | raw ieee-address entity created by z2m discovery before the friendly rename took effect — inactive duplicate of `zigbee_temperatura_exterior_*` |

Each live one has `_humidity`, `_battery`, `_voltage` siblings.

### Pileta (pool) — ESP32, MQTT

| entity_id | friendly_name | value | status |
|---|---|---|---|
| `sensor.esp32_pileta_temperatura_agua` | pileta-exp32 temperatura agua | 18.125°C | alive |
| `sensor.esp32_pileta_temperatura_caja_techo` | pileta-exp32 temperatura caja techo | 30.0625°C | alive — roof-box temp, used as an exterior-temp *proxy* at night (see §2) |
| `sensor.esp32_pileta_temperatura_calefactor` | pileta-exp32 temperatura calefactor | 47.375°C | alive — heater element temp |
| `sensor.pileta_exp32_temperatura_agua` / `_caja_techo` / `_calefactor` | pileta-exp32 (old spelling) | — | **removed 2026-09-01** — dashboard repointed to `esp32_pileta_*`, then deleted from entity registry |

### Pinamar house — Tuya WiFi sensors (native integration)

| entity_id | friendly_name | value | status |
|---|---|---|---|
| `sensor.wifi_temperature_humidity_sensor_temperature` | pin-temp-exterior1 Temperature | 14.7°C | alive |
| `sensor.wifi_temperature_humidity_sensor_2_temperature` | pin-temp-prpal Temperature | 11.3°C | alive |
| `sensor.pinamar_pin_temp_comedor_temperature` | pin-temp-comedor Temperature | 14.5°C | alive |
| `sensor.temperatura_hab_prpal_rs_temperature` | Temperatura hab prpal RS Temperature | 20.3°C | alive — Tuya device named "Temperatura hab prpal RS" (this is the *Granaderos* main bedroom sensor, not Pinamar; "RS" = a location marker inside the room, per user) |

Each has a paired `_humidity` and `_battery_state` (enum: high/low).

### Pinamar house — legacy MQTT bridge duplicates of the same physical sensors

| entity_id | friendly_name | value | status |
|---|---|---|---|
| `sensor.temperatura_comedor_pinamar_temperatura_comedor_pinamar` | Temperatura Comedor Pinamar Humedad/Temp | 14.5°C | **removed 2026-09-01** — confirmed same device as `pinamar_pin_temp_comedor_temperature`; dashboard repointed, then deleted from entity registry |
| `sensor.sensor_t_h_pinamar_temperatura_pinamar` | Sensor T&H Pinamar Temperatura Pinamar | — | **removed 2026-09-01** — deleted by user via HA UI |

### Device/system temperatures (not ambient — monitoring the hardware itself)

| entity_id | friendly_name | value | status |
|---|---|---|---|
| `sensor.enchufe_1_device_temperature` | Enchufe_1 Temperature | 40°C | alive — Xiaomi smart plug internal temp |
| `sensor.enchufe_2_device_temperature` | Enchufe_2 Temperature | 31°C | alive — Xiaomi smart plug internal temp |
| `sensor.nucbox_cpu_temp` | NucBox CPU Temperature | 84°C | alive — gr-srv03 (proxmox host) CPU; **no entity-registry record**, pushed directly via the HA REST API (not a config-entry integration) |
| `sensor.nucbox_socket_temp` | NucBox Socket Temperature | 27°C | alive — same host, socket/motherboard sensor, same push mechanism |

### External helper (not a native sensor entity)

| entity_id | friendly_name | value | status |
|---|---|---|---|
| `input_number.quetren_temperatura` | Temperatura quetren | 23.8°C | alive — `input_number` helper, presumably set by an automation calling the `quetren_diagnostico` rest_command (100.96.140.37:8766); origin device/purpose unclear from config alone |

### Weather (external API, used only as a last-resort fallback)

| entity_id | current temperature attribute |
|---|---|
| `weather.forecast_home` | 17.5°C |
| `weather.forecast_pinamar` | (not queried — same pattern) |

## 2. Calculated sensors (`template:` in `configuration.yaml`)

### `sensor.temperatura_exterior_parque` — "Temperatura exterior parque" — 20.1°C

Fallback chain, first fresh source wins (checked in order); **the dead `zigbee_temp_exterior_temperature` leg (was #3, −1.8°C correction) was removed 2026-09-01**:
1. `sensor.temperatura_exterior_granaderos` (rtl_433 Oregon) — fresh if updated <60 min ago, +0.0°C correction
2. `sensor.zigbee_temperatura_exterior_temperature` (Zigbee, current exterior sensor) — <100 min, +0.0°C
3. `sensor.esp32_pileta_temperatura_caja_techo` (pool roof-box) — only if sun elevation ≤10° (dusk/night) AND <15 min fresh, **+3.4°C correction**
4. `weather.forecast_home` attribute `temperature` — <150 min, no correction (last resort)

Currently resolving via source #2 (Zigbee exterior sensor, 20.1°C, no correction needed).

### `binary_sensor.temperatura_exterior_parque_sin_fuente` — "no live exterior source" alarm — currently `off`

Same source list as above (sources 1–3, no weather fallback), `delay_on: 1h`. Fires `problem`
if none of the 3 sources have reported fresh data for over an hour.

### `sensor.temperatura_hab_principal` — 20.3°C

`sensor.temperatura_hab_principal_prom` was a functionally-identical duplicate template —
**removed 2026-09-01** (config block deleted, entity deregistered).

Sources (averaged if both valid, else whichever one is valid):
- `sensor.temperatura_hab_principal_nexus` (rtl_433 Nexus) — currently unavailable
- `sensor.temperatura_hab_prpal_rs_temperature` (Tuya "RS") — 20.3°C, alive

Current result = the Tuya value alone (Nexus source is dead).

### `sensor.temperatura_living` — "Temperatura living" — 20.59°C

Average of:
- `sensor.temperatura_living_nexus` (rtl_433, 21.0°C)
- `sensor.zigbee_temp_living_temperature` (Zigbee, 20.19°C)

Both alive → (21.0 + 20.19) / 2 = 20.595 ≈ 20.59°C.

### `sensor.temperatura_hab_varones` — "Temperatura hab varones" — `unknown`

**Simplified 2026-09-01**: was an average of `temperatura_hab_chicos_nexus` and the orphaned
`zigbee_temp_chicos_temperature`; now passes through `temperatura_hab_chicos_nexus` alone.
Currently `unknown` because that rtl_433 sensor is offline — will resolve once it's back, no
other live source exists for that room.

## Naming issues to resolve

- `zigbee_*` vs `wifi_*` vs plain location names mix brand/protocol into the id inconsistently.
- `_nexus` / `_rs` / device-model fragments (Oregon, Nexus, RS) leak vendor/model into names
  a human has to decode. ("RS" = a location marker inside the room, not a model — resolved.)
- `sensor.0xa4c1380a7834ffff_temperature`/`_humidity` — still an inactive raw-address duplicate
  of `zigbee_temperatura_exterior_*`; not in the entity registry, so nothing to delete, will
  age out of the recorder on its own.
- Remaining open decision: the actual **rename** of the live entity_ids/friendly_names below,
  now that duplicates/orphans are cleared out.
