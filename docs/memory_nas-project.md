# NAS project — scope, preferences and baseline

**Started**: 2026-08-19. **Status**: investigation only — no hardware chosen, nothing purchased.

> **Resume here** (2026-08-20): recommended buy is **TerraMaster F2-425 Plus ($382 Amazon) + 6 TB
> recertified SATA enterprise drives** — two now (P1, $722) or one now with `zpool attach` of the
> twin later (P2, $552). The base F2-425/F4-425 are **N5095 + 4 GB DDR4 + no M.2** (the 08-19 doc
> was wrong) and their needed RAM upgrade costs more than the step up to the Plus. Two Amazon drive
> candidates were rejected: ST4000NM0023 is **SAS** (incompatible), WD RE4 2 TB is a **2010**
> design in the worst $/TB tier. See [[docs/2026-08-20_nas-disk-prices-and-raid-options.md]] §8.
> Still open: P1 vs P2, and docker03's replacement LXC on gr-srv03 is decided but not yet built.

## Scope (what the NAS must absorb)

1. **WDMyCloud live shares** — becomes the primary copy (photos, videos, documents).
2. **backup_usb1's *backup* function only** — the physical USB disk stays on gr-srv03 and is
   repurposed as a plain local disk for databases / recordings (`data/`).
3. **Time Machine** target for a future MacBook (not yet purchased — size unknown).
4. **Proxmox Backup Server** — placement still to be decided.
5. **Friendlier photo/video browsing** than Windows Explorer.

Offsite strategy is unchanged: BACKUP_A/B rotation continues, and a *full* backup must still fit
on one 3–4 TB disk. That caps the backed-up subset, not the NAS capacity.

## Confirmed preferences (2026-08-19)

| Decision | User's answer |
|---|---|
| Where to buy | **Brought from abroad** (US/EU) — not Argentine local retail. Weight/customs matter. |
| Turnkey vs DIY | **Undecided — compare both** with concrete models and prices. |
| Budget | **Below USD 600** total (enclosure + disks). HDD is good enough; NVMe cache is a nice addition, not a requirement. |
| Capacity | **2×8 TB is too large. 12 TB usable (4×4 TB RAIDZ1) is too much.** Wants alternatives explored between those points. |
| Media browsing | **Immich** (Google-Photos-like: timeline, faces, search, phone apps). Existing folder tree must stay intact → external-library mode. |
| PBS placement | Recommend one at the next step (on-NAS VM vs LXC on gr-srv03 with datastore on NAS). |
| Placement | **Prefers NOT next to gr-srv03** (physical separation), but is short of options — small footprint is required, and co-locating with gr-srv03 is an acceptable compromise. Ethernet available wherever it lands. Footprint is "to be considered but not a hard limit". |
| Peliculas (263 GB) | **May move to the NAS, but stays excluded from backups**, as today. |
| Time Machine | MacBook will have **1 TB**, not expected to fill for a long time. |
| Offsite scope | **PBS and Time Machine must both be backed up remotely.** BACKUP_A/B may be increased to **4 TB** (the size of the larger disk). |

## Baseline measurements (2026-08-19)

**WDMyCloud** (`//192.168.1.54/Public`) — 1.8 TB total, **1.6 TB used (88% full)**:

| Directory | Size |
|---|---|
| Shared Videos | 708 GB |
| Shared Pictures | 518 GB |
| Peliculas | 263 GB *(excluded from the S3 backup on purpose)* |
| Outlook | 65 GB |
| Copia disco iMac Mantchoff | 51 GB |
| Archivos / Shared Music / rest | ~20 GB |

**backup_usb1** (`/dev/sdb1` on gr-srv03) — 931 GB total, **273 GB used**:

| Directory | Size | Role |
|---|---|---|
| vm-containers | 171 GB | vzdump — would be replaced by a PBS datastore (better dedup) |
| homeassistant | 34 GB | host backup |
| raspberrypi1 | 30 GB | host backup |
| contabo2 | 26 GB | host backup |
| docker03 | 9.1 GB | host backup |
| raspberrypi2z / gickup / data | ~5.7 GB | backups + `data` (1.7 GB) is the only live, non-backup content |

