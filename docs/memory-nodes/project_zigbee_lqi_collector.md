---
name: project_zigbee_lqi_collector
description: "Persistent Zigbee LQI/route-error CSVs on CT206 (5-min systemd timer) — z2m's own logs rotate away, so day-over-day RF comparison must come from this collector; it parses log TEXT, so a log_level change rescales what it counts (bit us 2026-09-13) and route-error counts before that date are inflated ~3-4x"
metadata:
  node_type: memory
  type: project
  modified: 2026-09-13T23:30:00.000Z
---

zigbee2mqtt on CT206 logs into 3×10 MB rotating files — ~22 h of history at the `debug` level
this was built against (`info` since 2026-09-13, so longer now, but still finite).
Installed 2026-09-11: `/opt/zigbee-lqi/` writes every `linkquality` sample and route error to
daily CSVs on a 5-minute timer. Read it with `pct exec 206 -- /opt/zigbee-lqi/report.sh`
(daily per device) or `report.sh hourly N` (fleet trend).

**Why:** the 09-05 relapse in [[project_docker03_zigbee_rf_degradation]] could only be
analysed because the numbers were pulled the same week, and the 09-11 finding that LQI swings
~60 points daily means spot checks are actively misleading. Day-over-day evidence is the whole
point of the collector.

**How to apply:** never quote an LQI number without its hour, and prefer the collector's
hourly report over a fresh log scrape. Files live in `ct206/zigbee-lqi/` in the repo —
**that is the only home; don't add a second copy elsewhere** (a stray top-level `zigbee-lqi/`
was created and removed on 2026-09-13). `install.sh` redeploys.

**The trap, learned 2026-09-13: this collector parses log TEXT, so changing z2m's `log_level`
changes what it counts.** Dropping `debug` → `info` cut 3-4 matching lines per route error down
to 1, which would have read as a large improvement that never happened. `parse.awk` was fixed to
key on the one line emitted at *both* levels, so counts are now level-independent — but
**every `routeerr-*.csv` before 2026-09-13 is inflated ~3-4x**, can't be recomputed (logs
rotated), and 09-13 is a mixed day. **Comparable baseline starts 2026-09-14.**

**Sharper, found 2026-09-19: those old files don't just over-count, they mix three unrelated
event types.** 09-11 breaks down as 346 `SOURCE_ROUTE_FAILURE` + 825 `ZIGBEE_DELIVERY_FAILED` +
779 `unknown` + 13 `MANY_TO_ONE`. So a pre-09-13 total is **not a route-error count scaled by a
constant — it is a different metric.** Always read the code column (field 2) rather than
`wc -l`, or use nothing before 09-14. Quoting those totals as route errors is what produced the
retracted "1700-2000/day" headline in [[project_docker03_zigbee_rf_degradation]]. Re-check
`parse.awk` any time `log_level` moves. Details, including why `tail -F | awk` was abandoned (mawk
block-buffers its input — the CSVs look empty while it lags ~13 min):
`docs/memory_zigbee-lqi-collector.md`.
