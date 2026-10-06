# Minisforum N5 Air — Build & Maintenance Brief

**Status:** open
**Status detail:** hardware purchased 2026-10-06, delivery 2026-10-07 (US), acceptance test not yet run
**Host:** (project)
**Supersedes:** 2026-09-10_nas-chassis-price-correction-f4-424-pro.md (§3 chassis decision only)
**Superseded-by:** —

**Purpose:** hand-off document for the Claude instance that will install and maintain this machine.
**Author context:** research + purchase decision conversation, 2026-10-06 (outside this repo;
cross-checked against the repo the same day — see banner).

> **CORRECTED 2026-10-06 — cross-check against this repo's existing decisions.** The brief was
> written without the repo; where it disagrees, the repo wins:
>
> - **§4 is not the procedure.** The field procedure is
>   [2026-09-08_nas-us-acceptance-test-runbook.md](2026-09-08_nas-us-acceptance-test-runbook.md),
>   updated for this chassis, including the JMB585 test. §4 step 6's pool is a **throwaway test
>   pool**; the real `tank` is still built at home.
> - **§5 "remove the other M.2 SSDs during setup"** does not apply: the boot disk is a **ZFS
>   mirror of the 660p + 256 GB** ([2026-10-04_nas_boot-nvme-mirror.md](2026-10-04_nas_boot-nvme-mirror.md)),
>   so both are fitted and selected in the installer.
> - **§6 "the owner's existing host runs 6.17.2"** is wrong: gr-srv03 runs **7.0.14-15-pve**
>   (pinned), on PVE 9.2 — the same series the 9.2-1 ISO installs. Relevant to §3: the JMB585
>   fix is said to ship in 7.0, so the stock kernel may already carry it. Verify via the
>   `forcing 32bit` dmesg line, don't assume.
> - **§9 `chmod 777` for unprivileged bind mounts is retired** — PVE 9.2 `idmap=passthrough`
>   replaces it, and Samba already depends on it
>   ([2026-09-07_nas-software-stack.md](2026-09-07_nas-software-stack.md)).
> - **§9 "Docker/Podman in LXC with nesting"**: fleet rule is **Docker only inside VMs, podman
>   inside LXCs** ([2026-09-30_nas_32gb-allocation-vm-and-docker-revision.md](2026-09-30_nas_32gb-allocation-vm-and-docker-revision.md) §4).
> - **§9 "document in `/root/*.md`"**: docs live in this repo (`docs/`), not on the host.
>   Scripts go in a git repo under `/opt/`, as on gr-srv03.
> - **§9 Pushover**: errors only, never success or routine status.
> - **§1/§2 size and weight**: 199 × 202 × 252 mm, 4.0 kg, vs the F4-424 Pro's 150 × 122 × 219 mm
>   the shelf was measured for (09-08). **Re-check the shelf fit.** Carry weight with 2× 6 TB is
>   ~5.4 kg.
> - **The RAM allocation in the 09-30 doc stands unchanged** (still 32 GB), and the "two M.2
>   slots" and "32 GB ceiling" trade-offs of the F4-424 Pro no longer apply (3 slots, 96 GB max).

---

## 1. What was bought and why

**Unit:** MINISFORUM N5 Air, 5-bay desktop NAS, barebone + 64 GB OS storage
**Amazon ASIN:** B0GHQR2Z31 — variant `N5 Air-H255 0/64GB`
**Price:** $519.00 USD
**Ships from:** Amazon · **Sold by:** MINISFORUM US
**Delivery:** 2026-10-07 to a US address (Sunrise, FL 33351), then hand-carried to Argentina
**Returns:** free 30-day refund/replacement, customer service by Amazon

**Why this unit:** the owner already has 2× Kingston KVR48S40BS8-16 (DDR5-4800 SO-DIMM, 16 GB each, non-ECC, 1.1 V, SK Hynix). The N5 Air has two SO-DIMM slots, so both sticks go in for **32 GB** at no extra cost. Competing boxed NAS units either solder/pre-populate their single slot (TerraMaster F4-424 Pro, 32 GB in one non-upgradable slot, $644.99) or cost more for the same result (UGREEN DXP4800 Plus, $619.98).

