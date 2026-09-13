# Zigbee LQI collector (CT206)

**Status:** active
**Host:** CT206 (zigbee2mqtt)
**Supersedes:** —
**Superseded-by:** —

Persistent per-sample record of Zigbee `linkquality` and route errors, so the coordinator
RF investigation ([2026-08-24_docker03_zigbee-coordinator-rf-degradation.md](2026-08-24_docker03_zigbee-coordinator-rf-degradation.md))
can compare days instead of hours.

## Why it exists

zigbee2mqtt on CT206 logs into `3 x 10 MB` rotating files. At the `log_level: debug` in force
when this was built that was **~22 hours of history** (the level dropped to `info` on
2026-09-13, so the window is now considerably longer — but still finite, and still rotating).
Every LQI reading older than that is gone, and
the relapse of 2026-09-05 could only be analysed because the numbers were extracted the same
week. The collector keeps the two series that matter in CSVs the rotation never touches.

## What is installed

| Path (inside CT206) | What |
|---|---|
| `/opt/zigbee-lqi/collect.sh` | one-shot scrape of whatever is new in the live log |
| `/opt/zigbee-lqi/parse.awk` | log line → CSV row |
| `/opt/zigbee-lqi/report.sh` | `report.sh` (daily per device) / `report.sh hourly [N]` |
| `/opt/zigbee-lqi/data/` | `lqi-YYYY-MM-DD.csv` (`ts,device,linkquality`), `routeerr-YYYY-MM-DD.csv` (`ts,code,target`), `delivfail-YYYY-MM-DD.csv` (same shape; only written while `log_level: debug`) |
| `/opt/zigbee-lqi/state/cursor` | `<log dir> <inode> <byte offset>` |
| `zigbee-lqi.timer` / `.service` | every 5 min, `Persistent=true` |

Source of truth for the files is `ct206/zigbee-lqi/` in this repo; `install.sh` deploys them
(`pct push 206 …` into `/tmp/zigbee-lqi/`, then run it as root in the container).

Retention: 180 days, pruned by `collect.sh`. Volume is ~250 KB/day.

## Three things that bit

1. **`tail -F | awk` does not work here.** mawk block-buffers its input, so records appeared
   in bursts ~13 minutes late, and during that window the CSVs looked empty — the collector
   seemed broken when it was merely lagging. `stdbuf -oL` on `tail` did not fix it. The
   cursor-based scrape replaced it: each run reads a byte range and exits, so everything is
   flushed and the lag is bounded by the timer.
2. **Rotation and z2m restarts both move the file.** A restart creates a whole new log
   *directory*, and rotation renames `log.log` to `log1.log`. `collect.sh` stores the inode
   with the offset: when it no longer matches, it finishes the old file via `log1.log` (if
   that is still the same inode) before reading the new one from 0.

3. **`log_level` silently rescales the route-error count (2026-09-13).** Under `debug` a
   single route error emits 3-4 lines that the original broad `/ROUTE_ERROR/` pattern counted
   all of; under `info` only the summary line survives, and it carries neither `errorCode=`
   nor `target=`, so it was recorded as `unknown` with no device. **Every `routeerr-*.csv`
   before 2026-09-13 is therefore inflated ~3-4x** and cannot be recomputed — the logs have
   rotated. 2026-09-13 itself is a mixed day (old parser until ~18:50); **the comparable
   baseline starts 2026-09-14.**

   `parse.awk` now keys on the one line z2m emits at `info`, which is present at *both*
   levels:

   ```
   Received network/route error ROUTE_ERROR_SOURCE_ROUTE_FAILURE for "43800".
   ```

   That gives exactly one row per error regardless of `log_level`, and the code and target are
   parsed out of that format so per-device attribution survives. `ZIGBEE_DELIVERY_FAILED` is a
   **different event** and is debug-only — it moved to its own `delivfail-*.csv`, empty while
   the level is `info`, intact if `debug` is ever restored for an investigation. The previous
   parser is kept on CT206 as `/opt/zigbee-lqi/parse.awk.pre-2026-09-13`.

   **The general lesson: this collector parses log text, so any change to z2m's `log_level`
   changes what it counts.** Re-check `parse.awk` whenever that setting moves, and treat
   counts either side of such a change as different series.

## Reading it

```bash
pct exec 206 -- /opt/zigbee-lqi/report.sh            # daily average per device
pct exec 206 -- /opt/zigbee-lqi/report.sh hourly 3   # fleet hourly trend, last 3 days
```

The fleet number to watch is the `Enchufe_1` / `Enchufe_2` / `luces medianera z` average
(1–2 hops) — the same set used throughout the RF doc, where a *uniform* move across hops is
the signature that points at the coordinator rather than one link.

Seeded 2026-09-11 with the ~22 h still held in the rotating logs, so the series starts
2026-09-10 16:15.
