# raspberrypi2z: rtl_433 setup (2026-06-26)

## Overview

rtl_433 v25.02 installed on raspberrypi2z (Pi Zero W) to receive 433 MHz temperature/humidity sensor readings and forward them to MQTT.

Hardware: RTL-SDR dongle with Rafael Micro R820T tuner.

## Installation

```bash
sudo apt install rtl-433
```

Config directory created by the package at `/etc/rtl_433/`.

## Configuration

**`/etc/rtl_433/rtl_433.conf`:**

```
frequency   433.92M
sample_rate 250k
protocol    19
convert     si
report_meta time:iso:tz

# Output to Mosquitto broker on LAN. Topic template:
#   rtl_433/<model>/<id>/<channel>/<field>
output mqtt://192.168.1.8:1883,retain=0,devices=rtl_433/test[/model][/id][/channel]
```

- **Protocol 19**: Nexus / FreeTec NC-7345 / NX-3980 / Solight TE82S / TFA 30.3209 temperature+humidity sensor — the sensors in use at this installation.
- **MQTT broker**: `192.168.1.8:1883` (LAN IP, no auth, no retain).
- **Topic prefix**: `rtl_433/test` — set during testing. **Needs to be changed to a production prefix** (e.g. `rtl_433`) when confirmed working end-to-end.

## Systemd service

**`/etc/systemd/system/rtl433.service`:**

```ini
[Unit]
Description=rtl_433 RF receiver to MQTT
After=network-online.target
Wants=network-online.target

[Service]
User=rsi
ExecStart=/usr/bin/rtl_433 -c /etc/rtl_433/rtl_433.conf
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enabled and running. Note: service name is `rtl433` (no underscore), binary is `rtl_433`.

### Normal startup log noise

On each start, `[R82XX] PLL not locked!` appears — this is a known benign RTL-SDR startup message, not an error.

## Watchdog

The BCM2835 hardware watchdog (`/dev/watchdog0`) is present on the Pi Zero W and **auto-detected by systemd** at boot via `/usr/lib/systemd/system.conf.d/40-rpi-enable-watchdog.conf` (`RuntimeWatchdogSec=1m`):

```
systemd[1]: Using hardware watchdog 'Broadcom BCM2835 Watchdog timer', version 0, device /dev/watchdog0
systemd[1]: Watchdog running with a hardware timeout of 1min.
```

**Limitation**: this watchdog only resets the board if systemd itself stops petting it (kernel panic / systemd freeze). A Wi-Fi driver freeze leaves systemd running, so the board stays hung indefinitely.

**Key difference from raspberrypi1**: raspberrypi1 has `RuntimeWatchdogSec=10s` explicitly set; raspberrypi2z relies on the RPi default drop-in at 60s.

## Network watchdog

Added 2026-06-26 after a Wi-Fi freeze hang (see `docs/2026-06-26_raspberrypi2z_wifi-watchdog.md`).

The BCM43430 Wi-Fi firmware (version 7.45.98, July 2021 — latest available from Cypress/Infineon) is known to freeze intermittently, making the board unreachable while systemd keeps the hardware watchdog alive.

**Timer**: `net-watchdog.timer` — runs every 5 minutes, pings 192.168.1.1 (router).

Recovery sequence:
- **Fail 1**: restart Wi-Fi via `nmcli radio wifi off/on`
- **Fail 2**: `systemctl reboot`

Source files: `raspberrypi2z/net-watchdog/` in this repo.  
Logs: `journalctl -t net-watchdog`

## Persistent journal

Added 2026-06-26. Journal survives reboots for post-hang diagnosis.

Config: `/etc/systemd/journald.conf.d/persistent.conf` → `Storage=persistent`  
Source: `raspberrypi2z/journald/persistent.conf` in this repo.  
After any future hang: `journalctl -b -1 | grep -i brcm`

## Hardware note

RTL-SDR dongle connected directly to the Pi Zero W USB port (no powered hub). Ran stable for 12+ hours, so direct connection appears sufficient. Power supply is 2.5A — ruled out as cause of observed hangs.

## Pending

- Change MQTT topic prefix from `rtl_433/test` to production prefix once end-to-end flow is validated.
- Verify sensor readings are arriving at homeassistant/MQTT consumer.
- **Oregon-THGR122N not forwarded to MQTT**: config has `protocol 19` (Nexus only). Oregon sensor IS received by the hardware (confirmed in manual run output) but filtered out. Need to find the Oregon-THGR122N protocol number and add it to the config. Protocol number lookup: `rtl_433 -R help 2>&1 | grep -i oregon` — safe to run while service is active (never opens hardware). Suspect protocol 86 (Oregon Scientific V3) but needs verification.
- **Verify humidity and time fields are published**: with `devices=` format, rtl_433 publishes all decoded fields as subtopics (e.g. `.../humidity`, `.../time`). Config already has `report_meta time:iso:tz`. Check actual MQTT output before adding anything — fields may already be there.
