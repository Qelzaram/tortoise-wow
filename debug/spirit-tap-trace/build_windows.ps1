$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$BuildDir = Join-Path $RepoRoot 'build-spirit-tap-trace'
$ArtifactDir = Join-Path $RepoRoot 'trace-artifact'

Write-Host "[trace] Repo: $RepoRoot"
Write-Host "[trace] Applying instrumentation..."
python (Join-Path $PSScriptRoot 'patch_trace.py')

$vcpkgRoot = $env:VCPKG_INSTALLATION_ROOT
if (-not $vcpkgRoot) {
    if (Test-Path 'C:\vcpkg\vcpkg.exe') {
        $vcpkgRoot = 'C:\vcpkg'
    }
}

if (-not $vcpkgRoot -or -not (Test-Path (Join-Path $vcpkgRoot 'vcpkg.exe'))) {
    throw 'vcpkg was not found. Set VCPKG_INSTALLATION_ROOT or install vcpkg at C:\vcpkg.'
}

Write-Host "[trace] Installing ACE via vcpkg..."
& (Join-Path $vcpkgRoot 'vcpkg.exe') install ace:x64-windows
if ($LASTEXITCODE -ne 0) { throw "vcpkg install failed: $LASTEXITCODE" }

$AceRoot = Join-Path $vcpkgRoot 'installed\x64-windows'

if (Test-Path $BuildDir) {
    Remove-Item $BuildDir -Recurse -Force
}

Write-Host "[trace] Configuring x64 Release..."
cmake -S $RepoRoot -B $BuildDir -A x64 `
    "-DACE_ROOT=$AceRoot" `
    '-DUSE_STD_MALLOC=ON' `
    '-DUSE_SCRIPTS=ON' `
    '-DUSE_EXTRACTORS=OFF' `
    '-DUSE_DISCORD_BOT=OFF' `
    '-DUSE_LIBCURL=OFF'
if ($LASTEXITCODE -ne 0) { throw "CMake configure failed: $LASTEXITCODE" }

Write-Host "[trace] Building mangosd + realmd..."
cmake --build $BuildDir --config Release --target mangosd realmd --parallel
if ($LASTEXITCODE -ne 0) { throw "CMake build failed: $LASTEXITCODE" }

if (Test-Path $ArtifactDir) {
    Remove-Item $ArtifactDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $ArtifactDir | Out-Null

$wanted = @('mangosd.exe', 'realmd.exe')
foreach ($name in $wanted) {
    $file = Get-ChildItem -Path (Join-Path $RepoRoot 'bin') -Filter $name -Recurse -File | Select-Object -First 1
    if (-not $file) { throw "$name was not produced" }
    Copy-Item $file.FullName $ArtifactDir -Force
}

$aceDll = Join-Path $AceRoot 'bin\ACE.dll'
if (Test-Path $aceDll) { Copy-Item $aceDll $ArtifactDir -Force }

$depDllDir = Join-Path $RepoRoot 'dep\windows\lib\x64_release'
foreach ($dll in @('libmySQL.dll', 'libeay32.dll')) {
    $src = Join-Path $depDllDir $dll
    if (Test-Path $src) { Copy-Item $src $ArtifactDir -Force }
}

Copy-Item (Join-Path $PSScriptRoot 'spirit_tap_trace.sql') $ArtifactDir -Force

$manifest = @(
    'Spirit Tap / Touch of Weakness diagnostic build',
    "Built from: $(git -C $RepoRoot rev-parse HEAD)",
    'Instrumentation:',
    '  [TOW_TRACE] - Touch of Weakness trigger and target life/HP',
    '  [SPIRIT_TAP_TRACE] - Spirit Tap incoming proc flags and victim state',
    '',
    'Apply spirit_tap_trace.sql ONLY to the isolated trace world database.'
)
$manifest | Set-Content -Path (Join-Path $ArtifactDir 'TRACE_README.txt') -Encoding UTF8

Write-Host "[trace] Artifact ready: $ArtifactDir"
