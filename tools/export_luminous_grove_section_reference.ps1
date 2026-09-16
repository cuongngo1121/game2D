param(
    [string]$SourcePath = (Join-Path $PSScriptRoot "..\assets\backgrounds\luminous_grove_route_background_concept_v1_seamless_hd_v3.png"),
    [string]$OutputPath = (Join-Path $PSScriptRoot "..\tmp\luminous_grove_combat_1_reference.png"),
    [ValidateRange(0, 5119)]
    [int]$X = 0,
    [ValidateRange(0, 3839)]
    [int]$Y = 2400,
    [ValidateRange(1, 5120)]
    [int]$Width = 1448,
    [ValidateRange(1, 3840)]
    [int]$Height = 1440
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$sourceFullPath = (Resolve-Path -LiteralPath $SourcePath).Path
$outputFullPath = [IO.Path]::GetFullPath($OutputPath)
$source = [System.Drawing.Image]::FromFile($sourceFullPath)
try {
    $sourceRect = [System.Drawing.Rectangle]::Intersect(
        [System.Drawing.Rectangle]::new(0, 0, $source.Width, $source.Height),
        [System.Drawing.Rectangle]::new($X, $Y, $Width, $Height)
    )
    if ($sourceRect.Width -ne $Width -or $sourceRect.Height -ne $Height) {
        throw "Requested section must remain inside the source texture."
    }
    [IO.Directory]::CreateDirectory((Split-Path -Parent $outputFullPath)) | Out-Null
    $section = [System.Drawing.Bitmap]::new($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppPArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($section)
    try {
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $graphics.DrawImage($source, [System.Drawing.Rectangle]::new(0, 0, $Width, $Height), $sourceRect.X, $sourceRect.Y, $sourceRect.Width, $sourceRect.Height, [System.Drawing.GraphicsUnit]::Pixel)
        $section.Save($outputFullPath, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $graphics.Dispose()
        $section.Dispose()
    }
}
finally {
    $source.Dispose()
}

Get-Item -LiteralPath $outputFullPath | Select-Object FullName,Length,LastWriteTime
