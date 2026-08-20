# NAS project — small-capacity disk prices and RAID layout comparison

**Date**: 2026-08-20. Continues [[docs/2026-08-19_nas-hardware-research.md]].
Prices are **US street, USD, August 2026**, for import (see [[docs/memory_nas-project.md]]).

## 1. Health warning on the price data

Aggregators disagree by ~2× at the same capacity. Live retail scrapes (Best Buy / B&H, refreshed
within the hour) show 4 TB IronWolf at **$201** and 6 TB Exos at **$281**, while cached Newegg
listings still show 2 TB Red Plus at $80 and 6 TB Red Plus at $130. The cached numbers are almost
certainly stale — they contradict the documented +46% (and in places +100%) HDD move of 2026.
**Treat the low end of every range below as "only if you catch it", and re-verify on purchase day.**

## 2. Price by capacity (3.5" SATA, CMR)

| Capacity | New NAS-class (street) | $/TB new | Recertified / renewed enterprise | $/TB recert |
|---|---|---|---|---|
| **2 TB** | $80–120 | **$40–60** | ~$94 (Seagate Enterprise Capacity) | $47 |
| **3 TB** | $100–140, poorly stocked | **$33–47** | rare, not worth chasing | — |
| **4 TB** | $170–200 (IronWolf $201) | **$43–50** | $130 (Ultrastar 7K6000, Exos 7E8 $137–150) | **$33–38** |
| **6 TB** | $230–290 (Exos $281, Purple $320) | **$38–48** | $160–180 (MDD), $180 (Exos 7E8) | **$27–30** |
| **8 TB** | $330–430 | $41–54 | $235 (Seagate Enterprise Capacity) | **$29–32** |
| *(reference)* 12–20 TB | $350–600 | **$28–35** | — | — |

Two facts fall out of this table:

1. **2 TB and 4 TB are the worst $/TB on the market right now** — worse than 20 TB enterprise
   drives. Small capacity is not a way to save money in 2026, only a way to spend less in absolute
   terms.
2. **Recertified is where the 6/8 TB band becomes affordable** — 6 TB recert at ~$28/TB is roughly
   *half* the price of the same capacity new. This is the same lever build B leans on.

## 3. What to look for in a drive

**Non-negotiable**
- **CMR, never SMR.** SMR drives collapse during RAID rebuilds. WD hid SMR inside plain "WD Red"
  (WD20EFAX/WD40EFAX); **"Red Plus" / "Red Pro" are CMR**. Check the exact model number, not the family.
- **SATA, not SAS.** Several of the cheapest per-TB listings found are SAS 12G datacenter pulls —
  they will not work in a TerraMaster/UGREEN chassis without an HBA.
- **NAS or enterprise firmware with TLER/ERC** (WD: TLER, Seagate: ERC). A desktop drive retries a
  bad sector for up to two minutes and the controller drops it out of the array. NAS drives give up
  in ~7 s and let ZFS handle it.
- **Workload rating**: 180 TB/year for NAS drives (Red Plus, IronWolf, N300) vs 55 TB/year for
  desktop drives. Matters for a device that also hosts backups and scrubs monthly.

**Choose deliberately**
- **RPM**: 5400-class (Red Plus, IronWolf non-Pro) is quiet and cool; 7200 (Exos, Ultrastar, all
  recertified enterprise) is measurably louder and warmer. Given the NAS may sit in living space,
  this is a real cost of the recertified route.
- **Warranty**: 3 yr consumer NAS, 5 yr Pro/enterprise, **2 yr seller warranty** on recertified —
  and a seller warranty from a US reseller is close to worthless once the drive is in Argentina.
- **Rotational vibration (RV) sensors** — only relevant from ~4 bays up; irrelevant in a 2-bay.
- **Power/idle draw**: ~4–5 W idle for 5400-class, ~7–9 W for enterprise 7200. Two of each, 24/7,
  is a few dollars a year — but also heat in a small sealed chassis.
