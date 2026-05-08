<# **What ticket this solves:** Every support session should begin with gathering
baseline system information - OS version, hardware specs, last boot time, IP
configuration, running services, recent errors. Doing this manually requires
8-10 separate commands and clicks across multiple locations. This script collects
everything in a single run and formats it as a readable report.

**Why this is valuable in a portfolio:** It demonstrates knowledge of WMI/CIM,
PowerShell object properties, multiple system information sources, and output
formatting - all in one script.

**Cert alignment:** CompTIA A+

#>


<#
.SYNOPSIS
    Collects comprehensive system information for support session baseline documentation.

.DESCRIPTION
    Gathers hardware specifications, OS information, network configuration, disk
    health indicators, recent system errors, and running service count — all in
    one structured report. Run at the START of any support session to establish
    a documented baseline before making any changes.

    Information collected:
      - Machine name, domain membership, logged-on user
      - OS name, version, build number, install date
      - CPU model, core count, current utilisation
      - Total RAM and percentage currently in use
      - All network adapters with IP, MAC, gateway, DNS
      - All local drives with size and free space
      - Last boot time and uptime calculation
      - Most recent 5 System event log errors
      - Top 10 CPU-consuming processes at time of run

.PARAMETER OutputFile
    Optional. If specified, saves the report to a text file at this path
    in addition to displaying on screen. Useful for attaching to a ticket.

.EXAMPLE
    .\Get-SystemInfo.ps1
    # Display report on screen only

.EXAMPLE
    .\Get-SystemInfo.ps1 -OutputFile "C:\Tickets\INC-20260701-sysinfo.txt"
    # Display on screen and save to file

.NOTES
    Requires  : No elevation needed for most information
                Some WMI queries may return limited data without admin rights
    Tested on : Windows 10, Windows 11, Windows Server 2022
    Cert align: CompTIA A+
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$OutputFile = ""
)

# ── Output function — writes to screen and optionally to file ─────────────
$OutputLines = [System.Collections.Generic.List[string]]::new()

function Write-Report {
    param(
        [string]$Text = "",
        [string]$Colour = "White"
    )
    Write-Host $Text -ForegroundColor $Colour
    $OutputLines.Add($Text)
}

$Sep     = "═" * 60
$SubSep  = "─" * 60
$Now     = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Report $Sep "Cyan"
Write-Report "  SYSTEM INFORMATION REPORT" "Cyan"
Write-Report "  Generated: $Now" "Cyan"
Write-Report "  Operator : $($env:USERNAME)" "Cyan"
Write-Report $Sep "Cyan"
Write-Report ""

# ── Section 1: Machine Identity ───────────────────────────────────────────
Write-Report "  MACHINE IDENTITY" "Yellow"
Write-Report $SubSep "DarkGray"

$CS = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
$OS = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue

Write-Report "  Hostname          : $($env:COMPUTERNAME)"
Write-Report "  Domain/Workgroup  : $(if($CS.PartOfDomain){"DOMAIN: $($CS.Domain)"}else{"WORKGROUP: $($CS.WorkGroup)"})"
Write-Report "  Logged-on User    : $($env:USERDOMAIN)\$($env:USERNAME)"
Write-Report "  OS                : $($OS.Caption)"
Write-Report "  OS Version        : $($OS.Version)"
Write-Report "  OS Build          : $($OS.BuildNumber)"
Write-Report "  OS Architecture   : $($OS.OSArchitecture)"
Write-Report "  Install Date      : $($OS.InstallDate)"
Write-Report ""

# ── Section 2: Uptime ─────────────────────────────────────────────────────
Write-Report "  UPTIME" "Yellow"
Write-Report $SubSep "DarkGray"

$LastBoot = $OS.LastBootUpTime
$Uptime   = New-TimeSpan -Start $LastBoot -End (Get-Date)

Write-Report "  Last Boot         : $($LastBoot.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Report "  Uptime            : $($Uptime.Days)d $($Uptime.Hours)h $($Uptime.Minutes)m"

if ($Uptime.TotalDays -gt 30) {
    Write-Report "  ⚠ Machine has not been restarted in $([math]::Round($Uptime.TotalDays,0)) days." "Yellow"
    Write-Report "    Pending updates and memory issues are more likely on machines with long uptimes." "Yellow"
}
Write-Report ""

# ── Section 3: Hardware ───────────────────────────────────────────────────
Write-Report "  HARDWARE" "Yellow"
Write-Report $SubSep "DarkGray"

$CPU      = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue
# $RAM      = Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue |
            Measure-Object -Property Capacity -Sum
$RAMUsed  = $OS.TotalVisibleMemorySize - $OS.FreePhysicalMemory
$RAMPct   = [math]::Round(($RAMUsed / $OS.TotalVisibleMemorySize) * 100, 1)
$RAMGB    = [math]::Round($OS.TotalVisibleMemorySize / 1MB, 1)
$RAMUsedGB= [math]::Round($RAMUsed / 1MB, 1)

Write-Report "  CPU Model         : $($CPU.Name.Trim())"
Write-Report "  CPU Cores         : $($CPU.NumberOfCores) physical / $($CPU.NumberOfLogicalProcessors) logical"
Write-Report "  CPU Load Now      : $($CPU.LoadPercentage)%"

