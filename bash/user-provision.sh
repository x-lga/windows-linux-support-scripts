# **What ticket this solves:** "We have a new employee starting Monday — can you
# set up their Linux account?" - user provisioning on Linux systems requires multiple
# steps: useradd, setting a password, configuring password policy, adding to groups,
# creating home directory, and setting correct permissions. Done manually and
# inconsistently, accounts end up with different configurations. This script
# standardises the process.

# **Cert alignment:** CompTIA A+

#!/usr/bin/env bash
# =============================================================================
# user-provision.sh
# =============================================================================
# Provisions a new Linux user account with standardised settings.
#
# Actions performed:
#   - Validates the script is run as root
#   - Validates that the username does not already exist
#   - Validates username format (lowercase letters, numbers, underscores only)
#   - Creates the user account with home directory and specified shell
#   - Adds user to specified supplementary groups (if provided)
#   - Sets an initial password (prompted securely — not echoed to terminal)
#   - Forces password change on first login (chage -d 0)
#   - Sets password expiry policy (90 days max, 7 days warning)
#   - Logs all actions with timestamp and operator identity
#   - Displays a post-creation summary with verification commands
#
# Usage (interactive):
#   sudo bash user-provision.sh
#
# Usage (non-interactive — for scripted provisioning):
#   sudo bash user-provision.sh --username jsmith --fullname "John Smith" \
#     --groups sudo,developers --shell /bin/bash
#   (Will still prompt for password securely)
#
# Requires  : root or sudo, bash, useradd, chage, usermod
# Tested on : Ubuntu 20.04, Ubuntu 22.04, Debian 11
# Cert align: CompTIA A+
# =============================================================================

# ── Must run as root ──────────────────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root or with sudo."
    echo "Usage: sudo bash $0"
    exit 1
fi

# ── Logging ───────────────────────────────────────────────────────────────
LOG_DIR="/var/log"
LOG_FILE="${LOG_DIR}/user-provision.log"

log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local entry="[$timestamp] [$level] [operator: $(who am i | awk '{print $1}')] $message"
    echo "$entry" | tee -a "$LOG_FILE"
}

# ── Default values ────────────────────────────────────────────────────────
USERNAME=""
FULLNAME=""
GROUPS=""
SHELL="/bin/bash"
NON_INTERACTIVE=false

# ── Parse optional non-interactive arguments ──────────────────────────────
while [[ $# -gt 0 ]]; do
    case $1 in
        --username)   USERNAME="$2";    shift 2 ;;
        --fullname)   FULLNAME="$2";    shift 2 ;;
        --groups)     GROUPS="$2";      shift 2 ;;
        --shell)      SHELL="$2";       shift 2 ;;
        --non-interactive) NON_INTERACTIVE=true; shift ;;
        *)
            echo "Unknown argument: $1"
            echo "Usage: sudo bash $0 [--username NAME] [--fullname 'Full Name'] [--groups group1,group2] [--shell /bin/bash]"
            exit 1 ;;
    esac
done

# ── Interactive prompts if values not provided ────────────────────────────
echo ""
echo "════════════════════════════════════════════════"
echo "  LINUX USER PROVISIONING"
echo "════════════════════════════════════════════════"
echo ""

if [ -z "$USERNAME" ]; then
    read -p "  Username (lowercase, no spaces): " USERNAME
fi

if [ -z "$FULLNAME" ]; then
    read -p "  Full name (for GECOS field)    : " FULLNAME
fi

if [ -z "$GROUPS" ]; then
    echo "  Supplementary groups (comma-separated, leave blank for none)"
    echo "  Common groups: sudo, docker, www-data, developers"
    read -p "  Groups                         : " GROUPS
fi

# Shell selection
if ! $NON_INTERACTIVE && [ "$SHELL" = "/bin/bash" ]; then
    echo ""
    echo "  Available shells:"
    grep -v '^#' /etc/shells 2>/dev/null | while read -r s; do echo "    $s"; done
    read -p "  Login shell [/bin/bash]        : " SHELL_INPUT
    if [ -n "$SHELL_INPUT" ]; then
        SHELL="$SHELL_INPUT"
    fi
fi

# ── Validation ────────────────────────────────────────────────────────────
echo ""
echo "Validating inputs..."

