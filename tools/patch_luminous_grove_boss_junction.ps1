param(
    [string]$BasePath = (Join-Path $PSScriptRoot "..\assets\backgrounds\luminous_grove_route_background_user_six_stitched_complete_boss_hd_v20.png"),
    [string]$PatchPath = (Join-Path $PSScriptRoot "..\assets\backgrounds\luminous_grove_boss_junction_patch_v28.png"),
    [string]$OutputPath = (Join-Path $PSScriptRoot "..\assets\backgrounds\luminous_grove_route_background_user_six_boss_junction_repaired_hd_v28.png")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

# Coordinates are atlas pixels, not world or collision pixels.  They cover the
# two broken fragments at the upper-left Boss junction, while the original
# 5120 x 3840 route atlas remains the authority everywhere else.
$atlasX = 4100
$atlasY = 500
$patchCanvasWidth = 650
$patchCanvasHeight = 550
$repairWidth = 300
$repairHeight = 300
$featherPixels = 14

$baseFullPath = (Resolve-Path -LiteralPath $BasePath).Path
$patchFullPath = (Resolve-Path -LiteralPath $PatchPath).Path
$outputFullPath = [IO.Path]::GetFullPath($OutputPath)
if (Test-Path -LiteralPath $outputFullPath) {
    throw "Refusing to overwrite existing runtime asset: $outputFullPath"
}

$base = [System.Drawing.Bitmap]::FromFile($baseFullPath)
$patch = [System.Drawing.Bitmap]::FromFile($patchFullPath)
try {
    if ($base.Width -ne 5120 -or $base.Height -ne 3840) {
        throw "Boss junction base must be the 5120 x 3840 LV3 atlas."
    }
    if ($atlasX + $repairWidth -gt $base.Width -or $atlasY + $repairHeight -gt $base.Height) {
        throw "Boss junction patch rectangle must remain inside the atlas."
    }

    $output = [System.Drawing.Bitmap]::new($base)
    try {
        for ($localY = 0; $localY -lt $repairHeight; $localY++) {
            $sourceY = [Math]::Min($patch.Height - 1, [int][Math]::Floor($localY * $patch.Height / $patchCanvasHeight))
            $bottomFeather = [Math]::Min(1.0, ($repairHeight - $localY) / [double]$featherPixels)
            for ($localX = 0; $localX -lt $repairWidth; $localX++) {
                $sourceX = [Math]::Min($patch.Width - 1, [int][Math]::Floor($localX * $patch.Width / $patchCanvasWidth))
                $rightFeather = [Math]::Min(1.0, ($repairWidth - $localX) / [double]$featherPixels)
                $alpha = [Math]::Min($rightFeather, $bottomFeather)
                $basePixel = $base.GetPixel($atlasX + $localX, $atlasY + $localY)
                $patchPixel = $patch.GetPixel($sourceX, $sourceY)
                $red = [int][Math]::Round($basePixel.R * (1.0 - $alpha) + $patchPixel.R * $alpha)
                $green = [int][Math]::Round($basePixel.G * (1.0 - $alpha) + $patchPixel.G * $alpha)
                $blue = [int][Math]::Round($basePixel.B * (1.0 - $alpha) + $patchPixel.B * $alpha)
                $output.SetPixel($atlasX + $localX, $atlasY + $localY, [System.Drawing.Color]::FromArgb(255, $red, $green, $blue))
            }
        }
        $output.Save($outputFullPath, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $output.Dispose()
    }
}
finally {
    $patch.Dispose()
    $base.Dispose()
}

$result = [System.Drawing.Image]::FromFile($outputFullPath)
try {
    [PSCustomObject]@{
        Name = Split-Path -Leaf $outputFullPath
        Width = $result.Width
        Height = $result.Height
        Bytes = (Get-Item -LiteralPath $outputFullPath).Length
        Base = Split-Path -Leaf $baseFullPath
        Patch = Split-Path -Leaf $patchFullPath
        RepairedAtlasRect = "$atlasX,$atlasY,$repairWidth,$repairHeight"
    }
}
finally {
    $result.Dispose()
}
