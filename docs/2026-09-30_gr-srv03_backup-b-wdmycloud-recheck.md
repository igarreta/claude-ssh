# gr-srv03/ceres: BACKUP_B WDMyCloud repo re-check

**Status:** closed
**Host:** gr-srv03, ceres
**Supersedes:** —
**Superseded-by:** —

## Why this check

The WD MyCloud NAS died 2026-09-06 (see
[2026-09-06_ceres_wdmycloud-nas-dead.md](2026-09-06_ceres_wdmycloud-nas-dead.md)).
`restic-wdmycloud` on BACKUP_A/B holds the only complete copy of its data. This check confirms
that no snapshot has been deleted or corrupted since BACKUP_B was last verified on 2026-09-07.

## Result: healthy, nothing erased

| Check | Result |
|---|---|
| Drive connected | BACKUP_B (`/dev/sdc1`, plugged in 09-29); BACKUP_A offsite |
| ceres crons | both `backup-wdmycloud-local.sh` and `backup-wdmycloud-s3.sh` still commented out |
| `restic snapshots` | 14 snapshots, 2025-12-24 → 2026-09-05, **identical list to 09-07** |
| Snapshot sizes | 1.450–1.462 TiB, no empties |
| Latest `866e7c76` (09-05) | 117,635 files / 1.462 TiB, unchanged |
| Repo files changed after 09-06 | none (only the `locks` dir mtime moved, from the 09-07 `restic check`) |
| `restic check` | `no errors were found` (14/14 snapshots) |

BACKUP_A wasn't checked here. It is offsite and was last verified 2026-09-10
([2026-09-10_gr-srv03_backup-a-rotation-check.md](2026-09-10_gr-srv03_backup-a-rotation-check.md)).

## How it was done (outside the mount window)

The check ran at 16:37, after the 15:00 unmount. `systemctl start mnt-backup_b.mount` on
gr-srv03 did **not** make the drive visible in ceres. ceres had no `/mnt/backup_b` mount at all,
because the 15:00 unmount propagates into ceres and removes the slave bind. The bind comes back
only when `check-ceres-mount-sync.sh` reboots ceres at 02:20. This is expected behaviour; the
workaround in
[2026-09-10_gr-srv03_backup-a-rotation-check.md](2026-09-10_gr-srv03_backup-a-rotation-check.md)
(start the mount, query from ceres) only works while ceres's bind still exists.

Instead of rebooting ceres, restic ran on gr-srv03 directly. It read the repo password from ceres
without ever printing it:

```bash
systemctl start mnt-backup_b.mount
restic -r /mnt/backup_b/restic-wdmycloud \
  --password-command 'pct exec 203 -- cat /home/rsi/etc/restic-password-local' \
  snapshots --no-lock          # likewise: stats latest, check
systemctl stop mnt-backup_b.mount   # restore scheduled state
```

`restic check` took about 15 s and was run in the background to stay clear of the MCP timeout.
