<# **What ticket this solves:** "Application X is not responding" — many application
issues are resolved by restarting the underlying Windows service. Doing this
manually means opening Services.msc, finding the service, right-clicking,
stopping, waiting, and starting. This script does it in one command with timeout
handling, status verification, and clear output showing what happened.

**Cert alignment:** CompTIA A+

#>

<#
.SYNOPSIS
    Restarts a Windows service with timeout handling and health verification.

.DESCRIPTION
    Stops and starts a named Windows service with:
      - Pre-restart status check (is it running?)
      - Timeout handling for services that are slow to stop
      - Verification that the service reached Running state after restart
      - Dependent service awareness (warns if dependent services are affected)
      - Clear success/failure output

    Common services this is used for:
      - Spooler      (print queue issues)
      - BITS         (Windows Update background transfers)
      - wuauserv     (Windows Update)
      - W3SVC        (IIS web server)
      - WSearch      (Windows Search indexing)
      - RemoteRegistry(remote registry access)
      - TermService  (Remote Desktop Services)

.PARAMETER ServiceName
    The service name (not display name) to restart. Use Get-Service to find names.

.PARAMETER TimeoutSeconds
    How long to wait for the service to stop and start. Default: 30 seconds each.

.EXAMPLE
    .\Restart-ServiceWithCheck.ps1 -ServiceName "Spooler"
    # Restart the Print Spooler service

.EXAMPLE
    .\Restart-ServiceWithCheck.ps1 -ServiceName "wuauserv" -TimeoutSeconds 60
    # Restart Windows Update with a 60-second timeout (update services can be slow)

.EXAMPLE
    .\Restart-ServiceWithCheck.ps1 -ServiceName "W3SVC"
    # Restart IIS

.NOTES
    Requires  : Administrator privileges
    Tested on : Windows 10, Windows 11, Windows Server 2022
    Cert align: CompTIA A+
#>

param(
    [Parameter(Mandatory = $true, HelpMessage = "Service name (use Get-Service to find it)")]
    [ValidateNotNullOrEmpty()]
    [string]$ServiceName,

    [Parameter(Mandatory = $false)]
    [ValidateRange(10, 300)]
    [int]$TimeoutSeconds = 30
)

Write-Host ""
Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  SERVICE RESTART: $ServiceName" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# ── Validate service exists ───────────────────────────────────────────────
$Service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

if (-not $Service) {
    Write-Host "  ERROR: Service '$ServiceName' not found." -ForegroundColor Red
    Write-Host ""
    Write-Host "  To find the correct service name (not display name):" -ForegroundColor Yellow
    Write-Host "    Get-Service | Where-Object {`$_.DisplayName -like '*print*'}" -ForegroundColor DarkGray
    Write-Host "    Get-Service | Format-Table Name, DisplayName, Status" -ForegroundColor DarkGray
    exit 1
}

# ── Show service details ──────────────────────────────────────────────────
Write-Host "  Service name    : $($Service.Name)"
Write-Host "  Display name    : $($Service.DisplayName)"
Write-Host "  Current status  : $($Service.Status)"
Write-Host "  Start type      : $($Service.StartType)"
Write-Host ""

# Check for dependent services
$DependentServices = Get-Service -Name $ServiceName -DependentServices -ErrorAction SilentlyContinue |
                     Where-Object { $_.Status -eq "Running" }

if ($DependentServices) {
    Write-Host "  ⚠ WARNING: The following running services depend on '$ServiceName':" -ForegroundColor Yellow
    $DependentServices | ForEach-Object {
        Write-Host "    - $($_.DisplayName) ($($_.Name))" -ForegroundColor Yellow
    }
    Write-Host "    These services will also be stopped during the restart." -ForegroundColor Yellow
    Write-Host ""
}

# Handle already stopped service
if ($Service.Status -eq "Stopped") {
    Write-Host "  Service is already stopped. Starting it now..." -ForegroundColor Yellow
    $SkipStop = $true
} else {
    $SkipStop = $false
}

# ── Stop the service ──────────────────────────────────────────────────────
if (-not $SkipStop) {
    Write-Host "[1/2] Stopping $ServiceName..." -ForegroundColor White

    try {
        Stop-Service -Name $ServiceName -Force -ErrorAction Stop
    } catch {
        Write-Host "  ERROR: Could not stop '$ServiceName': $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Ensure you are running as Administrator." -ForegroundColor Yellow
        exit 1
    }

    # Wait for stopped state with timeout
    $Elapsed = 0
    while ($Elapsed -lt $TimeoutSeconds) {
        $Service.Refresh()
        if ($Service.Status -eq "Stopped") {
            Write-Host "  Service stopped after ${Elapsed}s." -ForegroundColor Green
            break
        }
        Start-Sleep -Seconds 1
        $Elapsed++
    }

    if ($Service.Status -ne "Stopped") {
        Write-Host "  ERROR: Service did not stop within $TimeoutSeconds seconds." -ForegroundColor Red
        Write-Host "  Current status: $($Service.Status)" -ForegroundColor Red
        Write-Host "  Try stopping it manually in Services.msc" -ForegroundColor Yellow
        exit 1
    }
}

# ── Start the service ─────────────────────────────────────────────────────
Write-Host ""
Write-Host "[2/2] Starting $ServiceName..." -ForegroundColor White

try {
    Start-Service -Name $ServiceName -ErrorAction Stop
} catch {
    Write-Host "  ERROR: Could not start '$ServiceName': $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Check Windows Event Log for service start failure details." -ForegroundColor Yellow
    exit 1
}

# Wait for running state with timeout
$Elapsed = 0
while ($Elapsed -lt $TimeoutSeconds) {
    $Service.Refresh()
    if ($Service.Status -eq "Running") {
        Write-Host "  Service running after ${Elapsed}s." -ForegroundColor Green
        break
    }
    Start-Sleep -Seconds 1
    $Elapsed++
}

# ── Final status and summary ──────────────────────────────────────────────
$Service.Refresh()

Write-Host ""
Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan

if ($Service.Status -eq "Running") {
    Write-Host "  COMPLETE — $ServiceName is running." -ForegroundColor Green
    Write-Host "  Ask the user to retry the operation that was failing." -ForegroundColor White
} else {
    Write-Host "  WARNING — $ServiceName did not reach Running state." -ForegroundColor Red
    Write-Host "  Current status: $($Service.Status)" -ForegroundColor Red
    Write-Host "  Check Windows Event Log: eventvwr.msc → Windows Logs → System" -ForegroundColor Yellow
    Write-Host "  Look for events from source '$ServiceName' at the restart time." -ForegroundColor Yellow
}

Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
