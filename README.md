# windows-linux-support-scripts

PowerShell and Bash scripts for common L1/L2 support tasks across Windows and Linux environments. All scripts tested in a Proxmox home lab environment with Windows Server 2022 and Ubuntu 22.04.

---

## PowerShell Scripts

| Script | Common Ticket | Usage |
|--------|--------------|-------|
| `Flush-DNS.ps1` | "Website won't load" | `.\Flush-DNS.ps1` |
| `Clear-PrintQueue.ps1` | "Can't print — stuck job" | `.\Clear-PrintQueue.ps1` |
| `Get-DiskSpace.ps1` | "Computer is slow / full" | `.\Get-DiskSpace.ps1` |
| `Reset-NetworkStack.ps1` | "No network after all other steps" | `.\Reset-NetworkStack.ps1` |
| `Get-SystemInfo.ps1` | "Gather info at start of session" | `.\Get-SystemInfo.ps1` |

## Bash Scripts

| Script | Purpose | Example |
|--------|---------|---------|
| `system-health.sh` | CPU/RAM/disk health report | `bash system-health.sh` |
| `backup-with-timestamp.sh` | Timestamped compressed backup | `sudo bash backup-with-timestamp.sh /etc /backups` |
| `user-provision.sh` | Create new Linux user account | `sudo bash user-provision.sh` |
| `log-cleanup.sh` | Move and compress old log files | `sudo bash log-cleanup.sh /var/log 30` |

---

## Skills Demonstrated

- PowerShell: Parameter handling, output formatting, service management, network stack
- Bash: Input validation, error handling, file operations, cron-compatible design
- Linux admin: User management, disk operations, log rotation, process monitoring
- A+ practical: Command-line troubleshooting of the most common L1 ticket types