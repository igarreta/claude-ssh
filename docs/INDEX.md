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
[2026-08-15_raspberrypi1_ttato-mqtt-resubscribe-fix.md](2026-08-15_raspberrypi1_ttato-mqtt-resubscribe-fix.md).
A **long-term plan** exists to split TTato into a gr-srv03 brain + an ESP32 at the boiler, and to
turn raspberrypi1 into a thin radio head — **not scheduled, nothing built** →
[2026-09-12_raspberrypi1-gr-srv03_radio-head-and-ttato-split.md](2026-09-12_raspberrypi1-gr-srv03_radio-head-and-ttato-split.md)

- [2026-09-12_..._radio-head-and-ttato-split.md](2026-09-12_raspberrypi1-gr-srv03_radio-head-and-ttato-split.md) — **open** — long-term architecture: TTato split, z2m state stays on gr-srv03, Pi runs `ser2net`; full GPIO map + 7 open questions
- [2026-08-15_..._ttato-mqtt-resubscribe-fix.md](2026-08-15_raspberrypi1_ttato-mqtt-resubscribe-fix.md) — *closed* — permanent fix
- [2026-08-01_..._ttato-mqtt-subscription-drop.md](2026-08-01_raspberrypi1_ttato-mqtt-subscription-drop.md) — **superseded** by the above; its "restart the container" remedy is not the fix
- [2026-08-01_..._ttato-manual-mode-phantom-zero-heating.md](2026-08-01_raspberrypi1_ttato-manual-mode-phantom-zero-heating.md) — *closed* — stale-sensor + HA unknown-state bugs in `CheckManual()`
- [2026-07-23_..._ttato-manual-mode-and-ha-script-fix.md](2026-07-23_raspberrypi1_ttato-manual-mode-and-ha-script-fix.md) — *active* — mode-change contract (`changemode.json` / `TTato/command`), HA script payload fix, HA-session notes
- [2026-07-20_..._ttato-granev-integration.md](2026-07-20_raspberrypi1_ttato-granev-integration.md) — *closed* — `granev/temp/*` subscription that was never wired up

## USB, Zigbee and RF (gr-srv03 + docker03)

**Current:** powered hub removed 2026-08-17, root cause confirmed 08-19 (BACKUP_A/_B hot-plug
transients on the shared xHCI 5V rail). Coordinator RF degraded in its bare chassis port, then
**recovered to ~220 LQI after the 08-25 wall-mounted final placement, then relapsed to ~120
on 09-05** → [2026-08-24_docker03_zigbee-coordinator-rf-degradation.md](2026-08-24_docker03_zigbee-coordinator-rf-degradation.md).
Recheck done 2026-09-11 (§8), still **open**: the WiFi-channel test is impossible (Deco mesh has
no manual channel), LQI is unrecovered, route errors have doubled past August's worst day, and
the LQI turns out to **swing ~60 points across the day** (86 at 04h, 147 at 16h) — measuring it
now needs the collector, not a spot check. Shielded-cable purchase stays on.
The storage hub for the rebuild (Rosonway RSH-A10) was **ordered 2026-08-29, ETA ~2026-10-24**
and the layout was decided 2026-08-30 (**Option D** — Zigbee keeps its own direct host port,
test-only RTL-433 goes on the hub, no second hub) — nothing is installed until it lands.
**Premise changed 2026-09-07: BACKUP_A/B rotation moves to the NAS, vacating a USB port, so
3 devices fit 3 ports and the hub is no longer needed** — it also removes the host's only
hot-plugged device, the documented root cause of the Zigbee drops. Re-evaluate Option D when the
NAS is commissioned, not when the hub arrives.