**Intended workload:**
- Proxmox VE (not the vendor OS)
- ZFS mirror of 2× 6 TB HDDs; growth path = a second mirror in the spare bays
- Samba LXC
- Immich LXC (photo/video library, ~700 GB of video)
- Proxmox Backup Server
- possibly a small Docker VM
- LAN is 1 GbE today

---

## 2. Hardware specification (verified)

| Item | Spec |
|---|---|
| CPU | AMD Ryzen 7 255, 8C/16T, up to ~4.9–5.1 GHz. PassMark multi **28,736**, single **3,715** |
| iGPU | AMD Radeon 780M, 12 CU RDNA 3, ~8.3–8.9 TFLOPS FP32 (third-party figures) |
| RAM | 2× DDR5 SO-DIMM, non-ECC, vendor says DDR5-5600, **max 96 GB** |
| HDD bays | 5× SATA, 2.5"/3.5", up to 30 TB each |
| M.2 | 3 slots (2230/2280/22110), U.2 adapter included. 64 GB MinisCloud OS drive pre-installed |
| Networking | 1× 10GbE (Realtek RTL8127) + 1× 5GbE (Realtek RTL8126) |
| Other I/O | 2× USB4 (8K), 3× USB 3.2 Gen 2-A, USB 2.0, internal USB 3.2, 8K HDMI, OCuLink, PCIe x16 slot |
| Chassis | 199 × 202 × 252 mm (~10.1 L), **4.0 kg**, plastic body |
| Power | ~26–27 W idle with SATA SSDs, ~81–83 W under full CPU load (NASCompares). 280 W 19 V external brick |

**M.2 lane layout — vendor spec and measurements disagree. Verify on arrival.**
- Minisforum store spec: Slot A PCIe 4.0 x1, Slot B PCIe 4.0 x2, Slot C PCIe 4.0 x1; OS drive in Slot 1
- LocalHake hands-on: Slot 1 negotiated **4.0 x4**, Slot 3 **4.0 x2**, OS drive in Slot 2 at **2.0 x1**

**Note on the CPU variant:** Amazon's variant string says `H255`, the title says Ryzen 7 255. These are two real, near-identical parts (PassMark 28,151 vs 28,728). The H255 has a 45 W TDP vs 28 W, so idle and thermals may run slightly higher. Confirm with `lscpu` on arrival.

**Power for Argentina:** external 100–240 V brick. Plug adapter only, no transformer. Confirm the label on arrival.

---

## 3. ⚠️ CRITICAL: JMB585 SATA controller silent data corruption

