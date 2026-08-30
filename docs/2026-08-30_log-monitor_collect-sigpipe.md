# log-monitor — contabo2 "ssh error" was an internal SIGPIPE in collect.sh

**Status:** closed
**Host:** comet, contabo2
**Supersedes:** —
**Superseded-by:** —

**Date:** 2026-08-30
**Code:** `log-monitor/collect.sh`, `log-monitor/run.sh`

## Symptom

From 2026-08-27 to 2026-08-30, every daily run produced a Pushover alert:

```
log-monitor: FAILED to collect logs from contabo2 (ssh error).
```

and `state/cron.log` logged `ERROR processing .../hosts/contabo2.conf`. contabo2's digest
was empty, its cursor frozen at 2026-08-26, and no report was generated for four days.
All five other hosts ran normally throughout.

**SSH was never broken.** Manual `ssh` to contabo2 worked the whole time. The message is
hardcoded in `run.sh` for *any* non-zero exit from `collect.sh`, which sent the diagnosis
down the wrong path from the start.

## Root cause

A chain of four things, each harmless alone:

1. **The trigger was the fix from four days earlier.** `/etc/group` on contabo2 was modified
   `2026-08-26 19:43` — that is when `rsi` was added to `systemd-journal` to close the
   journal-group blind spot (see `2026-06-30_log-monitor.md`, "Gotcha"). The 08-26 08:00 run
   predated it; **08-27 was the first run that could actually see the full journal, and the
   first failure.** Before the fix the journal was nearly empty, which is why this never fired.

2. **contabo2's journal is dominated by unique lines.** As an internet-facing host it logs
   ~4,500 UFW-blocked scan packets/day. Every line carries a distinct SRC/SPT/DPT/FLOWLBL, so
   `sort | uniq -c` cannot collapse them: **4,494 distinct signatures in a single day**, 19,018
   accumulated across the four stuck days.

3. **`head` in the remote pipeline turns a large result into exit 141.** The remote script's
   last command was:

   ```bash
   printf '%s\n' "$agg" | head -n "$TOP"      # TOP=200
   ```

   With more than 200 lines `head` exits early, `printf` takes SIGPIPE, and `set -o pipefail`
   makes the pipeline status **141**. Being the last command, that became the remote shell's
   exit status, and therefore `ssh`'s. Verified directly on contabo2:

   ```
   5000 lines | head -200  → exit 141
     50 lines | head -200  → exit 0
   ```

4. **`set -e` then killed collect.sh silently.** `RAW="$(ssh ...)"` inherited 141, `set -e`
   aborted with no stderr and no message, the digest was written empty, and — critically —
   **the cursor was never advanced**. Each day's backlog therefore grew, guaranteeing the
   condition would persist forever once entered. Self-perpetuating, not transient.

### The suppression that should have prevented it

`hosts/contabo2.conf` already carried `SUPPRESS_PATTERN="\[UFW BLOCK\]"` for exactly this
noise. It never ran: suppression was applied **locally, after** the remote `head -n 200` cap,
so the remote shell had already died. Even without the crash the design was wrong — the flood
would have filled all 200 slots and pushed every real message out of the digest.

## What was actually being missed

Only **four** non-UFW warning+ signatures existed in the entire four-day backlog — nothing
urgent, but invisible for four days:

```
43  systemd-networkd: Foreign process 'dockerd' changed sysctl
    '/proc/sys/net/ipv6/conf/eth0/disable_ipv6' from '0' to '1', conflicting with our setting to '0'
13  systemd-networkd-wait-online: Timeout occurred while waiting for network connectivity
 2  sshd-session: error: kex_exchange_identification: read: Connection reset by peer
 1  sudo: rsi : a password is required ; PWD=/home/rsi ; COMMAND=/usr/bin/true
```

The two `sshd` lines are ordinary scanner noise (dropped handshakes), not an SSH fault.

## Fix

**`collect.sh`** — three changes:

