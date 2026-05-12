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
