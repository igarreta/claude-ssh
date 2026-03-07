# living1 system description

[code]
System:
  Kernel: 6.17.0-14-generic arch: x86_64 bits: 64 compiler: gcc v: 13.3.0 clocksource: tsc
  Desktop: Xfce v: 4.18.1 tk: Gtk v: 3.24.41 wm: xfwm4 v: 4.18.0 with: xfce4-panel
    tools: light-locker vt: 7 dm: LightDM v: 1.30.0 Distro: Linux Mint 22.3 Zena
    base: Ubuntu 24.04 noble
Machine:
  Type: Laptop System: GIGABYTE product: MMLP3AP-00 v: 1.x serial: <superuser required>
  Mobo: GIGABYTE model: MMLP3AP-00 v: 1.x serial: <superuser required> uuid: <superuser required>
    BIOS: American Megatrends v: F7 date: 12/08/2014
Battery:
  Device-1: hidpp_battery_0 model: Logitech Wireless Touch Keyboard K400 serial: <filter>
    charge: 100% (should be ignored) rechargeable: yes status: discharging
CPU:
  Info: dual core model: Intel Core i3-4010U bits: 64 type: MT MCP smt: enabled arch: Haswell
    rev: 1 cache: L1: 128 KiB L2: 512 KiB L3: 3 MiB
  Speed (MHz): avg: 1696 min/max: 800/1700 cores: 1: 1696 2: 1696 3: 1696 4: 1696 bogomips: 13568
  Flags: avx avx2 ht lm nx pae sse sse2 sse3 sse4_1 sse4_2 ssse3 vmx
Graphics:
  Device-1: Intel Haswell-ULT Integrated Graphics vendor: Gigabyte driver: i915 v: kernel
    arch: Gen-7.5 ports: active: HDMI-A-1 empty: DP-1,HDMI-A-2 bus-ID: 00:02.0 chip-ID: 8086:0a16
    class-ID: 0300
  Display: x11 server: X.Org v: 21.1.11 with: Xwayland v: 23.2.6 compositor: xfwm4 v: 4.18.0
    driver: X: loaded: modesetting unloaded: fbdev,vesa dri: crocus gpu: i915 display-ID: :0.0
    screens: 1
  Screen-1: 0 s-res: 2560x1440 s-dpi: 96 s-size: 677x381mm (26.65x15.00") s-diag: 777mm (30.58")
  Monitor-1: HDMI-A-1 mapped: HDMI-1 model: Dell S2725DS serial: <filter> res: 2560x1440 hz: 60
    dpi: 109 size: 597x336mm (23.5x13.23") diag: 685mm (27") modes: max: 2560x1440 min: 720x400
  API: EGL v: 1.5 hw: drv: intel crocus platforms: device: 0 drv: crocus device: 1 drv: swrast
    gbm: drv: crocus surfaceless: drv: crocus x11: drv: crocus inactive: wayland
  API: OpenGL v: 4.6 compat-v: 4.5 vendor: intel mesa v: 25.2.8-0ubuntu0.24.04.1 glx-v: 1.4
    direct-render: yes renderer: Mesa Intel HD Graphics 4400 (HSW GT2) device-ID: 8086:0a16
  API: Vulkan v: 1.3.275 layers: 3 surfaces: xcb,xlib device: 0 type: integrated-gpu driver: N/A
    device-ID: 8086:0a16 device: 1 type: cpu driver: N/A device-ID: 10005:0000
Audio:
  Device-1: Intel Haswell-ULT HD Audio vendor: Gigabyte driver: snd_hda_intel v: kernel
    bus-ID: 00:03.0 chip-ID: 8086:0a0c class-ID: 0403
  Device-2: Intel 8 Series HD Audio vendor: Gigabyte 8 driver: snd_hda_intel v: kernel
    bus-ID: 00:1b.0 chip-ID: 8086:9c20 class-ID: 0403
  API: ALSA v: k6.17.0-14-generic status: kernel-api
  Server-1: PipeWire v: 1.0.5 status: active with: 1: pipewire-pulse status: active
    2: wireplumber status: active 3: pipewire-alsa type: plugin
Network:
  Device-1: Realtek RTL8723AE PCIe Wireless Network Adapter vendor: AzureWave driver: N/A pcie:
    speed: 2.5 GT/s lanes: 1 port: e000 bus-ID: 02:00.0 chip-ID: 10ec:8723 class-ID: 0280
  Device-2: Realtek RTL8111/8168/8211/8411 PCI Express Gigabit Ethernet vendor: Gigabyte
    driver: r8169 v: kernel pcie: speed: 2.5 GT/s lanes: 1 port: d000 bus-ID: 03:00.0
    chip-ID: 10ec:8168 class-ID: 0200
  IF: enp3s0 state: down mac: <filter>
  Device-3: Realtek RTL8188FTV 802.11b/g/n 1T1R 2.4G WLAN Adapter driver: rtl8xxxu type: USB
    rev: 2.0 speed: 480 Mb/s lanes: 1 bus-ID: 1-1:2 chip-ID: 0bda:f179 class-ID: 0000
    serial: <filter>
  IF: wlx00e0313f8b21 state: up mac: <filter>
  IF-ID-1: tailscale0 state: unknown speed: -1 duplex: full mac: N/A
