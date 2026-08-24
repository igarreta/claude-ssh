# MQTT broker migration: docker03 → dedicated gr-srv03 LXC (in progress)

**Status:** open
**Host:** mosquitto, docker03
**Supersedes:** —
**Superseded-by:** —

**Date started**: 2026-08-15

## Why

The mosquitto broker ran as a Docker container on docker03 (`192.168.1.8:1883`,
`allow_anonymous true`, plaintext, no ACLs, no auth). It's a hard dependency for Home
Assistant and TTato (boiler control), so it's moving to its own dedicated LXC — reduces
blast radius from docker03's other services, gives it independent restart/monitoring. While
rebuilding it, added username/password auth + per-client ACLs (stops any device on the LAN
from spoofing/hijacking topics it doesn't own) and TLS.

## Discovered MQTT clients (as of 2026-08-15, all still pointed at the old `192.168.1.8:1883`)

| Host | Client | File |
|---|---|---|
| docker03 | zigbee2mqtt (container) | `~/dockerfiles/zigbee2mqtt/data/configuration.yaml` — `mqtt.server: mqtt://mosquitto:1883` (Docker-network DNS name) |
| docker03 | mqtt-explorer (container) | UI-configured, no file |
| raspberrypi1 | TTato — 3 separate `mqtt.Client` instances | `TTato/bin/GlobalThreads.py` (`MQTT_BROKER` const, `_client_rtl`/`_client_oth`, connect calls ~L456/459/462) and `TTato/bin/TTato.py` (`mqtt_client`, connect at L258) |
| raspberrypi2z | rtl_433 | `/etc/rtl_433/rtl_433.conf` — `output mqtt://192.168.1.8:1883,...` |
| cygnus | tuya-link | `tuya_link.toml` (`[mqtt] host/port`) + `tuya_link.py` (`client.connect(...)`, no auth/TLS wiring today) |
| homeassistant | MQTT integration | UI/config-entry, not file-based; no SSH access to this host (password auth only) |

docker03's own `rtl_433` container/compose exists but is **not running** (superseded by
raspberrypi2z) — no migration needed there.

**raspberrypi2z's rtl_433 (v25.02, Debian armhf package) has no SSL support** — confirmed via
`ldd` (no libssl/libmosquitto linked). Decision: that one client stays on plaintext + auth
rather than maintaining a custom TLS-enabled build for one sensor node on the same LAN.

## New broker — done

- gr-srv03, VMID 105, hostname `mosquitto`, Debian 13 (trixie), unprivileged LXC
- `pct config`: 2 cores, 512MB mem + 512MB swap, 6GB disk, `net0` on `vmbr0`
- Was missing TUN device passthrough (same class of issue cygnus/ceres/castor needed fixed) —
  added `lxc.cgroup2.devices.allow: c 10:200 rwm` and
  `lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file` to `/etc/pve/lxc/105.conf`,
  `pct reboot 105`, tailscaled now starts fine.
- Tailscale IP: `100.69.153.63` (added to `.mcp.json`/`mcp-connectors.md`/`CLAUDE.md` as `mosquitto`)
- **LAN IP: `192.168.1.198`, now static** — set as a DHCP reservation at the router 2026-08-16,
  same address it already had. TLS cert SAN was already bound to this IP, so no cert
  regeneration needed.
- mosquitto installed **native** via `apt` (not containerized) — avoids the podman-restart-policy
  class of bug already seen on cygnus (`docs/2026-06-22_cygnus_podman-restart-after-reboot.md`),
  fewer moving parts for a critical service.

## Broker config

- `/etc/mosquitto/conf.d/broker.conf`: `per_listener_settings false`, `allow_anonymous false`,
  global `password_file`/`acl_file`.
- `listener 1883` — plaintext, auth required. Only raspberrypi2z's rtl_433 user is expected here.
- `listener 8883` — TLS. `cafile`/`certfile`/`keyfile` under `/etc/mosquitto/certs/`, self-signed
  CA (10-year validity — chosen to avoid a renewal process for a broker designed to run without
  internet dependency; **CA/server cert expire ~2036-08-15**, note for a future reminder).
