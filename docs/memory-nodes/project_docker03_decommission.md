---
name: project_docker03_decommission
description: docker03 (VM 102) is stopped since 2026-09-06 and not in use, onboot=0 since 09-10, in cooldown before deletion; umbrella for the individual migration nodes
metadata:
  type: project
---

docker03 (VM 102 on gr-srv03) is being retired. Every container, host service, cron job and
mount was inventoried 2026-08-27 with an agreed destination for each — new dedicated LXCs
cloned from CT901, podman containers on cygnus, or deliberately dropped.

**VM 102 is stopped and not in use** — shut down 2026-09-06 16:11, cooldown before deletion.

**Why it matters:** its services still *exist* on disk, including a zigbee2mqtt kept as
explicit rollback after the 09-05 CT206 cutover and `backup.sh` / `proxmox_backup_checker`
crons superseded by cygnus's. They are harmless only while the VM is down: starting it
resurrects all of them at once, next to their live replacements. `onboot` was set to `0` on
2026-09-10, so only a deliberate `qm start 102` can do that — a host reboot no longer will.

**How to apply:** never start VM 102 as a casual diagnostic step — it is a deliberate
rollback decision. Don't deploy anything new onto it. Ignore it in outage and service checks,
the way [[project_gr-srv03_vm100_stopped]] is ignored. Dropped rather than migrated: mosquitto
/ pool_heat / dynu / mqtt_log / apache2 / portainer / the orphaned compose projects; fail2ban
lives on cygnus now.

Full inventory and per-service destinations:
[docs/memory_docker03-decommission.md](../memory_docker03-decommission.md).
Pieces: [[project_gr-srv03_ct901-template]] (the clone source),
[[project_zigbee2mqtt_migration]], [[project_gr-srv03_rtl433-ct207]],
[[project_docker03_uptime-kuma-mqtt-explorer-cloudflare-migration]],
[[project_cygnus_backup-checker-iperf3-migration]],
[[project_gr-srv03_ct103-migration-plan]], [[project_beszel-disk-alerting]].
