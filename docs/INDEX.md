# docs/ index

Entry point for `docs/`. Grouped by **topic thread**, current state first.
Read the **Current** line before anything in **History** — history entries are kept
for the reasoning, not because they still describe the system.

Every doc carries a header block right under its title:

```
**Status:** active | closed | superseded | open
**Host:** docker03, gr-srv03
**Supersedes:** <older file>   (or —)
**Superseded-by:** <newer file> (or —)
```

- **active** — describes how the system works *now*; edit in place as it changes.
- **closed** — an incident that was resolved. Accurate as history; the fix is live.
- **superseded** — replaced by a newer doc. **Do not act on it.** Follow `Superseded-by`.
- **open** — unresolved, or a decision/purchase not yet made. Needs follow-up.

Quick queries:

```bash
grep -l '^\*\*Status:\*\* open' docs/*.md          # what still needs attention
grep -l '^\*\*Status:\*\* superseded' docs/*.md    # what not to trust
grep -l '^\*\*Host:\*\*.*docker03' docs/*.md       # everything about one host
```

---

## Heating — TTato (raspberrypi1)

**Current:** MQTT command subscription fixed permanently 2026-08-15 (`on_connect` resubscribe,
commit `b24d961`); Manual-mode phantom-zero bugs fixed 2026-08-01 →
[2026-08-15_raspberrypi1_ttato-mqtt-resubscribe-fix.md](2026-08-15_raspberrypi1_ttato-mqtt-resubscribe-fix.md)

- [2026-08-15_..._ttato-mqtt-resubscribe-fix.md](2026-08-15_raspberrypi1_ttato-mqtt-resubscribe-fix.md) — *closed* — permanent fix
- [2026-08-01_..._ttato-mqtt-subscription-drop.md](2026-08-01_raspberrypi1_ttato-mqtt-subscription-drop.md) — **superseded** by the above; its "restart the container" remedy is not the fix
- [2026-08-01_..._ttato-manual-mode-phantom-zero-heating.md](2026-08-01_raspberrypi1_ttato-manual-mode-phantom-zero-heating.md) — *closed* — stale-sensor + HA unknown-state bugs in `CheckManual()`
- [2026-07-23_..._ttato-manual-mode-and-ha-script-fix.md](2026-07-23_raspberrypi1_ttato-manual-mode-and-ha-script-fix.md) — *active* — mode-change contract (`changemode.json` / `TTato/command`), HA script payload fix, HA-session notes
- [2026-07-20_..._ttato-granev-integration.md](2026-07-20_raspberrypi1_ttato-granev-integration.md) — *closed* — `granev/temp/*` subscription that was never wired up

## USB, Zigbee and RF (gr-srv03 + docker03)

**Current:** powered hub removed 2026-08-17, root cause confirmed 08-19 (BACKUP_A/_B hot-plug
transients on the shared xHCI 5V rail). Coordinator RF has since degraded in its bare chassis
port — **shielded USB extension still pending** →
[2026-08-24_docker03_zigbee-coordinator-rf-degradation.md](2026-08-24_docker03_zigbee-coordinator-rf-degradation.md)

- [2026-08-24_docker03_zigbee-coordinator-rf-degradation.md](2026-08-24_docker03_zigbee-coordinator-rf-degradation.md) — **open** — fleet LQI 200→134; physical fix ~2 months out. Baselines in [data/](data/)
- [2026-08-19_gr-srv03_usb-hub-layout-plan.md](2026-08-19_gr-srv03_usb-hub-layout-plan.md) — **open** — port-3 layout undecided, nothing purchased
- [2026-08-19_gr-srv03_usb-hub-comparison.md](2026-08-19_gr-srv03_usb-hub-comparison.md) — **open** — storage hub decided (Rosonway RSH-A10), dongle hub open
- [memory_gr-srv03_powered-hub-instability.md](memory_gr-srv03_powered-hub-instability.md) — *closed* — root cause + current post-incident topology
- [memory_gr-srv03_usb-hub-eval.md](memory_gr-srv03_usb-hub-eval.md) — **superseded** — speed baseline whose "move to a powered hub" conclusion is void
- [memory_docker03_zigbee2mqtt.md](memory_docker03_zigbee2mqtt.md) — *closed* — 2026-07-15 outage, stable `by-id` mapping + 5-min watchdog

## rtl_433 / 433 MHz sensors (raspberrypi2z)

**Current:** production on raspberrypi2z since 2026-06-27, topic prefix `rtl_433/raspberrypi2z`,
daily restart in place →
[2026-06-26_raspberrypi2z_rtl433-setup.md](2026-06-26_raspberrypi2z_rtl433-setup.md)

