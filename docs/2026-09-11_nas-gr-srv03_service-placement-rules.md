# Service placement rules for the two-server fleet (gr-srv03 + NAS)

**Status:** open
**Host:** gr-srv03, NAS (F4-424 Pro, not yet purchased)
**Supersedes:** —
**Superseded-by:** —

**Status detail:** the rules below are decided and are the basis for every service-location
call. The dependency audit they require has **not been run** — it is a commissioning task for
the day the NAS exists. Open items are listed in §7.

Design conversation of 2026-09-11, once the chassis was settled
([2026-09-10_nas-chassis-price-correction-f4-424-pro.md](2026-09-10_nas-chassis-price-correction-f4-424-pro.md)).
The question was how to split load between the incoming NAS (i3-N305, 8 cores, 32 GB) and
gr-srv03 (N97, 12 GB), given the NAS will be the more powerful machine.

## 1. The one-week rule

> **No service that cannot tolerate one week of downtime may be hosted on the NAS.**

The user's rule, and the basis for every placement decision. It follows from the asymmetry of
the restore paths: if gr-srv03 dies, PBS is alive on the NAS and restore is easy; if the NAS
dies, PBS itself must be rebuilt and the primary datastore may be the thing that was lost.

It has two halves that are easy to conflate:

- **downtime** — the service being unavailable for a week must not hurt.
- **data reachability** — anything on gr-srv03 that *reads or writes* NAS-hosted data
  synchronously fails the rule even if the NAS-side service itself is not critical.

## 2. Split by volatility, not by capacity

The intuitive plan — "the NAS is bigger, so it gets most containers" — is wrong here. The NAS
will have spinning disks, scrubs, resilvers, Immich ML bursts and disk swaps: it is the box
that gets rebooted. gr-srv03 has no disks to swap and nothing to resilver, so it is the more
*available* machine even though it is the weaker one.

| Stays on gr-srv03 | Goes to the NAS |
|---|---|
| Home Assistant (VM 104), mosquitto (105), zigbee2mqtt (206), rtl433 (207), castor/postgres (205), cloudflare ingress (103) | Immich, Samba shares, Time Machine, PBS, media, `tank/backups` |

