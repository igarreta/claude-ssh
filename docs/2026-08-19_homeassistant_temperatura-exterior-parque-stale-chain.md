# HomeAssistant: "Temperatura exterior parque" froze on a dead sensor; staleness
# guards + met.no fallback added

**Status:** closed
**Host:** homeassistant, docker03
**Supersedes:** —
**Superseded-by:** —

## Symptom
2026-08-19: `sensor.temperatura_exterior_parque` reported **15.8 °C** while the
actual outdoor temperature was ~14.1 °C. The value had been frozen since
2026-08-18 08:37.

## Root cause
The template sensor is a 4-source priority chain. Its fallback logic only treated
`unavailable` / `unknown` as "no data":

```jinja
{% set primary = states('sensor.zigbee_temperatura_exterior_temperature') | float(none) %}
{% if primary is not none %}{{ primary }}
```

Priority 2 (`zigbee_temperatura_exterior`) had a **dead battery**, but it is a
zigbee2mqtt *discovery* entity — HA retains its last numeric state indefinitely, so
it never became `unavailable`. It kept returning a valid `15.8`, and the chain
never fell through to the healthy priority-3 sensor.

Chain state at diagnosis:

| # | Source | State | Result |
|---|---|---|---|
| 1 | `..._granaderos` (Oregon, rtl_433) | `unavailable` (dead 08-13, battery) | falls through |
| 2 | `zigbee_temperatura_exterior` | **frozen `15.8`** (dead battery) | **chain stops here** |
| 3 | `zigbee_temp_exterior` | `14.1`, healthy | never reached |
| 4 | `esp32_pileta_...` | healthy | never reached |

Priority 1 behaved correctly by contrast because its MQTT sensor has
`expire_after: 1800`. The zigbee discovery entities have no such setting, and
zigbee2mqtt's `availability.active.timeout: 30` applies only to mains-powered
routers — battery end devices use the *passive* timeout (~25 h default), which
also gets reset by brief reconnects. Confirmed: z2m reported both dead outdoor
sensors as `"state":"online"`.

## Two traps found while building the fix

**1. `last_changed` is the wrong attribute.** The obvious guard
(`now() - last_changed > threshold`) is broken: with `temperature_precision: 1`
a stable outdoor temperature holds the same rounded value for hours. Measured
state-change gaps for the *healthy* priority-3 sensor:

```
median 30 min   p95 90 min   max 325 min (5.4 h)
```

A 60-min guard on `last_changed` would have marked a working sensor stale >5% of
the time. **`last_reported` is correct** — it updates on every MQTT publish even
when the value is unchanged (HA 2024.8+; this instance runs 2026.8.2).

**2. Jinja macros return `str`, so `{% if fresh(...) %}` is always truthy.**
A `{% macro fresh() %}` helper would have silently disabled the guard entirely
(a returned `" False "` is a non-empty string). Verified in the HA container:

```
macro returns type: str
{% if fresh(false) %} -> TAKEN (bug: false branch entered)
```

The working form uses `namespace` + a loop, with no macro.

## Threshold sizing (method)
Publish gaps are **quantized** at multiples of the device heartbeat, so a
threshold must sit *between* levels, never on one. Measured for
`zigbee_temp_exterior` over ~29 h from zigbee2mqtt's own log (68 gaps, bursts
collapsed):

```
~15 min :   9    extra on-change reports
~30 min :  51    nominal heartbeat
~60 min :   1    one missed heartbeat
>60 min :   0
```

Heartbeat is a hard 30 min (held across a full overnight). Levels therefore fall
at 30/60/90/120. **90 was rejected** — it sits exactly on the 2-miss level, so
jitter makes it a coin flip. Chose **100 min** (tolerates 2 misses, trips at 3)
over 70 (tolerates 1) because the failure mode being caught is a *dead battery*,
which is permanent: faster detection buys nothing, while a false trip degrades a
working chain.

Same method for met.no: heartbeat 57 min, levels 57/114/171 → **150 min**.

## Changes applied (2026-08-19)

`/config/configuration.yaml`, `sensor.temperatura_exterior_parque`:
- **`state:`** — rewritten as a `namespace` loop with a per-source `last_reported`
  staleness guard, plus met.no as a final fallback.
