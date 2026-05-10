# **What ticket this solves:** Linux servers accumulate log files in `/var/log` and
# application-specific log directories. Without maintenance, these grow to fill the
# disk and cause service failures. This script automates the cleanup - moving old
# logs to an archive directory, compressing them, and deleting archives older than
# the configured retention period.

# **Cert alignment:** CompTIA A+

#!/usr/bin/env bash
# =============================================================================
# log-cleanup.sh
# =============================================================================
# Cleans up old log files by archiving and compressing them, then removing
# archives older than the configured retention period.
#
# Process:
#   1. Find log files older than AGE_DAYS in LOG_DIR
#   2. Move them to ARCHIVE_DIR (preserving file names)
#   3. Compress any uncompressed archives in ARCHIVE_DIR with gzip
#   4. Delete archives in ARCHIVE_DIR older than RETENTION_DAYS
#   5. Report all actions to a cleanup log
#
# Usage:
#   bash log-cleanup.sh [options]
#
# Options:
#   -l DIR     Log directory to clean (default: /var/log)
#   -a DIR     Archive directory (default: /var/log/archive)
#   -d DAYS    Age in days to archive logs (default: 7)
#   -r DAYS    Retention days for archives before deletion (default: 30)
#   -p PATTERN File pattern to match (default: *.log)
#   -n         Dry run — show what would be done without doing it
#
# Examples:
#   bash log-cleanup.sh
#   bash log-cleanup.sh -l /var/log/nginx -d 3 -r 14
#   bash log-cleanup.sh -l /opt/myapp/logs -p "*.log *.out" -n
#
# Cron example (weekly Sunday at 3am):
#   0 3 * * 0 /usr/local/bin/log-cleanup.sh -l /var/log -d 7 -r 30
#
# Requires  : bash, find, gzip, mv (standard Linux utilities)
# Tested on : Ubuntu 20.04, Ubuntu 22.04, Debian 11
# Cert align: CompTIA A+
# =============================================================================

# ── Defaults ─────────────────────────────────────────────────────────────
LOG_DIR="/var/log"
ARCHIVE_DIR="/var/log/archive"
AGE_DAYS=7
RETENTION_DAYS=30
FILE_PATTERN="*.log"
DRY_RUN=false
CLEANUP_LOG="/var/log/log-cleanup.log"

# ── Parse arguments ───────────────────────────────────────────────────────
while getopts "l:a:d:r:p:n" opt; do
    case $opt in
        l) LOG_DIR="$OPTARG" ;;
        a) ARCHIVE_DIR="$OPTARG" ;;
        d) AGE_DAYS="$OPTARG" ;;
        r) RETENTION_DAYS="$OPTARG" ;;
        p) FILE_PATTERN="$OPTARG" ;;
        n) DRY_RUN=true ;;
        *) echo "Usage: $0 [-l log_dir] [-a archive_dir] [-d age_days] [-r retention_days] [-p pattern] [-n]"
           exit 1 ;;
    esac
done

# ── Logging ───────────────────────────────────────────────────────────────
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local prefix=""
    if $DRY_RUN; then prefix="[DRY-RUN] "; fi
    local entry="[$timestamp] [$level] ${prefix}${message}"
    echo "$entry"
    echo "$entry" >> "$CLEANUP_LOG" 2>/dev/null || true
}

# ── Validation ────────────────────────────────────────────────────────────
if [ ! -d "$LOG_DIR" ]; then
    echo "ERROR: Log directory does not exist: $LOG_DIR"
    exit 1
fi

if ! [[ "$AGE_DAYS" =~ ^[0-9]+$ ]] || [ "$AGE_DAYS" -lt 1 ]; then
    echo "ERROR: AGE_DAYS must be a positive integer. Got: '$AGE_DAYS'"
    exit 1
fi

if ! [[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]] || [ "$RETENTION_DAYS" -lt 1 ]; then
    echo "ERROR: RETENTION_DAYS must be a positive integer. Got: '$RETENTION_DAYS'"
    exit 1
fi

# ── Create archive directory ──────────────────────────────────────────────
if [ ! -d "$ARCHIVE_DIR" ]; then
    if $DRY_RUN; then
        echo "[DRY-RUN] Would create archive directory: $ARCHIVE_DIR"
    else
        if ! mkdir -p "$ARCHIVE_DIR"; then
            log "ERROR" "Cannot create archive directory: $ARCHIVE_DIR"
            exit 1
        fi
        log "INFO" "Created archive directory: $ARCHIVE_DIR"
    fi
fi

# ── Header ────────────────────────────────────────────────────────────────
DRYRUN_NOTE=""
if $DRY_RUN; then DRYRUN_NOTE=" [DRY RUN — no changes will be made]"; fi

