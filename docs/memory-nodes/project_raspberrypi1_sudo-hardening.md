---
name: project_raspberrypi1_sudo-hardening
description: raspberrypi1 passwordless sudo removal requested 2026-09-06, pending — same preference as castor
metadata:
  type: project
---

User asked (2026-09-06) to remove passwordless sudo on raspberrypi1, extending the same
preference already set for castor ([[feedback_no_passwordless_sudo_castor]]). Found the
likely cause — `/etc/sudoers.d/010_pi-nopasswd` (the Raspberry Pi OS default NOPASSWD
grant) — but couldn't read or remove it: raspberrypi1's MCP connector is in the "prod"
host group, which policy-denies the entire "privileged" command class, including a
read-only `sudo -l` ([[feedback_mcp_privileged_policy_denied]]).

**Why:** this is genuinely blocked from here, not just inconvenient — no MCP workaround
exists for a "prod" group host.

**How to apply:** gave the user the commands to run themselves
(`sudo rm /etc/sudoers.d/010_pi-nopasswd`, `sudo -k`, `sudo -l` to confirm). Check back —
if still not done, re-offer the same commands rather than re-investigating from scratch.
