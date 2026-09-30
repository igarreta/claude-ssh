# raspberrypi1 TTato: evening heating despite warm outdoors — outdoor cutoff extended (2026-09-30)

**Status:** open
**Status detail:** config change live since 18:33; commit to `igarreta/TTato` still pending (see §Commit)
**Host:** raspberrypi1
**Supersedes:** —
**Superseded-by:** —

## Problem
At 18:20 the boiler relay was ON (`Boiler ON; BurnerOFF`, the burner never fired), with
the inside at 19.5–20.5 °C and ext_prom at 17.7 °C. At 17:38:57 a Manual period
ended, TTato went back to **A**, and the relay switched on during that same cycle.

## Cause — rules, not a bug
Weekday Automatic rules on `LIVING00` (the `living` sensor goes first):
`WD_LIV04` 16–18 h `< 20.0`, `WD_LIV05` 18–22 h `< 21.0`. With living at 19.9–20.0 both
of them asked for heat. The only outdoor cutoff, `EXT_LIM2` (`EXTERNAL > 17.0`), ran from
**00:00 to 15:00**, so nothing switched heating off in the evening because it was
warm outside.

Rule evaluation (`TTato.py`, `if ttato_mode == "A"`): rules run in file order, and the
last rule that matches sets the result. `EXT_LIM2` comes after all the time-of-day `<`
rules, so when it matches it overrides them. Only the `BASE_*` rules come after it,
and none of them extends past 15:00. When the boiler is on, `tolerance` is added to
`set_temp`, so the effective cutoff is 17.2 °C.

## Change (`/home/rsi/TTato/var/config.yaml`)
| Rule | Field | Before | After |
|---|---|---|---|
| `EXT_LIM2` | `end_time` | `"15:00"` | `"24:00"` |
| `WD_LIV04` | `set_temp` | 20.0 | 19.5 |
| `WD_LIV05` | `set_temp` | 21.0 | 20.5 |

Backup: `var/config.yaml.bak-2026-09-30`.

## Applying config changes
`get_config()` (`GlobalThreads.py:80`) returns a cached dict. The re-parse of the rules
every 60 s reads that cache, not the file. Per the code, `reload_config()` runs only on
the hour (`TTato.py:676`). Not verified live: to apply now, `docker restart TTato`.
A restart resets Manual mode to A (see
`2026-08-01_raspberrypi1_ttato-manual-mode-phantom-zero-heating.md`), which was
harmless here because the mode was already A.

## Verification
Restarted at about 18:31. At 18:38:13, with living 20.1 (< 20.5, `WD_LIV05` asks for
heat) and ext_prom 17.6 (> 17.0), the log shows `BoilerOFF`, so `EXT_LIM2` wins as
expected. When ext_prom falls below 17 °C in the evening, the living rules take over
again. That is expected behavior.

## Commit
Pending. The working tree also holds an older uncommitted, unrelated change: `ext_prom`
`type: I` → `E` (backup `var/config.yaml.bak-ext_prom-type`). It should go in its own
commit (the precedent is `5f7616a`/`c6bfb1a`). Splitting it would temporarily rewrite
the live config, and the auto-mode classifier blocked that from MCP, so the user
has to run it.

## Side finding
`www/heat.csv` logged `Error: pocas lecturas: 0` every day from 09-25 to 09-29 (daily
burner-time summary). Not investigated.
