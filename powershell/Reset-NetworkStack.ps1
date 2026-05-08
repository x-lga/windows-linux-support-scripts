<# **What ticket this solves:** Network connectivity failures that persist after all
standard L1 steps (DNS flush, ipconfig /release /renew, cable check) have been
attempted. A corrupt Winsock catalog or TCP/IP stack requires a stack reset to
restore normal network function. This is a last resort before escalating.

**Why this script has a confirmation step:** The reset requires a restart to take
effect, and the commands are irreversible without a restart. Running this on a
server that cannot be restarted immediately would be harmful. The script requires
explicit confirmation before executing and warns clearly that a restart is required.

**Cert alignment:** CompTIA A+, CompTIA Network+


#>

```powershell
<#
.SYNOPSIS
    Performs a complete Windows TCP/IP and Winsock network stack reset.

.DESCRIPTION
    This is a last-resort network repair script. Use it when standard L1 steps
    have all failed and network connectivity remains broken:
      - DNS flush (ipconfig /flushdns) did not help
      - DHCP release/renew did not get a valid IP
      - Winsock reset did not resolve the issue when run manually
      - Network worked after restart but the issue keeps recurring

    The script executes this sequence:
      1. Displays all current IP configuration for documentation
      2. Requires explicit user confirmation (RESET) before proceeding
      3. Resets the Winsock catalog to factory state
      4. Resets the TCP/IP stack to factory state
      5. Flushes DNS cache
      6. Releases DHCP lease
      7. Renews DHCP lease
      8. Flushes ARP cache
      9. Reports completion and reminds technician to restart

    IMPORTANT: A system restart is required for these changes to take effect.
    Warn the user before running this script.

.PARAMETER SkipConfirmation
    Switch. If specified, skips the interactive confirmation prompt.
    Use only in automated scenarios where you have already confirmed the action
    is appropriate.

.EXAMPLE
    .\Reset-NetworkStack.ps1
    # Interactive mode — prompts for confirmation before proceeding

.EXAMPLE
    .\Reset-NetworkStack.ps1 -SkipConfirmation
    # Non-interactive mode — use only when sure this is appropriate

.NOTES
    Requires  : Administrator privileges
    Restart   : REQUIRED after running — changes do not take effect until restart
    Tested on : Windows 10 22H2, Windows 11 23H2, Windows Server 2022
    Cert align: CompTIA A+, CompTIA Network+
    CAUTION   : This is a last-resort step. Ensure all other options are exhausted first.
#>

param(
    [Parameter(Mandatory = $false)]
    [switch]$SkipConfirmation
)

Write-Host ""
Write-Host "═══════════════════════════════════════════" -ForegroundColor Red
Write-Host "  NETWORK STACK RESET — LAST RESORT TOOL" -ForegroundColor Red
Write-Host "═══════════════════════════════════════════" -ForegroundColor Red
Write-Host ""
Write-Host "  This script resets the Windows TCP/IP stack and Winsock catalog." -ForegroundColor Yellow
Write-Host "  A SYSTEM RESTART IS REQUIRED after this script completes." -ForegroundColor Yellow
Write-Host "  Changes do not take effect until the machine is restarted." -ForegroundColor Yellow
Write-Host ""
Write-Host "  Only run this after these steps have already been attempted:" -ForegroundColor White
Write-Host "    ✓ Checked physical connection (cable, NIC lights)" -ForegroundColor White
Write-Host "    ✓ Ran: ipconfig /flushdns" -ForegroundColor White
Write-Host "    ✓ Ran: ipconfig /release and ipconfig /renew" -ForegroundColor White
Write-Host "    ✓ Checked DNS server reachability" -ForegroundColor White
Write-Host "    ✓ Issue persists after a normal restart" -ForegroundColor White
Write-Host ""

# ── Document current IP configuration before reset ────────────────────────
Write-Host "CURRENT IP CONFIGURATION (before reset):" -ForegroundColor Cyan
Write-Host "─────────────────────────────────────────" -ForegroundColor DarkGray

$Adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
foreach ($Adapter in $Adapters) {
    $IPConfig = Get-NetIPConfiguration -InterfaceIndex $Adapter.InterfaceIndex -ErrorAction SilentlyContinue
    if ($IPConfig) {
        Write-Host "  Adapter   : $($Adapter.Name) ($($Adapter.InterfaceDescription))"
        Write-Host "  IPv4      : $($IPConfig.IPv4Address.IPAddress)"
        Write-Host "  Gateway   : $($IPConfig.IPv4DefaultGateway.NextHop)"
        Write-Host "  DNS       : $($IPConfig.DnsServer.ServerAddresses -join ', ')"
        Write-Host ""
    }
}

# ── Confirmation step ─────────────────────────────────────────────────────
if (-not $SkipConfirmation) {
    Write-Host "─────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  TYPE 'RESET' AND PRESS ENTER TO PROCEED" -ForegroundColor Red
    Write-Host "  Type anything else or press Enter to cancel." -ForegroundColor Yellow
    Write-Host ""
    $Confirmation = Read-Host "  Confirm"

    if ($Confirmation -ne "RESET") {
        Write-Host ""
        Write-Host "  Reset cancelled. No changes were made." -ForegroundColor Green
        exit 0
    }
}

Write-Host ""
Write-Host "  Proceeding with network stack reset..." -ForegroundColor White
Write-Host ""

# ── Execute reset commands ────────────────────────────────────────────────
$Steps = @(
    @{ Name = "Reset Winsock catalog";   Command = "netsh winsock reset" },
    @{ Name = "Reset TCP/IP stack";      Command = "netsh int ip reset" },
    @{ Name = "Reset IPv6 stack";        Command = "netsh int ipv6 reset" },
    @{ Name = "Flush DNS cache";         Command = "ipconfig /flushdns" },
    @{ Name = "Release DHCP lease";      Command = "ipconfig /release" },
    @{ Name = "Renew DHCP lease";        Command = "ipconfig /renew" },
    @{ Name = "Flush ARP cache";         Command = "arp -d *" }
)

$StepNumber = 1
foreach ($Step in $Steps) {
    Write-Host "[$StepNumber/$($Steps.Count)] $($Step.Name)..." -ForegroundColor White
    try {
        $Output = cmd /c $Step.Command 2>&1
        Write-Host "  Done." -ForegroundColor Green
    } catch {
        Write-Host "  Warning: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    $StepNumber++
}

# ── Summary and restart reminder ─────────────────────────────────────────
Write-Host ""
Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  RESET COMPLETE" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  ALL STEPS COMPLETED. THE MACHINE MUST NOW BE RESTARTED." -ForegroundColor Red
Write-Host ""
Write-Host "  Before restarting, save all open documents." -ForegroundColor Yellow
Write-Host "  After restart, test network connectivity with:" -ForegroundColor White
Write-Host "    ping 127.0.0.1      (TCP/IP stack)"  -ForegroundColor White
Write-Host "    ping <gateway IP>   (local network)" -ForegroundColor White
Write-Host "    ping 8.8.8.8        (internet routing)" -ForegroundColor White
Write-Host "    ping google.com     (DNS resolution)" -ForegroundColor White
Write-Host ""
Write-Host "  If connectivity is still broken after restart: escalate to L2." -ForegroundColor Yellow
Write-Host ""
```
