# raspberrypi2z: Oregon-THGR122N outage 2026-07-01/02

**Status:** closed
**Host:** raspberrypi2z
**Supersedes:** —
**Superseded-by:** —

## Symptom
Oregon-THGR122N (exterior Granaderos, channel=1, id=161) stopped publishing to
`rtl_433/raspberrypi2z/events` around Jul 1 15:00. Other sensors (Nexus-TH ×3)
kept working normally. The Oregon sensor's own base station kept receiving it fine,
ruling out a dead sensor battery/transmitter.

## Diagnosis
- `rtl433.service` never crashed/restarted — ruled out software/service fault.
- MQTT pipeline confirmed healthy via live `mosquitto_sub` on docker03 (Nexus-TH
  flowing normally); zero Oregon-THGR122N messages over several minutes.
- No system anomalies in the Pi's journal at the time (net-watchdog checks passed,
  no reboots/USB resets).
- Journal showed sporadic garbled `WARNING: Undeclared field "power1_W"...
  [12] "Oregon Scientific Weather Sensor"` — a spurious/partial protocol-12 sync,
  not a clean THGR122N decode. Indicated marginal RF signal reaching the dongle,
  not total silence.

Conclusion: RF reception issue isolated to this one sensor (weakest/most distant
link), not a raspberrypi2z software or MQTT problem.

## Fix
1. Set explicit manual gain in `/etc/rtl_433/rtl_433.conf` (was `auto`):
   ```
   gain        49.6
   ```
   Repo copy: `raspberrypi2z/rtl433/rtl_433.conf`. Deployed via
   `sudo cp /tmp/rtl_433.conf /etc/rtl_433/rtl_433.conf && sudo systemctl restart rtl433`
   (sudo needs password on this Pi — user ran it directly).
2. User also repositioned the RTL-SDR antenna to a better spot.

Combination of both fixed it — confirmed Oregon-THGR122N publishing again
(`temperature_C: 8.0`, `humidity: 14`) within minutes of the restart.

## Follow-up
Readings show `battery_ok: 0` — sensor battery is low and should be replaced,
or the sensor may drop out again independent of the RF fix.
