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

## Roles

- `rsi` role created 2026-05-31: `LOGIN CREATEDB CREATEROLE` (can create databases and users, not superuser). Connects via local peer auth (OS user `rsi` → role `rsi`). Default database `rsi` (owner `rsi`) so bare `psql` works.
- `mcp` role used by the `castor-pg` MCP connector.

## Network access (as of 2026-05-31)

- `listen_addresses = 'localhost,10.0.100.11,100.65.209.119'` set via `ALTER SYSTEM` (postgresql.auto.conf). Bound on: localhost, vmbr1 `10.0.100.11`, Tailscale `100.65.209.119`. Requires full restart (`systemctl restart postgresql@17-main`) to apply — reload is not enough.
- Note: prior to this restart PostgreSQL was only bound to localhost (Tailscale IP in config but not bound, likely Tailscale up after postgres at boot). Restart re-bound it; the `castor-pg` MCP connector depends on the Tailscale binding.
- **cygnus → castor** over vmbr1: `pg_hba.conf` rule `host all ingestion_api 10.0.100.10/32 scram-sha-256`. `ingestion_api` role given a password (TCP can't use peer). Verified port reachable from cygnus (10.0.100.10); psql not installed on cygnus so app-level auth test pending.
- vmbr1-only chosen over Tailscale for cygnus link (more secure, no Tailscale dependency at boot).

## Operational notes

- `rsi` requires a password for sudo — use `pct exec 205 -- <cmd>` from gr-srv03 for privileged ops (verified 2026-05-29)
- Do **not** configure passwordless sudo on castor (user preference)
- Snapshot before schema changes
- `/var/lib/postgresql/17/main` deleted after migration — only `/var/lib/postgresql/` (empty, package-owned) remains on rootfs
- Full setup doc: `docs/2026-05-29_castor_postgresql-setup.md`
