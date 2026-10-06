# NAS — US acceptance-test runbook (field procedure)

**Status:** open
**Host:** (project)
**Supersedes:** 2026-09-08_nas-chassis-decision-and-acceptance-test.md (§ 5 only)
**Superseded-by:** —

> **CORRECTED 2026-09-10 — the chassis changed to the TerraMaster F4-424 Pro** (i3-N305 8-core,
> **32 GB**, 2× 2.5GbE, 2× M.2). As originally written this runbook told you to **return the box if
> the BIOS did not report 16 GB**, which would have rejected a correct machine. The four
> chassis-specific checks below (memory, memtest duration, LAN speed, USB/M.2 counts) have been
> updated in place and are marked *(F4-424 Pro)*. **The Proxmox install procedure is unchanged** —
> the 424 Pro's BIOS uses the same menu names, and unlike the 425 Plus it has a published Proxmox
> install guide. Why the chassis changed →
> [2026-09-10_nas-chassis-price-correction-f4-424-pro.md](2026-09-10_nas-chassis-price-correction-f4-424-pro.md)

> **UPDATED 2026-10-04 — the boot disk is now a ZFS mirror of both NVMe drives** (Intel 660p 512 GB
> + the on-hand 256 GB), not ext4 on the 660p with the 256 GB as a cold spare. Changed in place:
> Pack, A1, A2, A3.5, A4, the new A4.5 check, B1, B5, B6, troubleshooting. Also fixed: A5 `free -g`
> expected ~31, not ~16. Why →
> [2026-10-04_nas_boot-nvme-mirror.md](2026-10-04_nas_boot-nvme-mirror.md)

> **UPDATED 2026-10-06 — the chassis changed again: Minisforum N5 Air** (AMD Ryzen 7 255/H255
> 8C/16T, Radeon 780M, **barebone — RAM is your 2× Kingston 16 GB**, 5 bays, 3 M.2, 10GbE + 5GbE,
> Amazon, **30-day return window from delivery 2026-10-07 → about 2026-11-06**). All
> F4-424 Pro / TerraMaster-specific steps are replaced in place and marked *(N5 Air)*. **New and
> Phase D, the JMB585 SATA data-corruption test** — it verifies the kernel mitigation before real
> data lands; **not a return check** (user decision, 2026-10-06, after the root cause was found). Why →
> [2026-10-06_nas_minisforum-n5-air-purchase.md](2026-10-06_nas_minisforum-n5-air-purchase.md)

**Date**: 2026-09-08. Written to be followed **offline, in a hotel room, on a phone or a printout**.
Nothing here needs the rest of the repo. Why each test exists is in
[2026-09-08_nas-chassis-decision-and-acceptance-test.md](2026-09-08_nas-chassis-decision-and-acceptance-test.md);
this doc is the procedure only.

**Goal**: prove the chassis, the 32 GB, two *secondhand* 6 TB drives, and **the SATA controller's
data integrity** *(N5 Air)* are sound **while a US return is still possible**. Total hands-on time
≈ 1 h, spread over three sessions plus one unattended night and a ~3 h unattended stress run.

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

> **`amd64` does not mean "AMD processor".** It is the name of the 64-bit x86 instruction set AMD
> invented and Intel adopted, so it covers **both** Intel and AMD CPUs. The N5 Air's Ryzen takes
> the `amd64` build. SystemRescue uses the same convention.
>
> Proxmox's download page lists releases newest-first, so the ARM build appears **above** the one
> you want and neither says "Intel". Go by the **filename**:
>
> | Page entry | File | Verdict |
> |---|---|---|
> | "For ARM64: Proxmox VE 9.2 ISO Installer" | `proxmox-ve_9.2-1-arm64.iso` | **wrong** |
> | "Proxmox VE 9.2 ISO Installer" | **`proxmox-ve_9.2-1.iso`** (1.71 GB) | **correct** |
>
> **The correct file carries no architecture suffix at all.** If `-arm64` appears anywhere in the
> name, it is the wrong download.

### Prepare two USB sticks (8 GB+)

Two separate sticks. **Do not combine them on one Ventoy stick** — originally TerraMaster's
guidance; on the N5 Air Ventoy is reported to work, but two plain sticks remove a variable.

- **Rufus**: select the ISO → when it asks ISO Image mode vs **DD Image mode**, choose **DD Image
  mode** for *both* images. The Proxmox ISO in particular will not boot correctly in ISO mode.
