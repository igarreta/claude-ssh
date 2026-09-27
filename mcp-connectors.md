# MCP Connectors Configuration

This document describes the MCP (Model Context Protocol) connectors configured for Claude Code on comet.

## Overview

MCP connectors allow Claude to interact with external services and remote machines. Configuration is stored in `~/.claude.json` under the `mcpServers` section.

## SSH Connectors

SSH connectors use the `ssh-mcp` package to execute commands on remote machines.

### Configured Servers

| Name | Host | User | Port | Description |
|------|------|------|------|-------------|
| docker03 | docker03 | rsi | 22 | Docker host |
| gr-srv03 | 100.89.202.69 | root | 22 | GR server |
| ceres | 100.64.121.121 | rsi | 22 | Ceres server |
| contabo1 | 100.72.195.90 | rsi | 1789 | Contabo VPS (migrating to contabo2)|
| contabo2 | 100.77.125.40 | rsi | 1789 | Contabo VPS |
| cygnus | 100.96.140.37 | rsi | 22 | Cygnus server |
| castor | 100.65.209.119 | rsi | 22 | PostgreSQL DB server |
| raspberrypi1 | 100.111.232.99 | rsi | 22 | Raspberry Pi |
| raspberrypi2z | 100.92.195.47 | rsi | 22 | Raspberry Pi Zero W, 433 MHz temp sensors |
| samba03 | 100.77.7.42 | root | 22 | Samba server |
| living1 | 100.72.156.127 | rsi | 22 | stream to TV - not allways on |
| mosquitto | 100.69.153.63 | rsi | 22 | Dedicated MQTT broker LXC (gr-srv03, VMID 105) |

### SSH Key

All SSH connections use the key: `~/.ssh/id_ed25519_comet`

### Configuration Example

```json
"server-name": {
  "command": "npx",
  "args": [
    "-y",
    "ssh-mcp",
    "--",
    "--host=<ip-or-hostname>",
    "--port=<port>",
    "--user=<username>",
    "--key=/home/rsi/.ssh/id_ed25519_comet"
  ]
}
```

## GitHub Connector

Provides access to GitHub repositories, issues, pull requests, and more.

### Package

`@modelcontextprotocol/server-github`

### Wrapper Script

`~/etc/github-mcp.sh`

```bash
#!/bin/bash
export GITHUB_PERSONAL_ACCESS_TOKEN=$(cat /home/rsi/.ssh/github-token)
exec npx -y @modelcontextprotocol/server-github "$@"
```

### Credentials

- **File**: `~/.ssh/github-token`
- **Content**: GitHub Personal Access Token (PAT)
- **Permissions**: 600

### Creating a GitHub PAT

1. Go to https://github.com/settings/tokens
2. Generate new token (classic)
3. Required scopes: `repo`, `read:org`, `read:user`
4. Save token to `~/.ssh/github-token`

### Available Operations

- Search repositories, code, issues, users
- Create/read/update issues and pull requests
- Manage repository files and branches
- Create commits and reviews

## Notion Connector

Provides access to Notion workspaces, pages, databases, and blocks.

### Package

`@notionhq/notion-mcp-server`

### Wrapper Script

`~/etc/notion-mcp.sh`

```bash
#!/bin/bash
export OPENAPI_MCP_HEADERS=$(cat /home/rsi/.ssh/notion-headers)
exec npx -y @notionhq/notion-mcp-server "$@"
```

### Credentials

- **File**: `~/.ssh/notion-headers`
- **Content**: JSON with Authorization header
- **Permissions**: 600

**Format:**
```json
{"Authorization": "Bearer <notion-api-key>", "Notion-Version": "2022-06-28"}
```

### Creating a Notion Integration

1. Go to https://www.notion.so/my-integrations
2. Create new integration
3. Copy the "Internal Integration Secret"
4. Save to `~/.ssh/notion-headers` in the format above
5. Share pages/databases with the integration in Notion

### Available Operations

- Search pages and databases
- Create/read/update/delete pages and blocks
- Query databases
- Manage comments

## Home Assistant MCP Connector (ha-mcp) — primary HA connector

**Use `ha-mcp` first for any Home Assistant task** (entities, automations, scripts,
dashboards, helpers, areas, history, services, backups, etc. — ~87 tools). Verified
working end-to-end 2026-09-27 (`ha_get_overview` returned live data: HA 2026.9.3,
RUNNING, 500+ entities across 30 domains). Only fall back to the `homeassistant` SSH
connector for shell/log/filesystem-level diagnostics that ha-mcp's tool surface doesn't
cover — its `/config` write access has been broken since 2026-09-11 anyway (see
`docs/2026-09-13_homeassistant_config-write-path-lost.md`).

### What it is

