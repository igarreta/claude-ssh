# NAS project — software stack

**Status:** open
**Host:** (project)
**Supersedes:** —
**Superseded-by:** —

**Date**: 2026-09-07. Hardware buy list and sizing are in
[memory_nas-project.md](memory_nas-project.md); this doc covers only what runs on the box
once it exists. Nothing purchased, nothing built.

## Decided 2026-09-07: everything is an LXC, no VMs

Two independent reasons, either of which is sufficient:

1. **Shared data forces it.** Samba writes the share tree, Immich reads the same tree as an
   external library. Only LXCs can bind-mount a host dataset. A VM would need a virtual disk
   (private to that VM, invisible to the other guests) or an NFS/SMB re-export back to the host
   — a second network hop and a second cache for data that is already local.
2. **RAM.** VM memory is reserved; LXC memory is shared and on-demand. See the budget below —
   there is no headroom to reserve.

A PBS **VM** additionally cannot use a bind mount, so its datastore would have to be a zvol
(ZFS-on-ZFS write amplification, invisible to the host) or NFS — which
[2026-08-19_nas-hardware-research.md](2026-08-19_nas-hardware-research.md) §6 already rejected,
the chunk store being fsync- and latency-sensitive.

What is given up: PBS in an LXC is community practice, not officially supported (Proxmox
supports bare-metal or VM). The zero-RAM-cost supported alternative is `apt install
proxmox-backup-server` **on the PVE host itself** — documented by Proxmox, datastore is a plain
directory on the pool, at the cost of mixing roles onto the hypervisor. Kept as a fallback.

## Base OS

**Proxmox VE 9** on the Patriot P310 NVMe, ext4 + LVM-thin (installer default, same layout as
gr-srv03). The two 6 TB HDDs are **not** touched by the installer.

The ZFS mirror is created afterwards from the host, addressing disks by `/dev/disk/by-id/`,
never `/dev/sdX` — the same lesson as the 2026-07-15 zigbee2mqtt USB re-enumeration outage
([memory_docker03_zigbee2mqtt.md](memory_docker03_zigbee2mqtt.md)).

Dataset layout, split so each piece gets its own snapshot policy and quota:

| Dataset | Purpose | Notes |
|---|---|---|
| `tank/shares/{pictures,videos,documents,outlook,…}` | SMB live shares | snapshotted |
| `tank/shares/peliculas` | movies | no snapshots, excluded from backup, as today |
| `tank/timemachine` | MacBook Time Machine | ZFS quota 1T |
| `tank/pbs` | PBS datastore | |
| `tank/backups` | restic repos pushed from ceres etc. | |

`acltype=posixacl` and `xattr=sa` must be set **before** the datasets are populated —
retrofitting them onto 1.6 TB is painful.

**ARC must be capped explicitly** (`zfs_arc_max` in `/etc/modprobe.d/zfs.conf`). At 8 GB this
is not a tuning nicety; it is the difference between a working box and one that swaps.

## Guests

| Guest | Type | RAM | Role |
|---|---|---|---|
| `smb` | LXC, Debian 13 | 0.5 GB | Samba — live shares + Time Machine |
| `pbs` | LXC, unprivileged | 1–1.5 GB | Proxmox Backup Server, datastore on `/tank/pbs` |
| `immich` | LXC, `nesting=1`, containers inside | 3–4 GB | Immich stack, external-library mode |

`/dev/dri` is passed into the Immich LXC for N95 QuickSync (thumbnails, video transcode) — a
device entry plus group membership, which is trivial in an LXC and VFIO in a VM.

## How the disks reach the file server

```
2× 6 TB HDD ──SATA backplane──► PVE host ──► zpool "tank" (mirror)
                                              │
                                              ├─ bind mount ─► smb LXC    /srv/shares  (rw)
                                              ├─ bind mount ─► immich LXC /mnt/photos  (ro)
                                              └─ bind mount ─► pbs LXC    /datastore
```

The host owns the drives outright; ZFS talks to raw SATA devices, which is what it wants. No
guest ever sees a block device — each sees a directory. One page cache, no copies, one pool to
scrub and snapshot.

The alternative this forecloses is SATA-controller passthrough to a storage VM (the TrueNAS
pattern). It is unnecessary here and unaffordable at 8 GB.

## How shares are served

| Protocol | Serves | Clients |
|---|---|---|
| **SMB** (Samba LXC) | live shares — pictures, videos, documents | Windows, macOS Finder, phones |
| **SMB + `vfs_fruit`** | `tank/timemachine`, 1 TB quota | future MacBook |
| **PBS protocol** | guest backups | gr-srv03 adds the NAS as PBS storage |
| **SFTP** (plain sshd) | restic repos | ceres, contabo2 |
| **HTTPS** | Immich web + phone apps | family |

