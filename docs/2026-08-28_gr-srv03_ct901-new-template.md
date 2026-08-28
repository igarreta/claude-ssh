# gr-srv03: CT901 — new 3 GB Debian 13 template

**Status:** active
**Host:** gr-srv03
**Supersedes:** —
**Superseded-by:** —

## Why

CT900 (`deb13templ1`) was the standing template for new LXCs but had a 6 GB rootfs — too
large for the [docker03 decommission](memory_docker03-decommission.md) plan, which needs
two new 3 GB LXCs (zigbee2mqtt, rtl_433). Real usage on CT900 was only 1.6 GiB, so a
same-size clone wasn't needed — a smaller restore target was.

## What was done (2026-08-28)

1. Fresh `vzdump` of CT900 (stopped-mode, `backup_usb1_vm_containers`).
2. `pct restore 901 <archive> --storage local-lvm --rootfs local-lvm:3` — vzdump is a file-level
   tar, so restoring into a smaller rootfs than the source needs no filesystem-resize step, as
   long as content fits (1.6 GiB into 3 GB).
3. Regenerated the network MAC (`pct set 901 -net0 ...` without `hwaddr=`) — the restored
   config kept CT900's original MAC, which would collide if both CTs were ever booted together.
4. Booted 901, ran `apt-get update && apt-get -y dist-upgrade`, then `dpkg --configure -a`
   (the dist-upgrade's post-install triggers didn't finish inside the tool's 60s exec window —
   check `dpkg --audit` after any long apt run driven the same way), `apt-get -y autoremove
   --purge` (nothing to remove), `apt-get clean` (freed 265 MB), then rebooted (systemd, libc,
   openssh-server were all upgraded).
5. `pct shutdown 901` + `pct template 901` — marks the rootfs LV read-only
   (`base-901-disk-0`) so it can be cloned.

## Result

- 3 GB rootfs (`local-lvm:vm-901-disk-0` → templated to `base-901-disk-0`), 1.4 GB used / 1.4 GB
  free (50%) after cleanup — matches the mosquitto-based sizing estimate in the decommission doc.
- Debian 13 (trixie), fully patched at creation time, `dpkg --audit` clean, no failed
  systemd units, network confirmed via DHCP.
- **CT900 was deliberately kept, not destroyed** (user decision, 2026-08-28) — retained as
  rollback for some time. Ignore it for new clones; CT901 is now the template to clone from.

## Inventory (for anyone cloning from CT901)

- **User:** `rsi` (uid 1000), in `sudo` group. No `/etc/sudoers.d/` override beyond the
  stock README → **sudo requires a password** on any CT cloned from this template.
- **SSH:** `~/.ssh/id_ed25519` is a **baked-in personal key** used as a GitHub deploy key for
  `git@github.com:igarreta/bin.git` (cloned at `~/bin`, a personal script collection). No
  `authorized_keys` — inbound login is by password only, not this key. Every LXC cloned from
  this template inherits the same private key and github.com push access — be aware if cloning
  for anything beyond personal script provisioning.
- `~/etc`, `~/var`, `~/bak` — empty placeholder directories, no content.
- **nftables**: table `inet filter` exists but every chain policy is `accept` — no active
  firewall rules despite the package being installed.
- **apache2 + gitweb**: enabled as a side effect of `git-all`'s `gitweb` dependency, not an
  intentionally configured web service. Stock default page.
- **postfix**: `inet_interfaces = loopback-only`, no relayhost — local mail only, not
  internet-facing.
- Timezone `Etc/UTC`, NTP client inactive (systemd-timesyncd is enabled though, so it will
  sync once network is confirmed working after clone).
- `apt-daily.timer` / `apt-daily-upgrade.timer` are enabled (default Debian behavior — unlike
  the Proxmox *host*, which has these disabled per
  [2026-05-13_gr-srv03_disable-apt-timers.md](2026-05-13_gr-srv03_disable-apt-timers.md); that
  fix was host-scoped and wasn't carried into this LXC template).
- No cron jobs for `rsi` or `root`.