- **Linux/macOS**: `sudo dd if=<iso> of=/dev/sdX bs=4M status=progress conv=fsync` — check the
  device name twice.

**Verify the checksum before writing**, and **test-boot both sticks on any PC before you fly.**
Finding a bad write in a hotel room is the one avoidable failure in this whole procedure.

### Pack

- **The 2× Kingston KVR48S40BS8-16 RAM sticks** *(N5 Air — it ships with **no RAM**; forget them
  and nothing in this runbook can be done)*. Carry them in their anti-static packaging
- **Small Phillips screwdriver** — RAM, M.2 and drive fitting
- The two USB sticks
- A small USB keyboard
- **Your own HDMI cable** — a hotel TV's is usually captive behind the panel
- **Intel 660p 512 GB NVMe** and the **256 GB M.2**: the two halves of the boot mirror, both
  fitted in A1. There is no boot-disk spare any more
- **Two Ethernet cables**: NAS + Mac, or one per NAS port for the Phase C dual-port check
- **USB-C hub with Ethernet** for the MacBook, for the direct-cable alternative. Check at home
  that macOS sees its Ethernet port.
- The new **1 m** USB 3.0 A→Micro-B cable — UGREEN 10841, 22 AWG (Phase C tests it). Bring both if
  the spare was bought.
- This runbook, on the phone or printed

---

## Network — pick one before A4

**Default: NAS on the house router.** If the rented home has a free Ethernet port on its router,
plug the NAS in and follow A4 as written. The installer takes the address DHCP offers and saves it
as **static** config. That is fine for a one-week SSH target: SSH does not depend on
`pve-cluster`/web UI, which are the parts that care about `/etc/hosts` matching the live IP.

**Alternative: direct cable laptop ↔ NAS.** Use it when there is no free router port, when the
laptop cannot reach the NAS (client isolation), or when the router reassigns the address after a
power-off (B1) and it clashes with another device.

- **Cable:** any standard Ethernet patch cable. Both NAS ports and any modern laptop adapter do
  Auto-MDI/X, so you do not need a crossover cable. A MacBook needs the **USB-C hub with Ethernet**
  from the Pack list.
- **The MacBook stays on the home Wi-Fi at the same time.** The Ethernet side has **no router**
  set, so macOS keeps its default route (internet) on Wi-Fi and uses the cable only for the NAS's
  subnet.
- **NAS (A4 network screen):** IP `192.168.2.2/24`, gateway `192.168.2.1`, DNS `192.168.2.1`,
  hostname `nas-test`.
- **MacBook**, choose either:
  - **SSH only:** System Settings → Network → *USB LAN adapter* → Details → TCP/IP →
    Configure IPv4 **Manually**, IP `192.168.2.1`, mask `255.255.255.0`, **Router empty**.
  - **SSH + internet for the NAS:** System Settings → General → Sharing → **Internet Sharing**,
    share from Wi-Fi to the USB LAN adapter. The Mac becomes `192.168.2.1` and routes the NAS out
    through its Wi-Fi. Confirm the address with `ifconfig bridge100`. If it is not `192.168.2.1`,
    change the NAS's gateway/DNS in `/etc/network/interfaces` and `/etc/resolv.conf` to match.
- **Clash check:** if the home Wi-Fi itself is `192.168.2.x` (`ipconfig getifaddr en0`), use
  `192.168.77.x` instead with the SSH-only setup. Internet Sharing is then unavailable.
- **Without NAS internet** the A5 `apt install` is skipped. Everything else works because
  `smartctl`, `dd`, `lsblk` and `dmidecode` ship with Proxmox. For Phase C link speed, use
  `cat /sys/class/net/<iface>/speed` instead of `ethtool`. The Phase C second-port check is the
  same cable moved to the other port, with the NAS IP moved to that interface or a quick
  `ip addr add 192.168.2.3/24 dev <iface2>`.

---

## Phase A — the evening the NAS arrives *(no hard drives needed, ~25 min)*

### A1. Fit the RAM and both boot NVMe drives *(N5 Air)*

Follow Minisforum's quick-start guide in the box for opening the case; it is not documented here.

- **RAM:** both Kingston 16 GB sticks, one per SO-DIMM slot, until they click.
- **M.2:** the box has **3 slots**, and the factory 64 GB MinisCloud OS drive occupies one. Leave
  it where it is: it proves that slot works, and it must go back in the box untouched if the unit
  is returned. Fit the Intel 660p 512 GB and the 256 GB in **the two free slots**. Vendor spec and
  a hands-on review disagree on lane widths; A5 records the real ones, and the mirror can be moved
  to the faster slots at home.
