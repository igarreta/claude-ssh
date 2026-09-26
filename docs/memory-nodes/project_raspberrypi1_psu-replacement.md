---
name: project_raspberrypi1_psu-replacement
description: raspberrypi1 PSU replaced 2026-09-20 after sticky under-voltage flags; confirmed resolved 2026-09-26
metadata: 
  node_type: memory
  type: project
  originSessionId: a949b1ca-6578-475e-a9cd-91ba2fbee60b
  modified: 2026-09-26T15:20:00.000Z
---

raspberrypi1's power supply was physically replaced 2026-09-20 after `vcgencmd get_throttled`
showed sticky under-voltage/throttling bits (`0xd0000`). Re-checked 2026-09-26 (6 days later,
uptime continuous since the post-swap boot): still `0x0`, no volt/throttle lines in `dmesg`.
Resolved — the new PSU fixed it.

**Why:** this Pi runs TTato heating control — a silent under-voltage-induced freeze here is a
heating outage, not just a log noise item.

**How to apply:** no more follow-up needed for under-voltage specifically. If raspberrypi1
becomes unresponsive again, that's a different failure mode — see
[[project_raspberrypi1_watchdog]] for the freeze/watchdog history. Full detail:
docs/2026-09-20_raspberrypi1_power-supply-replacement.md.
