<# **What ticket this solves:** "Something is wrong but I don't know what" — pulling
recent errors from the Windows Event Log is a foundational diagnostic step that
reveals application crashes, service failures, driver issues, and security events
that are otherwise invisible. This script queries multiple logs simultaneously
and presents a consolidated, time-ordered view.

**Cert alignment:** CompTIA A+

#>

<#
.SYNOPSIS
    Retrieves and displays recent errors and warnings from Windows Event Logs.

.DESCRIPTION
    Queries the System, Application, and Security event logs for recent error
    and warning entries. Presents them in a consolidated, time-ordered view
    that is faster to review than opening Event Viewer manually.

    Useful for:
      - Identifying what caused a recent system crash or reboot
      - Finding application errors that coincide with user complaints
      - Reviewing security audit events around a specific time
      - Documenting system errors for escalation packages

.PARAMETER Hours
    How many hours back to look in the event logs. Default: 24 hours.

.PARAMETER Logs
    Which event logs to query. Default: System, Application, Security.

.PARAMETER MaxEvents
    Maximum number of events to return per log. Default: 20.

.EXAMPLE
    .\Get-EventLogErrors.ps1
    # Last 24 hours, all three logs, up to 20 events each

.EXAMPLE
    .\Get-EventLogErrors.ps1 -Hours 2 -Logs "System"
    # Last 2 hours from System log only

.EXAMPLE
    .\Get-EventLogErrors.ps1 -Hours 48 -MaxEvents 50
    # Last 48 hours, up to 50 events per log

.NOTES
    Requires  : Administrator privileges for Security log access
                (System and Application logs are accessible without elevation)
    Tested on : Windows 10, Windows 11, Windows Server 2022
    Cert align: CompTIA A+
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 720)]
    [int]$Hours = 24,

    [Parameter(Mandatory = $false)]
    [string[]]$Logs = @("System", "Application", "Security"),

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 500)]
    [int]$MaxEvents = 20
)

$CutoffTime = (Get-Date).AddHours(-$Hours)
$Timestamp  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  WINDOWS EVENT LOG ERRORS AND WARNINGS" -ForegroundColor Cyan
Write-Host "  Generated: $Timestamp" -ForegroundColor Cyan
Write-Host "  Time range: Last $Hours hours (since $($CutoffTime.ToString('yyyy-MM-dd HH:mm')))" -ForegroundColor Cyan
Write-Host "  Max events per log: $MaxEvents" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$TotalErrorCount   = 0
$TotalWarningCount = 0

foreach ($LogName in $Logs) {
    Write-Host "  ── $LogName Log ────────────────────────────────────────" -ForegroundColor Yellow
    Write-Host ""

    try {
        $Events = Get-WinEvent -FilterHashtable @{
            LogName   = $LogName
            Level     = @(1, 2, 3)    # 1=Critical, 2=Error, 3=Warning
            StartTime = $CutoffTime
        } -MaxEvents $MaxEvents -ErrorAction Stop |
        Sort-Object TimeCreated -Descending

        if (-not $Events) {
            Write-Host "  No errors or warnings in the last $Hours hours." -ForegroundColor Green
            Write-Host ""
            continue
        }

        $LogErrors   = ($Events | Where-Object { $_.Level -in @(1, 2) }).Count
        $LogWarnings = ($Events | Where-Object { $_.Level -eq 3 }).Count
        $TotalErrorCount   += $LogErrors
        $TotalWarningCount += $LogWarnings

        Write-Host "  Found: $LogErrors critical/errors, $LogWarnings warnings" -ForegroundColor White
        Write-Host ""

        foreach ($Event in $Events) {
            $LevelText = switch ($Event.Level) {
                1 { "CRITICAL" }
                2 { "ERROR" }
                3 { "WARNING" }
                default { "INFO" }
            }
            $LevelColour = switch ($Event.Level) {
                1 { "Red" }
                2 { "Red" }
                3 { "Yellow" }
                default { "White" }
            }

            $TimeStr = $Event.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
            $Header  = "  [$TimeStr] [$LevelText] ID:$($Event.Id) — $($Event.ProviderName)"
            Write-Host $Header -ForegroundColor $LevelColour

            # Truncate message for readability
            $Msg = $Event.Message
            if ($Msg -and $Msg.Length -gt 200) {
                $Msg = $Msg.Substring(0, 200) + "..."
            }
            if ($Msg) {
                # Clean up newlines for single-line display
                $MsgClean = $Msg -replace "`r`n|`n|`r", " " -replace "\s+", " "
                Write-Host "    $MsgClean" -ForegroundColor DarkGray
            }
            Write-Host ""
        }

    } catch [System.UnauthorizedAccessException] {
        Write-Host "  ACCESS DENIED: The $LogName log requires Administrator privileges." -ForegroundColor Red
        Write-Host "  Run this script as Administrator to access the $LogName log." -ForegroundColor Yellow
        Write-Host ""
    } catch {
        if ($_.Exception.Message -like "*No events were found*") {
            Write-Host "  No errors or warnings in the last $Hours hours." -ForegroundColor Green
        } else {
            Write-Host "  ERROR reading $LogName log: $($_.Exception.Message)" -ForegroundColor Red
        }
        Write-Host ""
    }
}

# ── Summary ───────────────────────────────────────────────────────────────
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  SUMMARY: $TotalErrorCount critical/errors | $TotalWarningCount warnings (last $Hours hours)" -ForegroundColor $(if($TotalErrorCount -gt 0){"Red"}elseif($TotalWarningCount -gt 0){"Yellow"}else{"Green"})
Write-Host ""
Write-Host "  For detailed investigation of a specific event ID:" -ForegroundColor White
Write-Host "    Get-WinEvent -FilterHashtable @{LogName='System'; Id=<EventID>; StartTime=(Get-Date).AddHours(-24)}" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  To open Event Viewer directly: eventvwr.msc" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