- **Leave the drive bays empty** if the HDDs have not arrived.

> One owner lost all HDDs after fitting RAM, fixed by reseating the **drive-slot connector** inside
> the case. If drives go missing after any internal work, check that before suspecting the controller.

### A2. Connect and enter the BIOS

HDMI, USB keyboard, Ethernet to the router, power. Power on and press **Del** at the Minisforum
splash. The one-time boot menu key is **F7** on most Minisforum units; it is not confirmed for the
N5 Air, and if it fails, set the boot order in the BIOS instead.

**Confirm on this screen — this is the check that validates the purchase:**

| Check | Expected |
|---|---|
| **Total memory** | **32768 MB / 32 GB**, both slots populated *(N5 Air)* |
| CPU | Ryzen 7 255 or H255 — record which |
| NVMe | **Three** listed: Intel 660p 512 GB, the 256 GB, and the 64 GB factory drive |
| SATA | 5 bays present (drives may be absent) |

Then set:

- **`Advanced → Offboard SATA Controller Driver` = Enabled** (an N5 Pro owner's tip — needed for
  the bays to enumerate). Exact menu path may differ; look for it under `Advanced`
- **Secure Boot = Disabled** (Proxmox supports Secure Boot, but untested on this unit — one less variable)
- Boot order: UEFI USB drive first
- Save & Exit

> **If the memory does not read 32 GB, reseat the sticks and test each alone in each slot.** The
> RAM is yours, not the vendor's: a dead *slot* is a **return** reason, a dead *stick* is not
> (one stick gives 16 GB, enough to continue the test).

### A3. memtest86+ *(optional, 20 min, recommended)*

Boot the **SystemRescue** stick and pick **memtest86+** from its boot menu. One full pass over
**32 GB** takes ~**30–40 min**. **Zero errors.** Do it while unpacking; it is the only test that proves the
RAM is *good* rather than merely *present*.

### A3.5. Check both boot NVMe drives *(reused hardware — both are on-hand, not new)*

"On hand" is not "tested" — unknown prior usage, so check before trusting either. From the
**SystemRescue** shell (still booted from A3). Confirm which is which with `lsblk -d -o NAME,SIZE,MODEL`
first — enumeration order is not guaranteed to follow slot order. *(N5 Air)* There are **three**
NVMe devices; the 64 GB one is the factory MinisCloud drive and is **never touched**. Below,
`nvmeA`/`nvmeB` stand for the 660p and the 256 GB — substitute the real names:

```sh
smartctl -a /dev/nvmeA | tee /root/nvmeA-before.txt
smartctl -a /dev/nvmeB | tee /root/nvmeB-before.txt
```

| Check | Accept | Reject |
|---|---|---|
| Percentage Used | low / near 0 | high → treat like a failed drive |
| Media Errors | 0 | > 0 → treat like a failed drive |
| Available Spare vs threshold | spare well above threshold | close to/below → treat like a failed drive |
| Power On Hours / Power Cycles | sanity-check against "unused" | wildly inconsistent → investigate |

**If one fails any check**, pull it and install on the good one alone as **ZFS (RAID0)** — a
single-disk ZFS pool — in A4. A replacement is `zpool attach`ed at home to make the mirror.
**Do not fall back to ext4**: it cannot be turned into a mirror without a reinstall.

Then clear leftover partition tables from prior use so the Proxmox installer starts clean —
**check the names against `lsblk` once more; wiping the 64 GB drive spoils a return**:

```sh
wipefs -a /dev/nvmeAn1
wipefs -a /dev/nvmeBn1
```

### A4. Install Proxmox VE 9.2 to the NVMe mirror

Boot the **Proxmox** stick → **Install Proxmox VE (Graphical)**. If the graphical installer shows a
black screen over HDMI, reboot and choose **Terminal UI** instead — it does the same job.

- Target: **Options → Filesystem: `zfs (RAID1)`**, then select **the 660p and the 256 GB and
  nothing else** — set the **64 GB factory drive** and any HDD to `-- do not use --`. Advanced: `ashift` **12**,
  `compress` **on** (default), leave `hdsize` at its default.
- **The HDDs never go in the installer.** Their pool (`tank`) is built at home, addressed by
  `/dev/disk/by-id/`.
- Country / timezone / keyboard: anything; corrected at home.
- Password + email: something you will remember for one week.
- Network (direct-cable alternative: use the static values from **Network — pick one before A4**
  instead): pick the NIC with the cable in it. Accept the DHCP-prefilled address, hostname
  `nas-test`.

