# docker03 decommission plan

**Status:** open
**Host:** docker03, cygnus, gr-srv03 (fleet)
**Supersedes:** —
**Superseded-by:** —

**Date started:** 2026-08-27. Planning only — execution not yet started.

## Why

docker03 (VM 102 on gr-srv03) is being decommissioned. This doc is the inventory of
everything running there and the agreed destination for each piece, decided in planning
conversation on 2026-08-27 before any execution.

## Inventory taken 2026-08-27

Docker containers (running): zigbee2mqtt, cloudflaretunnel, portainer, uptime-kuma,
beszel-agent, mqtt-explorer. Stopped/stale: mosquitto (deliberately stopped 2026-08-26, see
[memory_mqtt-broker-migration.md](memory_mqtt-broker-migration.md)), iperf3-server, mqtt_log. Host services: apache2
(default page only), fail2ban, rpcbind, supervisor (enabled, no configs — inert), tailscaled,
containerd, qemu-guest-agent. Cron (`rsi`): `backup.sh` (02:07), `proxmox_backup_checker`
(08:05), `zigbee2mqtt-watchdog.sh` (*/5 min); commented-out/inactive: dynu.sh, rclone-copy,
findata.py, a notion-compose puller. Mounts: NFS from gr-srv03 (`/mnt/backup`,
`/mnt/backup_usb1`), CIFS from Home Assistant (`/mnt/hassio/*`, 7 shares, confirmed unused),
CIFS from WDMyCloud (confirmed unused). Orphaned compose projects present but not running:
dashy, python-test, pishrink, nginx, plex, immich-app, jellyfin, mariadb, db_store, auth_token,
notion, pool_heat.

## Decisions

### New dedicated LXCs (bare/native install, no podman) — 3 GB disk each

Built from **CT901** (`deb13templ2`), a new 3 GB template restored from CT900's own vzdump —
done 2026-08-28, see
[2026-08-28_gr-srv03_ct901-new-template.md](2026-08-28_gr-srv03_ct901-new-template.md) for how
and its full inventory (sudo password required, baked-in personal GitHub deploy key, etc.).
**CT900 kept, not deleted** — user chose to retain it for now (2026-08-28), harmless since it's
no longer the clone source. Sizing based on mosquitto's real usage as the closest comparable
(bare Debian 13 + one native service): 1.8 GB used of 5.9 GB (1.3 GB base OS, 502 MB
`/var`). 3 GB covers either service with growth margin.

- **zigbee2mqtt** → own LXC, USB passthrough for the zigbee coordinator dongle. Critical
  path for Home Assistant and TTato (house heating) — isolated from every other service
  because **container isolation does not protect against USB/kernel-bus instability, only
  the LXC/VM boundary does** (the earlier zigbee RF/hot-plug USB saga, see
  [2026-08-24_docker03_zigbee-coordinator-rf-degradation.md](2026-08-24_docker03_zigbee-coordinator-rf-degradation.md),
  was host-level, not container-level). Runs bare Node.js, no podman — mirrors mosquitto's
  native-install reasoning (one less moving part for a critical service).
  `zigbee2mqtt-watchdog.sh` cron job moves here with it.
- **rtl_433** (backup/test role only — raspberrypi2z remains production, see
  [memory_rtl-test.md](memory_rtl-test.md)) → separate own LXC, own USB dongle. Not critical, but kept
  off both z2m's LXC and cygnus so a flaky non-critical USB device can't destabilize either.
  **CT207 created and proven working 2026-09-05** (rtl-433 installed, host USB/udev/DVB-driver
  passthrough done, live sensor reception verified) — see
  [memory_rtl433-lxc-ct207.md](memory_rtl433-lxc-ct207.md). Dongle was only temporary for the
  test and has been removed again; CT207 is stopped. Still pending: physical dongle move from
  docker03, `rtl_433.conf` + systemd service, fail2ban/beszel-agent.
- Both new LXCs get: fail2ban, a beszel-agent (reporting to the existing hub on contabo2 —
  lightweight, gives disk-space/host alerting per-host, not shared).

### cygnus (existing LXC, podman) — everything non-USB

- **cloudflaretunnel** — redeploy with the same tunnel token. Serves
  `proxmox03-ct.granev.casa`, the backup path to gr-srv03's Proxmox UI when the primary
  `proxmox03.granev.casa` route (direct to gr-srv03) has issues. The ingress rule itself
  lives in the Cloudflare dashboard, not locally — confirm it still resolves correctly once
  the tunnel connector runs from cygnus instead of docker03.
- **uptime-kuma**
- **mqtt-explorer** — already TLS-configured for the new mosquitto broker
  ([memory_mqtt-broker-migration.md](memory_mqtt-broker-migration.md)), redeploy as-is.
- **iperf3** — run ad hoc (`podman run`) on demand, not an always-on service.
- cron: `backup.sh`, `proxmox_backup_checker` (needs its Python venv rebuilt on cygnus).
- fail2ban — not currently installed on cygnus, needs adding.
- beszel-agent — confirm cygnus doesn't already have one before adding (MCP couldn't check;
  `sudo podman` here hits the "privileged commands blocked" policy even though it's
  passwordless — check manually).
- NFS `/mnt/backup` mount for `backup.sh` — check whether cygnus's existing backup-usb1 setup
  ([2026-05-28_cygnus_backup-usb1-data-mount-and-quetren-grabaciones.md](2026-05-28_cygnus_backup-usb1-data-mount-and-quetren-grabaciones.md))
  already covers this before creating a new mount.

### Deprecated — removed, not migrated

mosquitto container/compose, pool_heat, dynu.sh, mqtt_log/mqtt-resend, apache2 (stock
default install, unrelated to the Cloudflare tunnel), portainer (dropped — container
management going forward is done directly, not through a UI), and all dead orphaned compose
projects listed above.

### Left as-is, not migrated

CIFS mounts to Home Assistant and WDMyCloud — confirmed unused; leave documented as possible
future use, don't recreate on the new hosts now.

### docker03 itself

After cutover is verified, leave the VM **stopped** for a cooldown period — not indefinite,
the disk space is needed back. Exact duration not yet decided.

## Still open (non-blocking, resolve during execution)

1. Exact NFS backup-mount path for the two new LXCs, and whether cygnus's existing backup
   mount can just be extended.
2. Naming/IP assignment for the two new LXCs.
3. Cooldown duration for docker03 before final deletion.
