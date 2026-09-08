# NAS — US acceptance-test runbook (field procedure)

**Status:** open
**Host:** (project)
**Supersedes:** 2026-09-08_nas-chassis-decision-and-acceptance-test.md (§ 5 only)
**Superseded-by:** —

**Date**: 2026-09-08. Written to be followed **offline, in a hotel room, on a phone or a printout**.
Nothing here needs the rest of the repo. Why each test exists is in
[2026-09-08_nas-chassis-decision-and-acceptance-test.md](2026-09-08_nas-chassis-decision-and-acceptance-test.md);
this doc is the procedure only.

**Goal**: prove the chassis, the 16 GB, and two *secondhand* 6 TB drives are sound **while a US
return is still possible**. Total hands-on time ≈ 45 min, spread over two sessions plus one
unattended night.

**Shape of it**: a **15-minute Proxmox install on the first evening turns the NAS into an SSH
target**, and everything after that is done from the laptop. The monitor and keyboard are needed
once and then go back in the bag. Because the install lands on the NVMe, **it does not wait for
the hard drives** — which matters, since the drives are being bought after the chassis.

---

## Phase 0 — before leaving home

### Downloads

| What | Version | Link |
|---|---|---|
| **SystemRescue** | 13.02 amd64, 1318 MiB, 2026-08-01 | [system-rescue.org/Download](https://www.system-rescue.org/Download/) → `systemrescue-13.02-amd64.iso` ([direct](https://fastly-cdn.system-rescue.org/releases/13.02/systemrescue-13.02-amd64.iso), [SHA256](https://fastly-cdn.system-rescue.org/releases/13.02/systemrescue-13.02-amd64.iso.sha256)) |
| **Proxmox VE** | **9.2-1** amd64, 1.71 GB | [proxmox.com/en/downloads/…/iso](https://www.proxmox.com/en/downloads/proxmox-virtual-environment/iso) → [`proxmox-ve_9.2-1.iso`](https://enterprise.proxmox.com/iso/proxmox-ve_9.2-1.iso) |
| Rufus (if writing from Windows) | latest | [rufus.ie](https://rufus.ie/) |

Take **9.2-1 amd64** — *not* the `-arm64` build, which is for ARM hosts and will not boot this
machine. 9.2 is also the same generation as gr-srv03 (pve-manager 9.2.11).

### Prepare two USB sticks (8 GB+)

Two separate sticks. **Do not combine them on one Ventoy stick** — TerraMaster's own guidance says
not to use Ventoy for OS installer images on these boxes.

- **Rufus**: select the ISO → when it asks ISO Image mode vs **DD Image mode**, choose **DD Image
  mode** for *both* images. The Proxmox ISO in particular will not boot correctly in ISO mode.
- **Linux/macOS**: `sudo dd if=<iso> of=/dev/sdX bs=4M status=progress conv=fsync` — check the
  device name twice.

**Verify the checksum before writing**, and **test-boot both sticks on any PC before you fly.**
Finding a bad write in a hotel room is the one avoidable failure in this whole procedure.

### Pack

- The two USB sticks
- A small USB keyboard
- **Your own HDMI cable** — a hotel TV's is usually captive behind the panel
- An Ethernet cable (or two, for the dual-NIC check)
- The new 60 cm USB 3.0 A→Micro-B cable (Phase C tests it)
- This runbook, on the phone or printed

---

## Phase A — the evening the NAS arrives *(no hard drives needed, ~25 min)*

### A1. Fit the boot NVMe only

Patriot P310 into M.2 slot 1. **Leave the drive bays empty** if the HDDs have not arrived.

### A2. Connect and enter the BIOS

HDMI, USB keyboard, Ethernet to the router, power. Power on and press **Del** at the TerraMaster
splash (**F12** gives a one-time boot menu).

**Confirm on this screen — this is the check that validates the purchase:**

| Check | Expected |
|---|---|
| **Total memory** | **16384 MB / 16 GB** |
| NVMe | Patriot P310 listed |
| SATA ports | 4 present (drives may be absent) |

Then set:

- `Fast` → **`TOS Boot First` = Disabled**
- `Security` → **Secure Boot = Disabled**
- `Boot` → UEFI USB drive as Boot Option #1
- Save & Exit

> **If the memory does not read 16 GB, stop.** That is the entire reason this chassis was chosen
> over the cheaper F2. Return it and re-read the SKU table before rebuying — the N95 variant ships
> with 8 GB.

### A3. memtest86+ *(optional, 20 min, recommended)*

Boot the **SystemRescue** stick and pick **memtest86+** from its boot menu. One full pass over
16 GB takes ~15–20 min. **Zero errors.** Do it while unpacking; it is the only test that proves the
RAM is *good* rather than merely *present*.

### A4. Install Proxmox VE 9.2 to the NVMe

Boot the **Proxmox** stick → **Install Proxmox VE (Graphical)**. If the graphical installer shows a
black screen over HDMI, reboot and choose **Terminal UI** instead — it does the same job.

- **Target disk: the Patriot P310 — nothing else.** If the HDDs happen to be fitted already, be
  deliberate here.
- Filesystem: **ext4** (the default; same layout as gr-srv03). **Do not choose ZFS** — the pool is
  built at home, on the HDDs, addressed by `/dev/disk/by-id/`.
- Country / timezone / keyboard: anything; corrected at home.
- Password + email: something you will remember for one week.
- Network: pick the NIC with the cable in it. Accept the DHCP-prefilled address, hostname
  `nas-test`.

Install (~5 min), reboot, **remove the stick**.

### A5. Move to SSH — the monitor goes away here

The console prints the management URL. Note the IP, then from the laptop:

```sh
ssh root@<ip>
```

Everything from here is over SSH. Unplug the TV and the keyboard.

First inventory — **save this output**, it is the acceptance record:

```sh
pveversion
free -g                                              # ~16 total
dmidecode -t memory | grep -E 'Size|Speed|Part Number|Manufacturer'
lsblk -d -o NAME,SIZE,MODEL,SERIAL
lspci | grep -iE 'ethernet|vga'
smartctl --version                                   # ships with PVE
```

If the machine has internet, top up the toolbox:

```sh
apt update ; apt install -y nvme-cli ethtool hdparm lm-sensors
```

An `apt update` error about the **enterprise** repo returning 401 is expected on a machine with no
subscription and is harmless — the Debian repos the packages come from still work.

**Phase A is complete.** The box is now an SSH target and stays that way until you fly home.

---

## Phase B — the night the drives arrive *(~10 min hands-on + overnight)*

### B1. Fit the drives

`poweroff` over SSH, pull the power, mount both HDDs in trays, bays 1 and 2, power on. Wait a
minute, SSH back in.

```sh
lsblk -d -o NAME,SIZE,MODEL,SERIAL
```

Expect `sda` and `sdb` at **5.5T** each (6 TB decimal = 5.46 TiB), plus `nvme0n1`.
**Write down both serial numbers** — they are what a warranty claim keys on, and what the fleet's
SMART monitoring will trend for the rest of the drives' life.

### B2. Baseline the SMART data

```sh
mkdir -p /root/acceptance
smartctl -a /dev/sda | tee /root/acceptance/sda-before.txt
smartctl -a /dev/sdb | tee /root/acceptance/sdb-before.txt
```

Read now, before spending a night: **`Power_On_Hours`** (expected high — these are recertified
enterprise drives; record it as the baseline) and the five attributes in the table at B5. If any of
those five is already non-zero, **stop and return the drive** — there is no point testing it.

### B3. Stop anything from spinning the drives down

```sh
hdparm -B 255 -S 0 /dev/sda
hdparm -B 255 -S 0 /dev/sdb
```

A "not supported" reply on `-B` is harmless. Proxmox does not spin disks down by default, so this
is belt-and-braces here — but **under TOS it is mandatory**: TOS sleeps drives after 30 minutes and
that aborts a long self-test mid-run with *"aborted by host"*
(`Hardware & Power → Hard Drive Sleep → Never`).

### B4. Start both long self-tests and go to bed

```sh
smartctl -t long /dev/sda
smartctl -t long /dev/sdb
```

**10–13 hours each on a 6 TB 7200 rpm drive; they run in parallel on the drives' own controllers.**
Nothing needs to stay connected — close the laptop, leave the NAS powered. Progress any time:

```sh
smartctl -c /dev/sda | grep -i remaining
```

### B5. In the morning — the verdict

```sh
smartctl -l selftest /dev/sda
smartctl -a /dev/sda | tee /root/acceptance/sda-after.txt
diff /root/acceptance/sda-before.txt /root/acceptance/sda-after.txt
```

Repeat for `sdb`, and check the boot NVMe while you are here:

```sh
smartctl -a /dev/nvme0
```

| Attribute | Accept | Reject |
|---|---|---|
| Extended self-test result | **`Completed without error`** | anything else → **return** |
| `Reallocated_Sector_Ct` (5) | 0 | > 0 → **return** |
| `Current_Pending_Sector` (197) | 0 | > 0 → **return** |
| `Offline_Uncorrectable` (198) | 0 | > 0 → **return** |
| `Reported_Uncorrect` (187) | 0 | > 0 → **return** |
| `Command_Timeout` (188) | 0, or unchanged by the test | rising → **return** |
| `UDMA_CRC_Error_Count` (199) | 0 | > 0 → **retest in another bay first** — usually cable/backplane, not the drive |
| `Power_On_Hours` | any — record it | not a fail on a recert drive |

**Do not be alarmed by** Seagate's enormous `Raw_Read_Error_Rate` and `Seek_Error_Rate` raw values:
they are encoded counters, not error counts, and look alarming on every healthy Seagate.
An **`aborted by host`** result is a host problem, not a drive verdict — fix the spin-down (B3) and
re-run rather than returning the drive.

### B6. Optional — concurrent write test *(20 min, DESTRUCTIVE, worth it)*

The self-test is read-only and drive-internal. This is the only check that loads **the backplane
and the PSU with both drives writing at once**, which is where a marginal chassis shows up.

> **Verify with `lsblk` that `sda`/`sdb` are the HDDs and the NVMe is `nvme0n1` before running
> this.** It destroys whatever is on the target. The HDDs are empty; getting the device wrong
> would wipe the Proxmox install.

```sh
dd if=/dev/zero of=/dev/sda bs=1M count=100000 oflag=direct status=progress &
dd if=/dev/zero of=/dev/sdb bs=1M count=100000 oflag=direct status=progress &
wait
```

Expect **~180–250 MB/s each, sustained, on both simultaneously** (outer tracks of a 6 TB 7200 rpm
drive). Under 100 MB/s, or throughput that collapses partway, is a real finding. Afterwards
re-check `smartctl -a` for any new `UDMA_CRC_Error_Count`.

---

## Phase C — the rest of the machine *(10 min, while it is still returnable)*

```sh
ethtool <iface> | grep -i speed          # 5000Mb/s — repeat with the cable in the other port
lsusb -t                                 # after plugging the Canvio into each of the 4 ports
sensors ; smartctl -a /dev/sda | grep -i temperature
```

- **Both 5GbE ports** link at 5000Mb/s. Find interface names with `ip -brief a`.
- **All four USB ports** (1 front Type-A, 2 rear Type-A, 1 rear Type-C), tested with the **Toshiba
  Canvio and the new 60 cm cable** — that validates the cable purchase too. `lsusb -t` must show
  **`5000M`**, not `480M`; `480M` means a USB 2.0 Micro-B plug and ~35 MB/s.
- **Fan noise with both drives spinning** — force it with the B6 `dd`, or just re-read a few
  hundred GB. This is the last unverified item on the buy list: TerraMaster's 20.9 dB(A) figure is
  measured with drives in **standby** and says nothing about recertified 7200 rpm enterprise drives
  seeking. The USA is the only place a return is possible if it is intolerable.
- **Drive temperature** under sustained load: under 45 °C is comfortable, over 50 °C wants
  investigating.
- **PSU label**: 90 W external brick, must read **100–240 V**. It takes a detachable mains cord, so
  the fix for Argentina is an AR cord, not a plug adapter.

---

## Before you fly home

```sh
scp -r root@<ip>:/root/acceptance ./nas-acceptance/    # from the laptop
```

Keep those files — they are the drives' day-zero baseline. Also keep **every box, tray screw,
accessory and receipt** until the box is running in Argentina.

**Leave Proxmox installed.** It is the same version the final build uses, so the machine arrives
ready to configure. **Do not create the ZFS pool during the trip**: it is built at home from
`/dev/disk/by-id/` with `acltype=posixacl` and `xattr=sa` set *before* any data lands, and those
properties are painful to retrofit onto 1.6 TB.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Will not boot from USB | **Del** → `Fast > TOS Boot First = Disabled`, `Security > Secure Boot = Disabled`, USB first in boot order. Try the other USB port. If still nothing, rewrite the stick in **DD mode**. |
| Proxmox graphical installer is a black screen | Reboot, pick **Terminal UI** from the installer menu. |
| SMART test returns `aborted by host` | Something spun the drive down. Re-run B3, then B4. Under TOS: `Hardware & Power → Hard Drive Sleep → Never`. |
| `smartctl`: *"device lacks SMART capability"* | You addressed a USB-bridged device. Use the SATA `/dev/sdX`, or add `-d sat` for a USB enclosure. |
| Cannot find the NAS's IP | At the console `ip -brief a`, or check the router's DHCP leases for `nas-test`. |
| `apt update` 401 on the enterprise repo | Expected without a subscription; harmless. Silence it with `Enabled: false` in `/etc/apt/sources.list.d/pve-enterprise.sources`. |
| TOS SMART panel shows nothing for the NVMe | Long-standing TOS limitation. Check the P310 over SSH with `smartctl -a /dev/nvme0`. |

## Related

[2026-09-08_nas-chassis-decision-and-acceptance-test.md](2026-09-08_nas-chassis-decision-and-acceptance-test.md)
— why each test exists, the SKU price targets, and the BACKUP_A/B cable spec.
[memory_nas-project.md](memory_nas-project.md) — buy list and open decisions.
[2026-09-07_nas-software-stack.md](2026-09-07_nas-software-stack.md) — what gets built once home.
