# NAS project — hardware/OS research (first pass)

**Date**: 2026-08-19. **Status**: research for decision. Nothing purchased.
Preferences and scope: [[docs/memory_nas-project.md]].

## 1. Market context (the finding that drives everything else)

The hard-drive market is in a multi-year shortage:

- HDD prices are up **~46% since September 2025**, at two-year highs.
- WD is "pretty much sold out for calendar 2026"; Seagate can fill ~50–66% of near-term demand.
- Supply agreements are booked into 2027–2028. Enterprise lead times ~12 months.
- Consensus forecast: **no meaningful relief before 2027**, possibly 2028.

Three consequences for this project:

1. **Waiting is not a strategy.** Buying later most likely costs more, not less.
2. **$/TB now favours capacities larger than needed.** New consumer NAS drives run $32–43/TB,
   while recertified enterprise drives sit far below that. The usual "buy only what you need"
   logic is inverted at the moment.
3. **The <USD 600 budget does not reach the required capacity with new drives.** See §4.

## 2. Revised sizing (with the 2026-08-19 answers)

| Item | Size | Offsite? |
|---|---|---|
| Live shares from WDMyCloud, incl. Peliculas | 1.6 TB | Peliculas (263 GB) **excluded**, as today |
| Backups absorbed from backup_usb1 + PBS datastore with more history | 0.3–0.5 TB | **yes** |
| Time Machine (1 TB MacBook, not filled for a while) | plan 1.0 TB quota | **yes** |
| **NAS day one** | **~3.1 TB** | |
| **Offsite subset** (everything except Peliculas) | **~2.75 TB** | must fit BACKUP_A/B |

BACKUP_A/B can grow to 4 TB (3.6 TiB usable) → the offsite copy lands at ~76% on day one.
Workable, but it is the tighter of the two constraints and will bind before the NAS does.

**NAS usable capacity needed**: 3.1 TB day one plus photo/video growth.
- 2×4 TB mirror = 3.6 TiB usable → **86% full on day one. Not viable.**
- 2×6 TB mirror = 5.45 TiB usable → 57% day one. **Comfortable for years.**
- 2×8 TB mirror = 7.3 TiB usable → 42% day one. More than asked for, but see §4 on price.

## 3. Hardware options

### Enclosures (diskless, US prices, Aug 2026)

| Model | Bays | CPU | Notes | Price |
|---|---|---|---|---|
| TerraMaster F2-425 | 2 | Intel N150 | Cheapest capable x86 2-bay | **$255** |
| UGREEN NASync DXP2800 | 2 | Intel N100, 8 GB DDR5 | 2× M.2 NVMe, 2.5GbE, HDMI out | **$297** (Walmart) / $370 official |
| TerraMaster F4-425 | 4 | Intel N150 | Add disks later instead of replacing | **$365** |
| DIY N100 mini-ITX + case + PSU + RAM | 4–6 | N100/N150 | No cheaper than the above at 2 bays, and much bulkier to carry | ~$250–350 |

**DIY does not win here.** At 2 bays a turnkey box is cheaper, smaller, quieter and lighter to
bring back than anything assembled from parts. DIY only pays off at 4+ bays, or if ECC is wanted.
All of these are ordinary x86 machines with HDMI output, so a third-party OS (Proxmox, TrueNAS)
can be installed on them — that must be confirmed per model before buying (§7).

Both N100 and N150 include Intel QuickSync, which covers Immich's thumbnail/transcode work
and Jellyfin later if wanted. CPU is not a differentiator at this scale.

### Drives (prices are volatile — verify at purchase)

| Drive | Capacity | Price | $/TB | Note |
|---|---|---|---|---|
| WD Red Plus WD80EFZZ, new | 8 TB | $256–340 | $32–43 | Sources disagree; check on the day |
| WD Red Plus WD80EFZZ, renewed | 8 TB | ~$275 | $34 | Seller warranty, not manufacturer |
| Seagate IronWolf ST6000VN006, new | 6 TB | ~$230–260 | $38–43 | 5400 rpm, quiet |
| WD Red Plus WD60EFPX, new | 6 TB | from ~$260 | ~$43 | 5400 rpm, quiet |
| Recertified enterprise (Exos/Ultrastar) | 8 TB+ | **needs verification** | ~$15–25 | Best $/TB by far; 7200 rpm, **louder and hotter** |

