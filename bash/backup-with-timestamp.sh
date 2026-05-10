# **What ticket this solves:** "We need a backup of this directory before we make
# changes" - every IT professional needs a reliable way to create a timestamped
# backup before system modifications. This script creates a compressed, timestamped
# archive of any directory, logs the action, and automatically removes backups older
# than the configured retention period.

# **Cert alignment:** CompTIA A+

#!/usr/bin/env bash
# =============================================================================
# backup-with-timestamp.sh
# =============================================================================
# Creates a timestamped compressed backup of a specified directory.
#
# Features:
#   - Timestamped archive name: backup_YYYYMMDD_HHMMSS.tar.gz
#   - Validates source directory exists before starting
#   - Calculates and reports final archive size
#   - Logs all actions to a persistent log file
#   - Automatically removes backups older than RETENTION_DAYS
#   - Reports count of files backed up and compression ratio
#   - Exit codes: 0 = success, 1 = source not found, 2 = backup failed
#
# Usage:
#   bash backup-with-timestamp.sh <source_dir> [backup_dir] [retention_days]
#
# Arguments:
#   source_dir      Directory to back up (required)
#   backup_dir      Where to store backups (default: /var/backups)
#   retention_days  Days to keep old backups (default: 7)
#
# Examples:
#   bash backup-with-timestamp.sh /etc
#   bash backup-with-timestamp.sh /var/www/html /mnt/backups 14
#   bash backup-with-timestamp.sh /home/user/documents ~/backups 30
#
# Cron example (daily at 2am):
#   0 2 * * * /usr/local/bin/backup-with-timestamp.sh /etc /var/backups/etc 30
#
# Requires  : bash, tar, gzip, find (standard Linux utilities)
# Tested on : Ubuntu 20.04, Ubuntu 22.04, Debian 11
# Cert align: CompTIA A+
# =============================================================================

# ── Arguments ─────────────────────────────────────────────────────────────
SOURCE_DIR="${1}"
BACKUP_ROOT="${2:-/var/backups}"
RETENTION_DAYS="${3:-7}"

# ── Configuration ─────────────────────────────────────────────────────────
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
DATE_READABLE=$(date '+%Y-%m-%d %H:%M:%S')

# Sanitise source directory name for use in archive name (replace / with _)
SOURCE_BASENAME=$(echo "$SOURCE_DIR" | tr '/' '_' | sed 's/^_//')
BACKUP_NAME="backup_${SOURCE_BASENAME}_${TIMESTAMP}.tar.gz"
BACKUP_PATH="${BACKUP_ROOT}/${BACKUP_NAME}"
LOG_FILE="${BACKUP_ROOT}/backup.log"

# ── Logging function ──────────────────────────────────────────────────────
log() {
    local level="$1"
    local message="$2"
    local entry="[${DATE_READABLE}] [${level}] ${message}"
    echo "$entry"
    echo "$entry" >> "$LOG_FILE" 2>/dev/null || true
}

# ── Validate arguments ────────────────────────────────────────────────────
if [ -z "$SOURCE_DIR" ]; then
    echo "ERROR: Source directory is required."
    echo "Usage: $0 <source_dir> [backup_dir] [retention_days]"
    echo "Example: $0 /etc /var/backups 7"
    exit 1
fi

# Validate retention days is a number
if ! [[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]]; then
    echo "ERROR: retention_days must be a positive integer. Got: '$RETENTION_DAYS'"
    exit 1
fi

# ── Validate source directory ─────────────────────────────────────────────
if [ ! -d "$SOURCE_DIR" ]; then
    log "ERROR" "Source directory does not exist: $SOURCE_DIR"
    exit 1
fi

# Resolve absolute path
SOURCE_DIR=$(realpath "$SOURCE_DIR")

# ── Create backup directory ───────────────────────────────────────────────
if [ ! -d "$BACKUP_ROOT" ]; then
    if ! mkdir -p "$BACKUP_ROOT" 2>/dev/null; then
        log "ERROR" "Cannot create backup directory: $BACKUP_ROOT"
        exit 1
    fi
    log "INFO" "Created backup directory: $BACKUP_ROOT"
fi

# ── Calculate source size ─────────────────────────────────────────────────
SOURCE_SIZE=$(du -sh "$SOURCE_DIR" 2>/dev/null | cut -f1)
FILE_COUNT=$(find "$SOURCE_DIR" -type f 2>/dev/null | wc -l)

