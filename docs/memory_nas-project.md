# NAS project — scope, preferences and baseline

**Started**: 2026-08-19. **Status**: investigation only — no hardware chosen, nothing purchased.

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
| Placement | **Prefers NOT next to gr-srv03** (physical separation), but is short of options — small footprint is required, and co-locating with gr-srv03 is an acceptable compromise. Ethernet available wherever it lands. |

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
| Time Machine for one MacBook | 0.5–1.0 TB |
| **Total** | **2.5–3.1 TB** |

→ A 2×4 TB mirror is ~75% full on day one, so **2×6 TB is the realistic floor** for a 2-bay
mirror. This is the tension to resolve: the budget and the "8 TB is too large" preference pull
down, the 2.5–3.1 TB day-one figure plus photo/video growth pull up.

## Open decisions

1. **Bay count and disk size** — explore options between 2×6 TB mirror and 4-bay layouts;
   user rejected 2×8 TB and 4×4 TB RAIDZ1 as oversized.
2. **Turnkey appliance vs DIY** — needs a concrete price/availability comparison for goods
   carried from abroad.
3. **NAS OS** — constrained by decision 4 (running VMs) and by Immich support.
4. **PBS placement** — on the NAS (needs a VM-capable OS: TrueNAS SCALE / Proxmox / Unraid)
   vs an LXC on gr-srv03 with its datastore on the NAS over NFS/iSCSI.
5. **What must fit in the 3 TB offsite disk** — is Peliculas in? Time Machine? PBS datastore?
6. **Time Machine quota** — depends on the future MacBook's disk size.
7. **Does the BACKUP_A/B rotation move from gr-srv03 to the NAS**, or stay where it is?

## Related

[[docs/memory_backup_schedule.md]] — the existing backup windows and disk-wake constraints any
new NAS-side job must respect. [[docs/memory_ceres_wdmycloud_glacier.md]] — the WDMyCloud→S3
Glacier backup and its exclusions.
