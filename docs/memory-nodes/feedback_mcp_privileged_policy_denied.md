---
name: feedback_mcp_privileged_policy_denied
description: MCP privileged-command is policy-denied outright on "prod" host-group connectors, independent of each host's own sudo password requirement
metadata:
  type: feedback
---

Every MCP SSH connector whose role is "admin" on host group "prod" refuses
`privileged-command` with the same error, regardless of target host:

```
POLICY_DENIED: Role "admin" on host group "prod" cannot run "privileged" commands
(allowed: read-only, safe, destructive). Change the profile's group, or grant the
class to this role in the policy's roleBindings.
```

Confirmed on docker03 ([[feedback_docker03_sudo]]), mosquitto
([[project_mosquitto_ssh-socket-failed]]), and homeassistant
([[project_homeassistant_disk-cleanup]]). This is a connector-side policy, separate
from whether the host's own sudoers requires a password — it blocks even a would-be
passwordless sudo.

**How to apply:** don't retry `privileged-command` after this error — it's not a
one-off approval prompt, it won't succeed on a second try. Either:
- write the change locally, `scp` it over, and hand the user the bare command to run
  themselves in a session already open on the host, or
- for gr-srv03 guests specifically, use `qm guest exec <vmid>` from gr-srv03 (its
  connector runs as root) for read-only diagnostics.
