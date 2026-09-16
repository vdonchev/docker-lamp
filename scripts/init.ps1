# Requires PowerShell 5+
$ErrorActionPreference = "Stop"

function Check($msg) {
  Write-Host "[OK] $msg"
}

Write-Host "Starting environment initialization..."

# Check docker-compose.yml
if (Test-Path "docker-compose.yml") {
  Check "docker-compose.yml found"
} else {
  Write-Host "docker-compose.yml not found. Initialization aborted."
  exit 1
}

# Files
$EnvFile = ".env"
$ExampleEnv = "example.win.env"
$PwdAbs = (Get-Location).Path
$GenerateEnv = $false

# .env handling
if (Test-Path $EnvFile) {
  $confirm = Read-Host ".env already exists. Overwrite it? [y/N]"
  if ($confirm -match "^[Yy]$") { $GenerateEnv = $true } else { Check "skipped .env generation" }
} else {
  $GenerateEnv = $true
}

if ($GenerateEnv) {
  if (Test-Path $ExampleEnv) {
    Copy-Item $ExampleEnv $EnvFile -Force

    # Replace SQL_DATA_PATH and WEB_ROOT
    (Get-Content $EnvFile) |
      ForEach-Object {
        $_ -replace '^SQL_DATA_PATH=.*', "SQL_DATA_PATH=$PwdAbs\var\db" `
           -replace '^WEB_ROOT=.*', "WEB_ROOT=$PwdAbs\app"
      } | Set-Content $EnvFile

    Check ".env generated from example.win.env with absolute paths for SQL_DATA_PATH and WEB_ROOT"
  } else {
    Write-Host "example.env not found. Initialization aborted."
    exit 1
  }
}

# Required directories
New-Item -ItemType Directory -Force -Path "var/log", "config/apache/vhosts/generated" | Out-Null
Check "required directories created (or already exist)"

# Missing config files
$FilesToCreate = @{
  "config/apache/vhosts/vhost.local.conf"    = "# Local Apache Vhosts config (auto-created)"
  "config/php/conf.d/php.local.ini"          = "; Local PHP config (auto-created)"
  "config/projects/domains.local.conf"       = "# List of project domains (auto-created)"
  "config/sql/mysql/my.local.cnf"            = "# Local MySQL config (auto-created)"
  "config/sql/mariadb/my.local.cnf"          = "# Local MariaDB config (auto-created)"
}

foreach ($file in $FilesToCreate.Keys) {
  if (-not (Test-Path $file)) {
    New-Item -ItemType Directory -Force -Path (Split-Path $file) | Out-Null
    Set-Content -Path $file -Value $FilesToCreate[$file]
    Check "created $file"
  } else {
    Check "$file already exists"
  }
}

# Validate the persistent CA and issue a current leaf for configured domains.
& "$PSScriptRoot\generate-multidomain-ssl.ps1"
Check "local CA validated and SSL certificate generated"
