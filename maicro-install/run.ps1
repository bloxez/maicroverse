# mAIcro Quick Start Script (Windows PowerShell)
# Usage: irm https://raw.githubusercontent.com/bloxez/maicroverse/main/maicro-install/run.ps1 | iex
#    or: & ([scriptblock]::Create((irm https://raw.githubusercontent.com/bloxez/maicroverse/main/maicro-install/run.ps1))) -DataDir "C:\maicro-data"

param(
    [string]$DataDir = "$env:USERPROFILE\maicro-data",
    [int]$Port = 4321
)

$ErrorActionPreference = "Stop"

# Configuration
$Image = "bloxez/maicro-g2a:latest"
$ContainerName = "maicro"
$ConfigTemplateUrl = if ($env:MAICRO_CONFIG_TEMPLATE_URL) {
    $env:MAICRO_CONFIG_TEMPLATE_URL
} else {
    "https://raw.githubusercontent.com/bloxez/maicroverse/main/maicro-install/config.platform.json"
}

Write-Host ""
Write-Host "  mAIcro:G2A - Gateway to APPS" -ForegroundColor Cyan
Write-Host ""
Write-Host "  GraphQL-first rapid prototyping platform" -ForegroundColor White
Write-Host ""

# Check Docker is installed
try {
    $null = Get-Command docker -ErrorAction Stop
} catch {
    Write-Host "ERROR: Docker is not installed." -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install Docker Desktop from:"
    Write-Host "  https://www.docker.com/products/docker-desktop"
    Write-Host ""
    exit 1
}

# Check Docker is running
$dockerInfo = docker info 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Docker is not running." -ForegroundColor Red
    Write-Host ""
    Write-Host "Please start Docker Desktop and try again."
    Write-Host ""
    exit 1
}

Write-Host "OK: Docker is running" -ForegroundColor Green

# Resolve to absolute path
$DataDir = [System.IO.Path]::GetFullPath($DataDir)
$AppDataDir = Join-Path $DataDir "data"

# Create data directory
Write-Host "Data directory: $DataDir" -ForegroundColor Yellow
if (-not (Test-Path $DataDir)) {
    New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
}
if (-not (Test-Path $AppDataDir)) {
    New-Item -ItemType Directory -Path $AppDataDir -Force | Out-Null
}
if (-not (Test-Path "$DataDir\config")) {
    New-Item -ItemType Directory -Path "$DataDir\config" -Force | Out-Null
}

# Create platform config file from published template
$configPath = Join-Path (Join-Path $DataDir "config") "config.platform.json"
Write-Host "Downloading platform config template..." -ForegroundColor Yellow
try {
        Invoke-WebRequest -UseBasicParsing -Uri $ConfigTemplateUrl -OutFile $configPath
} catch {
        Write-Host "ERROR: Failed to download config template from $ConfigTemplateUrl" -ForegroundColor Red
        exit 1
}

# Create update script
$updateScript = @'
# mAIcro Update Script - Pull latest image and restart container

$ErrorActionPreference = "Stop"

$Image = "bloxez/maicro-g2a:latest"
$ContainerName = "maicro"
$Port = if ($env:MAICRO_PORT) { $env:MAICRO_PORT } else { 4321 }
$AppDataDir = Join-Path $PSScriptRoot "data"
$ConfigPath = Join-Path (Join-Path $PSScriptRoot "config") "config.platform.json"
$ConfigTemplateUrl = if ($env:MAICRO_CONFIG_TEMPLATE_URL) {
    $env:MAICRO_CONFIG_TEMPLATE_URL
} else {
    "https://raw.githubusercontent.com/bloxez/maicroverse/main/maicro-install/config.platform.json"
}

Write-Host "Checking for updates..."

# Sync config template on every update to keep schema changes aligned
$tmpConfigPath = "$ConfigPath.tmp"
$configChanged = $false
Write-Host "Syncing platform config template..."
try {
    Invoke-WebRequest -UseBasicParsing -Uri $ConfigTemplateUrl -OutFile $tmpConfigPath
} catch {
    Write-Host "ERROR: Failed to download config template from $ConfigTemplateUrl" -ForegroundColor Red
    exit 1
}

