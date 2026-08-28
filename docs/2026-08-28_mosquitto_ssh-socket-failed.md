# mosquitto: ssh.socket stuck in failed state

**Status:** closed
**Host:** mosquitto
**Supersedes:** —
**Superseded-by:** —

## What happened

log-monitor escalated an `important` finding on 2026-08-28: `ssh.socket` shown as
`loaded failed failed` in `systemctl --failed` on the mosquitto LXC.

## Root cause

Not an outage. Debian 13 defaults to SSH daemon mode (`ssh.service`), but `ssh.socket`
(socket activation) was also enabled and tried to bind `[::]:22`. `ssh.service` won the
port race and has been running fine throughout (confirmed: active since 2026-08-16
16:39:40, uninterrupted, serving connections including the one that collected this same
log digest). `ssh.socket` hit `service-start-limit-hit` on 2026-08-16 16:34:56 and sat in
`failed` ever since — cosmetic noise, not a loss of SSH access.

## Fix

```bash
sudo systemctl disable --now ssh.socket
sudo systemctl reset-failed ssh.socket
```

Applied 2026-08-28 by the user (mosquitto's MCP connector policy denies `privileged`
commands for this role/host-group, so Claude could diagnose but not apply the fix).
Verified after: `ssh.socket` disabled/inactive, `ssh.service` still active, `systemctl
--failed` clean.