1. **Suppression moved into the remote script, before aggregation and before the cap.**
   `SUPPRESS_PATTERN` and the Monday-only pattern are combined locally into
   `SUPPRESS_EFFECTIVE` and passed through the `%q`-quoted `REMOTE_ENV`. Noise is now dropped
   at the source, so it can neither crash the run nor crowd out real messages, and far less
   data crosses the wire. The redundant local filter blocks were removed — one home for the logic.
2. **`head -n "$TOP"` → `awk -v n="$TOP" 'NR<=n'`.** `awk` drains its input, so the cap can
   never raise SIGPIPE and can never set a failure exit.
3. **Empty-journal guard**, so a quiet host doesn't aggregate a here-string's trailing newline
   into a bogus `1 <blank>` signature.

The digest gained a `suppressed=N` field so the noise volume stays visible instead of vanishing.

**`run.sh`** — the collect-failure path reports the real exit code
(`collect.sh exit 141`) instead of asserting `(ssh error)`, and logs it to stderr.

### Trap hit while fixing it

The first version of the empty guard used `[[ -n "${raw//[[:space:]]/}" ]]`. Bash global
substitution over a multi-megabyte string takes **minutes** — on an unsuppressed high-volume
host this presented as an SSH hang, i.e. the exact misdiagnosis this whole fix is about. It is
now `kept=$(grep -c . <<<"$raw")`, which is ~0.02s on 2 MB. Don't reach for `${var//…}` on
anything that might hold a whole journal.

## Verification (2026-08-30)

| Test | Result |
|---|---|
| contabo2, real 4-day backlog | exit 0 — `total=59 distinct=4 suppressed=19215`; the 4 real signatures surface |
| >200 distinct with suppression **off** (reproduces the original bug) | exit 0 in 6.6s, exactly 200 emitted — **was exit 141** |
| gr-srv03 (multi-alternative pattern) | exit 0, 17 lines suppressed |
| mosquitto, raspberrypi1 (populated) | exit 0, counts correct |
| docker03, raspberrypi2z (empty journal) | exit 0, renders `none` |
| Monday pattern combination | correct; no leading `\|` when the base pattern is empty |

Other hosts were tested with their cursors backed up and restored, so no pending window was
consumed. contabo2's cursor **did** advance during testing — the four-day backlog is spent and
will not appear in a report, but its entire content is quoted above.

## Notes

- The bug was **latent on every host**, not specific to contabo2. Any host crossing 200 distinct
  signatures in one window would have failed the same silent way.
- Rapid repeated test connections tripped **fail2ban on contabo2** (active there), causing
  transient connection hangs during this investigation. Not a production concern — log-monitor
  opens two connections per day.
- The `dockerd` / `disable_ipv6` sysctl conflict (43 hits) was investigated the same day and
  is a **systemd-networkd misattribution of a container's `eth0`**, not a host IPv6 problem —
  present since 2026-02-26, merely invisible until now. Suppressed in `contabo2.conf`;
  full rationale in [2026-06-30_log-monitor.md](2026-06-30_log-monitor.md), "Noise suppression".
- The `systemd-networkd-wait-online` timeouts (13 hits) were investigated separately the same
  day. `networkctl` showed eth0 stuck at `routable (configuring)`; the source netplan
  (`/etc/netplan/50-cloud-init.yaml`) had no `accept-ra` override, defaulting to enabled, on a
  network with no real router ever sending RAs — a plausible cause, since IPv6 routing is
  entirely static. Fixed with a `/etc/netplan/90-disable-accept-ra.yaml` drop-in setting
  `accept-ra: false` (kept separate from the cloud-init-owned file, which may be regenerated),
  applied via `netplan try`. **This did not change the setup state** — eth0 still shows
  `configuring` after the fix. Further checking (`ip -6 neigh show dev eth0`, `curl -6
  https://ifconfig.co`) confirmed IPv6 is fully functional regardless: gateway `REACHABLE`,
  outbound IPv6 HTTP succeeds. Conclusion: the stuck setup state is cosmetic networkd
  bookkeeping, unrelated to RA (the RA fix stands on its own merit but wasn't the actual cause
  of the setup-state or wait-online symptom). Suppressed in `contabo2.conf` alongside the
  dockerd noise; root cause of the setup-state stall not identified, not pursued further.
