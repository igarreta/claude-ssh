# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Memory

**One fact, one home.** Three layers, each with a distinct job — never duplicate detail
between them, or updating one silently leaves the others lying:

| Layer | Holds | Size |
|---|---|---|
| `docs/*.md` (git-tracked) | the detail — the single source of truth | as long as needed |
| `docs/memory-nodes/<node>.md` | why it matters + how to apply + a `docs/` pointer | ~5–12 lines |
| `docs/memory-nodes/MEMORY.md` | **pointers only** — `- [node.md](node.md) — hook` | one line per node |

**The memory directory is a symlink into this repo**, so memory is versioned and every
memory write shows up in `git diff` for review before you commit it:

```
~/.claude/projects/-home-rsi-claude-ssh/memory -> /home/rsi/claude-ssh/docs/memory-nodes
```

Expect `git status` to go dirty during sessions where a memory is saved — that is the point,
not a problem. The nodes keep their memory-system frontmatter and are deliberately **exempt
from the `docs/` status-header convention**; the checks above glob `docs/*.md`, which does
not recurse into the subdirectory.

If the harness ever recreates that path as a real directory, the link is lost but the content
is not — it is already in git. Re-create the symlink and move any stray nodes across.

Rules:

1. **Never put content in `MEMORY.md`.** If a fact deserves remembering, it gets a node file.
   A bare line with the whole story in it is the failure this structure exists to prevent.
2. A node states *why the fact matters* and *how to apply it*, then points at `docs/`. It does
   not restate tables, inventories, or narrative that `docs/` already carries.
3. When a fact changes, update the `docs/` file first, then the node, then the `MEMORY.md`
   hook if the one-line summary is now wrong.
4. Link related nodes with `[[node_name]]` (no `.md`), and `docs/` files by path.

Check the layer is still consistent:

```bash
M=~/.claude/projects/-home-rsi-claude-ssh/memory
test -L "$M" || echo "SYMLINK LOST — re-link to docs/memory-nodes"   # link still intact
grep '^- ' $M/MEMORY.md | grep -v '](.*\.md)'                    # inline content: must be empty
for f in $M/*.md; do b=$(basename $f); [ "$b" = MEMORY.md ] && continue; \
  grep -q "($b)" $M/MEMORY.md || echo "unindexed: $b"; done       # every node indexed
grep -ho '\[\[[^]]*\]\]' $M/*.md | sed 's/\[\[//;s/\]\]//' | sort -u | \
  while read n; do case "$n" in docs/*) continue;; esac; \
  [ -e "$M/$n.md" ] || echo "dangling: [[$n]]"; done              # no broken wikilinks
```

## CRITICAL: docs/ conventions

**`docs/INDEX.md` is the entry point. Read it before searching `docs/` for how something
works** — it groups every doc into topic threads, current state first, so you don't act on
a stale write-up just because grep matched it.

### Every doc carries a status header

Immediately under the title of every file in `docs/`, before any other content:

```
**Status:** active | closed | superseded | open
**Host:** docker03, gr-srv03          (or `(fleet)` / `(project)`)
**Supersedes:** <older-file.md>       (or —)
**Superseded-by:** <newer-file.md>    (or —)
```

- **active** — describes how the system works *now*. Edit in place as reality changes.
- **closed** — a resolved incident. True as history; its fix is live. Don't edit, write a new doc.
- **superseded** — replaced. **Never act on it**; follow `Superseded-by`.
- **open** — unresolved, or a decision/purchase still pending. Needs follow-up.

Exactly **one** `**Status:**` line per file. If a doc needs a longer nuanced status, keep the
one-word canonical line and add a separate `**Status detail:**` line under it.

`Supersedes` / `Superseded-by` may carry a scope qualifier when only part of a doc is
replaced, e.g. `**Superseded-by:** 2026-08-20_nas-disk-prices.md (§5 and §9 only)`.

### The rules that keep it true

1. **Writing a doc that replaces an older one? Edit the old doc's `Superseded-by` in the
   same commit**, and set the new doc's `Supersedes`. A one-way link is the failure mode
   this convention exists to prevent — someone greps, hits the old doc first, and acts on
   a fix that was later found insufficient.
2. **Add the new doc to `docs/INDEX.md` in the same commit** — into its topic thread, and
   update that thread's **Current:** line if the state changed.
3. **When an `open` item resolves, change its status** to `closed` or `active` and update
   the thread's **Current:** line.
4. Never change a `closed` doc's findings. New facts go in a new dated doc that supersedes it,
   or in a `> **CORRECTED <date>**` banner at the top if the correction is small.

### Naming

- `YYYY-MM-DD_host_topic.md` — incident or investigation, dated, effectively immutable.
- `memory_<topic>.md` — live project/state notes, edited in place.
- `Title_Case.md` — legacy standing-reference docs. Don't create new ones.

Useful checks:

```bash
grep -l '^\*\*Status:\*\* open' docs/*.md          # what still needs attention
grep -l '^\*\*Status:\*\* superseded' docs/*.md    # what not to trust
grep -l '^\*\*Host:\*\*.*docker03' docs/*.md       # everything about one host
```

