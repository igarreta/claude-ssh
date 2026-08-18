# Memory: gr-srv03 powered USB hub instability (2026-07-15)

**Status:** unresolved, needs further investigation.

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

## Conclusion

The hub is not safe for anything now — not just spinning HDDs, but also the low-power
dongles previously assumed safe.

**Action needed (still open):** move the Zigbee dongle (and RTL-433, per the existing
plan in CLAUDE.md to move it to cygnus) off this hub onto a direct host port or a
different hub, not just the backup drives.
