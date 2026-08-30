# gr-srv03 USB layout plan — powered hubs for storage + dongles (2026-08-19)

**Status:** open
**Host:** gr-srv03
**Supersedes:** —
**Superseded-by:** —

**Status detail:** Storage hub **ordered 2026-08-29 (Rosonway RSH-A10), ETA ~2026-10-24**
(~8 week lead time); nothing installed or moved yet. **Layout decided 2026-08-30 —
[Option D](#decided-layout--option-d-2026-08-30), which needs no second hub**; Options A/B/C
below are retained for the record and were not taken. Extension cables still to order
(Conable CAL2S-6-3PK); ferrites deprioritised. Current setup is the
post-incident one (hub removed, everything on direct ports) documented in
[memory_gr-srv03_powered-hub-instability.md](memory_gr-srv03_powered-hub-instability.md).

## The constraint

gr-srv03 (GMKtec NucBox G5) has **only 3 external USB-A ports, all USB 3.2 Gen 1
(5 Gbps)**. All three are currently occupied:

| port | device |
|---|---|
| 1 | Sonoff Zigbee 3.0 Dongle Plus V2 (`10c4:ea60`) |
| 2 | Toshiba Canvio Basics, BACKUP_A/B rotating slot (`0480:a202`) |
| 3 | Kingston XS1000 SSD, `backup_usb1` (`0951:1780`, UAS) |

Bluetooth (`0bda:c821`) and the Zoran USB audio (`0573:1573`) are internal, not
occupying external sockets.

Planned additions: the **RTL-433 SDR** (disconnected since 2026-08-17 when the old hub
was pulled) and — **contingent, see below** — a **second HDD** permanently connected
alongside the rotating backup drive. Either way that is more devices than ports, so a hub
is mandatory.

> **The second HDD is cancelled if the NAS is bought (decided 2026-08-30).** The NAS
> absorbs the capacity that drive was for, so it is only purchased if the NAS project does
> not go ahead — see [memory_nas-project.md](memory_nas-project.md), which is
> purchase-ready with only the P1-vs-P2 call open. **Do not buy the HDD before the NAS
> decision.** Nothing in this layout depends on the outcome: the RSH-A10 has 10 ports and
> ample headroom either way (see the load note under Option D), so the drive can be added
> later with no re-planning.

> **Do not trust `connect_type` / `peer` in sysfs on this board.** It reports
> `usb1-port1` and `usb1-port2` as separate hotplug sockets with no USB3 peer, and
> shows `usb1-port6`/`usb2-port2` as one socket with a different device on each.
> Neither matches the physical 3-port reality. Count sockets at the chassis.

## Decided layout — Option D (2026-08-30)

**Port 3 stays dedicated to the Zigbee dongle, direct on a host port. No second hub is
bought.** Options A, B and C below were not taken; they are kept because their reasoning
still explains why the storage/dongle split matters.

| port | connected | carries |
|---|---|---|
| 1 | **RSH-A10** (12 V/3 A, PPPS) | BACKUP_A/B + **RTL-433** (test use) + second HDD *only if the NAS is not bought* |
| 2 | Kingston XS1000 | direct, dedicated |
| 3 | **Sonoff Zigbee dongle** | direct — **unchanged from today** |

**Load note.** The 36 W brick was sized for two 2.5" HDDs spinning up together (~20 W).
The actual day-one load is one HDD plus the RTL-433 (~300 mA at 5 V, ~1.5 W) — roughly
half that. If the second HDD is later added the peak returns to ~22 W, still ~40% under
budget. The hub is not the constraint under any outcome of the NAS decision.

**Why.** Zigbee is the critical device, and this is the only layout that does not touch it
at all. It keeps its own host port, no hub in its path, no shared 12 V brick — so the
rebuild introduces exactly zero new failure modes into home automation. Options A/B put it
behind a cheap unpowered hub; Option C put it behind the same brick as the backup drives,
whose blast radius was that option's stated reason for rejection. Here the storage hub can
fail completely and heating and lighting do not notice.

**Why the RTL on the storage hub is acceptable now — it is test-only.** Production 433 MHz
reception runs on raspberrypi2z and is unaffected by anything in this plan (see
[2026-06-26_raspberrypi2z_rtl433-setup.md](2026-06-26_raspberrypi2z_rtl433-setup.md)). The
gr-srv03 SDR has been disconnected since 2026-08-17 and comes back for experiments only, so
the USB3/HDD RFI penalty costs bench sensitivity, not sensor coverage. That is the whole
reason this layout appears under *Alternatives rejected* below in the 08-19 version and is
the decision now: the assumption that made it worse than Option C — a sensitivity-critical
SDR — is not true. Give it a shielded extension anyway and keep it off the drive cabling;
if a test needs real sensitivity, move it to port 3 for the duration and unplug the Zigbee
dongle, or run the test on raspberrypi2z.

**Bonus:** the RTL lands on a PPPS port, so a wedged SDR can be power-cycled with `uhubctl`
instead of by hand.

**The accepted cost — Zigbee gets no PPPS.** Option C's main draw was letting the recovery
watchdog cut VBUS on the dongle instead of escalating to a host reboot after a USB
re-enumeration like 2026-07-15
([memory_docker03_zigbee2mqtt.md](memory_docker03_zigbee2mqtt.md)). On a direct host port
that escalation path stays a reboot. Deliberate: paying for it meant putting the critical
device behind the storage hub's brick.

## Option A — two hubs, 10 Gbps dongle hub (original plan, not taken)

| port | connected | carries |
|---|---|---|
| 1 | **powered storage hub** (4–5 A, per-port switching) | BACKUP_A/B + new HDD |
| 2 | Kingston XS1000 | direct, dedicated |
| 3 | **small dongle hub** | Zigbee CP210x + RTL-433 |

Two clean domains: storage never shares a rail with the dongles.

## Rationale for splitting storage from dongles

**Storage on a self-powered hub — this is the actual fix.** The root cause of the
2026-07/08 Zigbee episodes was a bus-powered HDD's inrush (capacitor charge + motor
spin-up) sagging the shared host 5 V rail, which the cheap Terminus `1a40:0101` hub
could not tolerate. Once the HDDs draw their inrush from a self-powered hub's own
brick, the host rail sees only the hub's constant upstream logic current. **The
transient is eliminated at the source**, not merely routed around.

