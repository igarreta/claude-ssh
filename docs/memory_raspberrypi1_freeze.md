# raspberrypi1 — Hard freeze / disconnect (Jun 17 2026)

## Incident
- **Disconnected:** Wed 2026-06-17, journal stops dead at **21:02:13** mid-operation.
  Tailscale marked it offline ~21:12 (controller offline-detection timeout).
- **Recovered:** Mon 2026-06-21 ~23:27 only after a **manual reboot**. Stayed down ~4 days.

## Diagnosis (persistent journald)
- Previous boot's journal ends abruptly at 21:02:13 — **no shutdown sequence, no kernel
  panic/oops, no hung-task/soft-lockup, no OOM, no SD/mmc or EXT4-fs I/O errors, no
  under-voltage.** Logging simply stops.
- **No boot between** the failed boot and the recovery boot → the Pi never restarted on
  its own. A power outage would auto-recover; this required a manual power cycle.
- Conclusion: **hard system freeze / kernel lockup**, severe enough that nothing could be
  written to disk (hence no panic logged). Not a power outage, not a clean shutdown.

## Key gotcha — clock on boot
Pi 3B+ has **no RTC**. After a boot the journal's early timestamps come from
`fake-hwclock` (restored from last save) and look wrong until NTP syncs. Always trust
`uptime` (monotonic) for the true boot time, not `journalctl --list-boots` first-entry
times. Example: current-boot logs read "Jun 17 20:17" but real boot was Jun 21 23:27.

## Side observation (not proven cause)
Docker container **`TTato`** (`de8a1016…`) was **crash-looping on the failed boot**:
`restartCount=831`, exitCode=1, restarting ~every 60s right up to the freeze. Stable since
the reboot (`Up 4 days`). A runaway restart loop is the kind of load that can precede a
lockup on a low-RAM Pi 3B+ — watch it.

## If it happens again — checklist
1. `uptime` for true boot time; `journalctl --list-boots` to find the failed boot index.
2. `journalctl -b -1 | tail -50` — check for clean shutdown vs abrupt stop.
3. Scan failed boot: `journalctl -b -1 | grep -iE "panic|oops|oom|hung task|soft lockup|mmc|EXT4-fs error|under-voltage"`.
4. `vcgencmd get_throttled` (0x0 = never under-volted/throttled) and `vcgencmd measure_temp`.
5. Check whether the Pi auto-rebooted (boot exists between failure and recovery) → power
   blip; if not → hard freeze needing manual power cycle.
6. Review crash-looping containers (`docker ps`, restart counts) as a possible stress source.

## Hardware
Raspberry Pi 3 Model B Plus Rev 1.3, kernel 6.12.87+rpt-rpi-v8. Used for home heating control.
Journald is persistent (`/var/log/journal`).
