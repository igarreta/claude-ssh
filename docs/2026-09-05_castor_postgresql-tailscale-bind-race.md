# castor: PostgreSQL failed to bind Tailscale IP at boot (recurring)

**Status:** closed
**Host:** castor
**Supersedes:** —
**Superseded-by:** —

**Date:** 2026-09-05

## Symptom

Uptime Kuma reported PostgreSQL down on castor. The service was actually healthy —
`postgresql@17-main` active, DB reachable on `10.0.100.11` and localhost — but not
listening on the Tailscale IP `100.65.209.119`, which is what Uptime Kuma and the
`castor-pg` MCP connector use.

## Root cause

`postgresql@17-main.service` had a drop-in (`network-wait.conf`) ordering it
`After=network-online.target tailscaled.service`. That only waits for the
**tailscaled process** to start, not for the `tailscale0` interface to actually
receive its IP. Postgres started first, tried to bind all three
`listen_addresses`, and logged:

```
LOG:  could not bind IPv4 address "100.65.209.119": Cannot assign requested address
WARNING:  could not create listen socket for "100.65.209.119"
```

It then continued running on the addresses that *did* bind (localhost,
`10.0.100.11`), silently missing the Tailscale listener. This happened on both
restarts on 2026-09-05 (17:28 and the 17:43 unattended 17.10→17.11 upgrade), and
matches the same failure described in `memory_castor.md` §Network access
(2026-05-31) — that earlier occurrence was fixed with a one-off restart, and the
`network-wait.conf` drop-in was added afterward as a mitigation, but the ordering
alone was insufficient to prevent a recurrence.

## Fix

Immediate: `pct exec 205 -- systemctl restart postgresql@17-main` (Tailscale was
already up by then), restoring the `100.65.209.119:5432` listener.

Permanent: added an `ExecStartPre` that actively polls for the `tailscale0` IPv4
address (up to 30s) before postgres starts, instead of just ordering after the
tailscaled unit.

`/usr/local/bin/wait-for-tailscale.sh` (root:root, 755):
```bash
#!/bin/bash
# Waits for tailscale0 to have an IPv4 address before postgres binds listen_addresses.
# Fail-open: if Tailscale isn't up within the timeout, log it and let postgres start
# anyway (bound only to localhost/vmbr1) rather than blocking the whole DB.
for i in $(seq 1 30); do
    if ip -4 addr show tailscale0 2>/dev/null | grep -q 'inet '; then
        exit 0
    fi
    sleep 1
done
logger -t wait-for-tailscale "tailscale0 has no IPv4 address after 30s, starting postgres anyway"
exit 0
```

`/etc/systemd/system/postgresql@17-main.service.d/network-wait.conf`:
```ini
[Unit]
After=network-online.target tailscaled.service
Wants=network-online.target

[Service]
ExecStartPre=/usr/local/bin/wait-for-tailscale.sh
```

Deliberately fail-open: if Tailscale is somehow still down after 30s, postgres
starts anyway on its other addresses rather than taking the whole DB (and the
cygnus `10.0.100.11` clients with it) down over a monitoring-only listener.

Verified 2026-09-05 with a real `systemctl restart postgresql@17-main` — script
ran, exited 0 immediately (Tailscale already up), postgres bound all three
addresses including `100.65.209.119:5432`.

## Follow-up

If this recurs, the fail-open timeout (30s) may be too short for a slow
Tailscale reconnect — check `wait-for-tailscale` in `journalctl` for the
warning before assuming the script itself is broken.
