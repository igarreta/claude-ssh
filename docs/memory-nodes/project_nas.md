---
name: project_nas
description: "NAS project — BOUGHT 2026-10-06: Minisforum N5 Air, $519 Amazon, barebone with the user's own 2× Kingston 16 GB (two SO-DIMM slots → 32 GB), 5 bays, 3 M.2; F4-424 Pro (decided 09-10) never ordered; N5-family JMB585 SATA silent corruption is NOT a return reason (user, 10-06) — Hawk Point is affected, kernel fixes exist, runbook Phase D verifies the mitigation before data lands; boot is a ZFS mirror of on-hand 660p + 256 GB; mirror disks still manufacturer-recert; cold-spare HGST picked 09-26"
metadata: 
  node_type: memory
  type: project
  originSessionId: 674728fe-657f-43ee-985f-f339c95e4974
  modified: 2026-10-06T00:00:00.000Z
---

NAS to absorb the WDMyCloud live shares, backup_usb1's *backup* role, a future MacBook's Time
Machine and PBS, plus Immich for family photo browsing. Hardware brought from abroad, ~3.1 TB
day one. **Urgent since 2026-09-06**: the WDMyCloud it replaces is dead
([[project_ceres_wdmycloud-nas-dead]]), so this is no longer a nice-to-have.

**BOUGHT 2026-10-06: Minisforum N5 Air, $519 Amazon** — chosen because its **two** SO-DIMM slots
take the user's own 2× Kingston 16 GB for 32 GB at no RAM cost, and Ryzen 8C/16T beats the N305.
The 09-30 allocation stands unchanged. Why it matters:
- **JMB585 SATA silent corruption — not a return reason (user, 10-06).** Root cause is the BIOS
  enabling root-port "enhanced atomics"; **Hawk Point (the Ryzen 7 255) is an affected platform**,
  so never assume the Air is immune. Mitigations: 7.0 32-bit quirk (`forcing 32bit` in dmesg),
  7.3 root-cause quirk, `amd_iommu=pgtbl_v2`. How to apply: run runbook **Phase D before any real
  data goes on `tank`**; on a kernel bump, check which fix is live before dropping the boot param.
- **Amazon's 30-day return is the only recourse** — Minisforum's warranty excludes Amazon units.
- **It's bigger than the F4-424 Pro the shelf was measured for** (199×202×252 mm, 4.0 kg) — re-check fit.
- The purchase brief was written outside the repo; its §9 conventions (`chmod 777`, Docker in LXC,
  docs in `/root`) contradict repo decisions — the banner there wins.
Detail: [[docs/2026-10-06_nas_minisforum-n5-air-purchase.md]], procedure:
[[docs/2026-09-08_nas-us-acceptance-test-runbook.md]].

**History — previous buy list (2026-09-10), never ordered: TerraMaster F4-424 Pro — i3-N305 8-core, 32 GB, $687 Amazon → $1,056.90
total.** The 4-bay fits the measured space. **The 09-08 F4-425 Plus N150 decision is dead**: its
$479.99 was the **N95/8 GB** price, read off a store page that sells only the N95 and then applied
to the N150, which actually lists at **$649.99**. So the 09-08 price-target table is void — its
"walk away above $520" was that SKU's *best-ever* price. At $649 the N150 sat only **$38** below the
Pro line, and the user chose RAM over LAN: everything is 1 GbE, and a future upgrade would be to
2.5GbE anyway. Accepted and **not to be re-opened**: 2× 2.5GbE not 5GbE, 2 M.2 slots not 3 (one is
needed for the boot NVMe), 32 GB is the ceiling with no upgrade path. Bonus over the 425 Plus:
a **published Proxmox install guide**, same BIOS menu names.

**Boot NVMe swapped 2026-09-27**: an unused Intel 660p 512 GB (M.2 2280, PCIe 3.0 x4) turned up
and is spec-compatible with the planned Patriot P310 — the slot only runs at PCIe 3.0 x1 regardless,
so there's no reason to buy one. Drops the $65 line item; run a SMART health check before trusting
it, since prior usage is unknown.

**Boot disk is a ZFS mirror since 2026-10-04**: the 660p + the on-hand 256 GB M.2 as `zfs (RAID1)`
(~238 GiB usable), so there is no boot spare left. Why it matters: NVMe drives often die suddenly
with no SMART warning, and only a second copy covers that. How to apply: guest roots on `rpool`,
bulk data **and Immich thumbnails** on `tank`; don't re-propose cache uses for the 256 GB; when
`rpool` fills, weigh the upgrade paths in [[docs/2026-10-04_nas_boot-nvme-mirror.md]].

**RAM was re-allocated for 32 GB on 2026-09-30** as starting values (tune ARC after the restore),
including a 6 GB VM that will take over cygnus and run Docker — table and open items in
[[docs/2026-09-30_nas_32gb-allocation-vm-and-docker-revision.md]]. Still true and still worth knowing when comparing SKUs:
**the F2 is 2 bays, the F4-425 Plus N95 is 8 GB**, "F4 N95 with 16 GB" is not a factory SKU, and a
bare 16 GB DDR5 SODIMM is ~$209 in the shortage — which is exactly why the 16 GB SKU costs $170 more
than the 8 GB one, and why **waiting for the old price will not work**.

