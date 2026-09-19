---
name: project_bomba-agua_current-measurement
description: "The TS011F on bomba agua z accepts its attribute-reporting config and never honours it — current only updates on measurement_poll_interval, and for up to one poll after any state change the value is actively wrong, not merely stale; HA thresholds rescaled 2026-09-19 for a 1.15 A pump"
metadata:
  node_type: memory
  type: project
  modified: 2026-09-19T18:40:00.000Z
---

`bomba agua z` (TS011F, LXC 206 / zigbee2mqtt) has `rmsCurrent`, `activePower`, `rmsVoltage` and
`currentSummDelivered` listed in `configuredReportings` with a 5 s minimum and a 50 mA reportable
change. **Those rows only prove the device ACKed `configureReporting`. It never sends reports.**
Every real value change comes from `measurement_poll_interval` polling.

**Why it matters:** it inverts the obvious advice. `-1` does not "remove the backstop", it
**freezes current forever**; and a 5 s reporting latency that exists only on paper will get you
to leave a 120 s poll in place under a blocked-rotor automation. Detection latency *is* the poll
interval. Worse, for up to one poll interval after any state change the sensor republishes the
**previous régime's** value — after the relay opened, current read 1.15 A for 52 s. That is not
stale data, it is wrong data.

**How to apply:**

- **Never conclude reporting works from log gaps alone.** The 5 s gaps right after a re-pair are
  z2m's own interview reads. The clean test is whether value changes land on the poll grid: on
  2026-09-19 both transitions (0 → 1.15 A and 1.15 → 0) fell exactly 120 s apart on the :44–:45
  second where every idle poll had been landing. Identical repeated readings across a state
  change (2.49 A nine times, 1.15 A six times) are the cache, not a steady motor.
- **`last_reported` cannot detect this staleness** — the cached value is actively republished, so
  it looks fresh. This is the documented exception to
  [[project_homeassistant_stale_sensor_chain]]. The only discriminant is time since the *switch*
  changed state.
- **Keep the HA guard ≤ the trigger's own `for:`.** A `numeric_state` trigger fires only on the
  transition into range; if a longer condition rejects it, it never retries, so a pump that
  starts already blocked would trip once and then never fire again.
- Poll is now **10 s** (was 120). Cost ~8 640 polls/day; watch total mesh load, because
  `luces medianera z` is the same model and still repairs a route on nearly every poll —
  [[project_docker03_zigbee_rf_degradation]].
- **Open:** the 1.37 A closed-valve threshold is *scaled* from the old pump's empirical 1.55 A,
  not measured on this one. If this pump dead-heads below it, that automation stops protecting
  silently.

Full write-up, including the measured cycle, the three rescaled thresholds and the
`qm guest exec 104` apply procedure: `docs/2026-09-19_homeassistant_bomba-agua-current-thresholds.md`.
Write path: [[project_homeassistant_config_write_path]].
