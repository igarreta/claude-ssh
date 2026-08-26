---
name: project_docker03_zigbee_rf_degradation
description: "Zigbee coordinator RF degraded after the 2026-08-17 dongle move; fleet LQI 200→134; 08-25 final wall-mounted placement lifted it to ~220 fleet-wide; recheck 2026-09-09 before closing and cancelling the shielded-cable purchase"
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
still-open external-AP hypothesis. A further small position tweak that evening at ~21:30
produced a confirmed, fleet-wide LQI jump (~189 → ~220) starting ~21:45, holding into
08-26 morning. The user then made this the **permanent placement**: dongle screwed to the
wall, on a USB port dedicated away from the BACKUP_A/B disks (separate USB bus), with the
same reused cable. That removes the main remaining risk — the good position being
accidental and lost on the next disk swap.

**Why the ferrite cable purchase is on hold, not cancelled:** the original degradation
developed gradually over 4 days, not as a step, so ~16h of good readings doesn't yet rule
out a slow relapse. The purchase was already ~2 months out, so waiting costs nothing.

**How to apply:** `docs/2026-08-24_docker03_zigbee-coordinator-rf-degradation.md` (**open**,
recheck **2026-09-09**: if LQI is still ~200+ with no gradual decline, close the doc and
cancel the shielded-cable purchase, §4 item 1). §5 has the 08-25 relocation timeline incl.
an ~11.5h outage from the move not re-seating cleanly; §6 has the LQI confirmation with
hourly numbers. Also fixed there: HA offline/online automations dead since 2026-04-30 on a
missing entity. Related: [[project_gr-srv03_powered-hub-instability]],
[[project_docker03_zigbee2mqtt]].
