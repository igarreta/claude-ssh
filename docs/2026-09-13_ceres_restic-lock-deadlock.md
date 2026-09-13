# ceres — three nightly backups lost to a permanently "3h old" restic lock

**Status:** closed
**Host:** ceres, gr-srv03
**Supersedes:** —
**Superseded-by:** —

## Summary

`backup-usb1-local.sh` failed on 2026-09-11, 09-12 and 09-13 with
`ERROR: Repo locked by recent process (3h)` — the same age every night. A stale restic
lock left in `/mnt/backup_a/restic-repo` on **2026-09-10 14:58:59** was never cleared,
because the script's staleness check computed the lock's age wrongly: it always returned
"hours since midnight", which at the 03:00 cron is permanently `3` and therefore never
reaches the 6 h threshold.

The check had **never worked** since it was written. It only became visible when a lock
first survived long enough to matter.

Last good run before the outage: **2026-09-10**. Backup re-run manually 2026-09-13 19:00.

## The bug

`backup-usb1-local.sh:114` (pre-fix):

```bash
lock_json=$(restic cat lock "$lock_id" -r "$RESTIC_REPOSITORY" 2>/dev/null)
lock_time=$(echo "$lock_json" | grep -o "\"time\":\"[^\"]*\"" | cut -d"\"" -f4)
lock_epoch=$(date -d "$lock_time" +%s 2>/dev/null)
age_hours=$(( (now_epoch - lock_epoch) / 3600 ))
```

Two things combine:

1. **`restic cat lock` pretty-prints its JSON**, with a space after the colon:

   ```json
   {
     "time": "2026-09-10T14:58:59.177324474-03:00",
     "exclusive": false,
     "hostname": "ceres",
     "username": "rsi",
     "pid": 34352,
   ```

   The pattern `"time":"[^"]*"` has **no space** and never matches, so `lock_time` is empty.
   (`restic snapshots --json` *is* compact — which is why the same pattern in the
   `status-*.sh` scripts works fine and this went unnoticed.)

2. **GNU `date -d ""` does not fail.** It returns **today at 00:00:00**:

   ```
   $ date -d "" +%s
   1789268400          # Sun Sep 13 00:00:00 -03 2026
   ```

   So `age_hours` is really *hours since local midnight*. The `2>/dev/null` and the
   missing empty-string guard hid it completely.

At the 03:00 cron that is always `3`. `3 -ge 6` is false → `exit 1`, every night, forever.
The failure mode is the worst possible ordering: the bogus age is **smallest exactly during
the window the cron runs in** (00:00–06:00), so the check fails *closed* and skips the
backup, with no retry.

## Where the lock came from

```
-r-------- 1 rsi rsi 176 2026-09-10 14:58:59 d2a7eac2...
```

pid 34352 on ceres, non-exclusive, created at 14:58:59 on 09-10 — **one minute before**
gr-srv03's `pre-swap-unmount.sh` runs at 15:00 and pulls the mount out from under it.
That was the BACKUP_A rotation check
([2026-09-10_gr-srv03_backup-a-rotation-check.md](2026-09-10_gr-srv03_backup-a-rotation-check.md)).
The process died with the mount and left its lock behind.

Note plain `restic unlock` removes this kind of lock on its own (same host, dead PID) —
the script never got that far.

## What was *not* wrong

Worth recording, because both look alarming and are normal:

- **`/mnt/backup_a` empty and unmounted during the afternoon.** By design:
  `pre-swap-unmount.sh` at 15:00, remount at 00:30, `check-ceres-mount-sync.sh` at 02:20.
  When unmounted, ceres's bind mount shows as `/dev/mapper/pve-root` — the empty shadow
  directory on the host root fs, not a stale-mount fault.
- **BACKUP_A itself.** `/dev/sdc1` was connected and healthy throughout; the disk was
  mounted at 03:00 on all three failed nights.

## Fix

`backup_greven` is a git repo on ceres (`/home/rsi/backup_greven/.git`).

`backup-usb1-local.sh` — `check_and_clear_stale_locks` rewritten:

1. Parse with `sed -n 's/.*"time"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'` — tolerates
   both pretty and compact JSON.
2. Call plain `restic unlock` **first** and re-list, letting restic drop locks whose owning
   process is provably dead. That alone would have cleared this incident.
3. Examine **all** locks, not `head -1`, and decide on the newest survivor.
4. **Never guess an age.** An unparseable timestamp now logs a distinct error and alerts,
   instead of silently becoming midnight.
5. The `>= 6h` branch uses `restic unlock --remove-all`, since restic's own heuristic has
   already declined to remove it.

The same broken pattern existed in `backup-usb1-s3.sh`, `backup-wdmycloud-local.sh` and
`backup-wdmycloud-s3.sh` and was fixed in all three. Those three are **not** dangerous:
each guards with `if [ -n "$lock_time" ]` and falls through to
*"Could not determine lock age, attempting unlock anyway"* — they fail **open**. Their age
logic was simply dead code. Only `backup-usb1-local.sh` lacked the guard and hit
`date -d ""`.

## Lessons

- `date -d ""` returning midnight instead of failing turns any silent parse failure into a
  plausible-looking small number. Guard the empty string explicitly; `|| echo 0` is not
  enough either, since `0` would read as 1970.
- Don't parse a pretty-printed JSON field with a pattern written against compact JSON.
  `restic cat` pretty-prints, `restic snapshots --json` does not.
- A staleness check that can only fail closed will happily skip backups forever. The
  6 h threshold plus a per-day cron means one bad lock costs one full day, silently, per day.

## Decided against: a consecutive-failure counter

The daily Pushover alert fired on all three nights, and a third consecutive miss looked
identical to the first. A consecutive-failure counter in the backup health monitor was
considered and **rejected 2026-09-13**: the repeating daily alert is working as intended,
the user was already aware it was repeating, and a counter adds monitoring complexity for
no gain. Do not re-propose it.
