# docker03 — fail2ban not running (fixed)

**Status:** closed
**Host:** docker03
**Supersedes:** —
**Superseded-by:** —

**Date:** 2026-07-05
**Trigger:** log-monitor flagged `fail2ban.service failed` (important, escalated) in the 2026-07-05 daily report.

## Root cause

docker03 has no `rsyslog` installed, so `/var/log/auth.log` is never created. fail2ban's
`sshd` jail defaults to `logpath = %(sshd_log)s` / `backend = %(sshd_backend)s`, which
resolve to that file. At boot (2026-06-18 02:55:05) fail2ban aborted configuration:

```
ERROR   Failed during configuration: Have not found any log file for sshd jail
ERROR   Async configuration of server failed
```

...and exited with status 255. The unit file sets `RestartPreventExitStatus=0 255`, so
systemd deliberately did **not** auto-restart (255 is treated as a fatal config error,
not a transient crash) — the service just sat in `failed` for over 2 weeks with no retry
and no further log output, which is why nothing showed up in later daily digests until
log-monitor's first run against docker03.

## Fix

Override the `sshd` jail to read bans from the systemd journal instead of a log file:

`/etc/fail2ban/jail.d/sshd.local`:
```ini
[sshd]
backend = systemd
```

Then `sudo systemctl restart fail2ban`. Confirmed active and stable afterward
(`fail2ban-server ready`, no errors).

## Note

docker03's `sudo` requires a password (not passwordless) — MCP `sudo-exec` fails there.
Privileged fixes were staged with `Write` + `scp` to `/tmp/`, then run manually by the
user. See [[feedback_docker03_sudo]] / `docs/memory_feedback.md`.
