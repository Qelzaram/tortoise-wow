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

& docker compose -p $Settings.project --project-directory $Root -f $Compose -f $Override down
if ($LASTEXITCODE -ne 0) { throw 'Trace server shutdown failed.' }
Write-Host '[TRACE] Stopped. Trace database volume was preserved.'
