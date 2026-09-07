---
name: project_nas
description: "NAS project — software stack fully decided 2026-09-07 (PVE + all-LXC); chassis is the one open decision, F2 8GB $833.90 vs F4 16GB $944.90, blocked on a width measurement; nothing ordered"
metadata: 
  node_type: memory
  type: project
  originSessionId: 674728fe-657f-43ee-985f-f339c95e4974
  modified: 2026-09-07T00:00:00.000Z
---

NAS to absorb the WDMyCloud live shares, backup_usb1's *backup* role, a future MacBook's Time
Machine and PBS, plus Immich for family photo browsing. Hardware brought from abroad, ~3.1 TB
day one. **Urgent since 2026-09-06**: the WDMyCloud it replaces is dead
([[project_ceres_wdmycloud-nas-dead]]), so this is no longer a nice-to-have.

**One decision blocks the order — the chassis.** Every model has a single SODIMM slot, so an F2
upgrade discards its bundled stick, making the **F4-425 Plus N95 ($510, 16 GB, $944.90 total)**
the cheapest route to 16 GB — ~$98 *under* an F2 plus a ~$209 stick. Against it the **F2-425 Plus
N95 ($399, 8 GB, $833.90)**. Since the all-LXC RAM budget is 7.5–9 GB against 8 GB, this
**resolves the binding constraint rather than adding headroom**. "2 bays" was decided on box size
and then reopened when support confirmed the F4's 16 GB. **It turns solely on 59 mm of extra
width; the user is measuring. Order nothing until then.**

**Decisions not to re-derive** (each cost real investigation):

- **All LXCs, no VMs** — forced by shared data (Samba writes what Immich reads; only LXCs
  bind-mount) as much as by RAM. Host owns the disks, guests get bind mounts.
- **Samba: unprivileged LXC with `idmap=passthrough`.** The user leaned *privileged* after past
  idmap pain; the option that removes that pain is ignored on privileged containers, which
  reversed it. See [[project_proxmox_lxc_idmap_passthrough]].
- **Immich: podman, no Docker.** Verified feature-by-feature against podman-compose's source.
  Traps in [[project_podman_compose_gotchas]].
- **BACKUP_A/B rotation moves to the NAS** — frees gr-srv03's third USB port, makes the
  already-ordered RSH-A10 hub unnecessary, removes the host's only hot-plugged device (the
  Zigbee-drop root cause, [[project_gr-srv03_powered-hub-instability]]), and forces ceres's
  bind-mount backup architecture to change.

**Sourcing rule, learned the hard way**: the RAM story was rewritten **four times on 2026-09-07**
on aggregator and retailer claims, every one of them wrong. **Trust only the vendor datasheet
(committed to `download/`), a teardown, or TerraMaster support** — and note the datasheets cover
the **N150** variants, not the N95 machines being bought. Rejected options are listed in the docs;
don't re-open them.

**How to apply**: multi-step project — read the write-ups before proposing hardware, prices or
architecture. Stack, guests, share protocols and the RAM budget:
[[docs/2026-09-07_nas-software-stack.md]]. Scope, sizing, buy list, open decisions:
[[docs/memory_nas-project.md]]. Market/OS research: [[docs/2026-08-19_nas-hardware-research.md]].
Disk prices and RAID layouts: [[docs/2026-08-20_nas-disk-prices-and-raid-options.md]].
Related: [[project_backup_schedule]], [[project_ceres_wdmycloud_glacier]].
