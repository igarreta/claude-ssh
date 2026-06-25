# raspberrypi1 — Hardware/kernel watchdog enabled (2026-06-25)

## Why
Closes the "no auto-recovery" gap from the [Jun 17 2026 hard freeze](memory_raspberrypi1_freeze.md):
that incident had no panic, no OOM, nothing logged — a genuine kernel-level lockup that
required a manual power cycle and stayed down ~4 days. The existing `wifi-watchdog.sh`
(root cron, every 2 min) can't help with this class of failure since it depends on cron
itself running, which a true kernel hang prevents.

## What was enabled
The Pi's BCM2835 SoC has a built-in hardware watchdog timer (`bcm2835-wdt`), already loaded
by the kernel and exposed at `/dev/watchdog` / `/dev/watchdog0`, but unused before this
change. Enabled systemd's built-in support for it — no extra `watchdog` package needed.

`/etc/systemd/system.conf.d/watchdog.conf`:
```
[Manager]
RuntimeWatchdogSec=10s
WatchdogDevice=/dev/watchdog
```

PID 1 opens the device and pets it roughly every half of `RuntimeWatchdogSec`. The
hardware itself has a **fixed 15s max timeout** (Pi SoC limitation; `SETTIMEOUT` ioctl
capability isn't supported by this driver, confirmed via `wdctl`) — 10s leaves margin
under that ceiling. If PID 1 ever stops running (true kernel lockup), the SoC force-resets
the board independent of the CPU scheduler.

Applied live with `systemctl daemon-reexec` (no reboot needed). The watchdog re-arms
automatically on every future boot since the drop-in is on disk.

## Live test (confirmed working)
Stopping PID 1 with `kill -STOP 1` had **no effect** — the kernel exempts PID 1 from
`SIGSTOP`/`SIGTERM` default actions unless it installs a handler (systemd doesn't for
SIGSTOP), so this is not a viable way to test or otherwise defeat the watchdog.

Working test: temporarily removed the drop-in and ran `daemon-reexec` so systemd released
its exclusive hold on `/dev/watchdog0`, restored the drop-in file on disk immediately
(so the *next* boot re-arms it regardless of test outcome), then manually opened
`/dev/watchdog0` ourselves (opening arms the hardware timer) and let it sit without
petting it.

Result: the board hard-reset within ~15s, exactly mirroring the original incident's
"journal stops abruptly, no shutdown sequence" signature — except this time it rebooted
automatically within seconds instead of staying down for days. On the new boot,
`bcm2835-wdt` loaded normally and systemd re-armed `RuntimeWatchdogSec=10s` on its own.
All docker containers (`TTato` — heating control, `beszel-agent`, `portainer`,
`uptime-kuma`) came back up healthy within minutes.

## Verification commands
```bash
systemctl show -p RuntimeWatchdogUSec -p WatchdogDevice
sudo wdctl /dev/watchdog0   # state: active, Timeleft counting and resetting upward
```
