<# **What ticket this solves:** "My computer is running slowly" is one of the top five
most common L1 tickets, and one of the top causes is a nearly full disk causing
page file exhaustion, application crashes, and I/O saturation. This script provides
an instant, colour-coded disk space report across all local drives - the first
thing to check when a user reports slowness.

**Why this is better than the GUI:** It reports all drives simultaneously in a
single structured view, colour-codes by severity (green/yellow/red), calculates
used and free percentages, and flags drives below the warning threshold - something
that requires clicking through each drive individually in Windows Explorer.

**Cert alignment:** CompTIA A+

#>


<#
.SYNOPSIS
    Generates a colour-coded disk space report for all local fixed drives.

.DESCRIPTION
    Reports total size, used space, free space, and free percentage for every
    local fixed drive on the machine. Colour-codes each drive by health status:

      Green  : >= 25% free — healthy
      Yellow : 10–24% free — low, monitor and plan cleanup
      Red    : < 10% free  — critical, immediate action required

    This is the first diagnostic check when a user reports:
      - Computer running slowly
      - "Disk is full" error from an application
      - Windows Update failing to install
      - Event log truncation
      - Backup jobs failing

.PARAMETER WarnThreshold
    Percentage at which a drive is shown in yellow. Default: 25.

.PARAMETER CritThreshold
    Percentage at which a drive is shown in red. Default: 10.

.EXAMPLE
    .\Get-DiskSpace.ps1
    # Standard report with default thresholds (25% warn, 10% critical)

.EXAMPLE
    .\Get-DiskSpace.ps1 -WarnThreshold 30 -CritThreshold 15
    # Stricter thresholds — warn at 30%, critical at 15%

.NOTES
    Requires  : No elevation needed — runs as any user
    Tested on : Windows 10, Windows 11, Windows Server 2022
    Cert align: CompTIA A+
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 99)]
    [int]$WarnThreshold = 25,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 99)]
    [int]$CritThreshold = 10
)

# Validate threshold relationship
if ($CritThreshold -ge $WarnThreshold) {
    Write-Host "ERROR: CritThreshold ($CritThreshold%) must be less than WarnThreshold ($WarnThreshold%)." -ForegroundColor Red
    exit 1
}

$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$Hostname  = $env:COMPUTERNAME

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  DISK SPACE REPORT" -ForegroundColor Cyan
Write-Host "  Host: $Hostname | Time: $Timestamp" -ForegroundColor Cyan
Write-Host "  Thresholds: Warning < $WarnThreshold% | Critical < $CritThreshold%" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Header
$Header = "{0,-8} {1,12} {2,12} {3,12} {4,8}  {5}" -f "Drive", "Total (GB)", "Used (GB)", "Free (GB)", "Free %", "Status"
$Divider = "─" * 70
Write-Host $Header -ForegroundColor White
Write-Host $Divider -ForegroundColor DarkGray

# Get all fixed local drives (filter out mapped network drives and removable)
$Drives = Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue |
          Where-Object {
              $_.Used -ne $null -and
              $_.Free -ne $null -and
              $_.Used -gt 0 -and
              $_.Name.Length -eq 1    # Single letter = local fixed drive
          }

if (-not $Drives) {
    Write-Host "  No local fixed drives found." -ForegroundColor Yellow
    exit 0
}

$CriticalDrives = @()
$WarnDrives     = @()

foreach ($Drive in $Drives) {
    $TotalGB  = [math]::Round(($Drive.Used + $Drive.Free) / 1GB, 2)
    $UsedGB   = [math]::Round($Drive.Used / 1GB, 2)
    $FreeGB   = [math]::Round($Drive.Free / 1GB, 2)
    $FreePct  = [math]::Round(($Drive.Free / ($Drive.Used + $Drive.Free)) * 100, 1)

    # Determine status and colour
    if ($FreePct -lt $CritThreshold) {
        $StatusText = "CRITICAL"
        $Colour     = "Red"
        $CriticalDrives += "$($Drive.Name):\ ($FreePct% free)"
    } elseif ($FreePct -lt $WarnThreshold) {
        $StatusText = "WARNING"
        $Colour     = "Yellow"
        $WarnDrives += "$($Drive.Name):\ ($FreePct% free)"
    } else {
        $StatusText = "OK"
        $Colour     = "Green"
    }

    $Line = "{0,-8} {1,12} {2,12} {3,12} {4,7}%  {5}" -f `
        "$($Drive.Name):\",
        $TotalGB,
        $UsedGB,
        $FreeGB,
        $FreePct,
        $StatusText

    Write-Host $Line -ForegroundColor $Colour
}

Write-Host $Divider -ForegroundColor DarkGray
Write-Host ""

# ── Recommendations if any drives are low ────────────────────────────────
if ($CriticalDrives.Count -gt 0 -or $WarnDrives.Count -gt 0) {

    if ($CriticalDrives.Count -gt 0) {
        Write-Host "  ⚠ CRITICAL DRIVES — Immediate action required:" -ForegroundColor Red
        $CriticalDrives | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
        Write-Host ""
    }

    if ($WarnDrives.Count -gt 0) {
        Write-Host "  ⚠ WARNING DRIVES — Plan cleanup soon:" -ForegroundColor Yellow
        $WarnDrives | ForEach-Object { Write-Host "    - $_" -ForegroundColor Yellow }
        Write-Host ""
    }

    Write-Host "  RECOMMENDED CLEANUP STEPS (attempt in order):" -ForegroundColor White
    Write-Host "  1. Run Disk Cleanup: Start → Run → cleanmgr.exe" -ForegroundColor White
    Write-Host "     Select all categories including 'System files'" -ForegroundColor White
    Write-Host "  2. Clear Windows Update cache:" -ForegroundColor White
    Write-Host "     net stop wuauserv" -ForegroundColor DarkGray
    Write-Host "     del /q /f /s C:\Windows\SoftwareDistribution\Download\*" -ForegroundColor DarkGray
    Write-Host "     net start wuauserv" -ForegroundColor DarkGray
    Write-Host "  3. Clear Temp folders:" -ForegroundColor White
    Write-Host "     del /q /f /s `$env:TEMP\*" -ForegroundColor DarkGray
    Write-Host "     del /q /f /s C:\Windows\Temp\*" -ForegroundColor DarkGray
    Write-Host "  4. Find large files:" -ForegroundColor White
    Write-Host "     Get-ChildItem C:\ -Recurse -EA SilentlyContinue |" -ForegroundColor DarkGray
    Write-Host "       Sort Length -Desc | Select -First 20 FullName,Length" -ForegroundColor DarkGray
    Write-Host "  5. Escalate to L2 if above steps do not resolve — may need" -ForegroundColor White
    Write-Host "     storage expansion or archiving policy review." -ForegroundColor White

} else {
    Write-Host "  All drives are within healthy thresholds." -ForegroundColor Green
}

Write-Host ""




