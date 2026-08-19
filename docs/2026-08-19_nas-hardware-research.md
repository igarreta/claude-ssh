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