- [2026-08-24_docker03_zigbee-coordinator-rf-degradation.md](2026-08-24_docker03_zigbee-coordinator-rf-degradation.md) — **open** — fleet LQI 200→134, recovered to ~220 after 08-25 final placement, relapsed to ~120 on 09-05; §8 is the 09-11 recheck (diurnal swing, route errors doubled). Baselines in [data/](data/)
- [memory_zigbee-lqi-collector.md](memory_zigbee-lqi-collector.md) — *active* — persistent LQI/route-error CSVs on CT206 (5-min timer), because z2m's own logs only hold ~22 h; `report.sh` / `report.sh hourly N`
- [2026-08-19_gr-srv03_usb-hub-layout-plan.md](2026-08-19_gr-srv03_usb-hub-layout-plan.md) — **open** — RSH-A10 ordered 2026-08-29 (ETA ~10-24); layout decided 2026-08-30 (**Option D**: Zigbee stays direct on port 3, test-only RTL-433 on the hub); § *To implement when the hub arrives* carries the mandatory `uhubctl -a on` assertion and the pre-rebuild LQI baseline
- [2026-08-19_gr-srv03_usb-hub-comparison.md](2026-08-19_gr-srv03_usb-hub-comparison.md) — **open** — storage hub ordered 2026-08-29 (Rosonway RSH-A10); dongle hub closed, none needed
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
- [2026-09-12_..._radio-head-and-ttato-split.md](2026-09-12_raspberrypi1-gr-srv03_radio-head-and-ttato-split.md) — **open** — long-term: z2m/rtl_433 placement, and why raspberrypi2z is ruled out as a z2m host
- [memory_rtl-test.md](memory_rtl-test.md) — **open** — docker03 garage-remote capture, unfinished

## Backups

**Current:** health monitor phases 1–3 deployed 2026-08-15, **tests being finished as of
2026-08-24**; ceres empty-snapshot cause never reproduced across 3 probe readings incl. the
08-25→08-26 BACKUP_A rotation — probe **closed and removed 2026-08-26**. **WDMyCloud NAS
dead 2026-09-06** — its two backup crons on ceres are disabled until a replacement NAS is
in place (may take >2 months); existing local + S3 Glacier repos left untouched →
[2026-09-06_ceres_wdmycloud-nas-dead.md](2026-09-06_ceres_wdmycloud-nas-dead.md).
**BACKUP_A checked 2026-09-10 after rotating back in: nightly repo healthy (7/7 tags, floors
passed, `restic check` clean) and its `restic-wdmycloud` copy verified intact (2026-08-31,
1.462 TiB) — that closes the last unverified WDMyCloud copy, both local repos are now
confirmed** →
[2026-09-10_gr-srv03_backup-a-rotation-check.md](2026-09-10_gr-srv03_backup-a-rotation-check.md). **raspberrypi1's
`backup.sh` (shared `igarreta/bin` repo with contabo2) was clobbered by a contabo2-only commit
2026-09-06, breaking its 09-07 cron run — merged into one hostname-branched script, fixed and
verified on both hosts 2026-09-07** →
[2026-09-07_raspberrypi1-contabo2_backup-sh-merge.md](2026-09-07_raspberrypi1-contabo2_backup-sh-merge.md).
**zigbee2mqtt (CT206) got its own nightly backup 2026-09-12** — its Zigbee network key and device
registry had only the weekly whole-container vzdump until then. The same pass fixed two adjacent
faults: mosquitto's `backup.sh` had broken that very morning (the 09-07 merge branched on
raspberrypi1, so every *other* host fell into contabo2's SFTP path — now branches on the
exception), and `/mnt/backup_usb1/mosquitto` turned out to be in **no restic tag at all** →
[2026-09-12_ct206_zigbee2mqtt-backup.md](2026-09-12_ct206_zigbee2mqtt-backup.md)

