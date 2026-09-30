---
name: project_raspberrypi1_ttato_rules
description: TTato Automatic-mode rules — last matching rule wins, EXT_LIM2 outdoor cutoff now 24h; config.yaml edits need a restart or the top of the hour
metadata:
  type: project
---

"Heating on but it shouldn't be" in mode A is usually the schedule working as written,
not a bug. Detail: docs/2026-09-30_raspberrypi1_ttato-evening-outdoor-cutoff.md

**Why**: rules run in `config.yaml` order and the last match wins, so `>` cutoffs placed
after the `<` rules override them. `EXT_LIM2` (EXTERNAL > 17 °C) ran only 00–15 h until
2026-09-30. `get_config()` is cached and only re-reads the file hourly.

**How to apply**: find the active `<` rule and whether any later `>` rule covers the current
time before suspecting code. After editing `var/config.yaml`, run `docker restart TTato`
(this drops Manual → A, see [[project_raspberrypi1_ttato_manual_heating]]).
