<#
Generate the native 64x64 REFACTOR boss animation set for Zone 4 (PRISM SPIRE).

The supplied transparent boss model is the visual authority. Every runtime
frame is built from one nearest-neighbour canonical pose so the six articulated
prism limbs, floating shards, central diamond core and cyan eye stay recognisable
in idle, movement, attack, hurt and death.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

$projectRoot = Split-Path -Parent $PSScriptRoot
$referencePath = Join-Path $projectRoot 'assets\concepts\bosses\refractor_reference_user_source_v2.png'
$outputRoot = Join-Path $projectRoot 'assets\sprites\pixel_64\bosses\refractor'
$animationRoot = Join-Path $outputRoot 'animations'
$frameSize = 64

if (-not (Test-Path -LiteralPath $referencePath)) {
	throw "Missing supplied REFACTOR reference: $referencePath"
}

$script:palette = @{
	cyan = [System.Drawing.Color]::FromArgb(255, 57, 232, 255)
	violet = [System.Drawing.Color]::FromArgb(255, 142, 100, 255)
	prism = [System.Drawing.Color]::FromArgb(255, 222, 247, 255)
	pink = [System.Drawing.Color]::FromArgb(255, 255, 112, 225)
	ice = [System.Drawing.Color]::FromArgb(255, 248, 255, 255)
	ink = [System.Drawing.Color]::FromArgb(255, 14, 18, 43)
	transparent = [System.Drawing.Color]::FromArgb(0, 0, 0, 0)
}

function Get-Tone([string]$name, [int]$alpha = 255) {
	$base = $script:palette[$name]
	return [System.Drawing.Color]::FromArgb($alpha, $base.R, $base.G, $base.B)
}

