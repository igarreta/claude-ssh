# zigbee2mqtt migration: docker03 (container) → CT206 (native)

**Status:** open
**Host:** docker03, zigbee2mqtt (CT206), gr-srv03
**Supersedes:** —
**Superseded-by:** —

**Status detail:** planned 2026-08-28. Phase 1 (prepare CT206) complete 2026-08-28, including
the Tailscale join; phases 2–5 (state copy, dongle move, cutover, cleanup) deliberately
deferred to another day. docker03 still serves Zigbee untouched in the meantime.

## Why

zigbee2mqtt is the last critical-path service on docker03, which is being decommissioned
([memory_docker03-decommission.md](memory_docker03-decommission.md)). It feeds Home Assistant
and TTato house heating, so it gets its own dedicated LXC — CT206 `zigbee2mqtt`, 10.0.100.12 —
rather than a slot on cygnus, because container isolation does not protect against USB/kernel-bus
instability; only the LXC/VM boundary does.

Two things make this delicate:

1. **The Zigbee network must survive** — re-pairing 11 devices, several outdoors or wall-mounted,
   is the outcome this plan exists to avoid.
2. **The USB passthrough model changes completely** — docker03 is a VM using QEMU passthrough
   (`usb2: host=10c4:ea60`); CT206 is an *unprivileged* LXC, where the device node must be
   bind-mounted **and** have its ownership shifted into the container's id range. This is the
   step most likely to fail silently.

## Why no devices need re-pairing

A Zigbee network's identity lives in three places, and all three are preserved:

| What | Where it lives now | How it survives |
|---|---|---|
| Network key, PAN ID, ext PAN ID, channel 11 | Pinned explicitly in `configuration.yaml` **and** in the coordinator's NVRAM | Config copied verbatim; the same physical dongle moves across |
| Device registry (IEEE addrs, network addrs, endpoints, bindings) | `data/database.db` | Copied verbatim |
| Coordinator NVRAM backup | `data/coordinator_backup.json` | Copied verbatim |

Because `advanced.network_key`, `pan_id` and `ext_pan_id` are already written out explicitly
(not left to auto-generate), the network is fully reproducible.

**Hard rule: never let z2m start against an empty `data/` directory while the dongle is
attached.** That is the one action that would form a new network and force re-pairing. The
service is installed disabled and only started after data is in place.

## Established facts (investigated 2026-08-28)

- **Dongle**: Itead Sonoff Zigbee 3.0 USB Dongle Plus **V2**, `10c4:ea60`, serial
  `c4ba7c03e773ef11beaee41e313510fd`, root-hub port `1-3` (direct, not on the powered hub).
  Adapter `ember`, 115200 baud.
- **gr-srv03** already has `cp210x` + `usbserial` loaded. `/dev/ttyUSB0` is absent only because
  QEMU holds the device; it appears as soon as VM 102 releases it.
- **Node.js**: z2m 2.12.0 `engines` is `^20.15.0 || ^22.2.0 || ^24`. Debian 13 ships
  `nodejs 20.19.2` — satisfies it, so **no NodeSource repo** is needed and z2m stays in the
  distro security stream (same reasoning as the native mosquitto install).
- **CT206 is directly SSH-able from comet** at `10.0.100.12` — both are on vmbr1, and
  `provision-lxc.sh` installs `authorized_keys` (password auth is off). Prefer this over
  `pct exec` from gr-srv03: no 60-second MCP command window, so long builds run normally.
  Root actions still need `pct exec` (CT206 sudo requires a password, inherited from CT901).
- **Footprint**: `/app` 198 MB total, `node_modules` only 87 MB (production-pruned). Old logs
  111 MB across 10 directories.
- **Networking**: CT206 → `192.168.1.198:8883` verified reachable via the `10.0.100.1` gateway.
- **MQTT**: user `zigbee2mqtt`, TLS 8883, CA CN `mosquitto-broker-ca` (valid to 2036).
  **No broker-side change needed** — mosquitto authenticates by username, not source IP
  ([memory_mqtt-broker-migration.md](memory_mqtt-broker-migration.md)).
- **Home Assistant needs no changes** — z2m publishes via MQTT discovery on the unchanged
  `zigbee2mqtt` base topic to the unchanged broker.

## Decisions taken

