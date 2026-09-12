# zigbee2mqtt (CT206): independent nightly backup of the Zigbee network state

**Status:** active
**Host:** zigbee2mqtt (CT206), ceres, mosquitto, gr-srv03
**Supersedes:** —
**Superseded-by:** —

## Why

zigbee2mqtt holds the only copy of things that cannot be regenerated: the Zigbee
**network key**, the PAN ID / ext-PAN ID / channel, the device registry, and the
coordinator NVRAM backup. Lose them and every device has to be re-paired by hand.

Before 2026-09-12 the only copy was the **weekly whole-container `vzdump`**
(`/etc/pve/jobs.cfg`, Mon 04:00 → `/mnt/backup_usb1/vm-containers`,
`keep-monthly=2,keep-weekly=4`). That is: RPO up to 7 days, one local USB disk, **no
offsite copy**, and restoring a 13 KB `database.db` means unpacking a ~700 MB archive.
z2m's own `coordinator_backup.json` is not a backup — it is written into the same
directory as everything else, on the same disk.

Everything needed was already provisioned and unused: CT206 had the CT901-template
`~/bak` (empty), `~/etc/backup.key` → `/mnt/secrets/backup.key`, and the bind mount
`mp1: /mnt/backup_usb1/zigbee2mqtt,mp=/mnt/backup` — with **both sides empty**. So this
is not a new mechanism, it is the fleet-standard chain finally wired up for CT206.

## The chain

```
02:00  CT206  z2m-backup.timer → /opt/z2m-backup/z2m-backup-stage.sh   (root)
              /opt/zigbee2mqtt/data/{5 files} → validate → gpg
              → ~/bak/zigbee2mqtt-data.tar.gz.gpg          (rsi, 0600, ~6 KB)

02:07  CT206  ~/bin/backup.sh  (rsi, cron)
              ~/bak/ + gpg(~/etc/) → /mnt/backup/backup_<ts>/   (keeps 10)
              = /mnt/backup_usb1/zigbee2mqtt/ on gr-srv03

03:00  ceres  backup-usb1-local.sh, tag `zigbee2mqtt`
              → restic → BACKUP_A/B   (keep-daily 7, weekly 4, monthly 12)

08:00  comet  log-monitor → backup-health.sh: freshness + drift on the tag
```

Both of the 02:00/02:07 targets are on **backup_usb1** (Kingston XS1000 SSD, always
mounted). Neither touches BACKUP_A/B, so **no `wake-backup-disks.sh` entry is needed**
and the 02:25–03:30 disk-wake window in [memory_backup_schedule.md](memory_backup_schedule.md)
is not engaged.

## What is backed up

Five files out of `/opt/zigbee2mqtt/data/`:

| File | Mode | Why |
|---|---|---|
| `configuration.yaml` | 0600 | network key, PAN/ext-PAN, channel, MQTT credentials, device & group definitions (they are inline — there is no `devices.yaml`/`groups.yaml`/`secret.yaml` on this install) |
| `database.db` | 0644 | device registry, newline-delimited JSON |
| `state.json` | 0600 | last known state per device |
| `coordinator_backup.json` | 0644 | coordinator NVRAM dump z2m writes itself |
| `ca.crt` | 0644 | mosquitto CA the MQTT TLS connection needs |

**Deliberately excluded:** `log/` (the whole 24 MB of the data dir is logs, rotated at
~22 h — worthless a day later), `configuration.example.yaml` (upstream sample), and
`/opt/zigbee-lqi/data` (RF research CSVs — not network state; if those are worth keeping
they need their own job).

Whole payload: **~6 KB encrypted.**

## Two design choices worth knowing

**Encrypted, because `~/bak` is shipped in cleartext.** `backup.sh` gpg-encrypts `~/etc`
but copies `~/bak` as-is. `configuration.yaml` carries the MQTT password and
`advanced.network_key` in cleartext and `coordinator_backup.json` carries the network key,
so the encryption has to happen in the staging script:
`tar cz | gpg -c --cipher-algo AES256 --passphrase-file /mnt/secrets/backup.key`.
Same key as every other host's `etc.tar.gz.gpg`.

**Consistent without stopping z2m.** `database.db` and `state.json` are rewritten by a
live z2m (both had mtime = now during investigation), so a plain `cp` can catch a torn
write. Instead of a nightly service stop, the script copies and then *checks what it got*:
every line of `database.db` must parse as JSON and `state.json` must parse. On failure it
retries up to 3× at 3 s, and if it still cannot get a clean copy it **leaves the previous
archive untouched**, logs, and fires Pushover. Verified live 2026-09-12 against a
deliberately truncated `database.db`: 3 retries, refusal, archive md5 unchanged, exit 1.

Rejected: z2m's MQTT `bridge/request/backup` (supported in 2.12.0). It returns a base64
zip and would need an MQTT client, TLS and broker credentials on CT206 — complexity with
no gain over validate-and-retry for 20 KB of files.

**Fixed filename, not dated.** `~/bak/zigbee2mqtt-data.tar.gz.gpg` is overwritten nightly,
the same pattern contabo2 uses for `uptime-kuma.tar.gz`. Generations come from
`backup.sh`'s 10 timestamped `/mnt/backup/backup_<ts>/` directories and then from restic —
not from `~/bak`.

## Restore

Everything below is on CT206 as root. The archive preserves original ownership and modes,
so a plain `tar x` as root puts the files back exactly as they were.

