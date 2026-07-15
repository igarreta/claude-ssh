# Memory: docker03 zigbee2mqtt outage and hardening (2026-07-15)

**Status:** resolved, hardening applied.

## What happened
zigbee2mqtt container on docker03 was found exited (code 2), down since
2026-07-15 09:23 UTC (~9h). The Sonoff Zigbee 3.0 USB Dongle Plus V2 (Ember/EZSP,
`cp210x` driver, direct root-hub port — not on a shared hub) briefly dropped off
USB and re-enumerated. zigbee2mqtt lost its serial port cleanly and exited.
Docker's `restart: always` then tried to recreate the container but failed with
`error gathering device information ... no such file or directory` on the
`/dev/serial/by-id/...` symlink (transiently absent mid-re-enumeration) — this
failure happens at container *start*, not as a running-process exit, so Docker's
restart policy did not retry further and left it stopped indefinitely.

## Root cause detail
`compose.yaml` mapped the dongle two ways: a by-id path → `/dev/ttyACM0` (stale,
left over from an earlier adapter type) and a raw `/dev/ttyUSB0:/dev/ttyUSB0`
(unstable, kernel-assigned name). zigbee2mqtt's actual `configuration.yaml`
(`serial.port: /dev/ttyUSB0`) only used the raw mapping — the by-id/ttyACM0 entry
was dead weight whose only effect was to make container recreation fail whenever
the by-id symlink was momentarily missing.

## Fix applied (`dockerfiles` repo, commit `71b4b87`)
Collapsed to a single device entry: by-id path → `/dev/ttyUSB0` in-container.
Gives the container path a stable host-side identity (survives ttyUSB/ttyACM
renumbering) and removes the dead mapping that was the actual failure trigger.

## Recovery watchdog (`bin` repo, commit `d4e14e2`)
`~/bin/zigbee2mqtt-watchdog.sh` on docker03, cron `*/5 * * * *`: checks
`docker inspect -f {{.State.Status}}` and `docker start`s the container if not
`running`. Logs to `~/log/zigbee2mqtt-watchdog.log`. Covers the specific Docker
gap above (restart-always not retrying after a failed start). User already has
a separate Pushover watchdog for alerting — this script only does recovery, no
notification.

## Notes for future incidents
- docker03 conventions: user cron + scripts in `~/bin` (a git repo,
  `igarreta/bin`), not systemd timers/units — no custom systemd units exist on
  this host.
- `~/dockerfiles` on docker03 is also a git repo (`igarreta/dockerfiles`).
  zigbee2mqtt's own `data/configuration.yaml`, `data/database.db`,
  `data/coordinator_backup.json` are rewritten by the app itself on every
  restart (comment stripping, new-device entries) — don't bundle those into
  unrelated commits; stage only the intended file.
- docker03 sudo requires a password (see
  [[feedback_docker03_sudo]]), so `dmesg` couldn't be read to confirm the
  exact kernel-level USB disconnect cause (autosuspend was already off —
  `power/control=on` — so likely a transient reset/glitch, not power
  management).