Bluetooth:
  Device-1: IMC Networks Bluetooth driver: btusb v: 0.8 type: USB rev: 2.0 speed: 12 Mb/s lanes: 1
    bus-ID: 1-7:4 chip-ID: 13d3:3394 class-ID: e001 serial: <filter>
  Report: hciconfig ID: hci0 rfk-id: 0 state: up address: <filter> bt-v: 4.0 lmp-v: 6 sub-v: a5b1
    hci-v: 6 rev: e3d class-ID: 7c010c
Drives:
  Local Storage: total: 223.57 GiB used: 33.04 GiB (14.8%)
  ID-1: /dev/sda vendor: Kingston model: SA400S37240G size: 223.57 GiB speed: 6.0 Gb/s tech: SSD
    serial: <filter> fw-rev: 0107 scheme: GPT
Partition:
  ID-1: / size: 218.51 GiB used: 33.03 GiB (15.1%) fs: ext4 dev: /dev/sda3
  ID-2: /boot/efi size: 512 MiB used: 6.1 MiB (1.2%) fs: vfat dev: /dev/sda2
Swap:
  ID-1: swap-1 type: file size: 2 GiB used: 0 KiB (0.0%) priority: -2 file: /swapfile
USB:
  Hub-1: 1-0:1 info: hi-speed hub with single TT ports: 9 rev: 2.0 speed: 480 Mb/s lanes: 1
    chip-ID: 1d6b:0002 class-ID: 0900
  Device-1: 1-1:2 info: Realtek RTL8188FTV 802.11b/g/n 1T1R 2.4G WLAN Adapter type: Network
    driver: rtl8xxxu interfaces: 1 rev: 2.0 speed: 480 Mb/s lanes: 1 power: 500mA chip-ID: 0bda:f179
    class-ID: 0000 serial: <filter>
  Device-2: 1-2:3 info: Logitech Unifying Receiver type: keyboard,mouse,HID
    driver: logitech-djreceiver,usbhid interfaces: 3 rev: 2.0 speed: 12 Mb/s lanes: 1 power: 98mA
    chip-ID: 046d:c52b class-ID: 0300
  Device-3: 1-7:4 info: IMC Networks Bluetooth type: bluetooth driver: btusb interfaces: 2
    rev: 2.0 speed: 12 Mb/s lanes: 1 power: 500mA chip-ID: 13d3:3394 class-ID: e001 serial: <filter>
  Hub-2: 2-0:1 info: full speed or root hub ports: 2 rev: 2.0 speed: 480 Mb/s lanes: 1
    chip-ID: 1d6b:0002 class-ID: 0900
  Hub-3: 2-1:2 info: Intel Integrated Rate Matching Hub ports: 8 rev: 2.0 speed: 480 Mb/s
    lanes: 1 chip-ID: 8087:8000 class-ID: 0900
  Hub-4: 3-0:1 info: super-speed hub ports: 4 rev: 3.0 speed: 5 Gb/s lanes: 1 chip-ID: 1d6b:0003
    class-ID: 0900
Sensors:
  System Temperatures: cpu: 57.0 C mobo: N/A
  Fan Speeds (rpm): N/A
Repos:
  Packages: pm: dpkg pkgs: 2007
  No active apt repos in: /etc/apt/sources.list
  Active apt repos in: /etc/apt/sources.list.d/chrome-remote-desktop.list
    1: deb [arch=amd64] http: //dl.google.com/linux/chrome-remote-desktop/deb/ stable main
  Active apt repos in: /etc/apt/sources.list.d/google-chrome.list
    1: deb [arch=amd64] https: //dl.google.com/linux/chrome/deb/ stable main
  Active apt repos in: /etc/apt/sources.list.d/official-package-repositories.list
    1: deb http: //packages.linuxmint.com zena main upstream import backport
    2: deb http: //archive.ubuntu.com/ubuntu noble main restricted universe multiverse
    3: deb http: //archive.ubuntu.com/ubuntu noble-updates main restricted universe multiverse
    4: deb http: //archive.ubuntu.com/ubuntu noble-backports main restricted universe multiverse
    5: deb http: //security.ubuntu.com/ubuntu/ noble-security main restricted universe multiverse
  Active apt repos in: /etc/apt/sources.list.d/tailscale.list
    1: deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https: //pkgs.tailscale.com/stable/ubuntu noble main
Info:
  Memory: total: 16 GiB available: 15.54 GiB used: 1.7 GiB (10.9%)
  Processes: 227 Power: uptime: 17m states: freeze,mem,disk suspend: deep wakeups: 0
    hibernate: platform Init: systemd v: 255 target: graphical (5) default: graphical
  Compilers: gcc: 13.3.0 Client: Unknown python3.12 client inxi: 3.3.34
[/code]
