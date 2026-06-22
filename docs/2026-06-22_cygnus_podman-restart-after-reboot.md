# cygnus: containers down after 2026-06-17 reboot — podman-restart.service fix

**Date investigated:** 2026-06-22
**Host:** cygnus (LXC in gr-srv03, rootful podman)

## Symptom

Grafana (and other) podman containers were not running. `sudo podman ps -a` showed
them as `Exited`, several with the misleading `Exited (0) 292 years ago` /
`FinishedAt: 0001-01-01` display artifact (unreliable state recorded after an
unclean host shutdown).

## Root cause

cygnus rebooted on **2026-06-17 05:27** (`uptime -s`). All rootful podman
containers went down with it and **nothing brought them back up**.

`podman-restart.service` was **disabled**. The containers have
`RestartPolicy: unless-stopped`, but that policy only restarts a container
*within a running podman session* — it does **not** survive a host reboot. For
rootful podman, `podman-restart.service` must be enabled to relaunch
restart-policy containers after boot. There were no systemd/quadlet units for
these containers either.

Note: rootless podman does not work in this LXC (`newuidmap ... Operation not
permitted`), so everything runs as `sudo podman` (rootful).

## Containers affected (all reboot casualties, all `unless-stopped`)

- grafana
- data-ingestion-api
- pgadmin_pgadmin_1
- servidor_quetren_1
- tuya-link  — also showed a stale `June 7` exit timestamp, but its app log
  (`/home/rsi/tuya-link/log/tuya_link.log`) proved it ran until 05:22 on
  Jun 17, i.e. same reboot. It carries `CLIENT_ID`/`CLIENT_SECRET` as env vars
  (set by compose), so it does **not** need `~/etc/tuya-web.env` (that file is
  only a fallback path in `bin/tuya_web.py`).

**nucbox-monitoring** was NOT affected: it is a real systemd service
(`/etc/systemd/system/nucbox-monitoring.service`, enabled), so it auto-started
on the reboot. The only blip was ~90 s of "Cannot reach Home Assistant" at boot
while HA (192.168.1.7:8123) was still coming up — self-resolved.

## Fix applied

```bash
# start the stopped containers
sudo podman start grafana data-ingestion-api pgadmin_pgadmin_1 servidor_quetren_1 tuya-link

# make restart-policy containers survive future reboots (requires sudo password)
sudo systemctl enable --now podman-restart.service
```

`podman-restart.service` is now **enabled + active**. Future reboots will bring
back any container whose restart policy is not `no`.

## Verify

```bash
sudo podman ps --format '{{.Names}} | {{.Status}}'
systemctl is-enabled podman-restart.service   # enabled
systemctl is-active  podman-restart.service   # active
```