function New-TransparentBitmap([int]$width, [int]$height) {
	$bitmap = [System.Drawing.Bitmap]::new($width, $height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
	$bitmap.SetResolution(96, 96)
	return $bitmap
}

function Use-PixelDrawing([System.Drawing.Graphics]$graphics) {
	$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
	$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
	$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
	$graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighSpeed
}

function Add-PrismHaloBehind([System.Drawing.Bitmap]$bitmap, [int]$radius, [int]$alpha) {
	if ($radius -le 0 -or $alpha -le 0) {
		return
	}
	$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
	$brush = [System.Drawing.SolidBrush]::new((Get-Tone 'violet' $alpha))
	$pen = [System.Drawing.Pen]::new((Get-Tone 'cyan' ([Math]::Min(255, $alpha + 70))), 1.0)
	try {
		Use-PixelDrawing $graphics
		$diamond = [System.Drawing.Point[]]@(
			[System.Drawing.Point]::new(32, 29 - $radius),
			[System.Drawing.Point]::new(32 + $radius, 29),
			[System.Drawing.Point]::new(32, 29 + $radius),
			[System.Drawing.Point]::new(32 - $radius, 29)
		)
		$graphics.FillPolygon($brush, $diamond)
		$graphics.DrawPolygon($pen, $diamond)
	} finally {
		$pen.Dispose()
		$brush.Dispose()
		$graphics.Dispose()
	}
}

function Add-MotionArcs([System.Drawing.Bitmap]$bitmap, [int]$frame) {
	$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
	$cyanPen = [System.Drawing.Pen]::new((Get-Tone 'cyan' 140), 1.0)
	$violetPen = [System.Drawing.Pen]::new((Get-Tone 'violet' 130), 1.0)
	try {
		Use-PixelDrawing $graphics
		$offset = $frame % 3
		$graphics.DrawLine($cyanPen, 4, 52 + $offset, 19, 52 + $offset)
		$graphics.DrawLine($violetPen, 45, 55 - $offset, 60, 55 - $offset)
		$graphics.DrawLine($violetPen, 6, 60 - $offset, 23, 60 - $offset)
		$graphics.DrawLine($cyanPen, 41, 61, 57, 61)
	} finally {
		$violetPen.Dispose()
		$cyanPen.Dispose()
		$graphics.Dispose()
	}
}

function Draw-Canonical([System.Drawing.Bitmap]$destination, [int]$dx = 0, [int]$dy = 0, [double]$scale = 1.0) {
	$graphics = [System.Drawing.Graphics]::FromImage($destination)
	try {
		Use-PixelDrawing $graphics
		$drawSize = [int][Math]::Round(62.0 * $scale)
		$originX = [int][Math]::Round(($frameSize - $drawSize) / 2.0) + $dx
		$originY = [int][Math]::Round(($frameSize - $drawSize) / 2.0) + $dy
		$graphics.DrawImage($script:canonical, [System.Drawing.Rectangle]::new($originX, $originY, $drawSize, $drawSize), 0, 0, $frameSize, $frameSize, [System.Drawing.GraphicsUnit]::Pixel)
	} finally {
		$graphics.Dispose()
	}
}

function Add-CoreGlint([System.Drawing.Bitmap]$bitmap, [int]$energy, [string]$tone = 'prism') {
	$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
	$alpha = [Math]::Min(255, 115 + $energy)
	$brush = [System.Drawing.SolidBrush]::new((Get-Tone $tone $alpha))
	try {
		Use-PixelDrawing $graphics
		$graphics.FillRectangle($brush, 31, 25, 2, 9)
		$graphics.FillRectangle($brush, 27, 29, 10, 2)
		$graphics.FillRectangle($brush, 29, 27, 6, 6)
		$graphics.FillRectangle($brush, 31, 18, 2, 3)
	} finally {
		$brush.Dispose()
		$graphics.Dispose()
	}
}

function Add-OrbitingShards([System.Drawing.Bitmap]$bitmap, [int]$frame, [int]$alpha) {
	$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
	$brush = [System.Drawing.SolidBrush]::new((Get-Tone 'violet' $alpha))
	$pen = [System.Drawing.Pen]::new((Get-Tone 'cyan' ([Math]::Min(255, $alpha + 45))), 1.0)
	try {
		Use-PixelDrawing $graphics
		$positions = @(
			@(@(12, 24), @(17, 18), @(22, 15), @(16, 20), @(10, 28), @(14, 31)),
			@(@(52, 24), @(47, 18), @(42, 15), @(48, 20), @(54, 28), @(50, 31))
		)
		for ($side = 0; $side -lt 2; $side++) {
			$p = $positions[$side][$frame % 6]
			$diamond = [System.Drawing.Point[]]@(
				[System.Drawing.Point]::new($p[0], $p[1] - 2),
				[System.Drawing.Point]::new($p[0] + 2, $p[1]),
				[System.Drawing.Point]::new($p[0], $p[1] + 2),
				[System.Drawing.Point]::new($p[0] - 2, $p[1])
			)
			$graphics.FillPolygon($brush, $diamond)
			$graphics.DrawPolygon($pen, $diamond)
		}
	} finally {
		$pen.Dispose()
		$brush.Dispose()
		$graphics.Dispose()
	}
}

function Add-RefractionBurst([System.Drawing.Bitmap]$bitmap, [int]$frame) {
	$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
	$radius = @(7, 12, 20, 11)[$frame]
	$alpha = @(85, 140, 215, 110)[$frame]
	$cyanPen = [System.Drawing.Pen]::new((Get-Tone 'cyan' $alpha), 1.0)
	$prismPen = [System.Drawing.Pen]::new((Get-Tone 'prism' ([Math]::Min(255, $alpha + 30))), 1.0)
	try {
		Use-PixelDrawing $graphics
		$diamond = [System.Drawing.Point[]]@(
			[System.Drawing.Point]::new(32, 29 - $radius),
			[System.Drawing.Point]::new(32 + $radius, 29),
			[System.Drawing.Point]::new(32, 29 + $radius),
			[System.Drawing.Point]::new(32 - $radius, 29)
		)
		$graphics.DrawPolygon($cyanPen, $diamond)
		$graphics.DrawLine($prismPen, 32, [Math]::Max(2, 27 - $frame * 4), 32, [Math]::Min(61, 31 + $frame * 7))
		if ($frame -ge 1) {
			$graphics.DrawLine($cyanPen, [Math]::Max(1, 30 - $frame * 8), 29, [Math]::Min(62, 34 + $frame * 8), 29)
		}
		if ($frame -eq 2) {
			$graphics.DrawLine($prismPen, 14, 12, 50, 48)
			$graphics.DrawLine($prismPen, 50, 12, 14, 48)
		}
	} finally {
		$prismPen.Dispose()
		$cyanPen.Dispose()
		$graphics.Dispose()
	}
}

function New-Frame([int]$dx = 0, [int]$dy = 0, [double]$scale = 1.0, [int]$pulseRadius = 0, [int]$pulseAlpha = 0, [int]$trailStep = -1, [int]$glintEnergy = 0, [int]$orbitFrame = -1) {
	$frame = New-TransparentBitmap $frameSize $frameSize
	$graphics = [System.Drawing.Graphics]::FromImage($frame)
	try {
		$graphics.Clear($script:palette.transparent)
	} finally {
		$graphics.Dispose()
	}
	if ($trailStep -ge 0) {
		Add-MotionArcs $frame $trailStep
	}
	Add-PrismHaloBehind $frame $pulseRadius $pulseAlpha
	Draw-Canonical $frame $dx $dy $scale
	if ($orbitFrame -ge 0) {
		Add-OrbitingShards $frame $orbitFrame 170
	}
	if ($glintEnergy -gt 0) {
		Add-CoreGlint $frame $glintEnergy
	}
	return $frame
}

function Apply-HurtRefraction([System.Drawing.Bitmap]$bitmap, [int]$frame) {
	for ($y = 0; $y -lt $frameSize; $y++) {
		for ($x = 0; $x -lt $frameSize; $x++) {
			$pixel = $bitmap.GetPixel($x, $y)
			if ($pixel.A -eq 0) {
				continue
			}
			if ($frame -eq 1 -and (($x + $y) % 2 -eq 0)) {
				$bitmap.SetPixel($x, $y, (Get-Tone 'ice' $pixel.A))
			} elseif ($frame -ne 1 -and (($x * 7 + $y + $frame) % 5 -eq 0)) {
				$bitmap.SetPixel($x, $y, (Get-Tone 'pink' $pixel.A))
			}
		}
	}
}

function New-DeathFrame([int]$frame) {
	$result = New-Frame 0 ([Math]::Min(8, $frame * 2)) (1.0 - $frame * 0.075) 0 0 -1 0 -1
	$cutoff = 63 - $frame * 7
	for ($y = 0; $y -lt $frameSize; $y++) {
		for ($x = 0; $x -lt $frameSize; $x++) {
			$pixel = $result.GetPixel($x, $y)
			if ($pixel.A -eq 0) {
				continue
			}
			$dissolve = (($x * 17 + $y * 11 + $frame * 13) % 15) -lt ($frame * 2)
			if ($y -gt $cutoff -or $dissolve) {
				$result.SetPixel($x, $y, $script:palette.transparent)
			} elseif ($frame -ge 2) {
				$alpha = [Math]::Max(20, $pixel.A - $frame * 36)
				$result.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($alpha, $pixel.R, $pixel.G, $pixel.B))
			}
		}
	}
	$graphics = [System.Drawing.Graphics]::FromImage($result)
	$cyanBrush = [System.Drawing.SolidBrush]::new((Get-Tone 'cyan' ([Math]::Max(35, 220 - $frame * 26))))
	$violetBrush = [System.Drawing.SolidBrush]::new((Get-Tone 'violet' ([Math]::Max(35, 210 - $frame * 25))))
	try {
		Use-PixelDrawing $graphics
		$graphics.FillRectangle($cyanBrush, [Math]::Min(61, 6 + $frame * 5), [Math]::Max(1, 19 - $frame), 2, 2)
		$graphics.FillRectangle($violetBrush, [Math]::Max(1, 56 - $frame * 4), [Math]::Min(61, 34 + $frame * 3), 2, 2)
		$graphics.FillRectangle($cyanBrush, [Math]::Min(61, 23 + $frame * 4), [Math]::Min(61, 48 + $frame), 2, 2)
	} finally {
		$violetBrush.Dispose()
		$cyanBrush.Dispose()
		$graphics.Dispose()
	}
	return $result
}

