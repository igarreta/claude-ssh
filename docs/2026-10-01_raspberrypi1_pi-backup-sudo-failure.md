# raspberrypi1 monthly pi-backup.sh failed after passwordless sudo removal

**Status:** closed
**Host:** raspberrypi1
**Supersedes:** —
**Superseded-by:** —

## What happened

`pi-backup.sh` (monthly SD-card image, cron `7 2 1 * *`, log `/tmp/pi_backup_cron.log`)
failed on 2026-10-01 at 02:07, one second after starting. Prerequisites, NFS access to
`/mnt/backup` and the space check (588 GB free) all passed; the image step died:

```
sudo: a terminal is required to read the password
sudo: a password is required
ERROR: Backup creation failed
```

No image was written. The last good image is `raspberrypi1-20260901-020701.img.gz` (5.9 GB,
with `.sha256`) in `/mnt/backup/images/`.

## Cause

The script's only privileged call is `~/bin/pi-backup.sh:169`:

```
sudo dd if=/dev/mmcblk0 bs=4M status=progress | gzip -c > "$final_img"
```

The Raspberry Pi OS default NOPASSWD grant `/etc/sudoers.d/010_pi-nopasswd` was removed
2026-09-06 14:34 (sudo hardening requested that day). 10-01 was the first monthly run after
that, so cron's `sudo` had no way to authenticate.

## Fix

A narrow sudoers rule that allows only the exact `dd` command line the script uses.
Rejected the alternative of moving the job to root's crontab: the script lives in `~/bin`,
which is rsi-writable and pulled from the shared `igarreta/bin` repo, so root-running it
would hand root to anyone who can edit the file or push to the repo. It would also make
the images root-owned on the NFS share.

`/etc/sudoers.d/020_pi-backup-dd` (mode `0440`, root:root), created by the user with
`sudo visudo -f`:

```
rsi ALL=(root) NOPASSWD: /usr/bin/dd if=/dev/mmcblk0 bs=4M status=progress
```

`/usr/bin/dd` because `/bin` is a symlink to `usr/bin` on this host. sudo matches the
arguments exactly, so `dd` cannot be used with `of=` or any other argument set. What remains
is raw read access to the SD card for rsi (which exposes `/etc/shadow` and root-owned files),
read-only, not escalation.

`visudo -f` created the file as `0640`; `visudo -c` flagged it ("bad permissions, should be
mode 0440") even though sudo loaded the rule. Fixed with `chmod 0440`.

## Verification (2026-10-01)

- `sudo visudo -c`: all files `parsed OK`.
- `sudo -l` lists `(root) NOPASSWD: /usr/bin/dd if\=/dev/mmcblk0 bs\=4M status\=progress`.
- `sudo -k; sudo -n dd ... count=1 of=/dev/null` (different args): refused, password required.
- `sudo -k; timeout 2 sudo -n dd if=/dev/mmcblk0 bs=4M status=progress > /dev/null`: ran with
  no prompt (12 MB copied).

A full backup run was not done on 10-01; the next cron run is 2026-11-01 02:07.
