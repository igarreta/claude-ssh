# NAS — the $479.99 N150 price was never real; chassis changes to the F4-424 Pro

**Status:** open
**Host:** (project)
**Supersedes:** 2026-09-08_nas-chassis-decision-and-acceptance-test.md (§1 and its price-target table only)
**Superseded-by:** —

**Date**: 2026-09-10. The user went to order and found street prices nothing like the ones on the
buy list. Checking them turned up the **fifth price/spec error on this chassis** — and this one is
mine, not the vendor's. Correcting it moves the purchase to a different machine.

## 1. CORRECTION — the F4-425 Plus N150/16 GB was never $479.99

[2026-09-08_nas-chassis-decision-and-acceptance-test.md](2026-09-08_nas-chassis-decision-and-acceptance-test.md)
§1 records **both** F4-425 Plus CPU variants at **$479.99** and concludes *"both variants cost the
same, so the RAM decides the CPU and the CPU premium is zero."* That conclusion is wrong.

The same doc, four paragraphs later, records that **terra-master.com lists only the N95**. Those two
statements cannot both be load-bearing: the $479.99 read off the store page was the price of the
**N95/8 GB** configuration, and it was then applied to a SKU that store does not sell. The N150/16 GB
has its own list price.

| | 09-08 doc claimed | Actual, verified 2026-09-10 |
|---|---|---|
| F4-425 Plus **N95, 8 GB** | $479.99 | **$479** Newegg (sale, ends 09/21) — the price that was real |
| F4-425 Plus **N150, 16 GB** | $479.99 | **$649** Newegg — list is $649.99 |

Historical floor for the N150/16 GB is **$519.99** (Newegg/Amazon, 20% off $649.99, March 2026).
So the 09-08 decision table's *"buy at ≤$470, walk away above $520"* was calibrated against a price
that never existed, and its walk-away number was in fact the SKU's **best-ever** price.

> **Rule reinforced, fifth data point — and the first one that is our own error, not TerraMaster's.**
> The previous four were vendor/support/aggregator mistakes. This one was an internal inconsistency
> that survived because the price came from the right page but the wrong configuration on it.
> **A price is only valid attached to a SKU that the same page will actually sell you.** When a doc
> says "the store lists only variant X", every price scraped from that store belongs to X.

### Why waiting for the old price will not work

The $170 gap between the two F4-425 Plus variants is **8 GB of DDR5 at shortage pricing**, not a
discount cycle — the same shortage that puts a bare 16 GB SODIMM at ~$209 (09-08 doc §1). The
16 GB SKU's list price rose; it did not go off sale. Combined with the WD MyCloud being dead since
2026-09-06 ([2026-09-06_ceres_wdmycloud-nas-dead.md](2026-09-06_ceres_wdmycloud-nas-dead.md)),
there is nothing to be gained by holding out for $519.99.

## 2. The decision changes shape: the Pro line is now $38 away

At the corrected prices the F4-425 Plus N150 is no longer the value pick it was chosen as. Disks and
boot NVMe are unchanged throughout: $179.95 + $189.95 + $65.00 = **$434.90**.

| SKU | CPU | RAM | Bays | LAN | M.2 | Chassis | **Project total** |
|---|---|---|---|---|---|---|---|
| F2-425 Plus N95 | 4c | 8 GB | 2 | 2× 5GbE | 3 | $375 Newegg (ends 09/21) | $809.90 |
| F4-425 Plus N95 | 4c | 8 GB | 4 | 2× 5GbE | 3 | $479 Newegg (ends 09/21) | $913.90 |
| F4-425 Plus N150 | 4c | 16 GB | 4 | 2× 5GbE | 3 | $649 Newegg | $1,083.90 |
| F4-425 **Pro** N350 | 8c | 16 GB | 4 | 2× 5GbE | 3 | $679.99 vendor | $1,114.89 |
| **F4-424 Pro** i3-N305 | **8c** | **32 GB** | 4 | 2× 2.5GbE | 2 | **$687** Amazon | **$1,121.90** |

**The F4-425 Plus N150 at $649 is strictly dominated.** For **+$38** the F4-424 Pro doubles both the
cores and the RAM. It loses only 5GbE (→2.5GbE) and one M.2 slot (3→2), and the project needs one
M.2 slot for the PVE boot NVMe.

## 3. DECIDED 2026-09-10 — TerraMaster F4-424 Pro, $687, total $1,121.90

The user's reasoning, and it is the right one: **"now all is 1 GbE. I may grow later, but the RAM
will make a much larger difference in the long term."**

- **The LAN loss is close to notional.** Nothing on the LAN exceeds 1 GbE today, so both 5GbE and
  2.5GbE are equally unused. If the LAN is ever upgraded it will be to **2.5GbE** — the switch
  price gap between 2.5 and 5 GbE is still large — so the 424 Pro is arguably at the *right* level
  rather than a step down.
