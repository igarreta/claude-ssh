---
name: project_raspberrypi1_ttato_mqtt_drop
description: "TTato MQTT command subscription silently dropped after reconnects (2026-08-01, 2026-08-15); permanently fixed 2026-08-15 with an on_connect resubscribe"
metadata: 
  node_type: memory
  type: project
  originSessionId: 1349407a-748a-49f1-b5d7-aa634df14b1d
  modified: 2026-08-15T12:19:26.066Z
---

TTato (raspberrypi1) twice stopped applying HA mode-change commands sent via
the `TTato/command` MQTT topic — the payload reached the broker fine, but
TTato's `mqtt_client` had silently lost its subscription. Publishing
(`TTato/status`) kept working, masking the problem.

**Why:** `paho-mqtt` with default `clean_session=True` forgets subscriptions on
any client-level reconnect, and `bin/TTato.py` only subscribed once at startup.
Recurred 13 days after the 08-01 container-restart workaround.

**How to apply:** Permanently fixed 2026-08-15 (commit `b24d961`, pushed):
`on_connect` callback re-subscribes on every (re)connection, and
`connect()`/`loop_start()` now run after the callbacks are registered.
`compose.yaml` bind-mounts `./:/TTato`, so a `docker restart TTato` loads code
changes — no rebuild. To probe the whole path safely, publish
`{"newmode": "<current mode>"}` to `TTato/command` on docker03 and
`grep "Mode changed" /home/rsi/TTato/log/TTato.log`. That file holds
everything — `bin/TTato.py:84-86` redirects stdout/stderr into the logger, so
`docker logs TTato` is always empty; never use it as a probe.
See docs/2026-08-15_raspberrypi1_ttato-mqtt-resubscribe-fix.md
and the superseded docs/2026-08-01_raspberrypi1_ttato-mqtt-subscription-drop.md.
Related: [[project_raspberrypi1_ttato_granev]] (MQTT command contract), and the
07-23 payload-whitespace fix in the HA script (separate bug, same symptom).
</content>
</invoke>
