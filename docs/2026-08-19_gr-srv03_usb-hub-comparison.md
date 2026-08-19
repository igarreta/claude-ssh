# gr-srv03 USB hub comparison — storage hub + dongle hub (2026-08-19)

**Status:** Storage hub DECIDED, not yet purchased. Dongle hub still open.
Selects the hubs for
[2026-08-19_gr-srv03_usb-hub-layout-plan.md](2026-08-19_gr-srv03_usb-hub-layout-plan.md).

Six candidates were priced; three survived the plan's purchase criteria. The other
three are recorded at the bottom so they are not re-evaluated later.

## Finalists

| | **Rosonway RSH-A10** | **Leinsis KZW-U10217B** | **RSHTECH RSH-ST10C-6** |
|---|---|---|---|
| Price | $37 | $34 | $40 |
| PSU | 12 V/3 A (36 W) | 12 V/4 A (48 W) | 12 V/5 A (60 W) |
| Ports | 10 x USB 3.0 | 10 (3x10G + 7x5G) | 10 (3x10G + 7x5G) |
| Switches | **Mechanical, latching** | **Mechanical** | Touch (MCU latch) |
| Survives power outage | **Yes — physical state** | **Yes — physical state** | **Unknown** |
| PPPS / uhubctl | **Verified**, all ports, ~2.5 s | Unverified, chipset unknown | Verified (all but 2nd USB-C) |
| Chipset | Realtek `0bda:0411` | Unknown | Realtek `0bda:0423` |

## Decision: Rosonway RSH-A10

The only one of the three satisfying both hard requirements with evidence —
mechanical switches that cannot forget their state across an outage, and per-port
power switching independently confirmed on every port. Leave every switch
physically ON and drive the ports with `uhubctl`.

- 36 W is the smallest budget here but ample: two 2.5" drives peak around 20 W
  including simultaneous spin-up.
- USB 3.0 costs nothing — the drives top out near 100 MB/s against ~400 MB/s
  usable on a 5 Gbps link. See
  [memory_gr-srv03_usb-hub-eval.md](memory_gr-srv03_usb-hub-eval.md).
- Internal topology is three cascaded 4-port Realtek hubs sharing one 5 Gbps
  uplink. Irrelevant for two mechanical drives, and precisely why the Kingston
  XS1000 (~1 GB/s) stays on a direct host port.

## Why the outage question decided it

gr-srv03 has already lost power once (2026-07-12). A hub whose ports come back
OFF after an outage would silently leave the backup drives unpowered until
someone is physically at the machine — a failure mode that would present as
"backups stopped" days later.

RSHTECH does not document the power-on default of its touch buttons anywhere in
the product page or manual, and no first-hand power-cycle test could be found.
The touch latch is known to be **separate from** the hub's USB per-port power
switching: the octoprobe assessment of the sibling ST07C records that *"if
powered off manually, remote control does not work anymore; if powered off
automatically, manual control does not work anymore."* That is MCU-held state
with no non-volatile storage documented. It most likely resets to ON, but
"most likely" is the wrong confidence level for this requirement.

A mechanical switch is physical state and cannot forget. It also does **not**
cost per-port software control: on the RSH-A10 the octoprobe assessment found
power switching *"works fine on every port"*, with the caveat that it *"only
works when the button is in the pressed state."* Switch ON permanently, control
in software.

## Rejected

| Hub | $ | Reason |
|---|---|---|
| Leinsis KZW-U10217B | 34 | Better brick, but no evidence it supports PPPS at all |
| RSHTECH RSH-ST10C-6 | 40 | Best brick + verified PPPS, but undocumented power-on default on touch latches |
| Rosonway RSH-A10QPD | 41 | Not in uhubctl list; 60 W shared with 20 W PD + 2x2.4 A charging ports |
| intpw YH6AC | 40 | 65 W @ 20 V PD brick, 5 V budget unstated, shared with 2x45 W charging; not in uhubctl list |
| UGREEN CM859 / 75949 | 33 | 12 V/2 A (24 W) is too thin for two HDDs; no UGREEN entry in uhubctl list at all |
| RSHTECH RSH-ST07C | 29 | **5 V/3 A (15 W)** cannot carry two spinning HDDs; uhubctl works on only 4 of 7 ports, ~4 s per op |

## Known annoyances on the A10

- LEDs are hard to see; ports are not numbered → label them during install and
  record the `uhubctl` port numbers here.
- `uhubctl` control only works while the mechanical switch is in the ON position.
- Switching is slow (~2.5 s per operation) — fine for a mount/unmount hook.

## Verify on arrival

1. `uhubctl` lists the hub and tags it `ppps`.
2. Turning a port off actually kills VBUS — confirm the drive **spins down**, not
   just that the command returned cleanly. A hub can advertise PPPS without the
   load switches fitted.
3. Re-run the three benchmarks from
   [memory_gr-srv03_usb-hub-eval.md](memory_gr-srv03_usb-hub-eval.md) against the
   direct-connection baseline (69.2 MB/s `hdparm`, 100 MB/s write, 79.3 MB/s
   read). The old Terminus hub cost **-40% on writes** with reads unaffected —
   that is the regression signature to watch for.
