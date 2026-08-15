# log-monitor

Daily automated log review for homelab servers. Runs on **comet** from cron.

## Pipeline
`run.sh` per host in `hosts/*.conf`:
1. **collect.sh** — `ssh` + `journalctl`/`systemctl --failed`, incremental via a saved
   journal cursor (first run bootstraps at `-24h`). Deterministic pre-filter, no LLM.
2. **Haiku triage** (`prompts/triage.md`) — classifies the digest by severity and emits
   parseable headers (`MAX_SEVERITY`, `ESCALATE`, `FINGERPRINT`, `SEVERITY_COUNTS`).
3. **Sonnet escalation** (`prompts/analyze.md`) — only when triage flags important/critical;
   root cause + recommended action.
4. **Email** (always, via Resend HTTP API) + **Pushover** (only important/critical, with 24h
   per-fingerprint cooldown to avoid repeat alerts).
5. **Archive** — full report to `archive/<host>/YYYY-MM-DD.md`, one line per run to
   `archive/<host>/summary.log`. 90-day retention on the dated reports.

## Files
- `run.sh` — orchestrator / cron entrypoint
- `collect.sh` — per-host log collection
- `backup-health.sh` — freshness + drift check for BACKUP_A/B and Glacier, appended to
  gr-srv03's digest when `BACKUP_HEALTH_CHECK=yes` in its conf. Deterministic (bash + jq),
  never touches Deep Archive data. See `docs/2026-08-14_backup-health-monitor-design.md`.
- `lib/notify.sh` — Pushover + email helpers
- `prompts/` — triage (Haiku) and analyze (Sonnet) prompts
- `hosts/*.conf` — one file per monitored host
- `state/` — cursors, dedup log, last digest, `backup-sizes.csv` *(gitignored)*
- `archive/` — dated reports + summary log *(gitignored)*

## Setup
- `~/etc/pushover.env` (already present) — Pushover credentials.
- `~/etc/resend.env` (chmod 600) — `RESEND_API_KEY`, `MAIL_FROM`, `MAIL_TO`
  (copy from `resend.env.example`). `MAIL_FROM` must use a Resend-verified domain.
- `~/etc/restic-password-local` (chmod 600) — read-only copy of ceres's BACKUP_A/B restic
  password, needed by `backup-health.sh` to read snapshots from gr-srv03 over SSH (passed
  inline, never written to gr-srv03's disk — that host's own policy is to keep recovery
  credentials in Notion only).
- No system packages required (uses `curl` + `jq`, already present).

## Usage
```bash
./run.sh                      # normal daily run (incremental)
./run.sh --since "-7 days"    # one-off wide window (testing)
./collect.sh hosts/gr-srv03.conf --since "-24 hours"   # inspect a digest only
```

## Cron
```
0 8 * * *  /home/rsi/claude-ssh/log-monitor/run.sh >> /home/rsi/claude-ssh/log-monitor/state/cron.log 2>&1
```

## Adding a host
Drop a new `hosts/<name>.conf` (copy `gr-srv03.conf`, adjust `SSH_TARGET`/`SSH_PORT`/
`PRIORITY_FLOOR`). No other changes needed.
