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

Write-Host '[TRACE] Showing only Spirit Tap / Touch of Weakness trace lines. Ctrl+C exits.'
& docker compose -p $Settings.project --project-directory $Root -f $Compose -f $Override logs --tail 500 -f mangosd 2>&1 |
    Select-String -Pattern '\[TOW_TRACE\]|\[SPIRIT_TAP_TRACE\]'
