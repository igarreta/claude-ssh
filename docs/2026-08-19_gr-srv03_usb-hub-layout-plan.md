# gr-srv03 USB layout plan — powered hubs for storage + dongles (2026-08-19)

**Status:** PLANNED, nothing purchased or moved yet. Storage hub decided
(Rosonway RSH-A10), extension cables and ferrites decided (Conable CAL2S-6-3PK +
13 mm wire-wound clip-ons);
**port 3 layout undecided — three options below.** Current setup is the
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

Planned additions: a **second HDD** (permanently connected, alongside the rotating
backup drive) and the **RTL-433 SDR** (disconnected since 2026-08-17 when the old hub
was pulled). That makes **5 devices for 3 ports** — a hub is mandatory.

> **Do not trust `connect_type` / `peer` in sysfs on this board.** It reports
> `usb1-port1` and `usb1-port2` as separate hotplug sockets with no USB3 peer, and
> shows `usb1-port6`/`usb2-port2` as one socket with a different device on each.
> Neither matches the physical 3-port reality. Count sockets at the chassis.

## Option A — two hubs, 10 Gbps dongle hub (original plan)

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

## Option B — two hubs, USB 2.0 dongle hub

Same layout as Option A, but port 3 gets the **$7 Sabrent HB-MCRM** (USB 2.0,
bus-powered) instead of a 10 Gbps hub. Removes the SuperSpeed RFI source next to the
SDR and costs half as much; gives up PPPS and the aux 5 V input, and reintroduces
Terminus `1a40:0101` silicon — the same part as the hub pulled on 08-17, though the
root-cause work exonerates it for a dongle-only load. Reasoning in the dongle-hub
section of
[2026-08-19_gr-srv03_usb-hub-comparison.md](2026-08-19_gr-srv03_usb-hub-comparison.md).

## Option C — no second hub (added 2026-08-19)

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

Two extensions are required regardless of which layout option is taken:

- **RTL-433** — away from the chassis and the storage cabling. Mandatory in all three
  options.
- **Zigbee dongle** — off the RSH-A10 and the chassis (Option C), or off the dongle
  hub (Options A/B, where slim inline hubs have a port pitch too tight for two wide
  dongles side by side).

Check the Sonoff box first; the Dongle Plus V2 often ships with a short extension.

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

### Ferrites — decided 2026-08-19

> **13 mm ID clip-on, wire-wound type, 10 pcs.** Bought alongside the cables so the
> mitigation is on hand when the rebuild is verified, not a second shipping wait.

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
watches for it, the ferrites above are the first remedy, and a known-good shielded
cable is $8 if the cheap one proves to be the problem.

A bad extension cable was the kernel's first suspicion during the 2026-07-15 episode.
The failure mode presents as intermittent re-enumeration or quietly missing sensors,
not as an obvious cable fault — so if either dongle misbehaves after the rebuild,
swap the cable early rather than late.

## Alternatives rejected

- **Both dongles direct, drives on a hub** — does not fit. 3 ports minus the hub minus
  the XS1000 leaves one port for two dongles.
- **Zigbee direct, RTL on the storage hub** — the inverse of Option C, and worse:
  it puts the RF-sensitive one-way receiver next to the drives and denies PPPS to the
  device that has actually needed a power-cycle. Viable fallback, but accepts a certain
  RFI penalty on the SDR to avoid a risk that is now largely engineered out. If chosen,
  mitigate with a shielded extension putting the dongle well away from the drives.
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
> Not yet purchased.

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
- Chipset: VL817 / GL3510-class USB 3.2. **Not** Terminus-class.

**Dongle hub**
- USB2 is sufficient (Zigbee is full-speed, RTL needs 480 Mbps high-speed).
- Powered preferred but not essential at ~400 mA total.
- Still not the cheapest part available.

## No config changes needed

- Both mount units are `What=UUID=...` (`/etc/systemd/system/mnt-backup_[ab].mount`),
  so the drives mount identically behind a hub.
- VM 102's Zigbee passthrough is ID-based (`usb2: host=10c4:ea60`) and follows the
  dongle to any port. Path-based entries were removed 2026-08-18 — do not reintroduce
  them, they are an auto-capture trap when hub topology changes.

## Verify after install

1. Throughput: re-measure HDD writes against the direct-connection baseline in
   [memory_gr-srv03_usb-hub-eval.md](memory_gr-srv03_usb-hub-eval.md). The old hub cost
   **40%** on writes.
2. Transient isolation: hot-plug a drive and confirm no `cp210x` events —
   `journalctl -k --since '10 min ago' | grep -E 'cp210x|Spinning up|error -71'`.
3. With both HDDs connected, confirm a simultaneous spin-up (both mount units started
   together) produces no undervoltage or enumeration errors.
4. RTL reception: compare sensor coverage against the pre-move baseline; a quiet loss
   of distant sensors is the signature of RFI from the storage side — or of the
   CAL2S's unknown shield quality. Before re-planning the layout: fit ferrites to the
   HDD cables first (source side), then to the SDR extension, 2–3 turns each; then try
   a known-good shielded cable.
5. If Option C is taken, confirm `uhubctl` can power-cycle the Zigbee port and that
   zigbee2mqtt recovers from it, so the watchdog has a verified escalation step.
