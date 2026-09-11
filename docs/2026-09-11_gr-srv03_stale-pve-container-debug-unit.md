# gr-srv03: a stale pve-container-debug@<id> unit escalates in log-monitor forever

**Status:** closed
**Host:** gr-srv03
**Supersedes:** —
**Superseded-by:** —

## What happened

From 2026-09-07 to 2026-09-11, log-monitor escalated gr-srv03 to Sonnet on most days with an
`important` finding:

```
--- Failed systemd units ---
pve-container-debug@203.service loaded failed failed PVE LXC Container: 203
```

CT203 is ceres, the backup-management host, so the report read as a serious outage. The
2026-09-11 report went further and hypothesised a leftover WDMyCloud `hookscript:` in
`/etc/pve/lxc/203.conf`.

**None of that was true.** ceres was running the whole time:

```
pct status 203   → running
```

## Root cause

`pve-container-debug@<id>.service` is the unit Proxmox instantiates for
`pct start <id> --debug`. It is a **separate unit** from `pve-container@<id>.service`, it is
`static`, and nothing ever restarts it.

The failure timestamp gives it away:

```
Active: failed (Result: exit-code) since Sun 2026-09-06 11:14:15 -03; 5 days ago
Duration: 12.317s
Main PID: 601475 (code=exited, status=1/FAILURE)

journalctl -u pve-container-debug@203.service  → No entries
```

That is the 2026-09-06 WDMyCloud-dead session (see
[2026-09-06_ceres_wdmycloud-nas-dead.md](2026-09-06_ceres_wdmycloud-nas-dead.md)), where
ceres was started with `--debug` while diagnosing the missing NAS mounts. The debug start
exited 1, the normal start later succeeded, and the debug unit was left sitting in `failed`.
It has no journal entries because the debug unit logs to the terminal, not the journal —
which is also why the report had nothing to reason from and invented a cause.

## Fix

```bash
systemctl reset-failed pve-container-debug@203.service
```

Applied 2026-09-11. Verified after: `systemctl list-units --state=failed` empty on gr-srv03,
`pct status 203` still running, all other CTs up (207/rtl433 stopped on purpose).

## The general lesson

Any `pct start <id> --debug` that exits non-zero leaves a permanently `failed` unit. Because
log-monitor reports `systemctl --failed` verbatim and cannot see that the container is
actually running, it escalates that unit **every single day** — burning a Sonnet call per run
and, worse, training the reader to ignore container-failure findings.

After any `--debug` container start, run `systemctl reset-failed pve-container-debug@<id>`.

When a `pve-container-debug@<id>` finding does appear, check `pct status <id>` **first**. If
the container is running, it is this; the fix is `reset-failed`, not an investigation of the
container config. The same "stale failed unit outlives the problem" trap produced
[2026-08-28_mosquitto_ssh-socket-failed.md](2026-08-28_mosquitto_ssh-socket-failed.md) and the
cleanup in
[2026-09-11_mosquitto_networkd-wait-online-timeout.md](2026-09-11_mosquitto_networkd-wait-online-timeout.md).

## Also cleared the same day, unrelated

`pvedaemon: authentication failure; rhost=::ffff:100.127.59.91 user=rsi@pam msg=no such user`
— a single occurrence on 2026-09-10 17:21. `100.127.59.91` is `nb-rsigarreta`, the user's own
Windows laptop: a mistyped Proxmox web login (`rsi` instead of `root`). Not a script, not a
scan, no action. The report had guessed at the backup health monitor calling the API with bad
credentials; `tailscale status | grep <ip>` settles this class of question in one command.
