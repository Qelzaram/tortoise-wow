$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$Settings = Get-Content (Join-Path $Root 'trace-settings.json') -Raw | ConvertFrom-Json
$Compose = Join-Path $Root 'compose.yaml'
if (-not (Test-Path $Compose)) {
    foreach ($name in @('compose.yml','docker-compose.yaml','docker-compose.yml')) {
        $candidate = Join-Path $Root $name
        if (Test-Path $candidate) { $Compose = $candidate; break }
    }
}
$Override = Join-Path $Root 'compose.trace.override.yaml'

$runningPrimary = & docker compose --project-directory $Settings.primaryServer -f $Settings.primaryCompose ps --status running -q 2>$null
if ($runningPrimary) {
    throw 'Primary Turtle WoW server is running. Stop it first; trace uses the same client-facing ports.'
}

& docker compose -p $Settings.project --project-directory $Root -f $Compose -f $Override up -d
if ($LASTEXITCODE -ne 0) { throw 'Trace server startup failed.' }

& docker compose -p $Settings.project --project-directory $Root -f $Compose -f $Override ps
Write-Host ''
Write-Host '[TRACE] Server started. Reproduce Touch of Weakness on a target that survives.'
Write-Host '[TRACE] Then run 09_СМОТРЕТЬ_TRACE_ЛОГ.cmd.'