## 4. Budget reality

| Build | Cost | Verdict |
|---|---|---|
| F2-425 + 2×4 TB new | ~$555 | In budget, but 86% full day one — **not viable** |
| F2-425 + 2×6 TB new | **$715–775** | Right capacity, **~$150 over budget** |
| F2-425 + 2×8 TB renewed WD Red Plus | ~$805 | Over budget |
| F2-425 + 2×8 TB recertified enterprise | **~$550–600 (if recert 8 TB ≈ $150)** | In budget, **needs price verification**; 7200 rpm noise |
| F4-425 + 2×6 TB new, add disks later | $825–885 | Best growth path, worst up-front cost |

The honest conclusion: **at August 2026 prices, <USD 600 and "enough capacity with headroom" are
not simultaneously satisfiable with new consumer NAS drives.** One of three things has to give:

- **(a) Budget rises to ~$750** → F2-425 + 2×6 TB new. Quiet, warrantied, 5.45 TiB usable.
- **(b) Accept recertified enterprise drives** → likely stays under $600 for *more* capacity,
  at the cost of 7200 rpm noise/heat and a seller-only warranty. Noise matters given the
  placement preference.
- **(c) Shrink the scope** → drop Peliculas from the NAS and cap Time Machine at 500 GB, which
  brings day one to ~2.4 TB. Even then 2×4 TB is only a 3-year answer, so this mostly delays
  the same decision.

Recommendation: **(a) if the extra ~$150 is acceptable, otherwise (b)** — and buy sooner rather
than later, since the trend is upward.

## 5. OS recommendation

| Option | Fit |
|---|---|
| **Proxmox VE + ZFS mirror** | **Recommended.** Reuses knowledge already in this homelab, no licence cost, PBS installs directly on it with a *local* datastore, Immich in an LXC, SMB from an LXC. Trade-off: no polished NAS GUI — sharing is set up by hand. |
| TrueNAS Community Edition (25.10) | Storage-first, ZFS, good SMB/snapshot UI, Docker apps incl. Immich. VM support is the weak spot, so PBS would have to live elsewhere. |
| Unraid 7 | Best app ecosystem and the only one that lets disks be added **one at a time** in mixed sizes — genuinely valuable during a shortage. Paid licence. |
| Vendor OS (TOS / UGOS) | Fine for SMB + Time Machine + Docker Immich, but PBS on the NAS is out. |

The family-facing experience does not depend on this choice: Immich provides it, and Windows
Explorer keeps working over SMB regardless.

## 6. PBS placement — recommendation

**Run PBS on the NAS, with a local datastore.** Reasons:

- A PBS datastore on NFS is discouraged: the chunk store is fsync- and latency-sensitive, and
  an NFS-backed datastore is both slower and more fragile.
- It puts the backup server on **different hardware from the machine it protects** (gr-srv03),
  which is the correct failure separation — today's vzdump backups sit on a USB disk on the very
  host they back up.
- It replaces the 171 GB `vm-containers` vzdump directory with a deduplicating datastore, which
  should shrink while holding *more* history.

This is what makes Proxmox VE the recommended NAS OS: it is the option where PBS is a package
install rather than an architecture problem.

## 7. To verify before buying

1. **Recertified enterprise 8 TB street price** — decides whether option (b) is real. SPD/goharddrive
   listings are JS-rendered and could not be scraped; check manually.
2. **Third-party OS support on the chosen chassis** — BIOS access, HDMI console, boot device
   (internal M.2 vs USB) for the F2-425 specifically; the DXP2800 is known to have HDMI out.
3. **M.2 slot count** on the F2-425 (the DXP2800 has 2) — an NVMe boot/apps device keeps the
   HDDs able to spin down, which matters if the box ends up somewhere quiet.
4. **Noise figures** if recertified 7200 rpm enterprise drives are chosen.
5. **Weight/customs** for the return trip: a 2-bay chassis plus two 3.5" drives is ~2.5 kg.

## Sources

