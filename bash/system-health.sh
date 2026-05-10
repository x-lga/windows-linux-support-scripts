# **What ticket this solves:** "The server seems slow" - a Linux system health
# report provides uptime, CPU load averages, memory usage, disk space, network
# interface status, and the top CPU-consuming processes in a single run. Essential
# for any Linux server support session.

# **Cert alignment:** CompTIA A+, CompTIA Network+

#!/usr/bin/env bash
# =============================================================================
# system-health.sh
# =============================================================================
# Generates a comprehensive Linux system health report.
#
# Reports:
#   - Uptime and load averages
#   - CPU core count
#   - Memory usage (total, used, free, buffers/cache)
#   - Swap usage
#   - Disk space for all mounted filesystems (warns at thresholds)
#   - Network interface status and IP addresses
#   - Top 10 processes by CPU usage
#   - Top 10 processes by memory usage
#   - Last 5 kernel/system messages from syslog
#
# Usage:
#   bash system-health.sh
#   bash system-health.sh -w 80 -c 90      (custom thresholds)
#
# Options:
#   -w PERCENT   Disk warning threshold (default: 80%)
#   -c PERCENT   Disk critical threshold (default: 90%)
#   -o FILE      Save output to file in addition to stdout
#
# Requires  : bash, awk, df, free, ip, ps, top (standard Linux utilities)
# Tested on : Ubuntu 20.04, Ubuntu 22.04, Debian 11, CentOS 8
# Cert align: CompTIA A+, CompTIA Network+
# =============================================================================

# ── Default settings ──────────────────────────────────────────────────────
WARN_THRESHOLD=80
CRIT_THRESHOLD=90
OUTPUT_FILE=""

# ── Colour codes ──────────────────────────────────────────────────────────
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
BOLD='\033[1m'
NC='\033[0m' # No Colour

# ── Parse arguments ───────────────────────────────────────────────────────
while getopts "w:c:o:" opt; do
    case $opt in
        w) WARN_THRESHOLD="$OPTARG" ;;
        c) CRIT_THRESHOLD="$OPTARG" ;;
        o) OUTPUT_FILE="$OPTARG" ;;
        *) echo "Usage: $0 [-w warn_pct] [-c crit_pct] [-o output_file]"; exit 1 ;;
    esac
done

# Validate threshold relationship
if [ "$CRIT_THRESHOLD" -le "$WARN_THRESHOLD" ]; then
    echo "ERROR: Critical threshold ($CRIT_THRESHOLD%) must be greater than warning ($WARN_THRESHOLD%)."
    exit 1
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME=$(hostname -f 2>/dev/null || hostname)
SEPARATOR="═══════════════════════════════════════════════════════════"
SUBSEP="───────────────────────────────────────────────────────────"

# ── Output function — print to stdout and optionally to file ──────────────
output() {
    echo -e "$1"
    if [ -n "$OUTPUT_FILE" ]; then
        # Strip colour codes when writing to file
        echo -e "$1" | sed 's/\x1b\[[0-9;]*m//g' >> "$OUTPUT_FILE"
    fi
}

# Initialise output file if specified
if [ -n "$OUTPUT_FILE" ]; then
    > "$OUTPUT_FILE"
fi

# ── Header ────────────────────────────────────────────────────────────────
output ""
output "${CYAN}${SEPARATOR}${NC}"
output "${CYAN}${BOLD}  LINUX SYSTEM HEALTH REPORT${NC}"
output "${CYAN}  Hostname  : ${HOSTNAME}${NC}"
output "${CYAN}  Generated : ${TIMESTAMP}${NC}"
output "${CYAN}  Thresholds: Warning ${WARN_THRESHOLD}% | Critical ${CRIT_THRESHOLD}%${NC}"
output "${CYAN}${SEPARATOR}${NC}"
output ""

# ── Section 1: Uptime and Load ────────────────────────────────────────────
output "${YELLOW}  UPTIME AND LOAD AVERAGES${NC}"
output "  ${SUBSEP}"

UPTIME_INFO=$(uptime)
UPTIME_CLEAN=$(echo "$UPTIME_INFO" | sed 's/^ *//')
output "  ${UPTIME_CLEAN}"

