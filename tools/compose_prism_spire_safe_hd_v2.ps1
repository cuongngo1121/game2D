param(
    [string]$SourcePath = (Join-Path $PSScriptRoot "..\assets\backgrounds\prism_spire_route_background_user_geometry_v2.png"),
    [string]$DetailSectionsPath = (Join-Path $PSScriptRoot "..\assets\backgrounds\prism_spire_sections_v2_generated"),
    [string]$OutputPath = (Join-Path $PSScriptRoot "..\assets\backgrounds\prism_spire_route_background_concept_v1_refined_room_detail_safe_junctions_hd_v4.png"),
    [string]$BoundaryPath = (Join-Path $PSScriptRoot "..\data\map_boundaries_lv4.json"),
    [string]$CropOutputPath = (Join-Path $PSScriptRoot "..\tmp\prism_spire_v2_source_crops"),
    [ValidateRange(0.0, 1.0)]
    [double]$DetailOpacity = 0.88,
    [switch]$ExportSourceCrops
)

Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Drawing

# All rectangles use the native 1448 x 1086 coordinate system.  They overlap
# only to supply image-generation context; the compositor never draws them as
# opaque rectangles over the final atlas.
$sections = @(
    @{ Name = "combat_1"; X = 0; Y = 700; W = 390; H = 386; Rooms = @(0) },
    @{ Name = "combat_2"; X = 210; Y = 470; W = 530; H = 390; Rooms = @(1) },
    @{ Name = "support"; X = 455; Y = 580; W = 250; H = 406; Rooms = @(4) },
    @{ Name = "combat_3"; X = 620; Y = 300; W = 450; H = 360; Rooms = @(2) },
    @{ Name = "combat_4"; X = 760; Y = 35; W = 380; H = 380; Rooms = @(3) },
    @{ Name = "boss"; X = 1130; Y = 60; W = 318; H = 300; Rooms = @(5) }
)

# Geometry plate owns only the physical door/corridor handoff at each junction.
# These are deliberately small: a large rectangular keepout removes too much
# of the authored room material and reads as a low-detail patch in the atlas.
# The six detail sources keep their full room surfaces; the base plate remains
# solely at the exact places where two separately generated sections meet.
$junctionKeepouts = @(
    @{ X = 235; Y = 770; W = 55; H = 90 },  # Combat 1 -> Combat 2
    @{ X = 540; Y = 685; W = 95; H = 130 }, # Combat 2 -> Support
    @{ X = 620; Y = 500; W = 45; H = 100 }, # Combat 2 -> Combat 3
    @{ X = 600; Y = 575; W = 45; H = 105 }, # Combat 3 -> Support
    @{ X = 835; Y = 290; W = 105; H = 70 }, # Combat 3 -> Combat 4
    @{ X = 1140; Y = 150; W = 80; H = 80 }  # Combat 4 -> Boss
)

$nativeWidth = 1448.0
$nativeHeight = 1086.0
$atlasWidth = 5120
$atlasHeight = 3840
$scaleX = $atlasWidth / $nativeWidth
$scaleY = $atlasHeight / $nativeHeight
$pixelFormat = [System.Drawing.Imaging.PixelFormat]::Format32bppPArgb

function New-Graphics([System.Drawing.Bitmap]$Bitmap) {
    $graphics = [System.Drawing.Graphics]::FromImage($Bitmap)
    $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    return $graphics
}

function Get-AtlasRect($Rect) {
    return [System.Drawing.Rectangle]::new(
        [Math]::Round($Rect.X * $scaleX),
        [Math]::Round($Rect.Y * $scaleY),
        [Math]::Round($Rect.W * $scaleX),
        [Math]::Round($Rect.H * $scaleY)
    )
}

function Export-SourceCrops([System.Drawing.Image]$Source) {
    New-Item -ItemType Directory -Force -Path $CropOutputPath | Out-Null
    foreach ($section in $sections) {
        $target = Get-AtlasRect $section
        $crop = [System.Drawing.Bitmap]::new($target.Width, $target.Height, $pixelFormat)
        $graphics = New-Graphics $crop
        try {
            $sourceRect = [System.Drawing.Rectangle]::new($section.X, $section.Y, $section.W, $section.H)
            $graphics.DrawImage($Source, [System.Drawing.Rectangle]::new(0, 0, $target.Width, $target.Height), $sourceRect.X, $sourceRect.Y, $sourceRect.Width, $sourceRect.Height, [System.Drawing.GraphicsUnit]::Pixel)
            $crop.Save((Join-Path $CropOutputPath ("{0}_source_hd.png" -f $section.Name)), [System.Drawing.Imaging.ImageFormat]::Png)
        }
        finally {
            $graphics.Dispose()
            $crop.Dispose()
        }
    }
}

