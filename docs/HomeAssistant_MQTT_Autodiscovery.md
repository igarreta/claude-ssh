# Home Assistant MQTT: Always Use Autodiscovery

**Date**: 2026-02-17
**Lesson learned the hard way**

## Rule

When a script you control publishes data to MQTT, **always use MQTT autodiscovery** instead of defining the sensor in `configuration.yaml`.

## Why YAML Sensors Cause Problems

- HA 2026.x requires `mqtt:` as the top-level YAML key (older configs used `config:` — silently broken)
- Deleting a YAML-defined entity from the HA UI moves it to `deleted_entities`, which permanently blocks recreation with the same `unique_id`
- YAML sensors do not appear as devices in the MQTT integration page
- Debugging requires multiple full HA restarts

## The Autodiscovery Pattern

Add this to any Python MQTT publisher, right after connecting:

```python
DISCOVERY_TOPIC = "homeassistant/sensor/<unique_slug>/config"

def publish_discovery(client):
    payload = {
        "name": "My Sensor",
        "unique_id": "<globally_unique_id>",
        "default_entity_id": "sensor.<desired_entity_id>",
        "state_topic": "<your/data/topic>",
        "value_template": "{{ value_json.field | int }}",
        "unit_of_measurement": "cm",
        "expire_after": 1500,           # seconds; omit if data is continuous
        "device": {
            "identifiers": ["<device_slug>"],
            "name": "My Device",
            "model": "my_script",
            "manufacturer": "<hostname>"
        }
    }
    client.publish(DISCOVERY_TOPIC, json.dumps(payload), retain=True)

client.connect(broker)
client.loop_start()
time.sleep(1)
publish_discovery(client)
```

Key points:
- **`retain=True`** — broker stores the message; HA sees it even if it restarts before the script does
- **`unique_id`** — HA matches this to the existing entity on republish; never creates duplicates
- **`default_entity_id`** — suggests the entity ID (replaces deprecated `object_id` since HA 2026.4)
- No YAML changes needed, no HA restart needed — entity appears immediately in the MQTT integration page

## When YAML Is Acceptable

Only for sensors you do **not** control the publisher for, e.g. RTL-433 radio sensors, third-party devices without discovery support.
