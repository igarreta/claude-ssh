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
