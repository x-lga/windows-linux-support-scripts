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
