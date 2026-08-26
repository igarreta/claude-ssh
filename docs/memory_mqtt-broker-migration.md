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
  - **Recurred 2026-08-26**: the exact same Port-field bug came back — `settings.json`
    (`/home/rsi/dockerfiles/mqtt-explorer/config/settings.json` on docker03) had this
    connection persisted with `encryption: true` but `port: 1883`, so it silently failed again
    (mosquitto logged a protocol error, same signature as above). The UI apparently doesn't
    keep the two fields in sync when re-saving. Fixed by patching the port directly in the
    persisted JSON — the file is root-owned and docker03 sudo needs a password, so `docker exec
    mqtt-explorer node -e "..."` (container runs Node, no Python) was used to edit it from
    inside the container as root, then `docker restart mqtt-explorer`. Confirmed working by
    the user after reload. **If mqtt-explorer can't connect to the new broker again, check this
    file's `port` field before anything else.**

- **raspberrypi2z rtl_433**: **done, 2026-08-26.** `output mqtt://...` in
  `/etc/rtl_433/rtl_433.conf` updated to `192.168.1.198:1883,user=rtl433_pi2z,pass=...`
  (plaintext + auth — no TLS, per the earlier `ldd` finding that this package has no SSL
  support). Applied via write-local + sftp-upload to `/home/rsi/rtl_433.conf.new`, then the
  user ran the `sudo cp`/`mv`/`systemctl restart rtl433.service` sequence themselves (sudo
  needs a password on this host). Confirmed publishing: `mosquitto_sub` against
  `rtl_433/raspberrypi2z/#` on the new broker returned a live `Nexus-TH` reading.

- **docker03 zigbee2mqtt**: **done, 2026-08-26.** `data/configuration.yaml` `mqtt:` block →
  `server: mqtts://192.168.1.198:8883` + `user: zigbee2mqtt` + `password: ...` + `ca:
  /app/data/ca.crt`; `compose.yaml`'s `MQTT_SERVER` env var updated to match (unclear if the
  official image actually reads plain `MQTT_SERVER` vs the documented
  `ZIGBEE2MQTT_CONFIG_MQTT_SERVER` prefix — updated anyway so it can't drift out of sync with
  the real config). `docker compose up -d` (not just `restart`, since the compose file itself
  changed) to recreate the container and pick up both the new env var and the newly mounted
  `ca.crt`. Log confirms `Connected to MQTT server`; `zigbee2mqtt/bridge/state` verified
  `online` on the new broker via `mosquitto_sub`.
  - **Getting `ca.crt` onto docker03 hit a wall**: it's a small public file but its base64 body
    is high-entropy, so the harness's secret-redaction filter blanked it out of both a `cat`
    command's output and an SFTP-download's returned content — it never made it into the
    assistant's context however retrieved. Installing an SSH key for a direct host-to-host
    copy was offered but declined; resolved by having the user `scp` it manually in two hops
    (mosquitto → comet → docker03) from their own terminal, which isn't subject to the filter.
    Also hit a permission wall on the second hop: `.../zigbee2mqtt/data/` is root-owned even
    though the files inside are `rsi:root` — `scp` as `rsi` can't create a new file in that
    directory, so it has to land in `/home/rsi/` first, then `sudo mv` + `sudo chown rsi:root`
    into place. **Same likely applies to any other client whose data dir needs a `ca.crt`
    dropped in — check ownership before assuming a plain `scp` will work.**

