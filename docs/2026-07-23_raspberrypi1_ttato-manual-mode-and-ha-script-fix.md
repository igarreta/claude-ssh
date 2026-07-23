# raspberrypi1 TTato: manual mode override + HA script payload bug fix (2026-07-23)

## Request
Put TTato into Manual mode at 16°C until 2026-08-01 11:00.

## Immediate action (raspberrypi1)
TTato (`/home/rsi/TTato/`, Docker container `TTato`, repo `igarreta/TTato`)
reads mode-change requests from `www/changemode.json` (checked every loop
iteration) or from MQTT topic `TTato/command` (both feed the same
`changemode` dict: `newmode`, and for `M` also `mintemp`, `enddate`,
`endtime`).

Wrote `/home/rsi/TTato/www/changemode.json`:
```json
{"newmode":"M","mintemp":16,"enddate":"2026-08-01","endtime":"11:00:00"}
```
Verified applied: `www/TTatoMode` → `M`, `www/mode` → `M` on next minute cycle.

## Follow-up: HA scripts for changing TTato mode don't work
User reported `script.cambiar_modo_ttato` and `script.ttato_modificar_enviar`
(homeassistant, `/config/scripts.yaml`) don't actually change TTato's mode.

### `cambiar_modo_ttato` — orphaned, not the real path
Only cycles `input_select.ttato_mode_set` (O→A→M→E→O). Nothing in
`automations.yaml` or elsewhere consumes that entity — it has no effect on
TTato. Left as-is per user request (not fixed/removed this session).

### `ttato_modificar_enviar` — real path, had a whitespace bug
This script reads `input_select.ttato_opciones` / `input_number.ttato_modificar_temp`
/ `input_datetime.ttato_modificar_hora`, builds a JSON payload, and publishes
it via `mqtt.publish` to `TTato/command` — the same topic
`GlobalThreads.py`'s `on_message_command` subscribes to.

Root cause: the `payload` Jinja template was
```
{% set base = {"newmode": newmode} %} {% if incluir_extra %}
  {{ dict(base, mintemp=mintemp, enddate=enddate, endtime=endtime) | tojson }}
{% else %}
  {{ base | tojson }}
{% endif %}
```
The literal space between `%}` and `{% if %}`, plus the indentation before
each `{{ }}` (Jinja's `lstrip_blocks` only strips whitespace before `{%...%}`
block tags, not before `{{...}}` print tags), made the rendered MQTT payload
start with whitespace instead of `{`. TTato's `on_message_command` in
`TTato.py` does:
```python
if message[0] == "{" and len(message) > 1:
    changemode = json.loads(message)
```
With a leading space, this check silently fails — no error logged, message
just dropped. Affected every mode, not just Manual. Corroborated by state
history: user's 17:19 attempt set `input_select.ttato_opciones` to
"Apagado", but `sensor.ttato_mode` stayed at "M" throughout.

### Fix
Collapsed the template so no stray text sits before the tags:
```
payload: "{% set base = {\"newmode\": newmode} %}{% if incluir_extra %}{{ dict(base, mintemp=mintemp, enddate=enddate, endtime=endtime) | tojson }}{% else %}{{ base | tojson }}{% endif %}"
```
Applied directly to `/config/scripts.yaml` on homeassistant (backup at
`scripts.yaml.bak-payload-fix`), validated with `ha core check`, and reloaded
via `POST /api/services/script/reload` (Supervisor API proxy, using
`SUPERVISOR_TOKEN` from `/etc/profile.d/`, since the SSH addon session has no
token in its own env and needs `sudo` for `/config` write access — `hassio`
user cannot write `/config` directly, only via `sudo`).

Verified fix via HA's `/api/template` endpoint (side-effect-free) using the
live helper values: rendered payload was `{"newmode": "O"}` with no leading
whitespace.

## Notes for future sessions
- homeassistant SSH (MCP `homeassistant` connector): `hassio` user cannot
  write `/config` directly (`Permission denied`) — use `sudo-exec` for any
  file edit under `/config`.
- `SUPERVISOR_TOKEN` for calling the HA REST API from this SSH session is in
  `/etc/profile.d/*.sh` (not in the default env) — `export` it manually, or
  `. /etc/profile.d/<file>.sh`, before calling `ha core ...` or hitting
  `http://supervisor/core/api/...` with curl.
- `/api/template` (POST, `{"template": "..."}`) is a safe way to test Jinja
  templates against live entity states without triggering real side effects
  — use it before hand-testing any script/automation that has physical
  effects (like this one, which controls the boiler).
- TTato mode-change contract: `www/changemode.json` (file, polled) or MQTT
  `TTato/command` (JSON: `newmode`, plus `mintemp`/`enddate`/`endtime` when
  `newmode == "M"`) — both funnel into the same `changemode` handling in
  `TTato.py`. See also [[project_raspberrypi1_ttato_granev]] for the related
  `granev/temp/*` MQTT integration fixed 2026-07-20.
