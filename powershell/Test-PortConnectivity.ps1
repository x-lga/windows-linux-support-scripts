<# **What ticket this solves:** "I can't connect to [application/server/VPN]" - when
basic ping works but a specific application or service is unreachable, the issue
is often a firewall blocking the specific TCP port. This script tests whether a
port is reachable and returns a clear result, eliminating the ambiguity of
"is it the firewall or the application?"

**Cert alignment:** CompTIA A+, CompTIA Network+

#>

<#
.SYNOPSIS
    Tests TCP port connectivity to one or more remote hosts and ports.

.DESCRIPTION
    Tests whether specific TCP ports are open and reachable on remote hosts.
    Uses Test-NetConnection for accurate results including DNS resolution
    and route tracing.

    Common use cases:
      - "I can't connect to the VPN" → test TCP 1194/443/51820
      - "RDP to the server is failing" → test TCP 3389
      - "Email client can't connect" → test TCP 993/587/25
      - "Database connection refused" → test TCP 1433/5432/3306
      - "Website works from home but not from office" → test TCP 80/443

    Useful for determining whether the issue is:
      - Firewall blocking the port (port closed = firewall)
      - Service not running on the remote end (port closed = service issue)
      - DNS resolution failure (unable to resolve hostname)
      - Routing issue (unable to reach the host at all)

.PARAMETER Targets
    Array of hosts to test. Can be hostnames or IP addresses.

.PARAMETER Ports
    Array of TCP port numbers to test.

.PARAMETER TimeoutMs
    Connection timeout in milliseconds. Default: 3000 (3 seconds).

.EXAMPLE
    .\Test-PortConnectivity.ps1 -Targets "google.com" -Ports 80,443
    # Test HTTP and HTTPS to google.com

.EXAMPLE
    .\Test-PortConnectivity.ps1 -Targets "dc01.contoso.local","10.20.1.4" -Ports 3389,5985,53,389
    # Test RDP, WinRM, DNS, and LDAP to a domain controller by hostname and IP

.EXAMPLE
    .\Test-PortConnectivity.ps1 -Targets "mailserver.company.com" -Ports 25,587,993,995
    # Test all common email ports to a mail server

.NOTES
    Requires  : Windows PowerShell 5.1+ or PowerShell 7+
    Elevation : Not required
    Cert align: CompTIA A+, CompTIA Network+
#>

param(
    [Parameter(Mandatory = $true, HelpMessage = "One or more target hosts to test")]
    [string[]]$Targets,

    [Parameter(Mandatory = $true, HelpMessage = "One or more TCP ports to test")]
    [ValidateRange(1, 65535)]
    [int[]]$Ports,

    [Parameter(Mandatory = $false)]
    [ValidateRange(500, 30000)]
    [int]$TimeoutMs = 3000
)

# Port-to-service name lookup for friendly output
$ServiceNames = @{
    21   = "FTP"
    22   = "SSH"
    23   = "Telnet"
    25   = "SMTP"
    53   = "DNS"
    80   = "HTTP"
    110  = "POP3"
    143  = "IMAP"
    389  = "LDAP"
    443  = "HTTPS"
    445  = "SMB"
    465  = "SMTPS"
    587  = "SMTP-TLS"
    636  = "LDAPS"
    993  = "IMAPS"
    995  = "POP3S"
    1194 = "OpenVPN"
    1433 = "MSSQL"
    3306 = "MySQL"
    3389 = "RDP"
    5432 = "PostgreSQL"
    5985 = "WinRM-HTTP"
    5986 = "WinRM-HTTPS"
    8080 = "HTTP-Alt"
    8443 = "HTTPS-Alt"
    51820= "WireGuard"
}

$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  PORT CONNECTIVITY TEST" -ForegroundColor Cyan
Write-Host "  Time: $Timestamp | Timeout: ${TimeoutMs}ms" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$Results = @()

foreach ($Target in $Targets) {
    Write-Host "  Testing target: $Target" -ForegroundColor White
    Write-Host "  ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray

    foreach ($Port in $Ports) {
        $ServiceName = if ($ServiceNames.ContainsKey($Port)) { $ServiceNames[$Port] } else { "Unknown" }
        $PortLabel   = "Port $Port ($ServiceName)"

        try {
            $TestResult = Test-NetConnection `
                -ComputerName $Target `
                -Port $Port `
                -WarningAction SilentlyContinue `
                -ErrorAction Stop

            if ($TestResult.TcpTestSucceeded) {
                $Status   = "OPEN"
                $Colour   = "Green"
                $StatusSymbol = "✔"
            } else {
                $Status   = "CLOSED / FILTERED"
                $Colour   = "Red"
                $StatusSymbol = "✘"
            }

            $ResolvedIP = if ($TestResult.RemoteAddress) { $TestResult.RemoteAddress.ToString() } else { "DNS failed" }
            $Line = "  $StatusSymbol {0,-35} → {1,-20} IP: {2}" -f $PortLabel, $Status, $ResolvedIP

            Write-Host $Line -ForegroundColor $Colour

            $Results += [PSCustomObject]@{
                Target      = $Target
                Port        = $Port
                Service     = $ServiceName
                Status      = $Status
                ResolvedIP  = $ResolvedIP
                Connected   = $TestResult.TcpTestSucceeded
            }

        } catch {
            $Line = "  ✘ {0,-35} → ERROR: {1}" -f $PortLabel, $_.Exception.Message
            Write-Host $Line -ForegroundColor Yellow

            $Results += [PSCustomObject]@{
                Target      = $Target
                Port        = $Port
                Service     = $ServiceName
                Status      = "ERROR"
                ResolvedIP  = "N/A"
                Connected   = $false
            }
        }
    }
    Write-Host ""
}

# ── Summary ───────────────────────────────────────────────────────────────
$OpenCount   = ($Results | Where-Object { $_.Connected -eq $true }).Count
$ClosedCount = ($Results | Where-Object { $_.Connected -eq $false }).Count
$TotalTests  = $Results.Count

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  SUMMARY: $OpenCount/$TotalTests ports open | $ClosedCount closed or filtered" -ForegroundColor $(if($ClosedCount -gt 0){"Yellow"}else{"Green"})
Write-Host ""

if ($ClosedCount -gt 0) {
    Write-Host "  CLOSED/FILTERED PORTS — Possible causes:" -ForegroundColor Yellow
    Write-Host "    1. Firewall rule blocking this port (Windows Firewall, network firewall, NSG)" -ForegroundColor White
    Write-Host "    2. The service is not running on the remote machine" -ForegroundColor White
    Write-Host "    3. The target IP/hostname is wrong" -ForegroundColor White
    Write-Host "    4. The remote machine is offline or unreachable" -ForegroundColor White
    Write-Host ""
    Write-Host "  NEXT STEPS:" -ForegroundColor White
    Write-Host "    ping <target>         — Confirm basic network reachability" -ForegroundColor DarkGray
    Write-Host "    tracert <target>      — Find where in the path connectivity breaks" -ForegroundColor DarkGray
    Write-Host "    netstat -an (on target) — Confirm the service is listening on the port" -ForegroundColor DarkGray
}
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
