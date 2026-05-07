# windows-linux-support-scripts

Production-quality PowerShell and Bash scripts for common L1/L2 IT support tasks
across Windows and Linux environments. Every script in this repository solves a
real recurring ticket type, handles every edge case, includes full error handling,
produces clear human-readable output, and logs actions where appropriate.

These are not toy examples. They are tools built to be used on real machines by
real technicians, with the safety and reliability that production use requires.

---

## What this repo contains

### PowerShell Scripts (Windows)

| Script | Ticket type it solves | Key features |
|--------|----------------------|-------------|
| `Flush-DNS.ps1` | "Website won't load" / "Internal hostname not resolving" | Checks DNS Client service, counts cache entries before/after, tests resolution post-flush, provides next steps |
| `Clear-PrintQueue.ps1` | "Job stuck in print queue / can't print" | Correct order: stop spooler → delete jobs → start spooler → verify; handles slow-to-stop service with timeout |
| `Get-DiskSpace.ps1` | "Computer is slow" / "Disk is full" | All drives in one view, colour-coded by severity, cleanup guidance built in |
| `Reset-NetworkStack.ps1` | Last resort — all other network steps failed | Documents IP config before reset, requires typed RESET confirmation, full winsock+TCP/IP+DNS+DHCP+ARP reset |
| `Get-SystemInfo.ps1` | Baseline collection at start of any session | OS, CPU, RAM, disk, network, recent errors, top processes — all in one structured report with optional file output |
| `Test-PortConnectivity.ps1` | "Can't connect to application/server/VPN" | Tests multiple hosts and ports simultaneously, service name lookup, open/closed result per port, next steps |
| `Get-EventLogErrors.ps1` | "Something went wrong — I don't know what" | System, Application, Security logs in one view, truncated messages for quick scanning, Access Denied handling |
| `Restart-ServiceWithCheck.ps1` | "Application is unresponsive" | Pre-check, dependent service warning, timeout handling, post-start health verification |


### Bash Scripts (Linux)

| Script | Purpose | Key features |
|--------|---------|-------------|
| `system-health.sh` | Linux server baseline health report | CPU load vs core count analysis, colour-coded disk usage with progress data, top 10 processes by CPU and memory, network interfaces, recent errors |
| `backup-with-timestamp.sh` | Timestamped compressed backup before changes | Source validation, archive integrity verification, retention-based cleanup, compression ratio reporting |
| `user-provision.sh` | New Linux user account provisioning | Username format validation, group existence check, secure password prompt, forced change on first login, 90-day expiry policy |
| `log-cleanup.sh` | Archive and compress old log files | Dry-run mode, configurable age/retention/pattern, gzip compression, cron-ready |
| `disk-usage-report.sh` | "What is taking up all the disk space?" | Filesystem overview, top 15 largest directories, top 20 largest files, recently created large files |
| `service-monitor.sh` | Check and optionally restart Linux services | systemd-based, auto-restart mode, journal log on failure, exit code for cron alerting |

---