function New-RoomRegion($Boundary, $RoomIndexes) {
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    foreach ($roomIndex in $RoomIndexes) {
        $points = [System.Collections.Generic.List[System.Drawing.PointF]]::new()
        foreach ($point in $Boundary.rooms."$roomIndex") {
            $points.Add([System.Drawing.PointF]::new([single]($point[0] * $scaleX), [single]($point[1] * $scaleY)))
        }
        $path.AddPolygon([System.Drawing.PointF[]]$points.ToArray())
    }

    # Keep a narrow amount of wall/trim detail, while the exterior silhouette
    # and all outer edge pixels remain supplied by the continuous base plate.
    $expanded = $path.Clone()
    $pen = [System.Drawing.Pen]::new([System.Drawing.Color]::White, [single](20.0 * [Math]::Min($scaleX, $scaleY)))
    try {
        $expanded.Widen($pen)
        $path.AddPath($expanded, $false)
    }
    finally {
        $pen.Dispose()
        $expanded.Dispose()
    }

    $region = [System.Drawing.Region]::new($path)
    foreach ($keepout in $junctionKeepouts) {
        $region.Exclude((Get-AtlasRect $keepout))
    }
    $path.Dispose()
    return $region
}

function Draw-DetailSection([System.Drawing.Graphics]$Graphics, $Section, $Boundary) {
    $detailPath = Join-Path $DetailSectionsPath ("{0}_hd.png" -f $Section.Name)
    if (-not (Test-Path -LiteralPath $detailPath)) {
        throw "Missing generated detail section: $detailPath"
    }

    $detail = [System.Drawing.Image]::FromFile((Resolve-Path -LiteralPath $detailPath))
    $attributes = [System.Drawing.Imaging.ImageAttributes]::new()
    $matrix = [System.Drawing.Imaging.ColorMatrix]::new()
    $matrix.Matrix00 = 1.0
    $matrix.Matrix11 = 1.0
    $matrix.Matrix22 = 1.0
    # v4 is the delivery atlas: room detail is intentionally prominent, while
    # the geometry plate still owns all keepouts, void and external silhouette.
    $matrix.Matrix33 = [single]$DetailOpacity
    $matrix.Matrix44 = 1.0
    $attributes.SetColorMatrix($matrix)
    # Generated crops contain contextual black void.  It is never map detail:
    # make it transparent before the region mask is applied so it cannot hide
    # a valid corridor or leave a dark rectangular seam inside a room polygon.
    $attributes.SetColorKey([System.Drawing.Color]::FromArgb(0, 0, 0), [System.Drawing.Color]::FromArgb(24, 24, 24))
    $region = New-RoomRegion $Boundary $Section.Rooms
    $state = $Graphics.Save()
    try {
        $Graphics.SetClip($region, [System.Drawing.Drawing2D.CombineMode]::Replace)
        $target = Get-AtlasRect $Section
        $Graphics.DrawImage($detail, $target, 0, 0, $detail.Width, $detail.Height, [System.Drawing.GraphicsUnit]::Pixel, $attributes)
    }
    finally {
        $Graphics.Restore($state)
        $region.Dispose()
        $attributes.Dispose()
        $detail.Dispose()
    }
}

$source = [System.Drawing.Image]::FromFile((Resolve-Path -LiteralPath $SourcePath))
try {
    if ($source.Width -ne $nativeWidth -or $source.Height -ne $nativeHeight) {
        throw "Expected a $nativeWidth x $nativeHeight geometry source, found $($source.Width) x $($source.Height)."
    }
    if ($ExportSourceCrops) {
        Export-SourceCrops $source
        Get-ChildItem -LiteralPath $CropOutputPath -Filter "*_source_hd.png" | Select-Object Name, Length
        return
    }

    if (-not (Test-Path -LiteralPath $BoundaryPath)) {
        throw "Missing boundary source: $BoundaryPath"
    }
    $boundary = Get-Content -LiteralPath $BoundaryPath -Raw | ConvertFrom-Json
    if ($boundary.art_size[0] -ne $nativeWidth -or $boundary.art_size[1] -ne $nativeHeight) {
        throw "Boundary art_size must remain $nativeWidth x $nativeHeight."
    }

    $outputDirectory = Split-Path -Parent $OutputPath
    New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
    $atlas = [System.Drawing.Bitmap]::new($atlasWidth, $atlasHeight, $pixelFormat)
    $graphics = New-Graphics $atlas
    try {
        # Continuous geometry plate: it is drawn first and remains the source
        # of truth for every void, wall silhouette, corridor and room junction.
        $graphics.DrawImage($source, [System.Drawing.Rectangle]::new(0, 0, $atlasWidth, $atlasHeight))
        foreach ($section in $sections) {
            Draw-DetailSection $graphics $section $boundary
        }
        $atlas.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $graphics.Dispose()
        $atlas.Dispose()
    }
}
finally {
    $source.Dispose()
}

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
