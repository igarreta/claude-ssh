# Memory: Feedback & Preferences

**Status:** active
**Host:** (fleet)
**Supersedes:** —
**Superseded-by:** —

## Docs and memory location

Always save documentation, incident write-ups, and memory content in the local `docs/` directory of the claude-ssh repo (`/home/rsi/claude-ssh/docs/`), not on the remote machine being documented.

- When creating any .md doc about a remote system, write it locally with the Write tool to `/home/rsi/claude-ssh/docs/`
- Memory content goes in `docs/memory_*.md` (git-tracked), not only in `~/.claude/projects/`
- Keep `~/.claude/projects/MEMORY.md` as a short index only

## No passwordless sudo on castor

Do not configure passwordless sudo on castor. The user explicitly said they do not like it (2026-05-29).

Use `pct exec 205 -- <cmd>` from gr-srv03 instead of suggesting `NOPASSWD` sudoers entries. Do not propose passwordless sudo as a convenience improvement on castor.

## Browser requires HTTPS for Tailscale addresses — LAN hostnames are fine over plain HTTP

The user's browser refused plain `http://100.96.140.37:5050` (a Tailscale IP) on 2026-06-22,
so a Caddy+Tailscale-cert HTTPS front end was built for pgAdmin on cygnus. But on 2026-08-16,
`http://docker03:4000/` (a plain LAN hostname) worked fine directly in the browser — no HTTPS
needed, confirmed after an unnecessary `tailscale serve` HTTPS proxy was set up for
mqtt-explorer and then torn down once this was clarified.

**How to apply:** Don't assume every plain-HTTP link needs an HTTPS front end. Give the plain
`http://<lan-hostname>:<port>` link first if the service is reachable by LAN hostname; only
build/use an HTTPS path (Caddy reverse proxy, `tailscale serve`) when the user reports it
doesn't open, or when the only address available is a Tailscale IP (100.x range).

## docker03 sudo requires a password

`sudo` on docker03 requires a password — `mcp__docker03__sudo-exec` fails with "a password is required" (found 2026-07-05, see `docs/2026-07-05_docker03_fail2ban-fix.md`).

**Why:** No passwordless sudoers entry configured for `rsi` on docker03 (same situation as raspberrypi2z and castor).

**How to apply:** For privileged operations, write the file/script locally with `Write`, `scp` it to `/tmp/` on docker03, then give the user the exact `sudo` command to run themselves. Do not attempt `sudo-exec` directly on docker03.
