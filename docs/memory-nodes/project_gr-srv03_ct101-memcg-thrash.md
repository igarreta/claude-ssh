---
name: project_gr-srv03_ct101-memcg-thrash
description: gr-srv03 high-temp alert 10-09 was CT101 thrashing at its memory limit; high load + low CPU means D-state, check guest memcg
metadata:
  type: project
---

On 2026-10-09 a high-temperature alert on gr-srv03 (86 °C, load 34) turned out to be CT101 (Samba03) thrashing against its 512 MiB memory limit. It was not a cooling problem. CT101's memory was raised to 1 GiB and the container restarted.

**Why:** a guest at its memory-cgroup limit rereads page cache from disk nonstop. That produces heat, a huge load average and hung processes (including host `pvestatd`), while CPU usage stays low.

**How to apply:** on gr-srv03, high load with low CPU usage means processes are blocked in D-state. List D-state processes with their cgroup, then read `memory.events` / `io.pressure` for that guest before suspecting hardware. Still open: CT101's cron `smbclient`/`smbstatus` jobs stack up with no overlap protection.

Detail: `docs/2026-10-09_gr-srv03_ct101-memcg-thrash-high-temp.md`
