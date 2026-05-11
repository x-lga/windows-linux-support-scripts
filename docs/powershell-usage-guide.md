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

### Get-SystemInfo.ps1

```powershell
# Display on screen only
.\powershell\Get-SystemInfo.ps1

# Save report to file for ticket attachment
.\powershell\Get-SystemInfo.ps1 -OutputFile "C:\Temp\INC-001-sysinfo.txt"
```

**When to use:** At the beginning of every support session to establish a documented
baseline. Before making any changes. When creating an escalation package for L2.

---

### Test-PortConnectivity.ps1

```powershell
# Test HTTP and HTTPS to a web server
.\powershell\Test-PortConnectivity.ps1 -Targets "webserver.company.com" -Ports 80,443

# Test all common RDP and management ports to a server
.\powershell\Test-PortConnectivity.ps1 -Targets "server01","10.20.1.4" -Ports 3389,5985,22,443

# Test email server ports
.\powershell\Test-PortConnectivity.ps1 -Targets "mail.company.com" -Ports 25,587,993

# Test with shorter timeout for quick results
.\powershell\Test-PortConnectivity.ps1 -Targets "192.168.1.1" -Ports 80,443,22 -TimeoutMs 1500
```

**When to use:** "Can't connect to application X" when basic ping works.
Investigating firewall rules. Verifying a service is listening before connecting.

---

### Get-EventLogErrors.ps1

```powershell
# Last 24 hours, all logs (default)
.\powershell\Get-EventLogErrors.ps1

# Last 2 hours, System log only
.\powershell\Get-EventLogErrors.ps1 -Hours 2 -Logs "System"

# Last 48 hours, more events
.\powershell\Get-EventLogErrors.ps1 -Hours 48 -MaxEvents 50 -Logs "System","Application"
```

**Requires:** Administrator for Security log. System and Application are accessible
without elevation.

**When to use:** Investigating the cause of a crash, unexpected reboot, service
failure, or performance issue. Building an L2 escalation package.

---

### Restart-ServiceWithCheck.ps1

```powershell
# Restart Print Spooler
.\powershell\Restart-ServiceWithCheck.ps1 -ServiceName "Spooler"

# Restart Windows Update (may need longer timeout)
.\powershell\Restart-ServiceWithCheck.ps1 -ServiceName "wuauserv" -TimeoutSeconds 60

# Restart IIS
.\powershell\Restart-ServiceWithCheck.ps1 -ServiceName "W3SVC"

# Find the correct service name
Get-Service | Where-Object {$_.DisplayName -like "*Windows Update*"} |
    Select-Object Name, DisplayName
```

**Requires:** Administrator privileges.

**When to use:** Application is unresponsive and a specific service is suspected.
Printing issues (Spooler). Windows Update stuck (wuauserv). IIS site not responding (W3SVC).

---
