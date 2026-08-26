---
name: project_log-monitor_journal-group-gap
description: "log-monitor silently collects nothing on a host if its SSH user isn't in adm/systemd-journal — found on docker03 and mosquitto, other hosts unverified"
metadata:
  node_type: memory
  type: project
---

`log-monitor/collect.sh` runs plain `journalctl` over SSH with no `sudo`. If the SSH user
isn't in `adm`/`systemd-journal` on that host, journalctl silently restricts to the user's own
messages — the daily report reads as a clean/quiet host when it's actually blind, with no
error anywhere.

**Why:** found 2026-08-26 while adding `mosquitto.conf` — `rsi` wasn't in either group there,
and turned out not to be on **docker03** either, despite that host's log-monitor config having
been active for a while already. Fixed both with `sudo usermod -aG systemd-journal rsi`.

**How to apply:** before trusting a "quiet" daily report from any log-monitor host, or when
adding a new one, verify the SSH user's groups (`ssh <host> groups`) include `adm` or
`systemd-journal`. **Not yet re-verified**: `raspberrypi1`, `raspberrypi2z`, `contabo2`,
`gr-srv03` — check these before relying on their reports being complete. Full detail:
[[docs/2026-06-30_log-monitor.md]].