```bash
# 1. Pick a generation. Newest first:
ls -1t /mnt/backup/               # 10 most recent, or from ceres:
                                  # restic -r /mnt/backup_a/restic-repo snapshots --tag zigbee2mqtt
ARCH=/mnt/backup/backup_<ts>/bak/zigbee2mqtt-data.tar.gz.gpg

# 2. Unpack to a scratch dir first — never straight over live data.
T=$(mktemp -d)
gpg -d --batch --passphrase-file /mnt/secrets/backup.key "$ARCH" | tar xz -C "$T"
ls -la "$T"                       # expect the 5 files above

# 3. Sanity-check before committing to it.
python3 -c 'import json,sys;[json.loads(l) for l in open(sys.argv[1]) if l.strip()]' "$T/database.db"
grep -E 'network_key|pan_id|channel' "$T/configuration.yaml"

# 4. Stop z2m, restore, start.
systemctl stop zigbee2mqtt
cp -a /opt/zigbee2mqtt/data /opt/zigbee2mqtt/data.before-restore-$(date +%F)
cp -p "$T"/* /opt/zigbee2mqtt/data/
chown zigbee2mqtt:zigbee2mqtt /opt/zigbee2mqtt/data/*
chmod 600 /opt/zigbee2mqtt/data/configuration.yaml /opt/zigbee2mqtt/data/state.json
systemctl start zigbee2mqtt
journalctl -u zigbee2mqtt -n 40 --no-pager
```

If the coordinator itself was replaced, z2m restores the network from
`coordinator_backup.json` on first start — the network key and PAN must match or devices
will not rejoin.

Restoring from BACKUP_A/B instead: on ceres,
`restic -r $BACKUP_MOUNT/restic-repo restore <id> --target /tmp/r --include '*/zigbee2mqtt/*'`,
then copy the `bak/zigbee2mqtt-data.tar.gz.gpg` across and continue from step 2.
`/mnt/secrets/backup.key` is required either way — it is on gr-srv03 in
`/opt/shared-secrets`, and the recovery copy is in Notion.

## Two adjacent faults found and fixed the same day

**1. mosquitto's nightly backup was broken.** `~/bin` is one shared `igarreta/bin`
checkout across hosts. The 2026-09-07 merge
([2026-09-07_raspberrypi1-contabo2_backup-sh-merge.md](2026-09-07_raspberrypi1-contabo2_backup-sh-merge.md))
selected the transport with `if [[ $HOSTNAME == raspberrypi1 ]] … else <contabo2 SFTP>`,
so **every other host** fell into contabo2's WAN path. mosquitto pulled it and its
2026-09-12 02:07 run died:

```
2026-09-12 02:07:01 - ERROR: Cannot reach backup destination via SFTP (gr-srv03)
```

— using a key that exists only on contabo2, while mosquitto has a perfectly good bind
mount at `/mnt/backup`. This is the same shared-repo hazard recurring one commit later.

Fixed in `igarreta/bin` commit `efbb33c`: a single `BACKUP_MODE` set once at the top,
`contabo2 → sftp`, `* → mount`. **Branch on the exception, default to the common case** —
adding a host now needs no edit. Pulled and verified on mosquitto, raspberrypi1 (no
behaviour change) and CT206. cygnus and ceres still run the pre-merge version and work;
that drift is untouched here.

**2. `/mnt/backup_usb1/mosquitto` was in no restic tag.** CT105 has deposited there every
night since it was built, and `backup-usb1-local.sh`'s `containers` tag never listed it —
so none of it ever reached BACKUP_A/B. Added.

That path addition forces `--group-by host,tags` on the `containers` `forget`: restic
groups by `host,paths` by default, so a changed path list splits the snapshots into two
groups and the **old group stops ageing out** — it would freeze its retained set (~6 GiB)
forever instead of rolling. Grouping by tag keeps both path sets under one policy. Safe
because every `containers` snapshot is written by that one script, on that one host, with
exactly that tag.

Note separately, not fixed here: mosquitto's `etc.tar.gz.gpg` is **351 bytes** — `~/etc`
there is all symlinks into `/mnt/secrets`. The broker's real config
(`/etc/mosquitto/`, the password and ACL files, the CA) is **not** in its `~/bak` deposit.
Worth its own pass.

## Files

| Where | What |
|---|---|
| `ct206/z2m-backup/` (this repo) | `z2m-backup-stage.sh`, `z2m-backup.service`, `z2m-backup.timer`, `install.sh` |
| CT206 `/opt/z2m-backup/` | deployed staging script |
| CT206 `/etc/systemd/system/z2m-backup.{service,timer}` | 02:00 daily, `Persistent=true` |
| CT206 `crontab -u rsi` | `7 2 * * * /home/rsi/bin/backup.sh` |
| `igarreta/bin` `backup.sh` | `BACKUP_MODE` transport selection (`efbb33c`) |
| ceres `~/backup_greven/scripts/backup-usb1-local.sh` | `zigbee2mqtt` tag, mosquitto path, `--group-by host,tags` (`52d21da`) |
| `log-monitor/backup-health.sh` | `zigbee2mqtt` in `TAGS_LOCAL_JSON` |

CT206 has **no MCP connector**. Reach it with `ssh -i ~/.ssh/id_ed25519_comet rsi@10.0.100.12`,
or `pct exec 206 -- …` from gr-srv03 for root work (its sudo needs a password).

## Open

- **Raise the `zigbee2mqtt` floor from 4096 to ~40000 bytes after 2026-09-22**, once
  `backup.sh`'s 10 generations have accumulated (day 1 is ~6 KB, steady state ~60 KB).
  4096 is only the empty-directory tripwire.
- First restic run lands on the **2026-09-13 03:00** cycle — no backup disk was mounted
  when this was built (they unmount at 15:00, remount at 00:30), so the restic leg is
  verified from that run, not from the build.
