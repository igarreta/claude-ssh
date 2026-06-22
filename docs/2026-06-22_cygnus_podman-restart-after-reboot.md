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

## Container dependency chain (data ingestion)

Discovered while investigating the same reboot (2026-06-22):

```
servidor_quetren_1  --POST barrera events-->  data-ingestion-api  --asyncpg-->  castor homelab DB
  (net servidor_default,           (host :8000, published          (10.0.100.11:5432 over vmbr1,
   posts to API_URL                 0.0.0.0:8000; net               user ingestion_api, db homelab)
   http://10.89.0.1:8000)           data-ingestion-api_default)
```

- quetren reaches the API via the host gateway `10.89.0.1:8000` (the API's
  published port). This works **only if data-ingestion-api is up**.
- A quetren warning `API barrera POST error ... Cannot connect to host
  10.89.0.1:8000` almost always means **data-ingestion-api is down/crash-looping**,
  not a quetren problem. quetren keeps recording regardless ("no afecta grabación").
- data-ingestion-api in turn depends on castor PostgreSQL listening on
  `10.0.100.11:5432`. See `docs/2026-05-29_castor_postgresql-setup.md`
  (Incident 2026-06-22) — a missing `10.0.100.11` in castor's `listen_addresses`
  caused data-ingestion-api to crash-loop (RestartCount 2013) and broke this chain.
