# contabo2 — openclaw heartbeat drove ~$1/day Anthropic API cost since Aug 11

**Status:** closed
**Host:** contabo2
**Supersedes:** —
**Superseded-by:** —

**Date:** 2026-08-31

## Symptom

Anthropic API usage (billed, not subscription) rose to ~USD 1/day starting 2026-08-11,
all on `claude-haiku-4-5`.

## Cause

`openclaw` (self-hosted Claude-Code-like agent gateway, container
`openclaw-openclaw-gateway-1`, config at `/home/rsi/.openclaw/config/openclaw.json`) has
an `agents.defaults.heartbeat` feature — applied to both configured agents (`tadeo`,
`babel`) since neither overrides it:

```json
{
  "every": "20m",
  "model": "anthropic/claude-haiku-4-5",
  "activeHours": {"start": "06:00", "end": "18:00", "timezone": "America/Argentina/Buenos_Aires"},
  "target": "last", "lightContext": true, "isolatedSession": true
}
```

This existed in config since April, but had no live Anthropic credential wired into the
container until commit `148b3f76ab` ("feat(docker): wire anthropic and deepseek env
files into gateway") landed **2026-08-11 17:26** in the `openclaw` repo, adding
`/home/rsi/etc/anthropic.env` (real `ANTHROPIC_API_KEY`) to the gateway's `env_file` list
in `docker-compose.yml`. From that point every 20-minute tick (36/day during active
hours) actually reached `api.anthropic.com` and got billed — each tick made a burst of
~10 sequential Haiku calls. By 2026-08-30 the account's own configured usage cap was
being hit daily (`"You have reached your specified API usage limits"`), and the last 4+
days of heartbeat ticks were 100% failures — no value being delivered, only wasted
requests.

## Fix

Disabled the heartbeat: `docker exec openclaw-openclaw-gateway-1 node dist/index.js
config unset agents.defaults.heartbeat`. Applied live, no restart needed, confirmed
absent via `config get`.

Note: setting the field to `null` directly in `openclaw.json` (instead of using `config
unset`) fails schema validation and crash-loops the gateway container — the config CLI's
`unset` verb is the schema-safe way to remove a config path. Backup taken before editing:
`openclaw.json.manual-bak-heartbeat-disable-2026-08-31` in the same config dir.

## If a periodic check-in is wanted again

Prefer a coarse cron job (e.g. 1-2x/day) over a heartbeat — same intent, ~1/18th the
Haiku call volume, and existing `openclaw` cron jobs (`~/.openclaw/config/cron/jobs.json`)
are the established pattern for scheduled agent tasks on this host (e.g. the daily
DeepSeek balance check).
