---
name: project_nas
description: "NAS purchase project — buy list and P1 (both drives) decided 2026-08-30; only boot-NVMe timing open, nothing ordered yet"
metadata: 
  node_type: memory
  type: project
  originSessionId: 674728fe-657f-43ee-985f-f339c95e4974
  modified: 2026-08-30T22:21:22.228Z
---

NAS to absorb the WDMyCloud live shares, backup_usb1's *backup* role, a future MacBook's Time
Machine and Proxmox Backup Server, plus Immich for family photo browsing (external-library mode,
existing folder tree intact). Hardware brought from abroad; day-one need ~3.1 TB.

**Status 2026-08-30: research complete, purchase-ready, nothing bought.** OS decided = Proxmox VE
+ ZFS mirror, PBS on the NAS with a local datastore. Buy list: **TerraMaster F2-425 Plus, N95 CPU,
$383** (N150 variant rejected — $42 more for ~6% CPU/faster iGPU/AV1 accel, none of which matters
for a Full-HD-only, no-transcoding-planned use case) + **6 TB recertified SATA enterprise** from
**goHardDrive** (Ultrastar 7K6000 $179.95 / Exos 7E8 $189.95 — two different makers on purpose).
**P1 decided** (both drives now, $753 — chosen over P2's $563 because the drives are secondhand
and the user wants mirror redundancy from day one, not a degraded single-disk interval). Remaining
open call: whether to add a ~$60 boot NVMe now or defer — not required, Proxmox can boot off the
HDD mirror instead, but keeps Immich's DB/thumbnails off drives of unknown wear.

**Do not re-open these rejections**: base F2-425/F4-425 (N5095, 4 GB DDR4, no M.2 — the 08-19
research had their specs wrong); UGREEN DH2300 (ARM, cannot run Proxmox); UGREEN DXP2800 ($369 now
— the $297 that appears in trackers was an Oct 2025 sale); any SAS drive; ServerPartDeals for 6 TB
(sold out; its $114.99 listing is a ghost price that fools $/TB trackers).

Market context: HDD, DRAM and NAND are all in shortage, so aggregator prices are stale in both
directions and **stock must be verified, not just price**. Original <USD 600 budget is only reachable
via P2.

**How to apply**: multi-step project — read the write-ups before proposing hardware or prices.
Scope, sizing arithmetic and the buy list are in [[docs/memory_nas-project.md]] (claude-ssh repo);
market/hardware/OS research in [[docs/2026-08-19_nas-hardware-research.md]]; disk prices, drive
selection criteria, RAID layout comparison, enclosure alternatives and recert sourcing in
[[docs/2026-08-20_nas-disk-prices-and-raid-options.md]]. Related: [[project_backup_schedule]],
[[project_ceres_wdmycloud_glacier]].