## General instructions
I like concise responses, without excesive duplication.
Respond as requested, do not extend with supossiotions about next steps. Do not add descriptions of possible alternatives before asking if they are required.
When working interatively give a general plan, then provide the instructions step by step, checking the output of one step before proceeding to the next

## Repository Purpose

This repository documents MCP (Model Context Protocol) connector configurations for Claude Code on the comet machine. It serves as a reference for SSH, GitHub, and Notion connectors.
It will be used to connect to different servers via ssh and use Claude to test, troubleshoot and repair

## CRITICAL: MCP Remote Command Length Limit

**MCP SSH connectors have a 1000-character limit per command.** Writing file contents inline will fail with:
`MCP error -32602: Command is too long (max 1000 characters)`

**Hybrid approach for writing files on remote servers:**
- Use MCP SSH tools for normal commands (reading files, running scripts, short writes)
- For writing files, use the `Write` tool locally to `/tmp/filename`, then `scp` it to the remote

**NEVER use `cat >`, heredocs (`<< 'EOF'`), or `echo >` via MCP to write file contents.** These will always exceed the limit for any non-trivial file. Always use local `Write` + `scp`.

```bash
scp -i ~/.ssh/id_ed25519_comet /tmp/filename user@host:/target/path
# For non-standard port (e.g. contabo1):
scp -i ~/.ssh/id_ed25519_comet -P 1789 /tmp/filename rsi@100.72.195.90:/target/path
```

If you need to copy a medium file or several small ones between two servers, ask if is is appropiate to install an ssh key to make the direct transfer

**NEVER send a multi-line command body (embedded `\n`, e.g. a multi-statement `bash -c '...'`) to an MCP SSH `run-command`/`privileged-command` tool.** The newlines get silently stripped/collapsed in transport, so separate statements merge onto one line — control operators (`&&`/`||`/redirects) then reinterpret the merged text in unintended ways, executing something different from what was written, with no error surfaced. This has corrupted a config file (`sshd_config`, taking SSH down on a host) by merging a `sed`/`echo` fallback chain into garbage appended text. Always send **one command per tool call**. For a real multi-step script, write it locally with `Write`, `scp` it over, then run it with a single `bash /tmp/script.sh` call.

### SSH connection details (key: `~/.ssh/id_ed25519_comet`)

Available mcp connectors and information for ssh connections, can be found in mcp-connectors.md

homeassistant uses password auth — not usable with direct SSH.

## CRITICAL: Shell Script Line Endings

**ALWAYS use Unix line endings (LF) when creating shell scripts.** Never use Windows-style CRLF line endings.

When writing shell scripts:
- Use the Write tool which produces correct LF endings
- If a script fails with "cannot execute: required file not found", check for CRLF with: `file script.sh`
- Fix with: `sed -i 's/\r$//' script.sh`

This has caused MCP connector failures multiple times. The shebang `#!/bin/bash\r` (with carriage return) is interpreted as looking for a binary named `bash\r` which doesn't exist.

## Key Information

- MCP configuration lives in `~/.claude.json` under `mcpServers`
- All SSH connections use key: `~/.ssh/id_ed25519_comet`
- SSH servers use Tailscale IPs (100.x.x.x range)
- Credential files are stored in `~/.ssh/` with 600 permissions
- Wrapper scripts in `~/etc/` handle environment setup for GitHub/Notion

## Configured SSH Servers

