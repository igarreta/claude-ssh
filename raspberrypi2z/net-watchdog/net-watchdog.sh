#!/bin/bash
STATE=/run/net-watchdog-fails

if ping -c3 -W5 192.168.1.1 > /dev/null 2>&1; then
    echo 0 > "$STATE"
    exit 0
fi

FAILS=$(cat "$STATE" 2>/dev/null || echo 0)
FAILS=$((FAILS + 1))
echo $FAILS > "$STATE"
logger -t net-watchdog "Router 192.168.1.1 unreachable (fail $FAILS)"

if [ "$FAILS" -eq 1 ]; then
    logger -t net-watchdog "Attempting Wi-Fi restart"
    nmcli radio wifi off && sleep 5 && nmcli radio wifi on
    exit 0
fi

if [ "$FAILS" -eq 2 ]; then
    logger -t net-watchdog "Still unreachable after Wi-Fi restart - waiting one more cycle"
    exit 0
fi

logger -t net-watchdog "Wi-Fi restart did not recover after 10 min - rebooting"
systemctl reboot