**Why a hub in front of the Zigbee dongle is acceptable now.** The old failure was not
"the dongle was on a hub" — it was "a cheap hub browned out when HDD inrush sagged the
shared rail". With the drives self-powered, the dongle hub carries ~400 mA of steady
load and has no transient source on it at all. Different environment from the one that
failed.

**Why the RTL must not share the storage hub — RF, not power.** An RTL2832U/R820T2
draws ~300 mA (≈3× the CP210x), but the deciding factor is that USB3 SuperSpeed
signalling and spinning drives are broadband RFI sources across HF/VHF, right where
the 433 MHz sensors live. Sharing a hub with two USB3 HDDs costs receive sensitivity,
and it presents as *sensors going missing*, not as a USB fault. Keep the SDR away from
storage and on a short **shielded** extension cable, away from the chassis. (Use a
good one — a bad extension cable was the kernel's first suspicion on 07-15.)

**Kingston XS1000 stays direct.** It is NVMe-class (~1 GB/s) on UAS and is the only
device that would notice sharing a hub's single 5 Gbps uplink. The HDDs (~120 MB/s
each, ~240 MB/s aggregate) lose nothing behind a hub.

## Option B — two hubs, USB 2.0 dongle hub (not taken)

Same layout as Option A, but port 3 gets the **$7 Sabrent HB-MCRM** (USB 2.0,
bus-powered) instead of a 10 Gbps hub. Removes the SuperSpeed RFI source next to the
SDR and costs half as much; gives up PPPS and the aux 5 V input, and reintroduces
Terminus `1a40:0101` silicon — the same part as the hub pulled on 08-17, though the
root-cause work exonerates it for a dongle-only load. Reasoning in the dongle-hub
section of
[2026-08-19_gr-srv03_usb-hub-comparison.md](2026-08-19_gr-srv03_usb-hub-comparison.md).

