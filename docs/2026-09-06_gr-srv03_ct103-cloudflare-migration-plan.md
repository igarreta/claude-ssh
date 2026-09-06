# CT103 (cloudflaretunnel) Debian 12 → 13 migration plan

**Status:** open
**Host:** gr-srv03
**Supersedes:** —
**Superseded-by:** —

CT103 is the last general-purpose LXC still on Debian 12 (bookworm); CT101 (Samba03,
Turnkey) is the other one but is being deprecated outright, not migrated. CT103 runs only
`cloudflared` (systemd, token-based tunnel, no config.yml) plus stock `tailscaled` and
`postfix`. Minimal footprint — 1 core, 256M mem, 4G disk, tun device passthrough for
Tailscale (`lxc.mount.entry` + `lxc.cgroup2.devices.allow` for `/dev/net/tun`).

## Plan

1. Clone the Debian 13 template (CT901) to a new CTID, matching CT103's resources and the
   tun device passthrough.
2. Install `cloudflared` + `tailscale` on the clone; reuse CT103's existing tunnel token
   (`ExecStart=/usr/bin/cloudflared --no-autoupdate tunnel --metrics <ip>:2000 run --token
   <token>` — the token lives in Cloudflare's dashboard, not tied to the OS).
3. Join Tailscale, start the tunnel, verify `/ready` on the new container's own metrics port.
4. Update the uptime-kuma "cloudflare" monitor to the new Tailscale IP (see
   [memory_docker03-decommission.md](memory_docker03-decommission.md) for why it must hit
   `/ready`, not the public tunnel hostname).
5. Stop `cloudflared` on old CT103 — the tunnel is outbound-only, so there's no DNS/IP
   cutover, just don't run two connectors for the same tunnel at once.
6. Soak, then decommission CT103.

Low risk: no inbound traffic targets CT103's IP directly (Cloudflare routes via the
tunnel connector, not IP), so rollback is just restarting `cloudflared` on the old
container. Estimated at **well under 30 minutes** of hands-on work.
