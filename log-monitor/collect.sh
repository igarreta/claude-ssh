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

# Remote: failed units + aggregated priority-filtered journal, in one round-trip.
# ssh re-splits argv on spaces, so pass everything as %q-quoted env vars instead.
REMOTE_ENV="$(printf 'SEL_TYPE=%q SEL_VAL=%q PRIORITY_FLOOR=%q TOP=%q' \
    "$SEL_TYPE" "$SEL_VAL" "$PRIORITY_FLOOR" "$TOP_SIGNATURES")"
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
# Strip leading "Mon DD HH:MM:SS host " and [pid], then collapse duplicates with counts.
agg="$(journalctl "${sel[@]}" --priority="${PRIORITY_FLOOR}"..emerg --no-pager -q 2>/dev/null \
        | sed -E 's/^[A-Z][a-z]{2} [ 0-9]{2} [0-9:]{8} [^ ]+ //; s/\[[0-9]+\]//g' \
        | sort | uniq -c | sort -rn)"
total=$(awk '{s+=$1} END{print s+0}' <<<"$agg")
distinct=$(grep -c . <<<"$agg")
echo "@@STATS@@ total=${total} distinct=${distinct}"
printf '%s\n' "$agg" | head -n "$TOP"
REMOTE
)"

FAILED_UNITS="$(awk '/@@FAILED@@/{f=1;next} /@@JOURNAL@@/{f=0} f' <<<"$RAW")"
STATS="$(awk -F'@@STATS@@ ' '/@@STATS@@/{print $2}' <<<"$RAW")"
JOURNAL="$(awk '/@@STATS@@/{j=1;next} j' <<<"$RAW")"

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

# Persist cursor only if we got one (don't lose position on a transient ssh hiccup).
if [[ -n "$NEW_CURSOR" ]]; then
    printf '%s' "$NEW_CURSOR" > "$CURSOR_FILE"
fi
