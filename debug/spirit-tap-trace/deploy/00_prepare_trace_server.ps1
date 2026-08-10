param(
    [string]$MainServer = 'G:\servers\Tortoise-WoW-1.18.1-Win11',
    [string]$TraceServer = 'G:\servers\Tortoise-WoW-1.18.1-SpiritTap-TRACE'
)

$ErrorActionPreference = 'Stop'
$ProjectName = 'tortoise-spirit-trace'
$KitDir = $PSScriptRoot

function Invoke-DockerComposeJson {
    param(
        [string]$ProjectDirectory,
        [string[]]$Files,
        [string]$Project
    )

    $args = @('compose')
    if ($Project) { $args += @('-p', $Project) }
    $args += @('--project-directory', $ProjectDirectory)
    foreach ($file in $Files) { $args += @('-f', $file) }
    $args += @('config', '--format', 'json')

    $raw = & docker @args
    if ($LASTEXITCODE -ne 0) { throw 'docker compose config failed.' }
    return ($raw | Out-String | ConvertFrom-Json)
}

function Get-DatabaseVolumeName {
    param($ComposeConfig)

    if (-not $ComposeConfig.volumes) { throw 'No volumes were found in compose config.' }

    foreach ($property in $ComposeConfig.volumes.PSObject.Properties) {
        $logicalName = [string]$property.Name
        $value = $property.Value
        $actualName = if ($value -and $value.name) { [string]$value.name } else { $logicalName }

        if ($logicalName -match 'tortoise.*database|database' -or $actualName -match 'tortoise.*database|database') {
            return $actualName
        }
    }

    throw 'Could not identify the Tortoise database volume from compose config.'
}

function Get-ComposeFile {
    param([string]$Root)
    foreach ($name in @('compose.yaml', 'compose.yml', 'docker-compose.yaml', 'docker-compose.yml')) {
        $candidate = Join-Path $Root $name
        if (Test-Path $candidate) { return $candidate }
    }
    throw "Compose file was not found in $Root"
}

function Assert-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "$Name is required but was not found in PATH."
    }
}

Assert-Command docker
Assert-Command robocopy

$MainServer = (Resolve-Path $MainServer).Path
$MainCompose = Get-ComposeFile $MainServer

Write-Host "[TRACE] Primary server: $MainServer"
Write-Host "[TRACE] Trace server:   $TraceServer"
Write-Host "[TRACE] Checking that the primary server is stopped..."

$running = & docker compose --project-directory $MainServer -f $MainCompose ps --status running -q 2>$null
if ($LASTEXITCODE -ne 0) { throw 'Could not query the primary compose project.' }
if ($running) {
    throw 'Primary Turtle WoW server is still running. Stop it with its normal 08_ОСТАНОВИТЬ_сервер.cmd first.'
}

if (Test-Path $TraceServer) {
    throw "Trace directory already exists: $TraceServer. Remove/rename it before creating a fresh trace copy."
}

$mainConfig = Invoke-DockerComposeJson -ProjectDirectory $MainServer -Files @($MainCompose) -Project ''
$mainDbVolume = Get-DatabaseVolumeName $mainConfig

& docker volume inspect $mainDbVolume *> $null
if ($LASTEXITCODE -ne 0) {
    throw "Primary database volume '$mainDbVolume' does not exist. Nothing was changed."
}

Write-Host "[TRACE] Primary DB volume: $mainDbVolume"
Write-Host '[TRACE] Copying runtime/config without client, DB backups and extracted map data...'

New-Item -ItemType Directory -Path $TraceServer -Force | Out-Null
$excludeDirs = @(
    (Join-Path $MainServer 'client'),
    (Join-Path $MainServer '.git'),
    (Join-Path $MainServer 'storage\mangosd\extracted-data'),
    (Join-Path $MainServer 'storage\database\backups')
)

$roboArgs = @($MainServer, $TraceServer, '/E', '/COPY:DAT', '/DCOPY:DAT', '/R:1', '/W:1', '/NFL', '/NDL', '/NJH', '/NJS', '/NP', '/XD') + $excludeDirs
& robocopy @roboArgs | Out-Null
if ($LASTEXITCODE -gt 7) { throw "robocopy failed with exit code $LASTEXITCODE" }

# Do not leave primary maintenance/start-stop wrappers in the trace copy.
Get-ChildItem $TraceServer -File -Filter '*.cmd' -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^(02_|07_|08_|10_|11_|12_|13_)' } |
    Remove-Item -Force

$mainExtracted = Join-Path $MainServer 'storage\mangosd\extracted-data'
$traceExtracted = Join-Path $TraceServer 'storage\mangosd\extracted-data'
if (-not (Test-Path $mainExtracted)) { throw "Primary extracted-data directory was not found: $mainExtracted" }
New-Item -ItemType Directory -Path (Split-Path $traceExtracted -Parent) -Force | Out-Null
if (Test-Path $traceExtracted) { Remove-Item $traceExtracted -Recurse -Force }
& cmd /c "mklink /J `"$traceExtracted`" `"$mainExtracted`"" | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not create extracted-data junction.' }

