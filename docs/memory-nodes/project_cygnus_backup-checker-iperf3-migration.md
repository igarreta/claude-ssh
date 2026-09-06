---
name: project_cygnus_backup-checker-iperf3-migration
description: "docker03's proxmox_backup_checker cron and iperf3 image moved to cygnus 2026-09-05; backup.sh needed no migration"
metadata: 
  node_type: memory
  type: project
  originSessionId: b868f20e-cebb-4117-b221-e8b65fd87fab
  modified: 2026-09-06T00:41:00.058Z
---

`proxmox_backup_checker` (a personal git repo with a `python_utils` submodule) is now running
on cygnus at 8:05 daily, reading the whole `backup_usb1` tree via a new read-only `mp5` bind
mount. iperf3's `networkstatic/iperf3` podman image is pulled and tested for ad hoc use.

**Why it matters:** docker03's `backup.sh` cron job looked like it needed migrating too, but
cygnus already runs its own identical copy (it's a generic per-host self-backup script, not
docker03-specific data) — don't re-migrate it if this comes up again.

Email was initially left disabled (placeholder `~/etc/smtp.env`), which caused a silent bug:
the script always tries to email a summary regardless of `to_email: []`, so the placeholder's
`disabled.invalid` host threw a DNS-lookup `ERROR` on every run even though all backups
passed — log-monitor escalated that ERROR to a false "crash" Pushover alert. Fixed 2026-09-05
by copying docker03's real gmail SMTP creds into `~/etc/smtp.env` on cygnus; a test run
confirmed `Email sent successfully to 1 recipients`. Pushover itself was already confirmed
working independently. The script's Uptime Kuma heartbeat will keep failing (harmlessly)
until uptime-kuma itself also moves to cygnus.

**How to apply:** full command sequence and file contents are in
`docs/memory_docker03-decommission.md` (cygnus section) — don't re-derive the `mp5` mount
reasoning or the SMTP-placeholder trick from scratch.
