---
name: project_homeassistant_temperature-sensor-naming
description: HA temperature sensor entity_ids are being renamed for clarity; full inventory taken, waiting on user's naming proposal
metadata:
  type: project
---

Temperature entity naming in Home Assistant is confusing (mixes brand/protocol/location
inconsistently: `zigbee_*`, `wifi_*`, `_nexus`, `_rs`). User asked for a full inventory
before proposing new names.

**Why:** a rename pass touches `configuration.yaml` template sensor sources, automations,
and dashboards — needs the full picture (which entities are live, which are dead/orphaned
duplicates) before touching names, or renames could point at defunct entities.

**How to apply:** the inventory (real + calculated sensors, template source chains) is in
docs/2026-09-01_homeassistant_temperature-sensor-inventory.md. Duplicate/orphan cleanup is
done (2026-09-01): dead `zigbee_temp_exterior_*`/`zigbee_temp_chicos_*` unwired from all
template chains, duplicate `temperatura_hab_principal_prom` template removed, legacy
`pileta_exp32_*`/`temperatura_comedor_pinamar_*`/`sensor_t_h_pinamar_*` entities deleted and
dashboards repointed to the live entities. "RS" in `temperatura_hab_prpal_rs` = a location
marker inside the room. Only the actual entity_id/friendly_name **rename** is still open —
user to propose names or ask for suggestions.
