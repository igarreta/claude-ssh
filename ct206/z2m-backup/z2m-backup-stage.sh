#!/bin/bash
# z2m-backup-stage.sh - stage zigbee2mqtt's irreplaceable state into ~/bak.
#
# Host: CT206 (zigbee2mqtt, 10.0.100.12). Runs as root from z2m-backup.timer at
# 02:00, seven minutes before rsi's ~/bin/backup.sh ships ~/bak to
# /mnt/backup -> /mnt/backup_usb1/zigbee2mqtt on gr-srv03, whence ceres' restic
# job copies it to BACKUP_A/B at 03:00.
#
# Why root: /opt/zigbee2mqtt/data is owned by the zigbee2mqtt user and
# configuration.yaml / state.json are 0600. CT206's sudo needs a password, so a
# cron job running as rsi could not read them.
#
# Why encrypted: configuration.yaml holds the MQTT password and
# advanced.network_key in cleartext, and coordinator_backup.json holds the
# network key too. backup.sh copies ~/bak to backup_usb1 *unencrypted* (only
# ~/etc gets the gpg treatment), so the encryption has to happen here.
#
# Why a fixed filename: generations come from backup.sh's 10 timestamped
# /mnt/backup/backup_<ts>/ directories, not from ~/bak. Same pattern as
# contabo2's uptime-kuma.tar.gz.
#
# See docs/2026-09-12_ct206_zigbee2mqtt-backup.md in the claude-ssh repo.

set -uo pipefail

SCRIPT_NAME="z2m-backup-stage.sh"
HOSTNAME="$(hostname)"

DATA_DIR="${Z2M_DATA_DIR:-/opt/zigbee2mqtt/data}"
OUT_DIR="/home/rsi/bak"
OUT_FILE="$OUT_DIR/zigbee2mqtt-data.tar.gz.gpg"
LOG_FILE="$OUT_DIR/z2m-backup.log"
BACKUP_KEY="/mnt/secrets/backup.key"
PUSHOVER_CONFIG="/home/rsi/etc/pushover.env"

# The five files that actually matter. log/ is excluded (the whole 24 MB of the
# data dir is logs, rotated at ~22 h) and so is configuration.example.yaml.
FILES=(configuration.yaml database.db state.json coordinator_backup.json ca.crt)

MAX_ATTEMPTS=3
RETRY_SLEEP=3

STAGING=""
cleanup() { [[ -n "$STAGING" ]] && rm -rf "$STAGING"; }
trap cleanup EXIT

log_message() {
    local message="$(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo "$message"
    echo "$message" >> "$LOG_FILE"
}

# Pushover on errors only, never on success (fleet rule), with hostname + script
# name in the message.
send_notification() {
    local message="$1" priority="${2:-1}"
    [[ -f "$PUSHOVER_CONFIG" ]] || return 0
    # shellcheck disable=SC1090
    source "$PUSHOVER_CONFIG"
    [[ -n "${PUSHOVER_TOKEN:-}" && -n "${PUSHOVER_USER:-}" ]] || return 0
    curl -s --max-time 15 \
        --form-string "token=${PUSHOVER_TOKEN}" \
        --form-string "user=${PUSHOVER_USER}" \
        --form-string "title=[${HOSTNAME}] Backup Failed" \
        --form-string "message=${SCRIPT_NAME}: ${message}" \
        --form-string "priority=${priority}" \
        ${DEFAULT_DEVICE:+--form-string "device=${DEFAULT_DEVICE}"} \
        https://api.pushover.net/1/messages.json > /dev/null 2>&1
}

fail() {
    local message="$1"
    log_message "ERROR: $message"
    log_message "=== Staging failed - previous $(basename "$OUT_FILE") left untouched ==="
    send_notification "$message"
    exit 1
}

# database.db and state.json are rewritten by a live z2m, so a plain cp can catch
# a torn write. Rather than stopping the service every night, copy and then check
# what we actually got: database.db is newline-delimited JSON (one object per
# line), state.json a single object. A torn copy fails to parse, and we retry.
validate_copy() {
    local dir="$1"
    python3 - "$dir" <<'PY'
import json, sys, pathlib
d = pathlib.Path(sys.argv[1])

db = d / "database.db"
lines = db.read_text(encoding="utf-8").splitlines()
if not lines:
    sys.exit("database.db is empty")
for n, line in enumerate(lines, 1):
    if not line.strip():
        continue
    try:
        json.loads(line)
    except Exception as e:
        sys.exit(f"database.db line {n} does not parse: {e}")

st = d / "state.json"
try:
    json.loads(st.read_text(encoding="utf-8"))
except Exception as e:
    sys.exit(f"state.json does not parse: {e}")

cb = d / "coordinator_backup.json"
if cb.exists():
    try:
        json.loads(cb.read_text(encoding="utf-8"))
    except Exception as e:
        sys.exit(f"coordinator_backup.json does not parse: {e}")
PY
}

mkdir -p "$OUT_DIR"
log_message "=== Starting zigbee2mqtt state staging ==="

[[ -d "$DATA_DIR" ]] || fail "Data directory $DATA_DIR does not exist"
[[ -f "$BACKUP_KEY" ]] || fail "Encryption key not found: $BACKUP_KEY"

for f in configuration.yaml database.db state.json; do
    [[ -f "$DATA_DIR/$f" ]] || fail "Required file missing: $DATA_DIR/$f"
done

STAGING="$(mktemp -d)" || fail "Could not create staging directory"

attempt=1
while :; do
    rm -rf "${STAGING:?}"/*
    copied=()
    for f in "${FILES[@]}"; do
        if [[ -f "$DATA_DIR/$f" ]]; then
            cp -p "$DATA_DIR/$f" "$STAGING/" || fail "Failed to copy $f"
            copied+=("$f")
        else
            log_message "Note: $f not present in $DATA_DIR, skipping"
        fi
    done

    if validation_error="$(validate_copy "$STAGING" 2>&1)"; then
        log_message "Copied and validated: ${copied[*]}"
        break
    fi

    log_message "WARNING: attempt ${attempt}/${MAX_ATTEMPTS} caught an inconsistent copy: $validation_error"
    if (( attempt >= MAX_ATTEMPTS )); then
        fail "Could not get a consistent copy in ${MAX_ATTEMPTS} attempts: $validation_error"
    fi
    attempt=$(( attempt + 1 ))
    sleep "$RETRY_SLEEP"
done

TMP_OUT="${OUT_FILE}.tmp.$$"
if ! tar cz -C "$STAGING" . \
    | gpg -c --cipher-algo AES256 --batch --yes \
          --passphrase-file "$BACKUP_KEY" -o "$TMP_OUT" 2>/dev/null; then
    rm -f "$TMP_OUT"
    fail "Failed to encrypt the staged data"
fi

if [[ ! -s "$TMP_OUT" ]]; then
    rm -f "$TMP_OUT"
    fail "Encrypted archive came out empty"
fi

chown rsi:rsi "$TMP_OUT"
chmod 600 "$TMP_OUT"
mv -f "$TMP_OUT" "$OUT_FILE" || fail "Failed to move the archive into place"

log_message "Wrote $OUT_FILE ($(stat -c %s "$OUT_FILE") bytes)"
log_message "=== Staging completed successfully ==="
