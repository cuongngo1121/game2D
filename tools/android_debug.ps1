param(
    [string]$AndroidSdkPath,
    [string]$JavaSdkPath,
    [string]$DeviceSerial,
    [string]$UiProfilePath,
    [switch]$Build,
    [switch]$Install,
    [switch]$Launch,
    [switch]$Logs,
    [switch]$ClearLog,
    [switch]$Performance
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$packageName = 'com.noctis.neonresonance'
$activityName = 'com.godot.game.GodotApp'
if (-not $AndroidSdkPath) { $AndroidSdkPath = $env:ANDROID_SDK_ROOT }
if (-not $AndroidSdkPath) { $AndroidSdkPath = $env:ANDROID_HOME }
if (-not $AndroidSdkPath) { $AndroidSdkPath = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
if (-not $JavaSdkPath) {
    $bundledJbr = 'C:\Program Files\Android\Android Studio\jbr'
    $JavaSdkPath = if (Test-Path -LiteralPath $bundledJbr) { $bundledJbr } else { $env:JAVA_HOME }
}
$adb = Join-Path $AndroidSdkPath 'platform-tools\adb.exe'
$apk = Join-Path $projectRoot 'builds\android\NEON-RESONANCE-debug.apk'
$logPath = Join-Path $projectRoot '.tools\android_logcat.txt'
if (-not (Test-Path -LiteralPath $adb)) { throw "ADB không tồn tại: $adb. Cài Android SDK Platform Tools hoặc truyền -AndroidSdkPath." }

function Invoke-Adb([string[]]$Arguments) {
    if ($DeviceSerial) { & $adb '-s' $DeviceSerial @Arguments }
    else { & $adb @Arguments }
    if ($LASTEXITCODE -ne 0) { throw "ADB thất bại: adb $($Arguments -join ' ')" }
}

function Get-ConnectedDevice {
	# A cold ADB daemon can write its startup diagnostic to stderr and briefly
	# reject the first get-state call while the USB transport is enumerating.
	# Capture that diagnostic, retry the state probe, and accept only an exact
	# `device` line so PowerShell does not turn a transient notice into a stop.
	for ($attempt = 0; $attempt -lt 10; $attempt++) {
		# Keep the one-element get-state command as an explicit argument. PowerShell
		# can unwrap a one-item array during assignment; splatting that scalar would
		# make ADB receive only its first character ("g").
		$lines = if ($DeviceSerial) {
			@(& $adb '-s' $DeviceSerial 'get-state' 2>&1)
		} else {
			@(& $adb 'get-state' 2>&1)
		}
		$exitCode = $LASTEXITCODE
        $state = $lines | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ -eq 'device' } | Select-Object -Last 1
        if ($exitCode -eq 0 -and $state -eq 'device') { return }
        if ($attempt -lt 9) { Start-Sleep -Milliseconds 200 }
    }
    $inventory = @(& $adb 'devices' '-l' 2>&1)
    throw "Chưa có thiết bị Android ở trạng thái device. Kết quả:`n$($inventory -join "`n")`nBật Developer options + USB debugging, chấp nhận RSA prompt, rồi chạy lại."
}

if ($Build) {
    Push-Location $projectRoot
    try {
        $exportScript = Join-Path $projectRoot 'tools\export_android.ps1'
        if ($UiProfilePath) {
            & $exportScript -AndroidSdkPath $AndroidSdkPath -JavaSdkPath $JavaSdkPath -UiProfilePath $UiProfilePath
        } else {
            & $exportScript -AndroidSdkPath $AndroidSdkPath -JavaSdkPath $JavaSdkPath
        }
        if ($LASTEXITCODE -ne 0) { throw 'Export Android không thành công; xem .tools/export_android.log.' }
    } finally { Pop-Location }
}

if ($Install -or $Launch -or $Logs -or $ClearLog -or $Performance) { Get-ConnectedDevice }

if ($Install) {
    if (-not (Test-Path -LiteralPath $apk)) { throw "Chưa có APK: $apk. Chạy -Build trước hoặc tạo APK trong builds/android." }
    Invoke-Adb @('install', '-r', $apk)
    Write-Output "Đã cài debug APK lên thiết bị: $packageName"
}

if ($ClearLog) { Invoke-Adb @('logcat', '-c') }

if ($Launch) {
    Invoke-Adb @('shell', 'am', 'force-stop', $packageName)
    Invoke-Adb @('shell', 'am', 'start', '-n', "$packageName/$activityName")
    Write-Output "Đã mở $packageName/$activityName"
}

if ($Logs) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $logPath) | Out-Null
    Write-Output "Đang theo dõi log Android. Nhấn Ctrl+C để dừng. File: $logPath"
    $args = @('logcat', '-v', 'threadtime', 'Godot:D', 'AndroidRuntime:E', 'DEBUG:I', '*:S')
    if ($DeviceSerial) { $args = @('-s', $DeviceSerial) + $args }
    & $adb @args | Tee-Object -FilePath $logPath
}

if ($Performance) {
    $perfPath = Join-Path $projectRoot '.tools\android_perf.txt'
    $prefix = @()
    if ($DeviceSerial) { $prefix = @('-s', $DeviceSerial) }
    $gfx = & $adb @($prefix + @('shell', 'dumpsys', 'gfxinfo', $packageName, 'framestats'))
    $mem = & $adb @($prefix + @('shell', 'dumpsys', 'meminfo', $packageName))
    @(
        "NEON RESONANCE Android performance snapshot $(Get-Date -Format o)",
        "Package: $packageName",
        '--- gfxinfo framestats ---',
        $gfx,
        '--- meminfo ---',
        $mem
    ) | Set-Content -LiteralPath $perfPath -Encoding UTF8
    Write-Output "Đã ghi snapshot hiệu năng Android: $perfPath"
}

if (-not ($Build -or $Install -or $Launch -or $Logs -or $ClearLog)) {
    Write-Output @"
Android debug helper

  .\tools\android_debug.ps1 -Build -Install -Launch
  .\tools\android_debug.ps1 -Logs
  .\tools\android_debug.ps1 -ClearLog -Launch
  .\tools\android_debug.ps1 -Performance

Thêm -DeviceSerial <serial> khi có nhiều thiết bị. Nếu adb không có trạng thái
device, script dừng và in danh sách hiện tại.
"@
}
