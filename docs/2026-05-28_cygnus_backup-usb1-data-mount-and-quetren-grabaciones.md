# cygnus: backup_usb1 data mount and quetren grabaciones relocation

**Date:** 2026-05-28

## What was done

1. Created `/mnt/backup_usb1/data/cygnus` on gr-srv03 as a working data directory for the cygnus container.
2. Mounted it inside cygnus at `/mnt/data`.
3. Moved `quetren`'s `grabaciones` directory (958 MB) from the rootfs to `/mnt/data/grabaciones`.

## Motivation

The cygnus rootfs is a 6 GB disk. The `grabaciones` directory (audio recordings processed by quetren) was growing and consuming rootfs space. Moving it to the USB backup drive frees rootfs headroom.

## Host-side directory setup

```bash
mkdir -p /mnt/backup_usb1/data/cygnus
chown root:root /mnt/backup_usb1/data
chmod 755 /mnt/backup_usb1/data
chown 101000:101000 /mnt/backup_usb1/data/cygnus
chmod 755 /mnt/backup_usb1/data/cygnus
```

**UID mapping note:** cygnus is an unprivileged LXC (ID 202). Container UID 1000 maps to host UID 101000 (100000 + 1000). `chown 101000` gives the `rsi` user inside cygnus r/w access without needing world-writable permissions. See `Proxmox_unpriviedged_LXC_mount_permissions.md` for background.

## LXC mount point

Added to `/etc/pve/lxc/202.conf` via `pct set 202 -mp4 ...`:

```
mp4: /mnt/backup_usb1/data/cygnus,mp=/mnt/data
```

`backup_usb1` is a static fstab mount (always present at boot), so a standard `mp` directive is sufficient — slave propagation is not needed (unlike `backup_a`/`backup_b` hotplug drives).

## quetren compose.yml change

In `/home/rsi/quetren/servidor/compose.yml`, the grabaciones volume was updated from relative to absolute path:

```yaml
# Before
- ./grabaciones:/app/grabaciones:rw

# After
- /mnt/data/grabaciones:/app/grabaciones:rw
```

The directory was moved with `mv` (same filesystem would not apply here since it's a different mount, so it was a copy+delete — took a moment for 958 MB).

## Result

- Rootfs usage dropped from ~4.5 GB to ~3.5 GB (2.1 GB free on 5.9 GB usable)
- quetren container running normally, `/app/grabaciones` correctly mounted
