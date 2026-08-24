---
name: project_raspberrypi1_ttato_granev
description: raspberrypi1 TTato granev/temp/* MQTT integration fixed 2026-07-20; full content in docs/2026-07-20_raspberrypi1_ttato-granev-integration.md
metadata: 
  node_type: memory
  type: project
  originSessionId: c4a7b0ff-174f-4304-8062-337e96b70352
---

TTato (raspberrypi1, repo `igarreta/TTato`, `/home/rsi/TTato/`, Docker container `TTato`) never subscribed to HA's `granev/temp/*` MQTT topics, even though `config.yaml`'s sensor_groups (`HABPRPAL`, `LIVING00`, `VARONES_`, `EXTERNAL`) were already wired for it. Fixed by adding one subscription line in `GlobalThreads.py` (`granev/temp/#`) plus a new `ext_prom` sensor entry for the `EXTERNAL` group. Committed as `5f7616a` (split from unrelated pre-existing local changes committed as `c6bfb1a`), both pushed to origin.

**Why:** HA now does temperature-source preprocessing/averaging and publishes results to `granev/temp/*`; TTato's old multi-source reliability-selection logic was supposed to be replaced by simply consuming these topics, but the migration was left half-done — config was ready, subscription was not.

**How to apply:** If troubleshooting TTato temperature routing again, check `_on_connect_rtl`/`_on_connect_oth` subscriptions in `GlobalThreads.py` and `sensor_groups` in `var/config.yaml` together — the config-driven mapping (netname = `model/id` from JSON payload) means most future topic additions need only a config.yaml sensor entry, not code changes, as long as payload shape matches `{"model":..., "id":..., "temperature":...}`.

Known separate issue: `granev/temp/hab_chicos` still publishes 0 because upstream HA entity `sensor.temperatura_hab_varones` is stuck `unknown` — a hardware problem, not a TTato bug. See [[project_raspberrypi1_watchdog]] for other raspberrypi1 issues (unrelated).