# Parse load averages
LOAD_1=$(cat /proc/loadavg | awk '{print $1}')
LOAD_5=$(cat /proc/loadavg | awk '{print $2}')
LOAD_15=$(cat /proc/loadavg | awk '{print $3}')
CPU_CORES=$(nproc)

output ""
output "  Load average  : ${LOAD_1} (1m) / ${LOAD_5} (5m) / ${LOAD_15} (15m)"
output "  CPU cores     : ${CPU_CORES}"

# Warn if load is high relative to core count
LOAD_PCT=$(echo "$LOAD_1 $CPU_CORES" | awk '{printf "%.0f", ($1/$2)*100}')
if [ "$LOAD_PCT" -gt 100 ]; then
    output ""
    output "  ${RED}⚠ CPU load is above 100% of capacity (${LOAD_1} on ${CPU_CORES} cores).${NC}"
    output "  ${RED}  Check top 10 processes section below for the cause.${NC}"
elif [ "$LOAD_PCT" -gt 80 ]; then
    output ""
    output "  ${YELLOW}⚠ CPU load is elevated (${LOAD_PCT}% of capacity). Monitor closely.${NC}"
fi
output ""

# ── Section 2: Memory ─────────────────────────────────────────────────────
output "${YELLOW}  MEMORY USAGE${NC}"
output "  ${SUBSEP}"

free -h | awk '
NR==1 { printf "  %-15s %8s %8s %8s %8s\n", $1, $2, $3, $4, $6 }
NR==2 { printf "  %-15s %8s %8s %8s %8s\n", $1, $2, $3, $4, $6 }
NR==3 { printf "  %-15s %8s %8s %8s\n", $1, $2, $3, $4 }
' | while IFS= read -r line; do output "  $line"; done

# Memory percentage used
MEM_TOTAL=$(free | awk 'NR==2{print $2}')
MEM_USED=$(free | awk 'NR==2{print $3}')
if [ "$MEM_TOTAL" -gt 0 ]; then
    MEM_PCT=$(echo "$MEM_USED $MEM_TOTAL" | awk '{printf "%.0f", ($1/$2)*100}')
    if [ "$MEM_PCT" -gt 90 ]; then
        output ""
        output "  ${RED}⚠ Memory usage is critical (${MEM_PCT}%). Application crashes may occur.${NC}"
    elif [ "$MEM_PCT" -gt 80 ]; then
        output ""
        output "  ${YELLOW}⚠ Memory usage is high (${MEM_PCT}%). Monitor closely.${NC}"
    fi
fi
output ""

# ── Section 3: Disk Space ─────────────────────────────────────────────────
output "${YELLOW}  DISK SPACE${NC}"
output "  ${SUBSEP}"

# Header
output "  $(printf '%-30s %8s %8s %8s %6s %s' 'Filesystem' 'Size' 'Used' 'Avail' 'Use%' 'Status')"

# Process each filesystem
df -h --output=source,size,used,avail,pcent,target 2>/dev/null | tail -n +2 | while read -r source size used avail pcent target; do
    # Skip tmpfs and special filesystems for clarity
    case "$source" in
        tmpfs|devtmpfs|udev|none|cgroup*|sys*|proc*) continue ;;
    esac

    # Extract numeric percentage
    PCT_NUM=$(echo "$pcent" | tr -d '%')

    # Determine status and colour
    if [ "$PCT_NUM" -ge "$CRIT_THRESHOLD" ]; then
        STATUS="CRITICAL"
        COLOUR="$RED"
    elif [ "$PCT_NUM" -ge "$WARN_THRESHOLD" ]; then
        STATUS="WARNING"
        COLOUR="$YELLOW"
    else
        STATUS="OK"
        COLOUR="$GREEN"
    fi

    output "  ${COLOUR}$(printf '%-30s %8s %8s %8s %6s %s' "$target" "$size" "$used" "$avail" "$pcent" "$STATUS")${NC}"
done
output ""

