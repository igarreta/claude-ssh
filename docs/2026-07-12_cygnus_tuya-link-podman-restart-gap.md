# cygnus: tank water level sensor stopped — podman-restart.service filter gap

**Date:** July 12, 2026
**Host:** cygnus (LXC in gr-srv03, rootful podman)

---

## Symptom

Home Assistant's "Nivel tanque agua" (tank water level) entity stopped receiving
updates after gr-srv03's power outage around noon (same event that logged comet's
Tailscale out — see `docs/2026-07-12_comet_tailscale-logout-power-outage.md`).

## Root Cause

gr-srv03's power outage killed cygnus's LXC abruptly, taking down all 5 of its
podman containers (grafana, data-ingestion-api, pgadmin_pgadmin_1,
servidor_quetren_1, tuya-link). `tuya-link`'s own log confirms it was healthy and
polling right up to 11:47:07, then stopped mid-cycle — an infra kill, not an app
failure.

None of the 5 came back up on reboot, even though `podman-restart.service` was
enabled (fixed on 2026-06-22, see
`docs/2026-06-22_cygnus_podman-restart-after-reboot.md`) and ran successfully at
boot. **The 2026-06-22 fix was incomplete**: the unit's `ExecStart` is

```
podman start --all --filter restart-policy=always
```

but every cygnus container (all 5) has restart policy `unless-stopped`, not
`always`. The filter matched zero containers, so the service did nothing useful —
this was never actually exercised by a real reboot until today's outage exposed
it.

`tuya-link` down = no MQTT publishes to `homeassistant/.../granev_tank_level` =
Home Assistant entity goes stale. Same mechanism would have silently broken
grafana, data-ingestion-api, pgadmin, and quetren too (all were also down, just
less immediately visible).

## Fix

**1. Immediate — start the stopped containers** (passwordless, `podman` is
NOPASSWD for rsi on cygnus):

```bash
sudo podman start grafana data-ingestion-api pgadmin_pgadmin_1 servidor_quetren_1 tuya-link
```

**2. Systemic — widen the restart-policy filter** so future reboots actually
cover these containers. `podman ps --filter` with the same key repeated ORs
together (verified). Drop-in override:

`/etc/systemd/system/podman-restart.service.d/override.conf`:
```ini
[Service]
ExecStart=
ExecStart=/usr/bin/podman $LOGGING start --all --filter restart-policy=always --filter restart-policy=unless-stopped
ExecStop=
ExecStop=/usr/bin/podman  $LOGGING stop  --all --filter restart-policy=always --filter restart-policy=unless-stopped
```

```bash
sudo systemctl daemon-reload
sudo systemctl restart podman-restart.service
```

Applied and verified 2026-07-12 — service now starts all 5 containers
(`ExecStart status=0/SUCCESS`, 5 conmon processes running). `tuya-link` log
resumed publishing tank level readings immediately after restart.

## Verify

```bash
sudo podman ps --format '{{.Names}} | {{.Status}}'
systemctl cat podman-restart.service   # confirm override.conf is applied
tail -5 /home/rsi/tuya-link/log/tuya_link.log   # should show recent "Nivel tanque agua" entries
```

## Note

If any cygnus container is *intentionally* stopped (restart policy `no` or
manually `podman stop`ped) in the future, this widened filter will still leave
it alone — `no`/absent policy containers aren't matched by either `--filter`
clause. Only `always` and `unless-stopped` policies are auto-started at boot.
