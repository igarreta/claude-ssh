# ceres/gr-srv03: WDMyCloud NAS dead — configs wiped, backups preserved

**Status:** open
**Host:** gr-srv03, ceres
**Supersedes:** —
**Superseded-by:** —

## What happened

Yesterday's system-wide upgrade rebooted gr-srv03 (2026-09-05 17:28). ceres (CT203) came
back up fine with its `mp3` mount (`/mnt/WDMyCloud`, a CIFS share from a WD MyCloud NAS at
`192.168.1.54`) intact. Sometime before ceres's next scheduled daily restart (02:20 on
2026-09-06), the WD MyCloud NAS itself went unreachable (`ping`: Destination Host
Unreachable). That restart then failed: the LXC pre-start hook couldn't find
`/mnt/WDMyCloud` (autofs mount failing since the CIFS host is down), so ceres stayed
stopped until this was diagnosed.

**Confirmed by the user: the WD MyCloud is dead and not recoverable.** A replacement is
planned but may take **more than 2 months** to arrive.

## Immediate danger found and neutralized

ceres runs two restic backup jobs that read from `/mnt/WDMyCloud`:
- `backup-wdmycloud-local.sh` — daily 02:30 → local repo on BACKUP_A/B, `restic forget
  --keep-daily 7 --keep-weekly 4 --keep-monthly 12 --keep-yearly 2 --prune`
- `backup-wdmycloud-s3.sh` — monthly (4th) 03:30 → `s3:backup-greven-wdmycloud` (Glacier
  Deep Archive), `restic forget --keep-monthly 6 --prune` (see [[project_ceres_wdmycloud_glacier]])

Once `mp3` was removed from ceres's LXC config (to let it start), `/mnt/WDMyCloud` became
an **empty but readable directory** inside ceres — not missing, not a failed mountpoint.
Neither script's prerequisite check catches this (the S3 script only checks readability;
the local script has no check at all). Left alone, tonight's local cron would have backed
up 0 files, restic would report success, and `forget --prune` would run — starting to
rotate real historical snapshots out in favor of the new empty one. Over the >2-month
replacement window this would have progressively destroyed the only remaining copies of
the WDMyCloud data.

**Fix applied:** both cron lines commented out in ceres's crontab (2026-09-06), with a
comment explaining why and pointing back here. Verified the local repo's latest snapshot
(`549fe821`, 2026-09-03, 1.457 TiB) is intact and was not touched.

## Configs wiped (source is gone, no point keeping them live)

- gr-srv03 `/etc/fstab`: removed the WDMyCloud CIFS mount entry (lines 15-16,
  `//192.168.1.54/Public /mnt/WDMyCloud cifs ...`).
- gr-srv03 `pct config 203`: removed `mp3` (the WDMyCloud bind mount) — this is what let
  ceres start again.
- `/opt/proxmox-grsrv03/monitoring/disk-space-monitor.sh`: removed the WDMyCloud
  95%-threshold special case (dead mount, nothing to monitor).
- `/opt/proxmox-grsrv03/lxc-provisioning/provision-lxc.sh`: removed the `--wdmycloud` /
  `--wdmycloud-rw` provisioning options (nothing left to mount).

## Explicitly NOT touched (data preservation)

- ceres local restic repo (`/mnt/backup_b/restic-wdmycloud`, currently on BACKUP_B).
- S3 Glacier repo (`backup-greven-wdmycloud`).
- The backup scripts themselves (`backup-wdmycloud-local.sh`, `backup-wdmycloud-s3.sh`,
  `env-wdmycloud-*.sh`, `status-wdmycloud.sh`) — left in place, just not scheduled, so
  they're ready to re-enable once a replacement NAS exists and is backfilled.

## How to apply

- Do not re-enable the two cron lines in ceres's crontab until a replacement NAS is
  mounted at `/mnt/WDMyCloud` (or the scripts are repointed) — re-check readability isn't
  enough, confirm `mountpoint -q /mnt/WDMyCloud` and non-empty content before trusting it.
- When the replacement NAS is in place: remount, uncomment both cron lines, run
  `backup-wdmycloud-local.sh` once manually first to confirm real files are seen before
  letting `--prune` run automatically again.
- General lesson: a restic backup script pointed at a mount should verify
  `mountpoint -q` (or non-empty content) before backing up, not just readability —
  an unmounted-but-present empty directory is a silent way to poison retention.

## Checking a repo's snapshot history (e.g. verifying BACKUP_A once it's swapped in)

Both BACKUP_A and BACKUP_B have their own independent `wdmycloud-local` repo (they are
two separate physical drives, not mirrors — see [[project_ceres_wdmycloud-nas-dead]]).
To check whichever one is currently connected to ceres:

```
source ~/backup_greven/scripts/env-wdmycloud-local.sh
restic snapshots --tag wdmycloud-local --compact
```

`env-wdmycloud-local.sh` auto-detects which disk is mounted and points `RESTIC_REPOSITORY`
at it — no need to know in advance whether it's A or B.

**Expected result:** a list of snapshots, most-recent first(ish), each ~1.45-1.46 TiB, tagged
`wdmycloud-local automatic`, roughly one every few days to weeks (real-world example from
BACKUP_B on 2026-09-06: 14 snapshots from 2025-12-24 through 2026-09-05, sizes 1.450-1.462
TiB — consistent size confirms no partial/empty backups). A password prompt or repo-not-found
error means either the wrong drive is mounted or something is wrong with that disk's repo.
An empty list, or a snapshot much smaller than ~1.4 TiB, is a red flag — investigate before
trusting that drive.