Time Machine over SMB, not AFP — Netatalk is dead and modern macOS prefers SMB.

**No NFS**, deliberately: kernel NFS does not work in an unprivileged LXC, and nothing needs it.
PBS has its own protocol, and restic over SFTP is both simpler and already proven here — it is
what fixed contabo2 after NFS-over-WAN hung
([2026-08-17_contabo2_nfs-backup-hang-rclone-migration.md](2026-08-17_contabo2_nfs-backup-hang-rclone-migration.md)).

## The RAM budget is the binding constraint

| | RAM |
|---|---|
| PVE host | ~1 GB |
| ZFS ARC (capped) | 2 GB |
| `smb` LXC | 0.5 GB |
| `pbs` LXC | 1–1.5 GB |
| `immich` LXC (Postgres + ML) | 3–4 GB |
| **Total** | **7.5–9 GB** |

**The all-LXC plan is already at or slightly over the 8 GB the chassis ships with.** Something
has to give: ARC down to 1 GB (hurts ZFS), or Immich ML disabled (loses face recognition and
smart search — the reason Immich was chosen over a plain gallery).

**Correction 2026-09-07 — the cheap 16 GB path is gone.** The 08-19 and 08-20 research recorded
the **F4-425 Plus as shipping with 16 GB DDR5 at $493**, making it cheaper than any chassis plus
a $209 SODIMM and the obvious answer if RAM ever became the constraint. The user checked Amazon
on 2026-09-07: **it now ships with 8 GB.** That escape hatch is closed. Consequences:

- No TerraMaster model in this range ships with more than 8 GB. RAM can only be added as a
  ~$209 aftermarket SODIMM (DRAM shortage pricing, unlikely to ease before 2027).
- **Verify the SODIMM slot count on the F2-425 Plus before assuming an upgrade is additive.**
  If it is a single slot, a 16 GB stick *replaces* the 8 GB rather than joining it, and the
  original stick is wasted.
- The F2-425 Plus → F4-425 Plus step ($383 → $493) now buys **two extra bays and nothing else**.
  It is a pure growth-path argument, no longer a RAM argument. The mirror is 57% full on day
  one, so this is not urgent — but it is the last moment it can be decided cheaply.

## Open — Samba permissions: unprivileged + idmap vs privileged LXC

**Deferred to a later discussion (2026-09-07).** The user has been burned by Samba-in-LXC
permissions before and leans toward a **privileged LXC** as the lesser evil; running Samba
directly on the PVE host was raised and is deprioritised, not eliminated.

The trade: a privileged LXC makes the whole problem disappear, at the cost that a container
escape is host root — on the box holding the only copy of the family photos.

Landmines that apply to the unprivileged path, roughly in the order they bite:

1. **idmap is opaque.** `lxc.idmap` in the container conf must match `/etc/subuid`/`/etc/subgid`
   on the host. A wrong range means the container refuses to start, with an unhelpful error.
   Background: [Proxmox_unpriviedged_LXC_mount_permissions.md](Proxmox_unpriviedged_LXC_mount_permissions.md).
2. **Three writers, one tree.** Samba writes, Immich reads, host-side restic/rsync touches the
   same files — three UID contexts. Needs a shared group and a consistent umask, chosen up front.
3. **`force user`/`force group` works but flattens ownership.** Acceptable for a family share,
   wrong for multi-user Time Machine.
4. **`vfs_fruit` is order-sensitive** in the `vfs objects` line and fails silently — a
   misconfiguration corrupts Time Machine backups rather than erroring. Changing
   `fruit:metadata` mode later invalidates existing metadata.
5. **The restore arrives with foreign UIDs.** The 1.6 TB comes back from a restic repo that
   captured WDMyCloud/TurnKey ownership. There is a UID remap step on restore that is easy to
   discover only after copying 1.6 TB.

Prior art in the fleet: samba03 is a TurnKey fileserver appliance whose quirks are already known.

## Open — Immich container runtime

**Deferred to a later discussion (2026-09-07).** Immich upstream supports **Docker Compose
only**; the user runs **rootful `sudo podman`** on cygnus and prefers it.

Points to settle when it is taken up:

- Rootful podman avoids the worst issue — rootless would add a *second* UID shift on top of the
  LXC's, double-mapping every file.
- Remaining friction is `depends_on` + healthcheck semantics, which Immich's compose file leans
  on and podman's compose handling has historically been weaker at.
