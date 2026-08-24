---
name: project_ceres_wdmycloud_glacier
description: "WDMyCloud→S3 Glacier backup on ceres — unused dirs already excluded; old snapshot still holds ~330GB but pruning isn't worth it"
metadata: 
  node_type: memory
  type: project
  originSessionId: 749662a3-4b7a-47fd-a308-7bfc7215edd6
---

Full content in [docs/memory_ceres_wdmycloud_glacier.md](../../../../../claude-ssh/docs/memory_ceres_wdmycloud_glacier.md) of the claude-ssh repo.

Short version: the 4 dirs the user wanted removed from the Glacier backup
(Peliculas, Copia disco iMac Mantchoff, Archivos, Shared Music) were already
excluded from `backup-wdmycloud-s3.sh` since ~2025-12-15. Only the original
2025-12-08 snapshot still references their ~330GB (~$0.33/month). Pruning a
Deep Archive repo to reclaim that costs more in retrieval fees than it saves —
left for the `--keep-monthly 6` retention policy to age out naturally.
