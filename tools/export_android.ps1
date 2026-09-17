param(
    [string]$GodotPath,
    [string]$AndroidSdkPath,
    [string]$JavaSdkPath,
    [string]$UiProfilePath,
    [switch]$PrepareOnly,
    [switch]$AlsoWindows
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) { $GodotPath = Join-Path $projectRoot '.tools\godot\Godot_v4.5.2-stable_win64_console.exe' }
if (-not $AndroidSdkPath) { $AndroidSdkPath = $env:ANDROID_SDK_ROOT }
if (-not $AndroidSdkPath) { $AndroidSdkPath = $env:ANDROID_HOME }
if (-not $AndroidSdkPath) { $AndroidSdkPath = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
if (-not $JavaSdkPath) { $JavaSdkPath = $env:JAVA_HOME }
if (-not $JavaSdkPath) { $JavaSdkPath = Join-Path $env:ProgramFiles 'Android\Android Studio\jbr' }
foreach ($requiredPath in @($GodotPath, (Join-Path $AndroidSdkPath 'build-tools\35.0.0\apksigner.bat'), (Join-Path $AndroidSdkPath 'platforms\android-35\android.jar'), (Join-Path $JavaSdkPath 'bin\keytool.exe'), (Join-Path $projectRoot '.tools\templates\android_debug.apk'))) {
    if (-not (Test-Path -LiteralPath $requiredPath)) { throw "Required export tool/template is missing: $requiredPath" }
}
$resolvedGodot = (Resolve-Path -LiteralPath $GodotPath).Path
$portableTools = [IO.Path]::GetFullPath((Join-Path $projectRoot '.tools')) + [IO.Path]::DirectorySeparatorChar
if (-not $resolvedGodot.StartsWith($portableTools, [StringComparison]::OrdinalIgnoreCase)) { throw 'Copy Godot into project .tools so export settings stay inside this project.' }
New-Item -ItemType File -Force -Path (Join-Path (Split-Path -Parent $resolvedGodot) '_sc_') | Out-Null
$debugKey = Join-Path $projectRoot '.tools\debug.keystore'
if (-not (Test-Path -LiteralPath $debugKey)) {
    # This is a local testing key with the public standard Android debug password.
    & (Join-Path $JavaSdkPath 'bin\keytool.exe') -genkeypair -keystore $debugKey -storepass android -keypass android -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 -dname 'CN=Android Debug,O=Android,C=US' -noprompt
    if ($LASTEXITCODE -ne 0) { throw 'Could not create the local Android debug keystore.' }
}
$managedVariables = @('APPDATA', 'JAVA_HOME', 'NEON_ANDROID_SDK', 'NEON_JAVA_SDK', 'GODOT_ANDROID_KEYSTORE_DEBUG_PATH', 'GODOT_ANDROID_KEYSTORE_DEBUG_USER', 'GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD')
$priorValues = @{}
foreach ($variableName in $managedVariables) { $priorValues[$variableName] = [Environment]::GetEnvironmentVariable($variableName, 'Process') }
try {
    $env:APPDATA = Join-Path $projectRoot '.tools\export_appdata'
    $env:JAVA_HOME = (Resolve-Path -LiteralPath $JavaSdkPath).Path
    $env:NEON_ANDROID_SDK = (Resolve-Path -LiteralPath $AndroidSdkPath).Path
    $env:NEON_JAVA_SDK = $env:JAVA_HOME
    $env:GODOT_ANDROID_KEYSTORE_DEBUG_PATH = $debugKey
    $env:GODOT_ANDROID_KEYSTORE_DEBUG_USER = 'androiddebugkey'
    $env:GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD = 'android'
    New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
    & $resolvedGodot --headless --editor --path $projectRoot --log-file (Join-Path $projectRoot '.tools\export_setup.log') --script 'res://tools/setup_export.gd'
    if ($LASTEXITCODE -ne 0) { throw 'Portable Android configuration failed. See .tools/export_setup.log.' }
    if ($PrepareOnly) { Write-Output 'Export tools configured. No game build was exported.'; return }
    $syncScript = Join-Path $projectRoot 'tools\sync_ui_layout_defaults.ps1'
    if ($UiProfilePath) {
        & $syncScript -ProfilePath $UiProfilePath
    } else {
        & $syncScript
    }
    if ($LASTEXITCODE -ne 0) { throw 'Đồng bộ bố cục UI từ profile PC thất bại; APK chưa được export.' }
    $androidOutput = Join-Path $projectRoot 'builds\android'
    New-Item -ItemType Directory -Force -Path $androidOutput | Out-Null
    $apkPath = Join-Path $androidOutput 'NEON-RESONANCE-debug.apk'
    & $resolvedGodot --headless --path $projectRoot --log-file (Join-Path $projectRoot '.tools\export_android.log') --export-debug 'Android' $apkPath
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $apkPath)) { throw 'Android export failed. See .tools/export_android.log.' }
    & (Join-Path $AndroidSdkPath 'build-tools\35.0.0\apksigner.bat') verify --verbose $apkPath
    if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed.' }
    if ($AlsoWindows) {
        $windowsOutput = Join-Path $projectRoot 'builds\windows'
        New-Item -ItemType Directory -Force -Path $windowsOutput | Out-Null
        & $resolvedGodot --headless --path $projectRoot --log-file (Join-Path $projectRoot '.tools\export_windows.log') --export-debug 'Windows Desktop' (Join-Path $windowsOutput 'NEON-RESONANCE.exe')
        if ($LASTEXITCODE -ne 0) { throw 'Windows export failed. See .tools/export_windows.log.' }
    }
    Get-FileHash -LiteralPath $apkPath -Algorithm SHA256
    Write-Output "Android APK: $apkPath"
} finally {
    foreach ($variableName in $managedVariables) { [Environment]::SetEnvironmentVariable($variableName, $priorValues[$variableName], 'Process') }
}