Install (~5 min), reboot, **remove the stick**. *(N5 Air)* If it boots into MinisCloud instead,
enter the BIOS and put the Proxmox disks (`Linux Boot Manager` / the 660p) first in the boot order.

### A4.5. Check the mirror *(2 min, at the console or after A5 over SSH)*

```sh
zpool status rpool                              # mirror-0, both NVMe ONLINE, no errors
lsblk -o NAME,SIZE /dev/nvmeAn1 /dev/nvmeBn1    # compare partition 3 on each
proxmox-boot-tool status                        # two ESPs listed → boots from either disk
```

**Record the partition-3 sizes.** If the 660p's was sized down to match the 256 GB disk, that is
not a fault and not a return reason — it can be grown later (it is the last partition). A pull-one-disk
boot test is **not** part of the trip: it tests configuration, not hardware — do it at home.

### A5. Move to SSH — the monitor goes away here

The console prints the management URL. Note the IP, then from the laptop:

```sh
ssh root@<ip>
```

Everything from here is over SSH. Unplug the TV and the keyboard.

First inventory — **save this output**, it is the acceptance record:

```sh
pveversion ; uname -r                                # kernel matters for Phase D
lscpu | grep 'Model name'                            # Ryzen 7 255 or H255 (N5 Air)
free -g                                              # ~29–31 total; the iGPU reserves some
dmidecode -t memory | grep -E 'Locator|Size|Speed|Part Number|Manufacturer'   # 2 sticks, 4800 MT/s
lsblk -d -o NAME,SIZE,MODEL,SERIAL
lspci | grep -iE 'ethernet|vga|sata|jmicron|asmedia'
smartctl --version                                   # ships with PVE
```

*(N5 Air)* Two more records:

```sh
# M.2 lane widths — vendor spec and a review disagree; record what you actually get
for d in /sys/class/nvme/nvme*; do echo "$(basename $d) $(cat $d/model) \
  x$(cat $d/device/current_link_width) $(cat $d/device/current_link_speed)"; done

# SATA controller — the input to Phase D
lspci -nn | grep -iE 'sata|ahci'                     # JMicron JMB58x = [197b:0585]
dmesg | grep -iE 'ahci.*(64bit|32bit|flags)'
```

**If a JMB58x is listed, note whether dmesg says `controller can't do 64bit DMA, forcing 32bit`.**
That line means the running kernel already carries the fix. Without it, Phase D applies the
workaround first.

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

Expect `sda` and `sdb` at **5.5T** each (6 TB decimal = 5.46 TiB), plus the three NVMe devices.
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
is belt-and-braces here. A drive that spins down mid-test aborts it with *"aborted by host"*.

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

Repeat for `sdb`, and check both boot NVMe drives against their A3.5 baseline while you are here
(`Media and Data Integrity Errors` still 0, `Available Spare` unchanged):

