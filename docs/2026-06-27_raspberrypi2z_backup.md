# raspberrypi2z: Monthly SD card backup

## What is backed up

Full compressed SD card image via `dd | gzip`. Runs on the **2nd of each month at 02:07**.

Backup chain:
1. `pi-backup.sh` writes image to NFS share → `backup_usb1` on gr-srv03
2. ceres `backup-usb1-local.sh` (03:00 daily) snapshots that into restic on BACKUP_A/B (tag `raspberrypi`, keep-last 3)

## Setup (for disaster rebuild)

### Prerequisites

```bash
sudo apt-get install -y nfs-common
```

### gr-srv03: NFS export

`/etc/exports` entry (192.168.1.173 is raspberrypi2z's LAN IP — set a DHCP reservation):
```
/mnt/backup_usb1/raspberrypi2z 192.168.1.173(rw,sync,no_subtree_check,no_root_squash,nohide)
```
Directory: `/mnt/backup_usb1/raspberrypi2z/`  
Reload: `sudo exportfs -ra`

### raspberrypi2z: NFS mount

`/etc/fstab` entry:
```
192.168.1.3:/mnt/backup_usb1/raspberrypi2z /mnt/backup nfs nofail,soft,timeo=30,retrans=2,x-systemd.automount,x-systemd.device-timeout=10 0 0
```

```bash
sudo mkdir -p /mnt/backup
sudo systemctl daemon-reload
sudo mount /mnt/backup
```

### raspberrypi2z: sudoers for dd

`/etc/sudoers.d/backup-nopasswd`:
```
rsi ALL=(ALL) NOPASSWD: /bin/dd
```

### raspberrypi2z: pushover credentials

`~/etc/pushover.env` (chmod 600), same structure as other hosts.

### raspberrypi2z: script and cron

```bash
sudo install -m 755 raspberrypi2z/backup/pi-backup.sh /usr/local/bin/pi-backup.sh
```

Cron (runs as rsi):
```
7 2 2 * * /usr/local/bin/pi-backup.sh >> /tmp/pi_backup_cron.log 2>&1
```

## Key parameters

| Parameter | Value |
|---|---|
| `REQUIRED_SPACE_GB` | 10 |
| `MAX_BACKUPS` | 3 |
| Source device | `/dev/mmcblk0` |
| Image location | `/mnt/backup/images/raspberrypi2z-YYYYMMDD-HHMMSS.img.gz` |

## Restore procedure

```bash
gunzip -c raspberrypi2z-YYYYMMDD-HHMMSS.img.gz | sudo dd of=/dev/sdX bs=4M status=progress
```

Verify checksum first:
```bash
sha256sum -c raspberrypi2z-YYYYMMDD-HHMMSS.img.gz.sha256
```

## Monitoring

- Logs: `~/bak/backup-pi.log` on raspberrypi2z
- Pushover notification on completion and on errors
- Cron output: `/tmp/pi_backup_cron.log`

## ceres: backup-usb1-local.sh change

Backup 6 ("raspberrypi") in `/home/rsi/backup_greven/scripts/backup-usb1-local.sh` was updated to include `/mnt/backup_usb1/raspberrypi2z` alongside `/mnt/backup_usb1/raspberrypi1`.
