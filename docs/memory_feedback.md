# Memory: Feedback & Preferences

## Docs and memory location

Always save documentation, incident write-ups, and memory content in the local `docs/` directory of the claude-ssh repo (`/home/rsi/claude-ssh/docs/`), not on the remote machine being documented.

- When creating any .md doc about a remote system, write it locally with the Write tool to `/home/rsi/claude-ssh/docs/`
- Memory content goes in `docs/memory_*.md` (git-tracked), not only in `~/.claude/projects/`
- Keep `~/.claude/projects/MEMORY.md` as a short index only

## No passwordless sudo on castor

Do not configure passwordless sudo on castor. The user explicitly said they do not like it (2026-05-29).

Use `pct exec 205 -- <cmd>` from gr-srv03 instead of suggesting `NOPASSWD` sudoers entries. Do not propose passwordless sudo as a convenience improvement on castor.

## Browser requires HTTPS — give HTTPS URLs, not plain HTTP

The user's browser will not open plain `http://` web UIs (2026-06-22). When pointing them at a web service, always provide the **HTTPS** URL (e.g. via the Caddy reverse proxy `https://cygnus.tail366c79.ts.net`), not the raw `http://host:port`. Set up a TLS front end if one doesn't exist rather than handing over an HTTP link.
