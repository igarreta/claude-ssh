# comet emergency/alternate access

**Status:** active
**Host:** gr-srv03, comet
**Supersedes:** —
**Superseded-by:** —

comet is **CT 204** on gr-srv03 — an LXC container, not a separate physical box (confirmed:
it shares gr-srv03's pinned kernel `7.0.14-15-pve`). It is not listed in the SSH connector
table in `mcp-connectors.md` because it's the local machine Claude Code runs on, not an
MCP target.

Because of this, existing Proxmox web GUI access to gr-srv03 is *also* a full alternate path
into comet — no SSH key or comet credentials required:

1. Log into the Proxmox web UI for gr-srv03.
2. Node tree → **gr-srv03** (the host, not the CT) → **Shell**. Authenticated by the Proxmox
   login only.
3. From that host shell: `pct enter 204` — drops into a root shell inside comet immediately,
   since you're already root on the host.

Caveats:
- Single point of failure is shared with gr-srv03 itself: if gr-srv03/Proxmox is unreachable,
  this path is gone too — same exposure as any other emergency access to that host.
- Drops you in as root, not `rsi` — fine for recovery, be careful what you run.
- This is a fallback only. It doesn't replace giving a new device (e.g. a laptop) its own
  SSH key to comet for normal use.
