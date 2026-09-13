---
name: project_homeassistant_config_write_path
description: "HA /config is no longer writable from the homeassistant ssh-mcp connector (since 2026-09-11); write via qm guest exec 104 from gr-srv03"
metadata:
  node_type: memory
  type: project
---

The `homeassistant` MCP connector logs in as `hassio` (uid 1000). Since the SSH addon container
was recreated **2026-09-11**, `/config` is a symlink to root-owned `/homeassistant`, so writes,
SFTP and the Supervisor-token `ha` CLI all fail from that session. Reads still work fine.

**Why it matters:** the failure looks like a broken connector, and the obvious fix is wrong —
turning the addon's **Protection mode off does not restore root** (tried 09-13, container was
genuinely recreated, sessions still came up uid 1000). `sudo`/`su` are closed too, by
[[feedback_mcp_privileged_policy_denied]].

**How to apply:** use the connector for reads; do writes as root in the VM with
`qm guest exec 104` from gr-srv03 (HA config dir is `/mnt/data/supervisor/homeassistant/`).
Expect HAOS quirks: no `python3`, no `gzip`, and `PATH` omits `/bin` where the tools live.
There is **no HA API token** anywhere on gr-srv03, so a YAML reload stays a user UI action.
Full procedure, including the gzip+base64 chunked file transfer:
`docs/2026-09-13_homeassistant_config-write-path-lost.md`. Related:
[[feedback_docker03_sudo]], [[project_homeassistant_temperature-sensor-naming]].
