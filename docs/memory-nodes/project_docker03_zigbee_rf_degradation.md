---
name: project_docker03_zigbee_rf_degradation
description: "Zigbee coordinator RF degraded after the 2026-08-17 dongle move; fleet LQI 200→134; 08-25 fix lifted it to ~220; RELAPSED to ~120-127 after the 09-05 CT206 migration, dongle port confirmed unchanged; 09-09 recheck must address the relapse, not just confirm the August fix"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3a5d59b8-5617-4ea7-8442-e072c0e4686f
  modified: 2026-09-06T19:07:52.832Z
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
out a slow relapse — and on 09-05/06 it relapsed. Fleet LQI fell to ~120-127 (worse than
the original 134 floor) right after zigbee2mqtt's migration to CT206
([[project_zigbee2mqtt_migration]]), with route errors trending toward the worst August
day (551 on 09-06, partial day, vs 825 on 08-22 full day). The dongle's physical USB
port was checked on gr-srv03 and is unchanged (`usb 1-3`, still on a separate bus from
the backup disks).

Several candidate causes were checked and ruled out: the user recalled plugging the
rtl-433 (RTL-SDR) dongle briefly that evening — a plausible repeat of the original
USB3-proximity mechanism — but hourly LQI shows the drop to ~122 was already fully in
place 44 minutes after the CT206 cutover, *before* the rtl-433 ever touched a USB port
(19:20-19:30 window); it and a concurrent backup-disk disconnect only added a brief
extra dip on top of an already-degraded baseline. The user then started VM 102
(docker03) to compare against the pre-cutover stack (without starting its zigbee2mqtt
container, to avoid a second coordinator on the same PAN): identical zigbee2mqtt 2.12.0
/ zigbee-herdsman 10.4.0 on both sides, identical `configuration.yaml` advanced block
(no `transmit_power` set either place), and USB autosuspend confirmed off
(`power/control=on`) on the host port. Version, config, and USB power management are
now all ruled out. Only remaining candidates: the still-open WiFi-AP-channel hypothesis
(doc §4 item 2, AP on ch3 never moved — the one free/concrete thing left to try), or
something about the LXC-bind-mount vs. VM-passthrough access path itself with no
identified mechanism. A real A/B (temporarily passing the dongle back to the VM) may be
needed if the WiFi-channel change doesn't move the needle before 09-09.

**How to apply:** `docs/2026-08-24_docker03_zigbee-coordinator-rf-degradation.md` (**open**;
§7 has the 09-05/06 relapse data). **Do not close the doc or cancel the shielded-cable
purchase at the 2026-09-09 recheck on the strength of the August fix alone** — the relapse
must be explained or resolved first. §5 has the 08-25 relocation timeline incl. an ~11.5h
outage from the move not re-seating cleanly; §6 has the 08-26 LQI confirmation with hourly
numbers. Also fixed there: HA offline/online automations dead since 2026-04-30 on a
missing entity. Related: [[project_gr-srv03_powered-hub-instability]],
[[project_docker03_zigbee2mqtt]], [[project_zigbee2mqtt_migration]].