- [2026-06-26_raspberrypi2z_rtl433-setup.md](2026-06-26_raspberrypi2z_rtl433-setup.md) — *active* — install + config reference
- [2026-06-27_rtl433-production-migration.md](2026-06-27_rtl433-production-migration.md) — *closed* — docker03 → raspberrypi2z cutover
- [2026-07-21_raspberrypi2z_rtl433-decode-drop.md](2026-07-21_raspberrypi2z_rtl433-decode-drop.md) — *closed* — dropped to 1 of 3 sensors; daily restart added
- [2026-07-02_raspberrypi2z_oregon-sensor-outage.md](2026-07-02_raspberrypi2z_oregon-sensor-outage.md) — *closed*
- [memory_raspberrypi2z_pool-thermometer.md](memory_raspberrypi2z_pool-thermometer.md) — **open** — WT0124 (protocol 109) bought, not yet integrated
- [memory_rtl-test.md](memory_rtl-test.md) — **open** — docker03 garage-remote capture, unfinished

## Backups

**Current:** health monitor phases 1–3 deployed 2026-08-15, **tests being finished as of
2026-08-24**; ceres empty-snapshot cause still unproven — probe read 2026-08-24, never reproduced, held for the
08-25 BACKUP_A rotation →
[2026-08-14_backup-health-monitor-design.md](2026-08-14_backup-health-monitor-design.md)

- [2026-08-14_backup-health-monitor-design.md](2026-08-14_backup-health-monitor-design.md) — *active* — design + deployed implementation; finishing tests
- [2026-08-14_ceres-empty-snapshots-probe.md](2026-08-14_ceres-empty-snapshots-probe.md) — **open** — 7 months of empty snapshots; `pct reboot 203` fixed it, cause unproven after 8 probe nights, probe held for the 08-25 BACKUP_A rotation
- [memory_backup_schedule.md](memory_backup_schedule.md) — *active* — **read before adding any job**: disk-wake window 02:25–03:30
- [Backup_Drives_Mounting_Configuration.md](Backup_Drives_Mounting_Configuration.md) — *active* — fstab + udev/systemd mount units for BACKUP_USB1 / A / B
- [2026-08-17_contabo2_nfs-backup-hang-rclone-migration.md](2026-08-17_contabo2_nfs-backup-hang-rclone-migration.md) — *closed* — NFS over WAN → rclone/SFTP
- [2026-06-27_raspberrypi2z_backup.md](2026-06-27_raspberrypi2z_backup.md) — *active* — monthly SD image → NFS → restic
- [memory_ceres_wdmycloud_glacier.md](memory_ceres_wdmycloud_glacier.md) — *active* — WDMyCloud → S3 Glacier
- [2026-05-28_cygnus_backup-usb1-data-mount-and-quetren-grabaciones.md](2026-05-28_cygnus_backup-usb1-data-mount-and-quetren-grabaciones.md) — *closed*

## MQTT

**Current:** dedicated broker LXC 105 built and verified (auth + TLS); **client cutover not
started**, blocked on a static LAN IP →
[memory_mqtt-broker-migration.md](memory_mqtt-broker-migration.md)

- [memory_mqtt-broker-migration.md](memory_mqtt-broker-migration.md) — **open**
- [HomeAssistant_MQTT_Autodiscovery.md](HomeAssistant_MQTT_Autodiscovery.md) — *active* — always use autodiscovery; lesson learned the hard way

## Home Assistant

- [2026-08-19_homeassistant_temperatura-exterior-parque-stale-chain.md](2026-08-19_homeassistant_temperatura-exterior-parque-stale-chain.md) — *closed* — zigbee2mqtt discovery entities never go `unavailable`; guard on `last_reported`, not `last_changed`

## Containers — podman (cygnus) and docker (docker03)

**Current:** `podman-restart.service` needs a drop-in whose filter matches `unless-stopped`,
not just the default `always` →
[2026-07-12_cygnus_tuya-link-podman-restart-gap.md](2026-07-12_cygnus_tuya-link-podman-restart-gap.md)

- [2026-07-12_cygnus_tuya-link-podman-restart-gap.md](2026-07-12_cygnus_tuya-link-podman-restart-gap.md) — *closed* — the complete fix
- [2026-06-22_cygnus_podman-restart-after-reboot.md](2026-06-22_cygnus_podman-restart-after-reboot.md) — **superseded** — enabling the unit alone was not enough
- [2026-07-05_docker03_fail2ban-fix.md](2026-07-05_docker03_fail2ban-fix.md) — *closed* — no rsyslog → `backend = systemd`

## Networking and Tailscale

- [2026-08-17_docker03_tailscale-key-expiry-and-container-dns.md](2026-08-17_docker03_tailscale-key-expiry-and-container-dns.md) — *closed* — node-key expiry; MagicDNS-only `resolv.conf` broke all container DNS
- [2026-07-12_comet_tailscale-logout-power-outage.md](2026-07-12_comet_tailscale-logout-power-outage.md) — *closed* — corrupted `tailscaled.state`; also: unprivileged `journalctl` truncates and fakes an outage
- [Tailscale_ACL_Configuration.md](Tailscale_ACL_Configuration.md) — *active*
- [Initial_Internal_Network_Setup_vmbr1.md](Initial_Internal_Network_Setup_vmbr1.md) — *active* — 10.0.100.0/24 internal bridge
- [2026-04-12_ceres_systemd-resolved.md](2026-04-12_ceres_systemd-resolved.md) — *closed* — dhclient/tailscaled `resolv.conf` fight

