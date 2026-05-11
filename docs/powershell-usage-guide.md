# PowerShell Script Usage Guide

Quick reference for using every PowerShell script in this repository.

---

## Prerequisites

### Set PowerShell Execution Policy

Scripts cannot run by default on new Windows installations until the execution
policy is configured. Run PowerShell as Administrator:

```powershell
# Allow scripts signed by a trusted publisher, or scripts you write locally
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Verify
Get-ExecutionPolicy -Scope CurrentUser
```

### Check your PowerShell version

```powershell
$PSVersionTable.PSVersion
# These scripts require PowerShell 5.1 or later
# PowerShell 5.1 is included in Windows 10 and Server 2016+
```

---

## Script Reference

### Flush-DNS.ps1

```powershell
# Basic flush with default test (google.com)
.\powershell\Flush-DNS.ps1

# Flush and test an internal hostname
.\powershell\Flush-DNS.ps1 -TestHostname "fileserver.contoso.local"
```

**When to use:** User reports a website or network resource is unreachable by name
but the IP address works. DNS record was recently updated. Mapped drive disconnecting.

---

### Clear-PrintQueue.ps1

```powershell
# Clear the default spool directory
.\powershell\Clear-PrintQueue.ps1

# Clear a custom spool directory
.\powershell\Clear-PrintQueue.ps1 -SpoolPath "D:\CustomSpool\PRINTERS"
```

**Requires:** Administrator privileges (stopping/starting services).

**When to use:** Print jobs stuck in the queue. User cannot print but queue shows
jobs pending. Print Spooler service is running but nothing prints.

---

### Get-DiskSpace.ps1

```powershell
# Standard report with default thresholds
.\powershell\Get-DiskSpace.ps1

# Stricter thresholds for servers
.\powershell\Get-DiskSpace.ps1 -WarnThreshold 30 -CritThreshold 20
```

**When to use:** First check when a user reports the computer is slow, disk is full,
or applications are crashing. Run at the start of any server troubleshooting session.

---

### Reset-NetworkStack.ps1

```powershell
# Interactive mode — prompts for confirmation
.\powershell\Reset-NetworkStack.ps1

# Non-interactive mode (automated scenarios only)
.\powershell\Reset-NetworkStack.ps1 -SkipConfirmation
```

**Requires:** Administrator privileges.

**IMPORTANT:** Requires a system restart to take effect. Warn the user before running.

**When to use:** ALL other connectivity steps have been attempted and failed:
DNS flush, DHCP release/renew, cable check, restart. Use as a last resort.

---
