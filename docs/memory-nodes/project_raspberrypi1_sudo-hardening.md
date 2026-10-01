---
name: project_raspberrypi1_sudo-hardening
description: raspberrypi1 passwordless sudo removed 2026-09-06; only exception is a pinned-args dd rule for pi-backup.sh (2026-10-01)
metadata:
  type: project
---

raspberrypi1's NOPASSWD grant (`/etc/sudoers.d/010_pi-nopasswd`) was removed 2026-09-06,
same preference as castor ([[feedback_no_passwordless_sudo_castor]]). That broke the
monthly `pi-backup.sh` (needs `sudo dd`) on 10-01; fixed with `/etc/sudoers.d/020_pi-backup-dd`,
a NOPASSWD rule pinned to the script's exact `dd` command line.

**Why:** any other cron job or script that calls `sudo` on this host will now fail silently
the same way. Root's crontab was rejected because `~/bin` is rsi-writable and comes from a
shared repo ([[project_igarreta-bin_shared-repo-hazard]]).

**How to apply:** if a raspberrypi1 cron job fails with "a password is required", check for
`sudo` in it first. Fix with an exact-args sudoers line, not root's crontab or a broad grant.
If `pi-backup.sh` line 169 ever changes its `dd` arguments, the sudoers rule must change too.
The MCP connector can't run privileged commands here ([[feedback_mcp_privileged_policy_denied]]);
the user runs sudo steps. Detail: `docs/2026-10-01_raspberrypi1_pi-backup-sudo-failure.md`.
