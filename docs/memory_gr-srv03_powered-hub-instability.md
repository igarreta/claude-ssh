# Memory: gr-srv03 powered USB hub instability (2026-07-15)

**Status:** ROOT-CAUSED 2026-08-18 and mitigated 2026-08-17 by removing the hub.
**The "degrading hub" theory below is superseded — see "Actual root cause" at the
end.** History kept for context.

## What happened
Investigated "BACKUP_A not recognized" — turned out to be expected: BACKUP_A and
BACKUP_B are never both connected, one is always stored offsite (see CLAUDE.md).
BACKUP_A was simply the offsite one that day, not a fault.

While investigating, found a real problem: dmesg on gr-srv03 showed `usb2-port3`
failing to enumerate continuously for 24h+ (`Cannot enable. Maybe the USB cable is
bad?`, 9000+ retries). This port is on the powered USB hub shared with the RTL-433
dongle and the Zigbee dongle.

Testing steps and results:
1. Physically disconnect/reconnect the drive on that hub port — no change, same
   failure loop resumed immediately.
2. Move the drive to the hub port previously used by the RTL dongle — still unstable:
   device (identified as BACKUP_B, Toshiba Canvio Basics, `0480:a202`) rapidly
   connected/disconnected and bounced between different bus/port paths
   (`2-3` then `1-1.1`).
3. Connect BACKUP_B directly to a free port on the gr-srv03 server (bypassing the
   powered hub entirely) — worked immediately, clean enumeration, auto-mounted via
   `mnt-backup_b.mount` at `/mnt/backup_b` (`sdc1`, 1.2T avail).

## Diagnosis
Fault isolated to the powered hub (or a specific port/cable on it), not the drives —
same drive failed on the hub, worked fine direct. The hub tested fine on 2026-07-12
(see [[project_gr-srv03_usb-hub-eval]]) — BACKUP_A mounted through it successfully,
just with degraded write throughput (−40%). Something degraded further between
2026-07-12 and 2026-07-15 to go from "slow" to "won't enumerate at all."

RTL dongle and Zigbee dongle (both USB2, low current) still work fine on this hub —
so it's not a total hub failure. Leading hypothesis: marginal/degrading power
delivery on that hub or port, exposed by a spinning HDD's higher current draw
(especially at spin-up), which the low-power dongles never stress.

## Next steps (not yet done)
- Power-cycle the hub itself (unplug its own power brick, not just the device) and
  retest a drive on it — distinguishes a transient firmware lockup from a genuine
  hardware/power fault.
- If it still fails after a power cycle, test the hub's other ports individually.
- Until resolved, keep BACKUP_A/BACKUP_B connected directly to the gr-srv03 server
  rather than through this powered hub.

## Update 2026-08-17: hub now drops the Zigbee dongle too (revised 2026-08-18)

Previous note (07-15) said the RTL/Zigbee dongles "still work fine on this hub" — no
longer true. The hub has degraded further.

Host kernel log (`journalctl -k`) 19:34–20:45 on 2026-08-17 shows the hub at `1-1`
(the `1a40:0101` USB2.0 hub chip on `usb1-port1`) repeatedly cycling: `clear tt 1
error -71`, `disabled by hub (EMI?), re-enabling`, disconnect/reconnect of the
Sonoff Zigbee 3.0 Dongle Plus V2 (`10c4:ea60`, port `1-1.3`) every few minutes,
escalating at 20:45 to the hub itself failing enumeration (`device descriptor
read/64, error -71`, `Device not responding to setup address`, `attempt power
cycle`).

**Blast radius: one container.** The dongle is passed through to docker03 (VM 102,
`usb2: host=10c4:ea60`), where it appears as `usb 2-3`. Each host-side drop surfaced
in the guest as a `cp210x` disconnect and Docker restarted the zigbee2mqtt container
under its `restart: always` policy — **5 restarts** between 17:00 and 20:53,
recovering every time.

### Correction to the original 08-17 write-up

That write-up said this hub "froze docker03" via the passthrough. **It did not.**
docker03 was healthy and logging continuously throughout; the apparent VM freeze was
an unrelated, coincident Tailscale node-key expiry at 17:27, two hours before the USB
storm began. The "silent journal" that suggested a freeze was an artifact of reading
it unprivileged.

Full analysis, including the container-DNS coupling and the fleet-wide key-expiry
fix, is in
[2026-08-17_docker03_tailscale-key-expiry-and-container-dns.md](2026-08-17_docker03_tailscale-key-expiry-and-container-dns.md).

So: no VM-freeze escalation to attribute to this hub. What the hub *does* do is knock
the Zigbee dongle offline every few minutes, which is bad enough on its own.

## Resolution 2026-08-17 21:11 — hub eliminated

