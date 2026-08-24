# raspberrypi1 TTato: permanent fix for the MQTT command subscription drop (2026-08-15)

**Status:** closed
**Host:** raspberrypi1
**Supersedes:** 2026-08-01_raspberrypi1_ttato-mqtt-subscription-drop.md
**Superseded-by:** —

## Problem
HA mode changes (`ttato_modificar_modo`) had no effect again — same symptom as
2026-08-01, 13 days after that session's container restart.

## Diagnosis
Probe that bypasses Home Assistant entirely (no-op, mode was already `A`):
```bash
# on docker03
docker exec mosquitto mosquitto_pub -h localhost -t TTato/command -m '{"newmode": "A"}'
# on raspberrypi1 — did NOT change before the fix
stat -c "%y" /home/rsi/TTato/www/TTatoMode
```
Nothing happened, so the failure was below HA. Corroborating signal: the TTato
container had **3** sockets to `192.168.1.8:1883` in `/proc/net/tcp`, but the
broker only saw **2** established from `192.168.1.49` — one client connection
was half-dead, and it was the one carrying `TTato/command`.

`git log -- bin/TTato.py` confirmed the 08-01 `on_connect` fix had never been
applied (last touched 2026-07-20, `c6bfb1a`); what changed on 08-01 was only
the container restart plus the unrelated CheckManual commits.

## Fix (commit `b24d961`, pushed to `igarreta/TTato`)
In `bin/TTato.py`:
- subscribe to `TTato/command` from an `on_connect` callback, so the
  subscription is re-issued on every (re)connection;
- moved `connect()` / `loop_start()` **below** `message_callback_add`, so no
  message can arrive before the callbacks are registered.

```python
mqtt_client = mqtt.Client("TTato")

def on_connect_command(client, userdata, flags, rc):
    client.subscribe("TTato/command")

mqtt_client.on_connect = on_connect_command
# ... on_message_command defined ...
mqtt_client.message_callback_add("TTato/command", on_message_command)
mqtt_client.connect(MQTT_BROKER)
mqtt_client.loop_start()
```

`compose.yaml` bind-mounts `./:/TTato`, so `docker restart TTato` is enough to
load the change — no rebuild. Verified: broker now shows 3 connections from
the Pi, the no-op probe rewrote `www/TTatoMode` + `var/TTatoMode` within
seconds, and the user confirmed the HA script works.

## Notes for future sessions
- **Where TTato logs** — `docker logs TTato` is empty (`json.log` 0 bytes since
  2026-06-28) because `bin/TTato.py:84-86` reassigns `sys.stdout`/`sys.stderr`
  to `MyLogger`, so nothing ever reaches Docker. Everything, including
  `print()` output like `Mode changed to: X.` (`change_ttato_mode`,
  `bin/TTato.py:414`), goes to **`/home/rsi/TTato/log/TTato.log`**
  (`TimedRotatingFileHandler`, level INFO, weekly rotation on Mondays,
  `backupCount=4` → `TTato.log.YYYY-MM-DD`). A second logger writes
  temperature rows to `www/temps_log.csv` with the same rotation.
  So the probe is `grep "Mode changed" /home/rsi/TTato/log/TTato.log`, or the
  mtime of `/home/rsi/TTato/www/TTatoMode`.
- Commands go **straight** to the docker03 broker (`MQTT_BROKER = "192.168.1.8"`,
  `bin/GlobalThreads.py:54`). `mqtt-resend`'s `TTato/command` redirect rule in
  `BROKER_REDIRECTS.md` is legacy — that container isn't even running on the Pi.
- The `{"newmode": "<current mode>"}` publish is a safe end-to-end probe: it
  exercises the whole path and rewrites the mode files without touching the
  boiler.
- Supersedes the workaround in
  docs/2026-08-01_raspberrypi1_ttato-mqtt-subscription-drop.md.
</content>
</invoke>
