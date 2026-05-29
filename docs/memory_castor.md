# Memory: castor

PostgreSQL database server running on dedicated unprivileged LXC **castor** (ID 205) in gr-srv03.

**Why:** Home database server for Claude interaction. Dedicated LXC for independent snapshots before schema changes.

## Current state (as of 2026-05-29)

- **LXC ID:** 205, Debian 13, unprivileged
- **Internal IP:** 10.0.100.11 (vmbr1)
- **Tailscale IP:** 100.65.209.119
- **PostgreSQL:** 17.10, running and enabled
- **Data directory:** `/mnt/data/17/main` inside container → `/mnt/backup_usb1/data/castor/17/main` on host (USB SSD)
- **Backup mount:** `/mnt/backup_usb1/castor` → `/mnt/backup` (reserved for future backups)

## MCP connectors

- **SSH:** `castor` in `.mcp.json` → `ssh-mcp` at `100.65.209.119`
- **PostgreSQL:** `castor-pg` in `.mcp.json` → `@modelcontextprotocol/server-postgres` via `~/etc/castor-pg-mcp.sh`; connection URL in `~/.ssh/castor-pg-url`; DB user `mcp`; listens on Tailscale IP

## UID mapping

Unprivileged LXC: postgres UID 102 → host UID 100102, GID 107 → 100107. Host data dir owned `100102:100107`.

## Operational notes

- `rsi` requires a password for sudo — use `pct exec 205 -- <cmd>` from gr-srv03 for privileged ops (verified 2026-05-29)
- Do **not** configure passwordless sudo on castor (user preference)
- Snapshot before schema changes
- `/var/lib/postgresql/17/main` deleted after migration — only `/var/lib/postgresql/` (empty, package-owned) remains on rootfs
- Full setup doc: `docs/2026-05-29_castor_postgresql-setup.md`