**The radios stay on gr-srv03** (user's call, 2026-09-11). USB passthrough pins a guest to its
host, so z2m and rtl433 could never have failed over anyway; deciding once where the radios
live decides where the whole automation chain lives.

## 3. No clustering

Proxmox clustering was evaluated and **rejected**. The reasoning, so it is not re-derived:

- **`pvesr` replication is ZFS-only.** gr-srv03 is LVM-thin (`local-lvm`, 55% of 157 GiB) with
  no pool. Enabling replication means rebuilding its storage and restoring every guest, plus
  giving ARC memory on a host already using 3 GB of swap. Replication is also asynchronous
  (1-minute minimum), so a failover is a crash-consistent restore of a stale snapshot.
- **A 2-node cluster has no quorum, and the HA stack self-fences.** A node holding HA resources
  that loses quorum arms its watchdog and reboots after ~60 s. That box runs the heating, so HA
  would add a novel way for the house to go cold to protect against a failure that has never
  happened.
- **Quorum coupling defeats the goal.** With the NAS off — a disk swap, a BIOS update —
  gr-srv03 goes inquorate and `/etc/pve` turns read-only: no starting or stopping guests until
  a manual `pvecm expected 1`, repeated after every reboot while the peer is down. That is
  exactly the "requires my time, on-site" cost the plan exists to avoid.
- **It is near-irreversible.** Joining requires an empty node, and the supported way to leave a
  cluster is to reinstall. It also couples PVE major-version upgrades across both boxes.

**What is given up is small:** one merged UI, and cluster-wide storage definitions (one PBS
storage entry configured twice). Cross-host moves remain available via `qm remote-migrate` /
`pct remote-migrate`, which work between *unrelated* hosts. Fleet-wide visibility already comes
from uptime-kuma and beszel, which cover all ~10 hosts a cluster would never have included.

**If this is ever reconsidered, the deadline is before the NAS has guests** — the joining node
must be empty.

## 4. Dependency direction

> **Dependencies may point NAS → gr-srv03. They may never point gr-srv03 → NAS synchronously.**

The symmetric half matters as much as the obvious one: if NAS guests start depending on
mosquitto or castor, the two boxes become mutually dependent and neither can be restored
independently. NAS → gr-srv03 is acceptable only for paths that fail cleanly and
asynchronously (backup pushes, metric pushes).

Four classes to sweep, worst first:

1. **Mounts** — the dangerous class. An NFS/SMB mount to a dead NAS hangs in uninterruptible
   D-state rather than failing cleanly; it can block unrelated processes and hang shutdown.
   Precedent: [2026-08-17_contabo2_nfs-backup-hang-rclone-migration.md](2026-08-17_contabo2_nfs-backup-hang-rclone-migration.md).
   **No critical guest mounts NAS storage.**
2. **Databases** — see §5.
3. **Ingress** — cloudflare tunnel (CT 103) and caddy on cygnus. A reverse proxy on the NAS
   makes everything behind it inherit the NAS's availability. **Access routes must keep working
   with either server down.**
4. **Push-style, safe** — ceres restic → NAS SFTP, HA backups → NAS, log-monitor, beszel.
   These fail cleanly and retry. This is what the NAS is *for*.

## 5. Databases live with the service that owns them

**castor (CT 205) stays on gr-srv03.** 10 MB of data, ~1 GB of RAM, no performance requirement
the NAS could serve better, and it sits in an automation write path.

**Do not stand up a general-purpose Postgres on the NAS.** Nothing planned would use it: Immich
ships its own bundled Postgres with pinned vector extensions and cannot use a shared server
(already decided in [2026-09-07_nas-software-stack.md](2026-09-07_nas-software-stack.md)); PBS
and Samba use no SQL. Create one when a service needs it, not in anticipation.

### The HA → postgres path, as actually measured 2026-09-11

Worth recording because its *shape* — not its existence — determines the risk, and a first
reading of it was wrong:

```
HA (VM 104) ──POST http://192.168.1.3:8000/homeassistant/events──► gr-srv03 vmbr0
                                                                    │ DNAT (iptables)
                                                                    ▼
                                                   API on cygnus (CT 202, 10.0.100.10:8000)
                                                                    │
                                                                    ▼
                                                   postgres on castor (CT 205, 10.0.100.11:5432)
```

- **HA's recorder is local SQLite** (`/config/home-assistant_v2.db`, 135 MB). There is no
  `recorder:` block and no `db_url` anywhere in `/config`. The Postgres path is a *separate*
  long-term metrics store, not the recorder.
- Target is `homelab.measurements` on castor: 11,877 rows since 2026-06-02, 5 entities,
  `sensor.barrera_cruce_ferroviario_secs` every minute and `sensor.ttato_boiler_secs` hourly.
- The write is a **`rest_command` — fire-and-forget HTTP**, not a database driver. If the
  endpoint is unreachable HA logs an error and the automation continues: **HA does not block,
  does not stall at startup, and the heating is unaffected.**
- The cost of an outage is therefore **silently lost data points** — no queue, no retry, no
  backfill. A week of downtime on the minute-resolution sensor is ~10,000 unrecoverable rows.

**Constraint this creates:** the events API lives on **cygnus**, which is the container
workloads have been consolidating into and an obvious candidate to move to the NAS later. If
cygnus moves, HA's write path silently becomes NAS-dependent and lossy. **The events API must
stay on gr-srv03, or be split out of cygnus before cygnus moves.** Note the endpoint is
hardcoded as `192.168.1.3:8000` in `configuration.yaml` behind the DNAT rule, so a move means
editing HA config too.

If the silent loss ever matters, the fix is buffering, not collocation: HA publishes to
mosquitto (already local and critical-path), a consumer drains it into Postgres and survives DB
outages.

## 6. PBS

**PBS runs on the NAS**, as an LXC with its datastore on `tank/pbs` — unchanged from
[2026-09-07_nas-software-stack.md](2026-09-07_nas-software-stack.md). Load is not a reason to
move it: PBS is idle outside its backup window, GC and verify, and an i3-N305 will not notice a
dozen small guests. Schedule GC/verify clear of the 02:25–03:30 disk-wake window
([memory_backup_schedule.md](memory_backup_schedule.md)).

**PBS on gr-srv03 with a USB datastore was considered and rejected.** The chunk store is
millions of small files and is fsync- and latency-sensitive; USB is the wrong substrate, and on
this host USB hot-plug transients on the shared 5V rail are a documented cause of Zigbee drops
([memory_gr-srv03_powered-hub-instability.md](memory_gr-srv03_powered-hub-instability.md)). gr-srv03 also has
no ZFS and ~3 GB of free RAM. It would not even buy independence: PBS on gr-srv03 backing up
gr-srv03's own guests is the same correlated failure on the other box.

**The correlated-failure problem is solved with two datastores, not two servers.** The NAS holds
`tank/shares`, `tank/pbs` and `tank/backups` together, so a host-root event takes all three.
The answer is a PBS sync job into a removable datastore on the BACKUP_A/B drives, which already
rotate offsite — an offline, off-box copy of the backups without ever making USB the live chunk
store. Verify the removable-datastore feature against the PBS version installed.

**The encryption key is the thing that kills you.** If PBS backup encryption is enabled, the key
must exist **off the NAS** — printed, and/or on gr-srv03. An encrypted offsite copy on
BACKUP_A/B whose only key died with the NAS is not a backup. Decide this **before the first
backup runs**, not after.

**Restoring the NAS does not need a second PBS.** Its guests are tiny (smb, pbs, immich config);
a nightly `vzdump` to gr-srv03's `backup_usb1` covers them for a few GB and no new service.

## 7. Open — to resolve at NAS commissioning

1. **Run the dependency audit** (§4), against the real service list, on the day the NAS is
   commissioned. This is the task this document exists to trigger.
2. **gr-srv03 has no headroom, and the NAS does not create any.** Only samba03 (CT 101)
   actually relocates; Immich, Time Machine and PBS are new services, not moves. gr-srv03 stays
   at 8 GB used of 12 with 3 GB swapped while becoming, by design, the permanent home of
   everything critical. **Decommissioning VM 102 (6 GB allocated, stopped, `onboot: 0`) is what
   pays for this plan** — it is now a prerequisite, not an independent cleanup.
   See [memory_docker03-decommission.md](memory_docker03-decommission.md).
3. **Neither restore path has been rehearsed**, so the one-week rule's RTO is unverified. Two
   distinct drills: restore a gr-srv03 guest from NAS PBS, and rebuild the NAS with the NAS
   unavailable. The second is the hard one.
4. **Shared physical SPOFs.** Both boxes share a power feed and a LAN switch; a switch failure
   also cuts raspberrypi1/TTato from mosquitto, dropping the house to the physical thermostat.
   Whether these are on a UPS is unestablished, and it is a more likely event than a mainboard
   failure.
5. **ceres → BACKUP_A/B once the rotation hangs off the NAS** (open in `INDEX.md`) is now
   decided *in principle* by §4: ceres must not mount NAS storage, so either the NAS pulls or
   restic runs on the NAS. The mechanism still needs designing.

## 8. Fallback behaviour that makes these rules survivable

TTato on raspberrypi1 already degrades safely: with insufficient information it reverts to the
physical thermostat — poor regulation (it is why this system was built) but the house stays
warm. That fallback is what makes a ~10-minute restore acceptable instead of requiring
automatic failover, and it should not be removed without revisiting §3.
