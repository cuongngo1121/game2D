param(
    [string]$GodotPath,
    [switch]$Editor,
    [switch]$Headless,
    [int]$QuitAfter = 0
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) { $GodotPath = Join-Path $projectRoot '.tools\godot\Godot_v4.5.2-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Godot 4.5.2 is missing. Pass -GodotPath to its console executable.' }
$resolvedGodot = (Resolve-Path -LiteralPath $GodotPath).Path
$portableTools = [IO.Path]::GetFullPath((Join-Path $projectRoot '.tools')) + [IO.Path]::DirectorySeparatorChar
if (-not $resolvedGodot.StartsWith($portableTools, [StringComparison]::OrdinalIgnoreCase)) { throw 'Copy Godot into this project .tools directory so portable editor settings stay inside the project.' }
New-Item -ItemType File -Force -Path (Join-Path (Split-Path -Parent $resolvedGodot) '_sc_') | Out-Null
$previousAppData = $env:APPDATA
try {
    $env:APPDATA = Join-Path $projectRoot '.tools\play_appdata'
    New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
    $godotArguments = @('--path', $projectRoot, '--log-file', (Join-Path $projectRoot '.tools\play.log'))
    if ($Editor) { $godotArguments += '--editor' }
    if ($Headless) { $godotArguments += '--headless' }
    if ($QuitAfter -gt 0) { $godotArguments += @('--quit-after', [string]$QuitAfter) }
    & $resolvedGodot @godotArguments
    if ($LASTEXITCODE -ne 0) { throw "Godot exited with code $LASTEXITCODE. See .tools/play.log." }
} finally { $env:APPDATA = $previousAppData }
