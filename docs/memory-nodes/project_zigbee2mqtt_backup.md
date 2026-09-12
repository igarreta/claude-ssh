---
name: project_zigbee2mqtt_backup
description: CT206's Zigbee network state now has its own nightly gpg-encrypted backup and a written restore procedure
metadata:
  node_type: memory
  type: project
---

zigbee2mqtt's network key, PAN/ext-PAN, device registry and coordinator NVRAM backup are
staged nightly from `/opt/zigbee2mqtt/data` into `~/bak` on CT206 (02:00, root timer,
gpg-encrypted with the fleet `backup.key`), shipped at 02:07, and carried to BACKUP_A/B by
ceres under its **own restic tag `zigbee2mqtt`**.

**Why it matters:** before 2026-09-12 the only copy was the weekly whole-container vzdump —
RPO 7 days, one local disk, no offsite copy. Losing this state means re-pairing every device
by hand. The tarball is encrypted because `configuration.yaml` and `coordinator_backup.json`
carry the network key and MQTT password in cleartext and `backup.sh` ships `~/bak`
*unencrypted*.

**How to apply:** don't propose "stop z2m to back it up" — the staging script validates the
copy (every `database.db` line must parse as JSON) and retries instead, and refuses to
overwrite a good archive with a torn one. **Restore steps, what is deliberately excluded, and
the floor that must be raised after 2026-09-22 are in
[docs/2026-09-12_ct206_zigbee2mqtt-backup.md](../2026-09-12_ct206_zigbee2mqtt-backup.md).**
Adding a path to an existing restic tag needs `--group-by host,tags` or the old path-group
freezes instead of ageing out. Related: [[project_zigbee2mqtt_migration]],
[[project_backup_schedule]], [[project_igarreta-bin_shared-repo-hazard]].
