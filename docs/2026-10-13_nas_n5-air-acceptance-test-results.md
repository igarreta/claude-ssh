# N5 Air — Acceptance Test Results (2026-10-13)

**Status:** open
**Status detail:** in progress — Phase A done incl. A4 boot mirror (§7, 2026-10-16); A5 done (§8); updated (§9); Phase C partial (§10); soak PASS (§11); **Phase B PASS on all 3 drives (§12, §14)**; full-surface write running 2026-10-22 (replaces badblocks — 18 h budget); Phase D deferred unless time remains; Mac lab access §13; **hostname now `saturn` (§15)**; **pre-shutdown checklist incl. IP → 192.168.1.4 (§16)**; **full write PASS on all three (§17)**; Phase D running 2026-10-23
**Host:** (project)
**Supersedes:** —
**Superseded-by:** —

Results log for the field procedure in
[2026-09-08_nas-us-acceptance-test-runbook.md](2026-09-08_nas-us-acceptance-test-runbook.md), run on the
Minisforum N5 Air bought per
[2026-10-06_nas_minisforum-n5-air-purchase.md](2026-10-06_nas_minisforum-n5-air-purchase.md).
Source: four phone photos taken 2026-10-13 (not committed; values transcribed below).
Booted from SystemRescue (kernel 6.18.41-1-lts, smartctl 7.5).

## 1. BIOS

| Item | Value |
|---|---|
| Product name | N5A (N5 Air) |
| CPU | AMD Ryzen 7 255 w/ Radeon 780M Graphics |
| BIOS version | 1.01 (build 2025-10-24 19:35:20) |
| EC version | 0.14 |
| Manufacturer | Meigao Innovation Technology (Shen Zhen) Co., Ltd |
| Serial | MZ138L5P3AQEMLA00251 |
| AMI Aptio version | 2.22.0059 |

Menus: Main, Advanced, Security, Boot, Save & Exit.

**Secure Boot = Disabled could not be found** (runbook §BIOS step). The runbook lists it as "one less
variable", not a requirement, so it did not block the test. Not recorded whether it lives under
Security or Boot, or is absent on this firmware.

## 2. Drive inventory (`lsblk -d`)

| Device | Model | Size | Role |
|---|---|---|---|
| nvme2n1 | INTEL SSDPEKNW512G8 (660p 512 GB) | 476.9G | boot mirror member |
| nvme1n1 | Samsung SSD 960 EVO 250GB | 232.9G | boot mirror member |
| nvme0n1 | BAYHUB Foresee-C9A611 64GB | 58.3G | factory MinisCloud drive — untouched |
| sda | v165w (rescue USB stick) | 7.3G | — |

ZFS mirror capacity is bounded by the 960 EVO (~233 GiB raw).

## 3. SMART baseline ("before")

Saved in SystemRescue RAM as `/root/nvme1n1-before.txt` and `/root/nvme2n1-before.txt` — **lost on
reboot**; the photos are the record.

| | nvme2n1 — Intel 660p 512 | nvme1n1 — Samsung 960 EVO 250 |
|---|---|---|
| Overall health | PASSED | PASSED |
| Critical warning | 0x00 | 0x00 |
| Temperature | 26 °C | 37 °C (sensor 2: 38 °C) |
| Available spare | 100% (threshold 10%) | 100% (threshold 10%) |
| Percentage used | 6% | 16% |
| Data units read | 21.0 TB | 62.4 TB |
| Data units written | 18.7 TB | 50.0 TB |
| Power-on hours | 7,436 | 7,765 |
| Power cycles | 2,211 | 8,779 |
| Unsafe shutdowns | 80 | 177 |
| Media and data integrity errors | 0 | 0 |
| Error information log entries | 0 | 2,758 |
| Warning / critical temp time | 0 / 0 | 0 / 0 |
| Self-test log | none logged, none in progress | self-tests not supported |
| Firmware | 004C | — |

**960 EVO error log (2,758 entries):** the 16 visible entries are all `Invalid Field in Command`
(status 0x4004) or `Invalid Log Page` (0x4212) — commands the drive rejected, typically a tool probing
optional features. These are not media errors; media/integrity errors are 0 and spare is 100%. Assessed
benign. 48 of 64 stored entries were not read.