- The Postgres image is not stock: Immich requires a pgvector-enabled image, not a plain
  `postgres:` tag.
- LXC needs `nesting=1`; podman additionally wants `keyctl=1`.
- `/dev/dri` crosses two boundaries (host → LXC → container). The `render` group GID commonly
  differs between host and container, producing a silent fallback to software transcoding
  rather than an error.
- Immich moves fast and breaks things — pin a release, do not track `:latest`.

## Immich capabilities — resolved 2026-09-07

**Video: yes, fully.** Native playback in web and mobile apps, thumbnails, preview clips, motion
photos, ffmpeg transcoding with QuickSync/VAAPI. The 708 GB of Shared Videos becomes browsable.
Caveats: transcoded copies consume space *on top of* the originals (policy is configurable);
exotic codecs can fail to transcode and simply will not preview; the N95 has no AV1 encode,
which Immich does not need by default.

**Multiple storages: yes** — one internal upload library (Immich owns the layout), plus **any
number of external libraries**, each with its own import paths and exclusion patterns. So
"unprocessed" and "selected" are two external libraries over two dataset paths.

**The usual trap does not apply here.** Immich never writes, renames, moves, or deletes files in
an external library; albums and favourites are database concepts that leave the disk untouched.
Curating inside Immich therefore cannot reorganise the filesystem. **The user confirmed
2026-09-07 that selection is done outside Immich**, so this is a non-issue for this project —
Immich rescans after the fact.

Two consequences that do still apply:

- **Thumbnails and transcodes for external assets land in `UPLOAD_LOCATION`**, not next to the
  originals. That grows with library size and must be sized against the 480 GB boot NVMe.
- **Library watching uses inotify** — it works on local datasets and not over any network mount,
  which is a further argument for Immich living on the NAS rather than on cygnus.

## Prerequisite — restic restore source, verified 2026-09-07

The 1.6 TB must come back from restic, the source being dead. This was worth checking before
buying hardware, because
[2026-08-14_ceres-empty-snapshots-probe.md](2026-08-14_ceres-empty-snapshots-probe.md) records
seven months of empty snapshots whose cause was never reproduced.

**Checked on ceres 2026-09-07 — the restore source is sound.**

| Check | Result |
|---|---|
| Repo | `/mnt/backup_b/restic-wdmycloud` (BACKUP_B connected), 1.4 TB on disk, 952 GB free of 2.7 TB |
| Snapshots | **14**, 2025-12-24 → 2026-09-05, sizes 1.450–1.462 TiB — tightly clustered, **no empty or partial snapshots** |
| Latest | `866e7c76`, 2026-09-05 02:30 — the last run before the NAS died |
| Contents | 117,635 files, **1.462 TiB** restore size, matching the documented 1.6 TB of WDMyCloud usage |
| Completeness | includes `Peliculas`, `Shared Music`, `Shared Pictures`, `Shared Videos`, `Outlook` |
| Integrity | `restic check` structural pass **clean** — all packs, 14/14 snapshots, trees and blobs |
| Cron safety | both WDMyCloud cron lines still commented out, so retention cannot be poisoned |

**The local repo, not S3 Glacier, is the restore source.** The Glacier repo deliberately excludes
`Peliculas`, `Copia disco iMac Mantchoff`, `Archivos` and `Shared Music` (~330 GB) — see
[memory_ceres_wdmycloud_glacier.md](memory_ceres_wdmycloud_glacier.md) — and restoring from Deep
Archive carries 12–48 h latency plus retrieval fees. Glacier is the copy of last resort.

**Remaining caveats:**

- **BACKUP_A has its own independent repo and is offsite**, so it could not be checked. Its most
  recent WDMyCloud snapshot is only as fresh as its last connection. Worth verifying at the next
  rotation, since it is the second copy of data that now has no live source.
- A `--read-data-subset=2%` pass was still running when this was written; the structural check
  above is the part that proves index and tree consistency.
- **The restore will arrive with WDMyCloud/TurnKey UIDs** — see the Samba landmines above.

## Related

[memory_nas-project.md](memory_nas-project.md) — scope, sizing, buy list.
[2026-08-19_nas-hardware-research.md](2026-08-19_nas-hardware-research.md) — OS comparison, PBS
placement, market context.
[2026-08-20_nas-disk-prices-and-raid-options.md](2026-08-20_nas-disk-prices-and-raid-options.md)
— drive prices and RAID layouts.
[2026-09-06_ceres_wdmycloud-nas-dead.md](2026-09-06_ceres_wdmycloud-nas-dead.md) — why this is
now urgent, and the state the backups were left in.
