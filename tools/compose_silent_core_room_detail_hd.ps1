param(
    [string]$GeometryPath = (Join-Path $PSScriptRoot "..\assets\backgrounds\silent_core_route_background_concept_v1.png"),
    [string]$DetailSectionsPath = (Join-Path $PSScriptRoot "..\assets\backgrounds\silent_core_sections_v2_generated"),
    [string]$OutputPath = (Join-Path $PSScriptRoot "..\assets\backgrounds\silent_core_route_background_concept_v1_refined_room_detail_safe_junctions_hd_v2.png"),
    [string]$BoundaryPath = (Join-Path $PSScriptRoot "..\data\map_boundaries_lv5.json"),
    [string]$CropOutputPath = (Join-Path $PSScriptRoot "..\assets\backgrounds\silent_core_sections_v2_source_crops"),
    [ValidateRange(0.0, 1.0)]
    [double]$DetailOpacity = 0.88,
    [switch]$ExportSourceCrops
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

# Rectangles are in the native 1448 x 1086 coordinate space.  Their overlap
# gives the section artist enough context, but every final draw is masked to
# its own gameplay room polygon rather than becoming an opaque rectangle.
$sections = @(
    @{ Name = "combat_1"; X = 0; Y = 640; W = 370; H = 446; Rooms = @(0) },
    @{ Name = "combat_2"; X = 190; Y = 540; W = 555; H = 300; Rooms = @(1) },
    @{ Name = "combat_3"; X = 660; Y = 315; W = 365; H = 390; Rooms = @(2) },
    @{ Name = "combat_4"; X = 650; Y = 115; W = 555; H = 385; Rooms = @(3) },
    @{ Name = "support"; X = 510; Y = 130; W = 370; H = 245; Rooms = @(4) },
    @{ Name = "boss"; X = 950; Y = 80; W = 498; H = 330; Rooms = @(5) }
)

# The geometry plate owns only the real door/corridor handoff.  Keeping these
# bands narrow prevents low-detail rectangular patches from cutting into the
# otherwise fully detailed rooms, while preserving the source route topology.
$junctionKeepouts = @(
    @{ X = 220; Y = 660; W = 85; H = 125 },  # Combat 1 -> Combat 2
    @{ X = 690; Y = 570; W = 35; H = 95 },   # Combat 2 -> Combat 3
    @{ X = 850; Y = 350; W = 95; H = 130 },  # Combat 3 -> Combat 4
    @{ X = 695; Y = 210; W = 145; H = 80 },  # Combat 4 -> Support
    @{ X = 980; Y = 210; W = 185; H = 80 }   # Combat 4 -> Boss
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
        $sourceRect = [System.Drawing.Rectangle]::new($section.X, $section.Y, $section.W, $section.H)
        $crop = [System.Drawing.Bitmap]::new($sourceRect.Width, $sourceRect.Height, $pixelFormat)
        $graphics = New-Graphics $crop
        try {
            $graphics.DrawImage($Source, [System.Drawing.Rectangle]::new(0, 0, $crop.Width, $crop.Height), $sourceRect.X, $sourceRect.Y, $sourceRect.Width, $sourceRect.Height, [System.Drawing.GraphicsUnit]::Pixel)
            $crop.Save((Join-Path $CropOutputPath ("{0}_source.png" -f $section.Name)), [System.Drawing.Imaging.ImageFormat]::Png)
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

    # Preserve a sliver of generated wall trim inside each room.  The exterior
    # silhouette always comes from the continuous geometry plate underneath.
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
    $matrix.Matrix33 = [single]$DetailOpacity
    $matrix.Matrix44 = 1.0
    $attributes.SetColorMatrix($matrix)
    # The image model returns a black contextual void around some crops.  It is
    # never valid floor art, so turn it transparent before the polygon mask.
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

$geometry = [System.Drawing.Image]::FromFile((Resolve-Path -LiteralPath $GeometryPath))
try {
    if ($geometry.Width -ne $nativeWidth -or $geometry.Height -ne $nativeHeight) {
        throw "Expected a $nativeWidth x $nativeHeight geometry source, found $($geometry.Width) x $($geometry.Height)."
    }
    if ($ExportSourceCrops) {
        Export-SourceCrops $geometry
        Get-ChildItem -LiteralPath $CropOutputPath -Filter "*_source.png" | Select-Object Name, Length
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
        # Geometry first: void, outer wall silhouette, every doorway and all
        # narrow junctions remain source-authored regardless of generated art.
        $graphics.DrawImage($geometry, [System.Drawing.Rectangle]::new(0, 0, $atlasWidth, $atlasHeight))
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
    $geometry.Dispose()
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
