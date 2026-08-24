---
name: project_mosquitto_broker_migration
description: "MQTT broker migrated from docker03 to dedicated gr-srv03 LXC (mosquitto, VMID 105) with auth+TLS; client cutover still pending a static IP"
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

**Blocked on**: LAN IP is still DHCP (`192.168.1.198`) — static assignment needs router access
the user didn't have during the migration session. Client migration (zigbee2mqtt, TTato,
rtl_433, tuya-link, Home Assistant) is written up but **not yet executed**, waiting on the
static IP (TLS cert SAN needs to be regenerated for the final IP first).

**How to apply**: before doing anything with MQTT clients in this environment, check whether the
static IP has been set and the cutover has happened — if not, they're all still pointed at the
old docker03 broker. Full plan and exact per-host edits: [[docs/memory_mqtt-broker-migration.md]]
in the claude-ssh repo.
