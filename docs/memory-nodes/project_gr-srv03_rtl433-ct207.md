---
name: project_gr-srv03_rtl433-ct207
description: "CT207 LXC for rtl_433 (docker03 decommission) built and proven working 2026-09-05; test dongle removed, container stopped, permanent setup still pending"
metadata: 
  node_type: memory
  type: project
  originSessionId: b868f20e-cebb-4117-b221-e8b65fd87fab
  modified: 2026-09-05T22:52:32.818Z
---

CT207 (`10.0.100.13`) is the new dedicated LXC for rtl_433, part of the docker03
decommission ([[project_docker03_zigbee_rf_degradation]] sibling — same reasoning: USB/kernel
instability needs the LXC boundary, not just container isolation). Built from CT901 template,
`rtl-433` installed, host-side USB passthrough (DVB-driver blacklist, udev rule, whole-tree
`/dev/bus/usb` bind mount) done and proven with a live test capture on 2026-09-05.

**Why it matters:** the dongle was only temporarily connected for testing (had to disconnect
BACKUP_B to free the USB port) — both reverted at end of session, CT207 is stopped. The
host-side fixes are permanent and don't need to be redone next time.

**How to apply:** before touching this again, read `docs/memory_rtl433-lxc-ct207.md` for the
exact commands (DVB unbind/blacklist, udev rule content, LXC config lines) — don't re-derive
them. Still open: physical dongle move from docker03, `/etc/rtl_433/rtl_433.conf` + systemd
service, fail2ban/beszel-agent on CT207. Full context in
`docs/memory_docker03-decommission.md`.
