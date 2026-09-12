---
name: project_igarreta-bin_shared-repo-hazard
description: igarreta/bin (~/bin on raspberrypi1, contabo2, mosquitto, zigbee2mqtt, cygnus, comet, ...) is one shared git repo — a host-specific script committed on one host can silently break every other host on pull
metadata:
  type: project
---

`~/bin` on raspberrypi1, contabo2, mosquitto, zigbee2mqtt, cygnus, castor, comet and
raspberrypi2z is the same checkout of
`github.com/igarreta/bin`, not per-host copies. A script that must differ by
host (e.g. `backup.sh`: raspberrypi1 uses a local NFS mount, contabo2 uses
rclone/SFTP over WAN) needs to branch on `$HOSTNAME` inside one file —
committing a host-specific rewrite as if it were the only truth clobbers the
other host's copy on its next `git pull`. This already happened once: a
2026-09-06 commit meant for contabo2 broke raspberrypi1's 09-07 backup cron.
See [[project_backup_schedule]] and
docs/2026-09-07_raspberrypi1-contabo2_backup-sh-merge.md for the incident
and the fix (merged, hostname-branched `backup.sh`).

**It recurred one commit later.** The 09-07 merge branched on
`$HOSTNAME == raspberrypi1`, so every *other* host fell into contabo2's
SFTP path. mosquitto pulled it and its 2026-09-12 02:07 run died on
"Cannot reach backup destination via SFTP" using a key only contabo2 has.
Fixed in `efbb33c` with a single `BACKUP_MODE` (`contabo2 → sftp`,
`* → mount`) — see
docs/2026-09-12_ct206_zigbee2mqtt-backup.md.

**How to apply:** before committing any change to a script under this
`~/bin` repo, check whether the script's behavior needs to differ by host —
if so, **branch on the exception and let the default be the common case**.
Testing `$HOSTNAME` against *the one odd host* is the safe shape; testing it
against *one normal host* and putting the odd path in the `else` is the shape
that broke this twice. Never assume the committing host's version is
universal. **Versions have drifted**: cygnus and ceres still run the
pre-merge `backup.sh`; check `git log --oneline -1` in `~/bin` on a host
before reasoning about what it actually runs. raspberrypi2z's checkout is stale
(commit `cffca02`) and not cron-driven there; don't assume its presence
means raspberrypi2z uses these scripts.
