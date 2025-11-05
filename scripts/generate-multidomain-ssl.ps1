# generate-multidomain-ssl.ps1
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$BaseDir = Resolve-Path "$ScriptDir\.."
$ProjectsDir = "$BaseDir\config\projects"
$SslDir = "$BaseDir\config\apache\ssl"

$ListMain = "$ProjectsDir\domains.conf"
$ListLocal = "$ProjectsDir\domains.local.conf"

$CrtFile = "$SslDir\dev.crt"
$KeyFile = "$SslDir\dev.key"

New-Item -ItemType Directory -Force -Path $SslDir | Out-Null

function Get-Domains($file) {
  if (-Not (Test-Path $file)) { return @() }
  $lines = Get-Content $file | Where-Object {$_ -notmatch '^\s*#' -and $_ -match ','}
  foreach ($line in $lines) {
    $parts = $line -split ','
    if ($parts.Count -ge 2 -and $parts[0].Trim() -ne '') {
      $parts[0].Trim()
    }
  }
}

$domains = @(Get-Domains $ListMain) + @(Get-Domains $ListLocal) | Sort-Object -Unique
if ($domains.Count -eq 0) {
  Write-Host "No domains found. Aborting certificate generation."
  exit 1
}
$Primary = $domains[0]

$tmpConf = New-TemporaryFile
$conf = @"
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[dn]
CN = $Primary

[req_ext]
subjectAltName = @alt_names

[alt_names]
"@
$i = 1
foreach ($d in $domains) {
  $conf += "DNS.$i = $d`n"
  $i++
}
$conf | Out-File -FilePath $tmpConf -Encoding ascii -NoNewline

# Ensure openssl exists
if (-not (Get-Command openssl -ErrorAction SilentlyContinue)) {
  Write-Host "OpenSSL not found. Install it and rerun."
  exit 1
}

# Generate the certificate
& openssl req -x509 -nodes -days 3650 `
  -newkey rsa:2048 `
  -keyout $KeyFile `
  -out $CrtFile `
  -config $tmpConf `
  -extensions req_ext | Out-Null

Remove-Item $tmpConf -Force

Write-Host "[OK] Successfully generated multi-domain SSL cert:"
Write-Host " - $CrtFile"
Write-Host " - $KeyFile"
