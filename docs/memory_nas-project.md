# NAS project — scope, preferences and baseline

**Status:** open
**Host:** (project)
**Supersedes:** —
**Superseded-by:** —

**Started**: 2026-08-19. **Status**: investigation only — no hardware chosen, nothing purchased.

> **Resume here** (updated 2026-09-10). **The chassis is DECIDED: TerraMaster F4-424 Pro,
> i3-N305 8-core, 32 GB, $687 (Amazon) — project total $1,121.90.** Nothing ordered yet.
>
> **The 09-08 buy list was built on a price that never existed.** The $479.99 taken for the
> F4-425 Plus N150/16 GB was the **N95/8 GB** price on a store page that sells only the N95. Real
> prices 2026-09-10: N150/16 GB **$649**, N95/8 GB **$479**. The gap is 8 GB of DDR5 at shortage
> pricing, not a lapsed sale, so waiting will not bring it back. That put the **Pro line only $38
> above** the N150 — and the user chose RAM over LAN speed: *"now all is 1 GbE. I may grow later,
> but the RAM will make a much larger difference in the long term."* The F4-424 Pro doubles cores
> and RAM for +$38, losing 5GbE (→2× 2.5GbE, unused either way on a 1 GbE LAN) and one M.2 slot
> (3→2, one is needed). It also has a **published Proxmox install guide**, which the 425 Plus never
> had. Full correction and the accepted trade-offs →
> [2026-09-10_nas-chassis-price-correction-f4-424-pro.md](2026-09-10_nas-chassis-price-correction-f4-424-pro.md).
> **At 32 GB the RAM question is closed for good** — do not re-plan the ARC/Immich allocation
> before the box exists; tune it after the restore.
>
> <details><summary>Superseded 2026-09-08 chassis decision (F4-425 Plus N150) — kept for the trail</summary>
>
> **The chassis is DECIDED and the buy list is final.**
> The user measured the space on 2026-09-08 and the 4-bay fits on a new shelf. Checking the vendor
> store to order then found that **the 16 GB belongs to the N150 SKU, not the N95** — the 09-07
> "TerraMaster support confirmed the F4 N95 has 16 GB" was wrong, the fourth spec error on this
> chassis. Both CPU variants cost the same, so:
>
> **Buy the TerraMaster F4-425 Plus, N150 variant, 16 GB, ~$456–520. Total ~$914.89.**
>
> **But terra-master.com lists only the N95 (8 GB) right now** (user, 2026-09-08). The N150/16 GB
> is a separate SKU sold on **Amazon US, ASIN `B0FLHTF2PQ`** (the N95 is `B0GW883KMF` — the model
> name is identical, check the listing title) and Newegg. **Re-check at buy time.** If it is
> genuinely unobtainable in the trip window, the fallback ladder is F4 N95 + a ~$209 SODIMM
> (~$689) before the F2 at 8 GB ($424.99, which reinstates the ARC-vs-Immich-ML compromise) —
> ladder and reasoning in the 09-08 doc § 1.
>
> This also moots the 2026-08-30 "N95 not N150" call — there is no longer a premium to weigh, and
> the N150's larger iGPU suits the Immich transcoding the software stack introduced. Full
> correction, revised RAM allocation at 16 GB, the BACKUP_A/B cable spec, the gr-srv03 hub
> reassessment and the **US acceptance-test procedure** are in
> [2026-09-08_nas-chassis-decision-and-acceptance-test.md](2026-09-08_nas-chassis-decision-and-acceptance-test.md).
>
> </details>
>
> **Open, and worth deciding before the trip:** a **third 6 TB drive as a cold spare (~$180)** —
> replacing a failed mirror half from Argentina is slow and expensive, and the F4 now has the bay.
>
> **Open:** the F4-424 Pro's **USB port count/connector types** (vendor says 2 rear, 10 Gbps, no
> front; some listings mention Type-C) — confirm on unboxing, it is where BACKUP_A/B will plug in.
>
> **Software stack designed 2026-09-07** — Proxmox VE + ZFS mirror, everything as LXCs (no VMs),
> SMB + PBS + SFTP + HTTPS, host owns the disks and bind-mounts them into the guests →
> [2026-09-07_nas-software-stack.md](2026-09-07_nas-software-stack.md). **Samba: unprivileged LXC
> with `idmap=passthrough`.** **Immich runtime: podman, no Docker.** At 16 GB the two compromises
> that doc agonised over are withdrawn: ARC gets 4 GB and Immich ML stays on — and at the 32 GB the
> F4-424 Pro actually ships with, there is no allocation to argue about at all.
>
> Everything else on the hardware side is settled: **P1** (both drives now — secondhand, so the
> mirror is complete from day one) and the **Patriot P310 480 GB** boot NVMe at $65. Nothing
> bought yet.

