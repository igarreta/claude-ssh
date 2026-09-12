# PBS cross-backup — two servers, each backing up the other

**Status:** open
**Host:** gr-srv03, NAS (F4-424 Pro, not yet purchased)
**Supersedes:** 2026-08-19_nas-hardware-research.md (§6 *PBS placement* only), 2026-09-07_nas-software-stack.md (the `pbs` LXC row of § *Guests* only)
**Superseded-by:** —

**Date**: 2026-09-12. Design conversation. **Nothing is built** — the NAS does not exist yet.
This extends the placement rulebook
([2026-09-11_nas-gr-srv03_service-placement-rules.md](2026-09-11_nas-gr-srv03_service-placement-rules.md)),
which assigned PBS to the NAS. There is now a PBS on **both** hosts.

## 1. The premise, stated so the design can be judged against it

> **One server dies. The other is alive, with its PBS running.**

The goal is **a restore path with no surprises**, not storage efficiency and not maximal
history. Every trade below is resolved in favour of "fewer moving parts at 2 a.m. with a dead
box in front of you".

This is the same asymmetry the one-week rule comes from: gr-srv03 dying is recoverable because
PBS lives on the NAS; the NAS dying is the harder case, and the design must not make it harder
still.

## 2. The design

```
gr-srv03 (PVE) ──guest backups──────────────►  PBS on NAS       (datastore on tank/pbs)
gr-srv03 host  ──proxmox-backup-client──────►  PBS on NAS
gr-srv03 (PVE) ──guest backups, 3–7 days────►  PBS on gr-srv03  (datastore "local-short")

NAS (PVE)      ──guest backups──────────────►  PBS on gr-srv03  (datastore "nas-backups")
NAS host       ──proxmox-backup-client──────►  PBS on gr-srv03
```

**No sync jobs, no remotes, no namespaces, no push permissions.** Each PBS holds only the
peer's data plus, on gr-srv03, a short-retention copy of its own guests. Recovery never
involves importing a datastore, re-pointing a remote, or untangling ownership.

Three independent backup jobs, three retention policies, nothing shared between them.

### Why not local-first + sync (rejected 2026-09-12)

The obvious alternative — back up locally, then sync the datastore to the peer — was rejected
on recovery complexity, at the user's call. Sync in **push** direction is the one Proxmox
itself warns about: the target's ownership is fixed by the remote config, not the local user,
and every push job wants its own dedicated remote user or jobs prune each other's snapshots.
Pull is safer but means the *surviving* box must be configured to reach into the dead one.
Either way it adds remotes, credentials, namespaces and a schedule to a path that only ever
runs when something is already wrong.

The cross-target design gets the same off-box copy with none of that machinery.

### Why the local short-retention copy exists

Cross-target *alone* has one sharp edge: **the death of either box also destroys the other's
entire backup history.** If the NAS dies, gr-srv03 — the box running the heating — has no
backups at all until the NAS is rebuilt, which the project already assumes could be weeks.

The fix is deliberately *not* a sync job: a second, independent backup job from gr-srv03 to a
local datastore on `backup_usb1`, 3–7 days retention. Two storage entries, two schedules,
recovery unchanged. It is no more than gr-srv03 already does today with vzdump to the same
disk.

There is no matching local copy on the NAS: its guests are small and its data is protected
separately (§5), so the same gap there is not worth a second datastore on the same pool.

## 3. Where PBS runs: on the PVE host, both sides

**Recommendation** (see §8 — not yet ratified): `apt install proxmox-backup-server` on each PVE
host, datastore as a plain directory. Not an LXC.

| | Host install | LXC |
|---|---|---|
| Available when? | **as soon as the host boots** | after `local-lvm` is healthy *and* the guest starts |
| RAM | 0 (shares the host) | 1–1.5 GB |
| Datastore | plain directory on the pool / SSD | bind mount + `idmap` |
| Support status | documented by Proxmox | community practice |
| Cost | PVE and PBS major versions must move together; host mixes roles | separation |

The deciding argument is the first row. The survivor's PBS is the thing you need working at
the exact moment the other box is gone; in an LXC it depends on a guest whose rootfs sits on
the storage you may also be repairing.