if ((Test-Path $ConfigPath) -and (Get-FileHash $ConfigPath).Hash -eq (Get-FileHash $tmpConfigPath).Hash) {
    Remove-Item -Path $tmpConfigPath -Force
} else {
    Move-Item -Path $tmpConfigPath -Destination $ConfigPath -Force
    $configChanged = $true
}

# Get current image digest
$currentDigest = docker inspect --format='{{.Image}}' $ContainerName 2>$null
if (-not $currentDigest) { $currentDigest = "" }

# Pull latest
Write-Host "Pulling latest image..."
docker pull $Image

# Get new image digest
$newDigest = docker inspect --format='{{.Id}}' $Image 2>$null

if ($currentDigest -eq $newDigest) {
    if ($configChanged) {
        Write-Host "OK: Image unchanged, but config template updated. Restarting container..." -ForegroundColor Green
        docker stop $ContainerName 2>$null | Out-Null
        docker rm $ContainerName 2>$null | Out-Null
    } else {
        Write-Host "OK: Already on latest version" -ForegroundColor Green
        exit 0
    }
}

Write-Host "New version available, updating..." -ForegroundColor Yellow

# Stop and remove old container
docker stop $ContainerName 2>$null | Out-Null
docker rm $ContainerName 2>$null | Out-Null

# Get OpenRouter API key from environment if set
$OpenRouterKey = $env:OPENROUTER_API_KEY

# Restart with same settings
Write-Host "Starting updated container..."
$dockerArgs = @(
    "run", "-d",
    "--name", $ContainerName,
    "-p", "${Port}:3456",
    "-v", "${PSScriptRoot}:/app/runtime/userdata",
    "-v", "${AppDataDir}:/app/data",
    "-e", "CONFIG_PATH=/app/runtime/userdata/config/config.platform.json",
    "--restart", "unless-stopped"
)

if ($OpenRouterKey) {
    $dockerArgs += @("-e", "OPENROUTER_API_KEY=$OpenRouterKey")
}

# Add authentication and root management variables
$DockerAdminKey = if ($env:MAICRO_ADMIN_KEY) { $env:MAICRO_ADMIN_KEY } else { "" }
$DockerJwtSigningKey = if ($env:JWT_SECRET_INTERNAL_SIGNING_KEY) {
    $env:JWT_SECRET_INTERNAL_SIGNING_KEY
} elseif ($env:MAICRO_UNI_SECRET) {
    $env:MAICRO_UNI_SECRET
} else {
    "maicro-first-boot"
}
$DockerRootInstance = if ($env:ROOT_INSTANCE) { $env:ROOT_INSTANCE } else { "root" }
$DockerRootKey = if ($env:ROOT_KEY) { $env:ROOT_KEY } else { "rootg2a" }

if ($DockerAdminKey) { $dockerArgs += @("-e", "MAICRO_ADMIN_KEY=$DockerAdminKey") }
if ($DockerJwtSigningKey) { $dockerArgs += @("-e", "JWT_SECRET_INTERNAL_SIGNING_KEY=$DockerJwtSigningKey") }
if ($DockerRootInstance) { $dockerArgs += @("-e", "ROOT_INSTANCE=$DockerRootInstance") }
if ($DockerRootKey) { $dockerArgs += @("-e", "ROOT_KEY=$DockerRootKey") }

$dockerArgs += $Image
docker @dockerArgs | Out-Null

Start-Sleep -Seconds 2

$running = docker ps -q -f "name=$ContainerName"
if ($running) {
    Write-Host "OK: Update complete!" -ForegroundColor Green
    Write-Host "mAIcro: http://localhost:${Port}/ide" -ForegroundColor Cyan
} else {
    Write-Host "ERROR: Failed to start updated container" -ForegroundColor Red
    docker logs $ContainerName
    exit 1
}
'@

