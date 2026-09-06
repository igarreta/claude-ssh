---
name: project_gr-srv03_rtl433-ct207
description: "CT207 LXC for rtl_433, permanently test/backup-only (not a raspberrypi2z replacement); dongle moved from docker03 and re-tested 2026-09-05, beszel-agent still pending"
metadata: 
  node_type: memory
  type: project
  originSessionId: b868f20e-cebb-4117-b221-e8b65fd87fab
  modified: 2026-09-06T00:57:08.948Z
---

CT207 (`10.0.100.13`) is a dedicated LXC for rtl_433, part of the docker03 decommission
([[project_docker03_zigbee_rf_degradation]] sibling — same reasoning: USB/kernel instability
needs the LXC boundary, not just container isolation). Built from CT901 template, `rtl-433`
installed, host-side USB passthrough (DVB-driver blacklist, udev rule, whole-tree
`/dev/bus/usb` bind mount) done. Proven working twice: an initial capture test 2026-09-05, and
a second test 2026-09-05 after physically moving the real dongle from docker03.

**Why it matters:** CT207's role is now settled as **permanent test/backup only** — the user
does not plan to move raspberrypi2z's production rtl_433 service here, because gr-srv03 is the
wrong physical location for antenna reception of those sensors. Don't treat the unfinished
`rtl_433.conf`/systemd-service/beszel-agent items as blocking decommission work — they're
"do if/when needed for a test," not open migration steps. fail2ban was dropped from the plan:
Tailscale-only nodes don't need it, see [[feedback_fail2ban_tailscale_only]].

**How to apply:** before touching this again, read `docs/memory_rtl433-lxc-ct207.md` — it also
has the saved dmesg from the second test (the DVB driver grabbed the dongle again despite the
blacklist; unclear if the blacklist ever actually prevents the hotplug grab or a manual unbind
is always required) for if/when this service is ever made permanent. Full context in
`docs/memory_docker03-decommission.md`.
