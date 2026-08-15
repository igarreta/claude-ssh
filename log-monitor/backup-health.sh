#!/bin/bash
# backup-health.sh — deterministic freshness + drift check for BACKUP_A/B and Glacier.
#
# Called from collect.sh, gr-srv03 only (when BACKUP_HEALTH_CHECK=yes in host.conf).
# Prints "none" if there is nothing to report, else one line per problem — same
# convention as the "Failed systemd units" section, so a clean day stays quiet and
# doesn't burn a Haiku/Sonnet call. The arithmetic runs here; the LLM only narrates.
#
# BACKUP_A/B is read from gr-srv03 (the host), never through ceres's LXC bind mount —
# that bind mount going stale while the host mount was fine is exactly the failure mode
# from docs/2026-08-14_ceres-empty-snapshots-probe.md in claude-ssh, and reading through
# it here would reintroduce it. Glacier is read from ceres, which already holds that
# repo's password permanently for its own monthly job (env-usb1-s3.sh) — no new secret
# needed there. gr-srv03 deliberately does NOT keep the local-repo password on disk
# (recovery credentials live in Notion); it's passed inline over SSH from comet's own
# copy (~/etc/restic-password-local) and never written to gr-srv03.
#
# See docs/2026-08-14_backup-health-monitor-design.md in claude-ssh for the full design.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$SCRIPT_DIR/state"
SIZES_CSV="$STATE_DIR/backup-sizes.csv"
SSH_KEY="$HOME/.ssh/id_ed25519_comet"
RESTIC_PW_FILE="$HOME/etc/restic-password-local"

GRSRV_TARGET="root@100.89.202.69"
CERES_TARGET="rsi@100.64.121.121"

FRESH_DAYS_LOCAL=8      # BACKUP_A/B runs nightly
FRESH_DAYS_GLACIER=40   # backup-usb1-s3.sh runs monthly (day 5)
DRIFT_PCT=40            # finding if latest < (100-DRIFT_PCT)% of the rolling median
DRIFT_MIN_SAMPLES=5     # don't judge drift on thin history
DRIFT_LOOKBACK=30       # samples to pull for the median, most recent first

TAGS_LOCAL_JSON='["homeassistant","containers","castor-pg","proxmox-config","vm-images","raspberrypi","gickup"]'

mkdir -p "$STATE_DIR"
[[ -f "$SIZES_CSV" ]] || echo "date,source,tag,bytes" > "$SIZES_CSV"

ssh_grsrv() { ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=20 -o StrictHostKeyChecking=accept-new "$GRSRV_TARGET" "$@"; }
ssh_ceres() { ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=20 -o StrictHostKeyChecking=accept-new "$CERES_TARGET" "$@"; }

findings=()
now_epoch="$(date +%s)"

# Replace any existing row for this (date,source,tag) then append — makes re-runs and
# historical backfill (restic keeps several past snapshots per tag) idempotent.
upsert_row() {
    local date="$1" source="$2" tag="$3" bytes="$4"
    grep -v "^${date},${source},${tag}," "$SIZES_CSV" > "${SIZES_CSV}.tmp" 2>/dev/null || true
    mv "${SIZES_CSV}.tmp" "$SIZES_CSV"
    echo "${date},${source},${tag},${bytes}" >> "$SIZES_CSV"
}

# Median of up to DRIFT_LOOKBACK most recent bytes for (source,tag), excluding today and
# excluding zero-byte rows: no tag legitimately produces 0 bytes, so a 0 here is always
# contamination from a past fault (e.g. the 2026-01-20 -> 2026-08-14 empty-snapshot
# incident, still present in restic's keep-daily window for a couple weeks after the fix),
# never a real sample. Counting it would drag the median down and mask a genuine drift.
median_bytes() {
    local source="$1" tag="$2" today="$3"
    awk -F, -v s="$source" -v t="$tag" -v today="$today" \
        '$2==s && $3==t && $1!=today && $4+0>0 {print $1, $4}' "$SIZES_CSV" \
        | sort -r | head -n "$DRIFT_LOOKBACK" | awk '{print $2}' | sort -n \
        | awk '{a[NR]=$1} END{if(NR==0){print ""; exit} n=NR; if(n%2==1) print a[(n+1)/2]; else print int((a[n/2]+a[n/2+1])/2)}'
}

sample_count() {
    local source="$1" tag="$2" today="$3"
    awk -F, -v s="$source" -v t="$tag" -v today="$today" \
        '$2==s && $3==t && $1!=today && $4+0>0' "$SIZES_CSV" | wc -l
}

