---
name: project_docker03_zigbee_rf_degradation
description: "Zigbee coordinator RF degraded after the 2026-08-17 dongle move; fleet LQI 200→134; 08-25 fix lifted it to ~220; RELAPSED to ~120 after the 09-05 CT206 migration; 09-13: moved Zigbee ch 11→25 at zero re-pairing cost, and the real signal turns out to be ~1700-2000 route errors/day on a 10-device network — not the LQI, and not the dongle"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3a5d59b8-5617-4ea7-8442-e072c0e4686f
  modified: 2026-09-13T22:00:00.000Z
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

**2026-09-11 recheck (§8 of the doc):** still open. Three things changed how to read this
fault. (1) **LQI is not a stable degraded level — it swings ~60 points daily** (86 at 04h,
147 at 16h on 09-11), so every earlier single number, including the ~220 of 08-26 and the
~134 floor, is only as good as the hour it was taken; compare like-for-like hours from now
on. (2) The nightly trough starts near the 02:25-03:30 backup disk-wake window
([[project_backup_schedule]]) but outlasts it by ~3 h — suggestive, one night only, needs
two or three more nights before believing it. (3) Route errors are now ~1900/day against
825 on August's worst day, and they stay flat through the LQI swing — the two symptoms look
decoupled, so a recovered LQI would not by itself mean the fault is gone.

**The WiFi-channel test is dead**, not pending: the AP is a TP-Link Deco mesh with no manual
2.4 GHz channel selection. The remaining lever was moving Zigbee off channel 11 — **done on
2026-09-13, see below. The feared re-pairing cost did not exist.**

**2026-09-13 (§9 of the doc) — three things settled:**

1. **Channel moved 11 → 25, and it was free.** All 9 real devices republished within 4 minutes,
   battery end devices included. **Zero re-pairings.** The §8 reasoning that deferred this
   ("costs re-pairing 8 devices") was wrong — `pan_id`/`ext_pan_id`/`network_key` are pinned in
   `configuration.yaml`, so only the channel migrated, which is the clean case. **Don't defer a
   channel change again on that assumption.** Chose 25 (2475 MHz) over 15/20 because a real
   `nmcli` scan from raspberrypi1 put the loudest AP on WiFi ch 3 and another on ch 10, and 25
   sits above all of WiFi 1–11 — so it survives the Deco reassigning itself.
2. **The metric to watch is route errors, not LQI.** ~1700–2000/day on a network of **10
   devices** (5 mains routers, 4 battery end devices) is anomalous by one to two orders of
   magnitude. A mesh that small should produce a handful.
3. **The dongle is ruled out as the cause.** Startup banner: **EmberZNet 8.0.2 [GA]**, build 397,
   EZSP v14, on a Sonoff ZBDongle-E (EFR32MG21) — current firmware, well past the 6.10.3 factory
   image, on a chip rated for 100+ devices. Note EZSP v14 is shared by EmberZNet 7.4.x *and* 8.x,
   so read the stack version off the boot banner, never inferred from the EZSP number.
   See [[project_ttato-split-and-radio-head]]: if a coordinator is ever bought, the reason is
   Ethernet-attached placement, not more radio.

Also done 09-13: `log_level: debug` → `info` (it was writing every ASH frame to disk). And a
pre-existing fault to not misattribute: **`bomba agua z` (NWK 43800) was already failing
delivery before the channel change** and is the target of most route errors — open question
whether ch 25 fixes it or it's a device-level problem.

**The log_level change rescaled the route-error counter — read §9.8 before comparing any
numbers.** Under `debug` one route error produced 3-4 lines that the collector counted all of,
so **every `routeerr-*.csv` before 2026-09-13 is inflated ~3-4x** and cannot be recomputed (logs
rotate at ~22 h). `parse.awk` was fixed to count the one `info`-level line that both log levels
emit, so counts are now stable and carry the device again; `ZIGBEE_DELIVERY_FAILED` split off to
its own `delivfail-*.csv` (empty while log_level is info). **09-13 is a mixed day — discard it.
The clean baseline starts 2026-09-14.** Versioned copy: `ct206/zigbee-lqi/parse.awk` in claude-ssh.

**2026-09-19 (§10 of the doc) — two of the 09-13 conclusions above are wrong:**

1. **The route-error headline is retracted.** `bomba agua z` had been **physically unplugged
   since 09-09 22:06**, and it is a mains TS011F, i.e. a *router*. Splitting the pre-09-13 files
   by event code: 09-11 was 346 genuine `SOURCE_ROUTE_FAILURE` + **825 `ZIGBEE_DELIVERY_FAILED`**
   (attempts to reach the unplugged pump) + 779 duplicate `debug` lines. So "~1700-2000 route
   errors/day, anomalous by one to two orders of magnitude" **was never true** — real route
   errors were ~300-360/day, and mostly aimed at the dead device too.
2. **"Zero re-pairings" was a misreading.** The channel change **cost two sensors** —
   `zigbee_temp_living` and `zigbee_temperatura_exterior_alt` (both ZY-ZTH02) have been silent
   since 2026-09-13 18:45/19:15. What was taken as proof they returned is z2m's retained-state
   republish plus HA discovery configs, which it emits for **every configured device whether or
   not it rejoined**. Other battery devices did follow, so it is not "all end devices".

**What genuinely improved is LQI**, not the errors: daily means 121 → 133 → 143 → **154**, the
diurnal swing collapsed from 68 points to 25, and the night trough vanished — which also weakens
the §8 backup-disk-wake correlation. `SOURCE_ROUTE_FAILURE` went the *other* way, 346/day →
1321/day, and moved wholesale from 43800 to **25060 (`luces medianera z`)** at the 18:45 restart.
The log shows a route error and, in the same second, a successful publish from that device: the
source route fails, repairs, and the poll gets through — ~1 repair per poll. There is **no stale
route through the dead node** (only 6 mentions of 43800 since, all `Failed to ping`); the likelier
story is that ch 25 rebuilt every route from scratch **with one router fewer**.

Pump **manually re-paired 2026-09-19 14:44**, new NWK **46746** (was 43800 — every earlier
reference is historical), LQI 225-232. **No verdict yet** on whether that repairs the 25060 path:
baseline to beat is 41.6 route errors/hour. Also found: this TS011F never honours its
attribute-reporting config — [[project_bomba-agua_current-measurement]].

**Now measuring.** Give it several days, compare like-for-like hours, and **change nothing else
meanwhile** — especially don't move the dongle physically. Still to do: **re-pair the two lost
sensors**.

Measuring this now goes through the collector on CT206, not through the z2m logs (~22 h of
retention): [[project_zigbee_lqi_collector]].