**BACKUP_B**: 2.7 TiB (3 TB nominal), ext4, rotated offsite with BACKUP_A.

## Sizing arithmetic (day one)

| Item | Estimate |
|---|---|
| Live shares from WDMyCloud | 1.6 TB |
| Backups absorbed from backup_usb1 (+ more PBS history than today) | 0.3–0.5 TB |
| Time Machine (1 TB MacBook, plan a 1 TB quota) | 1.0 TB |
| **NAS total, day one** | **~3.1 TB** |
| **Offsite subset** (all of the above except Peliculas) | **~2.75 TB** |

→ A 2×4 TB mirror (3.6 TiB usable) is **86% full on day one — not viable**. 2×6 TB (5.45 TiB
usable, 57% day one) is the realistic floor. The offsite copy at ~2.75 TB on a 4 TB disk
(3.6 TiB usable) is ~76% full, and is the constraint that will bind first.

## Open decisions

**Decided 2026-08-19**: gr-srv03 **cannot** host the NAS role with only new drives — its 12 GB
LPDDR5 is soldered (already 9.1/11.7 GB used with 6.5 GB swapped), its single M.2 2242 SATA slot
is occupied so any drives would be USB on the bus with the documented Zigbee-drop history, and
PBS there would back the host up to itself. **docker03 will be replaced by an LXC on gr-srv03**
(not by the NAS), returning ~4.5 GB of allocation and keeping the Zigbee dongle where it is. The
NAS spec is unchanged by that decision.

**Decided by the 2026-08-19 research** (see [[docs/2026-08-19_nas-hardware-research.md]]):
DIY loses at 2 bays (turnkey is cheaper, smaller, lighter); recommended OS is **Proxmox VE +
ZFS mirror**; recommended **PBS placement is on the NAS with a local datastore** (NFS-backed
PBS datastores are discouraged, and it puts the backup server on different hardware from
gr-srv03, which it protects).

**Still open:**

1. **The budget collision** — HDD, DRAM *and* NAND are all in shortage. Re-costed builds:
   **A** F2-425 + NVMe + 2×6 TB new = **$775–835**; **B** same with 2×8 TB recertified enterprise
   = **~$615**; **C** F4-425 + 2×6 TB = $885–945; **D** F4-425 Plus (16 GB built in) + 2×6 TB =
   $1013–1073. **Only build B approaches <USD 600**, and only if recert 8 TB drives are ~$150.
   **This is the blocking decision.**
2. **2-bay vs 4-bay, and 8 GB vs 16 GB** — a 16 GB DDR5 SODIMM costs ~$209 on its own, so RAM
   must either be lived with at 8 GB (ARC capped at 2 GB, Immich ML at concurrency 1) or bought
   pre-installed via the F4-425 Plus. Losing Immich's face/smart search is the real cost of 8 GB.
3. **Verification items before purchase** — recertified enterprise 8 TB street price,
   third-party OS support/BIOS/HDMI on the chosen chassis, M.2 slot count, noise figures.
4. **Does the BACKUP_A/B rotation move from gr-srv03 to the NAS**, or stay where it is?

## Related

[[docs/2026-08-20_nas-disk-prices-and-raid-options.md]] — 2/3/4/6/8 TB street prices, what to look
for in a drive, and the 1-disk vs 2-disk mirror vs 4-disk RAIDZ comparison costed for this project.
[[docs/2026-08-19_nas-hardware-research.md]] — market context, hardware/OS/PBS comparison and the
budget analysis. [[docs/memory_backup_schedule.md]] — the existing backup windows and disk-wake constraints any
new NAS-side job must respect. [[docs/memory_ceres_wdmycloud_glacier.md]] — the WDMyCloud→S3
Glacier backup and its exclusions.