- [2026-09-12_ct206_zigbee2mqtt-backup.md](2026-09-12_ct206_zigbee2mqtt-backup.md) — *active* — the z2m state backup end to end: what is and is not copied, why it is gpg-encrypted and validated instead of quiesced, the **restore procedure**, plus the mosquitto `backup.sh` break and the `--group-by host,tags` retention trap that adding a path to a restic tag springs
- [2026-09-10_gr-srv03_backup-a-rotation-check.md](2026-09-10_gr-srv03_backup-a-rotation-check.md) — *closed* — post-rotation verification of BACKUP_A: mount/propagation, 7/7 tags with floors passed, `restic check` clean, SMART clean, and its WDMyCloud repo verified intact; also corrects the drive model in the mounting doc
- [2026-09-07_raspberrypi1-contabo2_backup-sh-merge.md](2026-09-07_raspberrypi1-contabo2_backup-sh-merge.md) — *closed* — shared-repo clobber; merged into one hostname-branched script
- [2026-09-06_ceres_wdmycloud-nas-dead.md](2026-09-06_ceres_wdmycloud-nas-dead.md) — **open** — WD MyCloud dead/irrecoverable; found+fixed a live risk where the missing mount would let backup cron rotate out real snapshots; crons disabled, configs wiped, repos preserved — **both local copies now verified (B 09-07, A 09-10)**
- [2026-08-14_backup-health-monitor-design.md](2026-08-14_backup-health-monitor-design.md) — *active* — design + deployed implementation; finishing tests
- [2026-08-14_ceres-empty-snapshots-probe.md](2026-08-14_ceres-empty-snapshots-probe.md) — *closed* — 7 months of empty snapshots; `pct reboot 203` fixed it, cause never proven after 3 probe readings, probe removed 2026-08-26
- [memory_backup_schedule.md](memory_backup_schedule.md) — *active* — **read before adding any job**: disk-wake window 02:25–03:30
- [Backup_Drives_Mounting_Configuration.md](Backup_Drives_Mounting_Configuration.md) — *active* — fstab + udev/systemd mount units for BACKUP_USB1 / A / B; drive models corrected 2026-09-10 (A and B are **not** the same model, both APM 128)
- [2026-08-17_contabo2_nfs-backup-hang-rclone-migration.md](2026-08-17_contabo2_nfs-backup-hang-rclone-migration.md) — *closed* — NFS over WAN → rclone/SFTP
- [2026-06-27_raspberrypi2z_backup.md](2026-06-27_raspberrypi2z_backup.md) — *active* — monthly SD image → NFS → restic
- [memory_ceres_wdmycloud_glacier.md](memory_ceres_wdmycloud_glacier.md) — **open** — WDMyCloud → S3 Glacier mechanics; paused, see 2026-09-06_ceres_wdmycloud-nas-dead.md
- [2026-05-28_cygnus_backup-usb1-data-mount-and-quetren-grabaciones.md](2026-05-28_cygnus_backup-usb1-data-mount-and-quetren-grabaciones.md) — *closed*

## MQTT

**Current:** dedicated broker LXC 105 live; **all 7 clients cut over** (2026-08-26, incl.
esp32-pileta found late) — old docker03 broker **stopped** 2026-08-26, not yet removed →
[memory_mqtt-broker-migration.md](memory_mqtt-broker-migration.md)

- [memory_mqtt-broker-migration.md](memory_mqtt-broker-migration.md) — **open**
- [HomeAssistant_MQTT_Autodiscovery.md](HomeAssistant_MQTT_Autodiscovery.md) — *active* — always use autodiscovery; lesson learned the hard way
- [2026-08-28_mosquitto_ssh-socket-failed.md](2026-08-28_mosquitto_ssh-socket-failed.md) — *closed* — `ssh.socket` vs `ssh.service` port race, cosmetic only, disabled the socket unit
- [2026-09-11_mosquitto_networkd-wait-online-timeout.md](2026-09-11_mosquitto_networkd-wait-online-timeout.md) — *closed* — daily `wait-online` warnings; networkd managed zero links (ifupdown owns eth0), masked + stopped. **Different cause from contabo2's identical log lines**

## Home Assistant

**Current:** temperature sensors inventoried, cleaned up, and renamed to a consistent
`<house>_<room>_<qualifier>_<what>` convention, all 2026-09-01; disk cleanup 2026-09-05
freed ~1.7GB (stale 1GB log + 8 old full backups) →
[2026-09-01_homeassistant_temperature-sensor-inventory.md](2026-09-01_homeassistant_temperature-sensor-inventory.md)

- [2026-09-05_homeassistant_disk-cleanup.md](2026-09-05_homeassistant_disk-cleanup.md) — *closed* — stale log + old backups removed, 74%→69% disk usage; notes the MCP shell's restricted view (`du` only sees ~2.5G of the 22G `df` total)
- [2026-09-01_homeassistant_temperature-sensor-inventory.md](2026-09-01_homeassistant_temperature-sensor-inventory.md) — *closed* — full old→new entity_id mapping; dead/duplicate entities removed, dashboards + templates repointed; documents the HA `.storage` live-edit-doesn't-stick gotcha; hab-chicos Nexus (channel 3/id 12) commented out as unreliable
- [2026-08-30_homeassistant_battery-binary-sensors-and-exterior-zigbee-swap.md](2026-08-30_homeassistant_battery-binary-sensors-and-exterior-zigbee-swap.md) — *closed* — 4 rtl_433 battery sensors → `binary_sensor`; exterior Zigbee sensor `0xa4c1386e91d0faf4` → `0xa4c1380a7834ffff`, same friendly_name, zero config changes needed
- [2026-08-19_homeassistant_temperatura-exterior-parque-stale-chain.md](2026-08-19_homeassistant_temperatura-exterior-parque-stale-chain.md) — *closed* — zigbee2mqtt discovery entities never go `unavailable`; guard on `last_reported`, not `last_changed`

