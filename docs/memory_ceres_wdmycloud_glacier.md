---
name: project_ceres_wdmycloud_glacier
description: WDMyCloud→S3 Glacier backup on ceres — unused dirs already excluded; old snapshot still holds ~330GB but pruning isn't worth it
metadata:
  type: project
---

# ceres WDMyCloud → AWS Glacier backup (backup-greven-wdmycloud)

Repo: `s3:s3.amazonaws.com/backup-greven-wdmycloud` (restic, S3 Glacier Deep Archive),
script `~/backup_greven/scripts/backup-wdmycloud-s3.sh` on ceres, runs monthly (~1st week, see [[project_backup_schedule]]).

## Finding (2026-06-06)
User asked to remove these unused dirs from the backup to stop paying for their storage:
`/mnt/WDMyCloud/Peliculas`, `Copia disco iMac Mantchoff`, `Archivos`, `Shared Music`.

They are **already excluded** in the script (added before 2025-12-15, comment says "included by error").
Confirmed by snapshot history: `total_bytes_processed` dropped from 1.59TB (snapshot `d7c545f9`,
2025-12-08) to 1.25TB (snapshot `7c72931f`, 2025-12-15) — a ~330GB drop matching these dirs' combined size
(263+51+9.4+6.5 GB ≈ 330GB, measured via `du -sh`).

However, the **first snapshot `d7c545f9` (2025-12-08) still references that ~330GB** of old data,
so it remains stored (and billed) in Deep Archive until that snapshot is forgotten + repo pruned.

## Why no action was taken
- Extra storage cost ≈ 330GB × $0.00099/GB-month ≈ **$0.33/month (~$4/year)** — negligible.
- All objects are stored in **DEEP_ARCHIVE** storage class. `restic prune` needs to read/repack pack
  files, which would require **retrieving objects from Deep Archive** (12–48h wait + ~$0.02/GB retrieval
  fees) — likely costing *more* than the storage it would save.
- The retention policy (`--keep-monthly 6`, see `apply_retention_policy()` in the script) will
  eventually forget `d7c545f9` naturally as newer monthly snapshots accumulate, freeing the space
  with no extra action — the prune cost would be incurred then anyway, as part of normal lifecycle.

## How to apply
- Don't suggest manually pruning Glacier-backed restic repos for small space savings — retrieval
  costs from Deep Archive usually dwarf the storage savings. Let retention policy handle it.
- If asked again about this specific cleanup: it's already handled (exclusions are in place);
  no further action needed — the old snapshot will age out on its own.