- [Hard Drive Prices Surge 50% as AI Data Centers Buy Out 2026 Supply](https://winbuzzer.com/2026/02/18/wd-seagate-2026-hard-drive-shortage-ai-data-centers-xcxwbn/)
- [Hard drives on backorder for two years as AI data centers trigger HDD shortage — Tom's Hardware](https://www.tomshardware.com/pc-components/hdds/ai-triggers-hard-drive-shortage-amidst-dram-squeeze-enterprise-hard-drives-on-backorder-by-2-years-as-hyperscalers-switch-to-qlc-ssds)
- [Hard Drive Price Forecast 2026 — Buy or Wait](https://datacenterdisk.com/price-forecast)
- [Best NAS Hard Drives 2026: CMR Picks & $/TB — TechFuel HQ](https://techfuelhq.com/homelab/best-nas-hard-drives-2026/)
- [TerraMaster NAS 2026 — F4-424, F4-425 Prices](https://datacenterdisk.com/nas-devices/terramaster)
- [UGREEN NASync DXP2800 product page](https://ai.ugreen.com/products/ugreen-nasync-dxp2800-nas-storage)
- [TrueNAS vs UnRAID — Which Should You Choose? (NAS Compares)](https://nascompares.com/2026/08/05/truenas-vs-unraid-which-should-you-choose/)
- [Seagate IronWolf ST6000VN006 listing](https://www.broadbandbuyer.com/products/47366-seagate-st6000vn006/)

---

# Addendum (2026-08-19): gr-srv03 as the NAS host, and re-cost

## 8. Can gr-srv03 do the job with only new drives? — **No**

Evaluated at the user's request, since docker03 is being decommissioned. Measured on the host:

| Check | Result |
|---|---|
| Model | GMKtec NucBox G5, Intel N97 (4 cores) |
| RAM | 12 GB LPDDR5, reported as `Form Factor: Row Of Chips` (4×3 GB) — **soldered, no SODIMM slot, no upgrade path** |
| RAM in use | 9.1 GB of 11.7 GB, **6.5 GB in swap** |
| Guest allocation | 16.1 GB allocated to running guests vs 11.7 GB physical |
| Storage expansion | **One M.2 2242 SATA slot, occupied** by the 256 GB boot SSD, plus microSD. No 2.5" bay, no M.2 2280, single SATA port in use |
| USB | 3 physical ports, all occupied; documented hot-plug instability |

Three blockers:

1. **RAM is soldered and already oversubscribed.** Retiring docker03 returns 6 GB of *allocation*
   (~3.1 GB resident), which fixes today's overcommit — worth doing on its own merits. But the NAS
   role needs ZFS ARC + Immich (6 GB with ML, 4 GB without) + PBS + Samba ≈ 6–10 GB, against the
   ~3–4 GB freed. It does not fit and **can never be made to fit**.
2. **Nowhere to put the drives.** With the only internal slot occupied, "some new drives" can only
   mean USB — on the bus with the documented Zigbee-drop history (BACKUP_A/B hot-plug transients on
   the shared xHCI 5V rail, 7/7 episodes, see [[docs/memory_gr-srv03_powered-hub-instability.md]]).
   That is the worst available home for the primary copy of irreplaceable family photos.
3. **PBS would back the host up to itself** — losing the failure separation that motivated it.

**Decision**: the NAS is separate hardware. **docker03 is replaced by an LXC on gr-srv03**, not by
the NAS.

### Consequences of the docker03 → LXC decision

docker03 currently runs: `zigbee2mqtt`, `cloudflaretunnel` (duplicated by LXC 103), `mosquitto`
(superseded by LXC 105, cutover pending), `portainer`, `uptime-kuma`, `beszel-agent`,
`mqtt-explorer`. All small.

- A replacement LXC sized ~1.5–2 GB covers the lot → **net ~4.5 GB of allocation returned** to
  gr-srv03, which should stop the swapping.
- The 64 GB VM disk leaves the LVM-thin pool, which also shrinks the future PBS datastore (the
  171 GB `vm-containers` directory is dominated by it).
- **The Zigbee dongle stays on gr-srv03**, so zigbee2mqtt stays local — no dongle relocation, and
  USB passthrough into an LXC (by-id device entry) is more robust than the VM passthrough that
  caused the 2026-07-15 outage ([[docs/memory_docker03_zigbee2mqtt.md]]).
- The NAS spec is therefore **unchanged** by the decommission: it still needs only Immich + PBS +
  Samba + ZFS.

## 9. Re-cost (August 2026 prices)

**All three component markets are in shortage simultaneously**: HDD +46% since Sep 2025,
DRAM +89–110% in 2026 (16 GB DDR5 SODIMM ≈ **$209**), NAND ~+100% (1 TB NVMe ≈ **$90**, was ~$45).
None are expected to recover before 2027.

**Implication: do not plan on a RAM upgrade.** A 16 GB stick costs most of a chassis. The NAS must
run within its stock 8 GB, or the RAM must come pre-installed (see the F4-425 Plus below).

### Chassis

| Model | Bays | RAM | M.2 | Price |
|---|---|---|---|---|
| TerraMaster F2-425 | 2 | 8 GB DDR5 SODIMM | verify | **$255** |
| UGREEN NASync DXP2800 | 2 | 8 GB DDR5 | 2× | **$297** |
| TerraMaster F4-425 | 4 | 8 GB DDR5 | verify | **$365** |
| TerraMaster F4-425 Plus | 4 | **16 GB DDR5** | 3× | **$493** (15% off) |

TerraMaster explicitly permits installing a third-party OS **without voiding the warranty**, and
the boxes have HDMI 2.0 out for the installer — so Proxmox VE is a supported path. A boot NVMe is
effectively required (installing the host onto the HDDs would block spin-down and complicate the
ZFS mirror).

Note: at $493 with 16 GB pre-installed, the F4-425 Plus is **cheaper than F4-425 + a $209 stick**
($574). If 16 GB is wanted, buy it built in.

### Builds

| Build | Components | Total |
|---|---|---|
| **A — cheapest workable** | F2-425 $255 + 500 GB NVMe $60 + 2×6 TB new $460–520 | **$775–835** |
| **B — budget-forced** | F2-425 $255 + NVMe $60 + 2×8 TB recertified enterprise ~$300 | **~$615** |
| **C — growth path** | F4-425 $365 + NVMe $60 + 2×6 TB new $460–520 | **$885–945** |
| **D — RAM-comfortable** | F4-425 Plus $493 + NVMe $60 + 2×6 TB new $460–520 | **$1013–1073** |

**The <USD 600 target is now reachable only via build B**, and only if recertified enterprise 8 TB
drives really land near $150 (unverified — §7). Everything else starts at $775.

### Living within 8 GB on the NAS

Feasible, but fully committed, and it needs deliberate tuning:

- **Cap the ZFS ARC at ~2 GB** (`zfs_arc_max`). A 6 TB pool of mostly-cold media does not need more;
  the "1 GB per TB" guideline applies to dedup-heavy use, which this is not.
- **Immich ~4 GB** with ML enabled but job concurrency set to 1. If it thrashes, either drop ML
  (`IMMICH_MACHINE_LEARNING_ENABLED=false`, ~4 GB total, loses face/smart search) or add RAM later
  when DRAM prices recover.
- **PBS ~1–1.5 GB**, **Samba LXC ~0.5 GB**.

If losing face recognition and smart search would be a disappointment, that is the argument for
build D — the 16 GB is what makes Immich comfortable, not the fourth bay.

## Additional sources

- [RAM price tracking 2026 — Tom's Hardware](https://www.tomshardware.com/pc-components/ram/ram-price-index-2026-lowest-price-on-ddr5-and-ddr4-memory-of-all-capacities)
- [SSD prices double as NAND shortage bites](https://tech-insider.org/ssd-prices-nand-shortage-2026/)
- [Immich requirements](https://docs.immich.app/install/requirements/)
- [TerraMaster F2-425 Plus review — itpro](https://www.itpro.com/infrastructure/servers-and-storage/terramaster-f2-425-plus-review-a-versatile-desktop-nas-at-a-great-price)
- [Installing TrueNAS on TerraMaster F4-425](https://blog.bitscry.com/2025/11/08/installing-truenas-on-terramaster-f4-425/)