## Option C — no second hub (added 2026-08-19, not taken)

The RSH-A10 has **10 PPPS ports and only two drives to put on them**. Spending a
second purchase on port 3 is optional.

| port | connected | carries |
|---|---|---|
| 1 | **RSH-A10** | BACKUP_A/B + new HDD + **Zigbee dongle** (~1 m USB2 extension) |
| 2 | Kingston XS1000 | direct, dedicated |
| 3 | **RTL-433** | direct, on a shielded extension |

**Why this beats Option A on the points that matter**

- **The RTL gets a direct host port**, no hub anywhere in its path. Strictly better
  RF than sharing a USB 3.2 dongle hub, which is what every purchasable candidate
  for port 3 turned out to be — see the dongle-hub section of
  [2026-08-19_gr-srv03_usb-hub-comparison.md](2026-08-19_gr-srv03_usb-hub-comparison.md).
- **The Zigbee dongle gains PPPS.** It is the one device with a demonstrated need:
  the 2026-07-15 zigbee2mqtt outage was a USB re-enumeration, and `uhubctl` lets the
  existing recovery watchdog cut VBUS instead of escalating to a host reboot.
  See [memory_docker03_zigbee2mqtt.md](memory_docker03_zigbee2mqtt.md).
- **No second purchase, and no new Terminus-class hub** reintroduced into the system.
- Uses 3 of 10 ports, leaving room to grow. The dongle's 12 Mbps sharing the hub's
  5 Gbps uplink with two HDDs is irrelevant.
- Passthrough is ID-based (`usb2: host=10c4:ea60`) so the dongle follows the move
  with no VM config change.

**The cost — blast radius.** Today the Zigbee dongle sits on a direct host port and
survives everything short of a host outage. Behind the RSH-A10, a single failed 12 V
brick takes out backups **and** home automation at once. That consolidation is the
reason to reject this option if it is rejected.

**Secondary concern.** USB3 emissions are a documented 2.4 GHz problem, so the Zigbee
dongle is not immune just because it is not the SDR. The ~1 m extension is the standard
mitigation (Sonoff recommends one regardless), and peak SuperSpeed emission coincides
with the 00:30 backup window, when Zigbee traffic is lowest.

**Fallback if the blast radius is unacceptable.** Take Option B. Spending $55–70 on a
Phidgets HUB0003_0 to get PPPS on a separate dongle hub is not proportionate — and no
cheap USB 2.0 PPPS hub remains in production, see the comparison doc.

## Extension cables (needed under every option)

> **Decided 2026-08-19: Conable CAL2S-6-3PK — 3 x 6 ft USB 2.0 A-male to A-female,
> $10 the pack.** Covers both dongles plus a spare. Not yet purchased.

Under **Option D** the split is:

- **RTL-433** — required. It hangs off the RSH-A10 alongside the USB3 drive cabling, so
  distance from that cabling is the only RFI mitigation left once the ferrites are dropped.
- **Zigbee dongle** — optional but recommended. It stays on its own host port, so this is
  the plain Sonoff advice (get the dongle away from the chassis), not a hub workaround.

The third cable in the pack is the spare. Under the untaken Options A/B/C both extensions
were mandatory — see the option sections above.

> **Allocation rule (added 2026-08-30): the Sonoff's own extension goes to Zigbee, the
> CAL2S to the RTL-433.** Check the box first — the Dongle Plus V2 usually ships with one.
> The CAL2S's shield quality is unpublished (see [the open risk](#the-open-risk-shield-quality)
> below), and under Option D that unknown must not sit on the critical device. Putting it on
> the test-only receiver costs nothing if it turns out to be poor. If the Sonoff box has no
> cable, Zigbee still gets the better-measuring CAL2S of the three and stays first suspect
> if it re-enumerates.