- **Helium (He) drives** run cooler and quieter but are only found at 8 TB+.

**Recertified-specific**
- Ask for / check **SMART power-on hours** on arrival; datacenter pulls with 40 000+ h are common.
- **Buy the two drives from different lots** if possible — same-batch drives fail at similar times,
  which is exactly the correlated failure a mirror does not protect against.
- Budget a **full badblocks/long SMART burn-in** before trusting either drive with the only copy.

**Import-specific**
- ~650–700 g per 3.5" drive; four drives is ~2.7 kg of the luggage allowance.
- Transport them **out of the NAS**, padded, in anti-static bags — never installed in the chassis.

## 4. RAID / vdev layouts: 1 disk vs 2 disks vs 4 disks

Read as ZFS on Proxmox (the OS decided on 2026-08-19). Usable figures are TiB after ZFS overhead;
drive cost uses the mid-range **new** prices above ($100 / 2 TB, $130 / 3 TB, $190 / 4 TB,
$270 / 6 TB). Chassis: F2-425 $255 (2-bay), F4-425 $365 (4-bay). Day-one need is **~3.1 TB**.

| Layout | Raw | Usable | Survives | Drives | + chassis | Total | Day-one full |
|---|---|---|---|---|---|---|---|
| 1×6 TB, single (no redundancy) | 6 TB | 5.45 TiB | nothing | $270 | $255 | **$525** | 57% |
| 2×4 TB mirror | 8 TB | 3.64 TiB | 1 drive | $380 | $255 | $635 | **86% — not viable** |
| **2×6 TB mirror** | 12 TB | 5.45 TiB | 1 drive | $540 | $255 | **$795** | 57% |
| 4×2 TB RAIDZ1 | 8 TB | 5.45 TiB | 1 drive | $400 | $365 | $765 | 57% |
| 4×3 TB RAIDZ1 | 12 TB | 8.2 TiB | 1 drive | $520 | $365 | $885 | 38% |
| 4×4 TB RAIDZ1 | 16 TB | 10.9 TiB | 1 drive | $760 | $365 | $1125 | 28% |
| 4×2 TB RAIDZ2 | 8 TB | 3.64 TiB | any 2 | $400 | $365 | $765 | 86% — not viable |
| 4×4 TB RAIDZ2 | 16 TB | 7.27 TiB | any 2 | $760 | $365 | $1125 | 43% |

### What actually separates them

**1 disk — no redundancy.** Cheapest by $270 and the only layout comfortably inside the old <$600
budget. A drive failure means the NAS is *down* until a replacement arrives from abroad, and
everything must be restored from BACKUP_A/B and Glacier — days to weeks, and the Glacier retrieval
has a real cost. ZFS on a single disk still checksums and scrubs, so it will *tell* you data has
rotted; it cannot repair it (unless `copies=2`, which halves capacity — at which point buy a mirror).
Defensible only because the backup chain already exists; not defensible for Time Machine, which
would be the only copy of the MacBook.

**2 disks — mirror.** Survives one failure with zero downtime, rebuilds ("resilvers") only the
*used* blocks, so a half-full 6 TB mirror resilvers in hours, not days. Read throughput is doubled;
write throughput is one drive's. Expansion is by adding a second mirror pair — impossible in a
2-bay, so this layout is terminal at 5.45 TiB until both drives are replaced with larger ones.

**4 disks — RAIDZ1 (RAID 5 equivalent).** Better capacity efficiency (75% vs 50%): 4×3 TB delivers
8.2 TiB for **$90 less** than the 2×6 TB mirror delivers 5.45 TiB. But: single parity across four
drives means the rebuild reads *every* sector of the three survivors, and a second failure or a
single unrecoverable read error during that window loses the pool. With 2–4 TB members the rebuild
is short enough that this is an acceptable risk (it is 8 TB+ members where RAIDZ1 gets frowned upon).
Four spinning drives also mean roughly double the noise, heat and idle power of two.

