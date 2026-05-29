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

## Passwordless sudo

`rsi` does not have passwordless sudo on castor. For privileged operations use `pct exec 205 -- <command>` from gr-srv03, which runs as root inside the container.
