---
name: feedback_stale_failed_unit_false_positive
description: A stale systemd failed unit escalates in log-monitor every day — check whether the thing it names is actually running before investigating
metadata:
  node_type: memory
  type: feedback
---

log-monitor reports `systemctl --failed` verbatim and cannot tell that the service or
container a failed unit names is running fine right now. So a unit left `failed` by a
one-off event escalates to Sonnet **every single day** until someone runs `reset-failed`.

**Why:** on 2026-09-11 a `pve-container-debug@203.service` finding had been escalating on
gr-srv03 since 09-07 and read as "ceres is down". ceres was running the whole time — the unit
was residue from a `pct start 203 --debug` on 09-06. The escalated report, having no journal
entries to work from, invented a plausible-sounding WDMyCloud `hookscript:` cause. One
`pct status 203` would have ended it.

**How to apply:** when a failed-unit finding names something, first confirm its actual state
(`pct status <id>`, `systemctl is-active <svc>`) before acting on the report's hypothesis — an
escalated analysis is a guess, not evidence. If it is running, the fix is `reset-failed`, and
the question becomes *what left it failed*. Also clean up after yourself: a `--debug` container
start, or stopping a long-running service, leaves failed units behind (see
[[project_mosquitto_networkd_masked]]). Same trap as
[[project_mosquitto_ssh-socket-failed]].

Detail: `docs/2026-09-11_gr-srv03_stale-pve-container-debug-unit.md`.