## docker03 decommission

**Current:** planning complete 2026-08-27; template rebuild done 2026-08-28 (CT901 replaces
CT900 as the clone source, CT900 kept as rollback, not deleted). CT206 `zigbee2mqtt` created
2026-08-28; dongle moved and cutover done 2026-09-05 — CT206 now serves the live Zigbee
network, docker03's copy kept only as rollback pending a soak period. CT207 `rtl433` created
and proven working 2026-09-05 (test dongle since removed, CT207 stopped). On cygnus: iperf3
image pulled/tested and `proxmox_backup_checker` migrated 2026-09-05 (cron at 8:05, new `mp5`
read-only whole-tree backup mount, email intentionally left unconfigured, Pushover confirmed
working); `backup.sh` needed no migration (cygnus already runs its own); uptime-kuma and
mqtt-explorer migrated, cloudflaretunnel went to its own dedicated CT103 instead (not
cygnus) — all three confirmed live, docker03's copies stopped. beszel-agent: CT206 now has
it (native systemd, 2026-09-06), cygnus's copy switched from native systemd to a podman
container the same day, CT207's is deliberately deferred until production →
[2026-09-06_beszel-fleet-disk-alerting.md](2026-09-06_beszel-fleet-disk-alerting.md).
**docker03 (VM 102) was shut down 2026-09-06 16:11 and is not in use — cooldown before
deletion has started; nothing runs there any more, and `onboot` was set to `0` on 2026-09-10
so a gr-srv03 reboot no longer resurrects it (and its rollback zigbee2mqtt).** The deletion
date remains outstanding, as do mosquitto/pool_heat/dynu/
mqtt_log/apache2/portainer/orphaned projects (dropped, not migrated; fail2ban lives on
cygnus) →
[memory_docker03-decommission.md](memory_docker03-decommission.md)

- [memory_docker03-decommission.md](memory_docker03-decommission.md) — **open** — full inventory + destination for every service, cron job, and mount; **VM stopped 2026-09-06, in cooldown; `onboot: 0` since 2026-09-10**
- [2026-09-06_gr-srv03_ct103-cloudflare-migration-plan.md](2026-09-06_gr-srv03_ct103-cloudflare-migration-plan.md) — **open** — CT103 is the last non-Turnkey LXC on Debian 12; clone-CT901/reinstall-cloudflared plan sketched, not started, <30 min job
- [2026-08-28_gr-srv03_ct901-new-template.md](2026-08-28_gr-srv03_ct901-new-template.md) — *active* — CT901, the new 3 GB template; sudo needs a password, baked-in GitHub deploy key
- [memory_zigbee2mqtt-migration.md](memory_zigbee2mqtt-migration.md) — **open** — cutover to CT206 done 2026-09-05, no re-pairing needed; only docker03 cleanup (phase 5) remains, held for a soak period
- [2026-09-12_ct206_zigbee2mqtt-backup.md](2026-09-12_ct206_zigbee2mqtt-backup.md) — *active* — CT206's Zigbee network state now has its own nightly backup and a written restore procedure; filed under **Backups**, cross-listed here
- [memory_rtl433-lxc-ct207.md](memory_rtl433-lxc-ct207.md) — **open** — CT207 built and tested 2026-09-05; DVB-driver blacklist + whole-tree `/dev/bus/usb` bind mount pattern; permanent setup (config, service, physical dongle move) still pending

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
- [2026-09-11_gr-srv03_stale-pve-container-debug-unit.md](2026-09-11_gr-srv03_stale-pve-container-debug-unit.md) — *closed* — a failed `pct start --debug` leaves a `failed` unit that log-monitor escalates daily; check `pct status <id>` first, then `reset-failed`

## Database — castor

**Current:** Tailscale-bind race (postgres starting before `tailscale0` gets its IP)
fixed permanently 2026-09-05 with a polling `ExecStartPre` →
[2026-09-05_castor_postgresql-tailscale-bind-race.md](2026-09-05_castor_postgresql-tailscale-bind-race.md)

