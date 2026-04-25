# gr-srv03: LVM Space Monitor and docker03 Thin Provisioning Fix

**Date:** 2026-04-25

## Background

The LVM thin pool (`pve/data`) on gr-srv03 previously ran out of space and caused filesystem corruption. After recovery, two actions were taken: add a Pushover alert for future space issues, and reclaim wasted thin pool space in docker03.

## 1. LVM Thin Pool Monitor

### What was set up

Script: `/opt/proxmox-grsrv03/monitoring/lvm-space-monitor.sh`

Monitors the `pve` VG thin pools only (thin volumes like VM disks are excluded). Sends a Pushover notification if `Data%` or `Meta%` exceeds 90%. Credentials sourced from `/opt/shared-secrets/pushover.env`.

Cron entry in rsi's crontab on gr-srv03:
```
*/30 * * * * sudo /opt/proxmox-grsrv03/monitoring/lvm-space-monitor.sh >> /var/log/lvm-space-monitor.log 2>&1
```

### Key design decision

`lvs` without filtering reports `data_percent` for all volumes including individual VM disks. `vm-102-disk-0` was showing 96% and would have triggered false alerts. The script filters with `-S 'lv_attr=~^t'` to target only thin pool LVs.

---

## 2. docker03 Thin Provisioning Fix

### Problem

`vm-102-disk-0` (docker03, 64 GB virtual) showed 96.84% allocated in the thin pool, but the filesystem inside was only 44% full. The gap (~35 GB) was due to `discard=on` being missing from the VM's disk config. Without it, `fstrim` inside the guest never propagated discards to the host LVM, so deleted blocks were never returned to the thin pool.

### Fix

1. Added `discard=on` to the disk config:
   ```
   qm set 102 --scsi0 local-lvm:vm-102-disk-0,iothread=1,size=64G,discard=on
   ```
2. Rebooted VM 102 to apply the pending config change.
3. Ran fstrim via the QEMU guest agent (rsi has no root on docker03):
   ```
   qm guest exec 102 -- /bin/bash -c "nohup /usr/sbin/fstrim -v / > /tmp/fstrim.out 2>&1 &"
   ```

### Result

| Metric | Before | After |
|--------|--------|-------|
| `pve/data` pool usage | 74.77% | 53.34% |
| `vm-102-disk-0` allocation | 96.84% | 44.21% |

~34 GB reclaimed from the thin pool.

### Notes

- `fstrim.service` systemd timer was already enabled on docker03 and running weekly. Future trims will now correctly propagate discards to the host.
- Running fstrim via `qm guest exec` requires a background + poll approach because the MCP tool has a 60s timeout and fstrim on a large volume can exceed that:
  ```bash
  qm guest exec 102 -- /bin/bash -c "nohup /usr/sbin/fstrim -v / > /tmp/fstrim.out 2>&1 &"
  # wait, then:
  qm guest exec 102 -- cat /tmp/fstrim.out
  ```
