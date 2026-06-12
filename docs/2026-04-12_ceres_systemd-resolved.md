# ceres: systemd-resolved setup

**Date:** 2026-04-12  
**Host:** ceres (Debian 13 LXC, gr-srv03 ID 203)

## Problem

On each DHCP lease renewal, `dhclient` overwrote `/etc/resolv.conf` with the ISP's DNS config. `tailscaled` detected this and immediately rewrote it back, causing a brief load spike and journal warnings:

```
tailscaled: health(warnable=resolv-conf-overwritten): error: System DNS config not ideal.
tailscaled: dns: resolve.conf was trampled, setting existing config again
```

## Solution

Install `systemd-resolved` and point `resolv.conf` to its stub. The dhclient hooks (`/etc/dhcp/dhclient-enter-hooks.d/resolved-enter` and `/etc/dhcp/dhclient-exit-hooks.d/resolved`) were already present on Debian 13 — they disable `make_resolv_conf()` and feed DHCP DNS to resolved via `resolvectl` when systemd-resolved is enabled.

## Steps

```bash
# Install (not included by default in Debian 13 minimal/LXC)
sudo apt install systemd-resolved

# Stop tailscaled before replacing resolv.conf (it will re-grab it otherwise)
sudo systemctl stop tailscaled
sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
sudo systemctl start tailscaled
```

## Result

- `resolv.conf` is now a symlink → `/run/systemd/resolve/stub-resolv.conf`
- `resolvectl status` shows `resolv.conf mode: stub`
- Tailscale uses `resolvectl` instead of writing resolv.conf directly
- DHCP renewals feed DNS to resolved via hook — no more file conflicts

## Notes

- The dhclient hooks check `systemctl is-enabled systemd-resolved` — the service must be **enabled**, not just started
- Must stop tailscaled before creating the symlink, otherwise tailscale immediately overwrites it
- Applies to any Debian 13 LXC/VM with both tailscale and dhclient
