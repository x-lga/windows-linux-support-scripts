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
