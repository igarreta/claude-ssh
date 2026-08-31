---
name: project_contabo2_openclaw-heartbeat-cost
description: contabo2 openclaw heartbeat caused ~$1/day Anthropic Haiku cost since 2026-08-11; disabled
metadata: 
  node_type: memory
  type: project
  originSessionId: 06c52e8a-402e-4b2a-9fda-7a7bf5e92ee4
  modified: 2026-08-31T14:18:38.464Z
---

contabo2 runs `openclaw` (self-hosted Claude-Code-like agent gateway,
`/home/rsi/openclaw`, config `/home/rsi/.openclaw/config/openclaw.json`). Its
`agents.defaults.heartbeat` fired every 20 min (06:00-18:00 ART), ~10 `claude-haiku-4-5`
calls per tick, billed via a real `ANTHROPIC_API_KEY` — the config existed since April
but only started being billed once `anthropic.env` was wired into the container's
`env_file` on 2026-08-11. Disabled 2026-08-31 via `config unset agents.defaults.heartbeat`
(setting it to `null` directly in the JSON fails schema validation and crash-loops the
container — always use the CLI's `unset`, not a raw edit, to remove an openclaw config path).

**Why it matters:** if contabo2's Anthropic/API costs spike again, check
`agents.defaults.heartbeat` and any `~/.openclaw/config/cron/jobs.json` entries first —
openclaw is a live cost source on this host, separate from the comet log-monitor (which
uses subscription OAuth, not metered billing).

**How to apply:** before adding/re-enabling any openclaw heartbeat or cron job that calls
a paid model, prefer a coarse schedule (1-2x/day) over a tight interval.

Full write-up: `docs/2026-08-31_contabo2_openclaw-heartbeat-cost.md` in the claude-ssh repo.
