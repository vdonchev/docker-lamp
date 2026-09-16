param(
    [switch]$RotateCa
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$BaseDir = (Resolve-Path "$ScriptDir\..").Path
$ProjectsDir = Join-Path $BaseDir "config\projects"
$SslDir = Join-Path $BaseDir "config\apache\ssl"
$CaDir = Join-Path $BaseDir "var\local-ca"

$ListMain = Join-Path $ProjectsDir "domains.conf"
$ListLocal = Join-Path $ProjectsDir "domains.local.conf"
$CaCertFile = Join-Path $CaDir "dev-ca.crt"
$CaKeyFile = Join-Path $CaDir "dev-ca.key"
$CaSerialFile = Join-Path $CaDir "dev-ca.srl"
$PublicCaFile = Join-Path $SslDir "dev-ca.crt"
$CrtFile = Join-Path $SslDir "dev.crt"
$KeyFile = Join-Path $SslDir "dev.key"

if (-not (Get-Command openssl -ErrorAction SilentlyContinue)) {
    throw "OpenSSL is required to generate local certificates."
}

New-Item -ItemType Directory -Force -Path $SslDir, $CaDir | Out-Null
$TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("docker-lamp-ca-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $TempDir | Out-Null

function Invoke-OpenSsl {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    & openssl @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "OpenSSL returned exit code $LASTEXITCODE."
    }
}

function Protect-PrivateKey([string]$Path) {
    if ($env:OS -ne "Windows_NT") { return }

    $acl = New-Object System.Security.AccessControl.FileSecurity
    $acl.SetAccessRuleProtection($true, $false)
    $identities = @(
        [System.Security.Principal.WindowsIdentity]::GetCurrent().User,
        (New-Object System.Security.Principal.SecurityIdentifier("S-1-5-18")),
        (New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544"))
    )
    foreach ($identity in $identities) {
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $identity,
            [System.Security.AccessControl.FileSystemRights]::FullControl,
            [System.Security.AccessControl.AccessControlType]::Allow
        )
        $acl.AddAccessRule($rule) | Out-Null
    }
    Set-Acl -LiteralPath $Path -AclObject $acl
}

function Test-Domain([string]$Domain) {
    if ($Domain.Length -gt 253 -or $Domain.StartsWith('.') -or $Domain.EndsWith('.') -or $Domain.Contains('..')) {
        return $false
    }
    foreach ($label in $Domain.Split('.')) {
        if ($label.Length -gt 63 -or $label -notmatch '^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$') {
            return $false
        }
    }
    return $true
}

function Get-Domains([string]$File) {
    if (-not (Test-Path $File)) { return @() }
    $result = @()
    foreach ($line in Get-Content -Encoding UTF8 $File) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line -match '^\s*#') { continue }
        $parts = $line.Split(',', 3)
        if ($parts.Count -lt 2) { continue }
        $domain = $parts[0].Trim().ToLowerInvariant()
        $path = $parts[1].Trim()
        if (-not $domain -or -not $path) { continue }
        if (-not (Test-Domain $domain)) {
            throw "Invalid domain in ${File}: $domain"
        }
        $result += $domain
    }
    return $result
}

function Test-CaPair {
    try {
        & openssl x509 -in $CaCertFile -noout -checkend 71366400 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { return $false }
        $details = (& openssl x509 -in $CaCertFile -noout -text 2>$null) -join "`n"
        if ($LASTEXITCODE -ne 0 -or $details -notmatch 'CA:TRUE') { return $false }
        $certPublicKey = (& openssl x509 -in $CaCertFile -pubkey -noout 2>$null) -join "`n"
        $privatePublicKey = (& openssl pkey -in $CaKeyFile -pubout 2>$null) -join "`n"
        return $LASTEXITCODE -eq 0 -and $certPublicKey -eq $privatePublicKey
    } catch {
        return $false
    }
}

