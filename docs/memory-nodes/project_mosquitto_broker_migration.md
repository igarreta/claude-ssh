---
name: project_mosquitto_broker_migration
description: "MQTT broker migrated from docker03 to dedicated gr-srv03 LXC (mosquitto, VMID 105) with auth+TLS; client cutover in progress, 2 of 6 clients done"
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

**Client cutover in progress**: mqtt-explorer (2026-08-16) and raspberrypi2z rtl_433
(2026-08-26) done and confirmed publishing/connecting. Still on the old docker03 broker:
zigbee2mqtt, tuya-link, TTato, Home Assistant — in that cutover order, old broker kept running
in parallel until each is confirmed.

**Watch for**: the mqtt-explorer UI has a recurring bug where its persisted connection ends up
with `encryption: true` but `port: 1883` (the plaintext listener), which mosquitto rejects as a
protocol error — it has now happened twice. If mqtt-explorer can't connect, check `port` in its
`settings.json` on docker03 before anything else.

**How to apply**: before doing anything with MQTT clients in this environment, check which
clients have been cut over (see "Client cutover in progress" above) — anything not listed as
done is still pointed at the old docker03 broker. Full plan and exact per-host edits:
[[docs/memory_mqtt-broker-migration.md]] in the claude-ssh repo.
