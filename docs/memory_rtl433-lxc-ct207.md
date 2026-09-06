# gr-srv03: CT207 — rtl_433 LXC (backup/test role)

**Status:** open
**Host:** gr-srv03, rtl433 (CT207)
**Supersedes:** —
**Superseded-by:** —

## Why

Part of the [docker03 decommission plan](memory_docker03-decommission.md) — rtl_433 gets its
own dedicated LXC, isolated from every other service, because container isolation does not
protect against USB/kernel-bus instability, only the LXC/VM boundary does (same reasoning as
zigbee2mqtt's CT206, see [memory_zigbee2mqtt-migration.md](memory_zigbee2mqtt-migration.md)).
Backup/test role only — raspberrypi2z remains production for real sensor readings
([2026-06-26_raspberrypi2z_rtl433-setup.md](2026-06-26_raspberrypi2z_rtl433-setup.md)).

## What was done (2026-09-05)

1. Cloned CT207 from the CT901 template: `10.0.100.13/24` on vmbr1, 512 MB RAM, 3 GB rootfs,
   `onboot=1` — same pattern as CT206.
2. **Fixed inherited Tailscale DNS.** The clone came up with Proxmox's MagicDNS resolver
   (`100.100.100.100`), which only resolves for Tailscale-joined hosts — CT207 isn't joined,
   so `apt` couldn't reach `deb.debian.org`. Fixed with `pct set 207 -nameserver 1.1.1.1
   -searchdomain granev.casa`. Note: `pct set` doesn't rewrite a running container's
   `/etc/resolv.conf` live — needed a `pct reboot` to take effect.
3. `apt install rtl-433` (25.02-1+deb13u1 from Debian repos) — native, no podman, matching the
   decommission doc's "bare install" decision.
4. **Host-level driver conflict**: the kernel's `dvb_usb_rtl28xxu` claims the RTL2838 dongle as
   a DVB-T adapter by default, which blocks rtl_433's raw libusb access. Fixed on the
   **gr-srv03 host** (not inside the container):
   - Unbind: `echo '1-1:1.0' > /sys/bus/usb/drivers/dvb_usb_rtl28xxu/unbind`
   - `rmmod dvb_usb_rtl28xxu dvb_usb_v2 dvb_core`
   - Permanent: `/etc/modprobe.d/blacklist-rtl-sdr.conf` → `blacklist dvb_usb_rtl28xxu`
   - `rc_core` stayed loaded (still used by unrelated `cec` module) — harmless, left alone.
5. Host udev rule `/etc/udev/rules.d/61-rtl-sdr.rules`:
   `SUBSYSTEM=="usb", ATTRS{idVendor}=="0bda", ATTRS{idProduct}=="2838", MODE="0666"` —
   world-writable. Simpler than the zigbee dongle's uid-shift (`OWNER=100000 GROUP=100020`)
   approach, since rtl_433 doesn't need root-owned exclusivity, just any read/write access.
6. Passthrough in `/etc/pve/lxc/207.conf`:
   ```
   lxc.cgroup2.devices.allow: c 189:* rwm
   lxc.mount.entry: /dev/bus/usb dev/bus/usb none bind,optional,create=dir 0 0
   ```
   `189` is the USB-bus char-device major. Binds the **whole** `/dev/bus/usb` tree rather than
   one bus/device path — a directory bind mount is a live view of the same devtmpfs, so a
   re-enumeration (new device number after replug) doesn't break it, unlike a single-path bind.
   Contrast with zigbee's stable-symlink-by-serial approach, which works there because it's a
   `tty` device; a raw USB device has no equivalent stable symlink via udev alone.
7. **Verified live reception** (45s test capture, 433.92 MHz): Nexus-TH sensors decoded
   correctly — id 12/channel 3, id 88/channel 1, id 33/channel 2. id 12/channel 3 matches the
   "hab_chicos" sensor already disabled in Home Assistant for unreliability
   ([2026-09-01_homeassistant_temperature-sensor-inventory.md](2026-09-01_homeassistant_temperature-sensor-inventory.md)) —
   it showed `battery_ok:0` here too, consistent with that call.

## Current state (end of session, 2026-09-05)

The dongle was only **temporarily connected for testing** — required disconnecting BACKUP_B
from its host USB port. Both reverted: dongle removed, BACKUP_B reconnected at
`/mnt/backup_b`. **CT207 stopped.** `rtl-433` is installed and proven working, but no
`/etc/rtl_433/rtl_433.conf` or systemd service written yet — no point while the dongle isn't
attached. All host-side changes (blacklist, udev rule, LXC passthrough config) are permanent
and need no rework next time the dongle is connected.

## Second test — dongle physically moved from docker03 (2026-09-05, later session)

Dongle moved from docker03 to gr-srv03 and re-tested. Confirmed working. **CT207's role is
now settled as permanent test/backup only** — the user does not plan to move raspberrypi2z's
production rtl_433 service here, because gr-srv03 is the wrong physical location for antenna
reception of the sensors raspberrypi2z currently captures. This LXC exists to let rtl_433
issues be diagnosed/tested without touching the production Pi, not to replace it.

**fail2ban dropped from the plan** — CT207 (like CT206) is reachable only via Tailscale, no
public exposure, so fail2ban adds nothing. beszel-agent still applies.

**dmesg from this test session, saved in case the service is ever moved here for real** (the
DVB driver grabbed the dongle again despite the blacklist — needs to be understood before any
production dependency is placed on this passthrough):

```
usb 1-1: New USB device found, idVendor=0bda, idProduct=2838, bcdDevice= 1.00
usb 1-1: Product: RTL2838UHIDIR
usb 1-1: dvb_usb_v2: found a 'Realtek RTL2832U reference design' in warm state
usb 1-1: dvb_usb_v2: will pass the complete MPEG2 transport stream to the software demuxer
dvbdev: DVB: registering new adapter (Realtek RTL2832U reference design)
dvbdev: dvb_create_media_entity: media entity 'dvb-demux' registered.
rtl2832 11-0010: Realtek RTL2832 successfully attached
usb 1-1: DVB: registering adapter 0 frontend 0 (Realtek RTL2832 (DVB-T))...
dvbdev: dvb_create_media_entity: media entity 'Realtek RTL2832 (DVB-T)' registered.
rtl2832_sdr rtl2832_sdr.1.auto: Registered as swradio0
rtl2832_sdr rtl2832_sdr.1.auto: Realtek RTL2832 SDR attached
rc rc0: Realtek RTL2832U reference design as /devices/pci0000:00/0000:00:14.0/usb1/1-1/rc/rc0
rc rc0: lirc_dev: driver dvb_usb_rtl28xxu registered at minor = 0, raw IR receiver, no transmitter
input: Realtek RTL2832U reference design as .../rc/rc0/input10
usb 1-1: dvb_usb_v2: schedule remote query interval to 200 msecs
usb 1-1: dvb_usb_v2: 'Realtek RTL2832U reference design' successfully initialized and connected
usbcore: registered new interface driver dvb_usb_rtl28xxu
[~636s later]
dvb_usb_v2: 'Realtek RTL2832U reference design:1-1' successfully deinitialized and disconnected
usbcore: deregistering interface driver dvb_usb_rtl28xxu
```

`lsmod` afterward showed `dvb_usb_rtl28xxu` **not** loaded and `rtl2832`/`rtl2832_sdr` present
— consistent with the documented manual unbind-then-blacklist procedure being followed again
during this session, not the blacklist alone preventing the initial grab. **Open question,
relevant only if this service is ever made permanent:** whether
`/etc/modprobe.d/blacklist-rtl-sdr.conf` actually prevents the hotplug auto-load at all (it
didn't here) and the workflow always requires a manual unbind after each replug, or whether
something else (initramfs not rebuilt after the blacklist was added?) is undermining it.

## Next steps

Since CT207 stays test/backup-only, there's no forcing function to finish the permanent
config — treat these as "do if/when actually needed for a test," not open decommission work:

- `/etc/rtl_433/rtl_433.conf` + systemd unit mirroring raspberrypi2z's pattern, MQTT topic
  prefix distinct from `rtl_433/raspberrypi2z`, only worth writing once a dongle is left
  attached for more than a one-off test.
- beszel-agent still needs adding (fail2ban dropped, see above).
- Not confirmed whether the dongle used in testing is the same physical unit that was on
  docker03, or a second one — worth checking if it ever matters (e.g. warranty, RTL2832 chip
  variant differences).