$PublishStarted = $false
$PublishBackups = @()
try {
    [string[]]$Domains = @((Get-Domains $ListMain) + (Get-Domains $ListLocal) | Sort-Object -Unique)
    if ($Domains.Count -eq 0) {
        throw "No valid domains found in domains.conf or domains.local.conf."
    }
    $PrimaryDomain = $Domains[0]

    $GenerateCa = [bool]$RotateCa
    if ($RotateCa) {
        Write-Host "[WARN] Rotating the local CA invalidates existing host trust and all issued certificates."
        $confirmation = Read-Host "Type ROTATE to continue"
        if ($confirmation -cne "ROTATE") { throw "CA rotation cancelled." }
    }

    $caCertExists = Test-Path $CaCertFile
    $caKeyExists = Test-Path $CaKeyFile
    if (-not $GenerateCa -and ($caCertExists -or $caKeyExists)) {
        if (-not $caCertExists -or -not $caKeyExists) {
            throw "Partial local CA state found in $CaDir; restore or remove it explicitly."
        }
        if (-not (Test-CaPair)) {
            throw "The existing local CA is invalid, mismatched, or expires too soon; rotate it explicitly."
        }
        Protect-PrivateKey $CaKeyFile
        Write-Host "[OK] Reusing persistent local CA: $CaCertFile"
    } elseif (-not $GenerateCa) {
        $GenerateCa = $true
    }

    if ($GenerateCa) {
        $caConfig = Join-Path $TempDir "ca.cnf"
        @"
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
x509_extensions = ca_ext

[dn]
CN = Docker LAMP Development CA

[ca_ext]
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
"@ | Set-Content -Encoding ASCII $caConfig

        $tempCaKey = Join-Path $TempDir "dev-ca.key"
        $tempCaCert = Join-Path $TempDir "dev-ca.crt"
        Invoke-OpenSsl req -x509 -new -nodes -days 3650 -newkey rsa:2048 -keyout $tempCaKey -out $tempCaCert -config $caConfig
        $SigningCaCert = $tempCaCert
        $SigningCaKey = $tempCaKey
        $SigningCaSerial = Join-Path $TempDir "dev-ca.srl"
    } else {
        $SigningCaCert = $CaCertFile
        $SigningCaKey = $CaKeyFile
        $SigningCaSerial = Join-Path $TempDir "dev-ca.srl"
        if (Test-Path $CaSerialFile) { Copy-Item $CaSerialFile $SigningCaSerial }
    }

    $leafConfig = Join-Path $TempDir "leaf.cnf"
    $altNames = for ($i = 0; $i -lt $Domains.Count; $i++) { "DNS.$($i + 1) = $($Domains[$i])" }
    @"
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[dn]
CN = $PrimaryDomain

[req_ext]
subjectAltName = @alt_names

[leaf_ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
subjectAltName = @alt_names

[alt_names]
$($altNames -join "`r`n")
"@ | Set-Content -Encoding ASCII $leafConfig

    $tempKey = Join-Path $TempDir "dev.key"
    $tempCsr = Join-Path $TempDir "dev.csr"
    $tempCert = Join-Path $TempDir "dev.crt"
    Invoke-OpenSsl req -new -nodes -newkey rsa:2048 -keyout $tempKey -out $tempCsr -config $leafConfig

    $serialArgs = @('-CAserial', $SigningCaSerial)
    if (-not (Test-Path $SigningCaSerial)) { $serialArgs += '-CAcreateserial' }
    Invoke-OpenSsl x509 -req -days 825 -sha256 -in $tempCsr -CA $SigningCaCert -CAkey $SigningCaKey @serialArgs -extfile $leafConfig -extensions leaf_ext -out $tempCert
    Invoke-OpenSsl verify -CAfile $SigningCaCert -purpose sslserver $tempCert

    $tempPublicCa = Join-Path $TempDir "public-dev-ca.crt"
    Copy-Item $SigningCaCert $tempPublicCa
    $backupDir = Join-Path $TempDir "backups"
    New-Item -ItemType Directory -Path $backupDir | Out-Null
    $publishPaths = @($CaKeyFile, $CaCertFile, $CaSerialFile, $KeyFile, $CrtFile, $PublicCaFile)
    for ($i = 0; $i -lt $publishPaths.Count; $i++) {
        $backup = Join-Path $backupDir $i
        $exists = Test-Path $publishPaths[$i]
        if ($exists) { Copy-Item $publishPaths[$i] $backup }
        $PublishBackups += [PSCustomObject]@{ Path = $publishPaths[$i]; Backup = $backup; Existed = $exists }
    }
    $PublishStarted = $true

    if ($GenerateCa) {
        Move-Item -Force $tempCaKey $CaKeyFile
        Move-Item -Force $tempCaCert $CaCertFile
        Protect-PrivateKey $CaKeyFile
        Write-Host "[OK] Created persistent local CA: $CaCertFile"
    }
    Move-Item -Force $SigningCaSerial $CaSerialFile
    Move-Item -Force $tempKey $KeyFile
    Protect-PrivateKey $KeyFile
    Move-Item -Force $tempCert $CrtFile
    Move-Item -Force $tempPublicCa $PublicCaFile
    $PublishStarted = $false

    Write-Host "[OK] Generated CA-signed multi-domain certificate:"
    Write-Host " - $CrtFile"
    Write-Host " - $KeyFile"
    Write-Host "[OK] Public CA certificate:"
    Write-Host " - $PublicCaFile"
} catch {
    if ($PublishStarted) {
        Write-Host "[ERROR] Publication failed; restoring the previous certificate set."
        foreach ($item in $PublishBackups) {
            Remove-Item -Force -ErrorAction SilentlyContinue $item.Path
            if ($item.Existed) { Copy-Item -Force $item.Backup $item.Path }
        }
    }
    Write-Host "[ERROR] Certificate generation failed: $($_.Exception.Message)"
    exit 1
} finally {
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $TempDir
}