> **CORRECTED 2026-10-06 — upstream found the root cause (LKML, September 2026), and it changes
> two conclusions below.**
>
> - **Root cause is the BIOS, not the JMB585.** The BIOS enables PCIe root-port **"enhanced
>   atomics"**, which repurposes the upper address bits, so 64-bit DMA addresses reaching them
>   corrupt. The JMB585 just exposed it.
> - **The N5 Air *is* on an affected platform.** The fix targets NBIO 7.7 (**Phoenix, Hawk Point**
>   — Zen 4) and NBIO 7.11 (Strix, Krackan, Strix Halo). The Ryzen 7 255 is Hawk Point. The
>   "Zen 4 may be less exposed" inference below is **wrong**.
> - **Fixes, by kernel**: (1) JMB585 forced to 32-bit DMA — mainline 7.0, AUTOSEL-backported to
>   older stable kernels; on some boards it made the controller unusable at probe (loud, not silent),
>   fixed by `ata: libahci: clear PxCLBU and PxFBU` (82e47533221d, 7.3-rc3, Cc stable).
>   (2) **Root-cause fix**: an x86 PCI quirk disabling enhanced atomics at boot/resume — 7.3,
>   Cc stable; the 32-bit quirk is then **reverted in 7.4**. (3) `amd_iommu=pgtbl_v2` — any kernel.
> - **Decision (user, 2026-10-06): not a return reason.** Software fixes exist and ZFS checksums
>   detect anything that slips through. The runbook's Phase D now **verifies the mitigation before
>   real data lands**, it no longer decides the return. Open: which fix the PVE 9.2 7.0 kernel
>   carries, and when a PVE kernel gets the 7.3 root-cause fix.
>
> Sources: [LKML "Fix for storage corruption w/ AMD"](https://ratatoskr.run/lkml/2026/09/17533339/t),
> [libahci PxCLBU fix](https://ratatoskr.run/stable/2026/09/17514448/t),
> [JMB585 32-bit patch v4](https://ratatoskr.run/linux-ide/2026/04/16730763).

**This is the single most important item in this document. Check it before putting any real data on the pool.**

### The problem

The Minisforum N5 and N5 Pro use a **JMicron JMB585** SATA controller behind the drive bays. On Linux it causes **silent data corruption**:

- The JMB585 sets the S64A bit advertising 64-bit DMA support
- Linux trusts it and enables 64-bit DMA
- The implementation is broken: under sustained I/O, data is written to **wrong memory addresses with no errors logged**
- Under heavy mixed I/O the controller can reset, briefly dropping all SATA disks at once
- Writes in flight are corrupted **before ZFS generates checksums**, so ZFS only detects corruption after it is already committed

Three factors stack: the controller lying about 64-bit DMA; AMD Zen 5 IOMMU 5-level page tables handing out wider addresses than Zen 4; and an IOMMU V1 page-table race condition present before kernel 6.17.

This is the same bug pattern as the ASMedia ASM1061 (kernel commit `20730e9b2778`), but the JMB585 needs the stricter `AHCI_HFLAG_32BIT_ONLY` because corruption occurs at any address above 4 GB.

Reported independently on Reddit and the Level1Techs forums. Minisforum appears aware of it via their Discord but issued no public statement for over a month.

### Is the N5 Air affected?

**Unknown — this must be tested.** Two considerations:

- NASCompares says the N5 Air appears to keep the same broad internal topology as the earlier N5 generation, including the dedicated SATA controller architecture behind the 5 bays — but adds there is no basis to treat it as a confirmed N5 Air problem.
- The root-cause analysis ties part of the trigger to **Zen 5** IOMMU behavior. The N5 Air is **Zen 4**, which may make it less exposed. This is inference, not evidence.

### Detection

```bash
lspci | grep -i jmicron        # look for JMB58x
dmesg | grep -i ahci           # look for the "64bit" capability flag
```

Watch for controller resets under load:

```bash
dmesg -w
journalctl -f
# red flags: "link reset", "SATA channel disabled", drives dropping and reappearing
```

### Workaround (apply preemptively if a JMB58x is present)

Boot parameter `amd_iommu=pgtbl_v2`, found by the Minisforum Discord community. **On Proxmox VE with UEFI + proxmox-boot-tool:**

```bash
proxmox-boot-tool status          # confirm "uefi"
nano /etc/kernel/cmdline          # append amd_iommu=pgtbl_v2
proxmox-boot-tool refresh
reboot
cat /proc/cmdline | grep pgtbl_v2 # verify
```

Caveat: this works for most users but **some report it is not sufficient on its own**.

### The real fix

A kernel patch adding `AHCI_HFLAG_32BIT_ONLY` for the JMB585/JMB582 has been **accepted into mainline Linux** (commit `105c4256`) and ships in **kernel 7.0**, with a likely backport to stable kernels. After the patch, dmesg shows:

```
ahci 0000:xx:00.0: controller can't do 64bit DMA, forcing 32bit
```

**Maintenance implication:** track whether the running Proxmox kernel carries this patch. Once a kernel with it is available, prefer it over the boot-parameter workaround. Reference: https://github.com/artmoty-dev/n5pro-jmb585-fix

---

## 4. Acceptance test plan — run inside the 30-day return window

**Do this before the machine leaves the US. After that there is no return path.**

1. `lscpu` — confirm the CPU variant (255 vs H255)
2. `dmidecode -t memory` — confirm **both** 16 GB sticks detected and running at 4800 MT/s in dual channel
3. `lspci | grep -i jmicron` — **the critical check**; if JMB58x present, apply the workaround above
4. `lspci -vv` on each M.2 slot — record actual negotiated lane width per slot
5. Install Proxmox VE, boot from NVMe, confirm the vendor OS can be bypassed
6. Build the ZFS mirror and **stress it**: sustained large writes, then repeated `zpool scrub`, while watching `dmesg -w` for link resets. Check `zpool status` for checksum errors after every scrub. This is the test that matters.
7. 4K HEVC hardware transcode via VAAPI on the 780M (Immich / ffmpeg)
8. Measure idle wall power with the 2× 6 TB HDDs installed
9. 24-hour soak test
10. Confirm the PSU label reads 100–240 V

~~**Return the unit if step 6 produces any checksum errors or SATA resets that the workaround does not eliminate.**~~ Superseded 2026-10-06 — not a return reason, see the §3 banner.

---

## 5. Proxmox installation notes

Installing Proxmox on this platform is well-trodden. A step-by-step N5 guide reports the install taking **under 10 minutes**.

Procedure:
1. Write the Proxmox VE ISO to a USB stick (Ventoy works; boot in **normal mode**)
2. **Remove the other M.2 SSDs during setup** so the installer can't pick the wrong target
3. Insert USB in a front port, connect a monitor over HDMI, power on
4. Install Proxmox VE (Graphical)
5. After the reboot, **change the BIOS boot drive** to the SSD where Proxmox was installed
6. Reinstall the remaining SSDs

**Target layout:** Proxmox as a **ZFS mirror across two NVMe drives** in the two fastest slots (measured 4.0 x4 and 4.0 x2 — verify per step 4 above). The stock 64 GB MinisCloud drive can be removed or left as a spare; it negotiates only PCIe 2.0 x1.

**BIOS tip from an N5 Pro owner:** set `Advanced → Offboard SATA Controller Driver` to **Enabled** so the SATA bays enumerate as expected.

**Secure Boot:** no notes exist for the N5 family. The published guide booted the installer in normal mode without mentioning it. Proxmox VE 8.1+ media support Secure Boot, so this should not block the install, but it is unconfirmed on this unit.

---

## 6. Networking

- **Use the 5GbE port (RTL8126)** — it works with the in-kernel `r8169` driver.
- **The 10GbE port (RTL8127)** needs an out-of-tree driver on Debian 13 / kernel 6.12; native in-kernel support arrives in **kernel 6.16**. The owner's existing host already runs 6.17.2, so if this box runs a comparable kernel the 10GbE should work natively — verify.
- The LAN is 1 GbE today, so neither port is a bottleneck. Don't spend time on 10GbE.
- Realtek NICs draw consistent complaints from owners running Proxmox. The **PCIe x16 slot** is the escape hatch: an Intel NIC can be dropped in if the Realtek proves troublesome.
- One owner reports Wake-on-LAN not working on the 5G NIC under TrueNAS.

---

## 7. Known quirks and owner reports

- **Vendor OS (MinisCloud):** widely disliked. NTP servers locked to Minisforum/Chinese servers, timezone config non-functional during install. Irrelevant once wiped for Proxmox — but it is a reason not to leave it installed.
- **Drive slot connector:** one owner fitted additional RAM and lost all HDDs afterward; fixed by pulling the drive-slot connector off and reseating it. Worth knowing if drives vanish after any internal work.
- **Support and reliability reputation is poor.** One reviewer with a large sample calls Minisforum by far the highest failure rate and worst support among Beelink, GMKtec and Aoostar. Multiple reports of warranty refusals, customer-paid return shipping, and weeks of silence on orders.
- **Warranty is effectively void for this owner anyway:** Minisforum states its warranty does not cover units bought through Amazon or third-party marketplaces, and the machine is leaving the US. Treat the 30-day Amazon return window as the only real recourse.
- Positive reports exist too: owners running Proxmox with TrueNAS on top, and nested ESXi, describe the hardware as impressive and the install as straightforward.

---

## 8. Local LLM capability (asked, answered, not a purchase driver)

Memory bandwidth is the ceiling, not the GPU. Dual-channel DDR5-4800 gives ~77 GB/s theoretical, perhaps 55–65 GB/s real. Rough Q4 expectations: 7–8B ≈ 10–14 tok/s; 14B ≈ 6–8 tok/s; 30B MoE (e.g. Qwen3-30B-A3B) ≈ 15–25 tok/s; 70B dense ≈ 1–2 tok/s, not worth it. These are estimates from comparable Zen 4 iGPU systems, not measurements.

If pursued: LXC with `/dev/dri` bind-mounted, Ollama or llama.cpp on the **Vulkan** backend (least painful on a 780M; ROCm needs `HSA_OVERRIDE_GFX_VERSION=11.0.0` and is officially unsupported). Raise the UMA/GTT allocation. Note that 32 GB total gets tight once ZFS ARC takes its share, and an LLM competes with Immich transcoding for the same iGPU. **OCuLink + the PCIe x16 slot are the real upgrade path** if this becomes serious.

---

## 9. Conventions to follow (from the owner's existing homelab)

Carry these over from the gr-srv03 Proxmox host:

- **Notifications: Pushover.** Every notification must include **hostname and script name**. Credentials live at `~/etc/pushover.env` with `PUSHOVER_TOKEN`, `PUSHOVER_USER`, `DEFAULT_DEVICE=iphoneRSI`. **Errors only.**
- **Email: Resend, not SendGrid** (free tier ended). Key at `~/etc/resend.env` as `RESEND_API_KEY`. Any script still on SendGrid should be migrated.
- **Kernel updates: conservative one-boot testing.** `proxmox-boot-tool kernel pin <ver> --next-boot`, reboot, verify hardware, then `proxmox-boot-tool kernel pin <ver>` to make it permanent. A failed kernel falls back automatically on the next reboot. **This practice matters doubly here given the JMB585 patch timeline.**
- **Major upgrades:** set `DEBIAN_FRONTEND=noninteractive`, pre-seed debconf, use `--force-confold`, run inside tmux, keep a second access path (web console). Frozen whiptail dialogs have bitten this owner before; kill only the dialog, never apt/dpkg.
- **Unprivileged LXC bind mounts:** UID/GID mapping means host `chown 1000:1000` does not work. The established fix for dedicated backup mounts is `chmod 777` on the host mount point. Acceptable for single-purpose backup storage, not for shared or sensitive directories. **Retired — use `idmap=passthrough` (see banner).**
- **External backup drives:** reference by **UUID, never device name**. Critical always-on drives go in `/etc/fstab` with `nofail,noatime`. Hotplug drives use a simple systemd `.mount` unit triggered by a udev rule on `ID_FS_UUID` — **never systemd automount units**, which caused dependency failures and freezes.
- **Tailscale in LXC:** needs `lxc.cgroup2.devices.allow: c 10:200 rwm` and `lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file` in the container config.
- **Docker/Podman in LXC:** `pct set <CTID> --features nesting=1,keyctl=1`. **Podman only — Docker goes in a VM (see banner).**
- Document every change in markdown, consistent with the existing `/root/*.md` runbooks. **Docs go in the claude-ssh repo `docs/` (see banner).**

---

## 10. Unverified items

Carry these as open questions:

- Whether the N5 Air specifically ships a JMB585, and which fix the PVE 9.2 kernel carries (Hawk Point is an affected platform — §3 banner)
- Actual M.2 lane width per slot (vendor spec and review measurements conflict)
- Whether the stick is the Ryzen 7 255 or H255
- Secure Boot behavior on this unit
- Real idle power with 2× 6 TB HDDs installed (published figures are SSD-only or hibernation figures)
- Noise in dB(A) — not published
- Whether the Kingston KVR48S40BS8-16 is on any compatibility list (it is not; it is a standard JEDEC DDR5-4800 1.1 V SO-DIMM and should work)
- Whether the 10GbE RTL8127 works natively on the kernel this box ends up running

---

**Document version:** 1.0 · **Created:** 2026-10-06