```sh
smartctl -a /dev/nvmeA
smartctl -a /dev/nvmeB
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

> **Verify with `lsblk` that `sda`/`sdb` are the HDDs before running this.** It destroys whatever is on the target. The HDDs are empty; getting the device wrong
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

## Phase C — the rest of the machine *(15 min, while it is still returnable)*

```sh
ip -brief link                           # both NICs present: RTL8126 (5GbE) and RTL8127 (10GbE)
ethtool <iface> | grep -i speed          # 1000Mb/s on a 1 GbE router — repeat in the other port
lsusb -t                                 # after plugging the Canvio into each USB port
sensors ; smartctl -a /dev/sda | grep -i temperature
```

- **Both LAN ports** *(N5 Air: 10GbE RTL8127 + 5GbE RTL8126)* must show up and link. They link at
  whatever the router offers, usually 1000Mb/s. The 5GbE uses the in-kernel `r8169`; the 10GbE
  needs kernel ≥ 6.16, which PVE 9.2's 7.0 kernel is. **If the 10GbE interface is missing, it
  is a note, not a return reason**: the 5GbE port is the one to use.
- **Every USB port**, tested with the **Toshiba Canvio and the new 1 m cable** — that validates
  the cable purchase too. `lsusb -t` must show **`5000M`**, not `480M`; `480M` means a USB 2.0
  Micro-B plug and ~35 MB/s.
  > *(N5 Air)* **3× USB 3.2 Gen2 Type-A**, 2× USB4 (Type-C), 1× USB 2.0. Test the three Type-A
  > ports; the BACKUP_A/B rotation plugs in there. Note which are front and which are rear.
- **iGPU media engine** *(N5 Air — needs internet)*: `apt install -y vainfo` then
  `vainfo --display drm --device /dev/dri/renderD128 | grep -i hevc`. Expect `VAProfileHEVCMain`
  and `HEVCMain10` with **`VAEntrypointVLD`** (decode) and **`VAEntrypointEncSlice`** (encode):
  that is what Immich's VAAPI transcoding uses. A real 4K transcode can wait for home.
- **Fan noise with both drives spinning** — force it with the B6 `dd` or Phase D, or just re-read a
  few hundred GB. Minisforum publishes **no** noise figure at all, and the chassis is plastic. The
  USA is the only place a return is possible if it is intolerable.
- **Drive temperature** under sustained load: under 45 °C is comfortable, over 50 °C wants
  investigating.
- **PSU label** *(N5 Air)*: 280 W, 19 V external brick, must read **100–240 V**. Note whether the
  mains side is a detachable cord (fix for Argentina: an AR cord) or a fixed US plug (fix: a plug
  adapter).

---

## Phase D — JMB585 SATA data-corruption test *(N5 Air, ~3 h mostly unattended)*

**Why**: on the N5/N5 Pro, the **JMicron JMB585** SATA controller **silently corrupts data** under
sustained I/O. The root cause is a BIOS setting on the AMD root ports ("enhanced atomics") that
breaks high 64-bit DMA addresses, and the N5 Air's **Hawk Point** CPU is on an affected platform.
Kernel fixes exist, so this is **not a return reason** (user decision, 2026-10-06). The test proves
the mitigation actually works on this box **before any real data lands**. Running it in the US is
simply the first chance with drives in.
Details → [2026-10-06_nas_minisforum-n5-air-purchase.md](2026-10-06_nas_minisforum-n5-air-purchase.md) §3.

Run it **after B5** has passed both drives, so any error points at the controller, not a disk.

### D1. Decide whether the workaround is needed

From the A5 record:

| A5 showed | Do |
|---|---|
| No JMicron SATA controller | Run D2–D4 anyway (it is a SATA stress test), no workaround |
| JMB58x **and** `forcing 32bit` in dmesg | Kernel already fixed. D2–D4 as-is |
| JMB58x, **no** `forcing 32bit` | Apply the workaround below first, then D2–D4 |

Workaround — boot parameter. Check `proxmox-boot-tool status` reports `uefi`, then:

```sh
cat /etc/kernel/cmdline                         # one line, e.g. root=ZFS=rpool/ROOT/pve-1 boot=zfs
sed -i '1s/$/ amd_iommu=pgtbl_v2/' /etc/kernel/cmdline
cat /etc/kernel/cmdline                         # still ONE line, parameter at the end
proxmox-boot-tool refresh
reboot
```

After reboot: `cat /proc/cmdline | grep pgtbl_v2` must print the line.

### D2. Throwaway test pool

**This is not `tank`.** It is destroyed in D5. `tank` is still built at home.

```sh
ls -l /dev/disk/by-id/ | grep -E 'ata-.*sd[ab]$'      # the two HDD ids
zpool create -f -o ashift=12 testpool mirror /dev/disk/by-id/<ata-id-1> /dev/disk/by-id/<ata-id-2>
```

### D3. Write, verify, scrub — with dmesg watched

In a **second SSH session**, leave this running for the whole phase:

```sh
dmesg -wT | grep -iE 'ata[0-9]|ahci|reset|error|iommu|i/o'
```

In the first, write 4 × 50 GB of random data in parallel. Each stream is hashed **in memory, on its
way in**, so the hash is a reference that never went through the controller (~20–30 min):

```sh
cd /testpool
for i in 1 2 3 4; do (dd if=/dev/urandom bs=1M count=50000 status=none | tee f$i | sha256sum > /root/acceptance/f$i.sha) & done; wait
```

Then read everything back and check it against the reference, scrubbing at the same time (mixed
I/O is what makes the controller reset). This takes ~30–40 min:

```sh
zpool scrub testpool
for i in 1 2 3 4; do echo "f$i $(sha256sum < f$i | cut -d' ' -f1) $(cut -d' ' -f1 /root/acceptance/f$i.sha)"; done
zpool wait -t scrub testpool ; zpool status -v testpool
```

Each `f` line must show **two identical hashes**.

### D4. Repeat under load

Write a second set while a scrub runs, then a final scrub:

```sh
zpool scrub testpool
for i in 5 6; do (dd if=/dev/urandom bs=1M count=50000 status=none | tee f$i | sha256sum > /root/acceptance/f$i.sha) & done; wait
zpool wait -t scrub testpool
zpool scrub -w testpool ; zpool status -v testpool
for i in 1 2 3 4 5 6; do echo "f$i $(sha256sum < f$i | cut -d' ' -f1) $(cut -d' ' -f1 /root/acceptance/f$i.sha)"; done
```

Save the evidence: `zpool status -v testpool > /root/acceptance/phaseD-zpool.txt ; dmesg > /root/acceptance/phaseD-dmesg.txt`.

| Check | Accept | Reject |
|---|---|---|
| `zpool status` READ / WRITE / CKSUM | **all 0**, `No known data errors` | any non-zero |
| Hash comparison | every pair identical | any mismatch |
| dmesg | no `link reset`, `hard resetting link`, `SATA link down`, `disabled`, IOMMU faults | any of them |

**If anything fails with no workaround applied** → apply D1's workaround, recreate the pool, and
run D3–D4 again. **If it still fails** → do **not** put data on `tank` at home; record the result
and wait for a PVE kernel carrying the 7.3 root-cause fix (enhanced-atomics quirk), then re-run
Phase D. Not a return reason.

### D5. Destroy the test pool

```sh
cd / ; zpool destroy testpool
zpool labelclear -f /dev/disk/by-id/<ata-id-1>-part1 ; zpool labelclear -f /dev/disk/by-id/<ata-id-2>-part1
wipefs -a /dev/sda ; wipefs -a /dev/sdb
```

**Keep the boot parameter** if it was needed: it stays until a kernel that prints `forcing 32bit`
is running, which then makes it redundant.

---

## Before you fly home

```sh
scp -r root@<ip>:/root/acceptance ./nas-acceptance/    # from the laptop
```

Keep those files — they are the drives' day-zero baseline. Also keep **every box, tray screw,
accessory and receipt** until the box is running in Argentina. *(N5 Air)* The 64 GB factory drive
stays fitted and untouched until then; your RAM and NVMe come out before any return.

**Leave Proxmox installed.** It is the same version the final build uses, so the machine arrives
ready to configure. **Do not create the real ZFS pool during the trip** (Phase D's `testpool` is
destroyed in D5): it is built at home from
`/dev/disk/by-id/` with `acltype=posixacl` and `xattr=sa` set *before* any data lands, and those
properties are painful to retrofit onto 1.6 TB.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Will not boot from USB | **Del** → Secure Boot Disabled, USB first in boot order. Try another USB port. If still nothing, rewrite the stick in **DD mode**. |
| Boots into MinisCloud after install | BIOS boot order: Proxmox (`Linux Boot Manager` / the 660p) first. |
| HDDs not listed after fitting RAM | Reseat the internal drive-slot connector (known N5 quirk); check `Offboard SATA Controller Driver = Enabled`. |
| Proxmox graphical installer is a black screen | Reboot, pick **Terminal UI** from the installer menu. |
| SMART test returns `aborted by host` | Something spun the drive down. Re-run B3, then B4. |
| `smartctl`: *"device lacks SMART capability"* | You addressed a USB-bridged device. Use the SATA `/dev/sdX`, or add `-d sat` for a USB enclosure. |
| Cannot find the NAS's IP | At the console `ip -brief a`, or check the router's DHCP leases for `nas-test`. |
| IP known but `ssh` times out on the house network | Client isolation, or the router gave the old address to another device after a power-off. Switch to the direct-cable alternative: at the console, edit `/etc/network/interfaces` (`address 192.168.2.2/24`, `gateway 192.168.2.1`), `/etc/hosts` to the same IP, then `ifreload -a`. |
| `apt update` 401 on the enterprise repo | Expected without a subscription; harmless. Silence it with `Enabled: false` in `/etc/apt/sources.list.d/pve-enterprise.sources`. |
| Installer is missing an NVMe | Reseat the missing one; check the BIOS lists it (A2). If the drive works in another slot, the slot is dead: that is a **chassis return** reason. |

## Related

[2026-09-08_nas-chassis-decision-and-acceptance-test.md](2026-09-08_nas-chassis-decision-and-acceptance-test.md)
— why each test exists, the SKU price targets, and the BACKUP_A/B cable spec.
[memory_nas-project.md](memory_nas-project.md) — buy list and open decisions.
[2026-09-07_nas-software-stack.md](2026-09-07_nas-software-stack.md) — what gets built once home.
