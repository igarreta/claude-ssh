# Second exterior Zigbee sensor added as a backup leg of `sensor.casa_ext_temp`

**Status:** active
**Host:** homeassistant, gr-srv03
**Supersedes:** 2026-09-01_homeassistant_temperature-sensor-inventory.md (§2 exterior chain only)
**Superseded-by:** —

## Why

`sensor.casa_ext_temp` is a first-fresh-source-wins chain built 2026-08-19 after it froze on a
dead-battery sensor ([2026-08-19_homeassistant_temperatura-exterior-parque-stale-chain.md](2026-08-19_homeassistant_temperatura-exterior-parque-stale-chain.md)).
It had only **two local ambient sources**, both of which have died before, plus a night-only
roof-box proxy and a met.no forecast of last resort. A second outdoor Zigbee thermometer was
installed near the existing one; wiring it in as a third local source pushes the "no local
source" state one failure further away.

Device: z2m friendly_name `zigbee_temperatura_exterior_alt`, IEEE `0xa4c1388a037daa90`,
Tuya **ZY-ZTH02** (`TS0201` / `_TZ3000_rdhukkmi`), on CT206. Paired and publishing since
2026-09-05 10:33; nothing consumed it until now.

## Measurements (recorder DB, 2026-09-05 → 2026-09-13)

### It reads warm — hence a correction constant

| pair | n | mean | median | p10 | p90 | range |
|---|---|---|---|---|---|---|
| `zb2` − `casa_ext_433_temp` | 162 | +1.69 | **+1.44** | +0.68 | +2.85 | −0.11 … +8.78 |
| `zb2` − `casa_ext_zb_temp` | 112 | +1.72 | — | — | — | −0.26 … +3.60 |
| `casa_ext_zb_temp` − `casa_ext_433_temp` | 120 | −0.17 | — | — | — | −0.60 … +0.50 |

The two pre-existing sensors agree with each other within ±0.6 °C, so **zb2 is the outlier, not
the reference pair**. The offset is present at every hour of the day (0.6 at 17–18 h, 2.7 at
06 h) — it is *not* solar gain, and it is slightly larger at night. **Correction applied: −1.5 °C**
(median-based), leaving roughly ±1.2 °C residual across p10..p90.

The single +8.78 outlier is the first reading after the 974-min silence below — a stale value,
exactly what the staleness guard rejects.

Corroboration: the *retired* `zigbee_temp_exterior` leg was the **same ZY-ZTH02 model** and
carried a −1.8 correction. Two independent units of this model both read high outdoors.

### Heartbeat and threshold

373 inter-publish gaps (from `sensor.casa_ext_zb2_last_seen` state changes):

```
<1 min   :  83   burst / on-change duplicates
1-28 min :  91   extra on-change reports
29-30 min: 166   nominal heartbeat
31-60 min:   2
>60 min  :  14   see below
```

Heartbeat is 30 min, so the quantisation levels are 30/60/90/120. Per the threshold-sizing
method in the 08-19 doc a threshold must sit *between* levels: **100 min** — tolerates 2 missed
heartbeats, trips at 3. Same guard as the other Zigbee leg.

### It drops out — known, accepted for a fallback

14 silences over 1 h in 8 days: 65, 81, 88, 105, 244, 315, 356, 416, 445, 496, 535, 562, 658 and
one of **974 min (16 h)**. LQI 116 vs 144 for the primary. As a *fallback* this costs nothing —
the guard skips it while silent — but it is **not** a sensor to promote above the SONOFF, and
repositioning it is worth considering. If it is moved, the −1.5 constant must be re-measured.

### Its battery sensor is not diagnostic

`sensor.casa_ext_zb2_battery` is a constant `100` and `sensor.casa_ext_zb2_voltage` a constant
`3000` — the ZY-ZTH02 trap already recorded in the 08-19 doc. `chequeo_baterias_diario` scans
every `device_class: battery` entity and will therefore **never fire for this device**. The
100-min staleness guard is its only protection, which is precisely the 08-19 follow-up note:
*"Zigbee battery sensors have no `expire_after` equivalent; any new source added to this chain
needs a staleness guard too."*

## Changes applied 2026-09-13

### Entity renames (HA UI, by the user)

`sensor.zigbee_temperatura_exterior_alt_{temperature,humidity,battery,voltage,last_seen}` →
`sensor.casa_ext_zb2_{temp,hum,battery,voltage,last_seen}`, friendly names
"… exterior 2 (Zigbee)". `update.zigbee_temperatura_exterior_alt` left alone, as the 09-01 pass
left `update.*` entities. Recorder history carried over intact back to 09-05. The z2m
friendly_name is unchanged.

