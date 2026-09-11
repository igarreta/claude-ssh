---
name: project_zigbee_lqi_collector
description: "Persistent Zigbee LQI/route-error CSVs on CT206 (5-min systemd timer) — zigbee2mqtt's own debug logs only retain ~22 h, so any day-over-day RF comparison must come from this collector"
metadata:
  node_type: memory
  type: project
  modified: 2026-09-11T19:45:00.000Z
---

zigbee2mqtt on CT206 logs at `debug` into 3×10 MB rotating files — **~22 hours of history**.
Installed 2026-09-11: `/opt/zigbee-lqi/` writes every `linkquality` sample and route error to
daily CSVs on a 5-minute timer. Read it with `pct exec 206 -- /opt/zigbee-lqi/report.sh`
(daily per device) or `report.sh hourly N` (fleet trend).

**Why:** the 09-05 relapse in [[project_docker03_zigbee_rf_degradation]] could only be
analysed because the numbers were pulled the same week, and the 09-11 finding that LQI swings
~60 points daily means spot checks are actively misleading. Day-over-day evidence is the whole
point of the collector.

**How to apply:** never quote an LQI number without its hour, and prefer the collector's
hourly report over a fresh log scrape. Files live in `ct206/zigbee-lqi/` in the repo;
`install.sh` redeploys. Details, including why `tail -F | awk` was abandoned (mawk
block-buffers its input — the CSVs look empty while it lags ~13 min):
`docs/memory_zigbee-lqi-collector.md`.