evaluate_tag() {
    local source="$1" tag="$2" latest_date="$3" bytes="$4" fresh_days="$5" today="$6"
    local snap_epoch age_days
    snap_epoch="$(date -d "$latest_date" +%s 2>/dev/null)" || return
    age_days=$(( (now_epoch - snap_epoch) / 86400 ))
    if (( age_days > fresh_days )); then
        findings+=("${source} ${tag}: ultimo snapshot hace ${age_days}d (> ${fresh_days}d) - el job dejo de correr o quedo atascado")
    fi

    local n med
    n="$(sample_count "$source" "$tag" "$today")"
    if (( n >= DRIFT_MIN_SAMPLES )); then
        med="$(median_bytes "$source" "$tag" "$today")"
        if [[ -n "$med" && "$med" -gt 0 ]]; then
            local floor_pct=$(( 100 - DRIFT_PCT ))
            local threshold=$(( med / 100 * floor_pct ))
            if (( bytes < threshold )); then
                local pct=$(( 100 - (bytes * 100 / med) ))
                findings+=("${source} ${tag}: ${bytes}B, ${pct}% por debajo de la mediana movil (${med}B, ${n} muestras)")
            fi
        fi
    fi
}

# ---- BACKUP_A/B, from the host ----
disk=""
for d in a b; do
    src="$(ssh_grsrv "findmnt -no SOURCE /mnt/backup_$d" 2>/dev/null)"
    [[ -n "$src" && "$src" == /dev/* ]] && disk="$d" && break
done

if [[ -z "$disk" ]]; then
    : # no disk mounted - normal up to ~48h of rotation, stays silent (comet cannot conclude today)
else
    pw="$(cat "$RESTIC_PW_FILE" 2>/dev/null)"
    if [[ -z "$pw" ]]; then
        findings+=("BACKUP_A/B: ${RESTIC_PW_FILE} no encontrado o vacio en comet")
    else
        json="$(ssh_grsrv "RESTIC_PASSWORD=$(printf '%q' "$pw") restic snapshots --json -r /mnt/backup_$disk/restic-repo" 2>/dev/null)"
        if [[ -z "$json" || "$json" == "null" ]]; then
            findings+=("BACKUP_A/B: no se pudo leer restic-repo en /mnt/backup_$disk desde gr-srv03")
        else
            today="$(date +%F)"
            while IFS=$'\t' read -r sdate tag bytes; do
                [[ -z "$tag" ]] && continue
                upsert_row "$sdate" "BACKUP_${disk^^}" "$tag" "$bytes"
            done < <(echo "$json" | jq -r --argjson allowed "$TAGS_LOCAL_JSON" \
                '.[] | select(.tags[0] as $t | $allowed | index($t)) | [(.time[0:10]), .tags[0], (.summary.total_bytes_processed // 0)] | @tsv')

            while IFS=$'\t' read -r tag ltime bytes; do
                [[ -z "$tag" ]] && continue
                evaluate_tag "BACKUP_${disk^^}" "$tag" "${ltime:0:10}" "$bytes" "$FRESH_DAYS_LOCAL" "$today"
            done < <(echo "$json" | jq -r --argjson allowed "$TAGS_LOCAL_JSON" \
                'group_by(.tags[0]) | map(select(.[0].tags[0] as $t | $allowed | index($t)) | max_by(.time)) | .[] | [.tags[0], .time, (.summary.total_bytes_processed // 0)] | @tsv')
        fi
    fi
fi

# ---- Glacier, from ceres (already holds that repo's password) ----
gjson="$(ssh_ceres "source ~/backup_greven/scripts/env-usb1-s3.sh >/dev/null 2>&1 && restic snapshots --tag usb1-glacier --json -r \"\$RESTIC_REPOSITORY\"" 2>/dev/null)"
if [[ -z "$gjson" || "$gjson" == "null" ]]; then
    findings+=("Glacier: no se pudo leer el repo usb1-glacier desde ceres")
else
    today="$(date +%F)"
    while IFS=$'\t' read -r sdate tag bytes; do
        [[ -z "$tag" ]] && continue
        upsert_row "$sdate" "Glacier" "$tag" "$bytes"
    done < <(echo "$gjson" | jq -r '.[] | [(.time[0:10]), .tags[0], (.summary.total_bytes_processed // 0)] | @tsv')

    while IFS=$'\t' read -r tag ltime bytes; do
        [[ -z "$tag" ]] && continue
        evaluate_tag "Glacier" "$tag" "${ltime:0:10}" "$bytes" "$FRESH_DAYS_GLACIER" "$today"
    done < <(echo "$gjson" | jq -r 'group_by(.tags[0]) | map(max_by(.time)) | .[] | [.tags[0], .time, (.summary.total_bytes_processed // 0)] | @tsv')
fi

if [[ "${#findings[@]}" -eq 0 ]]; then
    echo "none"
else
    printf '%s\n' "${findings[@]}"
fi
