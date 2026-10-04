# NAS — boot NVMe mirror: 660p + 256 GB as ZFS RAID1

**Status:** active
**Host:** (project)
**Supersedes:** memory_nas-project.md (the "256 GB kept as a cold spare" sentence only), 2026-09-07_nas-software-stack.md (§ *Base OS* filesystem choice only)
**Superseded-by:** —

**Date**: 2026-10-04. Decided by the user; NAS not yet bought or built.

## Decision

Proxmox is installed with **ZFS RAID1 (`rpool`) across both M.2 slots**: the Intel 660p 512 GB
(slot 1) and the on-hand 256 GB M.2 (slot 2). It replaces *ext4 + LVM-thin on the 660p alone*,
with the 256 GB kept as a cold spare. Usable capacity is the smaller disk: ~238 GiB.

**Layout principle (unchanged, now explicit):** guest root/OS disks on `rpool` (NVMe); bulk data
on the HDD pool (`tank`) as bind mounts or data disks. The two get different backup paths —
PBS/vzdump for guest roots, ZFS snapshots + restic for data.

## Why a mirror, not cache or a second pool

- **Sudden failure is the NVMe risk that matters.** Wear-out shows up in SMART
  (`Percentage Used`, `Available Spare`, media errors) months ahead; controller/firmware death and
  power-loss mapping-table corruption give no warning. The 660p is also reused with unknown
  history. Monitoring cannot cover sudden death — only a second copy can.
- **Cache stays rejected** (see [2026-09-08_nas-chassis-decision-and-acceptance-test.md](2026-09-08_nas-chassis-decision-and-acceptance-test.md) §2):
  L2ARC — read-cold workload, 1 GbE already saturated by the HDD mirror; `special` vdev — must be
  mirrored (needs 2 free slots, there is 1) and must precede the restore; SLOG — few sync writes,
  and a consumer NVMe without power-loss protection is a poor SLOG.
- **A separate unmirrored pool** would give 512 + 256 GB but no redundancy anywhere.

## Capacity budget

ZFS should stay below ~80% → ~190 GiB working space.

| Item | Estimate |
|---|---|
| PVE host (root, logs, templates) | ~20 GB |
| `smb` LXC | ~8 GB |
| `immich` LXC (OS, Postgres, ML model cache) | ~25–30 GB |
| PBS on host (datastore is on `tank`) | ~2 GB |
| cygnus Docker VM (cygnus root measured 7.7 GB used, 2026-10-04) | ~32 GB |
| **Total** | **~90–100 GB** |

Conditions that keep this true:

- **Immich thumbnails/transcodes (`UPLOAD_LOCATION`) go on `tank`**, not the NVMe — they grow with
  the library (~5–10%, i.e. ~80–160 GB for 1.6 TB) and are regenerable.
- PVE `local` storage for vzdump dumps and ISOs points at `tank`, not `rpool`.
- Short snapshot retention on `rpool` — busy guest disks (Postgres) make snapshots grow.

## Installer caveat — check on day one

With two different-size disks the PVE installer may size partition 3 (ZFS) on the 660p to match
the 256 GB disk. Compare with `lsblk` right after install (runbook A4.5). If the 660p's partition
is small it is still fixable later — it is the last partition, so it can be grown in place.

## Upgrade path when `rpool` runs out (to be weighed then, not now)

- **Grow the mirror (keeps redundancy):** `zpool detach` the 256 GB, shut down, fit a ≥512 GB NVMe,
  replicate the partition table, `proxmox-boot-tool format`/`init` its ESP, `zpool attach`, resilver
  (minutes for ~100 GB). Mirror grows to min(660p partition, new) ≈ 512 GB with `autoexpand=on`.
  Only exposure: unmirrored during swap + resilver (2 slots, no way around it).
- **Split into two unmirrored pools:** `zpool detach rpool <256-part>` (instant, online), wipe it,
  create a guest-storage pool, `proxmox-boot-tool clean` to drop its stale ESP. 512 + 256 GB, no
  redundancy.
- **Move big guest disks to `tank`** — the existing layout principle, usually enough on its own.

## Related

- Field procedure: [2026-09-08_nas-us-acceptance-test-runbook.md](2026-09-08_nas-us-acceptance-test-runbook.md) (A1–A4.5, B5)
- [memory_nas-project.md](memory_nas-project.md), [2026-09-07_nas-software-stack.md](2026-09-07_nas-software-stack.md)
