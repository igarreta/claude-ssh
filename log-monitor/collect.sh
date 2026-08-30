#!/bin/bash
# collect.sh — deterministic log pre-filter for one host.
# Usage: collect.sh <host.conf> [--since "<journalctl-since>"]
# Writes the digest to stdout and updates the saved journal cursor on success.
# The journal is aggregated (identical messages collapsed to "count x signature")
# so high-volume repetitive warnings don't bloat the digest sent to the LLM.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$SCRIPT_DIR/state"
TOP_SIGNATURES=200      # cap distinct signatures emitted

CONF="${1:?usage: collect.sh <host.conf> [--since <expr>]}"
SINCE_OVERRIDE=""
if [[ "${2:-}" == "--since" ]]; then
    SINCE_OVERRIDE="${3:?--since needs a value}"
fi

# shellcheck disable=SC1090
source "$CONF"
: "${HOST_LABEL:?}" "${SSH_TARGET:?}" "${SSH_PORT:=22}" "${SSH_KEY:?}" "${PRIORITY_FLOOR:=warning}"

CURSOR_FILE="$STATE_DIR/${HOST_LABEL}.cursor"

ssh_run() {  # ssh_run <remote-command-string>
    ssh -i "$SSH_KEY" -p "$SSH_PORT" \
        -o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new \
        "$SSH_TARGET" "$@"
}

# Decide the journal window — pass type/value as argv to the remote script (no quoting traps).
if [[ -n "$SINCE_OVERRIDE" ]]; then
    WINDOW="since $SINCE_OVERRIDE (override)"; SEL_TYPE="since"; SEL_VAL="$SINCE_OVERRIDE"
elif [[ -s "$CURSOR_FILE" ]]; then
    WINDOW="after last run (incremental)"; SEL_TYPE="cursor"; SEL_VAL="$(cat "$CURSOR_FILE")"
else
    WINDOW="since -24 hours (first run bootstrap)"; SEL_TYPE="since"; SEL_VAL="-24 hours"
fi

# Host-specific noise suppression (SUPPRESS_PATTERN in host.conf), plus the extra
# Monday-only pattern (MONDAY_SUPPRESS_PATTERN) for noise tied to the router's weekly
# Monday-morning reboot. Combined here, then applied REMOTELY (see below).
SUPPRESS_EFFECTIVE="${SUPPRESS_PATTERN:-}"
if [[ -n "${MONDAY_SUPPRESS_PATTERN:-}" && "$(date +%a)" == "Mon" ]]; then
    SUPPRESS_EFFECTIVE="${SUPPRESS_EFFECTIVE:+$SUPPRESS_EFFECTIVE|}$MONDAY_SUPPRESS_PATTERN"
fi

# Remote: failed units + aggregated priority-filtered journal, in one round-trip.
# ssh re-splits argv on spaces, so pass everything as %q-quoted env vars instead.
REMOTE_ENV="$(printf 'SEL_TYPE=%q SEL_VAL=%q PRIORITY_FLOOR=%q TOP=%q SUPPRESS=%q' \
    "$SEL_TYPE" "$SEL_VAL" "$PRIORITY_FLOOR" "$TOP_SIGNATURES" "$SUPPRESS_EFFECTIVE")"
RAW="$(ssh -i "$SSH_KEY" -p "$SSH_PORT" \
        -o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new \
        "$SSH_TARGET" "$REMOTE_ENV bash -s" <<'REMOTE'
set -uo pipefail
case "$SEL_TYPE" in
    cursor) sel=(--after-cursor "$SEL_VAL") ;;
    since)  sel=(--since "$SEL_VAL") ;;
esac
echo "@@FAILED@@"
systemctl --failed --no-legend --plain 2>/dev/null || true
echo "@@JOURNAL@@"
# Strip leading "Mon DD HH:MM:SS host " and [pid].
raw="$(journalctl "${sel[@]}" --priority="${PRIORITY_FLOOR}"..emerg --no-pager -q 2>/dev/null \
        | sed -E 's/^[A-Z][a-z]{2} [ 0-9]{2} [0-9:]{8} [^ ]+ //; s/\[[0-9]+\]//g')"
