# gr-srv03: Disable apt-daily Timers

**Date:** 2026-05-13

## Background

The `apt-daily.timer` and `apt-daily-upgrade.timer` systemd timers run daily on the Proxmox host to refresh package lists and auto-install security updates. On a Proxmox host this is undesirable — Proxmox manages its own package repos and updates should be applied manually during maintenance windows to avoid unexpected reboots or interference with PVE kernel/package management.

The timers were observed causing 43% I/O wait while `apt-get check -qq` was stuck in uninterruptible D state, spiking the host load average.

## Fix

```bash
systemctl disable --now apt-daily.timer apt-daily-upgrade.timer
```

This removes the symlinks from `timers.target.wants` and stops both timers immediately.

## Verify

```bash
systemctl list-timers apt-daily.timer apt-daily-upgrade.timer
# Should show: 0 timers listed
```
