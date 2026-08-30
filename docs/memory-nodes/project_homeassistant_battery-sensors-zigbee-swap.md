---
name: project_homeassistant_battery-sensors-zigbee-swap
description: rtl_433 battery sensors converted to binary_sensor; exterior Zigbee temp/humidity device physically swapped, same friendly_name
metadata:
  type: project
---

Two independent HA changes on 2026-08-30, both closed. Detail:
[docs/2026-08-30_homeassistant_battery-binary-sensors-and-exterior-zigbee-swap.md](../2026-08-30_homeassistant_battery-binary-sensors-and-exterior-zigbee-swap.md).

**Why it matters:** a `sensor` with `device_class: battery` fed a boolean 0/1
`battery_ok` flag — meaningless as a percentage, and the pattern still exists as a
documented convention in the HA repo's own `/config/CLAUDE.md` ("RTL_433 binary" battery
format). If more rtl_433 or similar boolean-battery devices show up, use `binary_sensor`
+ `device_class: battery` (on=low, off=normal) instead, and remember the
`chequeo_baterias_diario` automation needs `states.binary_sensor` in its scan loop too,
not just `states.sensor`.

**How to apply:** when a template/automation needs to keep working across a hardware
swap, reference the entity_id, not the device/IEEE address — `temp_exterior_parque`
needed zero config changes because it did exactly that. Also: removing a device from
z2m's config auto-retracts its MQTT discovery and HA auto-deletes the entity/device
registry rows on its own — no manual registry surgery needed before reusing a
friendly_name.
