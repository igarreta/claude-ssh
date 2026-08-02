# raspberrypi1 TTato: Manual-mode phantom-zero heating (2026-08-01)

## Problem
User asked why heating was on in Manual mode when only the exterior
temperature was below the set point — all currently-reporting interior
sensors were well above the 16°C mintemp. Two separate, unrelated bugs in
`CheckManual()` (`GlobalThreads.py`) turned out to cause this, found and
fixed in sequence during the same investigation.

## Bug 1: stale sensor counted as a real 0°C reading
`CheckManual()` filtered on `self._dictios[sensor]["valid"]`, but `"valid"`
is a static per-sensor validity-*duration* in seconds (config value, always
truthy) — not a freshness flag. The real freshness flag is `"current"`,
which `CheckManual()` never checked. When an interior sensor (`Digoo003`,
"hab chicos") went stale, the housekeeping thread `_clean_list` zeroed its
temp to `0.0` and set `current=False`, but `CheckManual()` still counted it
as a genuine 0°C interior reading — well below any mintemp — forcing the
boiler on. Confirmed against the log: `Digoo003` flagged
`Sensor Digoo003 sin datos.` at 21:00:32, Manual mode was (re-)enabled at
21:09:41, boiler turned ON at 21:10:01 while that sensor was still zeroed.

**Fix**: added `and self._dictios[sensor]["current"]` to the `CheckManual`
condition. Commit `fb98f2b` in `igarreta/TTato`, pushed.

### Side effect discovered
Restarting the `TTato` container to apply the code change always drops
Manual mode back to Automatic — `manual_end`/`manual_temp` are process
globals re-initialized to `datetime.datetime.today()` / `0` at startup
(`TTato.py:304,324`), so on the next loop tick `now > manual_end` is
immediately true and mode flips to `A`. Confirmed in log:
`Mode changed to: A.` right after each restart. Manual mode must be
re-applied (`www/changemode.json`) after any container restart.

## Bug 2: HA relay defaults to a fresh 0°C when the source sensor is unknown
After the Bug 1 fix and a fresh Manual-mode enable, the boiler turned on
again — same symptom, different cause. This time `hab_varo`
("habitacion varones", fed via HA from `granev/temp/hab_chicos`) reported
`0.0°C` as **current, non-stale** data, so the Bug-1 fix didn't catch it.

Root cause: HA automation `publicar_sensor_hab_prpal_en_mqtt`
(`/config/automations.yaml`, `time_pattern` every 5 min) builds each
`granev/temp/*` payload with `{{ states('sensor.X') | float(0) }}`. When
the source entity's state is `unknown` (confirmed: `sensor.
temperatura_hab_varones` flickers between a real value and `unknown` on a
~10 min cycle — the known flaky-sensor issue from
[[project_raspberrypi1_ttato_granev]], still unresolved and HA/hardware
side per the user), `float(0)` silently defaults to `0` and HA republishes
it as a fresh MQTT message every 5 minutes. `CheckManual()` has no
per-sensor fallback/reliability logic (unlike Automatic mode's rule groups,
which use priority-ordered fallback sensors), so any single flaky sensor
reporting a bogus fresh 0 can force the boiler on in Manual mode.

**Fix (both layers, per user's request)**:
- TTato: `CheckManual()` now also excludes `self._dictios[sensor]["temp"]
  != 0.0` — an interior sensor is never legitimately exactly 0°C; it's
  always either the `_clean_list` staleness placeholder or an HA
  default-value artifact. Commit `254dfc9` in `igarreta/TTato`, pushed.
- Home Assistant: all 4 `mqtt.publish` actions in
  `publicar_sensor_hab_prpal_en_mqtt` (`hab_prpal` id 1, `living` id 2,
  `hab_chicos` id 3, `exterior` id 4) wrapped in an `if`/`then` guard —
  `condition: template, value_template: "{{ states('sensor.X') not in
  ['unknown','unavailable'] }}"` — so the publish is skipped entirely
  instead of sending a fabricated 0. Backup at
  `/config/automations.yaml.bak-zero-guard`. Validated with `ha core
  check`, applied via `POST .../services/automation/reload`.

### Verification
Manually triggered `automation.publicar_sensor_hab_prpal_en_mqtt` (note:
entity_id slug is `..._en_mqtt`, not derived from the automation's `id:`
field `publicar_sensor_hab_prpal_mqtt`) while subscribed to
`granev/temp/#` on the broker: `hab_prpal`, `living`, `exterior` published
normally; `hab_chicos` was correctly skipped while `sensor.
temperatura_hab_varones` was `unknown` at that moment.

End-to-end: re-applied Manual mode at 16°C until 2026-08-01 23:00 after
both fixes; TTato correctly auto-reverted to Automatic at 23:00
(`now > manual_end`), with no further phantom-zero boiler activations
observed.

## Notes for future sessions
- `CheckManual()` (Manual-mode heating decision) now requires, per
  interior sensor: `temp < mintemp`, `temp != 0.0`, `type == "I"`,
  `valid` (config truthy), and `current` (freshness). All four
  guard conditions matter — don't drop any when touching this function.
  See also [[project_raspberrypi1_ttato_mqtt_drop]] for a different,
  unrelated Manual-mode issue (command subscription silently dropped).
- Any `docker restart TTato` drops Manual mode to Automatic — always
  check `www/TTatoMode` after a restart and re-send `changemode.json`
  if Manual mode should still be active.
- `sensor.temperatura_hab_varones` in HA is still flaky (intermittent
  `unknown`, ~10 min cycle) — unresolved, HA/hardware side. The fixes here
  only stop that flakiness from corrupting TTato's heating logic; they
  don't fix the sensor itself.
- To hand-edit HA's `automations.yaml` for a specific action within a
  linear `actions:` list without disturbing sibling actions, wrap the
  action in HA's `if:`/`then:` action shorthand (list of `condition:`
  under `if:`, list of actions under `then:`) rather than inserting a
  bare `condition:` action, which would abort the whole automation run at
  that point instead of just skipping one step.