- **32 GB ends the RAM question permanently.** The whole 09-07/09-08 argument was about whether the
  all-LXC budget fits in 16 GB with ARC and Immich ML. At 32 GB there is nothing left to ration,
  and there is room for guests this project has not thought of yet.
- **8 cores make the Immich ingest a non-event.** The 708 GB video library transcodes once; the
  i3-N305 has 8 cores and a 32 EU iGPU against the N150's 4 cores / 24 EU.
- **It has a documented Proxmox install path.** There is a published F4-424 Pro Proxmox guide and
  TerraMaster's own forum threads for the 424 series, and the BIOS steps are **identical to the ones
  already in the runbook** (`Fast → TOS Boot First = Disabled`, `Security → Secure Boot`,
  `Boot → UEFI USB BBS Priorities`, F4 to save). The 425 Plus had no such precedent.

### Accepted trade-offs — do not re-open these

| | F4-424 Pro | Why it is acceptable |
|---|---|---|
| LAN | 2× 2.5GbE, not 5GbE | LAN is 1 GbE; a future upgrade would be to 2.5GbE anyway |
| M.2 slots | 2, not 3 | One is needed (P310 boot). No L2ARC and no `special` vdev — already decided |
| RAM ceiling | ships **at** its 32 GB max, single module, no upgrade path | It starts at double what the design needs |
| Max drive | 22 TB/bay, 88 TB total | The pool is 2× 6 TB with a second mirror vdev as growth |
| Generation | 2024 "424" line, not the 2025 "425" | Buys the Proxmox precedent; TOS is not being used anyway |
| Power | 33 W loaded / 13 W hibernation, 90 W PSU | Higher than the N150, but this is a 24/7 box doing real work |

### Still open

- **USB port count and connector types.** The vendor spec table lists **2 rear USB 3.2 Gen2
  (10 Gbps)** and 1× HDMI 2.0b, with no front port; retail listings mention a Type-C among them.
  Confirm on unboxing. **This matters for the BACKUP_A/B rotation**, which moves to the NAS — but
  only one of the two drives is ever connected at a time, so 2 ports is sufficient, just not roomy.
- **The third 6 TB cold spare (~$180)** — unchanged and still the user's call before the trip.
- Nothing has been ordered.

## 4. What this does *not* change

The software stack, the guest layout and every architectural decision stand — they were designed
against 16 GB and only get easier at 32 GB. Specifically unchanged: all LXCs and no VMs; Samba as an
unprivileged LXC with `idmap=passthrough`; Immich on podman; growth as a second mirror vdev and never
RAIDZ; no L2ARC and no `special` vdev; BACKUP_A/B rotation moving to the NAS and freeing gr-srv03's
third USB port. See [2026-09-07_nas-software-stack.md](2026-09-07_nas-software-stack.md) and §2–§4 of
the [09-08 decision doc](2026-09-08_nas-chassis-decision-and-acceptance-test.md), which are **not**
superseded — only its §1 and price table are.

The RAM allocation in that doc was a 16 GB budget. At 32 GB it is no longer a budget at all; ARC can
take more than the 4 GB it was allotted. **Do not re-plan the allocation before the box is bought** —
tune ARC after the restore, against real usage.

## 5. Acceptance runbook — corrected in place

[2026-09-08_nas-us-acceptance-test-runbook.md](2026-09-08_nas-us-acceptance-test-runbook.md) was
written for the F4-425 Plus and told the user to **return the box if the BIOS did not report 16 GB**.
Followed as written it would have rejected a correct 32 GB machine. It carries a correction banner
and the four chassis-specific checks have been updated: expected memory **32768 MB / 32 GB**, memtest
pass ~30–40 min, LAN link **2500Mb/s**, and 2 M.2 slots / 2 rear USB ports. The Proxmox install
procedure itself needed no change.

## Sources

- [TerraMaster F4-424 Pro product page](https://www.terra-master.com/products/f4-424-pro) — specs, $730.99 vendor price
- [TerraMaster F4-425 Pro product page](https://www.terra-master.com/products/f4-425-pro) — $679.99, N305/8 GB or N350/16 GB
- [datacenterdisk price tracker](https://datacenterdisk.com/nas-devices/terramaster) — F4-424 Pro $687.99; F4-425 Plus out of stock
- [Newegg F4-425 Plus N150 16 GB](https://www.newegg.com/terra-master-f4-425-plus/p/14P-006A-00099)
- [Slickdeals, March 2026](https://slickdeals.net/f/19344966-terramaster-f4-425-plus-4-bay-nas-intel-n150-cpu-ddr5-16gb-ram-20-off-deal-519-99) — N150/16 GB at $519.99, 20% off $649.99: the historical floor
- [selfhosthero F4-424 Pro Proxmox install guide](https://selfhosthero.com/terramaster-f4-424-pro-proxmox-install-guide/) and [TerraMaster forum, Proxmox on the 424 series](https://forum.terra-master.com/en/viewtopic.php?t=7105)
- User-reported Newegg/Amazon prices, 2026-09-10