> **This revives a fallback the NAS thread had declared dead.** That line
> ([2026-09-07_nas-software-stack.md](2026-09-07_nas-software-stack.md) § *Decided: everything
> is an LXC*) killed the host install because at 8 GB the argument was about RAM, and at 32 GB
> RAM stopped being scarce. **This is not a RAM decision** — it is a recovery-availability one,
> and it is unaffected by the chassis change. The all-LXC decision stands for `smb` and
> `immich`, which need the bind mounts it was made for; PBS is the one guest whose datastore
> works just as well as a host directory.

The rest of the design is unaffected by this choice: if PBS ends up in an LXC on either side,
everything else in this doc still holds.

## 4. What each datastore holds, and how big

| Datastore | Host | Media | Holds | Retention |
|---|---|---|---|---|
| `tank/pbs` | NAS | ZFS mirror, 6 TB HDD | gr-srv03 guests + gr-srv03 host config | full history |
| `nas-backups` | gr-srv03 | `/mnt/backup_usb1` | NAS guests + NAS host config | full history |
| `local-short` | gr-srv03 | `/mnt/backup_usb1` | gr-srv03's own guests | **3–7 days** |

Separate datastores rather than namespaces: retention differs sharply, and dedup would not
cross the sources anyway.

Sizing, measured 2026-09-12:

- `/mnt/backup_usb1` — 916 G, 280 G used, **590 G free**. It absorbs both gr-srv03 datastores
  comfortably; today's 171 GB `vm-containers` vzdump directory is replaced by dedup'd chunks
  and should shrink while holding more history.
- gr-srv03's guests: `local-lvm` is ~55% of 157 GiB ≈ 86 GiB allocated, less after the VM 102
  decommission.
- **The NAS's guests are tiny** — `smb`, `immich` and (if it stays a guest) `pbs`. Bind mounts
  are never backed up by vzdump/PBS, so `tank/shares` and the Immich library are excluded by
  construction. Expect tens of GB, not terabytes. The capacity asymmetry between the two boxes
  is therefore irrelevant to this design.

### `backup_usb1` is an SSD, and is not part of the rotation

Recorded because it was misremembered during this design discussion, and it is the fact that
makes a chunk store on it acceptable:

- **Kingston XS1000, 1 TB external USB SSD** (`smartctl`: `Rotation Rate: Solid State Device`,
  TRIM available), permanently connected, `fstab` with `nofail`. It has never been a source of
  trouble.
- `lsblk -o ROTA` reports `1` for it — **the USB bridge hides the rotation flag**. Do not use
  `lsblk` to decide whether this disk is an SSD; use `smartctl -i`.
- The USB hot-plug instability on this host is **BACKUP_A/B** only — the weekly rotation drives
  on the shared 5 V rail
  ([memory_gr-srv03_powered-hub-instability.md](memory_gr-srv03_powered-hub-instability.md)).
  `backup_usb1` is not hot-plugged and is not implicated. Those drives move to the NAS anyway.

A PBS chunk store is fsync- and latency-sensitive, which is exactly why the NFS-backed
datastore was rejected in the first place; a directly attached SSD is the good case, not the
compromise.

## 5. Host configuration is **not** in a guest backup

The second question this design had to settle. A PBS/vzdump guest backup contains the guest
config — and nothing about the host.

**Included**, inside the archive (`./etc/vzdump/`), restored automatically with the guest:
`qemu-server.conf` / `pct.conf` — CPU, RAM, disks, **network interface definitions** (bridge,
VLAN, MAC), mount-point directives, and USB/device passthrough lines. CT 206's Zigbee `by-id`
entry and CT 207's `/dev/bus/usb` bind mount survive a restore.

**Not included** — all host-level, all needed to rebuild gr-srv03:

- `/etc/network/interfaces` — vmbr0 and **vmbr1 (10.0.100.0/24)**
- `storage.cfg`, `datacenter.cfg`, `jobs.cfg` (the backup schedules themselves), `user.cfg`,
  API tokens, ACME, notification targets
- cluster/host firewall and per-guest `/etc/pve/firewall/<vmid>.fw` — these live host-side, not
  in the guest archive — plus the **DNAT rule** for HA → cygnus API
