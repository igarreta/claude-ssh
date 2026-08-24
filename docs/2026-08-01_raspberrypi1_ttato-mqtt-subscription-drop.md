# raspberrypi1 TTato: MQTT command subscription silently dropped (2026-08-01)

**Status:** superseded
**Host:** raspberrypi1
**Supersedes:** —
**Superseded-by:** 2026-08-15_raspberrypi1_ttato-mqtt-resubscribe-fix.md

## Problem
User sent a mode-change command ("auto") from Home Assistant via
`script.ttato_modificar_enviar`. Payload arrived fine on the broker, but
TTato's mode stayed at `O` — the command was never applied.

## Diagnosis
Subscribed directly to the broker (docker03, `192.168.1.8:1883`, container
`mosquitto`) on `TTato/command` and `TTato/status` to watch live:
```
mosquitto_sub -h 192.168.1.8 -p 1883 -t 'TTato/command' -t 'TTato/status' -v
```
Confirmed `TTato/command {"newmode": "A"}` reached the broker correctly (no
leading-whitespace bug this time — the 2026-07-23 payload fix held).
`TTato/status` kept reporting `mode: "O"` before and after, and TTato's
internal log (`docker exec TTato tail /TTato/log/TTato.log`) showed zero
trace of receiving or processing the command — no error, no mode-change
line.

## Root cause
In `TTato.py`, `mqtt_client = mqtt.Client("TTato")` subscribes to
`TTato/command` once at startup, but there's no `on_connect` callback to
resubscribe. `paho-mqtt`'s `loop_start()` auto-reconnects after a TCP drop,
but with the default `clean_session=True` the broker forgets all prior
subscriptions on reconnect. The container had been running 8 days with
`RestartCount: 0` (i.e. the same process, no full restart) — a transient
network blip at some point almost certainly caused a client-level
reconnect that dropped the subscription silently. Publishing (`TTato/status`
every minute) kept working throughout since that direction doesn't depend
on any subscription — only incoming commands were black-holed. This is a
different bug from the 07-23 whitespace/payload issue; same symptom
("mode doesn't change"), different layer (transport vs payload format).

## Fix
`docker restart TTato` on raspberrypi1 — forces a fresh MQTT connection and
re-runs the one-time `subscribe("TTato/command")` at startup. Verified: sent
"auto" from HA again, `TTato/status` flipped to `"mode": "A"` within the next
~60s loop tick, log showed `Mode changed to: A.` at 09:47:54.

This is a workaround, not a permanent fix — the underlying subscription-loss
risk remains and will recur after any future reconnect (silent network
blip, broker restart, etc.), with no error logged when it happens.

## Notes for future sessions
- Real fix would be adding an `on_connect` callback to `mqtt_client` that
  re-issues `subscribe("TTato/command")` on every (re)connection, not just
  at startup. Not applied this session — user only asked to unblock the
  immediate command, not patch the code.
- To diagnose "HA command not applied" again: first check whether the
  payload even reaches the broker (external `mosquitto_sub` on
  `TTato/command`), then check `TTato/status` / `docker exec TTato tail
  /TTato/log/TTato.log` for a corresponding `Mode changed to:` line. If the
  payload arrives at the broker but TTato's log shows nothing, suspect this
  same silent-subscription-drop issue and restart the container.
- mosquitto broker log (`docker exec mosquitto tail /mosquitto/log/mosquitto.log`
  on docker03) only logs `error`/`warning` by default — connect/disconnect
  events aren't visible unless `log_type information` is enabled in
  `mosquitto.conf`, so it couldn't confirm the reconnect directly.
- Confirms the MQTT command contract documented in
  [[project_raspberrypi1_ttato_granev]] — `TTato/command` topic, JSON
  `{"newmode": ...}` — is otherwise working correctly end-to-end once the
  subscription is alive.