gr-srv03: proxmox server used for home managment
docker03 (102): VM in gr-srv03 for running docker containers in Debian 13
ceres (203): Debian 13 LXC in gr-srv03. Used for managing backups
cygnus (202): Debian 13 LXC in gr-srv03. Will run podman. Services in docker03 will be migrated to this container 
samba03 (101): LXC running a Turnkey server. Is beeing deprecated for proxmox shares and nfs shares with Tailscale
contabo1: a web based linux server running some Services, beeing deprecated
contabo2: a web based linux server running some Services, replacing contabo1 in march 2026
raspberrypi1: a raspberry pi for controlling the home heating
raspberrypi2z (100.92.195.47): a Raspberry Pi Zero W, receives temperature readings from 433 MHz devices via rtl_433 (protocol 19, Nexus/TFA sensors) → MQTT broker at 192.168.1.8:1883; topic prefix `rtl_433/raspberrypi2z`; service `rtl433.service` (runs as rsi). BCM2835 watchdog auto-armed by systemd at 60s (no explicit config, unlike raspberrypi1). See docs/2026-06-26_raspberrypi2z_rtl433-setup.md. **sudo requires password** (passwordless sudo removed).
homeassistant (104, 100.98.185.44): for home management, uses password auth (hassio user)
living1: is another small nuc for entertainment purposes. Most of the time is disconnected. Tailscale IP: 100.72.156.127
mosquitto (105, 100.69.153.63): Debian 13 LXC in gr-srv03, dedicated MQTT broker replacing the one on docker03. Native mosquitto (not containerized), `allow_anonymous false`, self-signed CA, listener 1883 (plaintext, auth-only — for raspberrypi2z's rtl_433, which has no TLS support) + listener 8883 (TLS, auth). Per-client users + ACLs; credentials in `/home/rsi/mosquitto-credentials.txt` on the host (600, not in git). LAN IP currently DHCP (`192.168.1.198`) pending a static assignment at the router. Client migration (zigbee2mqtt, TTato, rtl_433, tuya-link, Home Assistant) not yet done — see docs/memory_mqtt-broker-migration.md.

## raspberrypi2z
Scripts and config for raspberrypi2z are stored in `raspberrypi2z/` in this repo, organized in thematic subdirectories (e.g. `net-watchdog/`, `journald/`). Deploy by copying files to their target paths on the Pi. See `docs/2026-06-26_raspberrypi2z_wifi-watchdog.md` for the Wi-Fi hang diagnosis and watchdog setup.

## gr-srv03
All scripts for gr-srv03 must be stored in `/opt/proxmox-grsrv03/` (git repo: `igarreta/proxmox-grsrv03`), organized in thematic subdirectories (e.g. `host-backup/`, `monitoring/`). Never place scripts in `/usr/local/bin` or `/usr/local/sbin` directly — symlink from there if needed.

gr-srv03 runs in a GMTec NucBox G5 with  an N97 Intel processor and 12 GB of RAM
On 2026-01-14 is running pve-manager/9.1.2/9d436f37a0ac4172
Kernel is pinned to Linux 6.17.2-2-pve. I had hardware compatibility issues in the past, that can be found in the documentation
Documentation can be found in /opt/proxmox-grsrv03/docs/

I has connected:
- an usb drive, usually refered to as backup-usb1
- a rtl-433 : which I should move to cygnus in the future
- a zigbee hub

Backup drives BACKUP_A and BACKUP_B: only one is ever physically connected at a time; the other is always stored offsite. One being unmounted/missing is normal, not a fault. Once a week, both may be disconnected for one day during the swap.

Some containers run on vmbr1 for reducing LAN IP usage

More detailed information can be found in the docs directory of this repository

## living1
Gigabyte MMLP3AP-00 mini PC (NUC-style), used for entertainment.
- **OS**: Linux Mint 22.3 Zena (Ubuntu 24.04 base), Xfce 4.18
- **Kernel**: 6.17.0-14-generic
- **CPU**: Intel Core i3-4010U (dual core + HT, Haswell, 1.7 GHz)
- **RAM**: 16 GiB
- **Storage**: 240 GiB Kingston SSD (ext4, 33 GiB used)
- **Display**: Dell S2725DS 2560x1440 via HDMI
- **Network**:
  - Ethernet: Realtek RTL8111 gigabit (enp3s0) — **primary connection at home**
  - WiFi internal: Realtek RTL8723AE PCIe — blacklisted (`/etc/modprobe.d/blacklist-rtl8723ae.conf`)
  - WiFi USB: Realtek RTL8188FTV (rtl8xxxu driver) — used at other locations
    - Config: `/etc/modprobe.d/rtl8xxxu.conf` → `options rtl8xxxu dma_aggregation=1`
    - Regulatory domain: `/etc/default/crda` → `REGDOMAIN=AR`
- **Remote access**: AnyDesk (ID: 1451623058), Chrome Remote Desktop, Tailscale SSH
- **sudo**: requires password (not passwordless)
- Docs: `docs/2025-03-07_living1_description.md`, `docs/2025-12-13_living1_wifi-fix.md`

## cygnus
podman is installed, but must be run as sudo (sudo podman). It was configured to allow "sudo podman" without requestign the password

```bash
# Create dedicated sudoers file
sudo visudo -f /etc/sudoers.d/podman-nopasswd
```
Add this line (replace `rsi` with your username):
```
rsi ALL=(ALL) NOPASSWD: /usr/bin/podman
```

## log-monitor
Automated daily server log review. Runs on comet from cron (`0 8 * * *`), code in
`log-monitor/`. Per host: `collect.sh` (ssh+journalctl, aggregated, cursor-incremental) →
Haiku triage → Sonnet escalation (important+ only) → email always (Resend HTTP API) +
Pushover (important/critical only, deduped on a deterministic content-hash fingerprint).
Email creds in `~/etc/resend.env`. Add a host by dropping `log-monitor/hosts/<name>.conf`.
See `docs/2026-06-30_log-monitor.md`.

## Adding New MCP Servers

1. Edit `~/.claude.json`
2. Add entry under `projects["/home/rsi"].mcpServers`
3. Restart Claude Code

## Notifications
My preferred notification service is pushover

All notifications must include the hostname and the script name

Usually VMs and LXCs will have access to Pushover credentials in ~/etc/pushover.env with this structure

PUSHOVER_TOKEN="<pushover token>"
PUSHOVER_USER="<pushover user>"
DEFAULT_DEVICE=iphoneRSI