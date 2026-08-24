---
name: project_raspberrypi1_watchdog
description: "raspberrypi1 hard-froze Jun 2026 with no auto-recovery; BCM2835 hardware watchdog armed via systemd 2026-06-25 closes that gap"
metadata:
  node_type: memory
  type: project
---

raspberrypi1 hard-froze on 2026-06-17 (journal stops dead, no panic, no OOM) and stayed down
~4 days because nothing could recover it. The **BCM2835 hardware watchdog is now armed via
systemd** (`RuntimeWatchdogSec=10s`) since 2026-06-25, which closes that gap.

**Why:** the existing `wifi-watchdog.sh` runs from cron, so it cannot help with a true kernel
hang — cron isn't running either. Only a hardware watchdog can.

**How to apply:** `docs/2026-06-25_raspberrypi1_kernel-watchdog.md`. The incident write-up
`docs/memory_raspberrypi1_freeze.md` is **superseded** by it. raspberrypi2z gets the same
watchdog auto-armed by systemd at 60s. Related: [[project_raspberrypi2z_setup]].