4. No backfeed into the host port with the hub's brick unplugged.

## Dongle hub (port 3) — three unpowered candidates

None of the six powered hubs above is a good fit for port 3: all are USB 3.x,
and a SuperSpeed hub next to the RTL-433 is exactly the broadband RFI source the
layout plan wants kept away from 433 MHz. Three cheap bus-powered hubs were
priced instead.

| | **TSUPY TP01-00055** | **VENTION B0D2XWJ99H** | **UGREEN 35583 / CM806** |
|---|---|---|---|
| Price | $12 | $13 | $16 |
| Upstream plug | **USB-A** | **USB-A** | **USB-C** — needs adapter |
| Downstream | 4 x USB-A 10G | 4 x USB-A 10G | 2 x USB-A + 2 x USB-C 10G |
| Aux 5 V input | **Yes (USB-C)** | **Yes (USB-C)** | **No** |
| Cable | **1.2 m** | ~0.15 m | short pigtail |
| Chipset | undisclosed | undisclosed | undisclosed |
| PPPS / uhubctl | no | no | no |

### Recommendation: TSUPY TP01-00055, with reservations

It is the only one that is simultaneously USB-A upstream, four full-size A ports,
has an aux 5 V input, and puts the dongles **1.2 m away from the chassis** — which
is the single most useful property on this side, because the layout plan's whole
reason for a separate dongle hub is distance from the drives and from the USB3
storage cabling. The VENTION is the same hub with a 15 cm cable, which parks both
dongles against the back panel and defeats that.

**UGREEN 35583 is disqualified on connectors, not quality.** Its upstream plug is
USB-C and gr-srv03 has only USB-A sockets, so it needs an adapter hanging off the
back; and only two of its four ports are USB-A, which is exactly the number of
dongles with zero spare. It also has no aux power input.

### What these three do not solve

- **Still 10 Gbps.** Neither device needs it: the Sonoff CP210x is full-speed
  (12 Mbps) and the RTL2832U is high-speed (480 Mbps). The 10 Gbps is paid for
  and never used. Mitigating fact: with no SuperSpeed device attached, the hub's
  SS lanes never negotiate a link and sit in Rx.Detect polling, so emissions are
  far below an active USB3 link — but a plain USB 2.0 hub is strictly quieter and
  costs half as much. USB3 RFI is documented to hurt 2.4 GHz as well as HF/VHF,
  so this is a Zigbee concern too, not only an SDR one.
- **No per-port power switching.** None of the three appears in the uhubctl
  compatible-hub list. This is worth more on the dongle side than it looks: the
  2026-07-15 zigbee2mqtt outage was a USB re-enumeration, and a PPPS hub would let
  the existing recovery watchdog power-cycle the dongle instead of escalating.
  See [memory_docker03_zigbee2mqtt.md](memory_docker03_zigbee2mqtt.md).
- **Port pitch.** These are slim inline hubs. The Sonoff dongle is wide and will
  likely mask the neighbouring port; plan on short extension cables for both
  dongles regardless (the plan already requires a shielded one for the SDR).

### Power budget (not a constraint)

Bus-powered is fine here. Zigbee ~100 mA + RTL-SDR ~300 mA + hub logic ~100 mA
is ~500 mA against the 900 mA a USB3 host port grants. The aux USB-C input is
still worth using: it takes the SDR's draw off the host 5 V rail, which is the
same rail whose sag caused the 2026-07/08 episodes.

> **Verify if the aux input is used:** cheap hubs often wire the aux 5 V straight
> to bus VBUS with no OR-ing diode, which backfeeds the host port. Check for
> voltage on the host-side VBUS with the upstream plug out and the charger in.

### Preferred alternative

A **USB 2.0 powered hub with uhubctl PPPS** beats all three on every axis that
matters for port 3 — quieter, cheaper, remotely power-cyclable — at the cost of
having to pick from the uhubctl list rather than from what is on the shelf.
Buy one of these three only if that search is not worth the time.

## Sources

- [uhubctl compatible hubs](https://github.com/mvp/uhubctl/blob/master/README.md)
- [octoprobe assessment — RSH-A10](https://github.com/octoprobe/usbhubctl/blob/main/usb_hubs/README_RSHTECH_RSH-A10.md)
- [octoprobe assessment — RSH-ST07C](https://github.com/octoprobe/usbhubctl/blob/main/usb_hubs/README_RSHTECH_RSH-ST07C.md)
- [uhubctl issue #616 — RSH-ST10C-6](https://github.com/mvp/uhubctl/issues/616)
- [TSUPY TP01-00055 (B0C5593DBH)](https://www.amazon.com/TSUPY-Extension-Ultra-Slim-Aluminium-Chromebook/dp/B0C5593DBH)
- [VENTION B0D2XWJ99H](https://www.amazon.com/VENTION-Splitter-Expander-Chromebook-Surface/dp/B0D2XWJ99H)
  / [Vention CHOBB product page](https://ventiontech.com/products/usb-to-usb-3-2-gen-2-type-a-x-4-usb-c-10g-hub-0-15m-black)
- [UGREEN CM806 / 35583](https://ugreen.lk/product/ugreen-4-port-10gbps-hub-cm806/)
