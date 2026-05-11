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
