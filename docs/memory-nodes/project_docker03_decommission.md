---
name: project_docker03_decommission
description: docker03 (VM 102) is being decommissioned service by service; the umbrella project the individual migration nodes hang off
metadata:
  type: project
---

docker03 (VM 102 on gr-srv03) is being retired. Every container, host service, cron job and
mount was inventoried 2026-08-27 with an agreed destination for each — new dedicated LXCs
cloned from CT901, podman containers on cygnus, or deliberately dropped.

**Why it matters:** docker03 is still running, so finding a service there does *not* mean it
is live. Several were migrated with the docker03 copy **left in place as rollback** (notably
zigbee2mqtt after the 2026-09-05 CT206 cutover) — running on both hosts is expected during
the soak period, not a split-brain bug to fix. Check the inventory before repairing anything
on docker03, or you may be fixing a copy nothing uses.

**How to apply:** don't deploy anything new onto docker03. Outstanding as of 2026-09-06:
fail2ban (still genuinely needed on cygnus), and mosquitto / pool_heat / dynu / mqtt_log /
apache2 / portainer / the orphaned compose projects, which are dropped rather than migrated.

Full inventory and per-service destinations:
[docs/memory_docker03-decommission.md](../memory_docker03-decommission.md).
Pieces: [[project_gr-srv03_ct901-template]] (the clone source),
[[project_zigbee2mqtt_migration]], [[project_gr-srv03_rtl433-ct207]],
[[project_docker03_uptime-kuma-mqtt-explorer-cloudflare-migration]],
[[project_cygnus_backup-checker-iperf3-migration]],
[[project_gr-srv03_ct103-migration-plan]], [[project_beszel-disk-alerting]].
