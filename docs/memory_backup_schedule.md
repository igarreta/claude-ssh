# Memory: Backup schedule

All backup jobs run on gr-srv03 hardware. ceres and cygnus are LXCs sharing the host CPU — heavy jobs in both simultaneously spike load on both.

**Disk wake constraint**: gr-srv03 spins up backup HDDs (BACKUP_A/B, Toshiba) at 02:25 and 02:55. Drives spin down after ~10 min idle. Backup jobs must start within 10 min of their wake. Do not add jobs outside the 02:25–03:30 window without adding a corresponding wake entry in gr-srv03 crontab.

**Schedule (as of 2026-04-30):**

| Time | Machine | Job |
|------|---------|-----|
| 1:10 | homeassistant (104) | HA backup (~500 MB). Scheduled inside HA — not accessible via MCP. Rescheduled from 2:15 to avoid overlap. |
| 1:30 | gr-srv03 | backup-config.sh daily |
| 1:30 | cygnus | backup.sh (local copies) |
| 1:45 | ceres | backup.sh |
| 1:50 Mon | cygnus | gickup (GitHub backup via podman) |
| 2:25 | gr-srv03 | wake-backup-disks.sh |
| 2:30 | ceres | backup-wdmycloud-local.sh (WDMyCloud → BACKUP_A/B) |
| 2:55 | gr-srv03 | wake-backup-disks.sh |
| 3:00 | ceres | backup-usb1-local.sh |
| 3:08 | docker03 | rclone-copy to OneDrive |
| 3:30 day 4 | ceres | backup-wdmycloud-s3.sh (WDMyCloud → AWS) |
| 3:30 day 5 | ceres | backup-usb1-s3.sh (USB → AWS) |
| 4:00 Sun | ceres | restic check (USB verify) |
| 4:10 | ? | copias largas (RPi image, local + remote) |
| 8:05 | docker03 | proxmox_backup_checker |

**Jobs not yet confirmed in crontabs**: 3:08 docker03 rclone, 4:10 copias largas — verify on docker03.

**Why cygnus jobs are at 1:30/1:50:** Load alerts on ceres+cygnus at 2:36–2:46 were caused by cygnus backup.sh (2:07) still running when ceres WDMyCloud backup started (2:30). Cygnus jobs moved earlier (2026-04-30) to fix this.
