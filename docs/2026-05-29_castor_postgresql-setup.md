# castor: PostgreSQL server setup

**Date:** 2026-05-29

## Overview

castor is a dedicated PostgreSQL database server running as an unprivileged LXC (ID 205) on gr-srv03. It is kept separate from other containers so it can be snapshotted independently before schema changes.

- **OS:** Debian 13
- **LXC ID:** 205
- **Internal IP:** 10.0.100.11 (vmbr1)
- **Tailscale IP:** 100.65.209.119
- **PostgreSQL version:** 17.10

## Mount points

| Host path | Container path | Purpose |
|-----------|---------------|---------|
| `/mnt/backup_usb1/castor` | `/mnt/backup` | Reserved for future backups |
| `/mnt/backup_usb1/data/castor` | `/mnt/data` | PostgreSQL data directory |

LXC config in `/etc/pve/lxc/205.conf`:
```
mp1: /mnt/backup_usb1/castor,mp=/mnt/backup
mp2: /mnt/backup_usb1/data/castor,mp=/mnt/data
```

## PostgreSQL data directory

The data directory was moved from the default `/var/lib/postgresql/17/main` to `/mnt/data/17/main` (USB SSD) to avoid filling the 6 GB rootfs.

**Host path:** `/mnt/backup_usb1/data/castor/17/main`
**Ownership:** `100102:100107` (postgres:postgres inside castor; unprivileged LXC mapping: container UID + 100000)

Change in `/etc/postgresql/17/main/postgresql.conf`:
```
data_directory = '/mnt/data/17/main'
```

The original default data directory `/var/lib/postgresql/17/main` was removed after migration to free rootfs space. `/var/lib/postgresql/` is kept (owned by the postgres system user) as it is managed by the package.

## UID mapping note

castor is an unprivileged LXC. The postgres user (UID 102, GID 107 inside container) maps to host UID **100102**, GID **100107**. When creating or moving the data directory on the host, ownership must be set accordingly. The parent directory (`/mnt/backup_usb1/data/castor/`) is `root:root 755` — postgres only needs access to its own `17/` subdirectory.

## MCP connector

The SSH MCP connector uses the Tailscale IP. Entry in `/home/rsi/claude-ssh/.mcp.json`:
```json
"castor": {
  "command": "npx",
  "args": ["-y", "ssh-mcp", "--", "--host=100.65.209.119", "--user=rsi", "--key=/home/rsi/.ssh/id_ed25519_comet"]
}
```

## PostgreSQL MCP connector (castor-pg)

Allows Claude to query PostgreSQL directly via `@modelcontextprotocol/server-postgres`.

**Network access:** PostgreSQL listens on `localhost` and `100.65.209.119` (Tailscale). Connections from the Tailscale range (`100.64.0.0/10`) are allowed in `pg_hba.conf` using `scram-sha-256` auth.

Changes in `/etc/postgresql/17/main/postgresql.conf`:
```
listen_addresses = 'localhost,100.65.209.119'
```

Added to `/etc/postgresql/17/main/pg_hba.conf`:
```
host    all             mcp             100.64.0.0/10           scram-sha-256
```

**Credentials:**
- User: `mcp` (non-superuser, full privileges on `postgres` database)
- Connection URL stored in: `~/.ssh/castor-pg-url` (permissions 600)
- Wrapper script: `~/etc/castor-pg-mcp.sh`

Entry in `/home/rsi/claude-ssh/.mcp.json`:
```json
"castor-pg": {
  "command": "/home/rsi/etc/castor-pg-mcp.sh",
  "args": []
}
```

## Privileged operations

`rsi` requires a password for sudo on castor. Use `pct exec 205 -- <command>` from gr-srv03 instead, which runs as root inside the container.