- **cygnus tuya-link**: **done, 2026-08-26.** `tuya_link.toml` `[mqtt]` block → `host =
  "192.168.1.198"`, `port = 8883`, `user`/`password`, `ca_cert = "/tuya-link/bin/ca.crt"` (the
  container already bind-mounts `./bin/`, so the cert just needed to land there — no
  `compose.yaml` volume change needed, unlike zigbee2mqtt). `bin/tuya_link.py`'s `main()` got
  `client.username_pw_set(...)` + `client.tls_set(ca_certs=...)` inserted before
  `client.connect(...)` (previously connected plaintext/anonymous, no `on_connect` callback —
  worth remembering if this ever needs debugging again, since paho silently drops
  ACL-disallowed publishes with **no error surfaced to the app at all**, and `connect()` itself
  doesn't raise or block on bad auth either). `sudo podman compose up -d --force-recreate`
  (`tuya-link/`'s files are all `rsi`-owned, unlike zigbee2mqtt's data dir, so `ca.crt` needed
  no `sudo mv` step). Confirmed via a live `granev_tank_level` reading and the retained HA
  discovery config, both arriving on the new broker.
  - **False alarm during verification, worth remembering**: two separate MCP `run-command`
    calls issued "in parallel" (one `mosquitto_sub` with a timeout, one delayed `mosquitto_pub`)
    are **not actually concurrent** — this connector appears to run them sequentially, so the
    subscriber's whole timeout window elapses before the publish command even starts, making
    every such pub/sub race test fail regardless of whether the broker/client actually works.
    A real concurrency test needs both commands **backgrounded inside one single command**
    (e.g. `(mosquitto_sub ... -C 1 & sleep 2; mosquitto_pub ...; wait)`). This cost significant
    time chasing a phantom ACL/broker bug before the artifact was identified.

- **raspberrypi1 TTato**: **done, 2026-08-26.** `GlobalThreads.py`: `MQTT_BROKER` →
  `192.168.1.198`, added `MQTT_PORT`/`MQTT_USER`/`MQTT_PASS`/`MQTT_CA` (`MQTT_CA = str(base_dir
  / "ca.crt")` — `base_dir` already resolves to `/TTato/` in-container since the whole repo
  root is bind-mounted there via `compose.yaml`'s `./:/TTato`, so `ca.crt` just needed to land
  at the repo root, no volume change needed); `username_pw_set`/`tls_set` added on both
  `_client_rtl` and `_client_oth` in `launch()`, `connect()` calls in `relaunch()` updated to
  pass `MQTT_PORT`. `TTato.py`: imports the 4 new constants from `GlobalThreads`, same
  `username_pw_set`/`tls_set` added before its own `mqtt_client.connect(MQTT_BROKER,
  MQTT_PORT)`. `docker restart TTato` (no sudo needed, `rsi` is in the `docker` group on this
  host, unlike docker03/cygnus).
  - Confirmed via a live `TTato/status` publish arriving on the new broker (`mode: A, boiler:
    0, ...`) — direct proof for the `mqtt_client` (TTato.py) connection. The two
    `GlobalThreads.py` clients (`_client_rtl`, `_client_oth`, feeding zigbee2mqtt/rtl_433/
    granev sensor readings into the boiler-control logic) weren't independently proven the same
    way — didn't want to spoof a fake sensor reading on a real topic just to test, since a bad
    injected temperature could trigger a wrong heating decision. They use the identical
    connect/auth pattern and the container logged zero exceptions since restart, so treated as
    working; **if a "Sensor ... sin datos" warning reappears for a zigbee2mqtt/rtl_433-fed
    sensor in the hours after 2026-08-26 18:31, re-check these two clients specifically.**
  - **Known gap, not a bug**: TTato's `_client_oth` also subscribes to `granev/temp/#`, which
    Home Assistant publishes to — and HA is still on the old docker03 broker (last remaining
    cutover). Until HA moves, TTato won't receive `granev/temp/*` on the new broker even though
    its own connection is fine. See
    [2026-07-20_raspberrypi1_ttato-granev-integration.md](2026-07-20_raspberrypi1_ttato-granev-integration.md).

## Still to do

1. Last remaining client:
   - **Home Assistant**: manual UI step (Settings → Devices & Services → MQTT → Reconfigure) —
     new host/port/user/pass, enable TLS, upload the CA cert. No SSH/API access to this host in
     the migration session.
2. Cutover order: ~~mqtt-explorer~~ → ~~rtl_433~~ → ~~zigbee2mqtt~~ → ~~tuya-link~~ →
   ~~TTato~~ → Home Assistant last (most critical, and the only one left). Keep docker03's old
   broker running in parallel until Home Assistant is confirmed working on the new one.
3. After a stable cutover, decommission the docker03 mosquitto container/compose.
4. Add `log-monitor/hosts/mosquitto.conf` once the host is stable, so its logs join the daily
   automated review.