**A z2m rename would not have worked** — z2m's discovery `unique_id` is
`<ieee>_<property>_zigbee2mqtt`, IEEE-derived and never name-derived, so once HA holds a registry
row it matches on that and leaves `entity_id` untouched. Evidence in this install:
`sensor.0xa4c1380a7834ffff_linkquality` and `_last_seen` still carry the raw-IEEE spelling from
before that device's 08-30 rename, while siblings created after it got the friendly spelling.

**And the `.storage` stop/start dance was not needed.** The 09-01 pass scripted a
`core.entity_registry` edit with HA Core stopped because it was ~25 entities across 4 dashboards
and 2 YAML files at once. For a handful of entities that nothing references yet, the HA UI rename
is supported, needs no downtime, and carries history across.

### `configuration.yaml` — 3 sites (backup `configuration.yaml.bak-zb2-20260913-194845`)

Chain is now, first fresh source wins:

| # | Source | Guard | Correction |
|---|---|---|---|
| 1 | `sensor.casa_ext_433_temp` (rtl_433 Oregon, `expire_after: 1800`) | 60 min | 0.0 |
| 2 | `sensor.casa_ext_zb_temp` (SONOFF SNZB-02WD) | 100 min | 0.0 |
| 3 | **`sensor.casa_ext_zb2_temp` (Tuya ZY-ZTH02)** | **100 min** | **−1.5** |
| 4 | `sensor.esp32_pileta_temperatura_caja_techo` (roof box, sun elevation ≤10° only) | 15 min | +3.4 |
| 5 | `weather.forecast_home` (met.no) | 150 min | 0.0 |

- `sensor` `temp_exterior_parque` → `state:` gained `('sensor.casa_ext_zb2_temp', 100, -1.5)`
- same sensor → `availability:` gained `('sensor.casa_ext_zb2_temp', 100)` — adding it to
  `state:` alone does nothing, `availability:` is what forces `unavailable`
- `binary_sensor` `temp_exterior_parque_sin_fuente` → `srcs` gained the same pair, so the alarm
  counts zb2 as a live local source

### `automations.yaml` — 1 site (backup `automations.yaml.bak-zb2-20260913-194845`)

Automation `1787100000000` ("Temperatura exterior parque: sin fuente valida") lists per-source
ages in its Pushover body; `sensor.casa_ext_zb2_temp` added to that loop. Trigger and
priority (−1) unchanged.

### Nothing else needed

Dashboards (`lovelace.granaderos_base`, `lovelace.luces_granaderos`) reference only the
calculated `sensor.casa_ext_temp`.

## Verification

- `ha core check` — passed.
- **Template unit tests, 7/7** — rendered from the real on-disk `configuration.yaml`
  (`yaml.safe_load` + jinja2 inside the `homeassistant` container, so the YAML→Jinja escape layer
  was exercised), with mocked `states` / `now()` / `state_attr` / `this`. Cases: normal (433
  wins); 433+zb stale → zb2 used with −1.5; zb2 at **99 min** still fresh; zb2 at **101 min**
  stale → met.no and alarm on; zb2 `unavailable` → skipped; zb2 fresh at night beats the roof-box
  proxy; all local stale with no met.no → `unavailable`, holds last value.
  No Jinja macros were used — a `{% macro %}` returns `str`, so `{% if fresh(...) %}` is always
  truthy (08-19 trap).
- YAML reload of Template entities + Automations (no restart: these are edits to *existing*
  template entities, and a restart would blank the MQTT sensors for up to 30 min). Reload clean
  at 19:55:55; the only errors in the log are pre-existing and unrelated
  (`casa_hab_chicos_temp` has had no source since 09-02; `localtuya` thread-safety warnings).
- Live at reload: `casa_ext_433_temp` had just gone `unavailable` on its `expire_after`, and the
  chain correctly fell through to `casa_ext_zb_temp` = 11.2 °C, `sin_fuente` = `off`.
  `casa_ext_zb2_temp` read `unknown` — the device had not published since 19:14 — which is the
  dropout profile above, not a fault of the rename.

## Open

- Confirm the zb2 leg live once the device reports (it should populate on its next heartbeat).
- Re-check the offset in ~2 weeks; re-measure the constant if the sensor is repositioned.
