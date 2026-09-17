param(
    [string]$ProfilePath
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$defaultsPath = Join-Path $projectRoot 'data\ui_layout_defaults.json'

if (-not $ProfilePath) {
    $ProfilePath = Join-Path $projectRoot '.tools\play_appdata\Godot\app_userdata\NEON RESONANCE\profile.json'
}

# Keep this allow-list aligned with SaveStore's UI-only settings. The profile
# also contains checkpoint/progression data; none of those fields may enter the
# APK's shipped defaults.
$layoutSpecs = [ordered]@{
    'settings_layout_positions' = @{
        'ids' = @('title', 'audio', 'controls', 'save')
        'size' = 2
    }
    'hud_layout' = @{
        'ids' = @('hp', 'shield', 'energy', 'title', 'weapon', 'pause', 'boss')
        'size' = 4
    }
    'touch_layout' = @{
        'ids' = @('move', 'fire', 'dash', 'pulse')
        'size' = 4
    }
    'pause_layout' = @{
        'ids' = @('title', 'continue', 'settings', 'menu')
        'size' = 4
    }
    'reward_layout' = @{
        'ids' = @(
            'title',
            'card_01', 'card_01_title', 'card_01_description',
            'card_02', 'card_02_title', 'card_02_description',
            'card_03', 'card_03_title', 'card_03_description',
            'repair'
        )
        'size' = 4
    }
    'support_layout' = @{
        'ids' = @(
            'title', 'status',
            'card_01', 'card_01_icon', 'card_01_title', 'card_01_description',
            'card_02', 'card_02_icon', 'card_02_title', 'card_02_description',
            'card_03', 'card_03_icon', 'card_03_title', 'card_03_description',
            'back'
        )
        'size' = 4
    }
    'armory_layout' = @{
        'ids' = @(
            'title',
            'pistol_stt', 'pistol_name', 'pistol_action',
            'smg_stt', 'smg_name', 'smg_action',
            'shotgun_stt', 'shotgun_name', 'shotgun_action',
            'rail_stt', 'rail_name', 'rail_action',
            'beam_stt', 'beam_name', 'beam_action',
            'disc_stt', 'disc_name', 'disc_action',
            'arc_stt', 'arc_name', 'arc_action',
            'wave_stt', 'wave_name', 'wave_action',
            'glitch_stt', 'glitch_name', 'glitch_action',
            'orbit_stt', 'orbit_name', 'orbit_action',
            'blade_stt', 'blade_name', 'blade_action',
            'chord_stt', 'chord_name', 'chord_action'
        )
        'size' = 4
    }
}

function Read-JsonObject([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Không tìm thấy profile PC: $Path"
    }
    try {
        return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
    } catch {
        throw "Không đọc được profile PC hợp lệ: $Path"
    }
}

function Read-SelectedProfileSettings([string]$PrimaryPath) {
    $candidates = @($PrimaryPath, "$PrimaryPath.bak")
    $selected = $null
    $selectedPath = $null
    $selectedRevision = -1

    foreach ($candidate in $candidates) {
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            continue
        }
        try {
            $document = Read-JsonObject $candidate
            $payload = if ($document.payload_json -is [string]) {
                $document.payload_json | ConvertFrom-Json
            } else {
                $document
            }
            if ($null -eq $payload.settings) {
                continue
            }
            $revision = if ($null -eq $document.revision) { 0 } else { [int64]$document.revision }
            if ($null -eq $selected -or $revision -gt $selectedRevision) {
                $selected = $payload.settings
                $selectedPath = $candidate
                $selectedRevision = $revision
            }
        } catch {
            # A corrupt primary can be recovered from the valid .bak copy.
            continue
        }
    }

    if ($null -eq $selected) {
        throw "Không có bản profile PC hợp lệ để đồng bộ: $PrimaryPath hoặc $PrimaryPath.bak"
    }
    if ($selectedPath -ne $PrimaryPath) {
        Write-Warning "Profile chính không dùng được; đồng bộ từ bản phục hồi: $selectedPath"
    }
    return $selected
}

function Convert-ValidatedNumber([object]$Value, [string]$Context) {
    try {
        $number = [double]$Value
    } catch {
        throw "$Context không phải số hợp lệ."
    }
    if ([double]::IsNaN($number) -or [double]::IsInfinity($number)) {
        throw "$Context chứa số không hữu hạn."
    }
    return $number
}

