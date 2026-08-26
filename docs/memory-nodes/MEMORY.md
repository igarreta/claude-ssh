# Memory Index

Pointers only — one line per memory, never content. Detail lives in the node file;
full write-ups live in `docs/` of the claude-ssh repo (start at `docs/INDEX.md`).

## Working preferences

- [feedback_docs_location.md](feedback_docs_location.md) — docs and memories go in `docs/` of the claude-ssh repo, not on the remote host
- [feedback_pushover_errors_only.md](feedback_pushover_errors_only.md) — Pushover is for errors only, never success or routine status
- [feedback_https_urls_only.md](feedback_https_urls_only.md) — always give HTTPS URLs; the browser refuses plain HTTP
- [feedback_zed-agent-panel-breaks-ssh-mcp.md](feedback_zed-agent-panel-breaks-ssh-mcp.md) — Zed's embedded agent panel breaks every ssh-mcp connector; launch via `tmux-claude.sh`
- [feedback_docker03_sudo.md](feedback_docker03_sudo.md) — docker03 sudo needs a password; use `qm guest exec 102` from gr-srv03 for root diagnostics
- [feedback_raspberrypi2z_sudo.md](feedback_raspberrypi2z_sudo.md) — raspberrypi2z sudo needs a password; write locally, scp, have the user run it
- [feedback_no_passwordless_sudo_castor.md](feedback_no_passwordless_sudo_castor.md) — keep castor's sudo requiring a password
- [feedback_cygnus_podman_compose.md](feedback_cygnus_podman_compose.md) — on cygnus use `sudo podman compose`, not `sudo podman-compose`
- [feedback_sudo_commands_no_ssh_wrap.md](feedback_sudo_commands_no_ssh_wrap.md) — never wrap a sudo command in `ssh` — user runs it in a session already open on the host
- [feedback_mcp_ssh_no_true_parallelism.md](feedback_mcp_ssh_no_true_parallelism.md) — "parallel" MCP run-command calls execute sequentially; background both in one command to test races
- [feedback_dont-trust-vendor-fix-on-prod.md](feedback_dont-trust-vendor-fix-on-prod.md) — verify a tool's own suggested fix against this host's actual config before running it on a live service

## Open — needs follow-up

- [project_docker03_zigbee_rf_degradation.md](project_docker03_zigbee_rf_degradation.md) — coordinator LQI 200→134 after 08-17 dongle move; 08-25 final wall-mounted placement lifted it to ~220; recheck 2026-09-09
- [project_nas.md](project_nas.md) — purchase-ready 2026-08-24; only P1-vs-P2 still open
- [project_backup_health_monitor.md](project_backup_health_monitor.md) — deployed 08-15, tests being finished
- [project_raspberrypi2z_pool-thermometer.md](project_raspberrypi2z_pool-thermometer.md) — WT0124 bought, not yet integrated
- [project_docker03_rtl-test.md](project_docker03_rtl-test.md) — garage-remote 433 MHz capture, unfinished

## Backups and storage

- [project_ceres_empty_snapshots.md](project_ceres_empty_snapshots.md) — 7 months of empty backups, cause never reproduced across 3 probe readings; closed 2026-08-26, health monitor is now the safety net
- [project_backup_schedule.md](project_backup_schedule.md) — **read before adding any job**: the 02:25–03:30 disk-wake window
- [project_gr-srv03_powered-hub-instability.md](project_gr-srv03_powered-hub-instability.md) — Zigbee drops were BACKUP_A/_B hot-plug transients on the shared 5V rail
- [project_contabo2_nfs-backup-rclone-fix.md](project_contabo2_nfs-backup-rclone-fix.md) — NFS over WAN hung; migrated to rclone/SFTP
- [project_ceres_wdmycloud_glacier.md](project_ceres_wdmycloud_glacier.md) — WDMyCloud → S3 Glacier; pruning the old snapshot isn't worth it
- [project_gr-srv03_stale-mount-investigation.md](project_gr-srv03_stale-mount-investigation.md) — LXC bind mounts can't survive a host remount; reboot is the fix

## Services and hosts

- [project_castor_postgres.md](project_castor_postgres.md) — PostgreSQL 17 on LXC 205; must keep `10.0.100.11` in `listen_addresses`
- [project_cygnus_podman_restart_policy.md](project_cygnus_podman_restart_policy.md) — containers survive reboots only if the restart filter matches `unless-stopped`
- [project_docker03_zigbee2mqtt.md](project_docker03_zigbee2mqtt.md) — 07-15 outage from USB re-enumeration; stable `by-id` mapping + watchdog
- [project_mosquitto_broker_migration.md](project_mosquitto_broker_migration.md) — migration done; all 7 clients cut over, old docker03 broker stopped 08-26 (not yet removed)
- [project_docker03_tailscale-key-expiry-2026-08-17.md](project_docker03_tailscale-key-expiry-2026-08-17.md) — node-key expiry, not the USB storm; MagicDNS-only resolv.conf broke container DNS
- [project_docker03_fail2ban.md](project_docker03_fail2ban.md) — no rsyslog meant no auth.log; fixed with `backend = systemd`
- [project_comet_tailscale_logout.md](project_comet_tailscale_logout.md) — corrupted `tailscaled.state`; unprivileged `journalctl` fakes outages
- [project_comet_zed_tmux_claude.md](project_comet_zed_tmux_claude.md) — the working Zed + tmux + Claude Code setup
- [project_raspberrypi2z_setup.md](project_raspberrypi2z_setup.md) — Pi Zero W for 433 MHz sensors; hardened SSH and sudo
- [project_gr-srv03_vm100_stopped.md](project_gr-srv03_vm100_stopped.md) — VM 100 is stopped on purpose; ignore it in outage checks
- [project_raspberrypi1_watchdog.md](project_raspberrypi1_watchdog.md) — BCM2835 hardware watchdog armed since 06-25; closes the Jun 2026 hard-freeze gap
- [project_cygnus_caddy_tls.md](project_cygnus_caddy_tls.md) — Tailscale cert via root cron; the 08-04 ARI renewal failure self-resolved 08-10

## Heating and home automation

- [project_raspberrypi1_ttato_mqtt_drop.md](project_raspberrypi1_ttato_mqtt_drop.md) — command subscription dropped on reconnect; fixed with `on_connect` resubscribe
- [project_raspberrypi1_ttato_manual_heating.md](project_raspberrypi1_ttato_manual_heating.md) — Manual mode fired the boiler on phantom 0 °C readings
- [project_raspberrypi1_ttato_granev.md](project_raspberrypi1_ttato_granev.md) — TTato never subscribed to HA's `granev/temp/*`; fixed 07-20
- [project_homeassistant_stale_sensor_chain.md](project_homeassistant_stale_sensor_chain.md) — guard on `last_reported`, not `last_changed`; z2m entities never go `unavailable`
