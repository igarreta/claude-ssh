# raspberrypi1 — WiFi Watchdog Setup and Incident Log

## Overview

The wifi-watchdog is a bash script that monitors network connectivity on raspberrypi1
and attempts progressive recovery before rebooting.

**Script:** `/home/rsi/wifi-watchdog/wifi-watchdog.sh`
**Log:** `/home/rsi/wifi-watchdog/log/wifi-watchdog.log`

## How It Works

Runs every 2 minutes via root's crontab. Pings the gateway (192.168.1.1) and escalates:

| Failure count | ~Elapsed | Action |
|---|---|---|
| 5 | ~10 min | `nmcli connection down/up` on the active WiFi connection |
| 8 | ~16 min | `systemctl restart NetworkManager` |
| ≥ FC (default 10) | ~20 min | `reboot` |

The reboot threshold (FC) is stored in `/var/lib/wifi-watchdog/reboot_threshold` and triples
after each reboot (capped at 720) to avoid reboot loops. It decrements back to 10 one step
per successful check cycle.

Skips the first 2 hours after boot to allow NFS/NetworkManager to settle.

## Cron Entry (root's crontab)

```
*/2 * * * * flock -n /run/wifi-watchdog/lock /home/rsi/wifi-watchdog/wifi-watchdog.sh >> /home/rsi/wifi-watchdog/log/wifi-watchdog.log 2>&1
```

## Runtime Directories

| Path | Type | Purpose |
|---|---|---|
| `/run/wifi-watchdog/` | tmpfs (cleared on reboot) | Lock file, transient state (fail count, timestamps) |
| `/var/lib/wifi-watchdog/` | persistent | Reboot threshold (FC) |

## Known Issue: tmpfs Lock Directory

`/run/wifi-watchdog/` lives on tmpfs and is wiped on every reboot. The cron command
runs `flock` before the script, so the script's internal `mkdir -p` is too late.

**Fix (applied 2026-04-03):** Created `/etc/tmpfiles.d/wifi-watchdog.conf`:

```
d /run/wifi-watchdog 0755 root root -
```

This causes systemd to recreate the directory on every boot via `systemd-tmpfiles`.

Applied with:
```bash
echo 'd /run/wifi-watchdog 0755 root root -' > /etc/tmpfiles.d/wifi-watchdog.conf
systemd-tmpfiles --create /etc/tmpfiles.d/wifi-watchdog.conf
```

## Incident: 2026-03-30 — 9-Hour Network Outage

### What happened

At **05:25:25**, the ethernet link dropped (`lan78xx eth0: Link is Down`). Simultaneously,
wlan0 was disconnected by wpa_supplicant. NetworkManager failed to reactivate either
interface and the Pi remained unreachable until manually rebooted at **14:17** (~9 hours).

### Root cause

Both eth0 and wlan0 lost connectivity at the same moment, likely due to a brief
router/switch hiccup that left NetworkManager in an unrecoverable state.

### Why the watchdog didn't help

The tmpfiles issue above meant `/run/wifi-watchdog/` didn't exist. Every cron invocation
failed with:
```
flock: cannot open lock file /run/wifi-watchdog/lock: No such file or directory
```
The watchdog had been silently doing nothing since the previous reboot.

### Fix applied

See "Known Issue" section above.