# ── Section 4: Network Interfaces ────────────────────────────────────────
output "${YELLOW}  NETWORK INTERFACES${NC}"
output "  ${SUBSEP}"

ip -br addr show 2>/dev/null | while read -r iface state addrs; do
    if [ "$state" = "UP" ]; then
        STATE_COLOUR="$GREEN"
    else
        STATE_COLOUR="$RED"
    fi
    output "  ${STATE_COLOUR}$(printf '%-15s %-10s %s' "$iface" "$state" "$addrs")${NC}"
done
output ""

# Default gateway
DEFAULT_GW=$(ip route show default 2>/dev/null | awk '/default/{print $3}' | head -1)
if [ -n "$DEFAULT_GW" ]; then
    output "  Default gateway : ${DEFAULT_GW}"
fi

# DNS servers
if [ -f /etc/resolv.conf ]; then
    DNS_SERVERS=$(grep '^nameserver' /etc/resolv.conf | awk '{print $2}' | tr '\n' ' ')
    output "  DNS servers     : ${DNS_SERVERS}"
fi
output ""

# ── Section 5: Top 10 Processes by CPU ───────────────────────────────────
output "${YELLOW}  TOP 10 PROCESSES BY CPU USAGE${NC}"
output "  ${SUBSEP}"

output "  $(printf '%-8s %-25s %6s %8s %s' 'PID' 'Process' 'CPU%' 'MEM(MB)' 'User')"
ps aux --sort=-%cpu 2>/dev/null | awk 'NR>1 && NR<=11 {
    pid=$2; cpu=$3; mem_pct=$4; vsz=$5; rss=$6; user=$1; cmd=$11;
    mem_mb=int(rss/1024);
    # Truncate long command names
    if (length(cmd) > 24) cmd=substr(cmd,1,21)"...";
    printf "  %-8s %-25s %6s %8d %s\n", pid, cmd, cpu, mem_mb, user
}' | while IFS= read -r line; do output "$line"; done
output ""

# ── Section 6: Top 10 Processes by Memory ────────────────────────────────
output "${YELLOW}  TOP 10 PROCESSES BY MEMORY USAGE${NC}"
output "  ${SUBSEP}"

output "  $(printf '%-8s %-25s %8s %6s %s' 'PID' 'Process' 'MEM(MB)' 'MEM%' 'User')"
ps aux --sort=-%mem 2>/dev/null | awk 'NR>1 && NR<=11 {
    pid=$2; cpu=$3; mem_pct=$4; rss=$6; user=$1; cmd=$11;
    mem_mb=int(rss/1024);
    if (length(cmd) > 24) cmd=substr(cmd,1,21)"...";
    printf "  %-8s %-25s %8d %6s %s\n", pid, cmd, mem_mb, mem_pct, user
}' | while IFS= read -r line; do output "$line"; done
output ""

# ── Section 7: Recent System Messages ────────────────────────────────────
output "${YELLOW}  RECENT SYSTEM MESSAGES (last 10)${NC}"
output "  ${SUBSEP}"

if command -v journalctl &> /dev/null; then
    # systemd-based systems
    journalctl -p err..crit --no-pager -n 10 --output=short 2>/dev/null |
    while IFS= read -r line; do output "  ${RED}${line}${NC}"; done
elif [ -f /var/log/syslog ]; then
    tail -20 /var/log/syslog 2>/dev/null |
    grep -i "error\|critical\|fail" | tail -10 |
    while IFS= read -r line; do output "  ${RED}${line}${NC}"; done
elif [ -f /var/log/messages ]; then
    tail -20 /var/log/messages 2>/dev/null |
    grep -i "error\|critical\|fail" | tail -10 |
    while IFS= read -r line; do output "  ${RED}${line}${NC}"; done
else
    output "  No accessible system log found."
fi
output ""

# ── Footer ────────────────────────────────────────────────────────────────
output "${CYAN}${SEPARATOR}${NC}"
output "${CYAN}  END OF REPORT${NC}"
output "${CYAN}${SEPARATOR}${NC}"
output ""

if [ -n "$OUTPUT_FILE" ]; then
    echo "Report saved to: $OUTPUT_FILE"
fi



