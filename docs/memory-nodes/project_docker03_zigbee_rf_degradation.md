---
name: project_docker03_zigbee_rf_degradation
description: "Zigbee coordinator RF degraded after the 2026-08-17 dongle move to a bare chassis port; fleet LQI 200 to 134, shielded USB extension pending"
metadata:
  node_type: memory
  type: project
---

The Zigbee coordinator's RF degraded after the 2026-08-17 dongle move to a bare chassis port
beside USB3 storage: fleet-wide LQI fell **200 → 134** (08-18 → 08-22), which caused the
08-22 dropped switch command on `luces medianera z`. The fix — a shielded USB extension — is
**pending, ~2 months out**. Baselines saved in `docs/data/*.csv`.

**Why:** USB3 emits broadband noise in the 2.4 GHz band; the dongle sitting directly beside
storage ports is the whole mechanism. `linkquality` on the individual device stayed normal,
so per-device LQI is not a reliable detector.

**How to apply:** `docs/2026-08-24_docker03_zigbee-coordinator-rf-degradation.md` (**open**).
Also fixed there: HA offline/online automations dead since 2026-04-30 on a missing entity.
Related: [[project_gr-srv03_powered-hub-instability]], [[project_docker03_zigbee2mqtt]].
