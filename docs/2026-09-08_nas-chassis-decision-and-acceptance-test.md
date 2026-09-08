# NAS — chassis decided (F4-425 Plus **N150**), 16 GB stack, cabling and the US acceptance test

**Status:** open
**Host:** (project)
**Supersedes:** 2026-09-07_nas-software-stack.md (§ *The 16 GB question is OPEN* and § *The RAM budget is the binding constraint* only)
**Superseded-by:** 2026-09-08_nas-us-acceptance-test-runbook.md (§ 5 only — the procedure moved there)

**Date**: 2026-09-08. The user measured the space and **the 4-bay chassis fits** on a new shelf,
choosing it for the RAM rather than the bays. That closes item 5 of
[memory_nas-project.md](memory_nas-project.md) — but checking the vendor store to place the order
turned up a **fourth spec error on this chassis**, and it inverts which SKU to buy.

## 1. CORRECTION — the 16 GB belongs to the **N150**, not the N95

[2026-09-07_nas-software-stack.md](2026-09-07_nas-software-stack.md) records *"F4-425 Plus N95
($510): 16 GB — confirmed by TerraMaster customer support 2026-09-07"*. **That is wrong.**
TerraMaster's own product page sells the two CPU variants as separate configurations with
different memory:

| SKU | CPU | Pre-installed RAM | Store price 2026-09-08 |
|---|---|---|---|
| F2-425 Plus | N95 / N150 | **8 GB** (both) | **$424.99** (was $499.99) |
| F4-425 Plus | N95 | **8 GB** | **$479.99** (was $599.99) |
| **F4-425 Plus** | **N150** | **16 GB** (1× 16 GB, max 32 GB) | **$479.99** (was $599.99) |

