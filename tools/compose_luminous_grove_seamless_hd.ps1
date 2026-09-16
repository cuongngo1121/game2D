param(
    [string]$SourcePath = (Join-Path $PSScriptRoot "..\assets\backgrounds\luminous_grove_route_background_concept_v1.png"),
    [string]$OutputPath = (Join-Path $PSScriptRoot "..\assets\backgrounds\luminous_grove_route_background_concept_v1_seamless_hd_v3.png")
)

Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Drawing

# The previous HD plate overlaid six independently restored crops. Their floor
# motifs ended at different pixels, which exposed a seam at room connectors.
# This replacement scales the one authored source canvas in a single draw pass,
# so every corridor and its adjoining room share the exact same image surface.
$atlasWidth = 5120
$atlasHeight = 3840
$pixelFormat = [System.Drawing.Imaging.PixelFormat]::Format32bppPArgb
$source = [System.Drawing.Image]::FromFile((Resolve-Path -LiteralPath $SourcePath))
$atlas = [System.Drawing.Bitmap]::new($atlasWidth, $atlasHeight, $pixelFormat)
$graphics = [System.Drawing.Graphics]::FromImage($atlas)

try {
    $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.DrawImage($source, [System.Drawing.Rectangle]::new(0, 0, $atlasWidth, $atlasHeight))
    $atlas.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
}
finally {
    $graphics.Dispose()
    $atlas.Dispose()
    $source.Dispose()
}
