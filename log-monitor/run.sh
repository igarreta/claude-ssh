#!/bin/bash
# run.sh — log-monitor orchestrator (cron entrypoint).
# Per host: collect -> Haiku triage -> (Sonnet escalate) -> email + Pushover -> archive.

set -uo pipefail

# --- cron environment (find claude + its OAuth creds) ---
export HOME="${HOME:-/home/rsi}"
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$SCRIPT_DIR/state"
ARCHIVE_DIR="$SCRIPT_DIR/archive"
PROMPTS="$SCRIPT_DIR/prompts"
REPORTED_LOG="$STATE_DIR/reported.log"

HAIKU="claude-haiku-4-5-20251001"
SONNET="claude-sonnet-4-6"
COOLDOWN=259200     # 3 days between repeat Pushover alerts for the same problem set
                    # (must exceed the daily cadence, else an unchanged issue re-alerts nightly)
RETENTION_DAYS=90

# Optional --since override applies to every host this run (test convenience).
SINCE_ARGS=()
[[ "${1:-}" == "--since" ]] && SINCE_ARGS=(--since "${2:?--since needs a value}")

# shellcheck disable=SC1090
source "$SCRIPT_DIR/lib/notify.sh"

mkdir -p "$STATE_DIR" "$ARCHIVE_DIR"
touch "$REPORTED_LOG"

sev_is_alertable() { [[ "$1" == "important" || "$1" == "critical" ]]; }

# Run a model: stdin = prompt file + appended sections.
llm() {
    local model="$1"
    timeout 180 claude -p --model "$model" 2>>"$STATE_DIR/llm-errors.log"
}

