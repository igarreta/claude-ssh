# Memory: gr-srv03 powered USB hub instability (2026-07-15)

**Status:** RESOLVED 2026-08-17 by removing the hub from the setup entirely.
History kept below for context.

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
