# gr-srv03 USB layout plan — powered hubs for storage + dongles (2026-08-19)

**Status:** PLANNED, nothing purchased or moved yet. Current setup is the
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

## Planned layout

| port | connected | carries |
|---|---|---|
| 1 | **powered storage hub** (4–5 A, per-port switching) | BACKUP_A/B + new HDD |
| 2 | Kingston XS1000 | direct, dedicated |
| 3 | **small dongle hub** | Zigbee CP210x + RTL-433 |

Two clean domains: storage never shares a rail with the dongles.

## Rationale

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

## Alternatives rejected

- **Both dongles direct, drives on a hub** — does not fit. 3 ports minus the hub minus
  the XS1000 leaves one port for two dongles.
- **Zigbee direct, RTL on the storage hub** — viable fallback, but accepts a certain
  RFI penalty on the SDR to avoid a risk that is now largely engineered out. If chosen,
  mitigate with a shielded extension putting the dongle well away from the drives.
- **Everything except the SSD on one big powered hub** — recreates the exact
  drive/dongle adjacency that caused the incident, and the RFI problem regardless of
  power quality.
- **XS1000 on the storage hub** to free a port for a dongle — sacrifices the one
  device whose throughput is hub-limited.

## Purchase criteria

**Storage hub**
- Genuinely **self-powered** with its own **12 V / 4–5 A** brick, and no backfeed into
  the host port. This property is the entire basis of the layout — verify it.
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
   of distant sensors is the signature of RFI from the storage side.
