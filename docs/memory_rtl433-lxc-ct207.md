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

## Next steps

- When making this permanent: physically move the RTL2838 dongle from docker03 to gr-srv03,
  write `/etc/rtl_433/rtl_433.conf` + systemd unit mirroring raspberrypi2z's pattern, pick an
  MQTT topic prefix that doesn't collide with raspberrypi2z's production
  `rtl_433/raspberrypi2z`.
- fail2ban + beszel-agent still need adding, per the decommission doc's "new dedicated LXCs"
  section.
- Not confirmed whether the dongle used in this test session is the same physical unit
  currently on docker03, or a second one — worth checking before the real cutover.