The hub was removed from the setup: RTL-433 disconnected, Zigbee dongle moved to a
**direct root-hub port** on gr-srv03. Host kernel log:

```
21:11:36 usb 1-1: USB disconnect, device number 42        <- hub removed
21:11:44 usb 1-1: Sonoff Zigbee 3.0 USB Dongle Plus V2    <- now direct on root hub
21:11:44 cp210x 1-1:1.0: cp210x converter detected
```

**Verified 2026-08-18 (~12 h later):**

| | during the storm | after the move |
|---|---|---|
| USB kernel events | every 2-6 min | **zero in ~12 h** |
| `error -71` / `disabled by hub` | 16 in 24 h (all pre-21:11) | **0** |

`lsusb -t` no longer shows the `1a40:0101` hub chip at all. The dongle sits directly
on the bus-1 root hub under `usbfs` (claimed by QEMU for VM 102), and zigbee2mqtt is
passing live Zigbee traffic with a stable `/dev/serial/by-id/` node.

Do not reuse this hub. Keep BACKUP_A/BACKUP_B and any dongles on direct ports.

### Passthrough config survived the move — because it is ID-based

`qm config 102` has `usb2: host=10c4:ea60`. Being **vendor:product based rather than
bus-path based**, it followed the dongle to its new physical port with no config
change and no VM restart. Prefer this style for passthrough of a single unique
device; bus-path entries break whenever the topology changes.

### Leftover cruft — cleaned 2026-08-18

VM 102 carried three **phantom** path-based passthroughs pointing at the
now-departed hub's subports:

```
usb0: host=1-1.1
usb1: host=1-1.4
usb3: host=1-3.1
```

Nothing has enumerated at any of those paths since at least 2026-08-01, so they were
already dead before the hub was pulled. QEMU shows them as empty "USB Host Device"
slots (`qm monitor 102` -> `info usb`). They are harmless today but are a **latent
auto-capture trap**: plug a hub into bus-1 port 1 or port 3 later and QEMU will
silently pull whatever appears at those subpaths into docker03.

**Removed 2026-08-18** with `qm set 102 --delete usb0,usb1,usb3`. It applied
**live** — no reboot and no pending change; QEMU's `info usb` immediately dropped
the three empty slots, leaving only the tablet and `usb2`. Zigbee was undisturbed:
container not restarted, `/dev/serial/by-id/` symlink timestamp unchanged (so the
dongle never re-enumerated), traffic continuous. Prior config backed up to
`/root/102.conf.bak-20260818-091255` on gr-srv03.

Unrelated but noted: VM 100 (`debian-gui`, stopped and unused) holds
`usb0: host=0bda:c821`, the Realtek Bluetooth radio. No conflict while it stays
stopped.


## Actual root cause (2026-08-18): backup-drive hot-plug transients, not hub decay

User hypothesis — "the episodes coincide with unplugging/replugging BACKUP_A/_B, but
those disks were on a *different* USB port, the hub had only the Zigbee dongle" —
**confirmed against the logs, 7 of 7 episodes.**

### The correlation

Every Zigbee (`cp210x`) disconnect episode in 37 days of journal coincides with a
backup-drive plug or unplug on bus 2:

| dongle drop | drive event |
|---|---|
| 07-15 06:15–06:23 | `2-3` enumeration-failure loop, Toshiba attached 06:23 |
| 07-20 18:22 | **`2-1` USB disconnect** 18:22 |
| 07-21 18:11–18:15 | WD Elements attached, `[sdc] Spinning up disk...` 18:11 |
| 08-03 19:37 | **`2-1` USB disconnect** 19:37 |
| 08-04 19:39 | Toshiba attached 19:39 |
| 08-11 19:07–19:08 | WD Elements attached, `Spinning up disk...` 19:08 |
| 08-17 19:34 | **`2-1` USB disconnect 19:34:29 — storm began 19:34:33, 4 s later** |

The unplug→replug pairs are the weekly offsite rotation: 07-20→07-21, 08-03→08-04,
08-10→08-11, 08-17→(still out). The apparent "evening EMI" clustering was simply
when the swap is done.

**One negative case:** the 08-10 18:23 unplug caused no dongle drop. The coupling is
probabilistic — it depends on transient severity and timing — not deterministic.

### The mechanism: shared controller and VBUS rail, not a shared port

```
Intel Alder Lake-N PCH USB 3.2 xHCI [8086:54ed] @ 00:14.0   <- ONE controller
  ├─ Bus 001 (USB2 root)  port 1 ── powered hub 1a40:0101 ── Zigbee dongle
  └─ Bus 002 (USB3 root)  port 1 ── BACKUP_A/B
```

