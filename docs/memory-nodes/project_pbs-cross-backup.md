---
name: project_pbs-cross-backup
description: "Backup design settled 2026-09-12: a PBS on each of gr-srv03 and the NAS, each backing up the other, no sync jobs, plus a 3-7 day local copy on gr-srv03; guest backups carry no host config and no bind-mounted share data"
metadata:
  node_type: memory
  type: project
  modified: 2026-09-12T00:00:00.000Z
---

**Why it matters:** it decides how every future restore works, and two of its conclusions are
counter-intuitive enough to be re-derived wrongly. **A guest backup contains the guest config and
nothing about the host** — no `interfaces`, no `storage.cfg`, no kernel pin, no firewall — so
"we have PBS backups" is not the same as "we can rebuild gr-srv03". And **bind mounts are never
backed up**, so the NAS's shares and the Immich library are outside PBS entirely no matter how it
is configured. The design is also explicitly optimised for a simple restore, not for efficiency:
local-first + sync was evaluated and **rejected**.

**How to apply:**

- Each host backs up **to the peer's PBS**, plus a 3–7 day local copy on gr-srv03's
  `backup_usb1`. Do **not** propose sync jobs, remotes or namespaces to "improve" this — the
  extra machinery was the reason the alternative lost.
- Any "is X backed up?" question must be answered against **both** PBS *and* the restic /
  BACKUP_A/B side. PBS restores machines; restic restores the photos and shares.
- Host config needs its own `proxmox-backup-client` job. Keep `host-backup/backup-config.sh`
  running until a PBS host backup has actually been restored from at least once.
- Before the first backup runs, settle the **encryption key** and store the API token and PBS
  TLS fingerprint somewhere neither box hosts — see [[project_nas-service-placement-rules]].
- `backup_usb1` is a **Kingston XS1000 SSD**, permanently connected, and was never part of the
  BACKUP_A/B hot-plug trouble — do not object to a chunk store on it, and do not trust
  `lsblk -o ROTA` about it. See [[project_gr-srv03_powered-hub-instability]].
- The design is **not built** — the NAS does not exist. Open items, including PBS-on-host vs
  PBS-in-LXC and a mandatory restore test at commissioning, are in §8.

Detail: `docs/2026-09-12_nas-gr-srv03_pbs-cross-backup-design.md`.
Related: [[project_nas]], [[project_nas-service-placement-rules]], [[project_backup_schedule]],
[[project_backup_a_rotation_check]], [[project_docker03_decommission]].