function New-Sheet([object[]]$frames) {
	$sheet = New-TransparentBitmap ($frameSize * $frames.Count) $frameSize
	$graphics = [System.Drawing.Graphics]::FromImage($sheet)
	try {
		Use-PixelDrawing $graphics
		$graphics.Clear($script:palette.transparent)
		for ($index = 0; $index -lt $frames.Count; $index++) {
			$graphics.DrawImage($frames[$index], [System.Drawing.Rectangle]::new($index * $frameSize, 0, $frameSize, $frameSize), 0, 0, $frameSize, $frameSize, [System.Drawing.GraphicsUnit]::Pixel)
		}
	} finally {
		$graphics.Dispose()
	}
	return $sheet
}

function Write-Animation([string]$name, [object[]]$frames, [double]$fps, [bool]$loop) {
	$stem = 'refractor_{0}_{1}x64' -f $name, $frames.Count
	$sheetPath = Join-Path $animationRoot ($stem + '.png')
	$framePaths = @()
	for ($index = 0; $index -lt $frames.Count; $index++) {
		$framePath = Join-Path $animationRoot ('{0}_{1}.png' -f $stem, $index)
		$frames[$index].Save($framePath, [System.Drawing.Imaging.ImageFormat]::Png)
		$framePaths += ('assets/sprites/pixel_64/bosses/refractor/animations/{0}_{1}.png' -f $stem, $index)
	}
	$sheet = New-Sheet $frames
	try {
		$sheet.Save($sheetPath, [System.Drawing.Imaging.ImageFormat]::Png)
	} finally {
		$sheet.Dispose()
		foreach ($frame in $frames) {
			$frame.Dispose()
		}
	}
	return [ordered]@{
		id = 'refractor'
		animation = $name
		frames = $frames.Count
		fps = $fps
		loop = $loop
		sheet = 'assets/sprites/pixel_64/bosses/refractor/animations/{0}.png' -f $stem
		frame_paths = $framePaths
	}
}