- [2026-09-05_castor_postgresql-tailscale-bind-race.md](2026-09-05_castor_postgresql-tailscale-bind-race.md) — *closed* — recurring bind race (also seen 2026-05-31), fixed with `wait-for-tailscale.sh`
- [memory_castor.md](memory_castor.md) — *active* — must keep `10.0.100.11` in `listen_addresses`
- [2026-05-29_castor_postgresql-setup.md](2026-05-29_castor_postgresql-setup.md) — *active*

## Web / TLS — cygnus

- [2026-06-22_cygnus_caddy-tls-pgadmin.md](2026-06-22_cygnus_caddy-tls-pgadmin.md) — *active* — Caddy + Tailscale cert renewal via root cron
- [2026-08-04_cygnus_caddy-cert-ari-stuck-order.md](2026-08-04_cygnus_caddy-cert-ari-stuck-order.md) — *closed* — Let's Encrypt ARI stuck order, self-resolved 2026-08-10

## NAS project

**Current:** **chassis DECIDED 2026-09-10 — TerraMaster F4-424 Pro (i3-N305 8-core, 32 GB),
$687 Amazon → $1,121.90 total** (chassis + 2× 6 TB recert from goHardDrive + Patriot P310 480 GB
boot NVMe). Nothing ordered yet. **This replaces the 09-08 F4-425 Plus N150 decision, which rested
on a price that never existed** — the **fifth** price/spec error on this chassis and the first that
was ours: $479.99 was the **N95/8 GB** price, scraped from a store page that sells only the N95 and
then applied to the N150. Real 09-10 prices: N150/16 GB **$649** (list $649.99, best-ever $519.99),
N95/8 GB $479. The gap is 8 GB of DDR5 at shortage pricing, **not a lapsed sale**, so waiting will
not bring it back — and it put the Pro line only **$38** above the N150. **The 09-08 price-target
table is void**; its "walk away above $520" was the SKU's historical *floor*. User's call, and the
right one: *"now all is 1 GbE… the RAM will make a much larger difference in the long term."* The
F4-424 Pro doubles cores and RAM for +$38, losing only 5GbE (→2× 2.5GbE, unused either way on a
1 GbE LAN) and one M.2 slot (3→2, one is needed); it also has a **published Proxmox install guide**
and the same BIOS menu names the runbook already uses. **Trust only the vendor product page or
datasheet matched to the exact SKU — and only a price the same page will actually sell you.**
**At 32 GB the RAM question is closed** — the stack's two compromises were already withdrawn at
16 GB: ARC gets 4 GB (not 1–2) and
**Immich ML stays on**, so face recognition and smart search survive; the "PBS on the PVE host"
fallback is dead *on RAM grounds* — **but it was revived 2026-09-12 on recovery grounds**, see the
cross-backup design below. Growth path is a second mirror vdev in the spare bays (→10.9 TiB), never RAIDZ;
the spare M.2 slots get no L2ARC and no `special` vdev. **Service placement settled 2026-09-11** — one-week rule, **no clustering**, critical services and the radios stay on gr-srv03, NAS takes the data-heavy load; see the placement rulebook, whose dependency audit runs at commissioning. **Backup design settled 2026-09-12: a PBS on *each* host, each backing up the other** — no sync jobs, plus a 3–7 day local copy on gr-srv03 so neither box's death erases the other's history; host config needs a separate `proxmox-backup-client` job (guest backups carry the guest config only), and the share data is never in PBS at all. **Stack design otherwise unchanged** —
PVE + ZFS mirror, all LXCs, host owns the disks and bind-mounts them; **Samba: unprivileged LXC
with `idmap=passthrough`** (privileged containers cannot use the option at all); **Immich: podman,
no Docker**.
**BACKUP_A/B cable settled 2026-09-11: UGREEN 10841, 1 m, 22 AWG** — 1 m *deliberately*, because
the F4-424 Pro has no front port and the NAS will not be easily reachable, so the weekly swap must
happen where the drive can be seen; gauge beats length ~4:1, so never trade a published 22 AWG for a
shorter unknown cable. Buy two. Also corrected there: **A and B are different drives** (WD Elements
4 TB / Toshiba Canvio 3 TB), both Micro-B, so one cable type serves the rotation — verify the socket
on *both* before travelling.
**Also settled 2026-09-07: BACKUP_A/B rotation moves to the NAS** — freeing gr-srv03's third USB
port and making the ordered RSH-A10 unnecessary (keep it anyway: it is the fleet's only
PPPS/`uhubctl` device). **Open:** disks are now bought *after* the chassis (schedule risk — the SATA bays
cannot be tested until a drive is in); a ~$180 third drive as a cold spare; the F4-424 Pro's **USB
port count/connector types** (vendor says 2 rear, no front — confirm on unboxing, BACKUP_A/B plugs
in there); the US acceptance test (**runbook written 09-08, corrected 09-10 for the new chassis,
not yet run** — a 15-min PVE install on the NVMe makes the box an SSH target on arrival day, so the
chassis is testable before the drives exist; note **TOS aborts long SMART tests unless Hard Drive
Sleep is set to Never**); and **how ceres' restic jobs reach BACKUP_A/B once it hangs off the NAS**, which is
still undesigned. Last unverified purchase item: noise from the 7200 rpm recert drives — the
datasheet dB(A) figure is standby-only, so it can only be judged in the USA, inside the return
window.

