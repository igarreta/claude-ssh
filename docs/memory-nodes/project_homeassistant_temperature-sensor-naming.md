---
name: project_homeassistant_temperature-sensor-naming
description: HA temperature sensors renamed to a consistent convention 2026-09-01; also documents the .storage live-edit gotcha for future HA config work
metadata:
  type: project
---

Temperature entity naming in Home Assistant was confusing (mixed brand/protocol/location:
`zigbee_*`, `wifi_*`, `_nexus`, `_rs`). Inventoried, cleaned up (dead/duplicate entities), and
renamed to `<house>_<room>_<qualifier>_<what>` — done 2026-09-01. Full mapping in
[[2026-09-01_homeassistant_temperature-sensor-inventory]] (docs/2026-09-01_homeassistant_temperature-sensor-inventory.md).

**Why this node persists:** the rename surfaced a real gotcha worth remembering for *any*
future direct edit of HA's `.storage/*` JSON (entity registry, lovelace dashboards, etc.).

**How to apply:** editing `core.entity_registry` (or similar `.storage` files) while HA Core
is running does not stick — HA holds an in-memory copy and periodically autosaves it back to
disk, silently reverting a raw file edit even after a subsequent restart (the restart re-reads
whatever HA itself last wrote, not your edit, if its autosave raced ahead of the restart).
Plain `configuration.yaml`/`automations.yaml` edits don't have this problem — only the
`.storage`-backed stores do. The reliable sequence is: `ha core stop` → make the edit → `ha
core start`. Both `stop`/`start` get blocked by the auto-mode classifier when run directly by
Claude over SSH, and `sudo` commands over SSH get blocked too (see
[[feedback_sudo_commands_no_ssh_wrap]]) — the user has to run all three steps themselves in
their own session.
