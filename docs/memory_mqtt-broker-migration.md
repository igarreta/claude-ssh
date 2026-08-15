# MQTT broker migration: docker03 → dedicated gr-srv03 LXC (in progress)

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
- **LAN IP: `192.168.1.198`, DHCP-assigned — not yet static.** Fixed IPs are set at the router;
  user didn't have access at migration time. TLS cert SAN is bound to this IP; if/when it moves
  to a static address, **regenerate the server cert** (`openssl` commands in
  `/tmp/mosquitto-setup.sh` history, or redo the CA-signing steps) with the new SAN before
  pointing any client at it.
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

## Still to do (deferred until the static IP is set)

1. Get a static LAN IP assigned at the router, then regenerate the server TLS cert with the new SAN.
2. Update each client (write-local-then-scp per this repo's convention):
   - **docker03 zigbee2mqtt**: `configuration.yaml` → `mqtt.server: mqtts://<new-ip>:8883` +
     `mqtt.ca`/`mqtt.user`/`mqtt.password`; mount `ca.crt` into the container via `compose.yaml`.
   - **docker03 mqtt-explorer**: reconfigure manually in its web UI.
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
3. Cutover order: mqtt-explorer → rtl_433 → zigbee2mqtt → tuya-link → TTato → Home Assistant
   last (most critical). Keep docker03's old broker running in parallel until each client is
   confirmed working on the new one.
4. After a stable cutover, decommission the docker03 mosquitto container/compose.
5. Add `log-monitor/hosts/mosquitto.conf` once the host is stable, so its logs join the daily
   automated review.
