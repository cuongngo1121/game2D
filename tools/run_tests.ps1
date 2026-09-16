param(
    [string]$GodotPath,
    [string[]]$Tests = @('tests/rhythm_save_test.gd'),
    [switch]$Import
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) { $GodotPath = Join-Path $projectRoot '.tools\godot\Godot_v4.5.2-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Godot 4.5.2 is missing. Pass -GodotPath to its console executable.' }
$resolvedGodot = (Resolve-Path -LiteralPath $GodotPath).Path
$portableTools = [IO.Path]::GetFullPath((Join-Path $projectRoot '.tools')) + [IO.Path]::DirectorySeparatorChar
if (-not $resolvedGodot.StartsWith($portableTools, [StringComparison]::OrdinalIgnoreCase)) { throw 'Use Godot inside project .tools for isolated test configuration.' }
New-Item -ItemType File -Force -Path (Join-Path (Split-Path -Parent $resolvedGodot) '_sc_') | Out-Null
$previousAppData = $env:APPDATA
try {
    $env:APPDATA = Join-Path $projectRoot '.tools\test_appdata'
    New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
    if ($Import) {
        & $resolvedGodot --headless --editor --path $projectRoot --import --log-file (Join-Path $projectRoot '.tools\test_import.log')
        if ($LASTEXITCODE -ne 0) { throw 'Asset import failed. See .tools/test_import.log.' }
    }
    foreach ($test in $Tests) {
        if (-not (Test-Path -LiteralPath (Join-Path $projectRoot $test))) { throw "Test does not exist: $test" }
        $logName = [IO.Path]::GetFileNameWithoutExtension($test) + '.log'
        & $resolvedGodot --headless --path $projectRoot --log-file (Join-Path $projectRoot ".tools\$logName") --script $test
        if ($LASTEXITCODE -ne 0) { throw "Test failed: $test" }
    }
} finally { $env:APPDATA = $previousAppData }
