# gr-srv03: high temperature from CT101 (Samba03) memory-cgroup thrashing

**Status:** open
**Status detail:** symptom fixed 2026-10-09 (memory raised, CT restarted); what pushed CT101 past its limit, and why its cron jobs stack up, not yet investigated
**Host:** gr-srv03
**Supersedes:** —
**Superseded-by:** —

## Symptom

On 2026-10-09 gr-srv03 raised high-temperature alerts:

- `x86_pkg_temp` was at **86 °C**.
- The 1-minute load average was **34.5** on the 4-core N97.
- Actual CPU use was low. `vmstat` showed 44% iowait, 18–25 processes blocked, about 110 MB/s of reads, and constant swap-in/out.

## Root cause

CT101 (Samba03, Turnkey) was stuck at its **512 MiB** memory limit, with 532 MB in use.

Inside its memory cgroup the kernel could only free space by dropping cached file pages, which then had to be read straight back from disk. That reread loop kept the NVMe and CPU busy and produced the heat.

Evidence from `/sys/fs/cgroup/lxc/101`:

| Signal | Value |
|---|---|
| `memory.events` | `high` 160 M, `oom` 43, `oom_kill` 21 |
| `memory.pressure` full | ~60% |
| `io.pressure` some | **99%** |
| Kernel log | memcg OOM kills since 2026-10-07, mostly `webmin` |

**17 processes were stuck in D-state** in `folio_wait_bit_common`:

- CT101 services: `systemd-journald`, `nmbd`, `avahi`, `dbus`, `wsdd`, `smbd`, `htcacheclean`.
- A pile of **cron-launched `smbclient` / `smbstatus` / `lsof` processes**, which had stacked up every few hours for about 2 days.
- Host `pvestatd`, which leaves PVE GUI stats stale while CT101 is stuck.

The rest of the host was healthy, with about 3.4 GB available.

The repeated `nfsdcld` lines in the kernel log are OOM-killer task-table dumps, not NFS errors.

## Fix

```bash
pct set 101 -memory 1024      # applied live
timeout 120 pct stop 101      # stopped cleanly, no forced kill needed
pct start 101
```

## Verification (~5 min after restart)

| | Before | After |
|---|---|---|
| Load average (1 min) | 34.5 | 1.7, still falling |
| iowait | 44% | 0% |
| D-state processes | 17 | 0 |
| CT101 memory | 532 MB / 512 MiB | 332 MB / 1024 MiB, pressure 0 |
| `x86_pkg_temp` | 86 °C | 77 °C, still falling |

`smbd` and `nmbd` were active after the restart.

## Open

- **The CT101 cron job running `smbclient` / `smbstatus` / `lsof`.** It launches new runs while earlier ones are still hung, so it has no protection against overlapping runs. This is what turned a slow container into a stuck one.
- **What grew CT101's memory use from about 2026-10-07.** Not yet known.
- **Diagnostic for next time.** A high load average combined with low CPU usage on gr-srv03 means processes are blocked, not working. Check, in order:
  1. `ps -eo stat,cgroup,wchan,comm | awk '$1~/^D/'`
  2. `memory.events` of the guest cgroup that turns up
