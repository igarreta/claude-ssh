# gr-srv03 USB hub comparison — storage hub + dongle hub (2026-08-19)

> **Updated 2026-08-20** — the outage-default criterion has been retired; see
> [The outage question, retired](#the-outage-question-retired-2026-08-20).
> The decision is unchanged, but it now rests on different grounds.

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
| Survives power outage | **Yes — physical state** | **Yes — physical state** | Vendor states ports resume ON (2026-08-20) |
| PPPS / uhubctl | **Verified**, all ports, ~2.5 s | Unverified, chipset unknown | Verified (all but 2nd USB-C) |
| Chipset | Realtek `0bda:0411` | Unknown | Realtek `0bda:0423` |

> The *Survives power outage* row is kept for the record only — it was the row
> that originally decided this table, and as of 2026-08-20 it decides nothing.

## Decision: Rosonway RSH-A10

The cheapest candidate with **per-port power switching independently verified on
every port**, a real 12 V brick, and a USB-A upstream. Leave every switch
physically ON and drive the ports with `uhubctl`.

Since 2026-08-20 that verified-PPPS line is the whole argument. The mechanical
switches are a mild bonus, no longer the deciding factor.

- 36 W is the smallest budget here but ample: two 2.5" drives peak around 20 W
  including simultaneous spin-up.
- USB 3.0 costs nothing — the drives top out near 100 MB/s against ~400 MB/s
  usable on a 5 Gbps link. See
  [memory_gr-srv03_usb-hub-eval.md](memory_gr-srv03_usb-hub-eval.md).
- Internal topology is three cascaded 4-port Realtek hubs sharing one 5 Gbps
  uplink. Irrelevant for two mechanical drives, and precisely why the Kingston
  XS1000 (~1 GB/s) stays on a direct host port.

## The outage question, retired (2026-08-20)

This section originally decided the comparison. It no longer does.

**The original worry.** gr-srv03 has already lost power once (2026-07-12). A hub
whose ports come back OFF after an outage would silently leave the backup drives
unpowered until someone is physically at the machine — presenting as "backups
stopped" days later, and indistinguishable from the normal offsite-rotation
"drive missing" state.

**Why it does not survive scrutiny.** A *persistent* off-state barely exists in
this design:

| Use of `uhubctl` power-off | Persistent? |
|---|---|
| Reset a wedged Zigbee dongle (2026-07-15 recovery watchdog) | No — momentary off→on |
| Cut VBUS after the 15:00 unmount, before pulling the drive for the offsite swap | Yes, but only 15:00 → swap window |
| Leave BACKUP_A/B unpowered between nightly backups | **Never the plan, and would be wrong** |

That third row deserves the explicit "no": APM already spins the Toshibas down
after ~10 min idle (see
[memory_backup_schedule.md](memory_backup_schedule.md)), and cutting power
outright would add a spin-up cycle per night — spin-up count being the dominant
wear metric on a 2.5" HDD. It would trade drive life for nothing.

So the entire exposure is an outage landing inside the afternoon swap window.

**And that dissolves with one line.** Assert power on before mounting, rather
than trusting any hub's power-on default:

```sh
uhubctl -l <hub-location> -a on
```

placed at the top of the 00:30 remount path and at boot. An outage reboots
gr-srv03 anyway, so boot is exactly where the assertion runs — the failure mode
and its remedy arrive together. With that in place **no hub's power-on default
matters**, MCU or mechanical.

**Retained as background.** RSHTECH support confirmed on 2026-08-20 that a port
which was ON before power loss stays ON after power is restored. This is a
support statement, not a power-cycle test, and it does not cover the case of a
port that `uhubctl` (not the button) had switched off — on the sibling ST07C the
octoprobe assessment records that *"if powered off manually, remote control does
not work anymore; if powered off automatically, manual control does not work
anymore,"* which is MCU-held state with no documented non-volatile storage. The
boot-time assertion above makes the question moot, so it was not pursued further.

**What actually discriminates now:** verified PPPS, adequate 5 V budget, no
backfeed into the host port, USB-A upstream, price.

## Rejected

| Hub | $ | Reason |
|---|---|---|
| Leinsis KZW-U10217B | 34 | Better brick, but no evidence it supports PPPS at all |
| RSHTECH RSH-ST10C-6 | 40 | Best brick + verified PPPS, but $3 more than the A10 for 60 W and 10 Gbps ports that this host cannot use |
| RSHTECH RSH-ST10P | ? | **Not in the uhubctl list at all** — PPPS unverified, which is now the criterion that matters. USB-C upstream (host is USB-A only); 66 W at 24 V shared with 2x USB-C PD 45 W charging + 100 W PD passthrough, a laptop-docking feature set whose 5 V budget for the data ports is unpublished. Suggested by RSHTECH support 2026-08-20; a different model from the ST10C-6 |
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
- [RSHTECH RSH-ST10P product page](https://www.rshtech.com/products/10-port-powered-usb-c-hub-66w-with-3x10gbps-usb-32-data-ports-2c-1a-4-usb-30-ports-2-usb-c-pd-45w-charging-ports-and-pd-100w-rsh-st10p)
- [TSUPY TP01-00055 (B0C5593DBH)](https://www.amazon.com/TSUPY-Extension-Ultra-Slim-Aluminium-Chromebook/dp/B0C5593DBH)
- [VENTION B0D2XWJ99H](https://www.amazon.com/VENTION-Splitter-Expander-Chromebook-Surface/dp/B0D2XWJ99H)
  / [Vention CHOBB product page](https://ventiontech.com/products/usb-to-usb-3-2-gen-2-type-a-x-4-usb-c-10g-hub-0-15m-black)
- [UGREEN CM806 / 35583](https://ugreen.lk/product/ugreen-4-port-10gbps-hub-cm806/)