log "INFO" "Backup started"
log "INFO" "Source      : $SOURCE_DIR ($SOURCE_SIZE, $FILE_COUNT files)"
log "INFO" "Destination : $BACKUP_PATH"
log "INFO" "Retention   : $RETENTION_DAYS days"

echo ""
echo "════════════════════════════════════════════════"
echo "  BACKUP STARTING"
echo "════════════════════════════════════════════════"
echo "  Source      : $SOURCE_DIR"
echo "  Destination : $BACKUP_PATH"
echo "  Files found : $FILE_COUNT"
echo "  Source size : $SOURCE_SIZE"
echo "────────────────────────────────────────────────"
echo ""

# ── Create the backup ─────────────────────────────────────────────────────
echo "Creating compressed archive..."

# --exclude common patterns that should not be backed up
tar --exclude='*.tmp' \
    --exclude='*.log' \
    --exclude='__pycache__' \
    --exclude='.git' \
    --exclude='node_modules' \
    -czf "$BACKUP_PATH" \
    "$SOURCE_DIR" \
    2>/dev/null

TAR_EXIT=$?

if [ $TAR_EXIT -ne 0 ]; then
    log "ERROR" "tar command failed with exit code $TAR_EXIT"
    # Clean up partial backup file if it exists
    [ -f "$BACKUP_PATH" ] && rm -f "$BACKUP_PATH"
    echo "ERROR: Backup creation failed. Check that you have read access to $SOURCE_DIR"
    exit 2
fi

# ── Verify the backup ─────────────────────────────────────────────────────
if [ ! -f "$BACKUP_PATH" ]; then
    log "ERROR" "Backup file was not created: $BACKUP_PATH"
    exit 2
fi

ARCHIVE_SIZE=$(du -sh "$BACKUP_PATH" 2>/dev/null | cut -f1)
ARCHIVE_BYTES=$(stat -f%z "$BACKUP_PATH" 2>/dev/null || stat -c%s "$BACKUP_PATH" 2>/dev/null || echo "0")

log "SUCCESS" "Backup created: $BACKUP_NAME ($ARCHIVE_SIZE)"

echo ""
echo "Backup created successfully."
echo "  Archive name : $BACKUP_NAME"
echo "  Archive size : $ARCHIVE_SIZE"
echo ""

# ── Verify archive integrity ──────────────────────────────────────────────
echo "Verifying archive integrity..."
if tar -tzf "$BACKUP_PATH" > /dev/null 2>&1; then
    ARCHIVED_FILES=$(tar -tzf "$BACKUP_PATH" 2>/dev/null | grep -v '/$' | wc -l)
    log "INFO" "Archive integrity verified. Contains $ARCHIVED_FILES files."
    echo "  Archive verified: $ARCHIVED_FILES files confirmed readable."
else
    log "ERROR" "Archive integrity check failed: $BACKUP_PATH"
    echo "ERROR: Archive integrity check failed. The backup may be corrupt."
    exit 2
fi

# ── Remove old backups ────────────────────────────────────────────────────
echo ""
echo "Cleaning up backups older than $RETENTION_DAYS days..."

OLD_BACKUPS=$(find "$BACKUP_ROOT" \
    -name "backup_*.tar.gz" \
    -mtime +"$RETENTION_DAYS" \
    2>/dev/null)

if [ -n "$OLD_BACKUPS" ]; then
    DELETED_COUNT=0
    while IFS= read -r old_file; do
        OLD_NAME=$(basename "$old_file")
        rm -f "$old_file"
        log "INFO" "Deleted old backup: $OLD_NAME"
        DELETED_COUNT=$((DELETED_COUNT + 1))
    done <<< "$OLD_BACKUPS"
    echo "  Deleted $DELETED_COUNT old backup(s) (older than $RETENTION_DAYS days)."
else
    echo "  No old backups to remove."
fi

# ── Summary ───────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════"
echo "  BACKUP COMPLETE"
echo "────────────────────────────────────────────────"
echo "  Archive     : $BACKUP_PATH"
echo "  Size        : $ARCHIVE_SIZE"
echo "  Files       : $ARCHIVED_FILES"
echo "  Retention   : $RETENTION_DAYS days"
echo "  Log         : $LOG_FILE"
echo "════════════════════════════════════════════════"
echo ""

log "INFO" "Backup job completed successfully."
exit 0