log "INFO" "Log cleanup started${DRYRUN_NOTE}"
log "INFO" "Log directory   : $LOG_DIR"
log "INFO" "Archive dir     : $ARCHIVE_DIR"
log "INFO" "Archive files > : $AGE_DAYS days old"
log "INFO" "Delete archives > $RETENTION_DAYS days old"
log "INFO" "File pattern    : $FILE_PATTERN"
echo ""

# ── Step 1: Archive old log files ─────────────────────────────────────────
echo "Step 1: Finding log files older than $AGE_DAYS days..."

ARCHIVED_COUNT=0
ARCHIVED_BYTES=0

# Find matching files older than AGE_DAYS (only in LOG_DIR, not recursive into ARCHIVE_DIR)
find "$LOG_DIR" \
    -maxdepth 1 \
    -name "$FILE_PATTERN" \
    -mtime +"$AGE_DAYS" \
    -type f \
    2>/dev/null | while IFS= read -r log_file; do

    FILE_NAME=$(basename "$log_file")
    DEST_PATH="$ARCHIVE_DIR/$FILE_NAME"
    FILE_SIZE=$(du -sh "$log_file" 2>/dev/null | cut -f1)

    if $DRY_RUN; then
        echo "  [DRY-RUN] Would archive: $FILE_NAME ($FILE_SIZE)"
    else
        if mv "$log_file" "$DEST_PATH" 2>/dev/null; then
            log "INFO" "Archived: $FILE_NAME ($FILE_SIZE) → $ARCHIVE_DIR/"
            ARCHIVED_COUNT=$((ARCHIVED_COUNT + 1))
        else
            log "ERROR" "Failed to archive: $log_file"
        fi
    fi
done

echo ""

# ── Step 2: Compress uncompressed archives ────────────────────────────────
echo "Step 2: Compressing uncompressed archives..."

COMPRESSED_COUNT=0

find "$ARCHIVE_DIR" \
    -maxdepth 1 \
    -name "$FILE_PATTERN" \
    -not -name "*.gz" \
    -not -name "*.bz2" \
    -not -name "*.xz" \
    -type f \
    2>/dev/null | while IFS= read -r archive_file; do

    FILE_NAME=$(basename "$archive_file")
    SIZE_BEFORE=$(du -sh "$archive_file" 2>/dev/null | cut -f1)

    if $DRY_RUN; then
        echo "  [DRY-RUN] Would compress: $FILE_NAME ($SIZE_BEFORE)"
    else
        if gzip -f "$archive_file" 2>/dev/null; then
            SIZE_AFTER=$(du -sh "${archive_file}.gz" 2>/dev/null | cut -f1)
            log "INFO" "Compressed: $FILE_NAME ($SIZE_BEFORE → $SIZE_AFTER)"
            COMPRESSED_COUNT=$((COMPRESSED_COUNT + 1))
        else
            log "ERROR" "Failed to compress: $archive_file"
        fi
    fi
done

echo ""

# ── Step 3: Delete old archives ───────────────────────────────────────────
echo "Step 3: Removing archives older than $RETENTION_DAYS days..."

DELETED_COUNT=0
DELETED_BYTES=0

find "$ARCHIVE_DIR" \
    -maxdepth 1 \
    -type f \
    -mtime +"$RETENTION_DAYS" \
    2>/dev/null | while IFS= read -r old_archive; do

    FILE_NAME=$(basename "$old_archive")
    FILE_SIZE=$(du -sh "$old_archive" 2>/dev/null | cut -f1)
    FILE_AGE=$(( ($(date +%s) - $(stat -c %Y "$old_archive" 2>/dev/null || echo 0)) / 86400 ))

    if $DRY_RUN; then
        echo "  [DRY-RUN] Would delete: $FILE_NAME ($FILE_SIZE, ${FILE_AGE}d old)"
    else
        if rm -f "$old_archive" 2>/dev/null; then
            log "INFO" "Deleted archive: $FILE_NAME ($FILE_SIZE, ${FILE_AGE}d old)"
            DELETED_COUNT=$((DELETED_COUNT + 1))
        else
            log "ERROR" "Failed to delete: $old_archive"
        fi
    fi
done

echo ""

# ── Report archive directory status ──────────────────────────────────────
echo "Current archive directory status:"
ARCHIVE_SIZE=$(du -sh "$ARCHIVE_DIR" 2>/dev/null | cut -f1)
ARCHIVE_COUNT=$(find "$ARCHIVE_DIR" -maxdepth 1 -type f 2>/dev/null | wc -l)
echo "  Path       : $ARCHIVE_DIR"
echo "  Files      : $ARCHIVE_COUNT"
echo "  Total size : $ARCHIVE_SIZE"
echo ""

# ── Footer ────────────────────────────────────────────────────────────────
log "INFO" "Log cleanup completed${DRYRUN_NOTE}. Log: $CLEANUP_LOG"
echo "Cleanup log: $CLEANUP_LOG"
echo ""
exit 0
