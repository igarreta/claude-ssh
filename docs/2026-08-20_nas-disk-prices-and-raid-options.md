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

## Sources

- [ListofDisks — live US retailer HDD price tracker](https://www.listofdisks.com/)
- [CMRCheck — CMR NAS HDD $/TB tracker](https://cmrcheck.com/hdd/)
- [HDDHunt — best hard drives for NAS 2026, ranked by $/TB](https://hddhunt.com/blog/best-hard-drives-for-nas-2026/)
- [HDDHunt — how much does 1TB of storage cost (Aug 19 2026)](https://hddhunt.com/blog/how-much-does-1tb-of-storage-cost/)
- [DatacenterDisk — where to buy, live prices](https://datacenterdisk.com/where-to-buy)
- [ServerPartDeals — manufacturer recertified drives](https://serverpartdeals.com/collections/manufacturer-recertified-drives)
- [Disk-Scout — best NAS hard drives 2026](https://disk-scout.com/guides/best-nas-hard-drives)