$updateScriptPath = Join-Path $DataDir "update.ps1"
Set-Content -Path $updateScriptPath -Value $updateScript -Force

# Create remove script
$removeScript = @'
# mAIcro Remove Script - Remove container and optionally remove persisted data

$ErrorActionPreference = "Stop"

$ContainerName = "maicro"
$DataDir = $PSScriptRoot

Write-Host "WARNING: This will remove the mAIcro container: $ContainerName" -ForegroundColor Yellow
$confirmContainer = Read-Host "Remove container now? [y/N]"

if ($confirmContainer -notin @("y", "Y", "yes", "YES")) {
    Write-Host "Cancelled."
    exit 0
}

Write-Host "Stopping and removing container..."
docker stop $ContainerName 2>$null | Out-Null
docker rm $ContainerName 2>$null | Out-Null

Write-Host "OK: Container removed (or was not present)." -ForegroundColor Green
Write-Host ""
Write-Host "Persisted data directory: $DataDir"
$confirmData = Read-Host "Also remove persisted data from host? [y/N]"

if ($confirmData -in @("y", "Y", "yes", "YES")) {
    Write-Host "Removing persisted data..."
    Get-ChildItem -Path $DataDir -Force |
        Where-Object { $_.Name -notin @("update.ps1", "remove.ps1") } |
        Remove-Item -Recurse -Force
    Write-Host "OK: Persisted data removed." -ForegroundColor Green
} else {
    Write-Host "Data kept at: $DataDir"
}
'@

$removeScriptPath = Join-Path $DataDir "remove.ps1"
Set-Content -Path $removeScriptPath -Value $removeScript -Force

# Stop and remove existing container if it exists
$existing = docker ps -aq -f "name=$ContainerName" 2>$null
if ($existing) {
    Write-Host "Stopping existing mAIcro container..." -ForegroundColor Yellow
    docker stop $ContainerName 2>$null | Out-Null
    docker rm $ContainerName 2>$null | Out-Null
}

# Pull latest image
Write-Host "Pulling mAIcro image..." -ForegroundColor Yellow
docker pull $Image

# Get OpenRouter API key from environment if set
$OpenRouterKey = $env:OPENROUTER_API_KEY

# Run container
Write-Host "Starting mAIcro..." -ForegroundColor Yellow
$dockerArgs = @(
    "run", "-d",
    "--name", $ContainerName,
    "-p", "${Port}:3456",
    "-v", "${DataDir}:/app/runtime/userdata",
    "-v", "${AppDataDir}:/app/data",
    "-e", "CONFIG_PATH=/app/runtime/userdata/config/config.platform.json",
    "--restart", "unless-stopped"
)

if ($OpenRouterKey) {
    $dockerArgs += @("-e", "OPENROUTER_API_KEY=$OpenRouterKey")
}

# Add authentication and root management variables
$DockerAdminKey = if ($env:MAICRO_ADMIN_KEY) { $env:MAICRO_ADMIN_KEY } else { "" }
$DockerJwtSigningKey = if ($env:JWT_SECRET_INTERNAL_SIGNING_KEY) {
    $env:JWT_SECRET_INTERNAL_SIGNING_KEY
} elseif ($env:MAICRO_UNI_SECRET) {
    $env:MAICRO_UNI_SECRET
} else {
    "maicro-first-boot"
}
$DockerRootInstance = if ($env:ROOT_INSTANCE) { $env:ROOT_INSTANCE } else { "root" }
$DockerRootKey = if ($env:ROOT_KEY) { $env:ROOT_KEY } else { "rootg2a" }

if ($DockerAdminKey) { $dockerArgs += @("-e", "MAICRO_ADMIN_KEY=$DockerAdminKey") }
if ($DockerJwtSigningKey) { $dockerArgs += @("-e", "JWT_SECRET_INTERNAL_SIGNING_KEY=$DockerJwtSigningKey") }
if ($DockerRootInstance) { $dockerArgs += @("-e", "ROOT_INSTANCE=$DockerRootInstance") }
if ($DockerRootKey) { $dockerArgs += @("-e", "ROOT_KEY=$DockerRootKey") }

