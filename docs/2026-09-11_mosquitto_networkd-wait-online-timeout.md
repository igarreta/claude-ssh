# mosquitto: systemd-networkd-wait-online timeouts from apt-daily

**Status:** closed
**Host:** mosquitto
**Supersedes:** —
**Superseded-by:** —

## What happened

log-monitor reported `warning` on mosquitto every day for at least a week (2026-09-08 →
2026-09-11 in the archive, probably since the LXC was built):

```
3 systemd-networkd-wait-online: Timeout occurred while waiting for network connectivity.
```

The broker was never affected — MQTT stayed up throughout, on 1883 and 8883.

## Root cause

`systemd-networkd` was running but managed **nothing**:

```
IDX LINK       TYPE     OPERATIONAL SETUP
  1 lo         loopback carrier     unmanaged
  2 eth0       ether    routable    unmanaged
  4 tailscale0 none     routable    unmanaged

/etc/systemd/network/   → empty
networking.service (ifupdown)  → active     ← this is what configures eth0 (DHCP)
systemd-networkd.service       → disabled, but ACTIVE
systemd-networkd.socket        → enabled, active   ← socket-activated the service
```

`apt-daily` calls `apt-helper`, which tests `is-active systemd-networkd`; seeing it active,
it invokes `/lib/systemd/systemd-networkd-wait-online` **directly** and waits 30 s for links
that networkd will never configure, then exits 1:

```
10:51:39 systemd[1]: Starting apt-daily.service - Daily apt download activities...
10:52:10 systemd-networkd-wait-online[10849]: Timeout occurred while waiting for network connectivity.
10:52:10 apt-helper[10846]: E: Sub-process /lib/systemd/systemd-networkd-wait-online returned an error code (1)
10:52:10 systemd[1]: apt-daily.service: Deactivated successfully.
```

apt-daily then *finishes successfully* — the timeout cost 30 s and two log lines, nothing else.

## Not the same as the contabo2 case

contabo2 emits the identical two log lines and they are suppressed there via
`SUPPRESS_PATTERN` in `log-monitor/hosts/contabo2.conf`. **The cause is different.** On
contabo2, networkd *does* manage eth0 but its SETUP state never leaves `configuring`
(see [2026-06-30_log-monitor.md](2026-06-30_log-monitor.md)). On mosquitto, networkd manages
zero links, so the wait can never succeed. Do not read contabo2's config comment as covering
this host.

## Fix

Because networkd owned no links here, the cause could be removed rather than suppressed.
Applied 2026-09-11 by the user (mosquitto sudo requires a password):

```bash
sudo systemctl disable --now systemd-networkd.socket
sudo systemctl mask systemd-networkd.service systemd-networkd.socket systemd-networkd-wait-online.service
sudo systemctl stop systemd-networkd.service
```

Masking the units does **not** stop an already-running service, and it does not block
`apt-helper` either — apt-helper runs the wait-online *binary*, not the unit. The `stop` is
what actually fixes it, by making `is-active systemd-networkd` return false.

### Two failed units left by the stop — both expected, both cleared

`systemd-networkd.service` had been up 5 d 18 h and did not exit cleanly, so systemd's
watchdog ABRT'd it → `failed (Result: watchdog)`.

`systemd-networkd-persistent-storage.service` failed on *stop*: its
`ExecStop=networkctl persistent-storage no` could not reach networkd's socket, which was
already gone → `Failed to connect to /run/systemd/netif/io.systemd.Network: Connection refused`.

```bash
sudo systemctl mask systemd-networkd-persistent-storage.service
sudo systemctl reset-failed systemd-networkd-persistent-storage.service
sudo systemctl reset-failed systemd-networkd.service
```

Left unattended, either would have escalated in log-monitor every day — the same trap as
[2026-09-11_gr-srv03_stale-pve-container-debug-unit.md](2026-09-11_gr-srv03_stale-pve-container-debug-unit.md).

## Verified after

```
failed units: none
systemd-networkd{,.socket,-wait-online,-persistent-storage}: masked
eth0 192.168.1.198/24 UP    default via 192.168.1.1    tailscale0 100.69.153.63
curl https://deb.debian.org/  → 200          DNS ok
mosquitto: active, listening 1883 + 8883
/usr/lib/apt/apt-helper wait-online → exit 0 in 0.03 s   (was: 30 s, exit 1)
```

The 2026-09-12 mosquitto report will flag the two stop-time failures once, since they fall
in that run's incremental window. The cursor was deliberately not advanced past them.

## If networkd is ever needed again

`systemctl unmask systemd-networkd.service systemd-networkd.socket
systemd-networkd-wait-online.service systemd-networkd-persistent-storage.service`, then
enable the socket. Note that eth0 would still be ifupdown's — moving it to networkd needs a
`/etc/systemd/network/*.network` file and removal from `/etc/network/interfaces`.