Write-Host '[TRACE] Installing trace binaries and compose override...'
New-Item -ItemType Directory -Path (Join-Path $TraceServer 'trace-bin') -Force | Out-Null
Copy-Item (Join-Path $KitDir 'trace-bin\mangosd') (Join-Path $TraceServer 'trace-bin\mangosd') -Force
Copy-Item (Join-Path $KitDir 'trace-bin\realmd') (Join-Path $TraceServer 'trace-bin\realmd') -Force
Copy-Item (Join-Path $KitDir 'Dockerfile.trace') (Join-Path $TraceServer 'Dockerfile.trace') -Force
Copy-Item (Join-Path $KitDir 'compose.trace.override.yaml') (Join-Path $TraceServer 'compose.trace.override.yaml') -Force

$customSqlDir = Join-Path $TraceServer 'storage\database\custom-sql'
if (Test-Path $customSqlDir) { Remove-Item $customSqlDir -Recurse -Force }
New-Item -ItemType Directory -Path $customSqlDir -Force | Out-Null
Copy-Item (Join-Path $KitDir 'spirit_tap_trace.sql') (Join-Path $customSqlDir '999_spirit_tap_trace.sql') -Force

foreach ($file in @('trace_start.ps1','trace_stop.ps1','trace_log.ps1','02_ЗАПУСТИТЬ_TRACE.cmd','08_ОСТАНОВИТЬ_TRACE.cmd','09_СМОТРЕТЬ_TRACE_ЛОГ.cmd')) {
    Copy-Item (Join-Path $KitDir $file) (Join-Path $TraceServer $file) -Force
}

$traceCompose = Get-ComposeFile $TraceServer
$overrideFile = Join-Path $TraceServer 'compose.trace.override.yaml'
$traceConfig = Invoke-DockerComposeJson -ProjectDirectory $TraceServer -Files @($traceCompose, $overrideFile) -Project $ProjectName
$traceDbVolume = Get-DatabaseVolumeName $traceConfig

if ($traceDbVolume -eq $mainDbVolume) {
    throw "Safety check failed: trace DB volume resolves to the PRIMARY volume '$mainDbVolume'. Aborting before any DB write."
}

Write-Host "[TRACE] Trace DB volume: $traceDbVolume"

# Remove only a stale trace project/volume, never the primary project/volume.
& docker compose -p $ProjectName --project-directory $TraceServer -f $traceCompose -f $overrideFile down --remove-orphans 2>$null | Out-Null
& docker volume inspect $traceDbVolume *> $null
if ($LASTEXITCODE -eq 0) {
    & docker volume rm $traceDbVolume | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Could not remove stale trace volume '$traceDbVolume'." }
}

Write-Host '[TRACE] Building tiny local runtime image (stable image + two traced binaries)...'
Push-Location $TraceServer
try {
    & docker build --pull=false -f Dockerfile.trace -t tortoise-spirit-tap-trace:local .
    if ($LASTEXITCODE -ne 0) { throw 'docker build failed.' }
}
finally {
    Pop-Location
}

Write-Host '[TRACE] Creating and cloning isolated database volume...'
& docker volume create $traceDbVolume | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not create trace database volume.' }

& docker run --rm `
    -v "${mainDbVolume}:/from:ro" `
    -v "${traceDbVolume}:/to" `
    alpine:3.20 `
    sh -c 'cd /from && tar cf - . | tar xpf - -C /to'
if ($LASTEXITCODE -ne 0) { throw 'Database volume clone failed.' }

$settings = [ordered]@{
    project = $ProjectName
    primaryServer = $MainServer
    primaryCompose = $MainCompose
    primaryDatabaseVolume = $mainDbVolume
    traceDatabaseVolume = $traceDbVolume
    sourceCommit = '0da6ca514b247b135e64286733017f1dce298fd6'
}
$settings | ConvertTo-Json | Set-Content (Join-Path $TraceServer 'trace-settings.json') -Encoding UTF8

Write-Host ''
Write-Host '============================================================'
Write-Host ' TRACE SERVER READY'
Write-Host " Folder: $TraceServer"
Write-Host " DB:     $traceDbVolume (independent clone)"
Write-Host ' Core:   tortoise-spirit-tap-trace:local'
Write-Host ' Main DB was NOT modified.'
Write-Host '============================================================'
Write-Host ''
Write-Host 'Run 02_ЗАПУСТИТЬ_TRACE.cmd, reproduce Touch of Weakness once,'
Write-Host 'then run 09_СМОТРЕТЬ_TRACE_ЛОГ.cmd and send the trace lines.'
