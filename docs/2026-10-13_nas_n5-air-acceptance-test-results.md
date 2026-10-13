# N5 Air — Acceptance Test Results (2026-10-13)

**Status:** open
**Status detail:** in progress — Phase A (BIOS/inventory/SMART baseline) recorded; memtest running, later phases not yet recorded
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

## 4. Pending

- Memtest86+ — running 2026-10-13, result not yet recorded
- Remaining runbook phases (Proxmox install on the mirror, overnight SMART on the bay drives,
  Phase D JMB585 corruption test)