### Why USB 2.0, not USB 3.x

Neither device exceeds 480 Mbps, so the SuperSpeed pairs would carry nothing — and a
cable without them has nothing to radiate or pick up next to a 433 MHz receiver. It is
also cheaper. 6 ft is well inside the 5 m USB 2.0 limit, and the extra length helps the
RF separation the layout is built around.

### Why 28AWG is good enough (28/24AWG not worth paying for)

28AWG is ~0.21 Ω/m, so a 6 ft run is ~0.78 Ω round trip. At the RTL-SDR's ~300 mA that
is a **~0.23 V drop**, leaving ~4.75 V at the dongle against a 4.4 V spec floor —
comfortable. 24AWG power conductors would recover ~0.15 V that is not needed. The
Zigbee dongle at ~100 mA has three times the margin.

### Gold-plated contacts are not a factor

Gold is a worse conductor than copper; its only benefit is corrosion resistance across
many insertion cycles, and these connections are mated once and left in a dry indoor
room. The plating difference is milliohms against 0.78 Ω of cable. The USB spec already
requires gold on the mating contacts, so the phrase in a listing usually describes
compliance rather than an upgrade, and it says nothing about signal integrity or RF.

### Ferrites — deprioritised 2026-08-30

> **NOT being bought.** The 08-19 decision below (13 mm ID clip-on, wire-wound, 10 pcs,
> bought alongside the cables) is superseded by the Option D layout: the only RF victim on
> the storage hub is the **test-only** RTL-433, and cheap clip-ons were never expected to do
> more than take the edge off a marginal cable. If RTL coverage does prove unusable after
> the rebuild, buy them then — the spec below is still the right one, and a known-good
> shielded cable is the other remedy. Nothing in production depends on this receiver.

The 08-19 reasoning, retained for that eventuality:

13 mm is chosen specifically so **2–3 turns** of a 4.5 mm USB cable fit through the
bore. A ferrite's common-mode impedance scales with the square of the turns, so three
turns is roughly 9x a single pass — that gain is the entire reason not to buy a snug
5–6.5 mm core. (3.5 mm cores do not fit a USB cable at all.)

Expect modest, not dramatic, results at 433 MHz: cheap unspecified clip-ons are
optimised well below UHF, so the turns are what make them worth fitting. This takes the
edge off a marginal cable; it will not rescue a badly shielded one.

**Treat the source, not just the victim.** Ten cores is enough to clamp the two USB3
HDD cables between the RSH-A10 and the drives, which is where the broadband noise
originates. Suppressing there is usually more effective than protecting the SDR
extension alone, and it is the better first move if RTL coverage drops after the
rebuild.

**Do not clamp one at a connector.** A 13 mm core has real mass and will lever on the
USB contacts of a dongle plugged into a hub. Fit it a few cm back along the cable with
the core supported, or at the host end.

### The open risk: shield quality

Conable publishes no AWG, shielding, or ferrite spec for the CAL2S, and at $3.33/cable
it is probably foil-only. Shield coverage — and whether the connector shell is bonded
to it — is the one property that actually matters next to the SDR, and it is unknown.
This is deliberately accepted rather than insured against: verify step 4 below already
watches for it, and a known-good shielded cable is $8 if the cheap one proves to be the
problem. Under Option D the exposure is smaller than it looks — the SDR behind this cable
is test-only — but the Zigbee dongle may also end up on one of these cables, and that one
is critical, so a re-enumeration after the rebuild means swap the cable first.

A bad extension cable was the kernel's first suspicion during the 2026-07-15 episode.
The failure mode presents as intermittent re-enumeration or quietly missing sensors,
not as an obvious cable fault — so if either dongle misbehaves after the rebuild,
swap the cable early rather than late.

## Alternatives rejected

- **Both dongles direct, drives on a hub** — does not fit. 3 ports minus the hub minus
  the XS1000 leaves one port for two dongles.
