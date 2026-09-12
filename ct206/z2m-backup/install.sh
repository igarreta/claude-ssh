#!/bin/bash
# Install the zigbee2mqtt state staging job inside CT206. Run as root in the container.
# Expects the files staged at /tmp/z2m-backup/ (scp'd from comet).
set -eu
install -d -m 755 /opt/z2m-backup
install -m 755 /tmp/z2m-backup/z2m-backup-stage.sh /opt/z2m-backup/z2m-backup-stage.sh
install -m 644 /tmp/z2m-backup/z2m-backup.service  /etc/systemd/system/z2m-backup.service
install -m 644 /tmp/z2m-backup/z2m-backup.timer    /etc/systemd/system/z2m-backup.timer
systemctl daemon-reload
systemctl enable --now z2m-backup.timer
systemctl --no-pager list-timers z2m-backup.timer --no-legend
