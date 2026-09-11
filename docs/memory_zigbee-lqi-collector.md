# Zigbee LQI collector (CT206)

**Status:** active
**Host:** CT206 (zigbee2mqtt)
**Supersedes:** —
**Superseded-by:** —

Persistent per-sample record of Zigbee `linkquality` and route errors, so the coordinator
RF investigation ([2026-08-24_docker03_zigbee-coordinator-rf-degradation.md](2026-08-24_docker03_zigbee-coordinator-rf-degradation.md))
can compare days instead of hours.

## Why it exists

zigbee2mqtt on CT206 logs at `log_level: debug` into `3 x 10 MB` rotating files, which at
the current rate is **~22 hours of history**. Every LQI reading older than that is gone, and
the relapse of 2026-09-05 could only be analysed because the numbers were extracted the same
week. The collector keeps the two series that matter in CSVs the rotation never touches.

## What is installed

| Path (inside CT206) | What |
|---|---|
| `/opt/zigbee-lqi/collect.sh` | one-shot scrape of whatever is new in the live log |
| `/opt/zigbee-lqi/parse.awk` | log line → CSV row |
| `/opt/zigbee-lqi/report.sh` | `report.sh` (daily per device) / `report.sh hourly [N]` |
| `/opt/zigbee-lqi/data/` | `lqi-YYYY-MM-DD.csv` (`ts,device,linkquality`), `routeerr-YYYY-MM-DD.csv` (`ts,code,target`) |
| `/opt/zigbee-lqi/state/cursor` | `<log dir> <inode> <byte offset>` |
| `zigbee-lqi.timer` / `.service` | every 5 min, `Persistent=true` |

Source of truth for the files is `ct206/zigbee-lqi/` in this repo; `install.sh` deploys them
(`pct push 206 …` into `/tmp/zigbee-lqi/`, then run it as root in the container).

Retention: 180 days, pruned by `collect.sh`. Volume is ~250 KB/day.

## Two things that bit during the build

1. **`tail -F | awk` does not work here.** mawk block-buffers its input, so records appeared
   in bursts ~13 minutes late, and during that window the CSVs looked empty — the collector
   seemed broken when it was merely lagging. `stdbuf -oL` on `tail` did not fix it. The
   cursor-based scrape replaced it: each run reads a byte range and exits, so everything is
   flushed and the lag is bounded by the timer.
2. **Rotation and z2m restarts both move the file.** A restart creates a whole new log
   *directory*, and rotation renames `log.log` to `log1.log`. `collect.sh` stores the inode
   with the offset: when it no longer matches, it finishes the old file via `log1.log` (if
   that is still the same inode) before reading the new one from 0.

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