## Watchdogs and host recovery

- [2026-06-25_raspberrypi1_kernel-watchdog.md](2026-06-25_raspberrypi1_kernel-watchdog.md) — *closed* — BCM2835 watchdog armed; closes the freeze gap
- [memory_raspberrypi1_freeze.md](memory_raspberrypi1_freeze.md) — **superseded** by the above
- [2026-04-03_raspberrypi1_wifi-watchdog.md](2026-04-03_raspberrypi1_wifi-watchdog.md) — *active* — script + incident log
- [2026-06-26_raspberrypi2z_wifi-watchdog.md](2026-06-26_raspberrypi2z_wifi-watchdog.md) — *active*
- [memory_gr-srv03_stale-mount-investigation.md](memory_gr-srv03_stale-mount-investigation.md) — *closed* — LXC bind-mount propagation can't survive a host remount; reboot is correct

## Proxmox / gr-srv03 platform

- [Proxmox_unpriviedged_LXC_mount_permissions.md](Proxmox_unpriviedged_LXC_mount_permissions.md) — *active* — `nobody:nogroup` on bind mounts
- [Proxmox_8.4_to_9.1_Upgrade_Summary.md](Proxmox_8.4_to_9.1_Upgrade_Summary.md) — *closed*
- [2026-04-25_gr-srv03_lvm-monitor-and-docker03-discard.md](2026-04-25_gr-srv03_lvm-monitor-and-docker03-discard.md) — *closed* — thin-pool monitor + discard
- [2026-05-13_gr-srv03_disable-apt-timers.md](2026-05-13_gr-srv03_disable-apt-timers.md) — *closed*

## Database — castor

- [memory_castor.md](memory_castor.md) — *active* — must keep `10.0.100.11` in `listen_addresses`
- [2026-05-29_castor_postgresql-setup.md](2026-05-29_castor_postgresql-setup.md) — *active*

## Web / TLS — cygnus

- [2026-06-22_cygnus_caddy-tls-pgadmin.md](2026-06-22_cygnus_caddy-tls-pgadmin.md) — *active* — Caddy + Tailscale cert renewal via root cron
- [2026-08-04_cygnus_caddy-cert-ari-stuck-order.md](2026-08-04_cygnus_caddy-cert-ari-stuck-order.md) — **open** — Let's Encrypt ARI stuck order, unresolved as of 2026-08-04

## NAS project

**Current:** research complete, purchase-ready 2026-08-24. Buy list = TerraMaster F2-425 **Plus**
+ 6 TB recert from goHardDrive. **Only open call: P1 (both drives, $752) vs P2 (one now, $562)** →
[memory_nas-project.md](memory_nas-project.md)

- [memory_nas-project.md](memory_nas-project.md) — **open** — scope, sizing, buy list, rejected options
- [2026-08-20_nas-disk-prices-and-raid-options.md](2026-08-20_nas-disk-prices-and-raid-options.md) — *active* — prices, RAID layouts, recert sourcing. **Corrects §5/§9 of the 08-19 doc.** Verify stock before ordering
- [2026-08-19_nas-hardware-research.md](2026-08-19_nas-hardware-research.md) — *active* — market context and OS choice. **§5 and §9 enclosure specs are wrong** — see above

## Tooling and workstation

- [2026-06-30_log-monitor.md](2026-06-30_log-monitor.md) — *active* — daily log review from comet
- [memory_comet_zed-tmux-claude.md](memory_comet_zed-tmux-claude.md) — *closed* — Zed + tmux + Claude workflow
- [memory_feedback.md](memory_feedback.md) — *active* — **working preferences; read first**

## living1

- [2025-03-07_living1_description.md](2025-03-07_living1_description.md) — *active* — hardware/OS inventory
- [2025-12-13_living1_wifi-fix.md](2025-12-13_living1_wifi-fix.md) — *closed* — internal RTL8723AE blacklisted, USB RTL8188FTV used away from home
- [2026-03-04_living1_hdmi-audio-fix.md](2026-03-04_living1_hdmi-audio-fix.md) — *closed*

## Other hosts

- [2026-06-25_raspberrypi2z_setup-and-security.md](2026-06-25_raspberrypi2z_setup-and-security.md) — *active* — sudo needs a password; no SSH password auth
- [RaspberryPi3Bplus_Slow_Ethernet_Fix.md](RaspberryPi3Bplus_Slow_Ethernet_Fix.md) — *closed* — raspberrypi1
- [2026-02-24_migration_to_contabo2.md](2026-02-24_migration_to_contabo2.md) — *closed* — all phases completed by 2026-03-07
