---
name: project_mosquitto_broker_migration
description: "MQTT broker migrated from docker03 to dedicated gr-srv03 LXC (mosquitto, VMID 105); all 7 clients cut over, old docker03 broker stopped 2026-08-26"
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

**esp32-pileta** (ESPHome, roof-box pool sensor) was missed in the original inventory — found
2026-08-26 when the user had already repointed it at the new broker without realizing auth was
required. Provisioned account `esp32pileta` (plaintext 1883, `esp32-pileta/#`); user added
credentials in ESPHome Builder and reflashed; confirmed publishing (`status: online` + live
sensor/switch states).

**Old broker stopped, 2026-08-26**: verified first with a 15-min `mosquitto_sub -R` (no
retained messages) against the old broker — zero live traffic — then `docker stop mosquitto`
on docker03 (`unless-stopped` policy, survives reboot, ports confirmed released). Container
left in place, not removed, for easy rollback.

**Remaining**: remove the stopped container/compose entirely once comfortable no rollback is
needed; add `log-monitor/hosts/mosquitto.conf`.

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

**Uptime Kuma monitoring added 2026-08-26**: `uptimekuma` user (read-only `#`), URL form
`mqtt://192.168.1.198`. MQTT ACL wildcards (`#`, `+`) never match `$`-prefixed topics by
protocol convention, so monitoring broker-level `$SYS/broker/uptime` needed an explicit
`topic read $SYS/#` line (added for `uptimekuma` and, for consistency, `mqttexplorer` too).
Deliberately not using a client topic like `zigbee2mqtt/bridge/state` — that would make the
health check go down with one client instead of the broker itself.

**How to apply**: all MQTT clients now point at the new broker (`192.168.1.198:8883` TLS, or
`:1883` plaintext+auth for raspberrypi2z's rtl_433 only) — the old docker03 broker is a
fallback pending decommission, not a live source of truth. Any new client/monitor needs both
a `passwd` entry and an explicit ACL line — `$SYS` topics need their own `topic read $SYS/#`
even with a broad `#` grant. Full history and exact per-host edits:
[[docs/memory_mqtt-broker-migration.md]] in the claude-ssh repo.