**Endurance:** the 960 EVO has written 50 TB against a ~100 TBW rating (SMART "used" 16%); the 660p
18.7 TB against ~100 TBW (6%). Both fit the mirror role; neither is a concern for the 09-30 allocation.

## 4. Memtest86+ (runbook A3)

**PASS, zero errors** — one full pass over 32 GB (own 2× Kingston 16 GB). Temperatures during the
test: 62 / 67 °C (as shown on the memtest screen; normal under full load for this Ryzen).
Memtest was left looping after the PASS and stopped manually.

## 5. Pending

- Remaining runbook phases (overnight SMART on the bay drives,
  Phase C, Phase D JMB585 corruption test)
- apt repos: `apt-get update` fails nightly (enterprise repo, no subscription); PVE 9.2.2 / kernel 7.0.2-6
- BIOS 1.01 is the latest available (user, 2026-10-16) — no update pending.

## 6. Power-off at idle (2026-10-16)

Proxmox on the 960 EVO ran from 10-13 21:02 until the journal stopped mid-routine at
**10-16 10:17:01** (hourly cron; 11:17 never ran). Found with power LED and fan **off**.
No shutdown sequence, no MCE/EDAC, no lockup/watchdog, no NVMe resets, no thermal events,
empty pstore; NVMe "Unsafe Shutdowns" +2 each since §3 (660p 82, 960 EVO 179). Temps after
restart: CPU 26 °C, NVMe 24–34 °C.

**Verdict: power outage at the test location** — BIOS AC-restore was set to *Always Off*, so it
stayed off when power returned. Restore is now **Previous**. Not a hardware fault unless it recurs.

## 7. Boot mirror built (2026-10-16, A4/A4.5)

Two-stage install per [2026-10-13_nas_n5-air-boot-mirror-handout.md](2026-10-13_nas_n5-air-boot-mirror-handout.md) §6,
660p attached to the 960 EVO's single-disk `rpool`:

1. `sgdisk -R <660p> <960>` + `sgdisk -G <660p>` — identical p1/p2/p3; 244 GiB left unpartitioned.
2. `proxmox-boot-tool format <660p-part2>` refused: **a stale vfat from the disk's previous life sat
   at the ESP offset** (whole-disk `wipefs -n` doesn't see it) → `--force`. `init` then registered the
   **old** UUID (udev not refreshed) → `udevadm trigger` + `settle`, `proxmox-boot-tool clean`, `init` again.
3. `zpool attach rpool nvme-eui.0025385671b10d47-part3 /dev/disk/by-id/nvme-INTEL_SSDPEKNW512G8_PHNH12340B4Z512A-part3`
   — resilvered 2.09 G in 3 s, scrub 0 errors.

Result: `mirror-0` ONLINE; ESPs `15B8-093B` (960) + `DB2D-166F` (660p) both synced, kernel 7.0.2-6.
UEFI entries: Boot0006 = 660p, Boot0002 = 960 (systemd-boot), Boot0005 = 960 `\EFI\BOOT\BOOTX64.EFI`.

**Boot tests:** normal reboot → BootCurrent **0005** (960) — the firmware ignores the NVRAM BootOrder
(0006 first) in favour of the BIOS NVMe priority menu; `--bootnext 0006` → BootCurrent **0006**, booted
from the 660p ESP. Both healthy. Not tested: boot with the 960 physically removed.

## 8. A5 inventory (2026-10-16)

| Item | Result |
|---|---|
| PVE / kernel | 9.2.2 / 7.0.2-6-pve |
| CPU | AMD Ryzen 7 255 w/ Radeon 780M |
| RAM | 29 GiB visible of 32; 2× Kingston 9905790-068.A00G 16 GB @ 4800 MT/s (both report `Locator: DIMM 0` — firmware label quirk) |
| NICs | RTL8127 10GbE (03:00.0), RTL8126 5GbE (04:00.0) |
| SATA | **JMicron JMB58x [197b:0585]** at 06:00.0 |
| smartctl | 7.5 |

**M.2 link widths (actual):**

| Drive | Link | Speed |
|---|---|---|
| Intel 660p 512 GB | **x2** (drive max x4) | 8 GT/s (Gen3) |
| Samsung 960 EVO 250 GB | x4 | 8 GT/s (Gen3) |
| BAYHUB 64 GB (factory) | x1 | 5 GT/s (Gen2) |

So the 660p's slot is x2 — irrelevant for a boot mirror.

**JMB585 / Phase D input:** dmesg `ahci 0000:06:00.0: controller can't do 64bit DMA, forcing 32bit`
— **the running kernel already carries the 32-bit DMA quirk**; Phase D runs without the extra
workaround. Kernel cmdline has no `amd_iommu` override.

Toolbox installed (`nvme-cli ethtool hdparm lm-sensors`); enterprise repos 401 as expected.

## 9. Updates (2026-10-16)

Enterprise repos disabled (`Enabled: false` in `pve-enterprise.sources`, `ceph.sources`);
`proxmox.sources` added with `pve-no-subscription`. `dist-upgrade` (170 pkgs, run detached via
`systemd-run`): PVE 9.2.2 → **9.2.21**, kernel 7.0.2-6 → **7.0.14-24-pve**, ZFS 2.4.2 → **2.4.4**.
Both ESPs carry both kernels. After reboot: pool healthy, no failed units, **JMB585 32-bit DMA
quirk still active**. Phase D will run on this kernel.

## 10. Phase C (no data drives — they had not arrived)

| Check | Result |
|---|---|
| 5GbE RTL8126 (`nic1`, 04:00.0, `38:05:25:38:65:56`, in `vmbr0`) | **link 1000 Mb/s** |
| 10GbE RTL8127 (`nic0`, 03:00.0, `38:05:25:38:65:57`) | driver bound (`r8169`); link test pending |
| USB Type-A ports | **working** (user, 2026-10-16) |
| PSU | **100–240 V** (user) |
| iGPU VAAPI (Mesa 25.0.7 radeonsi, phoenix) | **PASS** — HEVC Main/Main10, H.264 and AV1: decode + encode; VP9 decode |
| Drive temps / fan with HDDs | pending (no drives) |

## 11. CPU/memory soak (2026-10-16, kernel 7.0.14-24)

`stress-ng --cpu 0 --vm 2 --vm-bytes 8G --timeout 60m` (16 threads + 2×8 GB VM workers), sampled
every minute (`/root/acceptance/soak.csv` on the NAS). **PASS — 18/18 stressors passed, 0 failed,
no kernel warnings during the run.**

| | Idle | Load (60 min) | 5 min after |
|---|---|---|---|
| CPU Tctl | 34 °C | peak **70 °C** (min 2), plateau 66–68 °C | 28 °C |
| All-core clock | — | **4.14–4.29 GHz**, never dropped (no throttling) | — |
| NVMe max | 34 °C | 38 °C | 34 °C |

The only kernel warnings in this boot predate the run (amdgpu `REG_WAIT timeout` at boot — cosmetic,
also on 10-13 — and `nvme0: using unchecked data buffer`).

## 12. Phase B — data drives (2026-10-21, kernel 7.0.14-24)

All three drives fitted (sda–sdc), every SATA link **6.0 Gbps**. JMB585 `forcing 32bit` still in
dmesg. Baselines (`smartctl -x`) in `/root/acceptance/sd{a,b,c}-before.txt` on the NAS; the script
that produced them is `/root/fast-tests.sh`.

| Dev | Drive | Serial | FW | POH | 5 / 187 / 188 / 197 / 198 / 199 | Error log | ERC as found |
|---|---|---|---|---|---|---|---|
| sda | Seagate ST6000NM021A (Lenovo OEM `00MX141LEN`) | WSE0HDDV | LBB8 | 5,510 | all 0 | none | 7.5 s |
| sdb | HGST HUS726060ALE610 | K8JWLGJD | APGNTD05 | 26,654 | all 0 (187/188 not reported) | none | **disabled** |
| sdc | HGST HUS726060ALE610 | K1KUV90N | APGNTD05 | 36,432 | all 0 (187/188 not reported) | none | **disabled** |

- Sector size identical on all three: 512 logical / 4096 physical → `ashift=12`.
- **ERC set to 7.0 s** (`scterc,70,70`) on sdb/sdc — **lost at power-off**; a boot-time unit is
  needed before `tank` is built. The Seagate's OEM firmware already had it on (7.5 s).
- `hdparm -B 255 -S 0` applied to all three (APM "not supported" on the Seagate — harmless).
- **Short self-test: `Completed without error` on all three.**
- **Long self-test started 2026-10-21 ~22:45 −03** on all three in parallel. Drive-estimated finish
  (−03): sda Thu 22 07:43, sdc 12:15, **sdb 14:41** (954 min).
- Cold-spare choice deferred to after burn-in — **the least reliable drive** (user). On hours
  alone sdc (36k h) is the early candidate.

**Remaining sequence (user: in order, no overlap):** B5 verdict → Phase D → one destructive
`badblocks` pass (`-b 4096`, ~20 h) via `systemd-run`. ~35 h total against 48 h left in the US.

## 13. Lab access from the MacBook (2026-10-21)

No LAN at this site: MacBook → USB → UGREEN hub (AX88179B, `en6`) → NAS `nic1`. The NAS keeps its
static `192.168.1.129/24`, which **overlaps the site Wi-Fi's 192.168.1.0/24**, and has no internet
(tmux/screen not installed — long jobs go through `systemd-run`).

- Internet Sharing **off** (its 192.168.2.x DHCP is useless to a static host).
- `sudo ifconfig en6 inet 192.168.1.250 netmask 255.255.255.255 alias`
- `sudo route -n add -net 192.168.1.128/30 -interface en6`
- **Do not use `route add -host … -interface en6`**: macOS pins the host to `en6`'s *own* MAC
  (`arp` shows `permanent`), so every packet is lost. The /30 net route ARPs normally.
- Both settings are lost on reboot or unplug. Link negotiates only **100baseTX** — fine for SSH.
- SSH: `root@192.168.1.129` with the Secretive agent key (installed with `ssh-copy-id` 10-21).
- **Use `ssh -b 192.168.1.250`.** macOS later self-assigns `169.254.x` to `en6` and uses it as the
  source address; the NAS answers ARP but its replies go to its gateway, so ping/SSH time out.
- The alias and route also vanish when the Mac sleeps or the hub re-enumerates — re-add both.

## 14. Phase B verdict + plan change (2026-10-22)

**B5: all three PASS.** Extended self-test `Completed without error` on all three (sda at 5,518 h,
sdb 26,669 h, sdc 36,445 h — the HGSTs finished well ahead of their 954/808-min estimates).
Reject attributes 5/187/188/197/198/199 all 0 and unchanged, `No Errors Logged` on all three.
Seagate attrs 1/7 raw values are encoded counters (as the runbook warns). Only SATA dmesg lines:
`ata1`/`ata2` link down at boot = the two empty bays. Snapshots: `/root/acceptance/sd{a,b,c}-after.txt`.

**Time budget cut to 18 h (user)** — one `badblocks` write+verify pass (~17–20 h) no longer fits
with a return drop-off. New plan:

1. **Full-surface write instead of `badblocks`** — the long test already read every sector; one
   `dd if=/dev/zero oflag=direct` pass writes every sector. Re-check SMART afterwards: any
   reallocated/pending → return. Started **2026-10-22 20:03 −03** as `systemd-run` units
   `wipe-sd{a,b,c}`, by-id paths. Had to be launched by the user: the Claude Code auto-mode
   classifier blocks a destructive whole-disk write even after explicit approval.
   Initial speed (outer tracks): **sda 268, sdb 227, sdc 225 MB/s** concurrently (~720 MB/s
   through the JMB585). ETA ~03:30–06:30.
2. **Phase D after, if time remains; otherwise at home.** Not a return reason (user, 10-06), so
   deferring loses no decision — but it must pass before `tank` is built. Proposed as a **3-way
   mirror `testpool` of all three drives** (more controller load, no spare choice needed first).

`sda` arrived with 4 empty 682.7 GB partitions from its previous owner — erased by the write.

## 15. Hostname `pve` → `saturn` (2026-10-22)

Name chosen by the user (see `memory_nas-project.md`). Done live with `/root/rename-saturn.sh`
while the `wipe-sd*` writes ran — safe because the node had **no guests and no cluster**:
`hostnamectl`, `/etc/hosts` → `192.168.1.129 saturn.lan saturn`, postfix `myhostname`, restart
`pve-cluster`, `pvecm updatecerts --force`, restart pvedaemon/pveproxy/pvestatd/pve-firewall/postfix,
remove the empty `/etc/pve/nodes/pve`. Backups: `/root/hosts.bak-rename`,
`/root/postfix-main.cf.bak-rename`. Result: node `saturn` **online**, no warnings, writes unaffected.
New web-UI cert fingerprint `31:C0:47:AB:…:CB:96:58`. **A reboot to confirm is still pending** —
not before the writes finish. Old RRD graphs (`pve2-node/pve`) are orphaned, cosmetic.

## 16. Before the final shutdown — checklist (decided 2026-10-22)

Write progress at 20:49 −03 (46 min in): sda 721 GB, sdb 608 GB, sdc 607 GB — averaging
~260 / ~220 MB/s, on track.

When the writes finish, in this order:

1. **Write verdict:** each `wipe-sd*` unit ended with `No space left on device` at the full
   6,001,175,126,016 bytes (not earlier); SMART reject attributes still 0; no `ata` errors in dmesg.
   Save `smartctl -x` as `/root/acceptance/sd{a,b,c}-afterwrite.txt`.
2. **Phase D** only if the 18 h budget allows; otherwise it runs at home.
3. `scp -r root@192.168.1.129:/root/acceptance ./nas-acceptance/` to the Mac.
4. **Change the IP to the home address `192.168.1.4/24`** (user, 2026-10-22) — **last step, edit
   only, do not apply** (`ifreload` would cut the Mac link, whose route covers only .128–.131):
   - `/etc/network/interfaces`: `address 192.168.1.129/24` → `address 192.168.1.4/24`
   - `/etc/hosts`: `192.168.1.129 saturn.lan saturn` → `192.168.1.4 saturn.lan saturn`
   - gateway/DNS `192.168.1.1` already match the home router — unchanged.
   - Then `poweroff`. First boot at home comes up on .4 and doubles as the rename-confirmation reboot.
   - **.4 checked free from gr-srv03 on 2026-10-22** (no ping/ARP reply, no gr-srv03 guest uses it);
     still **reserve it or keep it outside the router's DHCP pool**.
5. At home: SCT ERC is lost at power-off → re-set it (and write the boot-time unit) before `tank`.

## 17. Full-surface write verdict + Phase D start (2026-10-23)

**Write pass: PASS on all three.** Every `wipe-sd*` unit wrote the full 6,001,175,126,016 bytes and
ended with `No space left on device` (systemd shows `failed`/exit 1 — that is `dd`'s normal end on a
block device, not a fault).

| Drive | Finished (−03) | Avg | 5/187/188/197/198/199 | Error log | POH |
|---|---|---|---|---|---|
| sda Seagate WSE0HDDV | 04:01 | 210 MB/s | 0 | none | 5,544 |
| sdb HGST K8JWLGJD | 05:31 | 176 MB/s | 0 | none | 26,688 |
| sdc HGST K1KUV90N | 05:33 | 176 MB/s | 0 | none | 36,465 |

No `ata`/I/O errors in dmesg since boot. Snapshots: `/root/acceptance/sd{a,b,c}-afterwrite.txt`.
**No returns needed.** Burn-in shows no reliability difference between the HGSTs, so the cold spare
falls to hours: **K1KUV90N** (36k h) — pending the user's confirmation.

**Phase D started 08:25 −03** as `systemd-run --unit=phaseD bash /root/acceptance/phaseD.sh`:
**3-way mirror** `testpool` (all three by-id, `ashift=12`, compression off), runbook D3–D4 (4×50 GB
hashed in memory → scrub + verify; scrub while writing 2×50 GB more → final scrub → verify all),
with `zpool export/import` before each verify so reads come from disk, not ARC. Verdict line
`PHASE D RESULT: PASS|FAIL` in `/root/acceptance/phaseD.log`; dmesg before/after diffed for
`ata`/`ahci`/reset/IOMMU lines. `testpool` is left for D5 (destroy + `labelclear` + `wipefs`).
JMB585 `forcing 32bit` confirmed at start, kernel 7.0.14-24.

Mac access note: the Secretive agent can fail a signature intermittently
(`communication with agent failed`) — retry; not a NAS problem.
