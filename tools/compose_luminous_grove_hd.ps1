param(
    [string]$SourcePath = (Join-Path $PSScriptRoot "..\assets\backgrounds\luminous_grove_route_background_concept_v1.png"),
    [string]$SectionsPath = (Join-Path $PSScriptRoot "..\tmp\luminous_grove_hd_sections"),
    [string]$OutputPath = (Join-Path $PSScriptRoot "..\assets\backgrounds\luminous_grove_route_background_concept_v1_tiled_restored_hd_v2.png")
)

Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Drawing

$sections = @(
    @{ Name = "combat_1"; X = 0; Y = 700; W = 360; H = 386 },
    @{ Name = "combat_2"; X = 120; Y = 480; W = 620; H = 330 },
    @{ Name = "combat_3"; X = 630; Y = 350; W = 430; H = 330 },
    @{ Name = "support"; X = 620; Y = 160; W = 310; H = 330 },
    @{ Name = "combat_4"; X = 970; Y = 300; W = 330; H = 350 },
    @{ Name = "boss"; X = 1120; Y = 60; W = 328; H = 350 }
)

$nativeWidth = 1448.0
$nativeHeight = 1086.0
$atlasWidth = 5120
$atlasHeight = 3840
$pixelFormat = [System.Drawing.Imaging.PixelFormat]::Format32bppPArgb
$source = [System.Drawing.Image]::FromFile((Resolve-Path -LiteralPath $SourcePath))
$atlas = [System.Drawing.Bitmap]::new($atlasWidth, $atlasHeight, $pixelFormat)
$graphics = [System.Drawing.Graphics]::FromImage($atlas)

try {
    $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.DrawImage($source, [System.Drawing.Rectangle]::new(0, 0, $atlasWidth, $atlasHeight))
    $voidKey = [System.Drawing.Imaging.ImageAttributes]::new()
    # Each reconstructed crop has a solid near-black outer void. Make only
    # that range transparent while compositing so the source map's continuous
    # dark backdrop remains visible between rooms and corridors.
    $voidKey.SetColorKey([System.Drawing.Color]::FromArgb(0, 0, 0), [System.Drawing.Color]::FromArgb(28, 28, 28))

    try {
        foreach ($section in $sections) {
            $detailPath = Join-Path $SectionsPath ("{0}_hd.png" -f $section.Name)
            $detail = [System.Drawing.Image]::FromFile((Resolve-Path -LiteralPath $detailPath))
            try {
                $target = [System.Drawing.Rectangle]::new(
                    [Math]::Round($section.X * $atlasWidth / $nativeWidth),
                    [Math]::Round($section.Y * $atlasHeight / $nativeHeight),
                    [Math]::Round($section.W * $atlasWidth / $nativeWidth),
                    [Math]::Round($section.H * $atlasHeight / $nativeHeight)
                )
                $graphics.DrawImage($detail, $target, 0, 0, $detail.Width, $detail.Height, [System.Drawing.GraphicsUnit]::Pixel, $voidKey)
            }
            finally {
                $detail.Dispose()
            }
        }
    }
    finally {
        $voidKey.Dispose()
    }

    $atlas.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
}
finally {
    $graphics.Dispose()
    $atlas.Dispose()
    $source.Dispose()
}

if (Test-Path -LiteralPath $OutputPath) {
    $output = [System.Drawing.Image]::FromFile((Resolve-Path -LiteralPath $OutputPath))
    try {
        [PSCustomObject]@{
            Name = Split-Path -Leaf $OutputPath
            Width = $output.Width
            Height = $output.Height
            Bytes = (Get-Item -LiteralPath $OutputPath).Length
        }
    }
    finally {
        $output.Dispose()
    }
}
