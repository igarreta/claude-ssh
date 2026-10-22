# NAS data disks — layout decision and purchase (3× 6 TB, eBay)

**Status:** open
**Status detail:** all 3 delivered and fitted 2026-10-21; SMART long PASS on all three 2026-10-22; full-surface write (in place of badblocks, 18 h budget) running (results in 2026-10-13_nas_n5-air-acceptance-test-results.md §12, §14) — both HGSTs had ERC disabled; return decision pending
**Host:** (project)
**Supersedes:** 2026-08-20_nas-disk-prices-and-raid-options.md (§4 layout choice and the goHardDrive buy list only)
**Superseded-by:** —

**Date:** 2026-10-13. Buyer in the USA; drives are hand-carried to Argentina, so seller warranties
are worthless and only the **US return window** matters.

## 1. Decision

**2×6 TB ZFS mirror + 1 cold spare (shelf, outside the chassis).** About 5.24 TiB usable after
ZFS overhead against a ~3.1 TB day-one need and a 5–6 TiB target. The five bays leave three free;
growth is a second mirror vdev, as already decided in
[memory_nas-project.md](memory_nas-project.md) — not RAIDZ.

**Why RAIDZ lost, with this month's prices** (US street, refurbished/used, 2026-10-12/13):

| Layout | Cost incl. spare | Usable | Verdict |
|---|---|---|---|
| 2×6 TB mirror + spare, refurb | **~$430–520** | 5.24 TiB | chosen |
| 4×2 TB RAIDZ1 + spare, goHardDrive HGST 2 TB $99.99 | ~$500 | 5.24 TiB | $20–70 cheaper at best, four failure points instead of two, one free bay |
| 3×3 TB RAIDZ1 + spare | no live refurb 3 TB listing | — | dominated |
| 3×4 TB RAIDZ1 + spare, **new** WD40EFZZ | ~$860 | ~7 TiB | over the 5–6 TiB target, $330+ more |

6 TB refurb is the cheapest $/TB band; 2 and 4 TB are the worst. RAIDZ gives no cost advantage at
this size, and the mirror resilvers only used blocks from one surviving disk.

## 2. What was bought (eBay, 2026-10-13)

| Role | Drive | Seller | Item no. | Paid | Condition | Returns | Est. delivery |
|---|---|---|---|---|---|---|---|
| Pool 1 | HGST Ultrastar 7K6000 HUS726060ALE610 | NoviaNet (100%, 1,268) | 168678676680 | $128.00 | Used, "Tested Good, DOD Wiped, Refurbished" | 30 d, **buyer pays** | 16–20 Oct |
| Pool 2 | Seagate Exos 7E8 ST6000NM021A | tcsystemsonline (100%, 3,022, Top Rated Plus) | 267714953372 | $170.71 | Used, no test statement | 30 d, seller pays | 15–17 Oct |
| Cold spare | HGST Ultrastar 7K6000 HUS726060ALE610 | OCDEPOT (99.7%, 228K sold) | 366687701834 | $129.99 | Used, "Tested Pass 100%" | 30 d, seller pays | 16–20 Oct |

**Total $428.70** (~$82 per usable TiB). Amounts equal the listed prices; confirm against the order
emails that no shipping/tax was added. Order numbers and receipts not yet recorded.

The mirror has two models and two sellers, so two lots: a same-batch failure does not take both
halves. The spare is an HGST and can replace either member.

The Seagate photo appears to carry a **Lenovo OEM label (P/N SHD7A23099)** — an OEM firmware, not
unusual for this part number, but see §4 item 2.

## 3. Why these sellers and not goHardDrive

goHardDrive was the earlier plan ($179.95 HGST g01-1079, $189.95 Exos g01-1326). Its returns page
gives **15 days, defective only, repair/replace at their discretion, no refund promised, 15%
restocking fee, return shipping at the buyer's cost**. With a fixed departure date a replacement
cannot be received and tested before leaving, so a refund-only seller (eBay) is worth more than the
~$10–40 price gap. The same page showed the earlier cold-spare pick (eBay HGST $103.73, 09-26) was
no longer live; the three listings above replace it.

## 4. Arrival checklist

Run in the NAS using SystemRescue (see the runbook), all three drives in parallel, the day each
arrives:

1. Compare the serial from `smartctl -i` with the label on each drive.
2. `smartctl -l scterc` on **each** drive, especially the Seagate (OEM firmware). If ERC reads
   disabled: `smartctl -l scterc,70,70 /dev/sdX` — **not persistent across power cycles**, needs a
   boot-time unit. Record power-on hours.
3. SMART long test (~10 h) plus one destructive `badblocks` pass (~12–15 h per 6 TB drive). A
   4-pass run does not fit the window.
4. Compare logical/physical sector size across the three; create the pool with `ashift=12`
   explicitly (not fixable afterwards).
5. Open an eBay return for any failure early enough to drop the box at the carrier **before
   leaving the US** — 30 days is the seller's window, the departure date is the real one.

**Failure handling:** with three drives, one failure still leaves a working two-drive mirror; the
spare is what is lost, and can be rebought locally. Two failures force a rebuy before leaving.

## 5. Not verified

- Power-on hours of all three drives; test status of the Seagate listing.
- Final delivery dates (two HGST arrive up to 20 Oct; with a ~23 Oct departure that leaves 2–3 days).
- ERC on the Seagate's OEM firmware.
- Backblaze AFR: none of the models is in the latest report (tables start at 8 TB); only the
  HGST HMS5C4040 4 TB family (0.57% lifetime) is nearby, which is a different drive.
- WD40EFZZ CMR could not be confirmed from WD's own datasheet (irrelevant now, drive not bought).
