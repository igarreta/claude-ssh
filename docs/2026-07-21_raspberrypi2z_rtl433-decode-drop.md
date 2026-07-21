# raspberrypi2z: rtl_433 dropped to 1 sensor, fixed by reboot; daily restart added

## Symptom
2026-07-20: raspberrypi2z was publishing only 1 of 3 rtl_433 sensors (protocol 19,
Nexus/TFA) all day. A manual reboot at ~22:00 (actual reboot 21:39) restored all 3
sensors.

## Investigation (2026-07-21)
Checked the prior boot (2026-07-13 05:36 → 2026-07-20 21:38, ~1 week uptime):
- `rtl433.service`: ran continuously, no crashes or restarts.
- USB (kernel log): no disconnects/re-enumerations of the RTL-SDR dongle.
- Power: `vcgencmd get_throttled` clean, no undervoltage/throttling in dmesg.

No pi/service/USB-side fault found. Conclusion: likely RTL-SDR tuner/PLL frequency
drift over long uptime (common on cheap RTL2832U dongles, worsens with
temperature/time), degrading decode of weaker sensor signals. The tuner is
re-initialized whenever the `rtl_433` process starts, so a full OS reboot isn't
required — restarting the service should be sufficient (not yet isolated/confirmed
independently of the reboot).

## Fix
Added `/etc/cron.d/rtl433-restart` (root, 644) to restart `rtl433.service` daily:
```
3 1 * * * root systemctl restart rtl433.service
```
Deployed 2026-07-21 (file written locally, scp'd to `/tmp/`, installed by user via
sudo per raspberrypi2z's password-required sudo — see
[[feedback_raspberrypi2z_sudo]]). Verified in place, `cron.service` active.

## Follow-up
If the drop recurs despite the daily restart, next step is to confirm restart
(vs. reboot) is really sufficient by testing `systemctl restart rtl433.service`
alone, and consider a shorter interval or a PPM correction (`-p` option) if drift
is confirmed as root cause.
