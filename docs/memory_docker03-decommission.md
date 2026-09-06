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
- **rtl_433** — **permanently test/backup role, not a migration target for raspberrypi2z**
  (confirmed 2026-09-05: gr-srv03 is the wrong physical location for antenna reception of the
  sensors raspberrypi2z currently captures — this isn't a "not yet migrated" gap, it's a
  standing decision). → separate own LXC, own USB dongle, kept off both z2m's LXC and cygnus
  so a flaky non-critical USB device can't destabilize either.
  **CT207 created and proven working 2026-09-05** (rtl-433 installed, host USB/udev/DVB-driver
  passthrough done, live sensor reception verified) — see
  [memory_rtl433-lxc-ct207.md](memory_rtl433-lxc-ct207.md). Dongle physically moved from
  docker03 and re-tested 2026-09-05 (second session); currently disconnected again and CT207
  stopped between tests. Still pending: `rtl_433.conf` + systemd service (only worth writing
  once the dongle is left permanently attached).
- Both new LXCs get a beszel-agent (reporting to the existing hub on contabo2 —
  lightweight, gives disk-space/host alerting per-host, not shared).

### cloudflaretunnel — goes to CT103, not cygnus

**Correction 2026-09-05**: earlier plan below assumed cygnus; actual destination is **CT103**
(dedicated LXC, `100.100.91.26` Tailscale / `192.168.1.14` LAN), running `cloudflared` bare
via systemd (`/etc/systemd/system/cloudflared.service`, `tunnel run --token ...`), not
podman — already live and healthy as of 2026-09-05 20:28 UTC. Serves `proxmox03-ct.granev.casa`,
one of three ways to reach gr-srv03's Proxmox UI (alongside Tailscale direct and local LAN IP)
— cygnus plays no role in Proxmox access. docker03's old `cloudflaretunnel` container
**stopped 2026-09-05** — CT103 is now the sole active connector.

Added `--metrics 100.100.91.26:2000` to CT103's `cloudflared` command (systemd unit edited
in place with `sed`, token untouched) so uptime-kuma has a real health signal: cloudflared's
own `/ready` endpoint, bound to CT103's Tailscale IP only. **Why this matters**: hitting the
public `proxmox03-ct.granev.casa` hostname is *not* a valid health check — Cloudflare Access
returns its login-redirect at the edge regardless of whether the tunnel connector is up, so it
can't detect an actual outage. uptime-kuma's monitor #2 (renamed `cloudflare tunnel (CT103)`)
now hits `http://100.100.91.26:2000/ready` directly and is confirmed passing.

### cygnus (existing LXC, podman) — everything non-USB

