<#
Generate the native 64x64 SUBWOOFER boss animation set.

The supplied high-resolution model is retained as a concept/reference only.
This script downscales it once with nearest-neighbour sampling, then builds all
runtime frames from that fixed 64px source. Every output has RGBA alpha and can
be opened as an ordinary frame or horizontal spritesheet in Pixelorama.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

$projectRoot = Split-Path -Parent $PSScriptRoot
$referencePath = Join-Path $projectRoot 'assets\concepts\bosses\subwoofer_reference_user_v2.png'
$outputRoot = Join-Path $projectRoot 'assets\sprites\pixel_64\bosses\subwoofer'
$animationRoot = Join-Path $outputRoot 'animations'
$frameSize = 64

if (-not (Test-Path -LiteralPath $referencePath)) {
	throw "Missing supplied SUBWOOFER reference: $referencePath"
}

$script:palette = @{
	ink = [System.Drawing.Color]::FromArgb(255, 9, 12, 22)
	graphite = [System.Drawing.Color]::FromArgb(255, 42, 42, 51)
	orange = [System.Drawing.Color]::FromArgb(255, 255, 126, 18)
	amber = [System.Drawing.Color]::FromArgb(255, 255, 190, 45)
	cyan = [System.Drawing.Color]::FromArgb(255, 40, 229, 255)
	ice = [System.Drawing.Color]::FromArgb(255, 220, 250, 255)
	white = [System.Drawing.Color]::FromArgb(255, 255, 255, 255)
	coral = [System.Drawing.Color]::FromArgb(255, 255, 105, 80)
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

function Add-PulseBehind([System.Drawing.Bitmap]$bitmap, [int]$radius, [string]$tone, [int]$alpha) {
	if ($radius -le 0) {
		return
	}
	$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
	$brush = [System.Drawing.SolidBrush]::new((Get-Tone $tone $alpha))
	$pen = [System.Drawing.Pen]::new((Get-Tone $tone ([Math]::Min(255, $alpha + 60))), 1.0)
	try {
		Use-PixelDrawing $graphics
		$bounds = [System.Drawing.Rectangle]::new(32 - $radius, 31 - $radius, $radius * 2, $radius * 2)
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
	$cyanPen = [System.Drawing.Pen]::new((Get-Tone 'cyan' 145), 1.0)
	$orangePen = [System.Drawing.Pen]::new((Get-Tone 'orange' 145), 1.0)
	try {
		Use-PixelDrawing $graphics
		$offset = $frame % 3
		$graphics.DrawLine($cyanPen, 8, 55 + $offset, 24, 55 + $offset)
		$graphics.DrawLine($orangePen, 40, 57 - $offset, 57, 57 - $offset)
		$graphics.DrawLine($cyanPen, 12, 60 - $offset, 29, 60 - $offset)
		$graphics.DrawLine($orangePen, 36, 61, 52, 61)
	} finally {
		$orangePen.Dispose()
		$cyanPen.Dispose()
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

function Add-CoreSpark([System.Drawing.Bitmap]$bitmap, [int]$frame, [string]$tone = 'ice') {
	$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
	$brush = [System.Drawing.SolidBrush]::new((Get-Tone $tone 220))
	try {
		Use-PixelDrawing $graphics
		$shift = $frame % 2
		$graphics.FillRectangle($brush, 31, 27 + $shift, 2, 5)
		$graphics.FillRectangle($brush, 29, 29 + $shift, 6, 1)
	} finally {
		$brush.Dispose()
		$graphics.Dispose()
	}
}

function New-Frame([int]$dx = 0, [int]$dy = 0, [double]$scale = 1.0, [int]$pulseRadius = 0, [string]$pulseTone = 'orange', [int]$pulseAlpha = 0, [int]$trailStep = -1) {
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
	Add-PulseBehind $frame $pulseRadius $pulseTone $pulseAlpha
	Draw-Canonical $frame $dx $dy $scale
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
				$bitmap.SetPixel($x, $y, (Get-Tone 'white' $pixel.A))
			} elseif ($frame -ne 1 -and (($x * 3 + $y + $frame) % 5 -eq 0)) {
				$bitmap.SetPixel($x, $y, (Get-Tone 'coral' $pixel.A))
			}
		}
	}
}

function New-DeathFrame([int]$frame) {
	$result = New-Frame 0 ([Math]::Min(3, $frame)) (1.0 - $frame * 0.055) 0 'orange' 0 -1
	$cutoff = 63 - $frame * 8
	for ($y = 0; $y -lt $frameSize; $y++) {
		for ($x = 0; $x -lt $frameSize; $x++) {
			$pixel = $result.GetPixel($x, $y)
			if ($pixel.A -eq 0) {
				continue
			}
			$dissolve = (($x * 17 + $y * 11 + $frame * 13) % 13) -lt ($frame * 2)
			if ($y -gt $cutoff -or $dissolve) {
				$result.SetPixel($x, $y, $script:palette.transparent)
			} elseif ($frame -ge 3) {
				$result.SetPixel($x, $y, [System.Drawing.Color]::FromArgb([Math]::Max(45, $pixel.A - $frame * 35), $pixel.R, $pixel.G, $pixel.B))
			}
		}
	}
	$graphics = [System.Drawing.Graphics]::FromImage($result)
	$brush = [System.Drawing.SolidBrush]::new((Get-Tone ($(if ($frame % 2 -eq 0) { 'orange' } else { 'cyan' }) ) 220))
	try {
		Use-PixelDrawing $graphics
		$graphics.FillRectangle($brush, [Math]::Min(61, 7 + $frame * 4), [Math]::Max(1, 23 - $frame * 2), 2, 2)
		$graphics.FillRectangle($brush, [Math]::Max(1, 55 - $frame * 4), [Math]::Min(61, 35 + $frame * 2), 2, 2)
	} finally {
		$brush.Dispose()
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
	$stem = 'subwoofer_{0}_{1}x64' -f $name, $frames.Count
	$sheetPath = Join-Path $animationRoot ($stem + '.png')
	$framePaths = @()
	for ($index = 0; $index -lt $frames.Count; $index++) {
		$framePath = Join-Path $animationRoot ('{0}_{1}.png' -f $stem, $index)
		$frames[$index].Save($framePath, [System.Drawing.Imaging.ImageFormat]::Png)
		$framePaths += ('assets/sprites/pixel_64/bosses/subwoofer/animations/{0}_{1}.png' -f $stem, $index)
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
		id = 'subwoofer'
		animation = $name
		frames = $frames.Count
		fps = $fps
		loop = $loop
		sheet = 'assets/sprites/pixel_64/bosses/subwoofer/animations/{0}.png' -f $stem
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
		$graphics.DrawImage($reference, [System.Drawing.Rectangle]::new(0, 0, $frameSize, $frameSize), 0, 0, $reference.Width, $reference.Height, [System.Drawing.GraphicsUnit]::Pixel)
	} finally {
		$graphics.Dispose()
	}
	$script:canonical.Save((Join-Path $outputRoot 'subwoofer_model_64.png'), [System.Drawing.Imaging.ImageFormat]::Png)

	$preview = New-TransparentBitmap 320 320
	$previewGraphics = [System.Drawing.Graphics]::FromImage($preview)
	try {
		Use-PixelDrawing $previewGraphics
		$previewGraphics.Clear($script:palette.transparent)
		$previewGraphics.DrawImage($script:canonical, [System.Drawing.Rectangle]::new(0, 0, 320, 320), 0, 0, $frameSize, $frameSize, [System.Drawing.GraphicsUnit]::Pixel)
		$preview.Save((Join-Path $outputRoot 'subwoofer_model_64_preview_5x.png'), [System.Drawing.Imaging.ImageFormat]::Png)
	} finally {
		$previewGraphics.Dispose()
		$preview.Dispose()
	}

	$entries = @()
	$idle = @()
	foreach ($index in 0..3) {
		$frame = New-Frame 0 @(-1, 0, 1, 0)[$index] 1.0 @(7, 9, 11, 9)[$index] 'orange' @(35, 55, 85, 55)[$index]
		Add-CoreSpark $frame $index 'amber'
		$idle += $frame
	}
	$entries += Write-Animation 'idle' $idle 6.0 $true

	$move = @()
	$moveOffsets = @(@(0, 1), @(1, 0), @(1, -1), @(0, -1), @(-1, 0), @(-1, 1))
	foreach ($index in 0..5) {
		$frame = New-Frame $moveOffsets[$index][0] $moveOffsets[$index][1] 1.0 6 'cyan' 35 $index
		if ($index % 2 -eq 0) { Add-CoreSpark $frame $index 'orange' }
		$move += $frame
	}
	$entries += Write-Animation 'move' $move 10.0 $true

	$attack = @()
	$attackSpecs = @(@(0, 1.0, 12, 50), @(0, 1.04, 16, 90), @(0, 1.08, 22, 145), @(0, 1.02, 15, 85))
	foreach ($index in 0..3) {
		$frame = New-Frame 0 0 $attackSpecs[$index][1] $attackSpecs[$index][2] 'orange' $attackSpecs[$index][3]
		Add-CoreSpark $frame $index ($(if ($index -eq 2) { 'white' } else { 'amber' }))
		$attack += $frame
	}
	$entries += Write-Animation 'attack' $attack 12.0 $false

	$hurt = @()
	foreach ($index in 0..2) {
		$frame = New-Frame @(-1, 1, 0)[$index] 0 1.0 0 'orange' 0
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
		source_concept = 'assets/concepts/bosses/subwoofer_reference_user_v2.png'
		runtime_kind = 'boss1'
		animations = $entries
	}
	[System.IO.File]::WriteAllText((Join-Path $outputRoot 'animation_manifest.json'), ($manifest | ConvertTo-Json -Depth 8), [System.Text.UTF8Encoding]::new($false))

	$readme = @(
		'# SUBWOOFER — boss 64×64',
		'',
		'Native 64×64 RGBA pixel frames for the BASS FOUNDRY boss. The visual source is',
		'the player-supplied Subwoofer model at `assets/concepts/bosses/subwoofer_reference_user_v2.png`.',
		'The runtime loads the horizontal sheets below through `EnemySystem` for `boss1`.',
		'',
		'| Animation | Frames | FPS | Loop | Runtime state |',
		'| --- | ---: | ---: | :---: | --- |',
		'| `idle` | 4 | 6 | Yes | Waiting and boss preview |',
		'| `move` | 6 | 10 | Yes | Boss path movement |',
		'| `attack` | 4 | 12 | No | Beat attack / charge |',
		'| `hurt` | 3 | 10 | No | Damage reaction |',
		'| `death` | 6 | 8 | No | Defeat before reward UI |',
		'',
		'Each `*_Nx64.png` is the runtime spritesheet. The numbered files are its',
		'individual editable frames. Regenerate all assets with:',
		'',
		'```powershell',
		'.\tools\generate_subwoofer_64.ps1',
		'```'
	) -join [Environment]::NewLine
	[System.IO.File]::WriteAllText((Join-Path $outputRoot 'README_PIXELORAMA.md'), $readme.Trim() + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
} finally {
	if ($null -ne $script:canonical) { $script:canonical.Dispose() }
	$reference.Dispose()
}

Write-Host "Generated SUBWOOFER 64px model and 5 animation sheets in $outputRoot"
