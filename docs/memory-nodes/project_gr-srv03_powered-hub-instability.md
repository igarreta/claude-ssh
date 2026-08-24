---
name: project_gr-srv03_powered-hub-instability
description: "gr-srv03 Zigbee drops were BACKUP_A/_B hot-plug transients on the shared xHCI 5V rail, not hub decay; hub removed 08-17, fix confirmed 08-19"
metadata:
  node_type: memory
  type: project
---

gr-srv03's Zigbee dongle drops were triggered by BACKUP_A/_B **hot-plug transients on the
shared xHCI 5V rail** (7 of 7 episodes), not by hub decay. The hub was removed 2026-08-17
and the fix was **CONFIRMED 08-19** (survived 3 hot-plugs, 0 events). It did **not** freeze
docker03 — that was a coincident Tailscale key expiry.

**Why:** the drives sat on a different socket but shared one xHCI controller and one 5V
rail; a bus-powered 2.5" HDD's inrush transient sags it. PCH root ports tolerate this, the
cheap Terminus hub did not. The "degrading hub" and "evening EMI" theories were both wrong.

**How to apply:** a hub rebuild is **PLANNED but unpurchased** (only 3 USB ports, all full) —
`docs/2026-08-19_gr-srv03_usb-hub-layout-plan.md`. Narrative and the pre-switch USB speed
baseline are in `docs/memory_gr-srv03_powered-hub-instability.md`; the standalone baseline
doc `docs/memory_gr-srv03_usb-hub-eval.md` is **superseded**, don't act on its
"move to a powered hub" conclusion. Related:
[[project_docker03_tailscale-key-expiry-2026-08-17]], [[project_docker03_zigbee_rf_degradation]].
