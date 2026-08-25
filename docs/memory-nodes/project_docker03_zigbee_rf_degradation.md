---
name: project_docker03_zigbee_rf_degradation
description: "Zigbee coordinator RF degraded after the 2026-08-17 dongle move to a bare chassis port; fleet LQI 200 to 134; 08-25 relocated dongle + disabled gr-srv03's onboard WiFi; awaiting a day of LQI data"
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

On 2026-08-25 the dongle was relocated (now `usb 1-3`, was `usb 1-1`) and gr-srv03's
internal WiFi card (`wlp1s0`, unused backup) was fully disabled — driver blacklisted, not
just link-down — since it's another 2.4 GHz radio in the same chassis, distinct from the
still-open external-AP hypothesis. First post-move LQI sample read 200 (healthy), but
that's one reading right after reconnect, not a trend; a full day is still needed.

**How to apply:** `docs/2026-08-24_docker03_zigbee-coordinator-rf-degradation.md` (**open**,
§5 has the 08-25 timeline incl. an ~11.5h outage from the move not re-seating cleanly).
Also fixed there: HA offline/online automations dead since 2026-04-30 on a missing entity.
Related: [[project_gr-srv03_powered-hub-instability]], [[project_docker03_zigbee2mqtt]].