The ports really were different physical sockets — `usb1-port1` has **no USB3 peer**
(it is a USB2-only socket), while the drive's `usb2-port1` peers with `usb1-port5`.
Confirmed via `/sys/bus/usb/devices/usb*/…/usb*-port*/peer`.

But both sit on the same xHCI silicon and, on a NucBox-class mini PC, the same shared
5 V VBUS supply for the external sockets. A bus-powered 2.5" HDD pulls a large inrush
transient on plug-in (capacitor charge + motor spin-up — hence the `Spinning up
disk...` lines) and a similar transient on removal. That momentarily sags the shared
rail. The PCH root ports tolerate it; the cheap Terminus `1a40:0101` hub — minimal
decoupling, no local regulation — browns out, its controller glitches, and the kernel
reports what it observed: `disabled by hub (EMI?)` and `error -71` downstream.

### Why this supersedes the earlier theory

The 07-15 note assumed marginal hub power exposed by HDD current draw *through the
hub*, and the 08-17 note assumed progressive decay. Neither holds:

- The hub was **not** carrying the drives during these episodes — only the dongle.
- There was **no** decline from "slow" to "won't enumerate". There were discrete
  trigger events roughly weekly, all along.
- 08-17 looked catastrophic only because the drive was unplugged and, uniquely,
  **never plugged back in** — so the hub kept cycling instead of settling after the
  usual 1–4 minutes.

### Evidence the fix will hold — and why it is still unproven

Across all 37 days and all 7 swap events, **no root-hub-attached device was ever
disturbed**: the Bluetooth adapter (`usb1-port4`) and USB audio (`usb1-port6`) never
glitched, and bus-1 root-hub port errors total **0**. Only the downstream hub was
susceptible, which is why moving the dongle to a direct root-hub port should hold.

**But it has not yet been tested against the real trigger.** The drive was unplugged
2026-08-17 19:34 and has not been reconnected, so the hub was removed during a period
with no swap. The ~12 h of silence proves nothing about the failure mode.

**Test to run:** at the next BACKUP_A/_B reconnection, check for `cp210x` disconnects
within ~10 s of the drive attaching:

```bash
journalctl -k --since '10 min ago' | grep -E 'cp210x|Spinning up|usb 2-1'
```

If the dongle rides through a plug/unplug cycle, the fix is confirmed. If it still
drops, the transient is reaching the root port too, and the next step is a
**self-powered** drive dock/enclosure rather than a bus-powered 2.5" HDD.

## FIX CONFIRMED 2026-08-19 — dongle rode through three hot-plug events

The test described above has now run for real. BACKUP_B (Toshiba Canvio Basics
`0480:a202`, serial `20170126021100F`) was reconnected on 2026-08-18 and cycled:

| time (2026-08-18) | event on bus 2 | effect on Zigbee dongle |
|---|---|---|
| 19:11:33 | `usb 2-1` attach, `[sdc]` spin-up | **none** |
| 19:47:13 | `usb 2-1` USB disconnect | **none** |
| 19:47:20 | `usb 2-1` re-attach, EXT4 recovery, mounted | **none** |

Counters since the hub was removed (2026-08-17 21:12 → 2026-08-19):

- `cp210x` / `error -71` / `disabled by hub` kernel events: **0**
- bus-1 root-port errors, resets, `attempt power cycle`: **0**
- `/dev/serial/by-id/usb-Itead_Sonoff_Zigbee_3...` symlink mtime on docker03:
  still **Aug 17 21:11** — the dongle has not re-enumerated once
- zigbee2mqtt container: `Up 24 hours`, **RestartCount 0**

Under the old topology every one of these plug/unplug events had a ~6-in-7 chance of
knocking the dongle offline; three in a row passed clean. **The root-cause analysis
holds and the fix is proven: only the downstream `1a40:0101` hub was susceptible to
the shared-rail transient, the PCH root ports are not.**

No further action on this issue. Standing rule: keep the Zigbee dongle and the backup
drives on **direct root-hub ports**; do not reintroduce that hub.

### Side note — the 19:47:13 removal was unclean

The drive was pulled while still mounted with dirty writes:

```
Buffer I/O error on dev sdc1, ... lost sync page write
JBD2: I/O error when updating journal superblock for sdc1-8.
sd 2:0:0:0: [sdc] Synchronize Cache(10) failed: ... DID_NO_CONNECT
```

The journal replayed cleanly on re-attach (`EXT4-fs (sdc1): recovery complete`) and
the filesystem is mounted r/w, so no lasting damage — but unsynced data at that
instant was lost. Unrelated to the USB fix. For the weekly offsite rotation, unmount
first (`umount /mnt/backup_b`, or stop the `mnt-backup_b.mount` unit) before pulling
the cable.
