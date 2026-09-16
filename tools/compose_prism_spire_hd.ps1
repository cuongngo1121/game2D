param(
    [string]$SourcePath = (Join-Path $PSScriptRoot "..\assets\backgrounds\prism_spire_route_background_concept_v1.png"),
    [string]$SectionsPath = (Join-Path $PSScriptRoot "..\tmp\prism_spire_hd_sections"),
    [string]$OutputPath = (Join-Path $PSScriptRoot "..\assets\backgrounds\prism_spire_route_background_concept_v1_tiled_restored_hd_v1.png")
)

Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Drawing

# These source-space rectangles deliberately overlap at doorways. The HD
# reconstruction is applied section by section while the original map remains
# underneath, preserving the continuous dark void and exact route silhouette.
$sections = @(
    @{ Name = "combat_1"; X = 0; Y = 700; W = 390; H = 386 },
    @{ Name = "combat_2"; X = 210; Y = 470; W = 530; H = 390 },
    @{ Name = "support"; X = 455; Y = 580; W = 250; H = 406 },
    @{ Name = "combat_3"; X = 620; Y = 300; W = 450; H = 360 },
    @{ Name = "combat_4"; X = 760; Y = 35; W = 380; H = 380 },
    @{ Name = "boss"; X = 1130; Y = 60; W = 318; H = 300 }
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
