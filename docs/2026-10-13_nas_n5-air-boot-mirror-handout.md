# N5 Air — Boot Mirror Install Hand-out (2026-10-13)

**Status:** open
**Status detail:** hand-off mid-install — Proxmox on the 960 EVO only; boot-order problem resolved in BIOS (§2.5); mirror not built
**Host:** (project)
**Supersedes:** —
**Superseded-by:** —

Hand-off for a session with SSH access to the N5 Air (currently booted into **SystemRescue**, so SSH
means enabling sshd there — see §5). Context: the acceptance run in
[2026-10-13_nas_n5-air-acceptance-test-results.md](2026-10-13_nas_n5-air-acceptance-test-results.md);
procedure in [2026-09-08_nas-us-acceptance-test-runbook.md](2026-09-08_nas-us-acceptance-test-runbook.md);
mirror rationale in [2026-10-04_nas_boot-nvme-mirror.md](2026-10-04_nas_boot-nvme-mirror.md).

## 1. Goal

Boot disk = ZFS mirror (`rpool`) of the Intel 660p 512 GB and the Samsung 960 EVO 250 GB.
The factory 64 GB BAYHUB/Foresee drive is **never touched**.

## 2. What happened

1. Installer, ZFS (RAID1) with both NVMe drives: **refused** — `mirrored disks must have the same size`.
2. Retried with Advanced options `hdsize = 230` (GiB, below the 960 EVO's 232.89): **same error**.
   `hdsize` does not get around the check on PVE 9.2-1. (The 10-04 doc's caveat guessed the installer
   would silently shrink the partition; it refuses instead.)
3. Fell back to the two-stage plan: install **ZFS (RAID0) on the 960 EVO alone**, attach the 660p
   afterwards by hand. Install summary: ZFS (RAID0), bootdisk `/dev/nvme0n1` (= Samsung in the
   installer), hostname `pve.lan`, `192.168.1.129/24`, gw/DNS `192.168.1.1`, nic1 `r8169`
   (`38:05:25:38:65:56`), Buenos_Aires, reboot-after-install on. Install completed.
4. **Problem: after the reboot the firmware "does not recognize the new NVMe as boot drive."**
   Booted SystemRescue to troubleshoot. Not yet diagnosed.
5. **Resolved (user, later 2026-10-13): the fix was a BIOS boot-priority setting.** The NVMe boot
   priorities are in a **separate BIOS menu** from the main boot-order list (exact menu path not
   recorded) — the new drive had to be moved up there. So the install was fine and §4 is mostly
   moot. Whether Proxmox then booted cleanly was not reported; confirm before §6.

## 3. Facts to rely on

- **NVMe device names are not stable between boots.** SystemRescue run 1: Samsung `nvme1n1`, BAYHUB
  `nvme0n1`. Installer and SystemRescue run 2: Samsung `nvme0n1`, BAYHUB `nvme1n1`. Intel 660p was
  `nvme2n1` every time. **Always identify by model / `/dev/disk/by-id/`, never by `nvmeXn1`,
  before any destructive command.**
- Sizes: 660p 476.94 GiB, 960 EVO 232.89 GiB, BAYHUB 58.28 GiB.
- BIOS 1.01 / EC 0.14; **Secure Boot toggle not found** (Security/Boot menus not examined) — if
  Secure Boot is actually on and the install is unsigned-shim-less, that could explain "not a boot
  drive"; unverified.
- Runbook troubleshooting row: "Boots into MinisCloud after install → BIOS boot order: Proxmox
  (`Linux Boot Manager`) first." **On this BIOS the NVMe priorities are a second, separate menu** —
  the runbook row should name it once the path is known.
- SMART baselines saved only in SystemRescue RAM; photos are the record (results doc §3).

## 4. Diagnosis — next steps (one at a time)

*Likely obsolete — see §2.5. Keep only if Proxmox still fails to boot.*

1. From SystemRescue: `lsblk -o NAME,SIZE,FSTYPE,LABEL,MODEL` and `efibootmgr -v`. Questions:
   does the Samsung carry the ESP (vfat, ~1 GiB, label `EFI`?) + `zfs_member` partition 3; is
   there a `Proxmox`/`Linux Boot Manager` NVRAM entry; does `\EFI\proxmox\grubx64.efi` (or
   `\EFI\systemd\systemd-bootx64.efi`) exist on the ESP.
2. If the ESP and files exist but there is no NVRAM entry: BIOS issue — add the entry with
   `efibootmgr -c -d <disk> -p <esp part> -L Proxmox -l '\EFI\systemd\systemd-bootx64.efi'` (match
   the file actually present), or pick the file via the BIOS "boot from file" option; also check
   BIOS boot order and whether the BIOS hides the entry until the disk is "enabled" in Boot menu.
3. If the ESP is missing/empty: the install did not complete cleanly — re-run the installer
   (ZFS RAID0, Samsung only, verify model in the disk dropdown).
4. Check Secure Boot state (`bootctl status` or `od -An -t u1 /sys/firmware/efi/efivars/SecureBoot-*`)
   and find the BIOS toggle; the runbook's choice was Disabled.

## 5. Getting SSH to SystemRescue

On the NAS console: `passwd` (set a throwaway root password), `ip -4 a` (note the address; the PVE
installer used `192.168.1.129` for itself, SystemRescue gets its own DHCP address). sshd is enabled
by default; from comet: `ssh root@<ip>`. SystemRescue's ssh needs the password, not
`~/.ssh/id_ed25519_comet` (copy the key with `ssh-copy-id` if wanted). It is a RAM-only environment.
Remember the repo rules: one command per MCP call, no heredoc file writes over MCP.

## 6. Plan once Proxmox boots from the 960 EVO

Add the 660p as the second mirror member (it has no ESP yet and is larger than the 960 EVO):

1. Identify both disks by `/dev/disk/by-id`. Copy the 960 EVO's partition table to the 660p
   (`sgdisk -R <660p> <960>` then `sgdisk -G <660p>`); the ZFS partition 3 is then exactly the same size.
2. `proxmox-boot-tool format <660p-part2> ` then `proxmox-boot-tool init <660p-part2>`.
3. `zpool attach rpool <960-part3-by-id> <660p-part3-by-id>`; wait for the resilver.
4. Verify: `zpool status rpool` (mirror ONLINE), `proxmox-boot-tool status` (two ESPs),
   `lsblk`. Then test booting from each NVMe in turn.
5. Record the result in the acceptance results doc; update the 10-04 doc's installer caveat.

The 660p's remaining ~245 GiB stays unpartitioned (mirror is bounded by the 960 EVO).

## 7. Still to run after the boot disk is settled

Remaining runbook phases: bay-drive SMART/burn-in, Phase D JMB585 corruption test. Note the data disks
(3× 6 TB, bought 10-13 per the project node) are not yet in the box.
