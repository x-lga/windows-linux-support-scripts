# **What ticket this solves:** "The disk is getting full - find out what is taking
# up the space" - when disk space is low, finding the culprit requires knowing which
# directories are largest, which files are biggest, and when they were created.
# This script provides all three views in a single run.

# **Cert alignment:** CompTIA A+

#!/usr/bin/env bash
# =============================================================================
# disk-usage-report.sh
# =============================================================================
# Generates a disk usage report identifying the largest directories and files.
#
# Reports:
#   1. Overall filesystem usage with visual progress bars
#   2. Top 15 largest directories in the specified path
#   3. Top 20 largest individual files in the specified path
#   4. Recently created large files (> 100MB, last 7 days)
#
# Usage:
#   bash disk-usage-report.sh [path] [top_n]
#
# Arguments:
#   path    Root path to analyse (default: /)
#   top_n   How many top entries to show (default: 15)
#
# Examples:
#   bash disk-usage-report.sh
#   bash disk-usage-report.sh /var/log 20
#   bash disk-usage-report.sh /home
#
# Requires  : bash, du, df, find, sort (standard Linux utilities)
# Tested on : Ubuntu 20.04, Ubuntu 22.04, Debian 11
# Cert align: CompTIA A+
# =============================================================================

SEARCH_PATH="${1:-/}"
TOP_N="${2:-15}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME=$(hostname)

# Validate search path
if [ ! -d "$SEARCH_PATH" ]; then
    echo "ERROR: Path does not exist or is not a directory: $SEARCH_PATH"
    exit 1
fi

SEARCH_PATH=$(realpath "$SEARCH_PATH")

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  DISK USAGE REPORT"
echo "  Host: $HOSTNAME | Path: $SEARCH_PATH"
echo "  Generated: $TIMESTAMP"
echo "════════════════════════════════════════════════════════════"
echo ""

# ── Section 1: Overall filesystem usage ──────────────────────────────────
echo "  FILESYSTEM USAGE"
echo "  ──────────────────────────────────────────────────────────"
df -h --output=target,size,used,avail,pcent 2>/dev/null | head -1
df -h --output=target,size,used,avail,pcent 2>/dev/null | tail -n +2 | grep -v '^tmpfs\|^devtmpfs\|^udev' | while read -r mount size used avail pcent; do
    pct_num=$(echo "$pcent" | tr -d '%')
    if [ "$pct_num" -ge 90 ]; then
        echo "  [CRITICAL] $mount — $used / $size ($pcent used, $avail free)"
    elif [ "$pct_num" -ge 80 ]; then
        echo "  [WARNING]  $mount — $used / $size ($pcent used, $avail free)"
    else
        echo "  [OK]       $mount — $used / $size ($pcent used, $avail free)"
    fi
done
echo ""

# ── Section 2: Largest directories ───────────────────────────────────────
echo "  TOP $TOP_N LARGEST DIRECTORIES UNDER: $SEARCH_PATH"
echo "  ──────────────────────────────────────────────────────────"
echo "  (this may take a moment for large filesystems)"
echo ""

du -h "$SEARCH_PATH" \
    --max-depth=4 \
    --exclude="$SEARCH_PATH/proc" \
    --exclude="$SEARCH_PATH/sys" \
    --exclude="$SEARCH_PATH/dev" \
    2>/dev/null | \
    sort -rh | \
    head -n "$TOP_N" | \
    awk '{printf "  %-10s %s\n", $1, $2}'

echo ""

# ── Section 3: Largest individual files ──────────────────────────────────
echo "  TOP 20 LARGEST FILES UNDER: $SEARCH_PATH"
echo "  ──────────────────────────────────────────────────────────"

find "$SEARCH_PATH" \
    -type f \
    -not -path "*/proc/*" \
    -not -path "*/sys/*" \
    -not -path "*/dev/*" \
    -printf '%s\t%p\n' \
    2>/dev/null | \
    sort -rn | \
    head -20 | \
    awk '{
        size=$1;
        path=$2;
        if (size >= 1073741824)
            printf "  %8.1fG  %s\n", size/1073741824, path;
        else if (size >= 1048576)
            printf "  %8.1fM  %s\n", size/1048576, path;
        else if (size >= 1024)
            printf "  %8.1fK  %s\n", size/1024, path;
        else
            printf "  %8dB  %s\n", size, path;
    }'

echo ""

# ── Section 4: Recently created large files ───────────────────────────────
echo "  LARGE FILES CREATED IN THE LAST 7 DAYS (> 100MB)"
echo "  ──────────────────────────────────────────────────────────"

LARGE_RECENT=$(find "$SEARCH_PATH" \
    -type f \
    -mtime -7 \
    -size +100M \
    -not -path "*/proc/*" \
    -not -path "*/sys/*" \
    -not -path "*/dev/*" \
    2>/dev/null | head -20)

if [ -z "$LARGE_RECENT" ]; then
    echo "  No files larger than 100MB created in the last 7 days."
else
    echo "$LARGE_RECENT" | while IFS= read -r f; do
        SIZE=$(du -sh "$f" 2>/dev/null | cut -f1)
        MOD=$(stat -c '%y' "$f" 2>/dev/null | cut -d'.' -f1)
        echo "  [$MOD] $SIZE  $f"
    done
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  END OF DISK USAGE REPORT"
echo "════════════════════════════════════════════════════════════"
echo ""

