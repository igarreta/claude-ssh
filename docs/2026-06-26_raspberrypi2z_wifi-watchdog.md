# raspberrypi2z: Wi-Fi hang diagnosis and network watchdog

## Incident (2026-06-26 ~10:02)

raspberrypi2z became unreachable at ~10:02. Required manual reboot. The BCM2835
hardware watchdog did not trigger.

## Root cause analysis

### Why the watchdog didn't trigger

`/usr/lib/systemd/system.conf.d/40-rpi-enable-watchdog.conf` configures
`RuntimeWatchdogSec=1m`. This only resets the board if systemd stops petting
the watchdog — i.e. a kernel panic or systemd freeze. A Wi-Fi driver hang
leaves systemd running normally, so the board never resets.

### Likely cause: brcmfmac Wi-Fi firmware freeze

The Pi Zero W uses the BCM43430 chip via the `brcmfmac` SDIO driver. The
firmware blob (`/lib/firmware/cypress/cyfmac43430-sdio.bin`) is version 7.45.98
dated **July 2021** — the latest available from Cypress/Infineon. This firmware
is known to freeze intermittently, leaving the CPU and systemd running but the
Wi-Fi interface dead.

Power supply (2.5A) rules out undervoltage as a cause.

## Fixes applied

### 1. Persistent journal

Enabled so pre-hang logs survive reboots for future diagnosis.

```
/etc/systemd/journald.conf.d/persistent.conf:
[Journal]
Storage=persistent
```

Journal directory: `/var/log/journal/`

After the next incident, check: `journalctl -b -1 | grep -i brcm`

### 2. Network watchdog (`net-watchdog`)

Script: `/usr/local/bin/net-watchdog.sh`  
Units: `/etc/systemd/system/net-watchdog.{service,timer}`  
Runs every 5 minutes, pings 192.168.1.1 (router).

Recovery sequence:
- **Fail 1**: restart Wi-Fi via `nmcli radio wifi off/on`, wait 5 min
- **Fail 2**: log and wait another 5 min (allows slow router resets to recover)
- **Fail 3**: `systemctl reboot`

Total window before reboot: ~10 minutes.

Enable status: `systemctl list-timers net-watchdog.timer`  
Logs: `journalctl -t net-watchdog`
