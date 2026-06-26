# raspberrypi2z setup and initial security review (2026-06-25)

## Overview

New node, Raspberry Pi Zero W, Tailscale IP `100.92.195.47`. Will receive
temperature readings from 433 MHz devices (rtl_433 not yet installed/configured
as of this review). Same comet SSH key as raspberrypi1 (`~/.ssh/id_ed25519_comet`).

- OS: Raspbian GNU/Linux 13 (trixie), kernel `6.18.34+rpt-rpi-v6` (armv6l)
- User: `rsi` (only non-system shell user besides `root`)
- Added to `.mcp.json` as `raspberrypi2z`, added to `mcp-connectors.md` table and
  keyscan list, added to CLAUDE.md host inventory.

## Key setup issue (resolved)

Initial SSH key auth from comet failed even after the user copied
raspberrypi1's `authorized_keys` to this host. Two separate problems found
and fixed:

1. `~/.ssh/authorized_keys` was `664` (group-writable) — OpenSSH `StrictModes`
   (default `yes`) silently rejects pubkey auth when `authorized_keys` is
   writable by group/other. Fixed: `chmod 600 ~/.ssh/authorized_keys`.
2. The comet pubkey itself was missing from the copied `authorized_keys`
   (raspberrypi1's file has it, this one didn't carry over). Fixed: appended
   the comet pubkey, then re-chmod 600.

Lesson: when cloning `authorized_keys` between hosts, diff/verify the actual
key strings, not just file presence — a "copy" can silently drop entries.

## Security review findings (as found, before fixes below)

- **Passwordless sudo** for `rsi` via `/etc/sudoers.d/90-cloud-init-users`
  (`rsi ALL=(ALL) NOPASSWD:ALL`, cloud-init generated). Contrast with castor
  where the user explicitly wants sudo to require a password.
- **SSH password authentication was enabled** (`PasswordAuthentication yes`,
  effective via `sshd -T`), and sshd listens on `0.0.0.0:22` (all
  interfaces), not just Tailscale. `rsi` has a real password hash (not
  locked). Combined with no `fail2ban` and no host firewall rules beyond
  Tailscale's own `ts-input`/`ts-forward` chains (no ufw, no custom
  iptables/nft), this host was brute-forceable from anything that can reach
  it on the LAN. Internet exposure depends on router port-forwarding, not
  checked from this review.
- `PermitRootLogin without-password` — root login requires a key (no
  root password login), acceptable.

## Fixes applied (2026-06-25)

- Removed `/etc/sudoers.d/90-cloud-init-users` (the NOPASSWD rule). `rsi` is
  still in the `sudo` group, which has `%sudo ALL=(ALL:ALL) ALL` in
  `/etc/sudoers` (password required) — so sudo still works, just prompts now.
  Verified: `sudo -k; sudo -n true` → "a password is required".
- Disabled SSH password auth via
  `/etc/ssh/sshd_config.d/99-disable-password-auth.conf` containing
  `PasswordAuthentication no`, then `sshd -t && systemctl reload ssh`.
  Verified: a password-only auth attempt (`PubkeyAuthentication=no`) is now
  rejected; comet key-based login still works.
- Decided against installing fail2ban: with password auth disabled, the
  thing fail2ban would normally catch (SSH password brute-force) is no
  longer possible, so the remaining benefit (less log noise from scanners)
  didn't justify adding it.
- All system accounts other than `root`/`rsi` are locked (`*`/`!`/`!*` in
  shadow) — no leftover default `pi` user.
- OS fully patched: `apt update` shows all packages up to date, Debian
  13.4/trixie.
- No `unattended-upgrades` installed — patching is manual only.
- No rtl_433/MQTT/temperature service running yet — host is otherwise idle
  except Tailscale and sshd.

## Follow-ups (not yet done)

- Decide whether to disable SSH password auth / passwordless sudo
  fleet-wide vs. just here.
- rtl_433 installed 2026-06-26: see docs/2026-06-26_raspberrypi2z_rtl433-setup.md
- Consider unattended-upgrades for security patches, given this is a
  low-maintenance always-on sensor node.
