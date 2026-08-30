# Home Assistant: rtl_433 battery → binary_sensor, and exterior Zigbee sensor swap

**Status:** closed
**Host:** homeassistant, docker03
**Supersedes:** —
**Superseded-by:** —

## Part 1 — rtl_433 battery sensors converted to `binary_sensor`

`sensor.temperatura_hab_chicos_bateria` and 3 siblings exposed the rtl_433 `battery_ok`
flag (boolean 0/1) through an HA `sensor` with `device_class: battery`, which HA treats
as a 0–100% charge percentage — meaningless for a boolean, and missing `expire_after`
so it never went `unavailable` on sensor death.

Converted all four to `binary_sensor` (`device_class: battery`, HA semantics: `on` = low,
`off` = normal) with `payload_on: "0"` / `payload_off: "1"` and `expire_after` matching
each device's existing temp/hum cadence (1800s for exterior Granaderos, 600s for the
other three). Committed to the HA config repo (`igarreta/homeassistant`, commit `085ad79`).

| unique_id | old entity_id | new entity_id |
|---|---|---|
| `temp_ext_gran_bat` | `sensor.temperatura_exterior_granaderos_bateria` | `binary_sensor.temperatura_exterior_granaderos_bateria` |
| `temp_living_nexus_bat` | `sensor.temperatura_living_nexus_bateria` | `binary_sensor.temperatura_living_nexus_bateria` |
| `temp_hab_prpal_nexus_bat` | `sensor.temperatura_hab_principal_bateria` | `binary_sensor.temperatura_hab_principal_nexus_bateria` (name changed too) |
| `temp_hab_chicos_bat` | `sensor.temperatura_hab_chicos_bateria` | `binary_sensor.temperatura_hab_chicos_bateria` |

Also updated: `chequeo_baterias_diario` automation now also scans `states.binary_sensor`
(low when state `on`); `/config/CLAUDE.md`'s Battery Monitoring section; the 4 entity
rows in the `dashboard_pruebas` Lovelace dashboard (`.storage/`, not git-tracked).

Follow-up not done (low priority, cosmetic): the 4 orphaned `sensor.temperatura_*_bateria`
registry entries can be deleted via Settings → Devices & Services → Entities — HA already
moved them to its internal deleted-entity tombstone state on its own, so they aren't live
or visibly broken, just idle registry rows.

**Docs correction found while verifying exact `state_topic` strings against the live
config**: [2026-06-27_rtl433-production-migration.md](2026-06-27_rtl433-production-migration.md)
listed Oregon-THGR122N (exterior Granaderos) as `id=161`; the live config uses `id=87`.
Corrected with a banner on that doc.

## Part 2 — exterior Zigbee temp/humidity sensor physically replaced

`0xa4c1386e91d0faf4` (friendly_name `zigbee_temperatura_exterior`) was retired and
removed from the z2m config on docker03. `0xa4c1380a7834ffff` (a new SONOFF SNZB-02WD)
was renamed to the same friendly_name so it drops into the existing fallback chain with
zero config changes:

- `configuration.yaml`'s `temp_exterior_parque` template references
  `sensor.zigbee_temperatura_exterior_temperature` **by entity_id**, not by device/IEEE
  address — nothing there needed editing.
- Removing the old device from z2m's config made HA auto-retract its MQTT discovery and
  move its device + all 7 entities to the deleted-entity/deleted-device tombstone state
  on its own (no manual registry edit needed) — which freed the entity_id for reuse.
- The new device claimed `sensor.zigbee_temperatura_exterior_temperature` (and
  `_humidity`, `_battery`, `_voltage`, etc.) cleanly, no `_2` suffix collision.
- Verified live: `sensor.temperatura_exterior_parque` = 18.8°C at `21:35:59Z`, identical
  value and timestamp to `sensor.zigbee_temperatura_exterior_temperature` — the fallback
  chain is actively sourcing from the new device.

**Troubleshooting note for next time**: z2m does not retain per-device state messages
by default (`mqtt.force_disable_retain` / per-device `retain` both default `false`).
`mosquitto_sub -t 'zigbee2mqtt/<friendly_name>'` on a slow-reporting device (this sensor
reports only every few minutes) can time out with nothing wrong — check z2m's own
container log or HA's MQTT debug log instead of relying on a retained-message subscribe.
