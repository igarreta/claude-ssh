# Long-term plan: TTato split (gr-srv03 + ESP32) and raspberrypi1 as a radio head

**Status:** open
**Host:** raspberrypi1, gr-srv03, raspberrypi2z
**Supersedes:** —
**Superseded-by:** —

**Status detail:** this is a **long-term reconfiguration plan, not scheduled for execution.**
Nothing here is built. It records the architecture decided in the design conversation of
2026-09-12 and the measurements taken that day, so the reasoning does not have to be
re-derived when the work is actually picked up. Open questions are in §7.

---

## 1. The starting question

"Could zigbee2mqtt run on raspberrypi2z? And on raspberrypi1?" — which turned into a
placement question once the real goal surfaced: splitting TTato and deciding where the two
radios (Zigbee coordinator, RTL-SDR 433 MHz) should live.

## 2. raspberrypi2z — ruled out

Measured 2026-09-12:

| | |
|---|---|
| SoC | BCM2835, ARMv6 single core @ 1.0 GHz (BogoMIPS 1423) |
| RAM | 426 MB total, 129 MB used, **297 MB available**, already 17 MB into swap |
| Arch | `armv6l` |
| Node.js | not installed |
| Network | Wi-Fi only |

Four blockers, in severity order:

1. **RAM.** z2m 2.x idles at 250–400 MB RSS on a real network. It would live permanently in
   swap on the SD card.
2. **ARMv6.** Official Node.js dropped ARMv6 at v11 (2019). Unofficial builds *are* current —
   checked `unofficial-builds.nodejs.org`, `linux-armv6l` exists up to **v22.23.2** — so this is
   survivable, but untested by anyone. Worse: `@serialport/bindings-cpp` ships no armv6
   prebuilds, so npm falls back to node-gyp compiling on-device, competing for the same RAM.
3. **USB.** Single micro-USB OTG port; the Pi already carries the rtl_433 SDR. One port,
   two radios, no powered hub on that host.
4. **Single core**, already running rtl_433 continuously.

It also has the documented Wi-Fi hang history
([2026-06-26_raspberrypi2z_wifi-watchdog.md](2026-06-26_raspberrypi2z_wifi-watchdog.md)).

**Verdict: no.** raspberrypi2z stays what it is — a thin rtl_433 → MQTT edge node.

## 3. raspberrypi1 — capable, and freed by the TTato split

Measured 2026-09-12:

| | |
|---|---|
| Model | Raspberry Pi 3 Model B+ Rev 1.3 |
| CPU | 4× Cortex-A53 @ 1.4 GHz, **aarch64** |
| RAM | 956 MB total, 396 used, **559 available**, 135 MB in swap |
| Storage | 28 GB SD, 60 % used |
| Network | **wired** eth0 192.168.1.49 (wlan0 dormant) |
| Temp | 53 °C |
| `vcgencmd get_throttled` | **`0xd0000`** |
| USB | 4 free ports, no serial adapter attached |
| Containers | TTato, uptime-kuma, portainer, beszel-agent |

aarch64 means official Node 22 and official z2m arm64 images — no unofficial builds, no
source compiles. The Pi 3B+ was the reference z2m platform for years. It *can* run z2m.

Two cautions that survive the TTato split:

- **`0xd0000` = under-voltage, throttling, and soft-temp-limit have all occurred** during the
  74 days of uptime. No bits active currently, but hanging a USB coordinator off a PSU that
  has already browned out invites intermittent dropouts. Precedent:
  [2026-08-24_docker03_zigbee-coordinator-rf-degradation.md](2026-08-24_docker03_zigbee-coordinator-rf-degradation.md) —
  the Zigbee drops there were hot-plug transients on a shared 5 V rail.
- **SD card.** 559 MB available is workable for z2m, not comfortable, and z2m's database
  writes land on an SD card.

## 4. The decision: separate radio placement from compute placement

The trade-off as originally framed — "gr-srv03 has fewer problems but is bulky to locate" —
is a false choice. z2m reads its adapter over a serial port, and that port can be a TCP
socket (`port: tcp://192.168.1.49:20108` in `configuration.yaml`). The bulky, reliable host
stays in the rack; the antenna goes wherever the RF is good.

**Target architecture:**

| Layer | Host | Runs | State |
|---|---|---|---|
| Radio head | raspberrypi1 | `ser2net` (Zigbee coordinator over TCP), optionally `rtl_433` → MQTT | none worth losing |
| Radio head | raspberrypi2z | `rtl_433` → MQTT (as today) | none |
| Compute | gr-srv03 / cygnus | zigbee2mqtt (DB, network key, groups, bindings), TTato brain | all of it |
| Actuator | ESP32 at the boiler | relays + local I/O + failsafe | none |

Rationale: z2m's `database.db` and coordinator backup are the one piece of the Zigbee setup
that is genuinely painful to lose — re-pairing every device by hand. That belongs on
gr-srv03, not on an SD card in a cupboard on a host with a logged under-voltage history.
The *radio* costs nothing if its host dies: reflash, copy two config files.

