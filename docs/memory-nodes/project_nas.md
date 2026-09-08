---
name: project_nas
description: "NAS project — chassis decided 2026-09-08: TerraMaster F4-425 Plus N150 (16 GB), ~$914.89; the 16 GB is the N150 SKU not the N95 (vendor store lists only N95 — buy from Amazon US B0FLHTF2PQ); disks chosen after the NAS; nothing ordered"
metadata: 
  node_type: memory
  type: project
  originSessionId: 674728fe-657f-43ee-985f-f339c95e4974
  modified: 2026-09-08T00:00:00.000Z
---

NAS to absorb the WDMyCloud live shares, backup_usb1's *backup* role, a future MacBook's Time
Machine and PBS, plus Immich for family photo browsing. Hardware brought from abroad, ~3.1 TB
day one. **Urgent since 2026-09-06**: the WDMyCloud it replaces is dead
([[project_ceres_wdmycloud-nas-dead]]), so this is no longer a nice-to-have.

**Buy list is final (2026-09-08): TerraMaster F4-425 Plus, N150 variant, 16 GB, $479.99 → $914.89
total.** The user measured the space and the 4-bay fits. **The 16 GB belongs to the N150 SKU, not
the N95** — both F4 variants cost the same, so 16 GB carries no CPU premium and the 08-30
"N95 not N150" call is moot. At 16 GB the stack's compromises are withdrawn: ARC 4 GB, Immich ML
on, PBS stays an LXC.

**terra-master.com lists only the N95 (8 GB)** as of 09-08 — the N150/16 GB is a separate SKU on
Amazon US (`B0FLHTF2PQ`; the N95 is `B0GW883KMF`, identical model name) and Newegg, $456–520.
Never settle for the F4 N95 at full price: it fails the RAM budget and costs ~$209 more to fix,
the single SODIMM slot meaning the upgrade *replaces* the bundled stick. **Price targets for all
four SKUs** (buy the N150 at ≤$470, walk away >$520) are in the 09-08 doc — and note the recurring
confusions it settles: **the F2 is 2 bays, the F4 N95 is 8 GB**, and "F4 N95 with 16 GB" is not a
factory SKU.

**Disks are chosen after the chassis (user, 09-08).** Correctness is unaffected — the 2× 6 TB
sizing never depended on the NAS — but the **SATA bays cannot be tested until a drive is in**, so
the chassis's own US return window depends on the drives arriving. Budget ≥1 week of US time.

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

**Sourcing rule, learned the hard way and then broken again**: the RAM story was rewritten four
times on 2026-09-07 and corrected a fifth time on 09-08. **TerraMaster customer support was
wrong**, in the direction the buyer wanted. Trust only the **vendor product page or datasheet
matched to the exact SKU** — the datasheets in `download/` cover the **N150** variants, which is
precisely why their 16 GB row was misread as the N95's.

**How to apply**: multi-step project — read the write-ups before proposing hardware, prices or
architecture. Chassis decision, 16 GB allocation, BACKUP_A/B cable spec, hub reassessment and the
**price targets and rationale**: [[docs/2026-09-08_nas-chassis-decision-and-acceptance-test.md]].
**The US test procedure is a self-contained field runbook** —
[[docs/2026-09-08_nas-us-acceptance-test-runbook.md]] — built around a 15-minute Proxmox install on
the NVMe that turns the NAS into an SSH target on arrival day, so the chassis is testable before
the drives are even bought. Stack,
guests and share protocols (its two RAM sections are superseded):
[[docs/2026-09-07_nas-software-stack.md]]. Scope, sizing, buy list, open decisions:
[[docs/memory_nas-project.md]]. Market/OS research: [[docs/2026-08-19_nas-hardware-research.md]].
Disk prices and RAID layouts: [[docs/2026-08-20_nas-disk-prices-and-raid-options.md]].
Related: [[project_backup_schedule]], [[project_ceres_wdmycloud_glacier]].
