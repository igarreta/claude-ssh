---
name: project_mosquitto_broker_migration
description: "MQTT broker migrated from docker03 to dedicated gr-srv03 LXC (mosquitto, VMID 105) with auth+TLS; 6 original clients cut over, esp32-pileta discovered late and pending"
metadata: 
  node_type: memory
  type: project
  originSessionId: b6c90f75-782b-4e3c-9dc8-9f5d26bf346e
  modified: 2026-08-15T23:46:57.816Z
---

New dedicated mosquitto LXC (gr-srv03, VMID 105, Tailscale `100.69.153.63`) is built and
verified: native mosquitto, `allow_anonymous false`, self-signed CA, TLS on 8883 + plaintext+auth
on 1883 (kept only for raspberrypi2z's rtl_433, which has no TLS support in its Debian package),
per-client users + ACLs. Credentials live on the host itself
(`/home/rsi/mosquitto-credentials.txt`, 600), not in git.

**Why**: broker is a hard dependency for Home Assistant and TTato (boiler control) — moved off
docker03 to its own LXC for isolation, and added auth/ACLs since it was previously fully
anonymous.

**Static IP** (was the blocker) resolved 2026-08-16 — `192.168.1.198` is now a router DHCP
reservation, no cert regeneration needed.

**Client cutover complete, 2026-08-26**: mqtt-explorer (initial cutover 08-16), raspberrypi2z
rtl_433, docker03 zigbee2mqtt, cygnus tuya-link, raspberrypi1 TTato, and Home Assistant (manual
UI reconfigure — no SSH access to that host) all confirmed publishing/subscribing on the new
broker. HA verification done via its own Developer Tools → MQTT → "Listen to a topic", not an
external tool (mqttexplorer's view looked stale and caused a false scare — see below).

**Remaining**: decommission the docker03 mosquitto container once the new broker's run clean
for a few days; add `log-monitor/hosts/mosquitto.conf`; finish **esp32-pileta**, an ESPHome
device found late (missed in the original inventory) — broker account `esp32pileta` is
provisioned (plaintext 1883, `esp32-pileta/#`), waiting on the user to add those credentials in
ESPHome Builder and reflash.

**Caused a brief full outage 2026-08-26** chasing a mosquitto_passwd ownership warning —
`chown root:root` on `passwd`/`acl` (mosquitto's own suggested fix) broke the broker
(EACCES on start) for all 6 clients. Reverting to `chown mosquitto:mosquitto` fixed it
immediately. **Don't retry that chown** without finding the actual privilege-drop mechanism
first — see [[docs/memory_mqtt-broker-migration.md]] for full detail, and
[[feedback_dont-trust-vendor-fix-on-prod]] for the general lesson.

**TTato caveat**: its `granev/temp/#` subscription won't see live data until HA cuts over too
(HA is the publisher on that topic) — not a bug, just sequencing.

**A `ca.crt` file's base64 body is high-entropy enough that the harness redacts it out of any
command output or SFTP-download content before it reaches the assistant's context** — even
though a CA cert is public, not a secret. Moving it between hosts needs either a user-run scp
(their terminal isn't filtered) or a pre-approved direct host-to-host key. Also: several
docker03 `dockerfiles/*/data/` directories are root-owned even though the files inside are
`rsi:root` — a plain `scp`/upload into them as `rsi` fails; land it in `/home/rsi/` first, then
`sudo mv`+`chown`.

**Watch for**: the mqtt-explorer UI has a recurring bug where its persisted connection ends up
with `encryption: true` but `port: 1883` (the plaintext listener), which mosquitto rejects as a
protocol error — it has now happened twice. If mqtt-explorer can't connect, check `port` in its
`settings.json` on docker03 before anything else.

**How to apply**: all MQTT clients now point at the new broker (`192.168.1.198:8883` TLS, or
`:1883` plaintext+auth for raspberrypi2z's rtl_433 only) — the old docker03 broker is a
fallback pending decommission, not a live source of truth. Full history and exact per-host
edits: [[docs/memory_mqtt-broker-migration.md]] in the claude-ssh repo.
