---
name: feedback_sudo_commands_no_ssh_wrap
description: Never wrap a sudo command for the user in ssh — they already run it in a session open on the target server
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 97d638ec-9b13-4d17-b59f-d4177f7a58f7
  modified: 2026-08-26T21:00:17.309Z
---

When a host needs a password for `sudo` and I hand the user a command to run themselves, give
the plain command only — never wrap it in `ssh host "sudo ..."`.

**Why:** The user runs these commands inside a session already open on the target server, not
from comet's terminal. An `ssh ... "sudo ..."` wrapper is redundant at best, and at worst asks
for an interactive password through a non-interactive `ssh -c`, which fails. Confirmed
2026-08-26 after wrapping a raspberrypi2z command in `ssh -i ... rsi@... "sudo cp && sudo mv
&& sudo systemctl restart ..."` — it worked only because the user ran it manually, not because
the wrapping was correct.

**How to apply:** applies to every host with password-required sudo, not just one (see
[[feedback_raspberrypi2z_sudo]], [[feedback_docker03_sudo]],
[[feedback_no_passwordless_sudo_castor]]). Write the script/change locally, `scp`/sftp-upload
it to the target host, then give the user the bare command (e.g. `sudo bash /tmp/script.sh` or
a direct `sudo mv ...`/`sudo systemctl restart ...`) with no `ssh` prefix.

**Caveat found 2026-08-26**: when a task spans two hosts (e.g. an scp from comet, then a sudo
move on the receiving host), label which host each command block runs on explicitly — a bare
command with no host label, right after an scp command, reads as "run this next in the same
place" and caused the user to try it on comet where it doesn't apply.