- Frontend reached via **Tailscale on CT206** (it is on vmbr1 with no LAN address).
- Disk grown **3 GB → 4 GB** — the 3 GB sizing came from mosquitto (a small C daemon) and left
  only 1.2 GB free, too tight for the `npm ci` build peak.
- **Old logs migrated** along with state.
- z2m pinned to **2.12.0**, the version currently running. Upgrades are a separate change, so
  any new problem has exactly one possible cause.

## Phase 1 — prepare CT206 (done 2026-08-28, no downtime)

Executed while the docker03 container was still serving the network.

1. `pct resize 206 rootfs +1G` — online, non-destructive. 3.9 GB usable.
2. `apt install nodejs npm git build-essential`; system user `zigbee2mqtt` (uid 999)
   **added to `dialout` (gid 20)** — this is what makes the shifted device ownership in
   phase 3 usable. `build-essential` is genuinely required: the dependency `unix-dgram`
   (which backs systemd `Type=notify`) is a native module compiled by node-gyp at install.
3. `git clone --depth 1 -b 2.12.0`, then build — see the pnpm correction below.
4. systemd unit installed **and left disabled**.

**Correction to the original plan — z2m 2.12.0 uses pnpm, not npm.** It ships
`pnpm-lock.yaml`, declares `"packageManager": "pnpm@10.18.3"`, and has no
`package-lock.json`, so `npm ci` fails outright with `EUSAGE`. The working sequence uses
`corepack` (already present in Debian's nodejs 20) to pin the exact expected pnpm:

```
corepack enable && corepack prepare pnpm@10.18.3 --activate
pnpm install --frozen-lockfile     # 268 packages, ~32s
pnpm run build                     # tsc && node index.js writehash -> dist/
pnpm prune --prod
```

**systemd unit** (`/etc/systemd/system/zigbee2mqtt.service`), `Type=notify` with
`Restart=always`, `RestartSec=10`, `WatchdogSec=30s`, and **`StartLimitIntervalSec=0` /
`StartLimitBurst=0` in the `[Unit]` section — these are `[Unit]` directives and are silently
ignored if written under `[Service]`, which would leave the default 5-starts-in-10s limit in
force and defeat the whole point. No start limit is what replaces `zigbee2mqtt-watchdog.sh`:
the watchdog only ever existed because Docker's `restart: always` stops retrying when the
*device lookup at container start* fails
([memory_docker03_zigbee2mqtt.md](memory_docker03_zigbee2mqtt.md)). `systemd-analyze verify`
returns clean.

**Verified end state of phase 1:** service `disabled`/`inactive`; `data/` contains only
`configuration.example.yaml` (**no** `configuration.yaml`, so the service cannot form a new
network even if started by accident); `zigbee2mqtt` in `dialout`; `dist/` built;
installed size 347 MB; 1.2 GB free.

**Tailscale:** joined 2026-08-28 as `zigbee2mqtt`, **100.86.144.9**. Verified direct
(non-DERP) from comet and SSH-able over it. `tailscale up` is interactive, so it was run via
`pct exec` from gr-srv03 and the auth URL handed to the user. Deliberately no
`--accept-routes` — that flag previously broke connectivity on this fleet.

Once phase 4 starts the service the frontend is at `http://100.86.144.9:8080`, or
`http://zigbee2mqtt:8080` via MagicDNS. Plain HTTP: z2m's built-in frontend has no TLS, and
this is Tailscale-only, not public. An HTTPS name would mean a Caddy vhost on cygnus —
considered and not done, since it would make z2m's UI depend on cygnus being up.

## Phases 2–5 — not yet executed

**Phase 2, copy state.** Pre-seed logs and `ca.crt` with no downtime; then `docker stop
zigbee2mqtt` and take the authoritative copy of `configuration.yaml`, `database.db`,
`coordinator_backup.json` (must be the post-stop copy) and `state.json`. Files are `root`-owned
from the container — `chown` on arrival. Edit exactly two values in the copied config:
`serial.port:` → `/dev/zigbee`, and `mqtt.ca:` → `/opt/zigbee2mqtt/data/ca.crt`.

**Phase 3, move the dongle.** `qm set 102 -delete usb2` hot-unplugs it from the VM; confirm the
host then creates `/dev/ttyUSB0`. Add `/etc/udev/rules.d/60-zigbee-coordinator.rules`:

```
SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", \
  ATTRS{serial}=="c4ba7c03e773ef11beaee41e313510fd", \
  SYMLINK+="zigbee", OWNER="100000", GROUP="100020", MODE="0660"
```

- `SYMLINK+="zigbee"` gives a stable name independent of `ttyUSB` numbering. Matching on
  **serial number** rather than port matters because the rtl_433 dongle is planned for its own
  LXC later and is also a USB serial device — serial matching keeps the two from colliding.
- `OWNER="100000" GROUP="100020"` is the unprivileged-LXC id shift: container uid/gid 0 maps to
  host 100000, so container `dialout` (gid 20) is host 100020. **Without this the node appears
  inside the container as `nobody:nogroup` and z2m cannot open it** — the single most likely
  silent failure in this migration.

Then in `/etc/pve/lxc/206.conf` (alongside the existing TUN entries):

```
lxc.cgroup2.devices.allow: c 188:* rwm
lxc.mount.entry: /dev/zigbee dev/zigbee none bind,create=file,optional 0 0
```

`188` is the char major for `ttyUSB`; `optional` lets CT206 boot when the dongle is absent.
Restart CT206 to establish the bind mount.

**Phase 4, start and verify.** `systemctl enable --now zigbee2mqtt`, watch
`journalctl -fu zigbee2mqtt`.

**Phase 5, clean up docker03** — only after a soak period. Remove the watchdog cron and script
and the compose project. **Leave `data/` in place**; it is the rollback.

## Verification checklist

1. Inside CT206, `/dev/zigbee` is a char device readable by the `zigbee2mqtt` user.
2. Journal reports the **same PAN ID (33768)** and channel 11. A different PAN ID means a new
   network was formed — stop immediately and roll back.
3. All 11 devices appear in the frontend, none showing as newly-joined or unnamed.
4. `zigbee2mqtt/bridge/state` publishes `online`; per-device topics appear under the unchanged
   base topic.
5. Home Assistant entities stay available and keep updating, with no duplicates. Check
   `zigbee_temp_exterior` and `zigbee_temp_living` specifically — they feed the heating logic —
   and verify `last_reported` advances, since z2m discovery entities never go `unavailable`
   ([2026-08-19_homeassistant_temperatura-exterior-parque-stale-chain.md](2026-08-19_homeassistant_temperatura-exterior-parque-stale-chain.md)).
6. TTato still receives its feeds and can command the boiler.
7. Actuator round-trip: toggle `luz exterior garage` from HA — confirms both directions.
8. `systemctl restart`, then a full CT206 reboot, both recover unattended.
9. Coordinator LQI unchanged against the ~220 baseline in
   [2026-08-24_docker03_zigbee-coordinator-rf-degradation.md](2026-08-24_docker03_zigbee-coordinator-rf-degradation.md)
   — the dongle is not moving physically, so a drop would mean the port change disturbed something.

## Rollback

Fast and complete while phase 5 has not run:

```
systemctl disable --now zigbee2mqtt     # CT206
qm set 102 -usb2 host=10c4:ea60         # gr-srv03, re-attach to the VM
docker start zigbee2mqtt                # docker03
```

docker03's `data/` is untouched by this plan, so the old instance resumes with its own state.
Keep it until the new setup has soaked through at least one full heating cycle.

## Known risks

- **USB re-enumeration leaves a stale bind mount.** If the dongle re-enumerates while CT206 runs,
  the bind-mounted inode goes stale; systemd restarts z2m but it keeps failing until the
  container is restarted — the LXC analogue of the 2026-07-15 Docker incident. Mitigation is a
  small watchdog that must live **on the gr-srv03 host** (where it can `pct restart 206`), not
  inside the container. Worth adding once stable; not a cutover blocker.
- **Node 20 is near end of upstream support.** Debian 13 carries security patches for the release
  lifetime, but a future z2m major may require Node 22+ and force a NodeSource repo.
- **Something may still monitor the old frontend URL** (uptime-kuma against docker03:8088) —
  not yet verified; repoint at CT206's Tailscale address.
- **`configuration.yaml` holds the MQTT password and Zigbee network key in cleartext.** Keep it
  `0600` owned by the service user, and don't route the copy through anything that logs contents.
