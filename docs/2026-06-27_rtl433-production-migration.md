# rtl_433 production migration: docker03 → raspberrypi2z (2026-06-27)

**Status:** closed
**Host:** raspberrypi2z, docker03
**Supersedes:** —
**Superseded-by:** —

> **CORRECTED 2026-08-30**: the topic table below lists Oregon-THGR122N (exterior
> Granaderos) as `id=161`. The live `configuration.yaml` state_topic actually uses
> `id=87` — confirmed byte-for-byte while editing the battery sensors in
> [2026-08-30_homeassistant_battery-binary-sensors-and-exterior-zigbee-swap.md](2026-08-30_homeassistant_battery-binary-sensors-and-exterior-zigbee-swap.md).
> The other three rows (living/hab principal/hab chicos) were re-verified and are correct.

## Summary

The rtl_433 service previously ran as a Docker container on docker03, publishing to
`rtl_433/docker03`. After successful testing on raspberrypi2z, it was promoted to
production with topic prefix `rtl_433/raspberrypi2z`. The docker03 container was
retired.

## Changes made

### raspberrypi2z — `/etc/rtl_433/rtl_433.conf`

Promoted from test topic and corrected topic structure to match the old format:

```
output mqtt://192.168.1.8:1883,retain=0,devices=rtl_433/raspberrypi2z/devices[/model][/channel][/id],events=rtl_433/raspberrypi2z/events
```

Key differences from the test config:
- `rtl_433/test` → `rtl_433/raspberrypi2z`
- Added `/devices/` literal in path (matches old docker03 format and HA config)
- Fixed ordering: `[/channel][/id]` (test config had `[/id][/channel]` which was wrong)
- Added `events=` output for TTato (JSON per reading)

Config stored in repo at `raspberrypi2z/rtl433/rtl_433.conf`. Deploy with:
```bash
sudo cp /tmp/rtl_433.conf /etc/rtl_433/rtl_433.conf && sudo systemctl restart rtl433
```

### HomeAssistant — `/config/configuration.yaml`

**MQTT sensors**: replaced `docker03` → `raspberrypi2z` in all 8 topic strings.

**Humidity sensors added** (4 new sensors, one per device):
- Humedad exterior Granaderos (`hum_ext_gran`, expire 1800s)
- Humedad living Nexus (`hum_living_nexus`, expire 600s)
- Humedad hab principal Nexus (`hum_hab_prpal_nexus`, expire 600s)
- Humedad hab chicos Nexus (`hum_hab_chicos`, expire 600s)

**"Temperatura exterior parque" template sensor** — priority chain updated:

| Priority | Source | Notes |
|---|---|---|
| 1 (new) | `sensor.temperatura_exterior_granaderos` | Oregon-THGR122N via raspberrypi2z |
| 2 | `sensor.zigbee_temperatura_exterior_temperature` | Previous primary |
| 3 | `sensor.zigbee_temp_exterior_temperature` | -1.8°C correction |
| 4 | `sensor.esp32_pileta_temperatura_caja_techo` | Night only, +3.4°C correction |

The Oregon sensor was made primary because it is the most reliable source
(dedicated outdoor sensor, proved stable through testing).

### TTato — `/home/rsi/TTato/bin/GlobalThreads.py`

Line 331: `rtl_433/docker03/events` → `rtl_433/raspberrypi2z/events`

TTato runs as a Docker container on raspberrypi1 (`python_3_11_gpio:v2`), with
`/home/rsi/TTato/` volume-mounted as `/TTato` inside. Edit the file on the host,
then `docker restart TTato`.

TTato subscribes to the `events` topic (JSON per reading) and parses `model`, `id`,
`temperature_C`, `humidity`, `battery_ok` from the payload.

### docker03 — rtl_433 container

Stopped and removed:
```bash
cd /home/rsi/dockerfiles/rtl_433 && docker compose down
```

Container was `hertzg/rtl_433:latest`, command `-Fmqtt:mosquitto:1883,base=rtl_433/docker03`.
Compose file remains at `/home/rsi/dockerfiles/rtl_433/compose.yaml` (disabled).

## Topic structure reference

```
rtl_433/raspberrypi2z/devices/<model>/<channel>/<id>/<field>   # individual fields
rtl_433/raspberrypi2z/events                                    # JSON event per reading
```

Sensors and their topic paths:
- Oregon-THGR122N (exterior Granaderos): channel=1, id=161
- Nexus-TH (living):                     channel=1, id=88
- Nexus-TH (hab principal):              channel=2, id=33
- Nexus-TH (hab chicos):                 channel=3, id=12
