#!/bin/bash
# Install the zigbee-lqi collector inside CT206. Run as root in the container.
set -eu
systemctl disable --now zigbee-lqi.service 2>/dev/null || true
install -d -m 755 /opt/zigbee-lqi /opt/zigbee-lqi/data /opt/zigbee-lqi/state
install -m 755 /tmp/zigbee-lqi/collect.sh /opt/zigbee-lqi/collect.sh
install -m 755 /tmp/zigbee-lqi/report.sh  /opt/zigbee-lqi/report.sh
install -m 644 /tmp/zigbee-lqi/parse.awk  /opt/zigbee-lqi/parse.awk
install -m 644 /tmp/zigbee-lqi/zigbee-lqi.service /etc/systemd/system/zigbee-lqi.service
install -m 644 /tmp/zigbee-lqi/zigbee-lqi.timer   /etc/systemd/system/zigbee-lqi.timer
systemctl daemon-reload
systemctl enable --now zigbee-lqi.timer
systemctl start zigbee-lqi.service
systemctl --no-pager list-timers zigbee-lqi.timer --no-legend