raw_total=$(grep -c . <<<"$raw")
# Suppress host noise HERE, before aggregation and before the TOP cap. Filtering after
# the cap (as this used to) lets a high-volume noise source crowd every real message out
# of it — contabo2 emits ~4.5k UFW BLOCK lines/day, each unique, so uniq can't collapse
# them and they alone exceed TOP many times over.
if [[ -n "$SUPPRESS" ]]; then
    raw="$(grep -vE "$SUPPRESS" <<<"$raw" || true)"
fi
# Collapse duplicates with counts. Guard the empty case: a here-string always feeds one
# newline, which would otherwise aggregate into a bogus "1 <blank>" signature.
# Count with grep, NOT `[[ -n "${raw//[[:space:]]/}" ]]` — bash global substitution over a
# multi-megabyte string takes minutes, which on an unsuppressed high-volume host looks
# exactly like an ssh hang.
kept=$(grep -c . <<<"$raw")
if (( kept > 0 )); then
    agg="$(sort <<<"$raw" | uniq -c | sort -rn)"
else
    agg=""
fi
total=$(awk '{s+=$1} END{print s+0}' <<<"$agg")
distinct=$(grep -c . <<<"$agg")
echo "@@STATS@@ total=${total} distinct=${distinct} suppressed=$((raw_total - total))"
# awk, not `head -n`: head exits early on a long list, the upstream printf takes SIGPIPE,
# and `set -o pipefail` turns that into exit 141 for the whole remote shell — which the
# caller's `set -e` then treats as an ssh failure. awk drains its input, so it can't.
printf '%s\n' "$agg" | awk -v n="$TOP" 'NR<=n'
REMOTE
)"

FAILED_UNITS="$(awk '/@@FAILED@@/{f=1;next} /@@JOURNAL@@/{f=0} f' <<<"$RAW")"
STATS="$(awk -F'@@STATS@@ ' '/@@STATS@@/{print $2}' <<<"$RAW")"
JOURNAL="$(awk '/@@STATS@@/{j=1;next} j' <<<"$RAW")"

# (noise suppression happens remotely, before the TOP cap — see REMOTE block above)

# Newest journal cursor (any priority) so the next run resumes exactly here.
NEW_CURSOR="$(ssh_run 'journalctl -o export -n1 --no-pager 2>/dev/null | sed -n "s/^__CURSOR=//p"')"

# Emit digest.
printf '=== %s — collected %s ===\n' "$HOST_LABEL" "$(date '+%Y-%m-%dT%H:%M:%S%z')"
printf 'Window: %s\n\n' "$WINDOW"

printf -- '--- Failed systemd units ---\n'
if [[ -n "${FAILED_UNITS//[[:space:]]/}" ]]; then printf '%s\n' "$FAILED_UNITS"; else printf 'none\n'; fi
printf '\n'

printf -- '--- Journal (priority %s..emerg) ---\n' "$PRIORITY_FLOOR"
if [[ -n "${JOURNAL//[[:space:]]/}" ]]; then
    printf '%s  (top %s signatures by frequency)\n\n' "$STATS" "$TOP_SIGNATURES"
    printf '%s\n' "$JOURNAL"
else
    printf 'none\n'
fi

# Backup health (BACKUP_A/B + Glacier freshness/drift). Opt-in per host — only gr-srv03
# has the disks. Runs from comet, not over the ssh_run wrapper above: it needs its own
# ssh round trips to gr-srv03 *and* ceres. See backup-health.sh for why.
if [[ -n "${BACKUP_HEALTH_CHECK:-}" ]]; then
    printf '\n--- Backup health (BACKUP_A/B + Glacier) ---\n'
    "$SCRIPT_DIR/backup-health.sh" 2>>"$STATE_DIR/llm-errors.log" || printf 'ERROR: backup-health.sh failed\n'
fi

# Persist cursor only if we got one (don't lose position on a transient ssh hiccup).
if [[ -n "$NEW_CURSOR" ]]; then
    printf '%s' "$NEW_CURSOR" > "$CURSOR_FILE"
fi