**4 disks — RAIDZ2 (RAID 6 equivalent).** Survives any two failures — the right answer for eight
drives, overkill and capacity-wasteful for four (same 50% efficiency as a mirror, but slower and
noisier). Skip.

### The non-obvious result

**4×2 TB RAIDZ1 costs the same as 2×6 TB mirror ($765 vs $795), yields the same 5.45 TiB, and is
worse in every other dimension**: four failure points instead of two, more noise and power, a
2-bay's worth of capacity in a full 4-bay chassis with no room to grow, and the 2 TB drives are the
worst $/TB on the market. Small drives in a bigger array is not a route around the shortage.

The 4-bay only earns its extra $110 if bought with **3 TB or 4 TB members**, or bought with two
drives now and filled later — and "filled later" is now genuinely possible: **OpenZFS 2.3 RAIDZ
expansion** (present in Proxmox VE 9) allows adding a disk to an existing RAIDZ vdev, which was the
historical argument against ever starting a RAIDZ small.

### Ranking against this project

1. **2×6 TB mirror ($795)** — still the right answer if the budget can stretch. Quiet, simple,
   fast resilver, correct capacity.
2. **4×3 TB RAIDZ1 ($885)** — $90 more for 8.2 TiB and a real growth path via RAIDZ expansion.
   Costs noise and 4 bays of power.
3. **1×6 TB single ($525)** — the only sub-$600 option using *new* drives. Trades redundancy for
   price; only if the restore-from-offsite path is genuinely accepted, and Time Machine gets a
   second copy elsewhere.
4. **2×8 TB recertified (build B, ~$615)** — unchanged from yesterday: best capacity per dollar
   *with* redundancy, at the price of 7200 rpm noise and a US-only 2-year warranty.

## 5. Footnote: RAID 2 and RAID 4 as literal levels

Since the levels themselves were named: **RAID 2** stripes at the *bit* level with Hamming-code ECC
on dedicated drives — it required spindle-synchronised disks, was obsoleted by drives doing their
own ECC, and has not shipped in any product for decades. **RAID 4** is RAID 5 with all parity on a
single dedicated drive, which makes that drive the write bottleneck for the whole array; NetApp
used it (WAFL) but no home NAS offers it. Neither is available in ZFS, mdadm-for-NAS, Synology SHR,
TerraMaster or UGREEN. If either turns up as an option in a product menu, it is the wrong choice.

## 6. Enclosure prices recalled (unchanged, 2026-08-19 research)

| Model | Bays | RAM | M.2 | Price |
|---|---|---|---|---|
| TerraMaster F2-425 | 2 | 8 GB DDR5 SODIMM | verify | **$255** |
| UGREEN NASync DXP2800 | 2 | 8 GB DDR5 | 2× | **$297** (Walmart) / $370 official |
| TerraMaster F4-425 | 4 | 8 GB DDR5 | verify | **$365** |
| TerraMaster F4-425 Plus | 4 | **16 GB DDR5** | 3× | **$493** (15% off) |

2-bay → 4-bay is a **$110** step (F2-425 → F4-425). The F4-425 Plus at $493 remains cheaper than
F4-425 + a $209 16 GB SODIMM.

## 7. Must the array's drives match?

**Same size — effectively yes. Same model — no, and deliberately not.**

### Size

- In a ZFS mirror or RAIDZ vdev, **usable capacity = smallest member** (times the layout's
  efficiency). A 4 TB + 6 TB mirror yields 3.64 TiB and silently wastes 2 TB. ZFS permits it; it
  just doesn't pay.
- The real trap is at **replacement time**: "4 TB" is not an exact LBA count, and vendors differ by
  a few MB. If the replacement is marginally *smaller* than the drive it replaces, `zpool replace`
  refuses. Modern ZFS reserves a small slack margin, but the safe rule is **replace with the same
  model or a larger drive** — and keep a note of the exact model bought.