$dockerArgs += $Image

docker @dockerArgs | Out-Null

# Wait for startup: poll the health endpoint instead of a fixed sleep so the
# maicroverse prompt below doesn't race the backend's actual readiness.
Write-Host "Waiting for mAIcro to start..." -ForegroundColor Yellow
$healthy = $false
for ($i = 0; $i -lt 30; $i++) {
    try {
        $healthResponse = Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:${Port}/health" -TimeoutSec 2
        if ($healthResponse.StatusCode -eq 200) {
            $healthy = $true
            break
        }
    } catch {
        # not ready yet
    }
    Start-Sleep -Seconds 2
}

# Check if running
$running = docker ps -q -f "name=$ContainerName"
if ($running -and -not $healthy) {
    Write-Host "WARNING: Container is running but health check did not pass in time. Continuing anyway..." -ForegroundColor Yellow
}
if ($running) {
    Write-Host ""
    Write-Host "OK: mAIcro is running!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  IDE:      " -NoNewline; Write-Host "http://localhost:${Port}/ide" -ForegroundColor Cyan
    Write-Host "  GraphQL:  " -NoNewline; Write-Host "http://localhost:${Port}/graphql" -ForegroundColor Cyan
    Write-Host "  Data:     $DataDir"
    Write-Host "  DB Data:  $AppDataDir"
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor White
    Write-Host "  Update:  " -NoNewline; Write-Host "powershell $DataDir\update.ps1" -ForegroundColor Yellow
    Write-Host "  Remove:  " -NoNewline; Write-Host "powershell $DataDir\remove.ps1" -ForegroundColor Yellow
    Write-Host "  Stop:    " -NoNewline; Write-Host "docker stop maicro" -ForegroundColor Yellow
    Write-Host "  Start:   " -NoNewline; Write-Host "docker start maicro" -ForegroundColor Yellow
    Write-Host "  Logs:    " -NoNewline; Write-Host "docker logs -f maicro" -ForegroundColor Yellow
    Write-Host "  Force Remove: " -NoNewline; Write-Host "docker rm -f maicro" -ForegroundColor Yellow
    Write-Host ""

    $createMv = Read-Host "Would you like to create a maicroverse instance now? [y/N]"
    if ($createMv -in @("y", "Y", "yes", "YES")) {
        $openRouterSecureKey = Read-Host "Enter OPENROUTER_API_KEY (input hidden)" -AsSecureString
        $openRouterKeyPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($openRouterSecureKey)
        try {
            $setupOpenRouterKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($openRouterKeyPointer)
        } finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($openRouterKeyPointer)
        }

        if ([string]::IsNullOrWhiteSpace($setupOpenRouterKey)) {
            Write-Host "ERROR: OPENROUTER_API_KEY cannot be empty" -ForegroundColor Red
            exit 1
        }

        Write-Host "OPENROUTER_API_KEY received ($($setupOpenRouterKey.Length) characters)."
        docker exec -e "OPENROUTER_API_KEY=$setupOpenRouterKey" -i $ContainerName bash -lc 'curl -fsSL https://raw.githubusercontent.com/bloxez/maicroverse/main/create-mv.sh -o /tmp/create-mv.sh && bash /tmp/create-mv.sh'
        $setupOpenRouterKey = $null
    } else {
        Write-Host "Skipped. You can create one later with:"
        Write-Host "  docker exec -it maicro bash -lc 'curl -fsSL https://raw.githubusercontent.com/bloxez/maicroverse/main/create-mv.sh | bash'" -ForegroundColor Yellow
    }
} else {
    Write-Host "ERROR: Failed to start mAIcro" -ForegroundColor Red
    Write-Host "Check logs with: docker logs $ContainerName"
    exit 1
}
