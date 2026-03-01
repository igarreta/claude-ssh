# Tailscale ACL Configuration

## Overview

All machines are on the same tailnet: `tail366c79.ts.net` (account: `ramon.igarreta@gmail.com`).

Connectivity between nodes is controlled by ACL rules and grants in the Tailscale admin console (`login.tailscale.com/admin/acls`).

## Tags

| Tag | Purpose |
|-----|---------|
| `tag:server` | Physical/VM servers (e.g. gr-srv03) |
| `tag:worker` | Worker nodes |
| `tag:entry-node` | Entry/exit nodes |
| `tag:docker-container` | Docker containers |

## Key Gotcha: tagged nodes vs user-owned nodes

Devices with a tag (e.g. `tag:server`) do **not** automatically have connectivity to user-owned devices and vice versa. They must be explicitly granted access via the `grants` section.

**Symptom:** `ping` and `nc` time out between two nodes even though both show `tailscale status` and are on the same tailnet. The nodes will not appear in each other's peer list.

**Fix:** Add a grant in the ACL policy.

## Grants (node-to-node access)

| Source | Destination | Purpose |
|--------|-------------|---------|
| `100.125.21.4` (comet) | `*` | comet can reach all machines |
| `host:nb-rsigarreta` | `tag:server` | laptop can reach all servers |
| `100.72.195.90` (contabo1) | `100.89.202.69` (gr-srv03) | NFS backup mount |
| `100.77.125.40` (contabo2) | `100.89.202.69` (gr-srv03) | NFS backup mount |

## Adding access between two nodes

Add an entry to the `grants` section:

```json
{
    "src": ["<source-tailscale-ip>"],
    "dst": ["<dest-tailscale-ip>"],
    "ip":  ["*"],
},
```

Changes propagate within seconds after saving.

## NFS over Tailscale notes

- gr-srv03 (`100.89.202.69`) runs `nfs-kernel-server` exporting `/mnt/backup_usb1/`
- Exports are restricted by Tailscale IP in `/etc/exports`
- gr-srv03 also has an iptables rule in `ts-input` chain accepting each client IP (persisted via `netfilter-persistent`)
- Mount options used: `vers=3,rsize=8192,wsize=8192,nofail,x-systemd.automount,x-systemd.device-timeout=10`
  - Small rsize/wsize required due to WireGuard MTU limits (MTU 1280 on tailscale0)