**Disks are chosen after the chassis (user, 09-08).** Correctness is unaffected — the 2× 6 TB
sizing never depended on the NAS — but the **SATA bays cannot be tested until a drive is in**, so
the chassis's own US return window depends on the drives arriving. Budget ≥1 week of US time.

**Cold-spare third drive picked 2026-09-26**: eBay HGST Ultrastar 7K6000 (HUS726060ALE610),
$103.73 shipped (seller-refurbished, "wiped" only, no warranty) — Toshiba MG06ACA600E ($104.59)
then Seagate ST6000NM021A ($138.95), both same seller, are the fallbacks if that listing falls
through. Lower provenance than the mirror's manufacturer-recert pick is fine *for a spare*: it
isn't in the mirror's correlated-failure population and the warranty was already worthless once
in Argentina — but it must be burned in (`badblocks` + SMART long test) before being trusted,
since "wiped" is not "tested." **A local MercadoLibre WD Purple ($110) was checked and rejected**
— no warranty, low-reputation seller, despite a 14-day return window; the local-sourcing idea
itself remains worth revisiting for a better-rated listing.

**The acceptance runbook was corrected 2026-09-10**, and the correction matters: as written it told
the user to **return the box if the BIOS did not report 16 GB**, which would reject a correct 32 GB
machine. Re-read it before the trip if it has been a while.

**Testing gotcha worth remembering**: the box ships **diskless with no OS** — TOS installs from a
browser onto a disk you supply — and **TOS aborts long SMART self-tests** because it sleeps drives
after 30 min. Set `Hardware & Power → Hard Drive Sleep → Never` first, or use a live-Linux USB and
sidestep it. **Carry SystemRescue, not Ubuntu Live** — it ships smartmontools/nvme-cli/memtest86+
preinstalled, where Ubuntu Live needs internet and `apt` before it can test anything.

**Decisions not to re-derive** (each cost real investigation):

- **Pool/iGPU guests are LXCs; VMs allowed for self-contained guests** (narrowed 09-30 from
  "all LXCs, no VMs"). `smb` and `immich` stay LXCs because of shared data, not RAM — don't
  propose moving them into a VM. Host owns the disks, guests get bind mounts.
- **Samba: unprivileged LXC with `idmap=passthrough`.** The user leaned *privileged* after past
  idmap pain; the option that removes that pain is ignored on privileged containers, which
  reversed it. See [[project_proxmox_lxc_idmap_passthrough]].
- **Docker only inside VMs; podman inside LXCs** (09-30, replaces "no Docker in the fleet").
  Immich stays on podman — verified feature-by-feature against podman-compose's source. Traps in
  [[project_podman_compose_gotchas]].
- **Growth is a second mirror vdev in the spare bays, never RAIDZ** (a mirror pool cannot be
  converted). No L2ARC and no `special` vdev on the spare M.2 slots — and a `special` vdev would
  have to exist *before* the 1.6 TB restore or never, so don't propose it afterwards.
- **BACKUP_A/B rotation moves to the NAS** — frees gr-srv03's third USB port, makes the
  already-ordered RSH-A10 hub unnecessary (keep it: it is the fleet's only PPPS/`uhubctl` device),
  removes the host's only hot-plugged device (the Zigbee-drop root cause,
  [[project_gr-srv03_powered-hub-instability]]), and forces ceres's bind-mount backup architecture
  to change — still undesigned.

**Sourcing rule, broken five times now — and the fifth was ours, not the vendor's.** Four vendor,
support and aggregator errors on this chassis, then on 09-08 an internal one: a price scraped from
the right page but the wrong *configuration* on it. Two rules, both earned:
**(1)** trust only the **vendor product page or datasheet matched to the exact SKU** — the
datasheets in `download/` cover the **N150** variants, which is precisely why their 16 GB row was
misread as the N95's; **(2)** **a price is only valid attached to a SKU that same page will
actually sell you** — when a doc says "the store lists only variant X", every price on it is X's.
**TerraMaster customer support was wrong** too, in the direction the buyer wanted.

**How to apply**: multi-step project — read the write-ups before proposing hardware, prices or
architecture. **Current chassis decision, the corrected price table and the accepted trade-offs:**
[[docs/2026-09-10_nas-chassis-price-correction-f4-424-pro.md]]. RAM allocation, BACKUP_A/B cable
spec and hub reassessment (its §1 and price targets are superseded — don't act on them):
[[docs/2026-09-08_nas-chassis-decision-and-acceptance-test.md]].
**The US test procedure is a self-contained field runbook** —
[[docs/2026-09-08_nas-us-acceptance-test-runbook.md]] — built around a 15-minute Proxmox install on
the NVMe that turns the NAS into an SSH target on arrival day, so the chassis is testable before
the drives are even bought. Stack,
guests and share protocols (its two RAM sections are superseded):
[[docs/2026-09-07_nas-software-stack.md]]. Scope, sizing, buy list, open decisions:
[[docs/memory_nas-project.md]]. Market/OS research: [[docs/2026-08-19_nas-hardware-research.md]].
Disk prices and RAID layouts: [[docs/2026-08-20_nas-disk-prices-and-raid-options.md]].
Related: [[project_backup_schedule]], [[project_ceres_wdmycloud_glacier]].