This gets gr-srv03's reliability **and** the Pi's placement freedom, rather than splitting
the difference between them.

## 5. Coordinator migration — the re-pairing trap

- Keeping the **existing dongle** and merely relocating it preserves the network: same chip,
  same IEEE address, **no re-pairing**.
- Swapping to a network-native coordinator (SLZB-06 and similar) requires the radio family to
  match, or the entire mesh must be re-paired. A restore does not fix a chip change.
- The nightly Zigbee network-state backup covers the host-move case →
  [memory-nodes/project_zigbee2mqtt_backup.md](memory-nodes/project_zigbee2mqtt_backup.md).

**Measurement warning:** moving the coordinator changes the variable currently under
investigation. LQI is unrecovered since the 09-05 relapse and swings ~60 points across the
day. Take before/after readings from the CT206 collector, never a spot check →
[memory-nodes/project_zigbee_lqi_collector.md](memory-nodes/project_zigbee_lqi_collector.md).

## 6. The TTato split

Control logic (schedule, modes, MQTT, HA integration) moves to gr-srv03/cygnus; the physical
I/O moves to an ESP32 at the boiler.

**What the ESP32 must actually carry** — inspected 2026-09-12 in
`/home/rsi/TTato/bin/TTato.py` (lines 109–120), `GPIO.setmode(GPIO.BOARD)`, so these are
board pin numbers:

| Direction | Pin (BOARD) | BCM | Function |
|---|---|---|---|
| Out | 37 | GPIO26 | **boiler relay** |
| Out | 35 | GPIO19 | **pump relay** |
| Out | 16 / 18 / 22 | GPIO23/24/25 | red / yellow / green status LEDs |
| Out | 36 | GPIO16 | PI_TURNS_OFF |
| Out | 31 | GPIO06 | **433 MHz radio TX** |
| In | 11 | GPIO17 | external thermostat |
| In | 13 | GPIO27 | external override selector |
| In | 33 | GPIO13 | **433 MHz radio RX** |
| In | 40 | GPIO21 | shutdown order |
| In | 38 | GPIO20 | PI_ALIVE (used by Linux) |

Two findings that shape the split:

- **The `/sys/bus/w1` bind mount is vestigial.** `/sys/bus/w1/devices/` is empty — there are
  no 1-Wire sensors. All temperatures already arrive over MQTT (rtl_433, Zigbee,
  `granev/temp/*`). The split is cleaner than the container's mounts suggest.
- **There is a 433 MHz TX/RX pair on GPIO** (pins 31/33) that also needs a home — ESP32, or
  folded into the rtl_433 side. Easy to overlook until the boiler half is already built.
  Related unfinished work: [memory-nodes/project_docker03_rtl-test.md](memory-nodes/project_docker03_rtl-test.md).

### The failsafe is load-bearing

Today the Pi keeps the house warm on its own. After the split, heat depends on
**gr-srv03 + the mosquitto LXC + the network**. Design this first, not last:

- ESP32 reverts to a safe local setpoint (or hands over to the external thermostat input) if
  no valid command arrives within N minutes.
- Keep the **override selector electrically upstream of the ESP32**, so it still works when
  the ESP32 itself is dead.

Precedent for why this matters: TTato has already fired the boiler on phantom 0 °C readings →
[2026-08-01_raspberrypi1_ttato-manual-mode-phantom-zero-heating.md](2026-08-01_raspberrypi1_ttato-manual-mode-phantom-zero-heating.md),
and lost its MQTT command subscription on reconnect →
[2026-08-15_raspberrypi1_ttato-mqtt-resubscribe-fix.md](2026-08-15_raspberrypi1_ttato-mqtt-resubscribe-fix.md).

## 7. Open questions

1. **Where does the TTato brain land** — gr-srv03 directly, cygnus, or a new LXC? Check
   against the placement rules first
   ([2026-09-11_nas-gr-srv03_service-placement-rules.md](2026-09-11_nas-gr-srv03_service-placement-rules.md));
   gr-srv03 has no RAM headroom until the VM 102 decommission completes.
2. **Where does the 433 MHz TX/RX pair go** — ESP32 or the rtl_433 side?
3. **Which host runs `ser2net`** — raspberrypi1, or does the coordinator end up somewhere
   else entirely once the NAS and the Rosonway hub question resolve?
4. **Does rtl_433 stay split across two Pis**, or consolidate onto raspberrypi1?
5. **Is raspberrypi1's PSU replaced** before anything else hangs off its USB? The `0xd0000`
   history argues yes.
6. **ESP32 firmware** — ESPHome (native HA integration, `safe_mode`) vs. custom. Not decided.
7. Sequencing against the open Zigbee RF investigation — do not move the coordinator while
   the LQI degradation is still being measured.

## 8. What was explicitly rejected

- **z2m on raspberrypi2z** — §2.
- **z2m on raspberrypi1 with its database local** — §3, §4. The host is capable; the *state*
  is what should not live there.
- **Co-locating z2m with TTato as-is** — the objection that started this (Zigbee restarts
  coupled to boiler control) dissolves only *because* TTato is being split out. It is not a
  valid arrangement before that.