# Validate username format
if ! [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
    log "ERROR" "Invalid username format: '$USERNAME'"
    echo "ERROR: Username must start with a lowercase letter or underscore,"
    echo "       contain only lowercase letters, numbers, hyphens, or underscores,"
    echo "       and be 1–32 characters long."
    exit 1
fi

# Check username does not already exist
if id "$USERNAME" &>/dev/null; then
    log "ERROR" "Username '$USERNAME' already exists in the system."
    echo "ERROR: User '$USERNAME' already exists."
    echo "  Current account details:"
    id "$USERNAME"
    exit 1
fi

# Validate shell exists
if [ ! -f "$SHELL" ]; then
    log "ERROR" "Shell '$SHELL' does not exist on this system."
    echo "ERROR: Shell '$SHELL' does not exist."
    echo "Valid shells are listed in /etc/shells:"
    grep -v '^#' /etc/shells 2>/dev/null
    exit 1
fi

# Validate groups exist (if specified)
if [ -n "$GROUPS" ]; then
    IFS=',' read -ra GROUP_ARRAY <<< "$GROUPS"
    for grp in "${GROUP_ARRAY[@]}"; do
        grp=$(echo "$grp" | tr -d ' ')
        if ! getent group "$grp" &>/dev/null; then
            log "ERROR" "Group '$grp' does not exist on this system."
            echo "ERROR: Group '$grp' does not exist."
            echo "Create it first with: sudo groupadd $grp"
            exit 1
        fi
    done
fi

log "INFO" "Validation passed for new user: $USERNAME ($FULLNAME)"

# ── Password collection ───────────────────────────────────────────────────
echo ""
echo "  Set initial password for '$USERNAME':"
echo "  (This password must be changed on first login)"
echo ""

while true; do
    read -s -p "  Initial password : " PASSWORD
    echo ""
    read -s -p "  Confirm password : " PASSWORD_CONFIRM
    echo ""

    if [ -z "$PASSWORD" ]; then
        echo "  ERROR: Password cannot be empty."
        continue
    fi

    if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
        echo "  ERROR: Passwords do not match. Please try again."
        continue
    fi

    # Basic password length check
    if [ "${#PASSWORD}" -lt 8 ]; then
        echo "  WARNING: Password is less than 8 characters. Consider using a stronger password."
        read -p "  Continue anyway? (y/N): " WEAK_CONFIRM
        if [[ ! "$WEAK_CONFIRM" =~ ^[Yy]$ ]]; then
            continue
        fi
    fi

    break
done

# ── Create the user account ───────────────────────────────────────────────
echo ""
echo "Creating user account..."

# Build useradd command
USERADD_CMD="useradd --create-home --shell $SHELL"
if [ -n "$FULLNAME" ]; then
    USERADD_CMD="$USERADD_CMD --comment \"$FULLNAME\""
fi
USERADD_CMD="$USERADD_CMD $USERNAME"

eval $USERADD_CMD
USERADD_EXIT=$?

if [ $USERADD_EXIT -ne 0 ]; then
    log "ERROR" "useradd failed with exit code $USERADD_EXIT for user '$USERNAME'"
    echo "ERROR: Failed to create user '$USERNAME'. Exit code: $USERADD_EXIT"
    exit 1
fi

log "SUCCESS" "User account created: $USERNAME (full name: $FULLNAME, shell: $SHELL)"

# ── Set the password ──────────────────────────────────────────────────────
echo "$USERNAME:$PASSWORD" | chpasswd
CHPASSWD_EXIT=$?

# Clear password from variable immediately after use
unset PASSWORD
unset PASSWORD_CONFIRM

if [ $CHPASSWD_EXIT -ne 0 ]; then
    log "ERROR" "chpasswd failed for user '$USERNAME'. Deleting incomplete account."
    userdel -r "$USERNAME" 2>/dev/null
    echo "ERROR: Failed to set password. Incomplete account removed."
    exit 1
fi

log "INFO" "Password set for '$USERNAME' (value not logged)"

# ── Force password change on first login ──────────────────────────────────
chage -d 0 "$USERNAME"
log "INFO" "Password change forced on next login for '$USERNAME'"

# ── Set password expiry policy ────────────────────────────────────────────
chage -M 90 -W 7 "$USERNAME"
log "INFO" "Password policy set: max 90 days, 7-day warning for '$USERNAME'"

# ── Add to supplementary groups ───────────────────────────────────────────
if [ -n "$GROUPS" ]; then
    usermod -aG "$GROUPS" "$USERNAME"
    USERMOD_EXIT=$?
    if [ $USERMOD_EXIT -eq 0 ]; then
        log "SUCCESS" "Added '$USERNAME' to groups: $GROUPS"
        echo "  Added to groups: $GROUPS"
    else
        log "ERROR" "Failed to add '$USERNAME' to some groups: $GROUPS"
        echo "WARNING: Failed to add to some groups. Check groups exist."
    fi
fi

# ── Summary ───────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════"
echo "  USER PROVISIONING COMPLETE"
echo "────────────────────────────────────────────────"
echo "  Username    : $USERNAME"
echo "  Full name   : $FULLNAME"
echo "  Home dir    : $(eval echo ~$USERNAME)"
echo "  Shell       : $SHELL"
echo "  Groups      : $(id -Gn $USERNAME)"
echo "  PW policy   : Change on first login, expires every 90 days"
echo "────────────────────────────────────────────────"
echo "  Verification commands:"
echo "    id $USERNAME"
echo "    getent passwd $USERNAME"
echo "    chage -l $USERNAME"
echo "  Test login:"
echo "    su - $USERNAME"
echo "════════════════════════════════════════════════"
echo ""

log "INFO" "Provisioning complete for '$USERNAME'. Communicate initial password via secure channel."
exit 0