## Purchase list (prices verified 2026-08-20; CPU variant decided 2026-08-30 — re-check before ordering)

| Item | Source | Price |
|---|---|---|
| **TerraMaster F4-424 Pro** (**i3-N305 8-core**, **32 GB** DDR5 — at its max, no upgrade path, 2× M.2 PCIe 3.0 x1, 2× 2.5GbE, **4 bays**) | Amazon US | **$687** |
| ~~TerraMaster F4-425 Plus (N150, 16 GB, 3× M.2, 2× 5GbE, 4 bays)~~ — **superseded 2026-09-10**, actually $649 not $479.99 | Newegg | ~~$479.99~~ |
| **HGST Ultrastar 7K6000** HUS726060ALE610 6 TB SATA, cert. refurb, 3 yr | [goHardDrive g01-1079](https://www.goHardDrive.com/HGST-Ultrastar-0F23001-6TB-7200RPM-Hard-Drive-p/g01-1079.htm) | **$179.95** |
| **Seagate Exos 7E8** ST6000NM0115 6 TB SATA, enterprise, 5 yr | [goHardDrive g01-1326](https://www.goHardDrive.com/Seagate-ST6000NM0115-6TB-128MB-SATA-Enterprise-HDD-p/g01-1326.htm) | **$189.95** |
| **Patriot P310** 480 GB, M.2 2280 PCIe Gen3 x4 NVMe, 240 TB TBW — PVE boot | Amazon/Walmart/B&H | **$65** |

**Total: $1,121.90** (chassis decided 2026-09-10 — see the Resume-here block. The old $914.89 total
rested on a $479.99 price for the N150/16 GB that was never real; it lists at $649.99. **Re-check
prices before ordering** —
[2026-09-10_nas-chassis-price-correction-f4-424-pro.md](2026-09-10_nas-chassis-price-correction-f4-424-pro.md).)
Optional cold spare: a third 6 TB drive, ~$180, undecided.

### Vendor pricing and RAM, terra-master.com 2026-09-07

> **CORRECTED 2026-09-08 — the table below is wrong.** The F4-425 Plus is sold as two SKUs with
> *different* memory, and the 16 GB is the **N150**'s. Both cost the same. Current, verified on the
> vendor's own product pages 2026-09-08:
>
> | Model | CPU | Pre-installed RAM (1 slot) | Store price |
> |---|---|---|---|
> | F2-425 Plus | N95 / N150 | **8 GB** (both) | **$424.99** |
> | F4-425 Plus | N95 | **8 GB** | **$479.99** |
> | **F4-425 Plus** | **N150** | **16 GB** | **$479.99** ← buy this |
>
> Detail and sources: [2026-09-08_nas-chassis-decision-and-acceptance-test.md](2026-09-08_nas-chassis-decision-and-acceptance-test.md) § 1.

| Model | N95 | N150 | Pre-installed RAM (1 slot, all models) |
|---|---|---|---|
| F2-425 Plus | **$399** | $425 | **8 GB** |
| F4-425 Plus | **$510** | **N/A** | ~~**16 GB** (N95 confirmed by TerraMaster support)~~ — **WRONG, see above** |

> **Resolved 2026-09-08: the N150 premium is $0 on the F4, and it is the 16 GB SKU.** The CPU
> question below is therefore moot rather than overturned — there is no premium left to weigh, and
> the N150's larger iGPU happens to suit the Immich transcoding the software stack introduced.

**Note the datasheets in [`download/`](../download/) document the N150 variants only.** The N95
machines actually being bought are not covered by them; everything below that is chassis-level
(slots, ports, size, noise, power) is shared, but CPU-specific rows are not.

### Vendor specs, F2-425 Plus datasheet (2026-09-07)

| Spec | Value | Why it matters |
|---|---|---|
| Total Memory Slot Number | **1 (DDR5 SODIMM)** | upgrade **replaces** the 8 GB; 32 GB = one 32 GB stick |
| Pre-installed | 8 GB DDR5 non-ECC (1x 8 GB) | |
| M.2 2280 NVMe | 3, **PCIe 3.0 x1** | Patriot P310 (Gen3 x4) runs at x1 — fine for boot + Immich DB |
| USB3.2 host ports | **3 × Type-A + 1 × Type-C** | ample for the BACKUP_A/B rotation moving here |
| Disk slots / max raw | 2 / 60 TB (30 TB × 2) | |
| Noise | **20.0 dB(A)** (2 drives **standby**, 17.3 dB ambient, 1 m) | standby only — says nothing about 7200 rpm recert drives seeking |
| Size / net weight | 150×122×219 mm / **2.2 kg** | with 2× 3.5" drives ≈ **3.5 kg**, not the ~2.5 kg previously assumed for the trip |
| Power | 48 W PSU; 31 W read/write, 12 W hibernation | |
| Warranty | 2 years | |

**P1 decided 2026-08-30 — mirror now: $753** (enclosure + both HDDs). Both drives, ZFS mirror,
5.45 TiB usable, 57% full day one. Chosen over P2 (start small, $563, one drive + `zpool attach`
later) because the drives are secondhand — user wants mirror redundancy from day one rather than
running an unprotected single disk during the interval before the second drive is added.

**Boot NVMe decided 2026-08-30: Patriot P310 480 GB, $65.** PCIe Gen3 x4, M.2 2280 — fits the
F2-425 Plus's M.2 2280 slots (runs at the slot's PCIe 3.0 ×1, well above what boot + Immich DB/
thumbnails need). 240 TB TBW is ample for this workload (OS + a lightweight Postgres DB + thumbnail
cache — light, steady writes, not sustained heavy I/O). Not required for P1 (Proxmox could boot off
the HDD mirror instead), but keeps Immich's DB/thumbnail I/O off the secondhand HDDs.

Two *different* manufacturers is deliberate: it satisfies the different-lots rule (§7 of the
research doc) at no cost. Both carry longer warranties than any manufacturer-direct store
(Seagate direct = 6 months, WD direct = 1 year), though a US warranty is near-useless once the
drives are in Argentina — test them inside the US return window if the trip allows.

**CPU variant decided 2026-08-30: N95, not N150 (+$42) — MOOT since 2026-09-08**, both F4 SKUs
being $479.99 and only the N150 carrying 16 GB. Reasoning kept for the record. Chassis, RAM, M.2 count and LAN are
identical between the two — only the CPU/iGPU differ. N150 is ~6% faster CPU-wise and has a
faster iGPU with AV1 hardware support; N95 lacks AV1 accel and its HEVC-to-HEVC transcode is the
weakest link. None of that matters here: no transcoding use case is planned, and if one appears
later it's Full-HD only (no 4K) — N95's iGPU comfortably does ≥3 concurrent real-time 1080p
transcodes, including HEVC→H.264 and HDR10→SDR tone-mapping. **Not worth $42.**

**Rejected, with reasons** (don't re-open these): base F2-425/F4-425 (N5095, 4 GB DDR4, **no M.2**);
**F2-425 Plus N150 variant** (see above — CPU variant decided, $42 doesn't buy anything usable);
UGREEN DH2300 (**ARM** — Proxmox/TrueNAS cannot run on it); UGREEN DXP2800 (fine machine, but $369
now, not the $297 sale price — only $13 under the Plus, which has more); Seagate ST4000NM0023
(**SAS**, incompatible); WD RE4 2 TB (**2010** design, worst $/TB tier); ServerPartDeals for 6 TB
(**sold out** — its $114.99 listing is a ghost price that fools price trackers).

## Scope (what the NAS must absorb)

1. **WDMyCloud live shares** — becomes the primary copy (photos, videos, documents).
2. **backup_usb1's *backup* function only** — the physical USB disk stays on gr-srv03 and is
   repurposed as a plain local disk for databases / recordings (`data/`).
3. **Time Machine** target for a future MacBook (not yet purchased — size unknown).
4. **Proxmox Backup Server** — placement still to be decided.
5. **Friendlier photo/video browsing** than Windows Explorer.

Offsite strategy is unchanged: BACKUP_A/B rotation continues, and a *full* backup must still fit
on one 3–4 TB disk. That caps the backed-up subset, not the NAS capacity.

> **Knock-on: gr-srv03's planned second USB HDD (decided 2026-08-30).** That drive — a
> permanently-connected companion to the rotating backup disk — is **cancelled if the NAS is
> bought**, since the NAS absorbs the capacity it was for. It is therefore only purchased if this
> project does not go ahead, and **must not be ordered before the P1/P2 call is made**. The USB hub
> rebuild does not depend on the outcome either way — see
> [2026-08-19_gr-srv03_usb-hub-layout-plan.md](2026-08-19_gr-srv03_usb-hub-layout-plan.md) § The
> constraint.

> **Knock-on: BACKUP_A/B rotation moves to the NAS (decided 2026-09-07).** This is the bigger of
> the two knock-ons, because it removes a *root cause* from gr-srv03 rather than just a device.
>
> **1. It frees the port that made a USB hub mandatory.** gr-srv03 has 3 external USB-A ports, all
> occupied: Zigbee, the BACKUP_A/B rotating slot, and `backup_usb1`. The only planned addition is
> the RTL-433 SDR, and "more devices than ports" is the entire justification for the hub. Move the
> rotating drive to the NAS and it is **3 devices for 3 ports** — the **Rosonway RSH-A10, ordered
> 2026-08-29 with ETA ~2026-10-24, is no longer needed.** It arrives before the NAS does, so this
> is a plan change rather than a cancellable order; a spare powered hub is not useless, but Option
> D should not be executed on autopilot.
>
> **2. It removes the documented cause of the Zigbee drops.** The 7/7 episodes were BACKUP_A/_B
> **hot-plug transients** on the shared xHCI 5 V rail
> ([memory_gr-srv03_powered-hub-instability.md](memory_gr-srv03_powered-hub-instability.md)). The
> rotating drive is the only device that is ever hot-plugged — `backup_usb1` stays permanently
> connected. Moving it means gr-srv03 sees **no hot-plug events at all**. This is also relevant to
> the unresolved 09-05/06 LQI relapse, whose recheck is due 2026-09-09.
>
> **3. The backup architecture has to change.** ceres currently **bind-mounts** whichever drive is
> connected (`env-wdmycloud-local.sh` auto-detects A vs B). With the drives on the NAS that is
> impossible: either the restic jobs move to the NAS, or ceres writes over the network. The
> **02:25–03:30 disk-wake window** ([memory_backup_schedule.md](memory_backup_schedule.md)) moves
> to the NAS with them. `backup_usb1` stays on gr-srv03, repurposed as plain local disk.
>
> **None of this is designed yet** — it is a consequence to work through before the NAS is
> commissioned, not a solved problem.

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

**Item 1 was closed** by the 2026-08-30 buy decision (P1, $818 at the time). **Item 2 is live
again** and merged into item 5 — the chassis choice. Kept here for the reasoning.

1. ~~**The budget collision**~~ — closed 2026-08-30. Re-costed builds were **A** F2-425 + NVMe +
   2×6 TB new = $775–835; **B** same with 2×8 TB recertified = ~$615; **C** F4-425 + 2×6 TB =
   $885–945; **D** F4-425 Plus + 2×6 TB = $1013–1073. Resolved by accepting ~$818 (recert 6 TB,
   not 8 TB) rather than by reaching the original <$600 budget.
2. **8 GB vs 16 GB — this IS the live decision**, now merged into item 5 below. The original plan
   was to buy RAM pre-installed via the F4-425 Plus, since a bare 16 GB DDR5 SODIMM costs ~$209.
   **That plan is correct and available**: the F4-425 Plus **N95 ($510) ships with 16 GB**
   (TerraMaster support, 2026-09-07). An intermediate claim that it "now ships with 8 GB", taken
   from an Amazon listing earlier the same day, **was wrong — disregard it.** The all-LXC RAM
   budget is 7.5–9 GB against 8 GB and does not fit; losing Immich's face/smart search is the
   real cost of staying at 8 GB. See
   [2026-09-07_nas-software-stack.md](2026-09-07_nas-software-stack.md) § *The 16 GB question is
   OPEN*.

**Still open:**

3. ~~**SODIMM slot count**~~ — **resolved 2026-09-07: ONE slot.** A RAM upgrade **replaces** the
   bundled 8 GB, it does not join it; 32 GB means a single 32 GB module.

   Settled by the **vendor datasheets** in [`download/`](../download/) —
   `Total Memory Slot Number: 1 (DDR5 SODIMM)` on **both** the F2-425 Plus and F4-425 Plus. It is
   a chassis-level spec, so it holds for the N95 variants the datasheets do not cover.
   Independently corroborated by ITPro, who opened the unit (*"there's only one slot"*) and CNX
   Software's teardown (one module, no empty socket). The "two slots" claim on nasdrives.co.uk
   **infers it from the 32 GB maximum and is unsound** — 32 GB DDR5 SODIMMs exist as single
   modules. That is the third aggregator spec error on this chassis; **trust only the vendor
   datasheet or a teardown.**

   Also resolved here: **the N95 variant does exist** ($399), so the same-day worry that only the
   N150 was sold was wrong — only the recorded price was stale. **Noise partly answered**:
   20.0 dB(A), but measured with drives in **standby**, so the 7200 rpm recert-drive question
   stands and is now the only unverified purchase item.

4. ~~**Does the BACKUP_A/B rotation move to the NAS?**~~ — **decided 2026-09-07: yes, it moves.**
   See "Knock-on" below; this has consequences beyond the NAS.
5. ~~**2-bay vs 4-bay**~~ — **CLOSED 2026-09-08: the F4-425 Plus, N150 variant.** The user
   measured the space and the 4-bay fits on a new shelf, choosing it for the memory rather than
   the bays. The SKU then changed on inspecting the vendor store: **the 16 GB is the N150's, not
   the N95's** — the 09-07 support statement was wrong. Both F4 variants are $479.99, so 16 GB is
   free of any CPU premium.

   | Option | CPU | RAM | Bays | Total |
   |---|---|---|---|---|
   | F2-425 Plus | N95/N150 | 8 GB | 2 | $859.89 |
   | F4-425 Plus | N95 | 8 GB | 4 | $914.89 — pointless |
   | **F4-425 Plus** | **N150** | **16 GB** | **4** | **$914.89** ← ordered spec |

   Detail, sources and the revised 16 GB allocation:
   [2026-09-08_nas-chassis-decision-and-acceptance-test.md](2026-09-08_nas-chassis-decision-and-acceptance-test.md).

6. ~~**Verify the local restic repo**~~ — **done 2026-09-07, the restore source is sound.**
   BACKUP_B's `restic-wdmycloud` holds 14 snapshots (2025-12-24 → 2026-09-05) at a consistent
   1.450–1.462 TiB with no empties; the latest (`866e7c76`, 2026-09-05) is 117,635 files /
   1.462 TiB, matching the documented 1.6 TB, and `restic check` passes structurally. It is the
   **complete** copy — S3 Glacier excludes ~330 GB across four dirs, so the local repo is the
   restore source. Full detail and remaining caveats (BACKUP_A unverified, offsite) in
   [2026-09-07_nas-software-stack.md](2026-09-07_nas-software-stack.md).

7. **Disk purchase deferred — decided 2026-09-08: the drives are chosen after the NAS is bought.**
   Costs schedule, not correctness — the 2× 6 TB sizing never depended on the chassis, goHardDrive
   ships from California, and the **four SATA bays cannot be tested until a drive is in**, so part
   of the chassis's own return window depends on the drives arriving. Budget ≥1 week of US time
   after the NAS lands. A **third 6 TB as a cold spare (~$180)** is still open and is best decided
   in the same order — replacing a failed mirror half from Argentina is slow and expensive, and
   the F4 has the bay. Neither is in the ~$914.89 total.
8. **US acceptance test — planned, not executed.** Procedure, SMART pass/fail criteria and what to
   check inside the return window:
   [2026-09-08_nas-chassis-decision-and-acceptance-test.md](2026-09-08_nas-chassis-decision-and-acceptance-test.md) § 5.
9. **BACKUP_A/B cabling and the backup-job rewrite.** Cable spec is settled (§ 3 of the 09-08 doc);
   **how ceres' restic jobs reach the drive once it is on the NAS is still undesigned** — see the
   "Knock-on" note above.

## Related

[[docs/2026-09-08_nas-chassis-decision-and-acceptance-test.md]] — chassis decision, the 16 GB
allocation, BACKUP_A/B cabling, the hub reassessment and the US acceptance test.
[[docs/2026-09-07_nas-software-stack.md]] — what runs on the box: base OS, guests, sharing
protocols, disk topology, the RAM budget, and the two deferred questions.
[[docs/2026-08-20_nas-disk-prices-and-raid-options.md]] — 2/3/4/6/8 TB street prices, what to look
for in a drive, and the 1-disk vs 2-disk mirror vs 4-disk RAIDZ comparison costed for this project.
[[docs/2026-08-19_nas-hardware-research.md]] — market context, hardware/OS/PBS comparison and the
budget analysis. [[docs/memory_backup_schedule.md]] — the existing backup windows and disk-wake constraints any
new NAS-side job must respect. [[docs/memory_ceres_wdmycloud_glacier.md]] — the WDMyCloud→S3
Glacier backup and its exclusions.
