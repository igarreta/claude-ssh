#!/bin/bash
# notify.sh — Pushover + email helpers for log-monitor. Sourced by run.sh.
# Requires: ~/etc/pushover.env (Pushover), ~/etc/resend.env
#           (RESEND_API_KEY, MAIL_FROM, MAIL_TO). Email goes via the Resend HTTP API.

PUSHOVER_CONFIG="${PUSHOVER_CONFIG:-$HOME/etc/pushover.env}"
RESEND_CONFIG="${RESEND_CONFIG:-$HOME/etc/resend.env}"
SCRIPT_NAME="log-monitor"
ORCH_HOST="$(hostname -s)"

# shellcheck disable=SC1090
[[ -f "$PUSHOVER_CONFIG" ]] && source "$PUSHOVER_CONFIG"
# shellcheck disable=SC1090
[[ -f "$RESEND_CONFIG" ]] && source "$RESEND_CONFIG"

# pushover_send <message> [priority]  — message should already mention the target host.
pushover_send() {
    local message="$1" priority="${2:-0}"
    if [[ -z "${PUSHOVER_TOKEN:-}" || -z "${PUSHOVER_USER:-}" ]]; then
        echo "WARN: Pushover not configured; skipping alert" >&2
        return 0
    fi
    local title="[${ORCH_HOST}/${SCRIPT_NAME}]"
    curl -s --max-time 20 \
        --form-string "token=${PUSHOVER_TOKEN}" \
        --form-string "user=${PUSHOVER_USER}" \
        --form-string "title=${title}" \
        --form-string "message=${message}" \
        --form-string "priority=${priority}" \
        ${DEFAULT_DEVICE:+--form-string "device=${DEFAULT_DEVICE}"} \
        https://api.pushover.net/1/messages.json > /dev/null
}

# email_send <subject> <body-file>  — plain-text email via the Resend HTTP API.
# MAIL_TO may be a single address or a comma-separated list.
email_send() {
    local subject="$1" body_file="$2"
    if [[ -z "${RESEND_API_KEY:-}" || -z "${MAIL_FROM:-}" || -z "${MAIL_TO:-}" ]]; then
        echo "WARN: Resend not configured in $RESEND_CONFIG; skipping email" >&2
        return 0
    fi
    local payload resp
    payload="$(jq -n \
        --arg from "$MAIL_FROM" --arg to "$MAIL_TO" \
        --arg subject "$subject" --rawfile text "$body_file" \
        '{from:$from, to:($to|split(",")|map(gsub("^ +| +$";""))), subject:$subject, text:$text}')"
    resp="$(curl -s --max-time 30 -X POST https://api.resend.com/emails \
        -H "Authorization: Bearer $RESEND_API_KEY" \
        -H 'Content-Type: application/json' \
        -d "$payload")"
    if ! grep -q '"id"' <<<"$resp"; then
        echo "WARN: Resend email failed: $resp" >&2
        return 1
    fi
}
