# Comet - Internet Connectivity Loss (Tailscale Logged Out)

**Date:** July 12, 2026
**Container:** comet (LXC, CT 204 on gr-srv03)

---

## Symptom

- `ping <IP>` worked (gateway 192.168.1.1 and 8.8.8.8 both reachable)
- `ping google.com` failed: `Temporary failure in name resolution`
- Claude Code (and anything relying on DNS) stopped working

## Immediate Cause

`/etc/resolv.conf` pointed only to Tailscale's MagicDNS resolver:

```
nameserver 100.100.100.100
nameserver fd7a:115c:a1e0::53
```

This resolver only works while `tailscaled` is authenticated and connected to the
coordination server. `sudo tailscale status` showed `Logged out.` The `tailscale0`
interface still had a stale IP from the previous session, which masked the fact that
the daemon was actually logged out — raw IP connectivity (via the LXC's normal
network, not Tailscale) kept working fine.

## Root Cause (confirmed)

**gr-srv03 (the Proxmox host) had a power outage around midday on 2026-07-12.**

This killed comet's LXC (CT 204) abruptly, with no graceful shutdown sequence.
`journalctl -b -1` for the prior boot cuts off mid-stream at 11:49:14 with no
`Stopping...`/`Reached target Shutdown` messages, and `last -x reboot` flags the
resulting boot as `crash`. The abrupt kill corrupted/truncated
`/var/lib/tailscale/tailscaled.state`, so on restart `tailscaled` came up logged out
instead of reconnecting with its saved credentials. That's what broke MagicDNS.

Ruled out during investigation:
- **Node key expiry** — comet's Tailscale key doesn't expire until 2027-01-08; not
  the cause.
- **Extended outage** — an unprivileged-user journal read initially suggested a
  ~22h gap (last visible entry 2026-07-11 13:18, boot start 2026-07-12 11:51), but
  this was a permission artifact. With `sudo`, the previous boot's journal shows
  normal activity right up to 11:49:14 — a normal-length gap, not a day-long outage.
- **Internal trigger** (apt/unattended-upgrades, cron) — no `reboot-required` flag,
  no matching apt history, no reboot cron in the container.

## Fix

```bash
sudo tailscale up
```

Re-authenticate via the printed URL, then verify:

```bash
sudo tailscale status
ping google.com
```

## Diagnostic Sequence (for future reference)

1. `ping <IP>` works, `ping <hostname>` fails → DNS issue, not routing.
2. `cat /etc/resolv.conf` → confirm which resolver is configured.
3. If resolver is `100.100.100.100` (Tailscale MagicDNS):
   - `sudo tailscale status` → check for `Logged out.`
   - `sudo tailscale status --json | grep -E '"KeyExpiry"|"Expired"|"Online"|"ID"'`
     → rule out key expiry on comet's own node entry.
4. If logged out with a valid (non-expired) key, suspect an ungraceful
   restart corrupting `tailscaled.state`:
   - `last -x reboot` → look for `crash` entries.
   - `sudo journalctl -b -1 --no-pager | tail -80` → check whether the previous
     boot ends abruptly (no shutdown-target messages) vs. gracefully.
   - **Note:** journal reads without `sudo` are silently truncated to
     user-visible messages only (sshd, cron for that user) and can make an
     ordinary restart look like a multi-hour outage. Always re-check with
     `sudo` before concluding there was an extended gap.
5. If logged out: `sudo tailscale up` to re-authenticate.

## Note

An interface (`tailscale0`) having an assigned IP does **not** guarantee the daemon
is authenticated/connected. Always check `tailscale status` explicitly rather than
inferring health from `ip a`.

## Follow-up

This ties to gr-srv03's history of hardware/power instability (see
`/opt/proxmox-grsrv03/docs/`). No action needed on comet itself beyond the
re-auth — the corrupted state was a one-off consequence of the host losing power,
not a comet-specific defect. If `tailscaled` logs out again *without* a
corresponding gr-srv03 outage, revisit the disk-corruption angle instead.
