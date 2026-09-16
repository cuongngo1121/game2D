<#
Generate the native 64x64 CHOIR WIDOW boss animation set for Area 3.

The supplied transparent boss model remains the visual authority. This script
builds all runtime frames from one fixed nearest-neighbour 64px canonical pose,
so the silhouette, leaf fins, mask, bells, crystals and six legs remain stable
between idle, movement, attack, hurt and death.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

$projectRoot = Split-Path -Parent $PSScriptRoot
$referencePath = Join-Path $projectRoot 'assets\concepts\bosses\choir_widow_reference_user_source_v1.png'
$outputRoot = Join-Path $projectRoot 'assets\sprites\pixel_64\bosses\choir_widow'
$animationRoot = Join-Path $outputRoot 'animations'
$frameSize = 64

if (-not (Test-Path -LiteralPath $referencePath)) {
	throw "Missing supplied CHOIR WIDOW reference: $referencePath"
}

$script:palette = @{
	mint = [System.Drawing.Color]::FromArgb(255, 104, 255, 192)
	aqua = [System.Drawing.Color]::FromArgb(255, 56, 232, 255)
	violet = [System.Drawing.Color]::FromArgb(255, 176, 102, 255)
	gold = [System.Drawing.Color]::FromArgb(255, 248, 196, 92)
	ice = [System.Drawing.Color]::FromArgb(255, 228, 255, 245)
	coral = [System.Drawing.Color]::FromArgb(255, 255, 108, 134)
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

function Add-LeafPulseBehind([System.Drawing.Bitmap]$bitmap, [int]$radius, [int]$alpha) {
	if ($radius -le 0 -or $alpha -le 0) {
		return
	}
	$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
	$brush = [System.Drawing.SolidBrush]::new((Get-Tone 'mint' $alpha))
	$pen = [System.Drawing.Pen]::new((Get-Tone 'aqua' ([Math]::Min(255, $alpha + 70))), 1.0)
	try {
		Use-PixelDrawing $graphics
		$bounds = [System.Drawing.Rectangle]::new(32 - $radius, 28 - $radius, $radius * 2, $radius * 2)
		$graphics.FillEllipse($brush, $bounds)
		$graphics.DrawEllipse($pen, $bounds)
	} finally {
		$pen.Dispose()
		$brush.Dispose()
		$graphics.Dispose()
	}
}

function Add-MotionTrail([System.Drawing.Bitmap]$bitmap, [int]$frame) {
	$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
	$mintPen = [System.Drawing.Pen]::new((Get-Tone 'mint' 120), 1.0)
	$violetPen = [System.Drawing.Pen]::new((Get-Tone 'violet' 115), 1.0)
	try {
		Use-PixelDrawing $graphics
		$offset = $frame % 3
		$graphics.DrawLine($mintPen, 5, 53 + $offset, 20, 53 + $offset)
		$graphics.DrawLine($violetPen, 43, 56 - $offset, 59, 56 - $offset)
		$graphics.DrawLine($violetPen, 8, 60 - $offset, 25, 60 - $offset)
		$graphics.DrawLine($mintPen, 39, 61, 55, 61)
	} finally {
		$violetPen.Dispose()
		$mintPen.Dispose()
		$graphics.Dispose()
	}
}

function Draw-Canonical([System.Drawing.Bitmap]$destination, [int]$dx = 0, [int]$dy = 0, [double]$scale = 1.0) {
	$graphics = [System.Drawing.Graphics]::FromImage($destination)
	try {
		Use-PixelDrawing $graphics
		$drawSize = [int][Math]::Round($frameSize * $scale)
		$originX = [int][Math]::Round(($frameSize - $drawSize) / 2.0) + $dx
		$originY = [int][Math]::Round(($frameSize - $drawSize) / 2.0) + $dy
		$graphics.DrawImage($script:canonical, [System.Drawing.Rectangle]::new($originX, $originY, $drawSize, $drawSize), 0, 0, $frameSize, $frameSize, [System.Drawing.GraphicsUnit]::Pixel)
	} finally {
		$graphics.Dispose()
	}
}

function Add-ResonanceGlyph([System.Drawing.Bitmap]$bitmap, [int]$energy, [string]$tone = 'mint') {
	$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
	$alpha = [Math]::Min(255, 120 + $energy)
	$brush = [System.Drawing.SolidBrush]::new((Get-Tone $tone $alpha))
	try {
		Use-PixelDrawing $graphics
		# Eye and chest core: a small glyph makes the otherwise subtle breathing
		# cycle readable at native 64px without changing the supplied silhouette.
		$graphics.FillRectangle($brush, 31, 18, 2, 4)
		$graphics.FillRectangle($brush, 30, 20, 4, 1)
		$graphics.FillRectangle($brush, 31, 31, 2, 6)
		$graphics.FillRectangle($brush, 29, 33, 6, 2)
	} finally {
		$brush.Dispose()
		$graphics.Dispose()
	}
}

function Add-AttackBurst([System.Drawing.Bitmap]$bitmap, [int]$frame) {
	$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
	$radius = @(7, 12, 18, 10)[$frame]
	$alpha = @(80, 130, 190, 105)[$frame]
	$pen = [System.Drawing.Pen]::new((Get-Tone 'aqua' $alpha), 1.0)
	$goldBrush = [System.Drawing.SolidBrush]::new((Get-Tone 'gold' ([Math]::Min(255, $alpha + 35))))
	try {
		Use-PixelDrawing $graphics
		$graphics.DrawEllipse($pen, [System.Drawing.Rectangle]::new(32 - $radius, 29 - $radius, $radius * 2, $radius * 2))
		$graphics.FillRectangle($goldBrush, 31, [Math]::Max(2, 27 - $frame * 3), 2, 4 + $frame * 2)
		if ($frame -ge 1) {
			$graphics.DrawLine($pen, 13, 29, 51, 29)
			$graphics.DrawLine($pen, 32, 9, 32, 49)
		}
		if ($frame -eq 2) {
			$graphics.FillRectangle($goldBrush, 23, 28, 18, 2)
			$graphics.FillRectangle($goldBrush, 30, 20, 4, 18)
		}
	} finally {
		$goldBrush.Dispose()
		$pen.Dispose()
		$graphics.Dispose()
	}
}

function New-Frame([int]$dx = 0, [int]$dy = 0, [double]$scale = 1.0, [int]$pulseRadius = 0, [int]$pulseAlpha = 0, [int]$trailStep = -1, [int]$glyphEnergy = 0) {
	$frame = New-TransparentBitmap $frameSize $frameSize
	$graphics = [System.Drawing.Graphics]::FromImage($frame)
	try {
		$graphics.Clear($script:palette.transparent)
	} finally {
		$graphics.Dispose()
	}
	if ($trailStep -ge 0) {
		Add-MotionTrail $frame $trailStep
	}
	Add-LeafPulseBehind $frame $pulseRadius $pulseAlpha
	Draw-Canonical $frame $dx $dy $scale
	if ($glyphEnergy -gt 0) {
		Add-ResonanceGlyph $frame $glyphEnergy
	}
	return $frame
}

function Apply-HurtTint([System.Drawing.Bitmap]$bitmap, [int]$frame) {
	for ($y = 0; $y -lt $frameSize; $y++) {
		for ($x = 0; $x -lt $frameSize; $x++) {
			$pixel = $bitmap.GetPixel($x, $y)
			if ($pixel.A -eq 0) {
				continue
			}
			if ($frame -eq 1 -and (($x + $y) % 2 -eq 0)) {
				$bitmap.SetPixel($x, $y, (Get-Tone 'ice' $pixel.A))
			} elseif ($frame -ne 1 -and (($x * 5 + $y + $frame) % 5 -eq 0)) {
				$bitmap.SetPixel($x, $y, (Get-Tone 'coral' $pixel.A))
			}
		}
	}
}

function New-DeathFrame([int]$frame) {
	$result = New-Frame 0 ([Math]::Min(7, $frame * 2)) (1.0 - $frame * 0.07) 0 0 -1 0
	$cutoff = 63 - $frame * 7
	for ($y = 0; $y -lt $frameSize; $y++) {
		for ($x = 0; $x -lt $frameSize; $x++) {
			$pixel = $result.GetPixel($x, $y)
			if ($pixel.A -eq 0) {
				continue
			}
			$dissolve = (($x * 13 + $y * 19 + $frame * 11) % 15) -lt ($frame * 2)
			if ($y -gt $cutoff -or $dissolve) {
				$result.SetPixel($x, $y, $script:palette.transparent)
			} elseif ($frame -ge 2) {
				$alpha = [Math]::Max(25, $pixel.A - $frame * 35)
				$result.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($alpha, $pixel.R, $pixel.G, $pixel.B))
			}
		}
	}
	$graphics = [System.Drawing.Graphics]::FromImage($result)
	$mintBrush = [System.Drawing.SolidBrush]::new((Get-Tone 'mint' (220 - $frame * 20)))
	$violetBrush = [System.Drawing.SolidBrush]::new((Get-Tone 'violet' (210 - $frame * 18)))
	try {
		Use-PixelDrawing $graphics
		$graphics.FillRectangle($mintBrush, [Math]::Min(61, 8 + $frame * 5), [Math]::Max(1, 19 - $frame), 2, 2)
		$graphics.FillRectangle($violetBrush, [Math]::Max(1, 54 - $frame * 4), [Math]::Min(61, 35 + $frame * 3), 2, 2)
	} finally {
		$violetBrush.Dispose()
		$mintBrush.Dispose()
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
	$stem = 'choir_widow_{0}_{1}x64' -f $name, $frames.Count
	$sheetPath = Join-Path $animationRoot ($stem + '.png')
	$framePaths = @()
	for ($index = 0; $index -lt $frames.Count; $index++) {
		$framePath = Join-Path $animationRoot ('{0}_{1}.png' -f $stem, $index)
		$frames[$index].Save($framePath, [System.Drawing.Imaging.ImageFormat]::Png)
		$framePaths += ('assets/sprites/pixel_64/bosses/choir_widow/animations/{0}_{1}.png' -f $stem, $index)
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
		id = 'choir_widow'
		animation = $name
		frames = $frames.Count
		fps = $fps
		loop = $loop
		sheet = 'assets/sprites/pixel_64/bosses/choir_widow/animations/{0}.png' -f $stem
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
		# Keep a one-pixel horizontal safety margin so the animated legs do not
		# clip when the model sways or recoils.
		$graphics.DrawImage($reference, [System.Drawing.Rectangle]::new(1, 0, 62, 64), 0, 0, $reference.Width, $reference.Height, [System.Drawing.GraphicsUnit]::Pixel)
	} finally {
		$graphics.Dispose()
	}
	$script:canonical.Save((Join-Path $outputRoot 'choir_widow_model_64.png'), [System.Drawing.Imaging.ImageFormat]::Png)

	$preview = New-TransparentBitmap 320 320
	$previewGraphics = [System.Drawing.Graphics]::FromImage($preview)
	try {
		Use-PixelDrawing $previewGraphics
		$previewGraphics.Clear($script:palette.transparent)
		$previewGraphics.DrawImage($script:canonical, [System.Drawing.Rectangle]::new(0, 0, 320, 320), 0, 0, $frameSize, $frameSize, [System.Drawing.GraphicsUnit]::Pixel)
		$preview.Save((Join-Path $outputRoot 'choir_widow_model_64_preview_5x.png'), [System.Drawing.Imaging.ImageFormat]::Png)
	} finally {
		$previewGraphics.Dispose()
		$preview.Dispose()
	}

	$entries = @()
	$idle = @()
	foreach ($index in 0..3) {
		$frame = New-Frame 0 @(-1, 0, 1, 0)[$index] 1.0 @(5, 8, 11, 8)[$index] @(32, 54, 82, 54)[$index] -1 @(32, 56, 84, 56)[$index]
		$idle += $frame
	}
	$entries += Write-Animation 'idle' $idle 6.0 $true

	$move = @()
	$moveOffsets = @(@(0, 1), @(1, 0), @(1, -1), @(0, -1), @(-1, 0), @(-1, 1))
	foreach ($index in 0..5) {
		$frame = New-Frame $moveOffsets[$index][0] $moveOffsets[$index][1] 0.98 5 38 $index @(40, 56, 72, 56, 40, 28)[$index]
		$move += $frame
	}
	$entries += Write-Animation 'move' $move 10.0 $true

	$attack = @()
	$attackSpecs = @(@(0, 0.97, 8, 42), @(0, 0.99, 12, 74), @(0, 1.0, 16, 126), @(0, 0.98, 10, 68))
	foreach ($index in 0..3) {
		$frame = New-Frame $attackSpecs[$index][0] 0 $attackSpecs[$index][1] $attackSpecs[$index][2] $attackSpecs[$index][3] -1 @(66, 112, 180, 94)[$index]
		Add-AttackBurst $frame $index
		$attack += $frame
	}
	$entries += Write-Animation 'attack' $attack 12.0 $false

	$hurt = @()
	foreach ($index in 0..2) {
		$frame = New-Frame @(-1, 1, 0)[$index] 0 0.98 0 0 -1 0
		Apply-HurtTint $frame $index
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
		source_concept = 'assets/concepts/bosses/choir_widow_reference_user_source_v1.png'
		runtime_kind = 'boss2'
		animations = $entries
	}
	[System.IO.File]::WriteAllText((Join-Path $outputRoot 'animation_manifest.json'), ($manifest | ConvertTo-Json -Depth 8), [System.Text.UTF8Encoding]::new($false))

	$readme = @(
		'# CHOIR WIDOW — boss 64x64',
		'',
		'Native 64x64 RGBA pixel frames for the LUMINOUS GROVE boss. The visual source is',
		'the player-supplied model at `assets/concepts/bosses/choir_widow_reference_user_source_v1.png`.',
		'The runtime loads the horizontal sheets below through `EnemySystem` for `boss2`.',
		'',
		'| Animation | Frames | FPS | Loop | Runtime state |',
		'| --- | ---: | ---: | :---: | --- |',
		'| `idle` | 4 | 6 | Yes | Telegraph / resting pulse |',
		'| `move` | 6 | 10 | Yes | Leg sway and route movement |',
		'| `attack` | 4 | 12 | No | Beat volley / summon cast |',
		'| `hurt` | 3 | 10 | No | Damage reaction |',
		'| `death` | 6 | 8 | No | Leaf-core collapse before reward UI |',
		'',
		'Each `*_Nx64.png` is the runtime spritesheet. The numbered files are its',
		'individual editable frames. Regenerate all assets with:',
		'',
		'```powershell',
		'.\tools\generate_choir_widow_64.ps1',
		'```'
	) -join [Environment]::NewLine
	[System.IO.File]::WriteAllText((Join-Path $outputRoot 'README_PIXELORAMA.md'), $readme.Trim() + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
} finally {
	if ($null -ne $script:canonical) { $script:canonical.Dispose() }
	$reference.Dispose()
}

Write-Host "Generated CHOIR WIDOW 64px model and 5 animation sheets in $outputRoot"
