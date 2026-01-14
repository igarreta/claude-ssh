## Overview
Three backup drives with different mounting strategies:
- **BACKUP_USB1**: Critical drive, mounted at startup via fstab
- **BACKUP_A & BACKUP_B**: Hotplug drives, auto-mounted on insertion via systemd + udev

## Problem Solved
Initial attempts to auto-mount hotplug drives using systemd automount units failed with:
- Dependency failures preventing mounts
- System freezes when accessing unmounted directories
- Complex configuration conflicts with local-fs.target

Solution: Use simple systemd mount units triggered by udev rules instead of automount units.

---

## Configuration Files

### 1. fstab (`/etc/fstab`)

```
UUID=b52be7b7-1bd0-4281-8c16-87ceeca5b665 /mnt/backup_usb1 ext4 defaults,nofail,noatime 0 0
```

- **BACKUP_USB1**: Active entry, mounted at startup
  - `nofail` ensures boot continues if drive missing
  - `noatime` improves performance by not updating access times
  - Mounted immediately at boot (not hotplug)

- **BACKUP_A & BACKUP_B**: Commented entries (reference only)
  - Controlled by systemd mount units, not fstab
  - Comments preserve UUIDs for future reference

### 2. Systemd Mount Units

**File**: `/etc/systemd/system/mnt-backup_a.mount`
```ini
[Unit]
Description=Backup USB Drive BACKUP_A

[Mount]
What=UUID=ef8a4442-68a6-485c-992c-9fd79b183201
Where=/mnt/backup_a
Type=ext4
Options=defaults,nofail,noatime

[Install]
WantedBy=multi-user.target
```

**File**: `/etc/systemd/system/mnt-backup_b.mount`
```ini
[Unit]
Description=Backup USB Drive BACKUP_B

[Mount]
What=UUID=2d0b0d7c-c5bd-4d8a-b477-29732001f6df
Where=/mnt/backup_b
Type=ext4
Options=defaults,nofail,noatime

[Install]
WantedBy=multi-user.target
```

**Key Points**:
- NO `DefaultDependencies`, `Before=`, or `After=` directives (these caused issues)
- Simple, minimal configuration
- `nofail` allows boot to continue if device missing

### 3. Udev Rules

**File**: `/etc/udev/rules.d/99-backup-automount.rules`
```
ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_UUID}=="ef8a4442-68a6-485c-992c-9fd79b183201", TAG+="systemd", ENV{SYSTEMD_WANTS}="mnt-backup_a.mount"
ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_UUID}=="2d0b0d7c-c5bd-4d8a-b477-29732001f6df", TAG+="systemd", ENV{SYSTEMD_WANTS}="mnt-backup_b.mount"
```

**How it works**:
- Monitors for block device additions
- Matches by filesystem UUID (not device name, which changes)
- Triggers systemd mount unit when device appears
- Automatically mounts without user intervention

---

## Usage

### Manual Mounting
```bash
# Mount BACKUP_A immediately
systemctl start mnt-backup_a.mount

# Check mount status
mount | grep backup_a
```

### Testing Hotplug (Simulated)
```bash
# Simulate device insertion
udevadm trigger --subsystem-match=block

# Check if auto-mounted
sleep 2 && mount | grep backup_
```

### Enable Auto-Mounting at Boot
```bash
systemctl enable mnt-backup_a.mount mnt-backup_b.mount
udevadm control --reload-rules
```

### Manual Unmounting
```bash
systemctl stop mnt-backup_a.mount
```

---

## Device UUIDs Reference

| Drive | UUID | Status |
|-------|------|--------|
| BACKUP_USB1 | b52be7b7-1bd0-4281-8c16-87ceeca5b665 | fstab (always mounted) |
| BACKUP_A | ef8a4442-68a6-485c-992c-9fd79b183201 | Systemd + udev (hotplug) |
| BACKUP_B | 2d0b0d7c-c5bd-4d8a-b477-29732001f6df | Systemd + udev (hotplug) |

To find device/UUID for new drives:
```bash
blkid | grep -i backup
lsblk -o NAME,UUID,LABEL
```

---

## Troubleshooting

### Drive not auto-mounting after hotplug
1. Check if device is detected: `lsblk -o NAME,UUID,LABEL`
2. Check mount unit status: `systemctl status mnt-backup_a.mount`
3. Check udev rules: `udevadm info --query=property -n /dev/sdX1 | grep ID_FS_UUID`
4. Reload udev: `udevadm control --reload-rules && udevadm trigger --subsystem-match=block`

### Mount hangs/freezes
- Never use systemd automount units (they cause dependency chains)
- Stick with simple mount units + udev rules
- If issues persist, check systemd logs: `journalctl -u mnt-backup_a.mount`

### Changing drive UUIDs
- Update both the mount unit's `What=` line
- Update the udev rule's `ENV{ID_FS_UUID}==` value
- Reload: `systemctl daemon-reload && udevadm control --reload-rules`

---

## Important Notes

- **BACKUP_USB1 is critical**: Must be mounted at startup, so it stays in fstab with `nofail`
- **BACKUP_A/B are optional**: Use hotplug mounting; boot continues if missing
- **Device names change**: Always reference by UUID, never by device name
- **No automount units**: The problematic `/etc/systemd/system/mnt-backup_*.automount` files should NOT exist