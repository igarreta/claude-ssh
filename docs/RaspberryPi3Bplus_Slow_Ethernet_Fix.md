# Raspberry Pi 3B+ Slow Ethernet Fix

**Date:** 2026-02-27
**Host:** raspberrypi1

## Symptom

Ethernet speed was ~9 Mbps while WiFi gave ~100 Mbps on the same Deco M5 hub. A notebook connected to the same ethernet port achieved 200+ Mbps, ruling out a cable or switch problem.

Test command used:
```bash
docker run --rm networkstatic/iperf3 -c 192.168.1.8 -f m -V -t 5
```

## Root Cause

The kernel boot parameter `dwc_otg.speed=1` was set in `/boot/firmware/cmdline.txt`. This forces the DWC OTG USB host controller to operate in **Full Speed mode (12 Mbps)** instead of High Speed (480 Mbps).

On the Raspberry Pi 3B+, the ethernet chip (SMSC LAN7800, `0424:7800`) is connected internally via USB through two SMSC 2514 USB hubs. With Full Speed forced, the entire USB hub chain ran at 12 Mbps:

```
/:  Bus 01.Port 1: Dev 1, Class=root_hub, Driver=dwc_otg/1p, 480M
    |__ Port 1: Dev 2, If 0, Class=Hub, Driver=hub/4p, 12M      ← should be 480M
        |__ Port 1: Dev 3, If 0, Class=Hub, Driver=hub/3p, 12M  ← should be 480M
            |__ Port 1: Dev 4, If 0, Class=Vendor Specific Class, Driver=lan78xx, 12M  ← ethernet
```

Protocol overhead on a 12 Mbps USB link explains the observed ~9 Mbps ethernet throughput.

dmesg confirmed the issue at boot:
```
usb 1-1: new full-speed USB device number 2 using dwc_otg
usb 1-1: not running at top speed; connect to a high speed hub
```

## Fix

Remove `dwc_otg.speed=1` from `/boot/firmware/cmdline.txt` and reboot.

```bash
sudo cp /boot/firmware/cmdline.txt /boot/firmware/cmdline.txt.bak
sudo sed -i 's/ dwc_otg.speed=1//' /boot/firmware/cmdline.txt
sudo reboot
```

After reboot, the USB hub chain enumerates at High Speed (480 Mbps) and ethernet throughput reaches the Pi 3B+ practical maximum (~200-300 Mbps, limited by USB 2.0).

## Notes

- `dwc_otg.speed=1` is sometimes set intentionally to work around USB compatibility issues with specific external devices. Check for connected USB devices before applying this fix.
- The backup of the original cmdline.txt is at `/boot/firmware/cmdline.txt.bak`.