The [homeassistant-ai/ha-mcp](https://github.com/homeassistant-ai/ha-mcp) add-on
("app"), installed in Home Assistant. It runs an MCP server in-process inside HA and
exposes it directly as an HTTP/JSON-RPC (Streamable HTTP) endpoint — no local process on
comet reaches out to HA; comet connects **to** HA's endpoint as a remote MCP server.

### Configuration

Registered as a **local-scope** MCP server (`claude mcp add-json ha-mcp '{...}' -s
local`), which Claude Code stores in `~/.claude.json` under this project's entry — **not**
in this repo's git-tracked `.mcp.json`. This matters because the connection URL itself is
the credential (see below), so it must stay out of git, matching the credential-security
principle already used for the GitHub/Notion connectors.

```bash
claude mcp add-json ha-mcp '{"type":"http","url":"<see ~/.ssh/homeassistant-mcp-url>"}' -s local
```

### Authentication

Token-in-URL: the add-on generates a random `/private_<token>` path segment that *is*
the credential (no separate header/bearer token). The full URL is stored in
`~/.ssh/homeassistant-mcp-url` (600 permissions), same rationale as the other
`~/.ssh/`-stored credentials below.

### Access mode

Configured full read-write (no `read_only_mode`) — matches the access level of every
other connector here (they're all full shell). The add-on does offer a `read_only_mode`
toggle in its own config if write access ever needs to be revoked without removing the
connector.

### Webhook URL — not used

The add-on's optional "Webhook Proxy" companion app also creates a
`http://<ha-host>:8123/api/webhook/mcp_<id>` URL. That's for routing MCP traffic through
Nabu Casa/a reverse proxy so *internet* clients (e.g. claude.ai web) can reach the
server without port-forwarding. Not needed here — comet reaches the HA host directly
(both its LAN IP and its Tailscale IP work), so this connector uses the add-on's direct
`:9584/private_<token>` endpoint only.

### homeassistant-ai/skills

A companion best-practices Agent Skill (HA automation/dashboard/YAML conventions),
unrelated to ha-mcp's runtime (no dependency between them). Installed project-level:

```bash
npx skills add homeassistant-ai/skills
```

Lands in `.agents/skills/` (universal format) with a symlink at
`.claude/skills/home-assistant-best-practices` for Claude Code — both git-tracked, no
secrets involved.

## Credential Security

Credentials are stored in `~/.ssh/` because:

- Directory has restrictive permissions (700)
- Commonly excluded from backups
- Standard location for authentication material

Wrapper scripts in `~/etc/` do not contain secrets - they only reference credential files.

## Tailscale Network

Most SSH servers use Tailscale IP addresses (100.x.x.x). Ensure:

1. Tailscale is running: `tailscale status`
2. ACLs allow access from comet (100.125.21.4) to target machines

## Direct SSH/SCP from comet

MCP connectors do not verify host keys (ssh-mcp passes no `hostVerifier` to ssh2).
Direct `ssh`/`scp` from the comet terminal does verify them via `~/.ssh/known_hosts`.

When a new host is added or its Tailscale IP changes, run:
```bash
ssh-keyscan -H <ip> >> ~/.ssh/known_hosts
```

To re-scan all configured hosts at once:
```bash
ssh-keyscan -H 100.64.121.121 100.89.202.69 100.72.195.90 100.77.125.40 \
  100.96.140.37 100.111.232.99 100.92.195.47 100.77.7.42 100.72.156.127 >> ~/.ssh/known_hosts
```

## Troubleshooting

### SSH Connection Issues

```bash
# Test direct SSH connection
ssh -i ~/.ssh/id_ed25519_comet user@host "hostname"

# Check Tailscale connectivity
tailscale ping <ip-address>

# Verbose SSH debugging
ssh -vv -i ~/.ssh/id_ed25519_comet user@host
```

### GitHub/Notion Issues

```bash
# Test GitHub token
curl -H "Authorization: token $(cat ~/.ssh/github-token)" https://api.github.com/user

# Test Notion token
curl -H "Authorization: Bearer <token>" -H "Notion-Version: 2022-06-28" https://api.notion.com/v1/users/me
```

## Adding New SSH Servers

1. Edit `~/.claude.json`
2. Add new entry under `projects["/home/rsi"].mcpServers`
3. Restart Claude Code

## File Locations Summary

| File | Purpose |
|------|---------|
| `~/.claude.json` | Main Claude configuration with MCP servers |
| `~/.ssh/id_ed25519_comet` | SSH private key for all servers |
| `~/.ssh/github-token` | GitHub Personal Access Token |
| `~/.ssh/notion-headers` | Notion API authorization headers |
| `~/etc/github-mcp.sh` | GitHub MCP wrapper script |
| `~/etc/notion-mcp.sh` | Notion MCP wrapper script |