process_host() {
    local conf="$1"
    # shellcheck disable=SC1090
    source "$conf"
    local label="$HOST_LABEL"
    local digest_file="$STATE_DIR/${label}.digest"
    local today; today="$(date +%F)"
    local stamp; stamp="$(date '+%Y-%m-%dT%H:%M:%S%z')"

    echo "[$(date '+%T')] collecting $label" >&2
    if ! "$SCRIPT_DIR/collect.sh" "$conf" "${SINCE_ARGS[@]}" > "$digest_file"; then
        pushover_send "log-monitor: FAILED to collect logs from ${label} (ssh error)." 1
        return 1
    fi

    # Quiet run? No real content once headers / "none" / blank lines are stripped.
    local quiet="no" content_lines
    content_lines="$(grep -cvE '^(===|---|Window:|none|[[:space:]]*$)' "$digest_file")"
    [[ "$content_lines" -eq 0 ]] && quiet="yes"

    local counts max_sev escalate triage_body analysis=""
    # Deterministic fingerprint of the problem set (leading counts stripped, so volume
    # jitter doesn't change it). Used for alert dedup — stable across runs, unlike LLM slugs.
    local fp
    fp="$(grep -vE '^(===|---|Window:|none|total=|[[:space:]]*$)' "$digest_file" \
          | sed -E 's/^[[:space:]]*[0-9]+[[:space:]]+//' | sort -u | sha1sum | cut -c1-16)"
    if [[ "$quiet" == "yes" ]]; then
        counts="critical=0 important=0 warning=0 notice=0 info=0"
        max_sev="none"; escalate="no"
        triage_body="## Triage summary\nAll clear — no warning-or-above journal entries or failed units since the last run."
        triage_body="$(printf '%b' "$triage_body")"
    else
        echo "[$(date '+%T')] triaging $label (Haiku)" >&2
        local triage_out
        triage_out="$( { cat "$PROMPTS/triage.md"; printf '\n\n=== DIGEST ===\n'; cat "$digest_file"; } | llm "$HAIKU" )"

        if [[ -z "$triage_out" ]] || ! grep -q '^MAX_SEVERITY:' <<<"$triage_out"; then
            # Triage failed — don't swallow it; flag for a human.
            counts="critical=0 important=0 warning=0 notice=0 info=0"
            max_sev="important"; escalate="no"
            triage_body="$(printf '## Triage summary\nTriage step failed or returned no usable output. Raw digest included below for manual review.\n\nRaw triage output:\n%s' "$triage_out")"
        else
            counts="$(sed -n 's/^SEVERITY_COUNTS:[[:space:]]*//p' <<<"$triage_out" | head -1)"
            max_sev="$(sed -n 's/^MAX_SEVERITY:[[:space:]]*//p' <<<"$triage_out" | head -1)"
            escalate="$(sed -n 's/^ESCALATE:[[:space:]]*//p' <<<"$triage_out" | head -1)"
            triage_body="$(sed -n '/^---$/,$p' <<<"$triage_out" | sed '1d')"
            [[ -z "$triage_body" ]] && triage_body="$triage_out"
        fi

        if [[ "$escalate" == "yes" ]]; then
            echo "[$(date '+%T')] escalating $label (Sonnet)" >&2
            analysis="$( { cat "$PROMPTS/analyze.md"; printf '\n\n=== DIGEST ===\n'; cat "$digest_file"; printf '\n\n=== TRIAGE ===\n%s\n' "$triage_body"; } | llm "$SONNET" )"
            [[ -z "$analysis" ]] && analysis="## Analysis\n(escalation step returned no output — review digest manually)"
        fi
    fi

    # --- Build report ---
    local report; report="$(mktemp)"
    {
        printf '# Log report — %s — %s\n\n' "$label" "$stamp"
        printf 'Max severity: **%s**  |  Counts: %s  |  Escalated: %s\n\n' "$max_sev" "$counts" "$escalate"
        printf '%s\n\n' "$triage_body"
        [[ -n "$analysis" ]] && printf '%b\n\n' "$analysis"
        printf '<details><summary>Raw digest</summary>\n\n```\n'
        cat "$digest_file"
        printf '\n```\n</details>\n'
    } > "$report"

    # --- Archive + summary log ---
    mkdir -p "$ARCHIVE_DIR/$label"
    cp "$report" "$ARCHIVE_DIR/$label/${today}.md"

    # --- Pushover (alertable + problem set not alerted within cooldown) ---
    # Suppress only when the exact same problem set (fp) was alerted recently; a changed
    # set (new/resolved issue) produces a new fp and alerts again.
    local alerted="no"
    if sev_is_alertable "$max_sev"; then
        local now last
        now="$(date +%s)"
        last="$(awk -F'\t' -v l="$label" -v f="$fp" '$1==l && $2==f{t=$3} END{print t+0}' "$REPORTED_LOG")"
        if (( now - last >= COOLDOWN )); then
            local prio=0; [[ "$max_sev" == "critical" ]] && prio=1
            pushover_send "log-monitor [${label}]: ${max_sev} (${counts}). See email report." "$prio"
            printf '%s\t%s\t%s\n' "$label" "$fp" "$now" >> "$REPORTED_LOG"
            alerted="yes"
        fi
    fi

    # --- Email (always) ---
    local subject
    if [[ "$max_sev" == "none" ]]; then
        subject="[${label}] log-monitor: all clear — ${today}"
    else
        subject="[${label}] log-monitor: ${max_sev} — ${today}"
    fi
    email_send "$subject" "$report"

    printf '%s max=%s escalate=%s counts="%s" alerted=%s\n' \
        "$stamp" "$max_sev" "$escalate" "$counts" "$alerted" >> "$ARCHIVE_DIR/$label/summary.log"

    rm -f "$report"
    echo "[$(date '+%T')] $label done: max=$max_sev escalate=$escalate alerted=$alerted" >&2
}

# --- main ---
for conf in "$SCRIPT_DIR"/hosts/*.conf; do
    [[ -e "$conf" ]] || continue
    ( process_host "$conf" ) || echo "ERROR processing $conf" >&2
done

# --- retention: prune archives older than RETENTION_DAYS (summary.log kept) ---
find "$ARCHIVE_DIR" -type f -name '*.md' -mtime +"$RETENTION_DAYS" -delete 2>/dev/null || true
