---
name: raspberrypi2z_pool-thermometer
description: Pool thermometer buoy research for rtl_433 on raspberrypi2z — chose WT0124 (protocol 109) over GoveeLife P1 / Baldr HCS706+707
metadata:
  type: project
---

# Pool thermometer buoy — rtl_433 protocol research

**Status:** open
**Host:** raspberrypi2z
**Supersedes:** —
**Superseded-by:** —

**Goal:** add a wireless pool thermometer buoy that raspberrypi2z's existing rtl_433
setup (see `docs/2026-06-26_raspberrypi2z_rtl433-setup.md`) can decode, without a
lengthy reverse-engineering effort.

## Findings (2026-08-15)

Currently-desired models have **no confirmed rtl_433 decoder**:
- **GoveeLife WiFi Pool Thermometer P1** — zero GitHub hits for "GoveeLife" or "P1" in
  merbanan/rtl_433. Closest relative is Govee Pool/Spa Thermometer H5310 (protocol 349,
  FSK/PCM, XOR-obfuscated payload + CRC-16/AUG-CCITT), but no evidence P1 shares its
  frame format, and H5310 pairs with a proprietary Govee gateway rather than
  broadcasting standalone.
- **Baldr HCS706ARF+707** — not the same as the supported HCS528ARF (protocol 360,
  discontinued model). Issue #3333 shows someone reverse-engineering a *different*,
  newer Baldr pool thermometer from scratch — decoder partially working but temperature
  formula still unresolved as of last update. Baldr has changed protocol across
  generations, so HCS528ARF's decoder is not expected to work on newer units.

Models with a **mature, stable rtl_433 decoder that are still sold new**:
- **TFA Dostmann Marbella (30.3066.01)** — protocol 182, listed live on
  tfa-dostmann.de.
- **Metoluar/Elisona WT0124** — protocol 109, one of the oldest/most stable decoders in
  rtl_433, still widely sold as a rebranded OEM module (Amazon/eBay/Alibaba).

Weaker/discontinued: Rubicson 48942 (protocol 222, decoder confirmed via PR #2137, no
evidence still sold).

## Decision

Bought a **Metoluar Solar Powered Wireless Pool Thermometer WT0124** via eBay
(listing id 405519975409) to test against rtl_433 protocol 109.

**Next step:** once it arrives, capture its signal on raspberrypi2z's rtl_433 and
confirm it decodes cleanly as protocol 109 (`WT0124 Pool Thermometer`).
