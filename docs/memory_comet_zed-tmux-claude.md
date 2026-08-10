# Memory: comet replication of zed-tmux-claude setup (2026-08-10)

**Status:** done on comet; one manual client-side step left for the user.

## What this is
`~/bin/docs/zed-tmux-claude.md` documents a Zed+SSH+tmux+Claude Code workflow
(persistent per-project tmux session, reattach-or-create via
`~/bin/tmux-claude.sh`, terminal-bell notifications) built on `contabo2`,
meant to be replicated on other servers. Comet is one such server — and it's
also the host `claude-ssh` (this repo) itself runs on.

## What was found / done on comet
- `~/bin` (`igarreta/bin` repo) had an **unresolved merge conflict** in
  `bashrc.sh` when this work started: origin's fix commit `d1213c2`
  (subshell-wrapped `(cd ~/bin && git pull)`, prevents login shells from
  always landing in `~`) collided with comet's local `e1e02cd` (`cc` alias
  for `start-claude.sh`). Resolved by keeping the `cc` alias and taking the
  subshell fix; merged and pushed to origin as `f14f104`.
- `tmux`, `claude` CLI already installed on comet — no install needed.
- `~/bin/tmux-claude.sh` and `~/bin/docs/zed-tmux-claude.md` arrived via that
  same merge, unmodified from the doc.
- Smoke-tested `~/bin/tmux-claude.sh /home/rsi/claude-ssh`: creates tmux
  session `claude-ssh` running `claude`; re-running reattaches, doesn't
  duplicate. (`attach-session` itself errors "not a terminal" when run from
  a non-tty context like an MCP/Bash-tool shell — expected, works fine from
  a real terminal.) Session was left running.
- Added `"preferredNotifChannel": "terminal_bell"` to comet's
  `~/.claude/settings.json`. Read at Claude process startup only — an
  already-running session (including the pre-existing `claude`/`cc` tmux
  session and this smoke-test `claude-ssh` one) needs a fresh `claude`
  invocation to pick it up. **Confirmed working end-to-end**: user tested
  in a new tmux thread, bell rang on a real `Notification` event.

## Still open (user action, client-side)
Zed's `tasks.json` is read from the **Windows client**, not any remote host
— add via `Ctrl+Shift+P → "zed: open tasks"` on Windows:
```json
{
  "label": "comet » claude-ssh",
  "command": "/home/rsi/bin/tmux-claude.sh",
  "args": ["/home/rsi/claude-ssh"],
  "use_new_terminal": true,
  "allow_concurrent_runs": true
}
```

## Notes for future incidents
- Comet already had a project-specific predecessor of this pattern:
  `~/claude-ssh/start-claude.sh` (alias `cc`), hardcoded to this repo and a
  fixed tmux session name `claude`. `tmux-claude.sh` duplicates this for the
  same project under a different session name (`claude-ssh` vs `claude`) —
  not consolidated, both currently coexist. If asked to add more comet
  projects to Zed later, `tmux-claude.sh` is the one to point new task
  entries at (it's host-agnostic, no per-project script needed); `cc` stays
  as the manual/local shortcut.
- `~/bin` is shared across every server that sources it via `.bashrc` — a
  merge conflict there (as happened here) isn't comet-specific breakage,
  just two servers/commits touching the same lines independently. Standard
  resolution, nothing to treat as a bug.
- Bash-tool / MCP exec shells are non-tty, so `tmux attach-session` (or
  anything needing a real pty) will always error there — that's an
  environment limitation, not a script fault. Verify tmux logic instead via
  `tmux has-session` / `tmux list-panes`, as done here.
