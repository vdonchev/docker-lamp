param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("install", "remove")]
    [string]$Action,

    [Parameter(Mandatory = $true)]
    [string]$CertificatePath
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $CertificatePath -PathType Leaf)) {
    throw "CA certificate not found: $CertificatePath. Generate it first."
}

$Certificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertificatePath)
if ($Action -eq "install") {
    $BasicConstraints = $Certificate.Extensions | Where-Object { $_.Oid.Value -eq "2.5.29.19" }
    $KeyUsage = $Certificate.Extensions | Where-Object { $_.Oid.Value -eq "2.5.29.15" }
    if (-not $BasicConstraints -or -not $BasicConstraints.CertificateAuthority) {
        throw "Refusing to trust a certificate that is not a CA."
    }
    if (-not $KeyUsage -or -not ($KeyUsage.KeyUsages -band [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::KeyCertSign)) {
        throw "Refusing to trust a CA without certificate-signing key usage."
    }
    if ($Certificate.NotAfter -le (Get-Date)) {
        throw "Refusing to trust an expired CA certificate."
    }
}

$Sha256 = [System.Security.Cryptography.SHA256]::Create()
try {
    $Fingerprint = ([BitConverter]::ToString($Sha256.ComputeHash($Certificate.RawData))).Replace('-', ':')
} finally {
    $Sha256.Dispose()
}

Write-Host "Docker LAMP development CA SHA256 fingerprint:"
Write-Host "  $Fingerprint"

$Expected = if ($Action -eq "install") { "TRUST" } else { "UNTRUST" }
$Confirmation = Read-Host "Type $Expected to continue"
if ($Confirmation -cne $Expected) {
    throw "CA trust operation cancelled."
}

$Store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "CurrentUser")
$Store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
try {
    $ExpectedRawData = [Convert]::ToBase64String($Certificate.RawData)
    $ExactMatches = @($Store.Certificates | Where-Object {
        [Convert]::ToBase64String($_.RawData) -ceq $ExpectedRawData
    })

    if ($Action -eq "install") {
        if ($ExactMatches.Count -eq 0) {
            $Store.Add($Certificate)
            Write-Host "[OK] Installed the CA in CurrentUser\Root."
        } else {
            Write-Host "[OK] This exact CA is already installed in CurrentUser\Root."
        }
    } else {
        foreach ($Match in $ExactMatches) {
            $Store.Remove($Match)
        }
        if ($ExactMatches.Count -eq 0) {
            Write-Host "[OK] This exact CA was not present in CurrentUser\Root."
        } else {
            Write-Host "[OK] Removed this exact CA from CurrentUser\Root."
        }
    }
} finally {
    $Store.Close()
    $Certificate.Dispose()
}

Write-Host "Restart open browsers before testing. Firefox may require separate certificate trust configuration."
