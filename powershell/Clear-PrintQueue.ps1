<# **What ticket this solves:** "I can't print - there's a job stuck in the queue" is
one of the most frequent L1 help desk calls. A stuck print job blocks all subsequent
jobs in the queue. Clearing it manually requires opening Services, stopping the
Print Spooler, navigating to the spool folder, deleting files, and restarting
the service - a 3-minute process with multiple steps that technicians often get
wrong (forgetting to stop the service before deleting files, or not restarting it). 

**Why this script matters:** It handles the complete workflow - stops the spooler,
deletes stuck jobs, restarts the spooler, and confirms the service came back up
cleanly. It also handles the case where the spooler service cannot be stopped
(rare but real) without crashing.

**Cert alignment:** CompTIA A+

#>

```powershell
<#
.SYNOPSIS
    Clears a stuck Windows print queue by stopping the Print Spooler service,
    deleting all pending print jobs, and restarting the service.

.DESCRIPTION
    Resolves the most common printing support ticket: jobs stuck in the print queue
    that prevent any further printing.

    The script performs these steps in the correct order:
      1. Check Print Spooler service status
      2. Stop the Print Spooler service (required before deleting spool files)
      3. Delete all files in the spool directory (the stuck print jobs)
      4. Restart the Print Spooler service
      5. Verify the service is running and healthy
      6. Display a count of jobs cleared and status confirmation

    Why order matters: deleting spool files while the spooler is running can
    cause file locking errors and partial deletions. Always stop first, delete,
    then start.

.PARAMETER SpoolPath
    Path to the print spool directory. Defaults to the standard Windows location.
    Only change this if your environment uses a custom spool directory.

.EXAMPLE
    .\Clear-PrintQueue.ps1
    # Clears the print queue using the default spool directory

.EXAMPLE
    .\Clear-PrintQueue.ps1 -SpoolPath "D:\CustomSpool\PRINTERS"
    # Clears using a custom spool directory

.NOTES
    Requires  : Administrator privileges (stopping/starting services requires elevation)
    Tested on : Windows 10 22H2, Windows 11 23H2, Windows Server 2022
    Cert align: CompTIA A+
    Caution   : This deletes ALL pending print jobs. Warn users before running.
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$SpoolPath = "$env:WINDIR\System32\spool\PRINTERS"
)

Write-Host ""
Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  PRINT QUEUE CLEAR" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# ── Validate spool directory exists ──────────────────────────────────────
if (-not (Test-Path $SpoolPath)) {
    Write-Host "  ERROR: Spool directory not found: $SpoolPath" -ForegroundColor Red
    Write-Host "  Verify the path and run again." -ForegroundColor Yellow
    exit 1
}

# ── User warning ──────────────────────────────────────────────────────────
Write-Host "  WARNING: This script will delete ALL pending print jobs." -ForegroundColor Yellow
Write-Host "  Spool directory: $SpoolPath" -ForegroundColor White
Write-Host ""

# Count jobs before clearing
$JobsBefore = Get-ChildItem -Path $SpoolPath -File -ErrorAction SilentlyContinue
$JobCount   = if ($JobsBefore) { $JobsBefore.Count } else { 0 }
Write-Host "  Pending print jobs found: $JobCount" -ForegroundColor Cyan

if ($JobCount -eq 0) {
    Write-Host ""
    Write-Host "  Print queue is already empty. No action needed." -ForegroundColor Green
    Write-Host "  If the user still cannot print, investigate:" -ForegroundColor White
    Write-Host "    - Printer is offline or in error state (check printer display)" -ForegroundColor White
    Write-Host "    - Printer driver is missing or corrupt (Device Manager)" -ForegroundColor White
    Write-Host "    - Printer is set as default but wrong printer selected" -ForegroundColor White
    exit 0
}

Write-Host ""

# ── Step 1: Stop Print Spooler ────────────────────────────────────────────
Write-Host "[1/4] Stopping Print Spooler service..." -ForegroundColor White

$Spooler = Get-Service -Name "Spooler" -ErrorAction SilentlyContinue

if (-not $Spooler) {
    Write-Host "  ERROR: Print Spooler service (Spooler) not found." -ForegroundColor Red
    exit 1
}

try {
    Stop-Service -Name "Spooler" -Force -ErrorAction Stop

    # Wait up to 15 seconds for the service to stop
    $StopTimeout = 0
    while ($StopTimeout -lt 15) {
        $Spooler.Refresh()
        if ($Spooler.Status -eq "Stopped") { break }
        Start-Sleep -Seconds 1
        $StopTimeout++
    }

    if ($Spooler.Status -ne "Stopped") {
        Write-Host "  ERROR: Print Spooler did not stop within 15 seconds." -ForegroundColor Red
        Write-Host "  Status: $($Spooler.Status)" -ForegroundColor Red
        Write-Host "  Try running this script as Administrator." -ForegroundColor Yellow
        exit 1
    }

    Write-Host "  Print Spooler stopped." -ForegroundColor Green

} catch {
    Write-Host "  ERROR: Could not stop Print Spooler: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  This script requires Administrator privileges." -ForegroundColor Yellow
    exit 1
}

# ── Step 2: Delete spool files ────────────────────────────────────────────
Write-Host ""
Write-Host "[2/4] Deleting stuck print jobs..." -ForegroundColor White

$DeletedCount = 0
$ErrorCount   = 0

$Files = Get-ChildItem -Path $SpoolPath -File -ErrorAction SilentlyContinue

foreach ($File in $Files) {
    try {
        Remove-Item -Path $File.FullName -Force -ErrorAction Stop
        $DeletedCount++
    } catch {
        Write-Host "  WARNING: Could not delete $($File.Name): $($_.Exception.Message)" -ForegroundColor Yellow
        $ErrorCount++
    }
}

Write-Host "  Files deleted: $DeletedCount" -ForegroundColor Green
if ($ErrorCount -gt 0) {
    Write-Host "  Files that could not be deleted: $ErrorCount" -ForegroundColor Yellow
}

# ── Step 3: Restart Print Spooler ────────────────────────────────────────
Write-Host ""
Write-Host "[3/4] Starting Print Spooler service..." -ForegroundColor White

try {
    Start-Service -Name "Spooler" -ErrorAction Stop

    # Wait up to 15 seconds for the service to start
    $StartTimeout = 0
    while ($StartTimeout -lt 15) {
        $Spooler.Refresh()
        if ($Spooler.Status -eq "Running") { break }
        Start-Sleep -Seconds 1
        $StartTimeout++
    }

    if ($Spooler.Status -ne "Running") {
        Write-Host "  ERROR: Print Spooler did not start within 15 seconds." -ForegroundColor Red
        Write-Host "  Status: $($Spooler.Status)" -ForegroundColor Red
        Write-Host "  Check Windows Event Log for service start failure." -ForegroundColor Yellow
        exit 1
    }

    Write-Host "  Print Spooler started." -ForegroundColor Green

} catch {
    Write-Host "  ERROR: Could not start Print Spooler: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# ── Step 4: Verify and summary ────────────────────────────────────────────
Write-Host ""
Write-Host "[4/4] Verifying Print Spooler health..." -ForegroundColor White

$SpoolerFinal = Get-Service -Name "Spooler"
$SpoolerFinal.Refresh()

Write-Host ""
Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
if ($SpoolerFinal.Status -eq "Running") {
    Write-Host "  COMPLETE — Print queue cleared." -ForegroundColor Green
    Write-Host ""
    Write-Host "  Jobs removed : $DeletedCount" -ForegroundColor Green
    Write-Host "  Spooler      : Running" -ForegroundColor Green
} else {
    Write-Host "  WARNING — Jobs cleared but Spooler status is unexpected." -ForegroundColor Yellow
    Write-Host "  Spooler status: $($SpoolerFinal.Status)" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "  Ask the user to retry printing now." -ForegroundColor White
Write-Host "  If printing still fails after queue is clear:" -ForegroundColor White
Write-Host "    1. Check printer is online (not showing error on display)" -ForegroundColor White
Write-Host "    2. Remove and re-add the printer: Settings > Printers & Scanners" -ForegroundColor White
Write-Host "    3. Update the printer driver via Device Manager" -ForegroundColor White
Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
```


