---
name: project_gr-srv03_ct901-template
description: "CT901 replaced CT900 as gr-srv03's LXC clone template (3 GB, on local-lvm); CT900 kept as rollback"
metadata: 
  node_type: memory
  type: project
  originSessionId: f6d6ecb3-af43-4428-b37d-580c789b4010
  modified: 2026-08-28T12:28:39.741Z
---

CT900 (`deb13templ1`, 6 GB, on USB dir storage) was shrunk to CT901 (`deb13templ2`, 3 GB, on
`local-lvm`) by restoring CT900's own vzdump into a smaller rootfs, then `pct template 901`.
Done 2026-08-28 as part of [[project_docker03_decommission]] needing 3 GB LXCs.

**Why it matters:** any future "clone the standing Debian 13 template" request on gr-srv03
should target **CT901, not CT900**. CT900 was deliberately kept running (not destroyed) as a
rollback per the user's explicit choice — don't suggest deleting it without asking again.

**How to apply:** CT901 carries a baked-in personal SSH deploy key (`~/.ssh/id_ed25519`, for
`git@github.com:igarreta/bin.git`) and password-required sudo (no NOPASSWD override) — every
clone inherits both. Full inventory and rebuild steps:
docs/2026-08-28_gr-srv03_ct901-new-template.md.
