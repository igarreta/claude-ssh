#!/bin/bash
# pi-backup.sh - Monthly full Raspberry Pi image backup
# Uses NFS-mounted backup directory and Pushover notifications

set -euo pipefail

# Set explicit PATH for cron environment
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Configuration
BACKUP_ROOT="/mnt/backup"
HOSTNAME=$(hostname)
DATE=$(date +%Y%m%d-%H%M%S)
LOG_FILE="$HOME/bak/backup-pi.log"
TEMP_LOG_FILE="/tmp/backup-pi-$DATE.log"
REQUIRED_SPACE_GB=10
MAX_BACKUPS=3
SCRIPT_NAME="pi-backup.sh"
PUSHOVER_CONFIG="/home/rsi/etc/pushover.env"

# Load Pushover credentials if available
if [[ -f "$PUSHOVER_CONFIG" ]]; then
    source "$PUSHOVER_CONFIG"
fi

# Functions
log_message() {
    local message="$(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo "$message"
    echo "$message" >> "$TEMP_LOG_FILE"
}

send_notification() {
    local message="$1"
    local priority="${2:-0}"

    if [[ -z "$PUSHOVER_TOKEN" ]] || [[ -z "$PUSHOVER_USER" ]]; then
        return 0
    fi

    local full_message="[${HOSTNAME}] ${SCRIPT_NAME}: ${message}"

    curl -s \
        --form-string "token=${PUSHOVER_TOKEN}" \
        --form-string "user=${PUSHOVER_USER}" \
        --form-string "message=${full_message}" \
        --form-string "priority=${priority}" \
        ${DEFAULT_DEVICE:+--form-string "device=${DEFAULT_DEVICE}"} \
        https://api.pushover.net/1/messages.json > /dev/null 2>&1
}

cron_environment_setup() {
    log_message "=== Cron Environment Setup ==="
    cd "$HOME/bin" 2>/dev/null || cd /home/rsi/bin
    if [[ -z "${TZ:-}" ]]; then
        export TZ="America/Buenos_Aires"
        log_message "Set timezone: $TZ"
    fi
    log_message "Cron environment setup completed"
}

check_backup_accessibility() {
    log_message "Checking /mnt/backup accessibility..."
    if [[ ! -d "$BACKUP_ROOT" ]]; then
        local error_msg="Backup directory $BACKUP_ROOT does not exist"
        log_message "ERROR: $error_msg"
        send_notification "$error_msg" 1
        return 1
    fi
    if ! touch "$BACKUP_ROOT/.write_test" 2>/dev/null; then
        local error_msg="Backup directory $BACKUP_ROOT is not writable"
        log_message "ERROR: $error_msg"
        send_notification "$error_msg" 1
        return 1
    fi
    rm -f "$BACKUP_ROOT/.write_test"
    log_message "Backup directory is accessible and writable"
    return 0
}

cleanup_and_exit() {
    local exit_code=$1
    local cleanup_reason="${2:-normal}"
    log_message "=== Cleanup and Exit (code: $exit_code, reason: $cleanup_reason) ==="
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    if [[ -f "$TEMP_LOG_FILE" ]]; then
        cat "$TEMP_LOG_FILE" >> "$LOG_FILE" 2>/dev/null || true
    fi
    if [[ $exit_code -eq 0 ]]; then
        rm -f "$TEMP_LOG_FILE"
    else
        log_message "Backup failed - preserving logs for debugging:"
        log_message "  Temp log: $TEMP_LOG_FILE"
        log_message "  Final log: $LOG_FILE"
    fi
    exit $exit_code
}

check_prerequisites() {
    log_message "=== Prerequisites Check ==="
    local missing_tools=()
    for tool in dd gzip sha256sum; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        local error_msg="Missing required tools: ${missing_tools[*]}"
        log_message "ERROR: $error_msg"
        send_notification "$error_msg" 1
        return 1
    fi
    log_message "Prerequisites check passed"
    return 0
}

check_available_space() {
    log_message "=== Space Check ==="
    local available_kb=$(df "$BACKUP_ROOT" | tail -1 | awk '{print $4}')
    local available_gb=$((available_kb / 1024 / 1024))
    local required_kb=$((REQUIRED_SPACE_GB * 1024 * 1024))
    log_message "Available space: ${available_gb}GB (Required: ${REQUIRED_SPACE_GB}GB)"
    if [[ $available_kb -lt $required_kb ]]; then
        local error_msg="Insufficient space. Available: ${available_gb}GB, Required: ${REQUIRED_SPACE_GB}GB"
        log_message "ERROR: $error_msg"
        send_notification "$error_msg" 1
        return 1
    fi
    log_message "Space check passed: ${available_gb}GB available"
    return 0
}

create_backup() {
    local final_img="$BACKUP_ROOT/images/$HOSTNAME-$DATE.img.gz"
    mkdir -p "$BACKUP_ROOT/images"
    log_message "Starting disk image backup (direct compression method)"
    log_message "Target: $final_img"
    if sudo dd if=/dev/mmcblk0 bs=4M status=progress 2>>"$TEMP_LOG_FILE" | gzip -c > "$final_img"; then
        log_message "Direct compressed backup completed"
        local final_size=$(stat -c%s "$final_img")
        local final_size_gb=$((final_size / 1024 / 1024 / 1024))
        log_message "Backup size: $((final_size / 1024 / 1024))MB (${final_size_gb}GB)"
        log_message "Creating integrity checksum..."
        sha256sum "$final_img" > "$final_img.sha256"
        return 0
    else
        local error_msg="Backup creation failed"
        log_message "ERROR: $error_msg"
        send_notification "$error_msg" 1
        rm -f "$final_img" "$final_img.sha256"
        return 1
    fi
}

cleanup_old_backups() {
    log_message "=== Cleanup Old Backups (keeping $MAX_BACKUPS most recent) ==="
    local old_backups=$(ls -t "$BACKUP_ROOT/images/$HOSTNAME-"*.img.gz 2>/dev/null | tail -n +$((MAX_BACKUPS + 1)))
    if [ -n "$old_backups" ]; then
        echo "$old_backups" | while read -r file; do
            log_message "Removing old backup: $(basename "$file")"
            rm -f "$file" "${file}.sha256"
        done
        log_message "Deleted old backup(s)"
    else
        log_message "No old backups to clean up"
    fi
}

# Main execution
trap 'cleanup_and_exit 1 "error_trap"' ERR

log_message "=== Starting Raspberry Pi Backup ==="
log_message "Script started at: $(date)"
log_message "Process ID: $$"

cron_environment_setup
check_prerequisites
check_backup_accessibility
check_available_space
create_backup
cleanup_old_backups

send_notification "Monthly backup completed successfully" -1
log_message "=== Backup completed successfully ==="
cleanup_and_exit 0 "success"
