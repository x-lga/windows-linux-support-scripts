# Bash Script Usage Guide

Quick reference for using every Bash script in this repository on Linux systems.

---

## Prerequisites

### Make scripts executable

```bash
# Make a single script executable
chmod +x bash/system-health.sh

# Make all scripts in the bash directory executable
chmod +x bash/*.sh

# Verify
ls -la bash/*.sh
```

### Run scripts

```bash
# Option 1: Execute directly (requires chmod +x first)
./bash/system-health.sh

# Option 2: Run with bash explicitly (no chmod needed)
bash bash/system-health.sh

# Option 3: With sudo for scripts requiring root
sudo bash bash/user-provision.sh
sudo bash bash/service-monitor.sh -r nginx mysql
```

---

## Script Reference

### system-health.sh

```bash
# Basic health report
bash bash/system-health.sh

# Custom thresholds (warn at 80%, critical at 90%)
bash bash/system-health.sh -w 80 -c 90

# Save to file for ticket attachment
bash bash/system-health.sh -o /tmp/health-$(hostname)-$(date +%Y%m%d).txt
```

**When to use:** Beginning of any Linux server support session. Server reported as
slow. Investigating high CPU or memory complaints. Building an L2 escalation package.

---

### backup-with-timestamp.sh

```bash
# Backup /etc to default location (/var/backups)
sudo bash bash/backup-with-timestamp.sh /etc

# Backup web root to custom location with 14-day retention
sudo bash bash/backup-with-timestamp.sh /var/www/html /mnt/backups 14

# Backup home directory with 30-day retention
bash bash/backup-with-timestamp.sh /home/user /home/user/backups 30
```

**When to use:** Before making any system configuration changes. Before applying
patches. Creating a checkpoint before testing new software.

---

### user-provision.sh

```bash
# Interactive mode
sudo bash bash/user-provision.sh

# Non-interactive mode (prompts for password only)
sudo bash bash/user-provision.sh \
    --username jsmith \
    --fullname "John Smith" \
    --groups sudo,developers \
    --shell /bin/bash
```

**Requires:** Root/sudo.

**When to use:** New employee account creation on a Linux server or workstation.
Standardised provisioning to ensure consistent account configuration.

---
