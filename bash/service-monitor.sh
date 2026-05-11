# **What ticket this solves:** "Is [service] running?" on a Linux server - checking
# whether critical services are active, restarting them if they have stopped, and
# logging the result. This is a common NOC and monitoring task that is also useful
# as a cron-based watchdog script.

# **Cert alignment:** CompTIA A+, CompTIA Network+

#!/usr/bin/env bash
# =============================================================================
# service-monitor.sh
# =============================================================================
# Checks the status of one or more Linux services, attempts restart if stopped,
# and logs the result.
#
# Modes:
#   1. Check mode (default):
#      Reports the status of each service — running, stopped, or not found.
#
#   2. Auto-restart mode (-r flag):
#      If a service is stopped, attempts to restart it and logs the result.
#      Suitable for use as a cron watchdog.
#
# Usage:
#   bash service-monitor.sh <service1> [service2] [service3] ...
#   bash service-monitor.sh -r <service1> [service2] ...
#
# Examples:
#   bash service-monitor.sh nginx ssh cron ufw
#   bash service-monitor.sh -r nginx mysql     (restart stopped services)
#
# Cron watchdog example (check every 5 minutes):
#   */5 * * * * /usr/local/bin/service-monitor.sh -r nginx mysql ssh
#
# Exit codes:
#   0 = all services running (or successfully restarted)
#   1 = one or more services failed or could not be restarted
#
# Requires  : bash, systemctl (systemd-based systems)
# Tested on : Ubuntu 20.04, Ubuntu 22.04, Debian 11
# Cert align: CompTIA A+, CompTIA Network+
# =============================================================================

# ── Settings ─────────────────────────────────────────────────────────────
LOG_DIR="/var/log"
LOG_FILE="$LOG_DIR/service-monitor.log"
AUTO_RESTART=false

# ── Parse arguments ───────────────────────────────────────────────────────
if [ "$1" = "-r" ]; then
    AUTO_RESTART=true
    shift
fi

if [ $# -eq 0 ]; then
    echo "Usage: $0 [-r] <service1> [service2] [service3] ..."
    echo "  -r    Auto-restart stopped services"
    echo ""
    echo "Examples:"
    echo "  $0 nginx ssh cron"
    echo "  $0 -r nginx mysql"
    exit 1
fi

SERVICES=("$@")

# ── Logging ───────────────────────────────────────────────────────────────
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local entry="[$timestamp] [$level] $message"
    echo "$entry"
    echo "$entry" >> "$LOG_FILE" 2>/dev/null || true
}

# ── Check systemd is available ────────────────────────────────────────────
if ! command -v systemctl &>/dev/null; then
    echo "ERROR: systemctl not found. This script requires a systemd-based system."
    echo "For non-systemd systems, use: service <name> status"
    exit 1
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME=$(hostname)
RESTART_NOTE=""
if $AUTO_RESTART; then RESTART_NOTE=" (auto-restart enabled)"; fi

echo ""
echo "═══════════════════════════════════════════════════"
echo "  SERVICE STATUS MONITOR${RESTART_NOTE}"
echo "  Host: $HOSTNAME | Time: $TIMESTAMP"
echo "═══════════════════════════════════════════════════"
echo ""

OVERALL_STATUS=0

for SERVICE in "${SERVICES[@]}"; do

    # Check if the unit exists
    if ! systemctl list-unit-files "${SERVICE}.service" &>/dev/null &&
       ! systemctl status "${SERVICE}.service" &>/dev/null 2>&1; then
        echo "  [NOT FOUND] $SERVICE — service unit does not exist on this system"
        log "WARN" "Service not found: $SERVICE"
        OVERALL_STATUS=1
        continue
    fi

    # Get current state
    SERVICE_STATE=$(systemctl is-active "$SERVICE" 2>/dev/null)
    SERVICE_ENABLED=$(systemctl is-enabled "$SERVICE" 2>/dev/null)

    # Build status line
    case "$SERVICE_STATE" in
        "active")
            echo "  [  OK  ] $SERVICE — running (enabled: $SERVICE_ENABLED)"
            log "INFO" "Service OK: $SERVICE (active, enabled: $SERVICE_ENABLED)"
            ;;

        "inactive"|"failed")
            if $AUTO_RESTART && [ "$(id -u)" -eq 0 ]; then
                echo "  [STOPPED] $SERVICE — attempting restart..."
                log "WARN" "Service stopped: $SERVICE. Attempting restart."

                systemctl start "$SERVICE" 2>/dev/null
                RESTART_EXIT=$?

                sleep 2
                NEW_STATE=$(systemctl is-active "$SERVICE" 2>/dev/null)

                if [ "$NEW_STATE" = "active" ]; then
                    echo "  [  OK  ] $SERVICE — successfully restarted"
                    log "SUCCESS" "Service restarted successfully: $SERVICE"
                else
                    echo "  [ FAIL ] $SERVICE — restart failed (state: $NEW_STATE)"
                    log "ERROR" "Service restart failed: $SERVICE (state: $NEW_STATE)"
                    OVERALL_STATUS=1

                    # Show recent journal entries for context
                    echo "           Recent journal entries:"
                    journalctl -u "$SERVICE" --no-pager -n 5 --output=short 2>/dev/null |
                    while IFS= read -r line; do echo "           $line"; done
                fi

            elif $AUTO_RESTART && [ "$(id -u)" -ne 0 ]; then
                echo "  [STOPPED] $SERVICE — stopped (auto-restart requires root)"
                log "WARN" "Service stopped: $SERVICE. Auto-restart skipped — not running as root."
                OVERALL_STATUS=1

            else
                echo "  [STOPPED] $SERVICE — not running"
                log "WARN" "Service stopped: $SERVICE"
                OVERALL_STATUS=1

                # Show the last known exit status
                LAST_STATUS=$(systemctl show "$SERVICE" --property=Result 2>/dev/null | cut -d= -f2)
                if [ -n "$LAST_STATUS" ] && [ "$LAST_STATUS" != "success" ]; then
                    echo "           Last exit result: $LAST_STATUS"
                fi
            fi
            ;;

        "activating")
            echo "  [STARTING] $SERVICE — currently starting up"
            log "INFO" "Service starting: $SERVICE"
            ;;

        *)
            echo "  [UNKNOWN] $SERVICE — state: $SERVICE_STATE"
            log "WARN" "Service in unknown state: $SERVICE ($SERVICE_STATE)"
            OVERALL_STATUS=1
            ;;
    esac
done

echo ""
echo "═══════════════════════════════════════════════════"
if [ $OVERALL_STATUS -eq 0 ]; then
    echo "  RESULT: All services are running."
else
    echo "  RESULT: One or more services require attention."
fi
echo "  Log: $LOG_FILE"
echo "═══════════════════════════════════════════════════"
echo ""

exit $OVERALL_STATUS