function Copy-LayoutSection([object]$Settings, [string]$SectionName, [hashtable]$Spec) {
    $sectionProperty = $Settings.psobject.Properties[$SectionName]
    if ($null -eq $sectionProperty) {
        throw "Profile PC thiếu nhóm bố cục: $SectionName"
    }
    $section = $sectionProperty.Value
    $output = [ordered]@{}

    foreach ($itemId in $Spec.ids) {
        $itemProperty = $section.psobject.Properties[$itemId]
        if ($null -eq $itemProperty) {
            throw "Profile PC thiếu mục bố cục: $SectionName/$itemId"
        }
        $values = @($itemProperty.Value)
        if ($values.Count -ne [int]$Spec.size) {
            throw "Mục bố cục $SectionName/$itemId phải có $($Spec.size) giá trị, nhận $($values.Count)."
        }

        $numbers = @()
        for ($index = 0; $index -lt $values.Count; $index++) {
            $number = Convert-ValidatedNumber $values[$index] "$SectionName/$itemId[$index]"
            if ($Spec.size -eq 2) {
                $maximum = if ($index -eq 0) { 1280.0 } else { 720.0 }
                if ($number -lt 0.0 -or $number -gt $maximum) {
                    throw "$SectionName/$itemId[$index] nằm ngoài màn hình 1280x720."
                }
            } elseif ($index -lt 2) {
                $maximum = if ($index -eq 0) { 1280.0 } else { 720.0 }
                if ($number -lt 0.0 -or $number -gt $maximum) {
                    throw "$SectionName/$itemId[$index] nằm ngoài màn hình 1280x720."
                }
            } elseif ($number -lt 0.55 -or $number -gt 2.0) {
                throw "$SectionName/$itemId[$index] phải nằm trong khoảng kích cỡ 0.55..2.0."
            }
            $numbers += $number
        }
        $output[$itemId] = $numbers
    }
    return $output
}

$settings = Read-SelectedProfileSettings $ProfilePath
$touchScale = Convert-ValidatedNumber $settings.touch_scale 'touch_scale'
$touchOpacity = Convert-ValidatedNumber $settings.touch_opacity 'touch_opacity'
if ($touchScale -lt 0.7 -or $touchScale -gt 1.5) {
    throw 'touch_scale phải nằm trong khoảng 0.7..1.5.'
}
if ($touchOpacity -lt 0.2 -or $touchOpacity -gt 1.0) {
    throw 'touch_opacity phải nằm trong khoảng 0.2..1.0.'
}

$snapshot = [ordered]@{
    'schema_version' = 1
    'source' = 'PC profile layout snapshot'
    'touch_scale' = $touchScale
    'touch_opacity' = $touchOpacity
}
foreach ($sectionName in $layoutSpecs.Keys) {
    $snapshot[$sectionName] = Copy-LayoutSection $settings $sectionName $layoutSpecs[$sectionName]
}

$serialized = $snapshot | ConvertTo-Json -Depth 20
$temporaryPath = "$defaultsPath.tmp.$PID"
$utf8 = New-Object System.Text.UTF8Encoding($false)
try {
    [System.IO.File]::WriteAllText($temporaryPath, $serialized, $utf8)
    $check = Get-Content -LiteralPath $temporaryPath -Raw | ConvertFrom-Json
    if ($null -eq $check.touch_layout -or $null -eq $check.pause_layout -or $null -eq $check.reward_layout -or $null -eq $check.support_layout -or $null -eq $check.armory_layout) {
        throw 'Snapshot sinh ra thiếu nhóm bố cục bắt buộc.'
    }
    Move-Item -LiteralPath $temporaryPath -Destination $defaultsPath -Force
} catch {
    if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
        Remove-Item -LiteralPath $temporaryPath -Force
    }
    throw
}

$totalItems = 0
foreach ($sectionName in $layoutSpecs.Keys) {
    $totalItems += $layoutSpecs[$sectionName].ids.Count
}
Write-Output "Đã đồng bộ $totalItems mục bố cục UI từ profile PC vào $defaultsPath"