Sources: the [F4-425 Plus product page](https://www.terra-master.com/en-us/products/f4-425-plus)
("*Equipped with an Intel N150 processor, 16GB DDR5 memory*" / "*Intel N95 processor, 8GB DDR5
memory*"), the [F2-425 Plus page](https://www.terra-master.com/products/f2-425-plus), and the
[F4-425 Plus datasheet](https://download2.terra-master.com/F4-425_Plus.pdf), whose spec table is
the **N150** one — which is exactly why it said 16 GB. The 09-07 doc even flagged that the
datasheets in [`download/`](../download/) *"document the N150 variants only"*; the 16 GB row was
then mistakenly attributed to the N95 and a support reply appeared to confirm it.

> **Rule reinforced, now with a fourth data point:** on this chassis, trust the **vendor product
> page or datasheet, matched to the exact SKU** — not aggregators (nasdrives.co.uk "two slots"),
> not Amazon listings, and **not customer support**. Support was wrong here in the same direction
> the buyer wanted, which is the dangerous kind.

### What it changes

**Both variants cost the same, so the RAM decides the CPU and the CPU premium is zero.**
The 2026-08-30 "N95, not N150, not worth $42" decision is not overturned on its merits — it is
simply moot: there is no longer a price to weigh. Buying 16 GB *is* buying the N150.

The N150 is also the better fit for what the stack turned into: 24 EU Gen12 iGPU vs the N95's 16
EU, plus AV1, against a 708 GB video library that Immich will transcode once on ingest. The
08-30 reasoning explicitly assumed "no transcoding use case is planned"; that assumption died
when the software stack was designed.

### Revised buy list

| Item | Source | Price |
|---|---|---|
| **TerraMaster F4-425 Plus — N150 variant, 16 GB** | terra-master.com | **$479.99** |
| HGST Ultrastar 7K6000 HUS726060ALE610 6 TB, cert. refurb | goHardDrive g01-1079 | $179.95 |
| Seagate Exos 7E8 ST6000NM0115 6 TB, enterprise | goHardDrive g01-1326 | $189.95 |
| Patriot P310 480 GB NVMe — PVE boot | Amazon/Walmart/B&H | $65.00 |
| **Total** | | **$914.89** |

That is **$30 below** the $944.90 the 09-07 doc costed the F4 at, and **$55 above** the F2 path —
not the $111 previously believed. The $479.99 is a 20% sale price; street pricing for this SKU has
been seen between ~$456 and ~$520, so **re-check before ordering** and buy on a dip if the trip
timing allows.

### AVAILABILITY — the N150 SKU is not on terra-master.com right now (checked by the user, 2026-09-08)

The vendor store currently lists **only the N95 (8 GB) F4-425 Plus**. The N150/16 GB SKU is a
separate product with its own listings elsewhere:

- **Amazon US — ASIN [`B0FLHTF2PQ`](https://us.amazon.com/dp/B0FLHTF2PQ)**, *"F4-425 Plus … Intel
  N150 Quad-Core CPU, 16GB RAM DDR5"* (the N95/8 GB is a **different** ASIN, `B0GW883KMF` — check
  the title, both say "F4-425 Plus")
- **[Newegg](https://www.newegg.com/terra-master-f4-425-plus/p/14P-006A-00099)**, same SKU
- Street price seen $455.99 – $519.99 over recent months

Buying from a US retailer is preferable anyway for this trip — domestic delivery and a real return
window. **Re-check at buy time; the SKU must be confirmed from the listing title, not the model
name.**

### Price targets — the buy-time decision table

Only **four SKUs exist**. Two facts kill most of the confusion: **the F2 is 2 bays** (not 4), and
**the F4 N95 ships with 8 GB** — 16 GB belongs to the N150 alone.

Reference points: TerraMaster list is $599.99 (F4) / $499.99 (F2), currently discounted to
$479.99 / $424.99. Street prices observed for the F4 N150 over recent months: **$455.99,
$484.99, $492.99, $519.99**. The F2 has floated **$383–$425**. An aftermarket 16 GB DDR5 SODIMM is
**~$209** in the ongoing DRAM shortage, and the single slot means it **replaces** the bundled
stick rather than joining it.

| # | SKU | RAM | Bays | **Target — buy at or below** | **Walk away above** | Project total at target |
|---|---|---|---|---|---|---|
| **1** | **F4-425 Plus N150** | **16 GB** | **4** | **$470** | **$520** | **~$905** |
| 2 | F2-425 Plus N150 | 8 GB | 2 | $400 | $440 | ~$835 |
| 3 | F2-425 Plus N95 | 8 GB | 2 | $385 | $415 | ~$820 |
| 4 | F4-425 Plus N95 | 8 GB | 4 | $440 | $455 | ~$875 |

*Project total = chassis + $179.95 + $189.95 + $65.00 (the two 6 TB recerts and the P310).*

**How the targets were set, so they can be re-derived if prices move:**

- **#1 is the reference and the first choice.** $470 sits between the observed floor ($456) and the
  current sale ($480); above $520 the whole street range has been beaten historically, so wait or
  buy elsewhere rather than pay it.
- **#4 must be priced as an 8 GB machine**, because reaching 16 GB costs a further $209 and pushes
  the all-in to ~$689 — **$219 worse than #1 for an identical result.** So its only honest value is
  "an F2 with two spare bays": F2 target plus ~$45. At its $479.99 list it is **overpriced against
  every alternative** and should not be bought. *Buy #4 only if it appears at or under $455 and
  #1 is unavailable.*
- **#2 and #3 are the same machine** for this workload — same 8 GB, same 2 bays, same M.2 count,
  same LAN. Only the iGPU differs (N150: 24 EU + AV1; N95: 16 EU, no AV1). Given Immich will
  transcode 708 GB of video once on ingest, the N150 is worth roughly **$25**, no more — so take
  the N95 only when it is at least that much cheaper.
- **Both F2 options reinstate the compromise this project spent 09-07 trying to escape**: at 8 GB
  the all-LXC budget does not fit, and either ARC drops to 1 GB or Immich ML goes off, costing face
  recognition and smart search — the reason Immich was chosen over a plain gallery. Price them
  accordingly: they are cheaper machines, not equivalent ones.
- **"F4-425 Plus N95 with 16 GB" is not a factory SKU.** If a listing claims it, it is either a
  retailer that fitted an aftermarket stick (legitimate, and worth up to ~$500 — treat it as #1
  minus the iGPU) or the **fifth** spec error on this chassis. Confirm from the listing title and
  the seller, not the model name.

**Buy-time procedure**: check Amazon US `B0FLHTF2PQ` (N150/16 GB) and Newegg first, then
terra-master.com. Only if #1 is unavailable across all three does anything below it apply.

**Optional, and worth deciding before the trip: a third 6 TB drive as a cold spare (~$180).**
Not needed for capacity — it is about logistics. Once the box is in Argentina, sourcing a
replacement 6 TB for a failed mirror half is slow and expensive, and the pool runs unprotected
until it arrives. The trip is the cheap moment to buy insurance, and the F4 now has the bays to
hold it. User's call; not assumed in the total above.

## 2. Software stack at 16 GB — the compromises are withdrawn

The 09-07 budget totalled 7.5–9 GB against 8 GB and did not fit, forcing a choice between capping
ARC at 1 GB and disabling Immich ML. **Neither is needed now.**

| | 8 GB plan (09-07) | **16 GB plan (09-08)** |
|---|---|---|
| PVE host + kernel | ~1 GB | 1.0 GB |
| ZFS ARC (`zfs_arc_max`) | 2 GB, or 1 GB under pressure | **4.0 GB** |
| `smb` LXC | 0.5 GB | 0.75 GB |
| `pbs` LXC | 1–1.5 GB | **2.0 GB** |
| `immich` LXC | 3–4 GB, **ML off** | **6.0 GB, ML on** |
| **Allocated** | 7.5–9 GB | **13.75 GB** |
| **Headroom** | −1 to +0.5 GB | **~2.25 GB** |

Inside the 6 GB Immich container:

| Service | RAM |
|---|---|
| `immich-machine-learning` (CLIP ViT-B/32 + `buffalo_l` face model, OpenVINO on the iGPU) | 2.5 GB |
| `immich-server` (Node) | 1.5 GB |
| `postgres` + VectorChord (`shared_buffers` 512 MB) | 1.0 GB |
| `redis` | 0.15 GB |
| burst / page cache | ~0.85 GB |

Consequences for the decisions already taken:

1. **Immich keeps face recognition and smart search.** These were the reason Immich was chosen
   over a plain gallery; at 8 GB they were the thing being traded away.
2. **ARC gets a real cap, not a starvation cap.** `zfs_arc_max=4G`, `zfs_arc_min=1G` in
   `/etc/modprobe.d/zfs.conf`. Still explicit — ZFS defaults to half of RAM (8 GB here), which
   would collide with the guests.
3. **The "PBS on the PVE host" fallback is dead.** It existed only to reclaim the LXC's 1–1.5 GB.
   PBS stays an unprivileged LXC with a bind-mounted datastore, and PBS at 2 GB is comfortable for
   verify and GC at this datastore size.
4. **Everything else in [2026-09-07_nas-software-stack.md](2026-09-07_nas-software-stack.md) is
   unchanged and still current** — all-LXC, ZFS mirror on raw SATA, unprivileged Samba with
   `idmap=passthrough`, podman for Immich, SMB/PBS/SFTP/HTTPS, no NFS, the restic restore source.
   Only the two RAM sections above are superseded.

### What the two spare bays are for

The growth path is **`zpool add tank mirror <disk3> <disk4>`** — a second mirror vdev striped with
the first, taking the pool from 5.45 TiB to ~10.9 TiB, with no rebuild and no downtime.
**Do not plan on RAIDZ**: a mirror pool cannot be converted to RAIDZ, and RAIDZ1 across 4×6 TB
would mean buying two more drives up front for capacity that day one does not need (3.1 TB used
of 5.45 TiB). Leave the bays empty until they are needed.

### What the two spare M.2 slots are *not* for

Three M.2 slots, one taken by the P310 boot drive. At 16 GB with a 4 GB ARC there is **no case for
L2ARC** (it consumes ARC for headers, and the working set is not read-hot). A **metadata `special`
vdev** would help SMB directory walks and restic/PBS chunk lookups, but it must be **mirrored**
(losing it loses the pool) and it only catches *new* writes — so it would have to be in place
**before the 1.6 TB restore, or never**. Recommendation: **skip it.** Noted here so the "add it
later" instinct is not acted on after the restore, when it can no longer help.

## 3. BACKUP_A/B on a 60 cm cable — specification

The rotating drive moves off gr-srv03 and hangs off the NAS. The F4-425 Plus has **four USB
ports at 10 Gbps — one front Type-A, two rear Type-A, one rear Type-C**. Use the **front Type-A**
for the rotating drive: the weekly offsite swap is a hot-plug by hand, and a front port means no
reaching behind the chassis, no strain on the cable, and no disturbing the rear cabling.

**The drive**: Toshiba Canvio Basics 3 TB, `0480:a202`, mechanism MQ03UBB300 — a bus-powered
2.5" USB 3.0 portable with a **SuperSpeed Micro-B (10-pin)** socket. *Confirm by eye before
buying* — a newer replacement unit could be USB-C, in which case buy A→C instead and everything
below still applies.

| Spec | Requirement | Why |
|---|---|---|
| Connectors | **USB 3.0/3.2 Gen1 Standard-A male → SuperSpeed Micro-B male** | see the trap below |
| Length | **0.5–0.6 m** | shorter is better; do not exceed 1 m |
| **Power-pair gauge** | **≥ 24 AWG, prefer 22 AWG** — look for a jacket marking like `28AWG/1P + 28AWG/2C + 22AWG/2C` (the last figure is VBUS/GND) | the one spec that actually matters — see below |
| Data pairs | 28/30 AWG twisted, individually shielded | standard on any real SS cable |
| Rating | USB-IF certified, 5 Gbps minimum, full 9-conductor | |
| Shielding | foil **+** braid with drain wire; integrated ferrite a bonus | |
| Build | molded, strain-relieved plugs; right-angle Micro-B only if clearance demands it | SS Micro-B plugs are mechanically fragile |
| Path | **direct, single cable** — no extension, no hub, no adapters | |

**Why the gauge matters.** The Canvio is bus-powered and rated 5 V / 0.9 A, which is the entire
USB 3.x budget for one port, and its peak is at **spin-up** — which happens nightly, because APM
level 128 spins these drives down after ~10 min idle
([Backup_Drives_Mounting_Configuration.md](Backup_Drives_Mounting_Configuration.md)). Round-trip
drop over 0.6 m at 0.9 A:

| Power pair | Round-trip resistance | Drop at 0.9 A |
|---|---|---|
| 28 AWG (cheap cable) | ~0.26 Ω | **~0.23 V** |
| 24 AWG | ~0.10 Ω | ~0.09 V |
| **22 AWG** | ~0.06 Ω | **~0.06 V** |

Nothing here is exotic; the point is margin at spin-up. This host family already has the failure
mode on record — the 2026-07-15 incident presented as a drive that *"cannot enable, maybe the USB
cable is bad"* with 9000+ retries, and the low-power dongles on the same hub were unaffected
because only the HDD stressed the rail
([memory_gr-srv03_powered-hub-instability.md](memory_gr-srv03_powered-hub-instability.md)).

**The trap to avoid: a USB 2.0 Micro-B cable physically plugs into the left half of a SuperSpeed
Micro-B socket** and works — at 480 Mbps, ~35 MB/s, **with no error anywhere**. A 1.4 TB restic
run would take a day and a half and nothing would say why. Buy the 10-pin SuperSpeed plug and
verify after connecting: `lsusb -t` must show `5000M`, not `480M`.

**Fallbacks if the drive proves marginal on one port**: a USB 3.0 **Y-cable** (two A plugs, one
for data + power, one for power only), or the rear **Type-C** port with an A-less C→Micro-B cable,
which has a larger current budget. Neither should be needed.

**Buy two** — one as the spare, on the same US trip. It is a $10 item that is annoying to source
locally and is in the path of the only offsite backup.

## 4. The USB hub on gr-srv03 — reassessed

**Port arithmetic after the NAS**: gr-srv03 has 3 external USB-A ports and will have exactly 3
devices — Zigbee dongle, `backup_usb1` (Kingston XS1000), RTL-433 SDR. **Fits, with zero spare.**
So "a hub is mandatory" is dead, but "I want spare ports" is a fair want.

**Keep the RSH-A10** (ordered 08-29, ETA ~10-24) rather than treating it as waste. It is the only
**PPPS / `uhubctl`-capable** device in the fleet, verified on all ports — that is what lets a
wedged RTL-433 be power-cycled from a script without a person walking to the machine.

**On the planned unpowered-hub test, three findings:**

1. **Current is not the risk.** A bus-powered hub on a USB 3.x host port has a 900 mA budget less
   ~50–100 mA of hub silicon. RTL-SDR ≈ 280–320 mA continuous (and it runs hot), Sonoff Zigbee
   dongle ≈ 60–100 mA. Total ~400 mA against ~800 mA available — roughly 2× margin. On a **USB 2.0
   host port** the budget is 500 mA and that margin evaporates, so the hub must go on a USB 3 port.
2. **Do not put the Zigbee dongle behind any hub, powered or not.** On this exact host a hub in
   the Zigbee path produced `disabled by hub (EMI?)` and `cp210x` disconnects every few minutes,
   causing 5 zigbee2mqtt restarts in one evening (2026-08-17, same doc as above). Option D already
   gives Zigbee its own direct port for this reason. Test the hub with the **RTL-433 alone**.
3. **Prefer a USB 2.0 hub for the SDR, not USB 3.0.** SuperSpeed signalling is a well-known
   broadband RFI source that desenses 2.4 GHz radios and lifts the noise floor of an SDR sitting
   beside it. The RTL-433 is a USB 2.0 device and gains nothing from a USB 3 hub, so a USB 2.0 hub
   removes the noise source for free. If a USB 3.0 hub is used anyway, keep it and its cable
   physically away from the Zigbee dongle and the SDR antenna.

**Timing.** The Zigbee **LQI relapse recheck is due 2026-09-09**
([2026-08-24_docker03_zigbee-coordinator-rf-degradation.md](2026-08-24_docker03_zigbee-coordinator-rf-degradation.md)).
Introducing a hub before that closes adds a variable to an open investigation. **Test the hub
after the recheck lands, not before.**

**Also note** the RTL-433 is itself slated to move to cygnus/CT207
([memory_gr-srv03_rtl433-ct207.md](memory_gr-srv03_rtl433-ct207.md)), which would free a third
port on gr-srv03 and make the hub unnecessary even for spares.

## 5. Testing the NAS and the used drives before returning from the USA

> **The procedure moved 2026-09-08 to
> [2026-09-08_nas-us-acceptance-test-runbook.md](2026-09-08_nas-us-acceptance-test-runbook.md)** —
> a self-contained field document meant to be followed offline, with the download links, the USB
> preparation, the SMART pass/fail table and troubleshooting. **Follow that, not this section.**

What remains here is *why* the test is shaped the way it is:

**The shape**: a **15-minute Proxmox VE install on the NVMe the first evening** turns the NAS into
an SSH target, and everything afterwards is done from the laptop. The monitor and keyboard are
needed once. This was chosen over living in a SystemRescue session because the install **does not
depend on the hard drives** — and the drives are being bought after the chassis, so the chassis
must be testable on its own. It also means the machine comes home already running the same PVE
generation the final build uses. SystemRescue still travels, for **memtest86+** (the only test that
proves the 16 GB is *good* rather than merely *present*) and as a fallback if the install fails.

**What each phase is buying:**

- **Phase A validates the purchase decision.** The BIOS memory reading is the check that matters —
  16 GB is the entire reason the F4 was chosen over the cheaper F2, and the figure so far comes from
  vendor web pages rather than from the machine. Everything else in the project rests on it.
- **Phase B is about the *secondhand* drives**, which is where the real risk sits. A long SMART
  self-test reads the whole surface using the drive's own controller, so it needs no host I/O and
  survives being left overnight — ~10–13 h for 6 TB, both in parallel. The optional concurrent
  `dd` write pass exists because the self-test is read-only and drive-internal: it is the only
  check that loads the **backplane and PSU** with both drives writing at once.
- **Phase C closes the last unverified purchase item** — fan noise with 7200 rpm recert drives
  spinning. TerraMaster's 20.9 dB(A) is a drives-in-standby figure, so it can only be judged with
  the drives running, and only the USA leg offers a return if it is intolerable.

**Sequencing risk** (see the sub-section above): the SATA bays cannot be tested until a drive is
in, so part of the *chassis's* return window is hostage to the drive order.

## Related

[memory_nas-project.md](memory_nas-project.md) — scope, buy list, rejected options.
[2026-09-07_nas-software-stack.md](2026-09-07_nas-software-stack.md) — the full stack design; its
two RAM sections are superseded by §2 above, the rest is current.
[2026-08-19_gr-srv03_usb-hub-layout-plan.md](2026-08-19_gr-srv03_usb-hub-layout-plan.md) — the hub
layout §4 reassesses.
[memory_gr-srv03_powered-hub-instability.md](memory_gr-srv03_powered-hub-instability.md) — why a
hub never goes in the Zigbee path, and the spin-up current failure mode behind the cable spec.
[2026-09-06_ceres_wdmycloud-nas-dead.md](2026-09-06_ceres_wdmycloud-nas-dead.md) — why this is
urgent.