- ~~**Zigbee direct, RTL on the storage hub**~~ — **this is Option D, chosen 2026-08-30.**
  Rejected on 08-19 as "the inverse of Option C, and worse: it puts the RF-sensitive one-way
  receiver next to the drives and denies PPPS to the device that has actually needed a
  power-cycle." That rejection assumed the gr-srv03 SDR mattered for sensor coverage; it is
  test-only, production 433 MHz being on raspberrypi2z. With the RFI penalty falling on a
  bench device, keeping the critical Zigbee dongle off any hub wins. See
  [Option D](#decided-layout--option-d-2026-08-30).
- **Everything except the SSD on one big powered hub** — recreates the exact
  drive/dongle adjacency that caused the incident, and the RFI problem regardless of
  power quality.
- **XS1000 on the storage hub** to free a port for a dongle — sacrifices the one
  device whose throughput is hub-limited.

## Purchase criteria

> **Decided 2026-08-19: Rosonway RSH-A10 ($37)** — mechanical switches (state
> survives a power outage) plus per-port power switching verified on every port.
> Six candidates compared against these criteria in
> [2026-08-19_gr-srv03_usb-hub-comparison.md](2026-08-19_gr-srv03_usb-hub-comparison.md).
> **Ordered 2026-08-29, ETA ~2026-10-24.**

**Storage hub**
- Genuinely **self-powered** with its own **12 V / 4–5 A** brick, and no backfeed into
  the host port. This property is the entire basis of the layout — verify it.
  (The selected RSH-A10 is 12 V/3 A / 36 W — below this range but still ample:
  two 2.5" drives peak near 20 W including simultaneous spin-up.)
- Sizing is for **two 2.5" HDDs spinning up simultaneously** (~1 A @ 5 V transient
  each on top of ~0.5 A steady). Worst case is real: the 00:30 cron starts both mount
  units in one command.
- **Per-port power switching (PPPS)** — keeps a hot-plug on one port from sagging the
  other, and enables `uhubctl` to cut port power after unmounting and before physically
  pulling a drive. That gives a guaranteed clean detach and a near-zero removal
  transient. (Relevant: the 08-18 19:47 removal was a live yank of a mounted
  filesystem — JBD2 I/O error and EXT4 journal replay.)
- **Assert port power on, never assume it** (added 2026-08-20). Run
  `uhubctl -l <hub-location> -a on` at the top of the 00:30 remount path and once at
  boot, before any mount is attempted. Without it, an outage landing between the 15:00
  unmount and the physical swap could leave a port switched off, and the resulting
  failure is indistinguishable from the normal offsite-rotation "drive missing" state.
  With it, no hub's power-on default matters — which is why that property was retired
  as a purchase criterion. See
  [2026-08-19_gr-srv03_usb-hub-comparison.md](2026-08-19_gr-srv03_usb-hub-comparison.md).
- **Do not power the backup drives off between nightly runs.** APM already spins them
  down after ~10 min idle; cutting VBUS instead would add a spin-up cycle per night,
  and spin-up count is the dominant wear metric on a 2.5" HDD.
- Chipset: VL817 / GL3510-class USB 3.2. **Not** Terminus-class.

**Dongle hub** — **not being bought** under Option D. Criteria retained in case a fourth
USB device ever appears: USB2 is sufficient (Zigbee is full-speed, RTL needs 480 Mbps
high-speed); powered preferred but not essential at ~400 mA total; still not the cheapest
part available.

## No config changes needed

- Both mount units are `What=UUID=...` (`/etc/systemd/system/mnt-backup_[ab].mount`),
  so the drives mount identically behind a hub.
- VM 102's Zigbee passthrough is ID-based (`usb2: host=10c4:ea60`) and follows the
  dongle to any port. Path-based entries were removed 2026-08-18 — do not reintroduce
  them, they are an auto-capture trap when hub topology changes.

## To implement when the hub arrives (added 2026-08-30)

Three items that are not "plug it in". The first is a hard dependency of the decision
already made; the second must happen **before** the rebuild, not after.

### 1. Assert port power on — REQUIRED, not optional

```sh
uhubctl -l <hub-location> -a on
```

Must run **at boot** and **at the top of the 00:30 remount path**, before any mount is
attempted. Script lives in `/opt/proxmox-grsrv03/` (thematic subdir, symlink from
`/usr/local/sbin` if a path entry is wanted — never place it there directly).

**Why this is not a nice-to-have.** The comparison doc
([2026-08-19_gr-srv03_usb-hub-comparison.md](2026-08-19_gr-srv03_usb-hub-comparison.md),
§ *The outage question, retired*) **retired the power-on-default purchase criterion on the
grounds that this assertion would exist.** Without it that reasoning is unbacked and the
RSH-A10's MCU/mechanical behaviour after an outage becomes load-bearing again. The failure
it prevents is quiet: an outage landing between the 15:00 unmount and the physical swap
leaves a port switched off, and the resulting "drive missing" is indistinguishable from the
normal offsite-rotation state — so it surfaces as *backups stopped* days later.

Record the `uhubctl` port numbers in the comparison doc during install; the A10's ports are
unnumbered and its LEDs are hard to see, so label them physically at the same time.

### 2. Take a Zigbee LQI baseline BEFORE touching anything

Under Option D the dongle does not move — but the RF environment around it does: a new hub,
its brick, and more USB3 cabling appear in the same enclosure. The verify list below covers
throughput and RTL reception; without a fresh coordinator baseline a post-rebuild LQI change
cannot be told apart from the drift already being tracked in
[2026-08-24_docker03_zigbee-coordinator-rf-degradation.md](2026-08-24_docker03_zigbee-coordinator-rf-degradation.md)
(recheck due 2026-09-09, i.e. resolved well before the hub lands ~10-24).

Capture fleet LQI the same way as the existing baselines in [data/](data/), on the day of
the rebuild, and compare after. Same method, or the comparison is worthless.

### 3. Cable allocation

Sonoff's own extension → Zigbee; CAL2S → RTL-433. See the allocation rule under
[Extension cables](#extension-cables-needed-under-every-option).

## Verify after install

1. Throughput: re-measure HDD writes against the direct-connection baseline in
   [memory_gr-srv03_usb-hub-eval.md](memory_gr-srv03_usb-hub-eval.md). The old hub cost
   **40%** on writes.
2. Transient isolation: hot-plug a drive and confirm no `cp210x` events —
   `journalctl -k --since '10 min ago' | grep -E 'cp210x|Spinning up|error -71'`.
3. With both HDDs connected, confirm a simultaneous spin-up (both mount units started
   together) produces no undervoltage or enumeration errors.
4. RTL reception (test-only, so this gates experiments, not production): compare what the
   SDR hears on the hub against a direct-port capture on the same day. A quiet loss of
   distant sensors is the signature of RFI from the storage side, or of the CAL2S's unknown
   shield quality. Remedies in order, cheapest first: route the extension away from the
   drive cables and use a hub port far from the drives; try a known-good shielded cable;
   only then buy ferrites (HDD cables first — the source — then the SDR extension, 2–3
   turns each). If a specific test needs full sensitivity, run it on raspberrypi2z or
   borrow port 3 for the duration.
5. Zigbee: it never leaves its direct host port, so confirm it still enumerates and that
   zigbee2mqtt is up — then **re-measure fleet LQI against the same-day baseline from
   step 2 of the implementation list above**. A drop points at the new hub, its brick, or
   the added cabling as a 2.4 GHz source; the remedy is separation (move the hub and its
   cabling away from the dongle, lengthen the Zigbee extension), not a layout change.
   There is no `uhubctl` escalation for the dongle under Option D — the recovery
   watchdog's last resort stays a host reboot.
6. `uhubctl` power-cycles the **RTL's** port cleanly (its one PPPS benefit under this
   layout), and the boot/00:30 `-a on` assertion actually runs — reboot once and confirm
   the ports come up powered and both mount units succeed.
