---
name: project_raspberrypi2z_pool-thermometer
description: "Pool thermometer buoy for raspberrypi2z rtl_433 — bought WT0124 (protocol 109), pending arrival/test"
metadata: 
  node_type: memory
  type: project
  originSessionId: 10dfc3b6-43b9-404f-8391-448767ba89d5
  modified: 2026-08-15T20:34:22.301Z
---

Bought a Metoluar WT0124 pool thermometer (eBay listing 405519975409) to test with
raspberrypi2z's rtl_433 setup — matches existing decoder protocol 109. Chosen over
GoveeLife P1 and Baldr HCS706+707, neither of which has a confirmed rtl_433 decoder
(would require reverse-engineering). Full research and reasoning in
docs/memory_raspberrypi2z_pool-thermometer.md.

**Next step:** once it arrives, capture signal on raspberrypi2z and confirm it decodes
as protocol 109.
