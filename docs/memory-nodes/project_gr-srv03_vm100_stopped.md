---
name: project_gr-srv03_vm100_stopped
description: "gr-srv03 QEMU VM 100 (debian-gui) is stopped on purpose and not in use — ignore its stopped state in outage checks"
metadata:
  node_type: memory
  type: project
---

gr-srv03 QEMU VM 100 (`debian-gui`) is stopped and not in use.

**Why:** it repeatedly reads as a casualty during reboot/outage investigations and wastes a
diagnostic pass.

**How to apply:** ignore VM 100's stopped state. Related: [[project_comet_tailscale_logout]].
