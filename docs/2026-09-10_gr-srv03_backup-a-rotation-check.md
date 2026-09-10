# gr-srv03/ceres: BACKUP_A post-rotation verification

**Status:** closed
**Host:** gr-srv03, ceres
**Supersedes:** —
**Superseded-by:** —

## Why this check

BACKUP_A was rotated back in and its first nightly run was 2026-09-09. Two things needed
confirming:

1. That the nightly `backup-usb1-local.sh` run is actually landing on the returned drive
   (mount, propagation into ceres, floors, integrity).
2. That BACKUP_A's **`restic-wdmycloud` repo** is intact. Since the WD MyCloud died
   2026-09-06 (see `2026-09-06_ceres_wdmycloud-nas-dead.md`), this repo is a second copy of
   data that **no longer has a live source**. It had been offsite and unverified — the
   memory node flagged it as "check it at the next rotation". This closes that item.

## Rotation timeline (read from `cron-backup.log`)

| Date | Disk in place |
|---|---|
| …–08-31 | BACKUP_A |
| 09-01 – ~09-06 | BACKUP_B |
| 09-08 03:00 | neither — "No backup disk mounted (12h since last seen). Within 24h grace period." (the swap) |
| 09-09 onward | BACKUP_A |

The grace-period path worked as designed: the missing-disk night exited quietly instead of
erroring.

## 1. Mount and propagation

Host: `/dev/sdc1` LABEL `BACKUP_A` at `/mnt/backup_a`, 3.6T, 1.8T used (51%). The same
device and figures were visible inside ceres — slave propagation is working, no stale bind
mount (contrast the 2026-03-18 incident in `Backup_Drives_Mounting_Configuration.md`).

Incidentally confirmed live: the 15:00 unmount cron fired **during** this check, and the
unmount propagated into ceres immediately.

## 2. `restic-repo` — nightly backup_usb1 → BACKUP_A

Run of 2026-09-10 03:00, all 7 tags fresh, all floors passed:

| Tag | Snapshot | Time | Size |
|---|---|---|---|
| homeassistant | 00ed8375 | 03:00:03 | 10.978 GiB |
| containers | b12ffdab | 03:00:37 | 30.918 GiB |
| castor-pg | beba897c | 03:01:29 | 1.748 MiB |
| proxmox-config | 12287df7 | 03:01:46 | 1.385 MiB |
| vm-images | 6bf4b9bb | 03:02:03 | 180.871 GiB |
| raspberrypi | 3c6412eb | 03:02:17 | 28.446 GiB |
| gickup | 5202204f | 03:02:34 | 1022.970 MiB |

`restic check` at 03:00: *no errors were found*. Repo total 88 snapshots / 391.757 GiB.
Prune found nothing to reclaim (0 blobs). Log closed with "Backup completed successfully -
all tags passed their floor".

**Two things that look wrong in the snapshot list but are not:**

- **09-09 shows only 6 tags, 09-10 shows 7.** `vm-images` *did* run on 09-09 (`81d2930d`,
  180.871 GiB, floor passed at 194208343879B). Its snapshot was retired by the weekly
  retention policy when 09-10's replaced it. Not a gap.
- **`immich` last seen 2025-12-17** (`f7dd3feb`, 64.867 GiB). The tag is no longer in
  `backup-usb1-local.sh` and `/mnt/backup_usb1/immich` does not exist. Retained historical
  relic, not a stalled job.

The remaining `0 B` snapshots (`containers` 2026-05-26 / 2026-08-13, `raspberrypi`
2026-06-27, `vm-images` 2026-07-31) are residue of the empty-snapshot incident, kept by
retention. They carry different path sets from the current ones.

## 3. `restic-wdmycloud` on BACKUP_A — the item this check existed to close

**Latest snapshot `905e13f3`, 2026-08-31 02:30, 1.462 TiB.** 6 snapshots retained:

| ID | Time | Size | Path |
|---|---|---|---|
| 465d8dcf | 2025-12-14 11:16 | 456.154 GiB | `/mnt/WDMyCloud/Shared Pictures` only |
| 804637d0 | 2026-08-27 02:30 | 1.462 TiB | `/mnt/WDMyCloud` |
| 6bea436a | 2026-08-28 02:30 | 1.457 TiB | `/mnt/WDMyCloud` |
| 0f78e713 | 2026-08-29 02:30 | 1.462 TiB | `/mnt/WDMyCloud` |
| 075575d6 | 2026-08-30 02:30 | 1.461 TiB | `/mnt/WDMyCloud` |
| 905e13f3 | 2026-08-31 02:30 | 1.462 TiB | `/mnt/WDMyCloud` |

**Verdict: intact and full-sized.** The 08-27→08-31 run sits in a 1.457–1.462 TiB band,
matching BACKUP_B's 1.450–1.462 TiB — nothing was shrinking in the days before the NAS died.
The 08-31 end date is exactly where the rotation table says A went offsite, so nothing is
missing.

State of the three WDMyCloud copies, none of which will ever gain a new snapshot:

| Copy | Latest | Size | Note |
|---|---|---|---|
| BACKUP_B `restic-wdmycloud` | 2026-09-05 (14 snapshots from 2025-12-24) | 1.462 TiB | **the restore source** — freshest and complete |
| BACKUP_A `restic-wdmycloud` | 2026-08-31 | 1.462 TiB | verified here; independent second copy |
| S3 `backup-greven-wdmycloud` | Glacier Deep Archive | — | excludes ~330 GB; 12–48 h + retrieval fees |

Nothing was lost by disabling the two crons on 09-06: the NAS died 09-06, so BACKUP_B's
09-05 snapshot is the freshest that can ever exist.

## 4. SMART on `/dev/sdc`

`PASSED`. Reallocated_Sector_Ct 0, Current_Pending_Sector 0, Offline_Uncorrectable 0,
UDMA_CRC_Error_Count 0, Power_On_Hours 2863, Start_Stop_Count 156, Load_Cycle_Count 1236,
35 °C.

## Correction to `Backup_Drives_Mounting_Configuration.md`

That doc says "BACKUP_A and BACKUP_B are spinning HDDs (Toshiba MQ03UBB300)". That is true
of BACKUP_B (3 TB, seen as 2.7T) but **not** of BACKUP_A, which is a **WDC WD40NDZW-11BCVS0,
4.00 TB, 4800 rpm** (WD Elements / My Passport USB). The doc's *reasoning* is unaffected:
BACKUP_A also reports `APM_level = 128`, so it spins down the same way and the
`wake-backup-disks.sh` 02:25/02:55 cron is still required for it. Corrected in place.

## Method notes

- `du -sh` on the 1.4 TiB wdmycloud repo timed out at the MCP 60 s limit. `restic snapshots`
  answers the size question without walking the tree — use it instead.
- To inspect a drive outside its mounted window: `systemctl start mnt-backup_a.mount` on
  gr-srv03 (root), query from ceres, then `systemctl stop mnt-backup_a.mount` to return it
  to the scheduled post-15:00 state. Done here; the drive remounted normally at 00:30.
- `env-wdmycloud-local.sh` auto-detects which of A/B is mounted, so the same command works
  either way — it reported `Disk: BACKUP_A` as expected.
