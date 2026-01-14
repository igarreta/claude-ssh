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
| contabo1 | 100.72.195.90 | rsi | 1789 | Contabo VPS |
| cygnus | 100.96.140.37 | rsi | 22 | Cygnus server |
| raspberrypi1 | 100.111.232.99 | rsi | 22 | Raspberry Pi |
| samba03 | 100.77.7.42 | root | 22 | Samba server |

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
