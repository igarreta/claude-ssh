# Alder Lake-N CPU comparison — i3-N305 vs N150 vs N95

**Status:** active
**Host:** (project) — NAS chassis selection
**Supersedes:** —
**Superseded-by:** —

Reference table for the small-CPU choices that keep coming up in the NAS chassis decision.
All three are the **same Gracemont E-core architecture** — no P-cores, no hyper-threading,
no AVX-512. Only core count, clocks and GPU EU count separate them. Chassis decision itself
lives in `2026-09-10_nas-chassis-price-correction-f4-424-pro.md`; this doc is the silicon
side only.

## 1. Specifications

| | Core i3-N305 | N150 | N95 |
|---|---|---|---|
| Generation | Alder Lake-N (2023) | Twin Lake (2025) | Alder Lake-N (2023) |
| Cores / threads | 8 / 8 | 4 / 4 | 4 / 4 |
| Base / turbo | 1.8 / 3.8 GHz | ~1.0 / 3.6 GHz | 1.7 / 3.4 GHz |
| L3 cache | 6 MB | 6 MB | 6 MB |
| Base power (TDP) | 15 W (9–15 W cTDP) | **6 W** | 15 W |
| iGPU | UHD, 32 EU @ 1.25 GHz | 24 EU @ 1.0 GHz | 16 EU @ 1.2 GHz |
| Memory | DDR4-3200 / DDR5-4800 | + LPDDR5-4800 | DDR4-3200 / DDR5-4800 |
| Memory channels | single | single | single |
| PCIe | 9× Gen3 | 9× Gen3 | 9× Gen3 |
| ECC | no | no | no |
| Multi-thread (CB R23, approx.) | ~5,500–6,000 | ~3,400–3,700 | ~3,000–3,300 |
| Single-thread (approx.) | ~1,000–1,050 | ~1,000–1,050 | ~930–970 |

For reference, gr-srv03's **N97** sits between the N150 and the N95: 4 cores, 3.6 GHz turbo,
24 EU, 12 W. An N305 is roughly 1.7× its multi-thread at the same single-thread feel.

## 2. What actually differs

- **Single-thread is the same chip.** All three are Gracemont at similar clocks; the N305 and
  N150 are within noise of each other, the N95 ~7% behind. Nothing here is "faster per core"
  in any way you would notice.
- **The N305's whole advantage is parallel throughput** — double the cores, ~1.7× the N150
  and ~1.8× the N95 multi-thread.
- **The N150 beats the N95 outright**: same core count, higher turbo, more GPU EUs, at 6 W
  base power instead of 15 W. There is no workload where the N95 is the better chip — it
  survives only as cheaper/older stock.
- **The N305's 15 W is a sustained-load caveat**, not a peak figure. It only feeds 8 cores in
  that envelope by dropping all-core clocks; in a passively-cooled NAS it will throttle where
  a 6 W N150 will not. Real draw depends on the board's PL1/PL2.
- **Media engine is identical on all three**: QuickSync H.264/HEVC/VP9 encode+decode, AV1
  **decode only**. For one or two transcodes the fixed-function block is the bottleneck, so
  EU count barely matters; EUs only show up under many simultaneous streams or shader work.
- **AES-NI on all three**, so restic/ZFS encryption is not a differentiator.
- **Single-channel memory on all three** — under 8 busy cores that is the N305's real limit,
  more than clocks are.

## 3. Applied to the NAS

The genuine choice was **N150 vs N305** (the N95 was never in contention on merit — it only
appeared because a scraped N95/8 GB price was misattributed to the N150 SKU; see the 09-10
price-correction doc).

- N150 profile: mostly-idle file serving plus a transcode. More efficient, cooler, quieter.
- N305 profile: several LXCs/VMs, parallel compression, ZFS scrubs under load.

The decision went to the F4-424 Pro (N305) for **+$38**, and the deciding factor was RAM
(32 GB vs 16 GB), not cores — for a container host the memory ceiling binds before the core
count does. The extra 4 cores are headroom, not the justification.