- **uptime-kuma** — **migrated 2026-09-05**: `kuma.db` (sqlite, ~326 MB uncompressed) tarred
  from docker03's named volume via a helper `alpine` container (avoids host-side root
  permission issues on the volume), relayed through comet's local disk (`scp`, MCP's own
  sftp tools reject anything over 1 MB), extracted into `~/uptime-kuma/data` on cygnus.
  Compose at `~/uptime-kuma/compose.yaml`, `restart: unless-stopped`. All 13 monitors came
  across intact. Two needed IP-address fixups after the move (cygnus's Tailscale IP,
  `100.96.140.37`, differs from docker03's): **PostgreSQL castor** — fixed by adding a
  `pg_hba.conf` line for the new IP (`~/etc/postgresql/17/main/pg_hba.conf` on castor,
  reloaded). **cloudflare** (was a `docker` monitor type against `/var/run/docker.sock`) —
  handled by enabling `podman.socket` on cygnus (`sudo systemctl enable --now podman.socket`,
  needs a password, user ran it) and initially remapping it to `/run/podman/podman.sock`, then
  **superseded by the CT103 fix above** once it turned out cloudflaretunnel isn't moving to
  cygnus at all — the monitor is now a plain HTTP check against CT103's `/ready`, the podman
  socket remap is currently unused by this monitor but left enabled (harmless, may be useful
  for a future docker-type monitor against cygnus's own containers).
- **mqtt-explorer** — **migrated 2026-09-05**: `config/settings.json` (already
  TLS-configured for the new mosquitto broker, see
  [memory_mqtt-broker-migration.md](memory_mqtt-broker-migration.md)) copied verbatim via
  `scp` through comet, real broker credentials intact. Compose at
  `~/mqtt-explorer/compose.yaml`, `restart: unless-stopped`. Verified serving on `:4000`.
- **iperf3** — run ad hoc (`podman run`) on demand, not an always-on service. **Done
  2026-09-05**: `networkstatic/iperf3` (same image as docker03) pulled and smoke-tested on
  cygnus via `sudo podman run --rm networkstatic/iperf3 --version`.
- cron: `backup.sh` needs **no migration** — cygnus already runs its own identical copy of
  this generic per-host script (confirmed 2026-09-05; it backs up each host's own `~/etc`/
  `~/bak`, not docker03-specific data). `proxmox_backup_checker` **migrated 2026-09-05**: repo
  cloned fresh (`git clone --recurse-submodules`) to `~/proxmox_backup_checker` on cygnus, venv
  rebuilt, `var/config.yaml` copied verbatim (paths already match since cygnus's new `mp5`
  mount, added 2026-09-05, covers the whole backup_usb1 tree at the same absolute path — see
  the NFS/mount bullet below). Cron added
  at 8:05, same slot as docker03. **Email enabled 2026-09-05**: real SMTP creds copied from
  docker03's `~/etc/smtp.env` (gmail relay) over the placeholder `disabled.invalid` one, and
  a test run confirmed `Email sent successfully to 1 recipients`. `var/config.yaml` still has
  `to_email: []` — the script falls back to `smtp.env`'s `TO_EMAIL` when the config list is
  empty. Before the fix, the placeholder host caused a DNS-lookup `ERROR` on every run despite
  all backups passing, which log-monitor escalated to Pushover as a false "crash" alert.
  Pushover itself (shared-secrets `pushover.env`) is confirmed working independently. Uptime
  Kuma heartbeat in the script still fails (logged, non-fatal) until uptime-kuma itself moves
  to cygnus.
- fail2ban — not currently installed on cygnus, needs adding.
- beszel-agent — **confirmed already installed and running natively** on cygnus (2026-09-05,
  `systemctl status beszel-agent`, binary at `/opt/beszel-agent`, not a podman container —
  that's why `podman ps` doesn't show it). It correctly alerted on the 2026-09-05 disk-full
  incident (see [2026-09-05_cygnus_disk-full-podman-storage.md](2026-09-05_cygnus_disk-full-podman-storage.md)). No migration needed.
- Backup mounts: cygnus's existing `mp1`/`mp3`/`mp4` bind mounts
  ([2026-05-28_cygnus_backup-usb1-data-mount-and-quetren-grabaciones.md](2026-05-28_cygnus_backup-usb1-data-mount-and-quetren-grabaciones.md))
  are all scoped to cygnus's own subtree (`/mnt/backup_usb1/cygnus`, `/gickup`, `/data/cygnus`)
  — not usable as-is for `proxmox_backup_checker`, which needs to read *other* hosts'
  subtrees too. Added **`mp5: /mnt/backup_usb1,mp=/mnt/backup_usb1,ro=1`** (2026-09-05,
  read-only, whole tree, applied live with no restart) instead of an NFS mount — gr-srv03
  exposes backup_usb1 to LXCs via direct bind mount (`mp`), not NFS; NFS is only used for the
  VM (docker03), which can't get LXC-style bind mounts.

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

`cloudflaretunnel`, `uptime-kuma`, and `mqtt-explorer` on docker03 were **stopped 2026-09-05**
(not removed) now that CT103/cygnus are confirmed as their live replacements — remaining
docker03 items still running: `zigbee2mqtt` (kept as explicit rollback, see
[memory_zigbee2mqtt-migration.md](memory_zigbee2mqtt-migration.md)), `backup.sh`/`proxmox_backup_checker` crons (superseded by
cygnus's own copies but not yet disabled on docker03 itself), and whatever host services were
never explicitly stopped (see the 2026-08-27 inventory above).