- Users (one per client) in `/etc/mosquitto/passwd`: `ttato`, `rtl433_pi2z`, `zigbee2mqtt`,
  `tuyalink`, `homeassistant`, `mqttexplorer`, `admin`.
- ACLs in `/etc/mosquitto/acl`:
  - `ttato`: readwrite `TTato/#`; read `rtl_433/raspberrypi2z/#`, `zigbee2mqtt/#`, `granev/temp/#`; write `homeassistant/#`
  - `rtl433_pi2z`: readwrite `rtl_433/raspberrypi2z/#`; write `homeassistant/#`
  - `zigbee2mqtt`: readwrite `zigbee2mqtt/#`; write `homeassistant/#`
  - `tuyalink`: readwrite `tuya-link/#`; write `homeassistant/#`
  - `homeassistant`: broad `#` (it's the automation hub)
  - `mqttexplorer`: read-only `#`
  - `admin`: broad `#`, for manual `mosquitto_pub`/`sub` debugging
- **Credentials**: generated randomly by the setup script, saved to
  `/home/rsi/mosquitto-credentials.txt` on the mosquitto host itself (600, rsi-owned) — **not
  committed to git**. CA cert (public, safe to distribute) at `/etc/mosquitto/certs/ca.crt`.

Verified 2026-08-15: anonymous connections rejected on both listeners, wrong password rejected,
TLS handshake works against the SAN IP, ACL correctly blocks a scoped user's out-of-topic
publish while allowing its own topics.

## Provisioning gap found and fixed (2026-08-16)

105 was created with `/opt/proxmox-grsrv03/lxc-provisioning/provision-lxc.sh`, invoked with a
`--disk` smaller than template 900's 6GB. `pct resize` can't shrink, so that step failed;
`set -e` (no error trap) killed the script right there — **before** it reached the Tailscale
TUN config, container start, or any step after. Root-caused via
`/var/log/lxc-provision-105-20260815-200327.log` on gr-srv03 (last line: `unable to shrink
disk size`). Script fixed (commit `2b6e866` in `igarreta/proxmox-grsrv03`, not yet pushed to
origin): preflight now rejects `--disk` smaller than the template and exits cleanly before
touching anything.

Since the container was already TUN-patched, started, and had the mosquitto broker configured
manually afterward (see above), only the generic provisioning steps were still missing. Fixed
directly on 105:
- `mp0` shared-secrets mount (`/opt/shared-secrets` → `/mnt/secrets`, ro) — **this was the
  reported "secrets not working" bug**; `/mnt/` was completely empty
- `mp1` backup mount (`/mnt/backup_usb1/mosquitto` → `/mnt/backup`), host dir created +
  chowned to the unprivileged-container-mapped uid/gid (101000:101000)
- `keyctl=1` feature (was `nesting=1` only)
- `onboot: 1` (container would not have auto-started after a gr-srv03 reboot)
- SSH hardening (password auth was still at Debian defaults, unlike other LXCs)
- `~/bin` was 8+ months stale (never `git pull`led) — updated; `.bashrc` now sources
  `bin/bashrc.sh`; `backup.sh` cron job added
- Timezone was UTC, set to `America/Argentina/Buenos_Aires`
- Secrets symlink automation (`~/bin/update-secrets` symlink + daily 00:35 cron) set up and
  run once — confirmed working (`~/etc/*`, `~/.ssh/authorized_keys` now populated from
  `/mnt/secrets`)

Applied via a `pct reboot 105` (safe — no MQTT clients migrated yet, see "Still to do" below)
to pick up the mount points and `keyctl` feature.

**Incident during the fix**: a multi-line `bash -c` SSH-hardening command sent through the
gr-srv03 MCP `run-command` tool had its newlines silently collapsed in transport, merging
several statements onto one line. Control operators then reinterpreted the merged text,
corrupting `sshd_config` (extra tokens appended to the `PasswordAuthentication` line) and
taking `ssh.service` down on 105 for a few minutes. Recovered via `pct exec` (unaffected by
sshd being down) — removed the bad line, reapplied each `sed` as its own single-line command,
validated with `sshd -t`, restarted, and confirmed key-based login worked again. New rule
recorded in `CLAUDE.md`: never send a multi-line command body through an MCP SSH
`run-command`/`privileged-command` tool — one command per call, or write a script locally and
`scp` it over for anything multi-step.

The disk itself was never a problem — `pct resize` refused before touching the volume, so 105
kept a clean 6GB disk (the template's size), just larger than whatever was originally
requested.

## Client cutover progress

- **docker03 mqtt-explorer**: **done, 2026-08-16.** Reconfigured via its web UI. Briefly
  exposed over HTTPS with `sudo tailscale serve --bg 4000` on docker03 (assumed the plain
  HTTP UI on :4000 would be blocked) — turned out plain `http://docker03:4000/` works fine on
  the LAN, so the serve proxy was unnecessary and has been reset (`sudo tailscale serve
  reset`). New connection: host `192.168.1.198`, port `8883`, user `mqttexplorer`.
  - The `smeagolworms4/mqtt-explorer` browser-packaged fork's "Server Certificate (CA)" file
    upload picker is broken (opens an error dialog, never lands a file on disk, no error in
    `docker logs`) — worked around by leaving encryption **on** but **Validate Certificate
    off**. Traffic is still TLS-encrypted and auth still applies; only CA-pinning against a
    LAN MITM is lost for this one debug tool.
  - Hit one real bug getting there: the UI's Port field silently stayed `1883` after toggling
    Encryption on, so the client sent a TLS ClientHello at the plaintext listener — mosquitto
    logged `New connection ... disconnected due to protocol error` (ciphertext failing to
    parse as an MQTT packet). Fix was simply setting Port to `8883` to match. Confirmed
    working end-to-end with a `mosquitto_pub`/UI round-trip test.
  - Old docker03 broker connection left in place per the cutover-order/parallel-run plan below.

## Still to do

1. Update each remaining client (write-local-then-scp per this repo's convention):
   - **docker03 zigbee2mqtt**: `configuration.yaml` → `mqtt.server: mqtts://192.168.1.198:8883` +
     `mqtt.ca`/`mqtt.user`/`mqtt.password`; mount `ca.crt` into the container via `compose.yaml`.
   - **raspberrypi1 TTato**: add `MQTT_PORT`/`MQTT_USER`/`MQTT_PASS`/`MQTT_CA` constants in
     `GlobalThreads.py`; call `.tls_set(ca_certs=MQTT_CA)` + `.username_pw_set(...)` on all 3
     client instances before `.connect()`; `docker restart TTato`.
   - **raspberrypi2z rtl_433**: update `output mqtt://...` in `rtl_433.conf` to the new IP +
     `user=rtl433_pi2z,pass=...` (plaintext, no TLS); restart `rtl433.service` (needs sudo
     password — write locally, scp, hand the sudo command to the user).
   - **cygnus tuya-link**: add `user`/`pass`/`ca_cert` to `tuya_link.toml`; small code change in
     `tuya_link.py` to call `client.username_pw_set(...)` + `client.tls_set(...)` before
     `client.connect(...)`; `sudo podman restart tuya-link` (passwordless on cygnus).
   - **Home Assistant**: manual UI step (Settings → Devices & Services → MQTT → Reconfigure) —
     new host/port/user/pass, enable TLS, upload the CA cert. No SSH/API access to this host in
     the migration session.
2. Cutover order: ~~mqtt-explorer~~ → rtl_433 → zigbee2mqtt → tuya-link → TTato → Home Assistant
   last (most critical). Keep docker03's old broker running in parallel until each client is
   confirmed working on the new one.
3. After a stable cutover, decommission the docker03 mosquitto container/compose.
4. Add `log-monitor/hosts/mosquitto.conf` once the host is stable, so its logs join the daily
   automated review.
