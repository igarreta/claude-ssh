# Log-monitor — automated daily server log review

**Date:** 2026-06-30
**Host:** comet (orchestrator) → targets gr-srv03 (v1)
**Code:** `log-monitor/` in this repo

## Purpose
Automated daily review of server logs: collect → AI triage → escalate → email digest
(always) + Pushover alert (important issues only). Starts with gr-srv03; designed to
fan out to more hosts by adding `hosts/*.conf`.

## Architecture
Cron on comet runs `log-monitor/run.sh` daily at 08:00. Per host:

1. **Collect** (`collect.sh`) — deterministic, no LLM. `ssh` to the host, run
   `journalctl` (priority warning..emerg) + `systemctl --failed`. Incremental via a
   saved **journal cursor**; first run bootstraps at `-24h`. The journal is **aggregated
   remotely** — identical messages (timestamp/PID stripped) collapse to `count × signature`,
   shrinking ~650 lines/day to a few dozen. Output: `state/<host>.digest`.
2. **Triage (Haiku)** — `prompts/triage.md`. Classifies the digest by severity
   (info/notice/warning/important/critical), emits parseable headers `SEVERITY_COUNTS`,
   `MAX_SEVERITY`, `ESCALATE`.
3. **Escalate (Sonnet)** — only when triage flags important/critical. `prompts/analyze.md`
   produces root-cause + recommended action.
4. **Email (always)** via the **Resend HTTP API** (plain text). Subject reflects max severity.
5. **Pushover (important/critical only)**, with dedup (see below).
6. **Archive** — full report to `archive/<host>/YYYY-MM-DD.md`; one line per run to
   `archive/<host>/summary.log`. Dated reports pruned after 90 days.

## Model auth / cost
`claude` CLI uses **subscription OAuth** (`~/.claude/.credentials.json`), so headless
`claude -p` works in cron with no API key. Model tiering (Haiku triage, Sonnet only on
escalation) manages plan usage, not per-token billing.

## Alert dedup (important)
The Pushover cooldown keys on a **deterministic fingerprint** computed in code:
sha1 of the digest's sorted unique problem signatures with leading counts stripped.
LLM-generated slugs were tried first but drift every run (`backup-usb-failure` vs
`backup-usb-mount-fail`), defeating dedup — so the fingerprint is content-derived instead.
Same problem set within `COOLDOWN` (3 days) → Pushover suppressed; a changed set
(new/resolved issue) → new fingerprint → alerts again. Cooldown exceeds the daily cadence
so an unchanged ongoing problem doesn't re-alert nightly. The daily **email always**
carries full detail regardless.

## Configuration
- `~/etc/pushover.env` — Pushover creds (pre-existing).
- `~/etc/resend.env` (chmod 600) — `RESEND_API_KEY`, `MAIL_FROM` (Resend-verified domain),
  `MAIL_TO`. Sender: `comet@igarreta.net` → `ramon.igarreta@gmail.com`.
- No system packages required (`curl` + `jq` only).

## Cron
```
0 8 * * *  /home/rsi/claude-ssh/log-monitor/run.sh >> /home/rsi/claude-ssh/log-monitor/state/cron.log 2>&1
```

## Verification done (2026-06-30)
- Collection: 4,579 raw warning+ lines/7d → 25 signatures → 34-line digest. ✓
- Triage (Haiku) + escalation (Sonnet): correct severity + actionable analysis. ✓
- Email via Resend API: accepted (returns id) and **delivered to Gmail inbox (confirmed)**. ✓
- Pushover: test alert delivered. ✓
- Dedup: run twice → run1 alerts, run2 suppressed; fingerprint stable across runs. ✓
- Cron readiness: ran under stripped `env -i`, exit 0; quiet/all-clear path emits email, no alert. ✓
- Cron installed: `0 8 * * *` on comet. ✓

## Adding a host
Drop `hosts/<name>.conf` (copy `gr-srv03.conf`, set `SSH_TARGET`/`SSH_PORT`/`PRIORITY_FLOOR`).
No other changes.

## Noise suppression (SUPPRESS_PATTERN)

`collect.sh` supports a `SUPPRESS_PATTERN` variable in each host config: a `grep -vE`
regex applied to the aggregated journal lines before they reach the LLM.

`gr-srv03.conf` suppresses:
- `BACKUP_B|backup_b|2d0b0d7c` — rotating removable backup drives; absence/timeout is expected.
- `192\.168\.1\.54` — WDMyCloud NAS (old hardware, reboots nightly causing CIFS reconnects).
- `own address as source` — `vmbr0` "received packet ... with own address as source" (2026-07-03:
  investigated, was a single 2s/9-line burst on 2026-07-02 21:32, no recurrence). `vmbr0` has one
  port (`enp2s0`) with STP off, so a local loop is impossible; a real external loop would need to
  recur over time, but the digest aggregator collapses timestamps into a bare count, so a one-off
  burst reads to the LLM triage like an ongoing loop. Suppressed; revisit if it recurs across days.

## Issues resolved after first runs (2026-06-30)

| Issue | Resolution |
|-------|-----------|
| postfix `/etc/aliases.db` missing | Ran `newaliases` on gr-srv03 — file created, errors gone. |
| BACKUP_B mount timeout | Expected — rotating drive, suppressed in log-monitor. |
| CIFS `192.168.1.54` nightly reconnect | Expected — WDMyCloud reboot, suppressed. |
| EXT4 `sdc1` errors (02:30, 03:00 daily) | BACKUP_B had hardware I/O failure; stale `shutdown`-flagged sdc1 mount persisted inside ceres LXC. Fixed with `pct exec 203 -- umount -l /mnt/backup_b`. See `Backup_Drives_Mounting_Configuration.md`. |
| `dm-15` write access warnings | Normal — vzdump mounts LVM snapshots read-only during backup. |

## Notes / future
- Out of scope for v1: live SSH context-gathering during escalation, log sources beyond
  the systemd journal, per-service custom rules.
