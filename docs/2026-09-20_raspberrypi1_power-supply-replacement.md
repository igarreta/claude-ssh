# raspberrypi1 — Power supply replacement

**Status:** closed
**Host:** raspberrypi1
**Supersedes:** —
**Superseded-by:** —

## Background
`vcgencmd get_throttled` showed `0xd0000` (sticky under-voltage-occurred, throttling-occurred,
soft-temp-limit-occurred bits) before the swap — evidence of past under-voltage events, likely
from a weak/undersized micro-USB supply or a thin cable. Pi is a Raspberry Pi 3 Model B Plus
Rev 1.3, used for home heating control (TTato).

Recommended replacement spec: 5.1V, 3A (headroom over the 2.5A minimum), regulated under load,
short/thick micro-USB cable — e.g. official Raspberry Pi 3B+ PSU or CanaKit 5V/2.5A+.

## 2026-09-20: PSU physically replaced
Checked immediately after: boot time `2026-09-20 15:24:55`, `vcgencmd get_throttled` → `0x0`
(clean, no sticky flags at all), `dmesg` has zero volt/throttle matches since boot.

## Verify later
No under-voltage/throttling events should reappear over the following days/weeks of normal
heating-control load. Re-check with:
```
vcgencmd get_throttled   # expect 0x0
dmesg | grep -i 'volt\|throttl'
```
If `0xd0000`-style sticky bits return, the new PSU/cable is not sufficient and the cause is
elsewhere (e.g. cable run, connector).

## 2026-09-26: confirmed resolved
6 days after the swap, `vcgencmd get_throttled` → `0x0`, no volt/throttle lines in `dmesg`,
uptime continuous since the post-swap boot (no reboots/freezes). New PSU fixed the under-voltage
issue.