- `/etc/fstab`, the BACKUP_A/B udev + systemd mount units
  ([Backup_Drives_Mounting_Configuration.md](Backup_Drives_Mounting_Configuration.md)),
  LVM/ZFS layout
- **`/etc/kernel/proxmox-boot-pin`** — the deliberate 7.0.14-15-pve pin
- everything outside `/etc/pve`: `/opt/proxmox-grsrv03`, crontabs, Tailscale state, SSH keys

**The fix is a `proxmox-backup-client` file-level host backup** of `/etc` (plus `/opt`,
`/root`) from each host into the *peer's* datastore, scheduled like any other job. This is the
supported way to get host config into PBS.

Functionally this is what `host-backup/backup-config.sh` already does into a tarball — the
difference is that PBS makes it deduplicated, versioned, verifiable, and **stored on the other
machine** rather than on a disk attached to the host it protects. Whether to retire the script
once PBS host backups are proven is §8.

## 6. What must survive the loss of either box

The restore prerequisites. All of these are *inputs* to recovery and cannot live only on the
machines being recovered:

1. **Backup encryption key — decide, then protect it.** If backups are encrypted, the key is
   required to restore and the key lives on the machine that just died. Either leave backups
   unencrypted (both hosts are on private hardware, reachable only over Tailscale) or store the
   key in the password manager **and** on paper. The placement rulebook already calls for an
   off-box key; this is where it bites.
2. **Peer credentials**: datastore name, PBS API token, and the **PBS TLS fingerprint**.
3. Where to find this doc and the runbook — i.e. a clone of this repo somewhere neither box
   hosts.

This is the single most common way a homelab cross-backup fails: everything works until the
day it is needed, then the key or the fingerprint was only on the dead host.

## 7. Recovery, in outline

### gr-srv03 dies, NAS alive

1. Reinstall PVE 9 on new/repaired hardware; **re-pin the kernel** before anything else.
2. `apt install proxmox-backup-client`; restore the host backup from the NAS → network
   interfaces (vmbr0 + vmbr1), `storage.cfg`, `fstab`, mount units, boot pin,
   `/opt/proxmox-grsrv03`, the DNAT rule.
3. Add the NAS PBS as storage; `qm restore` / `pct restore` each guest by ID.
4. Re-attach the USB dongles; confirm the `by-id` paths in `206.conf` / `207.conf` still match
   — a replacement dongle has a different serial.
5. Heating first: HA (VM 104), mosquitto (105), z2m (206).

### NAS dies, gr-srv03 alive

1. Reinstall PVE; restore host config from gr-srv03's PBS.
2. `zpool import tank` if the disks survived. Otherwise rebuild the mirror and restore `tank`
   from the BACKUP_A/B restic repos — **not from PBS**.
3. Restore the three guests from gr-srv03's `nas-backups` datastore.

> **PBS restores the machines, not the photos.** `tank/shares` and the Immich library are bind
> mounts and are outside every PBS backup in this design. They remain a restic / BACKUP_A/B
> job, exactly as planned. Any future "is the NAS backed up?" question must be answered against
> *both* systems.

## 8. Open — to settle before or during NAS commissioning

1. **Ratify §3** — PBS on the PVE host vs in an LXC, on each side. Recommendation above; at
   32 GB the LXC is affordable, so this is a recovery-simplicity call, reversible until built.
2. **Retention numbers** for all three datastores; `local-short` proposed at 3–7 days.
3. **Retire `host-backup/backup-config.sh`?** Only after PBS host backups have been restored
   from at least once. Until then, run both.
4. **Verify / GC / prune schedules** on each PBS, and notification wiring — Pushover **on
   failure only**, per the standing rule.
5. **Schedule placement**: new jobs on gr-srv03 must respect the 02:25–03:30 disk-wake window
   ([memory_backup_schedule.md](memory_backup_schedule.md)). Backups *to* the NAS do not touch
   BACKUP_A/B, but jobs landing on `backup_usb1` share the host's I/O with them.
6. **Prerequisite**: VM 102 decommission, for the RAM and to shrink the datastore.
7. **A restore test is part of commissioning.** A cross-backup that has never been restored
   from is a hypothesis. Restore one LXC in each direction before declaring this done.