- Growing later: both mirror members must be replaced with the larger drive before capacity
  appears, and `zpool set autoexpand=on` must be set (or `zpool online -e` run afterwards).
- Synology **SHR** and TerraMaster **TRAID** exist precisely to make mismatched sizes useful. The
  decision to run Proxmox + ZFS (2026-08-19) gives that lever up — a deliberate trade for ZFS
  checksums, snapshots and send/recv.

### Model and brand

- Not required. Any CMR SATA drive of the same capacity pairs fine — a WD Red Plus mirrored with a
  Seagate IronWolf is a perfectly valid vdev.
- **Mixing is mildly preferable.** Drives from one production lot share wear characteristics and
  tend to fail near each other — precisely the correlated failure a mirror does not protect
  against. Different lots, or different vendors, decorrelates it. This matters most for
  **recertified enterprise drives**, which frequently arrive as consecutive pulls from the same
  rack with near-identical power-on hours.

### What must match

- **CMR throughout.** Never mix an SMR drive into an array — resilvers crawl or fail outright.
- **RPM class**, in practice. A 5400 + 7200 mirror writes at the slower drive's pace *and* carries
  the 7200's noise and heat: both costs, neither benefit.
- **ashift=12** at pool creation. It is a property of the pool, not of the disks, cannot be changed
  afterwards, and is the default for any modern drive.

### For this build

Two drives of the **same nominal capacity and RPM class**, from **different lots or different
brands**. If the recertified route (build B) is taken, ask the reseller for drives from different
batches and check SMART power-on hours on both before building the pool.

## 8. Evaluating the actual Amazon candidates (2026-08-20)

### 8.1 Correction: the F2-425 / F4-425 specs in the 2026-08-19 research were wrong

That doc listed the F2-425 and F4-425 as **Intel N150 with 8 GB DDR5**. They are not. Verified
against TerraMaster's store, the F4-425 datasheet and reviews:

| Model | CPU | RAM (stock) | RAM max | M.2 NVMe | LAN | Amazon price |
|---|---|---|---|---|---|---|
| **F2-425** | Intel **N5095** (Jasper Lake, 2021) | **4 GB DDR4**, 1 SODIMM | 16 GB | **none** | 1× 2.5GbE | **$254** |
| **F4-425** | Intel **N5095** | **4 GB DDR4**, 1 SODIMM | 16 GB | **none** | 1× 2.5GbE | **$365** |
| **F2-425 Plus** | Intel **N150** (Alder Lake-N) | **8 GB DDR5** | **32 GB** | **3× M.2 2280** (PCIe 3.0 ×1) | **2× 5GbE** | **$382** |
| F4-425 Plus | Intel N150 | 16 GB DDR5 | 32 GB | 3× M.2 | 2× 5GbE | $493 |

Only the **Plus** models are the N150/DDR5/NVMe machines. Two consequences for this project:

- **The NVMe line item in builds A–D of the 2026-08-19 doc was unbuildable** — the base F2-425 and
  F4-425 have nowhere to put it. On those, Proxmox root would have to live on the HDD mirror
  itself (workable, but Immich's PostgreSQL and thumbnail cache then sit on spinning rust).
- **4 GB is not enough** for Proxmox + ZFS ARC + Immich with machine learning. It would have to be
  upgraded, and a **16 GB DDR4 SODIMM now costs $150–219** (median $219, Aug 2026 — DRAM is in the
  same shortage as everything else).

### 8.2 The decisive arithmetic

> **F2-425 ($254) + a 16 GB DDR4 stick ($150–219) = $404–473 — more than the F2-425 Plus at $382,
> for a worse machine.**

The Plus wins on every axis at a lower total: newer CPU, DDR5 expandable to 32 GB, dual 5GbE,
HDMI 2.0 4K60 (which also confirms a third-party OS install is practical), and three M.2 slots that
solve the Proxmox-boot problem — PVE on a small NVMe, both HDD bays free for the mirror. **The base
F2-425 is only the right buy if 4 GB is genuinely lived with, i.e. Immich without ML (no face
recognition, no smart search).**

### 8.3 The two drives: one is incompatible, one is too old

**Seagate ST4000NM0023, $96 — reject, it is a SAS drive.** The Amazon title says so: *"6Gbps SAS"*.
This is exactly the trap flagged in §3 — the cheapest per-TB listings are SAS datacenter pulls.
It will not connect to a TerraMaster (or any consumer NAS) without an HBA, and these chassis have
no slot for one. It is also a Constellation ES.3, a 2012–2013 design.

**WD RE4 WD2003FYYS 2 TB, $63 — reject on age and capacity tier.**
- **Released February 2010** — a *sixteen-year-old* design. "Renewed" refers to the testing, not to
  the age of the platters, bearings and spindle motor.
- **SATA 3.0 Gb/s (SATA II)** — the interface generation before the one every other drive uses.
- 7200 rpm enterprise mechanics: roughly double the idle power and clearly more audible than a
  5400-class NAS drive, in a box that may sit in living space.
- $63 / 2 TB = **$31.50/TB**, in the capacity tier that §2 identifies as the worst value on the
  market. Four of them (RAIDZ1, 5.45 TiB, $252) is the "small drives in a bigger array" trap of §4,
  made worse by putting sixteen-year-old mechanics under it.

**The instinct is right, the drives are wrong.** Recertified enterprise *is* the sensible lever
here — but from the 2015–2018 generation and in **SATA**, at 6 TB where $/TB is best (§2):
HGST Ultrastar 7K6000 4 TB ~$130, Exos 7E8 4 TB $137–150, **Exos 7E8 / MDD 6 TB $160–180**.

Also worth stating plainly: **no RAID is "error proof."** Redundancy covers *drive* failure. It
does not cover deletion, corruption propagated by the filesystem, ransomware, PSU or controller
failure, or theft — which is what BACKUP_A/B and Glacier are for. With older recertified drives the
right response is not a fancier RAID level but ZFS checksums, monthly scrubs, SMART monitoring, and
the offsite copy that already exists.

### 8.4 Revised builds, with "start small and upgrade in a couple of years"

Using recertified 6 TB SATA at ~$170 each. Usable figures are for a ZFS mirror.

| Build | Parts | Total | Usable | Day-one full | Redundancy |
|---|---|---|---|---|---|
| **P1 — recommended** | F2-425 Plus $382 + 2×6 TB recert $340 | **$722** | 5.45 TiB | 57% | mirror |
| **P2 — genuinely "start small"** | F2-425 Plus $382 + 1×6 TB recert $170 | **$552** | 5.45 TiB | 57% | **none until the twin is attached** |
| P3 — cheapest with a mirror | F2-425 $254 + 2×6 TB recert $340 | $594 | 5.45 TiB | 57% | mirror, but **4 GB RAM** |
| P3+ | P3 + 16 GB DDR4 later | $744–813 | — | — | worse than P1, costs more |
| P4 — 4-bay | F4-425 $365 + 2×6 TB recert $340 | $705 | 5.45 TiB | 57% | mirror; 4 GB, no M.2, 2 bays spare |

Add ~$60 for a 500 GB NVMe boot device on P1/P2 whenever convenient — it is optional at purchase
time (PVE can boot from the HDD mirror and be moved later) and there are three free slots.

**P2 deserves attention given the stated preference.** ZFS converts a single-disk vdev into a mirror
online and non-destructively with `zpool attach` — no rebuild of the pool, no downtime, just a
resilver. So P2 is not a dead end: it is P1 paid in two instalments, and the second instalment is
the part whose price is most likely to *fall* (HDDs are at a two-year high; the chassis, RAM and
NVMe markets are equally inflated but the chassis is the part that will not get cheaper in a way
that rewards waiting). The cost is an unprotected interval — acceptable for the WDMyCloud content,
which is still covered by BACKUP_A/B and Glacier, but **Time Machine would be its only copy** and
should not be pointed at the NAS until the mirror is complete.

**P4 (the 4-bay) is not the growth path it looks like** at these prices: it costs $111 more than the
base 2-bay *and* still needs a $150–219 RAM upgrade to run Immich properly, ending at $855–924 —
more than P1, on the older platform. The 4-bay only makes sense with the F4-425 **Plus** at $493
(16 GB, 3× M.2), which is a $111 premium over the F2-425 Plus for two spare bays. Given usage that
"should not grow very fast apart from Time Machine", 5.45 TiB at 57% full leaves ~2.3 TiB of
headroom — several years at the stated rate — and by then post-shortage 12 TB drives will make a
two-drive swap cheaper than a four-drive array is today.

### 8.5 Recommendation

**F2-425 Plus + 6 TB recertified SATA enterprise drives** — both of them if $722 is acceptable
(P1), otherwise one now and `zpool attach` the second when HDD prices ease (P2, $552, inside the
original budget). Do not buy the ST4000NM0023 (SAS, incompatible) or the RE4 2 TB (2010 design,
worst $/TB tier). Do not buy the base F2-425 unless Immich's ML features are being given up — the
RAM upgrade it needs costs more than the difference to the Plus.

## Sources

- [ListofDisks — live US retailer HDD price tracker](https://www.listofdisks.com/)
- [CMRCheck — CMR NAS HDD $/TB tracker](https://cmrcheck.com/hdd/)
- [HDDHunt — best hard drives for NAS 2026, ranked by $/TB](https://hddhunt.com/blog/best-hard-drives-for-nas-2026/)
- [HDDHunt — how much does 1TB of storage cost (Aug 19 2026)](https://hddhunt.com/blog/how-much-does-1tb-of-storage-cost/)
- [DatacenterDisk — where to buy, live prices](https://datacenterdisk.com/where-to-buy)
- [ServerPartDeals — manufacturer recertified drives](https://serverpartdeals.com/collections/manufacturer-recertified-drives)
- [Disk-Scout — best NAS hard drives 2026](https://disk-scout.com/guides/best-nas-hard-drives)
- [TerraMaster F2-425 official product page](https://www.terra-master.com/products/f2-425)
- [TerraMaster F4-425 official product page](https://www.terra-master.com/products/f4-425)
- [TerraMaster F2-425 Plus official product page](https://www.terra-master.com/products/f2-425-plus)
- [itpro — TerraMaster F2-425 Plus review (N150, 8 GB DDR5, 3× M.2, dual 5GbE)](https://www.itpro.com/infrastructure/servers-and-storage/terramaster-f2-425-plus-review-a-versatile-desktop-nas-at-a-great-price)
- [CNX Software — F2-425 Plus 3+2-bay teardown](https://www.cnx-software.com/2026/02/19/terramaster-f2-425-plus-32-bay-hybrid-nas-review-part-1-unboxing-teardown-drives-installation-and-first-boot/)
- [NASCompares — TerraMaster F2-425 before you buy (N5095, 4 GB DDR4, 16 GB max)](https://nascompares.com/review/terramaster-f2-425-nas-before-you-buy/)
- [Seagate ST4000NM0023 — Constellation ES.3 SAS 6Gb/s](https://www.bhphotovideo.com/c/product/929904-REG/seagate_st4000nm0023_4tb_constellation_es_3_sas.html)
- [WD RE4 WD2003FYYS — SATA II, released February 2010](https://www.amazon.com/RE4-Enterprise-Hard-Drive-WD2003FYYS/dp/B002XW44QY)
- [Tom's Hardware — RAM price index 2026](https://www.tomshardware.com/pc-components/ram/ram-price-index-2026-lowest-price-on-ddr5-and-ddr4-memory-of-all-capacities)