$CPUColour = if ($CPU.LoadPercentage -gt 90) { "Red" } elseif ($CPU.LoadPercentage -gt 70) { "Yellow" } else { "White" }
Write-Report "" $CPUColour

Write-Report "  Total RAM         : $RAMGB GB"
Write-Report "  RAM In Use        : $RAMUsedGB GB ($RAMPct%)"

$RAMColour = if ($RAMPct -gt 90) { "Red" } elseif ($RAMPct -gt 80) { "Yellow" } else { "White" }
if ($RAMPct -gt 80) {
    Write-Report "  ⚠ RAM utilisation is high ($RAMPct%)." $RAMColour
}
Write-Report ""

# ── Section 4: Disk Space ─────────────────────────────────────────────────
Write-Report "  DISK SPACE" "Yellow"
Write-Report $SubSep "DarkGray"

$Drives = Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue |
          Where-Object { $_.Used -ne $null -and $_.Used -gt 0 -and $_.Name.Length -eq 1 }

foreach ($Drive in $Drives) {
    $TotalGB = [math]::Round(($Drive.Used + $Drive.Free) / 1GB, 1)
    $FreeGB  = [math]::Round($Drive.Free / 1GB, 1)
    $FreePct = [math]::Round(($Drive.Free / ($Drive.Used + $Drive.Free)) * 100, 0)

    $DiskLine   = "  Drive $($Drive.Name):\ - Total: ${TotalGB}GB | Free: ${FreeGB}GB ($FreePct%)"
    $DiskColour = if ($FreePct -lt 10) { "Red" } elseif ($FreePct -lt 25) { "Yellow" } else { "White" }
    Write-Report $DiskLine $DiskColour
}
Write-Report ""

# ── Section 5: Network Configuration ─────────────────────────────────────
Write-Report "  NETWORK CONFIGURATION" "Yellow"
Write-Report $SubSep "DarkGray"

$ActiveAdapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }

if ($ActiveAdapters) {
    foreach ($Adapter in $ActiveAdapters) {
        $IPConfig = Get-NetIPConfiguration -InterfaceIndex $Adapter.InterfaceIndex -ErrorAction SilentlyContinue
        Write-Report "  Adapter   : $($Adapter.Name) — $($Adapter.InterfaceDescription)"
        Write-Report "  MAC       : $($Adapter.MacAddress)"
        Write-Report "  Link Speed: $($Adapter.LinkSpeed)"
        if ($IPConfig) {
            Write-Report "  IPv4      : $($IPConfig.IPv4Address.IPAddress)"
            Write-Report "  Gateway   : $($IPConfig.IPv4DefaultGateway.NextHop)"
            Write-Report "  DNS       : $($IPConfig.DnsServer.ServerAddresses -join ', ')"
        }
        Write-Report ""
    }
} else {
    Write-Report "  No active network adapters found." "Yellow"
    Write-Report ""
}

# ── Section 6: Recent System Errors ──────────────────────────────────────
Write-Report "  RECENT SYSTEM ERRORS (last 5 from System log)" "Yellow"
Write-Report $SubSep "DarkGray"

try {
    $SysErrors = Get-EventLog -LogName System -EntryType Error -Newest 5 -ErrorAction Stop
    if ($SysErrors) {
        foreach ($Event in $SysErrors) {
            Write-Report "  [$($Event.TimeGenerated.ToString('yyyy-MM-dd HH:mm'))] Source: $($Event.Source)"
            $ShortMsg = if ($Event.Message.Length -gt 120) {
                $Event.Message.Substring(0, 120) + "..."
            } else {
                $Event.Message
            }
            Write-Report "    $ShortMsg" "DarkGray"
        }
    } else {
        Write-Report "  No recent System errors found." "Green"
    }
} catch {
    Write-Report "  Could not read System event log: $($_.Exception.Message)" "Yellow"
}
Write-Report ""

# ── Section 7: Top 10 CPU Processes ──────────────────────────────────────
Write-Report "  TOP 10 CPU-CONSUMING PROCESSES" "Yellow"
Write-Report $SubSep "DarkGray"

$Processes = Get-Process | Sort-Object CPU -Descending | Select-Object -First 10
$ProcHeader = "  {0,-30} {1,10} {2,12}" -f "Process Name", "CPU (s)", "Memory (MB)"
Write-Report $ProcHeader "White"

foreach ($Proc in $Processes) {
    $MemMB   = [math]::Round($Proc.WorkingSet64 / 1MB, 1)
    $CPUSecs = [math]::Round($Proc.CPU, 1)
    $ProcLine = "  {0,-30} {1,10} {2,12}" -f $Proc.Name, $CPUSecs, $MemMB
    Write-Report $ProcLine
}
Write-Report ""

Write-Report $Sep "Cyan"
Write-Report "  END OF REPORT" "Cyan"
Write-Report $Sep "Cyan"
Write-Report ""

# ── Save to file if requested ─────────────────────────────────────────────
if ($OutputFile -ne "") {
    try {
        $OutputDir = Split-Path $OutputFile -Parent
        if ($OutputDir -and -not (Test-Path $OutputDir)) {
            New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        }
        $OutputLines | Set-Content -Path $OutputFile -Encoding UTF8
        Write-Host "  Report saved to: $OutputFile" -ForegroundColor Cyan
    } catch {
        Write-Host "  WARNING: Could not save report to file: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}


