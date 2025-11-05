# generate-multidomain-ssl.ps1
# Generates a local multi-domain SSL certificate for Docker Apache setup.
# Works natively on Windows with OpenSSL 3+.
# Requires: PowerShell 5+, OpenSSL available in PATH.

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$BaseDir   = Resolve-Path "$ScriptDir\.."
$Projects  = "$BaseDir\config\projects"
$SslDir    = "$BaseDir\config\apache\ssl"

$ListMain  = "$Projects\domains.conf"
$ListLocal = "$Projects\domains.local.conf"

$CrtFile = "$SslDir\dev.crt"
$KeyFile = "$SslDir\dev.key"

New-Item -ItemType Directory -Force -Path $SslDir | Out-Null

# --- Functions ---
function Get-Domains($file) {
    if (-not (Test-Path $file)) { return @() }
    $lines = Get-Content -Encoding UTF8 $file
    $validDomains = @()
    foreach ($line in $lines) {
        # Skip comments, empty lines, or malformed entries
        if ($line -match '^[a-zA-Z0-9\.-]+\s*,\s*.+$') {
            $domain = ($line.Split(',')[0]).Trim()
            if ($domain -and $domain -match '^[a-zA-Z0-9.-]+$') {
                $validDomains += $domain
            }
        }
    }
    return ,$validDomains
}

# --- Collect domains safely ---
[string[]]$domains = @()

$mainDomains = @(Get-Domains $ListMain)
$localDomains = @(Get-Domains $ListLocal)

if ($mainDomains.Count -gt 0) { $domains += $mainDomains }
if ($localDomains.Count -gt 0) { $domains += $localDomains }

# Filter valid entries only
$domains = $domains | Where-Object { $_ -match '^[a-zA-Z0-9.-]+$' } | Sort-Object -Unique

if (-not $domains -or $domains.Count -eq 0) {
    Write-Host "[WARN] No domains found in domains.conf or domains.local.conf"
    Write-Host "       Certificate generation skipped."
    exit 0
}

$Primary = $domains[0]
$san = ($domains | ForEach-Object { "DNS:$($_)" }) -join ","

# --- Verify OpenSSL presence ---
if (-not (Get-Command openssl -ErrorAction SilentlyContinue)) {
    Write-Host "[WARN] OpenSSL not found in PATH. Skipping SSL generation."
    Write-Host "       Install OpenSSL or rerun this script later."
    exit 0
}

# --- Generate certificate ---
Write-Host "Generating SSL certificate for: $Primary"
try {
    & openssl req -x509 -nodes -days 3650 `
        -newkey rsa:2048 `
        -keyout $KeyFile `
        -out $CrtFile `
        -subj "/CN=$Primary" `
        -addext "subjectAltName=$san" 2>&1 | Out-Null

    if ($LASTEXITCODE -ne 0) {
        throw "OpenSSL returned exit code $LASTEXITCODE"
    }

    if (-not (Test-Path $CrtFile) -or (Get-Item $CrtFile).Length -eq 0) {
        throw "Certificate file not created."
    }
    if (-not (Test-Path $KeyFile) -or (Get-Item $KeyFile).Length -eq 0) {
        throw "Key file not created."
    }

    Write-Host "[OK] Successfully generated multi-domain SSL cert:"
    Write-Host " - $CrtFile"
    Write-Host " - $KeyFile"
}
catch {
    Write-Host "[ERROR] SSL generation failed: $($_.Exception.Message)"
    exit 1
}
