---
name: project_raspberrypi1_ttato_manual_heating
description: TTato Manual-mode heating turned on by phantom 0°C readings (stale sensor + HA unknown-state default); two bugs fixed 2026-08-01
metadata: 
  node_type: memory
  type: project
  originSessionId: a2d7a9d7-679e-42f3-8532-21cf4a348901
  modified: 2026-08-02T02:10:17.465Z
---

TTato's Manual-mode `CheckManual()` (`GlobalThreads.py`) forced the boiler
on twice on 2026-08-01 due to two separate phantom-0°C bugs, both now
fixed. Full narrative: docs/2026-08-01_raspberrypi1_ttato-manual-mode-phantom-zero-heating.md

**Why**: (1) `CheckManual` checked `"valid"` (a static config duration,
always truthy) instead of `"current"` (the real freshness flag), so a
stale sensor zeroed by `_clean_list` counted as a genuine cold reading.
(2) Even after fixing that, HA's `granev/temp/*` relay automation
defaults to a *fresh* `0` via `float(0)` when the source entity is
`unknown` (sensor.temperatura_hab_varones flickers unknown ~every 10
min — known flaky, unresolved, see [[project_raspberrypi1_ttato_granev]]),
which isn't "stale" so bug 1's fix didn't catch it.

**How to apply**: `CheckManual` now requires `current` AND `temp != 0.0`
(TTato commits `fb98f2b`, `254dfc9`). HA's `automations.yaml` publish
actions for `granev/temp/*` are now guarded with `if: state not in
[unknown,unavailable] / then: publish` so a flaky source sensor is skipped
rather than republished as a fake 0 (backup:
`/config/automations.yaml.bak-zero-guard` on homeassistant). Any
`docker restart TTato` drops Manual mode back to Automatic — re-apply
`changemode.json` after restarts. See also
[[project_raspberrypi1_ttato_mqtt_drop]].
