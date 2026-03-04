# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
homeassistant (104, 100.98.185.44): for home management, uses password auth (hassio user)
living1: is another small nuc for entertainment purposes. Most of the time is disconnected

## gr-srv03
gr-srv03 runs in a GMTec NucBox G5 with  an N97 Intel processor and 12 GB of RAM
On 2026-01-14 is running pve-manager/9.1.2/9d436f37a0ac4172
Kernel is pinned to Linux 6.17.2-2-pve. I had hardware compatibility issues in the past, that can be found in the documentation
Documentation can be found in /opt/proxmox-grsrv03/docs/

I has connected:
- an usb drive, usually refered to as backup-usb1
- a rtl-433 : which I should move to cygnus in the future
- a zigbee hub

Some containers run on vmbr1 for reducing LAN IP usage

More detailed information can be found in the docs directory of this repository

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