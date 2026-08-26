---
name: project_log-monitor_journal-group-gap
description: "log-monitor silently collects nothing on a host if its SSH user isn't in adm/systemd-journal — found and fixed on docker03, mosquitto, and contabo2; all hosts now verified"
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

**Resolved 2026-08-26** — every configured host checked: `raspberrypi1`/`raspberrypi2z` already
had `adm`; `gr-srv03` connects as `root` (moot); `contabo2` had the same gap and was fixed the
same way. All log-monitor hosts now actually see their system journal.

**How to apply:** when adding any new log-monitor host, verify the SSH user's groups (`ssh
<host> groups`) include `adm` or `systemd-journal` before trusting its reports — this doesn't
self-heal or error visibly if missed. Full detail: [[docs/2026-06-30_log-monitor.md]].
