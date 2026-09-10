---
name: project_nas
description: "NAS project — chassis decided 2026-09-10: TerraMaster F4-424 Pro (i3-N305 8-core, 32 GB), $687, total $1,121.90; the 09-08 F4-425 Plus N150 pick rested on a $479.99 price that was never real (that was the N95/8 GB price — the N150/16 GB lists at $649.99); disks chosen after the NAS; nothing ordered"
metadata: 
  node_type: memory
  type: project
  originSessionId: 674728fe-657f-43ee-985f-f339c95e4974
  modified: 2026-09-10T00:00:00.000Z
---

NAS to absorb the WDMyCloud live shares, backup_usb1's *backup* role, a future MacBook's Time
Machine and PBS, plus Immich for family photo browsing. Hardware brought from abroad, ~3.1 TB
day one. **Urgent since 2026-09-06**: the WDMyCloud it replaces is dead
([[project_ceres_wdmycloud-nas-dead]]), so this is no longer a nice-to-have.

**Buy list (2026-09-10): TerraMaster F4-424 Pro — i3-N305 8-core, 32 GB, $687 Amazon → $1,121.90
total.** The 4-bay fits the measured space. **The 09-08 F4-425 Plus N150 decision is dead**: its
$479.99 was the **N95/8 GB** price, read off a store page that sells only the N95 and then applied
to the N150, which actually lists at **$649.99**. So the 09-08 price-target table is void — its
"walk away above $520" was that SKU's *best-ever* price. At $649 the N150 sat only **$38** below the
Pro line, and the user chose RAM over LAN: everything is 1 GbE, and a future upgrade would be to
2.5GbE anyway. Accepted and **not to be re-opened**: 2× 2.5GbE not 5GbE, 2 M.2 slots not 3 (one is
needed, for the P310 boot NVMe), 32 GB is the ceiling with no upgrade path. Bonus over the 425 Plus:
a **published Proxmox install guide**, same BIOS menu names.

**At 32 GB the RAM question is closed for good** — don't re-plan the ARC/Immich allocation before
the box exists; tune ARC after the restore. Still true and still worth knowing when comparing SKUs:
**the F2 is 2 bays, the F4-425 Plus N95 is 8 GB**, "F4 N95 with 16 GB" is not a factory SKU, and a
bare 16 GB DDR5 SODIMM is ~$209 in the shortage — which is exactly why the 16 GB SKU costs $170 more
than the 8 GB one, and why **waiting for the old price will not work**.

**Disks are chosen after the chassis (user, 09-08).** Correctness is unaffected — the 2× 6 TB
sizing never depended on the NAS — but the **SATA bays cannot be tested until a drive is in**, so
the chassis's own US return window depends on the drives arriving. Budget ≥1 week of US time.

**The acceptance runbook was corrected 2026-09-10**, and the correction matters: as written it told
the user to **return the box if the BIOS did not report 16 GB**, which would reject a correct 32 GB
machine. Re-read it before the trip if it has been a while.

**Testing gotcha worth remembering**: the box ships **diskless with no OS** — TOS installs from a
browser onto a disk you supply — and **TOS aborts long SMART self-tests** because it sleeps drives
after 30 min. Set `Hardware & Power → Hard Drive Sleep → Never` first, or use a live-Linux USB and
sidestep it. **Carry SystemRescue, not Ubuntu Live** — it ships smartmontools/nvme-cli/memtest86+
preinstalled, where Ubuntu Live needs internet and `apt` before it can test anything.

**Decisions not to re-derive** (each cost real investigation):

- **All LXCs, no VMs** — forced by shared data (Samba writes what Immich reads; only LXCs
  bind-mount) as much as by RAM. Host owns the disks, guests get bind mounts.
- **Samba: unprivileged LXC with `idmap=passthrough`.** The user leaned *privileged* after past
  idmap pain; the option that removes that pain is ignored on privileged containers, which
  reversed it. See [[project_proxmox_lxc_idmap_passthrough]].
- **Immich: podman, no Docker.** Verified feature-by-feature against podman-compose's source.
  Traps in [[project_podman_compose_gotchas]].
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
