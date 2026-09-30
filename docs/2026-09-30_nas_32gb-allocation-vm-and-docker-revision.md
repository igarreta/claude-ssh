# NAS — 32 GB revision: VMs allowed, RAM allocation, cygnus as a Docker VM

**Status:** open
**Host:** (project)
**Supersedes:** 2026-09-07_nas-software-stack.md (§ *Decided: everything is an LXC, no VMs* — narrowed; and the fleet-wide scope of § *Immich runs under podman, no Docker in the fleet*), 2026-09-08_nas-chassis-decision-and-acceptance-test.md (§ 2's RAM allocation table only), 2026-09-10_nas-chassis-price-correction-f4-424-pro.md (§ 4's "all LXCs and no VMs" and "do not re-plan the allocation" only)
**Superseded-by:** —

**Date**: 2026-09-30. Three decisions taken at 8–16 GB were reviewed against the 32 GB of the
F4-424 Pro. Nothing is bought or built; the figures below are **starting values for the build**,
to be tuned against real usage after the restore.

## 1. "All LXCs, no VMs" is narrowed, not dropped

The 09-07 doc gave two reasons, each called sufficient. Only the RAM one is gone.

**New rule: guests that touch the pool or the iGPU are LXCs. VMs are allowed for self-contained
guests.**

What still forces LXC for `smb` and `immich`, independent of RAM:

- **Shared data.** Samba writes the tree Immich reads; an LXC bind mount gives both the same files
  through one cache (ARC). The VM alternative is virtiofs, which the 09-07 doc did not consider.
  It is worse here: a second cache in the guest, and host-side changes are not expected to raise
  inotify events in the guest, which Immich's library watching needs. *(Verified 2026-09-30 from
  upstream, not tested here: virtiofsd issue #203 "Inotify support" states it is unsupported and
  that the 2021 kernel RFC "Inotify support in FUSE and virtiofs" was never merged.)*
- **iGPU.** `/dev/dri` into an LXC is a device entry; into a VM it is whole-device passthrough and
  the host loses it.
- **`idmap=passthrough`** is an LXC mount option; the Samba decision depends on it.

PBS is unaffected: its VM option was rejected on datastore grounds (zvol or NFS), and the
[09-12 design](2026-09-12_nas-gr-srv03_pbs-cross-backup-design.md) recommends the PVE host anyway.

What a VM is now for:

1. **The cygnus + Docker VM** (§3).
2. **Emergency restore of Home Assistant (VM 104)** from PBS if gr-srv03 dies. The blanket rule
   would have forbidden it for no remaining reason.

## 2. RAM allocation at 32 GB

About 31 GB is usable after the iGPU's share.

| | 16 GB plan (09-08) | **32 GB plan** | Why |
|---|---|---|---|
| PVE host + kernel | 1.0 GB | **1.5 GB** | |
| PBS | 2.0 GB (LXC) | **1.5 GB** (on host) | Follows the 09-12 recommendation, not yet ratified; as an LXC, cap it at 2 GB |
| ZFS ARC (`zfs_arc_max`) | 4.0 GB | **8 GB**, `zfs_arc_min` 2 GB | Data is read-cold, so this buys metadata caching: SMB directory walks, PBS GC/verify, restic chunk lookups |
| `smb` LXC | 0.75 GB | **1 GB** | File cache for bind-mounted datasets lives in ARC, not in the container |
| `immich` LXC | 6.0 GB | **8 GB** | Postgres `shared_buffers` 512 MB → 1–2 GB; more concurrent thumbnail/transcode/ML jobs on 8 cores |
| cygnus + Docker VM | — | **6 GB** | §3 |
| **Allocated** | 13.75 GB | **26 GB** | |
| **Headroom** | ~2.25 GB | **~5 GB** | |

- **Caps versus real consumers.** LXC figures are cgroup limits, not reservations. ARC and a
  running VM are the only items that actually hold RAM.
- **The Home Assistant emergency VM has no standing reservation.** It comes out of the headroom;
  if more is needed, `zfs_arc_max` can be lowered at runtime.
- **ARC must be set explicitly** in `/etc/modprobe.d/zfs.conf`. The 09-08 doc's "ZFS defaults
  to half of RAM" is **wrong for this generation**. Measured on gr-srv03 2026-09-30 (ZFS
  2.4.4-pve1, `zfs_arc_max=0`, no `zfs.conf`): `c_max` = 11,202,084,864 against `MemTotal`
  12,275,826,688 — **all RAM minus exactly 1 GiB**. On the NAS the default would be ~30 GB and
  would collide with every guest.
- **Why 8 GB and not more.** One SODIMM slot, 32 GB is the ceiling, and Linux ARC shrinks slowly
  under sudden pressure. Raise it after the restore if `arc_summary` hit rates justify it; raising
  is the safe direction.

## 3. cygnus moves to the NAS as a VM running Docker

**Decided (user, 2026-09-30):** a future VM on the NAS takes over cygnus's workloads and hosts
secondary Docker containers. **Not scheduled.**

Sizing, measured on cygnus (CT 202) 2026-09-30: capped at 2 GB / 2 cores, ~0.4 GB resident plus
~0.4 GB swapped across 8 containers (`data-ingestion-api`, `pgadmin`, `servidor_quetren`,
`grafana`, `tuya-link`, `uptime-kuma`, `mqtt-explorer`, `beszel-agent`). A VM adds its own kernel
and page cache, so ~2 GB covers today's load and ~4 GB is left for secondary containers → **6 GB**.

Open, to settle before the move:

- **Events API (`data-ingestion-api`) and caddy are to be dealt with later and may stay on
  gr-srv03.** This keeps the constraint in
  [2026-09-11_nas-gr-srv03_service-placement-rules.md](2026-09-11_nas-gr-srv03_service-placement-rules.md):
  HA posts to the events API with no retry, and access routes must work with either server down.
- **cygnus's bind mounts from gr-srv03** (the backup tree, `quetren` recordings) have not been
  checked for a NAS equivalent.
- Moving cygnus frees its 2 GB on gr-srv03, which has no headroom.

## 4. Docker: allowed in VMs, podman stays in LXCs

The "podman, no Docker in the fleet" rule existed because Docker inside an LXC was not
recommended. **New rule: Docker only inside VMs; inside an LXC, use podman.**

- **The new VM runs Docker** with Compose v2: the upstream-supported setup, and free of the
  podman-compose traps already paid for (`podman-restart` filter missing `unless-stopped`,
  `extends: file:` resolving against the CWD, misleading `config` output).
- **Immich stays on podman in its LXC.** It must be an LXC (§1), Docker-in-LXC is still the
  unsupported combination, and the podman setup was verified feature by feature on 09-07.
- **Cost:** two runtimes. Once cygnus's containers move, podman's footprint is the Immich LXC only.

## Related

[2026-09-07_nas-software-stack.md](2026-09-07_nas-software-stack.md) — stack; everything outside
the sections named above remains current.
[2026-09-08_nas-chassis-decision-and-acceptance-test.md](2026-09-08_nas-chassis-decision-and-acceptance-test.md)
— the 16 GB budget this replaces, and the Immich per-service breakdown, which still applies.
[2026-09-11_nas-gr-srv03_service-placement-rules.md](2026-09-11_nas-gr-srv03_service-placement-rules.md)
— placement rulebook.
