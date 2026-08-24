---
name: project_gr-srv03_usb-hub-eval
description: gr-srv03 BACKUP_A USB speed baseline before switching direct connection to a powered USB hub
metadata:
  type: project
---

# gr-srv03: BACKUP_A USB speed baseline before the powered-hub switch

**Status:** superseded
**Host:** gr-srv03
**Supersedes:** —
**Superseded-by:** memory_gr-srv03_powered-hub-instability.md

Evaluating moving BACKUP_A (WD Elements 2621, WD40NDZW, 4TB, `/mnt/backup_a`) from its
current direct USB connection on gr-srv03 to a powered USB hub.

**Why:** Considering a powered hub for the backup-usb1/BACKUP_A/BACKUP_B drives on gr-srv03.
Baseline measured 2026-07-12 before the change so post-change numbers are comparable.

**How to apply:** After connecting via the powered hub, re-run the same commands and
compare against this baseline; a regression suggests the hub or its power delivery is a
bottleneck.

## Setup at baseline (direct connection)
- Device: `/dev/sdd` (`WDC_WD40NDZW-11BCVS0`), USB ID `1058:2621` (WD Elements 2621)
- Path: `pci-0000:00:14.0-usb-0:3:1.0` — behind onboard VL813 hub (`2109:0813`), port 2-3
- Link: negotiated 5000M (USB 3.0/3.1 Gen1) on the `xhci_hcd` 10000M root hub (bus 2)
- Driver: `usb-storage` (not UAS)
- Mount: `/mnt/backup_a`, ext4, `rw,noatime`

## Baseline speeds (2026-07-12)
- `hdparm -t --direct /dev/sdd`: **69.2 MB/s**
- `dd` write 1GB, `oflag=direct`, bs=1M: **100 MB/s**
- `dd` read 1GB (same file), `iflag=direct`, bs=1M: **79.3 MB/s**

Commands used:
```bash
hdparm -t --direct /dev/sdd
dd if=/dev/zero of=/mnt/backup_a/speedtest.tmp bs=1M count=1024 oflag=direct status=progress
dd if=/mnt/backup_a/speedtest.tmp of=/dev/null bs=1M iflag=direct status=progress
rm -f /mnt/backup_a/speedtest.tmp
```

Note: link is already 5Gbps, well above the ~100MB/s observed, so the drive/driver is the
current bottleneck rather than link speed — a hub is unlikely to improve throughput unless
the current setup has a marginal/unstable connection.

## Powered hub speeds (2026-07-12, same drive, reconnected via powered USB hub)
Device path became `/dev/sdc` (was `/dev/sdd`), still 5000M negotiated link via `usb-storage`.
- `hdparm -t --direct`: **61.9 MB/s** (was 69.2, −11%)
- `dd` write 1GB: **59.7 MB/s** (was 100, **−40%**)
- `dd` read 1GB: **82.0 MB/s** (was 79.3, +3%)

**Conclusion:** write throughput dropped substantially through the hub while read stayed
flat; link speed unchanged (still 5000M), so the hub (power delivery, cable, or extra tier)
is degrading write performance rather than helping. Direct connection was better for writes.
