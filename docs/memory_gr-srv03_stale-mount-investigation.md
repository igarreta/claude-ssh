---
name: project_gr-srv03_stale-mount-investigation
description: gr-srv03 ceres bind mount goes stale nightly since 2026-07-10 — root cause found 2026-07-14, is inherent LXC bind-mount propagation behavior, not a bug
metadata:
  type: project
---

## Recurring stale ceres bind mount — ROOT CAUSE FOUND (2026-07-14)

`check-ceres-mount-sync.sh` (cron `20 2 * * *` on gr-srv03) detected the
backup_a/backup_b bind mount as stale/empty inside ceres (CT 203) every night
from **2026-07-10 to 07-13**, self-healed by `remount-backup.sh`, which
stops/starts the `mnt-backup_X.mount` unit and then **reboots ceres**
(`pct reboot 203`).

**Root cause:** ceres's LXC config binds these paths with raw
`lxc.mount.entry` lines using `slave` propagation:
```
lxc.mount.entry: /mnt/backup_a mnt/backup_a none bind,create=dir,slave 0 0
lxc.mount.entry: /mnt/backup_b mnt/backup_b none bind,create=dir,slave 0 0
```
Host `/` is `shared` propagation. The daily hot-swap cycle
(`pre-swap-unmount.sh` unmounts backup_a/b on the host at 15:00 for a
18:00–22:00 physical swap window; cron remounts host-side at 00:30) unmounts
and **fully remounts** the underlying filesystem each night. Mount
propagation correctly propagates the 15:00 **unmount** into ceres (destroying
its bind mount), but propagation only follows *existing* mount objects — it
cannot resurrect a bind mount that's already been torn down. So the 00:30
remount creates a brand-new mount object on the host that ceres has nothing
left to receive it into; ceres just sees an empty local directory until
02:20's check. This is why `pct reboot 203` "fixes" it: LXC only
re-evaluates `lxc.mount.entry` bind mounts at container start, so a reboot is
the only way to re-establish the bind under this config — not a workaround
masking a bug, but the correct remediation for this architecture.

**Real fix (not yet implemented):** would require changing the architecture,
e.g. serving backup_a/b to ceres over NFS or 9p instead of a raw LXC bind
mount, so ceres could pick up a fresh mount without a full container restart.
Not undertaken as of 2026-07-14 — current nightly detect+reboot self-heal is
considered acceptable.

**Status:** on 2026-07-13 the Pushover notifications for both the detection
(`check-ceres-mount-sync.sh`) and the remount success (`remount-backup.sh`) were
removed (routine/success events, not actionable per [[feedback_pushover_errors_only]]).
Check `/var/log/proxmox-backup.log` on gr-srv03 directly to see if it's still
happening (rather than relying on notifications).

## Related: 2026-07-13 physical USB disconnect (separate issue) — CORRECTED 2026-07-15

On 2026-07-14, `check-ceres-mount-sync.sh` logged a *different* symptom:
`backup_a: not mounted on host, skipping` (neither backup_a nor backup_b
present on host at all — `lsblk`/`lsusb` showed no WD drive). Root cause: a
real USB disconnect at **2026-07-13 21:28:46**, inside the designed
15:00–22:00 swap window, after which no drive was reconnected before the
00:30 remount cron ran — both `mnt-backup_a.mount` and `mnt-backup_b.mount`
timed out waiting for their device (`Dependency failed`).

**Correction:** only one of BACKUP_A/BACKUP_B is ever physically connected at
a time — the other is always stored offsite (see CLAUDE.md). So *one* unit
being unmounted is normal by design, not a fault; only worth investigating if
**neither** is present past the swap window. Do not assume "drive needs
reconnecting" without first checking which drive is supposed to be onsite that
week. Also see [[project_gr-srv03_powered-hub-instability]] — the powered hub
these drives connect through was independently found to be unreliable on
2026-07-15.

## Related: BACKUP_A journal aborts during 2026-07-12 power outage

Same physical drive (UUID `ef8a4442-68a6-485c-992c-9fd79b183201`, BACKUP_A)
had its ext4 journal aborted twice around the outage (11:36 and 11:48 on
07-12), re-enumerating from `/dev/sdd` to `/dev/sdc` in between. Both times
ext4 replayed the journal cleanly on remount ("recovery complete"), and the
next morning's automatic `e2scrub` (03:10) found nothing. Not urgent, but a
full offline `fsck` on it at the next swap window would be a reasonable
sanity check since it was written to during an actual power loss. See
`docs/2026-07-12_comet_tailscale-logout-power-outage.md` for the outage
root cause.