- [2026-09-12_nas-gr-srv03_pbs-cross-backup-design.md](2026-09-12_nas-gr-srv03_pbs-cross-backup-design.md) — **open** — **the backup + recovery design**: cross-target PBS (each host backs up to the peer, no sync jobs and why local-first+sync was rejected), the 3–7 day local short-retention copy, PBS on the PVE host rather than in an LXC, exactly what host configuration a guest backup does **not** contain, the restore prerequisites that must live off both boxes (encryption key, API token, TLS fingerprint), and a recovery outline per direction. Also records that `backup_usb1` is a **Kingston XS1000 SSD**, never hot-plugged and unrelated to the BACKUP_A/B USB trouble
- [2026-09-11_nas-gr-srv03_service-placement-rules.md](2026-09-11_nas-gr-srv03_service-placement-rules.md) — **open** — **the placement rulebook for the two-server fleet**: the one-week rule, split by volatility not capacity, **no clustering** (and why — ZFS, quorum coupling, self-fencing, irreversibility), one-way dependencies, DBs live with their service, PBS stays on the NAS with an off-box encryption key. **Its §7 dependency audit is a NAS-commissioning task** — and flags that the NAS frees no gr-srv03 RAM, so the VM 102 decommission is now a prerequisite
- [2026-09-11_nas_alder-lake-n-cpu-comparison.md](2026-09-11_nas_alder-lake-n-cpu-comparison.md) — *active* — silicon-only reference: i3-N305 vs N150 vs N95 (vs gr-srv03's N97). Same Gracemont core in all three, so single-thread is identical — the N305 buys parallel throughput only, and the N95 is beaten outright by the N150 at 6 W. Media engine identical (AV1 decode only), single-channel RAM on all
- [2026-09-10_nas-chassis-price-correction-f4-424-pro.md](2026-09-10_nas-chassis-price-correction-f4-424-pro.md) — **open** — **current chassis decision (F4-424 Pro, $687, total $1,121.90)**; why the $479.99 N150 price was never real and the 09-08 price targets are void; the five-SKU price table at real 09-10 prices; the accepted trade-offs (2.5GbE, 2× M.2, 32 GB ceiling) — do not re-open them
- [2026-09-08_nas-us-acceptance-test-runbook.md](2026-09-08_nas-us-acceptance-test-runbook.md) — **open** — **the field procedure**, **corrected 2026-09-10 for the F4-424 Pro** (expect **32 GB**, not 16 — as written it would have told you to return a correct box; LAN 2500Mb/s; 2 M.2 / 2 rear USB): ISO links (SystemRescue 13.02, PVE 9.2-1), USB prep, a 15-min Proxmox install on the NVMe that makes the NAS an SSH target, the overnight SMART run, pass/fail table, troubleshooting. Self-contained — follow this one on the trip
- [2026-09-08_nas-chassis-decision-and-acceptance-test.md](2026-09-08_nas-chassis-decision-and-acceptance-test.md) — **open** — **§1 and its price targets are superseded by the 09-10 doc — do not act on them**; the rest stands: the 16 GB RAM allocation; the BACKUP_A/B cable spec and the chosen cable (UGREEN 10841, 1 m, 22 AWG — §3 updated 09-11, and its port-layout premise corrected); gr-srv03 hub reassessment; *why* the acceptance test is shaped as it is (§5 procedure moved to the runbook)
- [2026-09-07_nas-software-stack.md](2026-09-07_nas-software-stack.md) — **open** — base OS, guests, share protocols, disk topology; **its two RAM sections are superseded by the 09-08 doc**, the rest is current; **restore source verified 2026-09-07** (BACKUP_B restic repo sound and complete — S3 Glacier is *not* the restore source)
- [memory_nas-project.md](memory_nas-project.md) — **open** — scope, sizing, buy list, rejected options
- [2026-08-20_nas-disk-prices-and-raid-options.md](2026-08-20_nas-disk-prices-and-raid-options.md) — *active* — prices, RAID layouts, recert sourcing. **Corrects §5/§9 of the 08-19 doc**; itself **corrected 2026-09-07 and again 2026-09-08** on the F4-425 Plus RAM (16 GB is the N150 SKU). Verify stock before ordering
- [2026-08-19_nas-hardware-research.md](2026-08-19_nas-hardware-research.md) — *active* — market context and OS choice. **§5 and §9 enclosure specs are wrong** — see above; §9's "buy RAM pre-installed" advice is void

## Tooling and workstation

**Current:** log-monitor covers 6 hosts and is healthy as of 2026-09-11. Two collection bugs
found and fixed in quick succession: the `adm`/`systemd-journal` blind spot (08-26) and the
`collect.sh` SIGPIPE it then exposed (08-30) →
[2026-08-30_log-monitor_collect-sigpipe.md](2026-08-30_log-monitor_collect-sigpipe.md).
Two standing daily false positives cleared 09-11 — a stale `pve-container-debug@203` unit on
gr-srv03 and networkd `wait-online` timeouts on mosquitto (see the Proxmox and MQTT threads).
**A stale `failed` unit escalates every day until `reset-failed`** — check whether the thing
it names is actually running before investigating the report's hypothesis.

- [2026-06-30_log-monitor.md](2026-06-30_log-monitor.md) — *active* — daily log review from comet; architecture, `SUPPRESS_PATTERN`, adding a host
- [2026-08-30_log-monitor_collect-sigpipe.md](2026-08-30_log-monitor_collect-sigpipe.md) — *closed* — 4-day contabo2 blackout reported as "(ssh error)"; was `head`+`pipefail`+`set -e`. Suppression now runs remotely before the cap
- [2026-08-30_comet_homeassistant-mcp-ssh-mcp-v2-password-flag.md](2026-08-30_comet_homeassistant-mcp-ssh-mcp-v2-password-flag.md) — *closed* — unpinned `npx -y ssh-mcp` auto-updated to v2, dropped `--password`; only the password-auth `homeassistant` connector broke
- [memory_comet_zed-tmux-claude.md](memory_comet_zed-tmux-claude.md) — *closed* — Zed + tmux + Claude workflow
- [memory_feedback.md](memory_feedback.md) — *active* — **working preferences; read first**

## living1

- [2025-03-07_living1_description.md](2025-03-07_living1_description.md) — *active* — hardware/OS inventory
- [2025-12-13_living1_wifi-fix.md](2025-12-13_living1_wifi-fix.md) — *closed* — internal RTL8723AE blacklisted, USB RTL8188FTV used away from home
- [2026-03-04_living1_hdmi-audio-fix.md](2026-03-04_living1_hdmi-audio-fix.md) — *closed*

## openclaw (contabo2)

- [2026-08-31_contabo2_openclaw-heartbeat-cost.md](2026-08-31_contabo2_openclaw-heartbeat-cost.md) — *closed* — 20-min heartbeat + Aug 11 anthropic.env wiring drove ~$1/day Haiku cost; disabled via `config unset`

## Other hosts

- [2026-06-25_raspberrypi2z_setup-and-security.md](2026-06-25_raspberrypi2z_setup-and-security.md) — *active* — sudo needs a password; no SSH password auth
- [RaspberryPi3Bplus_Slow_Ethernet_Fix.md](RaspberryPi3Bplus_Slow_Ethernet_Fix.md) — *closed* — raspberrypi1
- [2026-02-24_migration_to_contabo2.md](2026-02-24_migration_to_contabo2.md) — *closed* — all phases completed by 2026-03-07