- **`availability:`** — rewritten to be freshness-aware and include met.no.
  Required: adding met.no to `state:` alone does nothing, because the old
  `availability:` template was what forced `unavailable`.

Per-source thresholds:

| # | Source | Heartbeat | Guard |
|---|---|---|---|
| 1 | `..._granaderos` | rtl_433, `expire_after: 1800` | 60 min |
| 2 | `zigbee_temperatura_exterior` | 30 min | 100 min |
| 3 | `zigbee_temp_exterior` | 30 min | 100 min |
| 4 | `esp32_pileta` (night only, +3.4) | ~1–2 min | 15 min |
| 5 | `weather.forecast_home` (met.no) | 57 min | 150 min |

New template `binary_sensor.temperatura_exterior_parque_sin_fuente`
(`device_class: problem`, `delay_on: 1 h`) — `on` when no **local** source is
fresh. `delay_on` exists to suppress a false alarm on HA restart, when MQTT
sensors read `unknown` until their next publish (up to 30 min).

`/config/automations.yaml` — new automation (id `1787100000000`) triggering on that
binary sensor, sending Pushover at **priority -1** with hostname + automation name
and a per-source age listing. Deliberately keyed to **local sources only**: it
stays `on` while met.no is filling in, so three dead sensors can't hide behind a
forecast.

Backups: `configuration.yaml.bak-20260819-085332` (state + binary_sensor),
`.bak-20260819-103923` (availability + met.no); `automations.yaml.bak-*` likewise.

## Verification
Templates were unit-tested against mocked real values inside the HA container
(jinja2 + `yaml.safe_load` of the actual YAML, so the YAML→Jinja escape layer was
exercised too). All cases passed, including met.no missing its `temperature`
attribute, and the 2-miss / 1-miss boundary cases.

Live confirmation:
- Alert fired **09:57:07** — exactly 1 h after the 08:56 restart, per `delay_on`.
  Log distinguishes `Running automation` (fired) from `Initialized trigger`
  (restart re-arm), confirming no duplicate on the second restart.
- After the met.no change, `parque` = **9.7**, matching `weather.forecast_home`
  exactly.

Note: HAOS has no `ha core reload` — only `ha core restart`. A new template entity
or automation requires a restart.

## Second, unrelated fault found during verification
`zigbee_temp_exterior` — priority 3, the only healthy source — **stopped
transmitting 2026-08-19 06:56:29** (last reading 11.3 °C at dawn) and stayed
silent. Link quality decayed 220 → 176 → 140 beforehand. `battery: 100` /
`voltage: 3000` are **constants on this Tuya ZY-ZTH02 model and are not
diagnostic**. It went silent two hours *before* the HA restart, so it is unrelated
to these changes; zigbee2mqtt was healthy throughout (`zigbee_temp_living` kept
publishing).

Ruled out: `luz exterior garage` (an outdoor mains Router) is offline, but has been
for over a day while the sensor kept working — not the trigger.

Also rejected as a substitute source: `sensor.wifi_temperature_humidity_sensor_*`
is live but its friendly name is `pin-temp-exterior1` — that is the **Pinamar**
property, a different location.

## Outstanding — hardware, needs physical action
All three outdoor sensors are dead. Software now routes around them, but the value
shown is a regional forecast, not the garden.

1. `zigbee_temp_exterior` — failed 08-19; the source the chain depends on. Battery first.
2. `zigbee_temperatura_exterior` — dead battery since 08-18 08:37.
3. Oregon exterior (Granaderos) — dead since 08-13; low battery already flagged
   2026-07-02 (see `2026-07-02_raspberrypi2z_oregon-sensor-outage.md`).

Both Zigbee outdoor sensors failed within ~26 h of each other, both in the early
morning. If fresh batteries don't revive them, suspect moisture or cold at the
mounting location rather than the sensors.

## Follow-up worth considering
- Zigbee battery sensors have no `expire_after` equivalent; the staleness guard is
  the only protection. Any *new* source added to this chain needs one too.
- 9 pre-existing `last_changed` uses in `automations.yaml` throw
  `UndefinedError: 'None' has no attribute 'last_changed'` (entity since renamed or
  removed). Unrelated to this work, but noisy in the log.