New-Item -ItemType Directory -Force -Path $outputRoot, $animationRoot | Out-Null

$reference = [System.Drawing.Bitmap]::new($referencePath)
try {
	$script:canonical = New-TransparentBitmap $frameSize $frameSize
	$graphics = [System.Drawing.Graphics]::FromImage($script:canonical)
	try {
		Use-PixelDrawing $graphics
		$graphics.Clear($script:palette.transparent)
		# Preserve a transparent safety margin for subtle locomotion and recoil.
		$graphics.DrawImage($reference, [System.Drawing.Rectangle]::new(1, 1, 62, 62), 0, 0, $reference.Width, $reference.Height, [System.Drawing.GraphicsUnit]::Pixel)
	} finally {
		$graphics.Dispose()
	}
	$script:canonical.Save((Join-Path $outputRoot 'refractor_model_64.png'), [System.Drawing.Imaging.ImageFormat]::Png)

	$preview = New-TransparentBitmap 320 320
	$previewGraphics = [System.Drawing.Graphics]::FromImage($preview)
	try {
		Use-PixelDrawing $previewGraphics
		$previewGraphics.Clear($script:palette.transparent)
		$previewGraphics.DrawImage($script:canonical, [System.Drawing.Rectangle]::new(0, 0, 320, 320), 0, 0, $frameSize, $frameSize, [System.Drawing.GraphicsUnit]::Pixel)
		$preview.Save((Join-Path $outputRoot 'refractor_model_64_preview_5x.png'), [System.Drawing.Imaging.ImageFormat]::Png)
	} finally {
		$previewGraphics.Dispose()
		$preview.Dispose()
	}

	$entries = @()
	$idle = @()
	foreach ($index in 0..3) {
		$frame = New-Frame 0 @(-1, 0, 1, 0)[$index] 1.0 @(5, 8, 11, 8)[$index] @(32, 58, 92, 58)[$index] -1 @(30, 62, 98, 62)[$index] $index
		$idle += $frame
	}
	$entries += Write-Animation 'idle' $idle 6.0 $true

	$move = @()
	$moveOffsets = @(@(0, 1), @(1, 0), @(1, -1), @(0, -1), @(-1, 0), @(-1, 1))
	foreach ($index in 0..5) {
		$frame = New-Frame $moveOffsets[$index][0] $moveOffsets[$index][1] 0.98 5 40 $index @(42, 58, 74, 58, 42, 30)[$index] $index
		$move += $frame
	}
	$entries += Write-Animation 'move' $move 10.0 $true

	$attack = @()
	$attackSpecs = @(@(0.97, 8, 42), @(0.99, 12, 80), @(1.0, 18, 140), @(0.98, 10, 70))
	foreach ($index in 0..3) {
		$frame = New-Frame 0 0 $attackSpecs[$index][0] $attackSpecs[$index][1] $attackSpecs[$index][2] -1 @(66, 122, 194, 104)[$index] $index
		Add-RefractionBurst $frame $index
		$attack += $frame
	}
	$entries += Write-Animation 'attack' $attack 12.0 $false

	$hurt = @()
	foreach ($index in 0..2) {
		$frame = New-Frame @(-1, 1, 0)[$index] 0 0.98 0 0 -1 0 -1
		Apply-HurtRefraction $frame $index
		$hurt += $frame
	}
	$entries += Write-Animation 'hurt' $hurt 10.0 $false

	$death = @()
	foreach ($index in 0..5) {
		$death += New-DeathFrame $index
	}
	$entries += Write-Animation 'death' $death 8.0 $false

	$manifest = [ordered]@{
		format = 'RGBA PNG'
		frame_dimensions = [ordered]@{ width = $frameSize; height = $frameSize }
		filter = 'nearest'
		source_concept = 'assets/concepts/bosses/refractor_reference_user_source_v2.png'
		runtime_kind = 'boss3'
		animations = $entries
	}
	[System.IO.File]::WriteAllText((Join-Path $outputRoot 'animation_manifest.json'), ($manifest | ConvertTo-Json -Depth 8), [System.Text.UTF8Encoding]::new($false))

	$readme = @(
		'# REFACTOR - boss 64x64',
		'',
		'Native 64x64 RGBA pixel frames for the PRISM SPIRE boss. The player-supplied',
		'model at `assets/concepts/bosses/refractor_reference_user_source_v2.png` is',
		'the source of truth. The runtime loads the horizontal sheets for `boss3`.',
		'',
		'| Animation | Frames | FPS | Loop | Runtime state |',
		'| --- | ---: | ---: | :---: | --- |',
		'| `idle` | 4 | 6 | Yes | Core pulse and floating prism orbit |',
		'| `move` | 6 | 10 | Yes | Mechanical leg glide and refraction trail |',
		'| `attack` | 4 | 12 | No | Laser charge and prism burst |',
		'| `hurt` | 3 | 10 | No | Magenta refraction damage response |',
		'| `death` | 6 | 8 | No | Prism-collapse disintegration before reward UI |',
		'',
		'Each `*_Nx64.png` is the runtime spritesheet. Numbered PNG files are',
		'individual editable frames. Regenerate the whole package with:',
		'',
		'```powershell',
		'.\tools\generate_refractor_64.ps1',
		'```'
	) -join [Environment]::NewLine
	[System.IO.File]::WriteAllText((Join-Path $outputRoot 'README_PIXELORAMA.md'), $readme.Trim() + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
} finally {
	if ($null -ne $script:canonical) { $script:canonical.Dispose() }
	$reference.Dispose()
}

Write-Host "Generated REFACTOR 64px model and 5 animation sheets in $outputRoot"
