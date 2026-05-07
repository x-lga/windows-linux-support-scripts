**What ticket this solves:** "Website won't load" or "I can't reach [internal resource]
by name" - often caused by a stale or corrupt DNS cache entry pointing to an old IP
address. A DNS flush clears the local resolver cache and forces the machine to query
the DNS server fresh on the next lookup.

<# **Why this is more than just `ipconfig /flushdns`:** This script checks whether
the flush succeeded by verifying the cache is empty afterwards, catches the case
where the DNS Client service is not running (which prevents flushing), provides
clear output with a confirmation test, and is safe to run on any machine without
elevated privileges for the flush operation itself. #>

**Cert alignment:** CompTIA A+, CompTIA Network+

```powershell
<#
.SYNOPSIS
    Flushes the local DNS resolver cache and verifies the flush succeeded.

.DESCRIPTION
    Clears the Windows DNS resolver cache — the most common first step when a
    user reports that a website or internal hostname is resolving to the wrong IP
    address or not resolving at all.

    The script:
      - Checks that the DNS Client service is running (required for flush to work)
      - Clears the DNS resolver cache using Clear-DnsClientCache
      - Verifies the cache is empty after flushing
      - Tests resolution of a specified hostname to confirm DNS is working
      - Provides clear colour-coded output at every step

    Common ticket types resolved by this script:
      - "Website says connection refused but it worked yesterday"
      - "Internal server not found by name but IP address works"
      - "DNS record was updated but old IP is still being used"
      - Mapped drive disconnecting because server IP changed

.PARAMETER TestHostname
    Optional. A hostname to resolve after the flush to confirm DNS is working.
    Defaults to "google.com" as a public resolution test.
    Change to an internal hostname (e.g., dc01.contoso.local) for internal testing.

.EXAMPLE
    .\Flush-DNS.ps1
    # Flush DNS and test resolution of google.com (default)

.EXAMPLE
    .\Flush-DNS.ps1 -TestHostname "dc01.contoso.local"
    # Flush DNS and test resolution of an internal domain controller

.NOTES
    Requires  : Windows Vista / Server 2008 or later
    Run as    : Standard user (no elevation required for DNS flush)
    Tested on : Windows 10 22H2, Windows 11 23H2, Windows Server 2022
    Cert align: CompTIA A+, CompTIA Network+
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$TestHostname = "google.com"
)

Write-Host ""
Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  DNS RESOLVER CACHE FLUSH" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# ── Step 1: Check DNS Client service is running ──────────────────────────
Write-Host "[1/4] Checking DNS Client service status..." -ForegroundColor White

$DnsService = Get-Service -Name "Dnscache" -ErrorAction SilentlyContinue

if (-not $DnsService) {
    Write-Host "  ERROR: DNS Client service (Dnscache) not found on this machine." -ForegroundColor Red
    Write-Host "  This is unexpected on a standard Windows installation." -ForegroundColor Yellow
    exit 1
}

if ($DnsService.Status -ne "Running") {
    Write-Host "  WARNING: DNS Client service is not running (Status: $($DnsService.Status))." -ForegroundColor Yellow
    Write-Host "  Attempting to start the DNS Client service..." -ForegroundColor Yellow
    try {
        Start-Service -Name "Dnscache" -ErrorAction Stop
        Start-Sleep -Seconds 2
        Write-Host "  DNS Client service started successfully." -ForegroundColor Green
    } catch {
        Write-Host "  ERROR: Could not start DNS Client service: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  DNS flush requires the DNS Client service to be running." -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "  DNS Client service is running." -ForegroundColor Green
}

# ── Step 2: Count current cache entries before flush ─────────────────────
Write-Host ""
Write-Host "[2/4] Counting current DNS cache entries..." -ForegroundColor White

$CacheBefore = Get-DnsClientCache -ErrorAction SilentlyContinue
$CacheCount  = if ($CacheBefore) { $CacheBefore.Count } else { 0 }
Write-Host "  Current cache entries: $CacheCount" -ForegroundColor Cyan

# ── Step 3: Flush the DNS cache ───────────────────────────────────────────
Write-Host ""
Write-Host "[3/4] Flushing DNS resolver cache..." -ForegroundColor White

try {
    Clear-DnsClientCache -ErrorAction Stop
    Start-Sleep -Milliseconds 500

    # Verify the cache is empty
    $CacheAfter = Get-DnsClientCache -ErrorAction SilentlyContinue
    $CacheAfterCount = if ($CacheAfter) { $CacheAfter.Count } else { 0 }

    if ($CacheAfterCount -eq 0) {
        Write-Host "  DNS cache flushed successfully." -ForegroundColor Green
        Write-Host "  Cache entries cleared: $CacheCount → $CacheAfterCount" -ForegroundColor Green
    } else {
        Write-Host "  WARNING: Cache may not have fully cleared." -ForegroundColor Yellow
        Write-Host "  Entries remaining: $CacheAfterCount (some system entries may persist)" -ForegroundColor Yellow
    }

} catch {
    Write-Host "  ERROR: DNS flush failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# ── Step 4: Test DNS resolution ───────────────────────────────────────────
Write-Host ""
Write-Host "[4/4] Testing DNS resolution for: $TestHostname" -ForegroundColor White

try {
    $Resolution = Resolve-DnsName -Name $TestHostname -ErrorAction Stop
    $ResolvedIPs = $Resolution | Where-Object { $_.Type -in @("A", "AAAA") } |
                   Select-Object -ExpandProperty IPAddress

    if ($ResolvedIPs) {
        Write-Host "  Resolution succeeded." -ForegroundColor Green
        Write-Host "  $TestHostname resolves to: $($ResolvedIPs -join ', ')" -ForegroundColor Green
    } else {
        Write-Host "  Hostname resolved but returned no A/AAAA records." -ForegroundColor Yellow
    }

} catch {
    Write-Host "  WARNING: Resolution test failed for '$TestHostname'." -ForegroundColor Yellow
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "  The DNS flush completed — the resolution test failure may indicate:" -ForegroundColor Yellow
    Write-Host "    - The hostname does not exist" -ForegroundColor Yellow
    Write-Host "    - No network connectivity" -ForegroundColor Yellow
    Write-Host "    - DNS server is unreachable" -ForegroundColor Yellow
}

# ── Summary ───────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  COMPLETE — DNS cache has been flushed." -ForegroundColor Green
Write-Host ""
Write-Host "  NEXT STEPS FOR THE TECHNICIAN:" -ForegroundColor White
Write-Host "  - Ask the user to retry the operation that was failing" -ForegroundColor White
Write-Host "  - If the issue persists: check if 8.8.8.8 is reachable (ping 8.8.8.8)" -ForegroundColor White
Write-Host "  - If ping to IP works but hostname fails: DNS server may be down" -ForegroundColor White
Write-Host "    Run: nslookup $TestHostname" -ForegroundColor White
Write-Host "    and: Test-NetConnection -ComputerName <dns-server-ip> -Port 53" -ForegroundColor White
Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
```


