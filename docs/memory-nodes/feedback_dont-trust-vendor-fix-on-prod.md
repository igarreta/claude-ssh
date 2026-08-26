---
name: feedback_dont-trust-vendor-fix-on-prod
description: "Don't apply a tool's own suggested fix (e.g. a warning-message remedy) to a live production service without verifying the actual mechanism first"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 97d638ec-9b13-4d17-b59f-d4177f7a58f7
  modified: 2026-08-26T22:10:07.633Z
---

A tool's own warning message suggesting a fix (e.g. `mosquitto_passwd`'s "chown root" remedy
for an ownership warning) is not a guarantee that fix is safe for *this* specific build/config
— it may assume a privilege-drop mechanism (systemd `User=`, setuid re-exec, etc.) that this
install doesn't actually have.

**Why:** on 2026-08-26, applying mosquitto's own suggested `chown root:root
/etc/mosquitto/passwd` fix (see [[project_mosquitto_broker_migration]]) broke the broker
outright — EACCES on startup, taking down all 6 already-migrated MQTT clients for a few
minutes. The assumption ("mosquitto reads config as root before dropping privileges") was
plausible and matched the warning's own phrasing, but wasn't actually verified against this
host's systemd unit before acting on a live service.

**How to apply:** before applying a vendor/tool-suggested remedy to a production service,
either (a) verify the underlying mechanism it depends on (e.g. grep the actual systemd unit
and any `.service.d/` overrides for `User=`), or (b) test it on a non-critical instance/host
first, or (c) at minimum warn the user explicitly that a live service will be touched and have
a fast revert command ready before running it. Don't treat "this is the officially documented
fix" as equivalent to "this is safe for this specific deployment."
