<#
Generate the native 64x64 NULL MAESTRO boss animation set for Zone 5 (SILENT CORE).

The canonical source is the original transparent concept generated for the
final encounter. Frames retain its central cyan eye, radial conductor arms,
tuning-fork blades and violet note shards while adding readable motion at the
actual 64px runtime scale.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

$projectRoot = Split-Path -Parent $PSScriptRoot
$referencePath = Join-Path $projectRoot 'assets\concepts\bosses\null_maestro_reference_generated_v1.png'
$outputRoot = Join-Path $projectRoot 'assets\sprites\pixel_64\bosses\null_maestro'
$animationRoot = Join-Path $outputRoot 'animations'
$frameSize = 64

if (-not (Test-Path -LiteralPath $referencePath)) {
	throw "Missing NULL MAESTRO reference: $referencePath"
}

$script:palette = @{
	cyan = [System.Drawing.Color]::FromArgb(255, 48, 231, 255)
	violet = [System.Drawing.Color]::FromArgb(255, 141, 92, 255)
	purple = [System.Drawing.Color]::FromArgb(255, 101, 45, 210)
	ice = [System.Drawing.Color]::FromArgb(255, 240, 253, 255)
	pink = [System.Drawing.Color]::FromArgb(255, 255, 104, 214)
	ink = [System.Drawing.Color]::FromArgb(255, 12, 14, 31)
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

function Add-ResonanceRingBehind([System.Drawing.Bitmap]$bitmap, [int]$radius, [int]$alpha) {
	if ($radius -le 0 -or $alpha -le 0) {
		return
	}
	$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
	$brush = [System.Drawing.SolidBrush]::new((Get-Tone 'purple' ([Math]::Floor($alpha / 3))))
	$cyanPen = [System.Drawing.Pen]::new((Get-Tone 'cyan' $alpha), 1.0)
	$violetPen = [System.Drawing.Pen]::new((Get-Tone 'violet' ([Math]::Min(255, $alpha + 45))), 1.0)
	try {
		Use-PixelDrawing $graphics
		$bounds = [System.Drawing.Rectangle]::new(32 - $radius, 31 - $radius, $radius * 2, $radius * 2)
		$graphics.FillEllipse($brush, $bounds)
		$graphics.DrawArc($cyanPen, $bounds, 205, 128)
		$graphics.DrawArc($violetPen, $bounds, 20, 135)
	} finally {
		$violetPen.Dispose()
		$cyanPen.Dispose()
		$brush.Dispose()
		$graphics.Dispose()
	}
}

function Add-BeatTrails([System.Drawing.Bitmap]$bitmap, [int]$frame) {
	$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
	$cyanPen = [System.Drawing.Pen]::new((Get-Tone 'cyan' 140), 1.0)
	$violetPen = [System.Drawing.Pen]::new((Get-Tone 'violet' 130), 1.0)
	try {
		Use-PixelDrawing $graphics
		$offset = $frame % 3
		$graphics.DrawLine($violetPen, 3, 18 + $offset, 15, 18 + $offset)
		$graphics.DrawLine($cyanPen, 49, 20 - $offset, 61, 20 - $offset)
		$graphics.DrawLine($cyanPen, 4, 50 - $offset, 17, 50 - $offset)
		$graphics.DrawLine($violetPen, 48, 53 + $offset, 61, 53 + $offset)
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
		$drawSize = [int][Math]::Round(61.0 * $scale)
		$originX = [int][Math]::Round(($frameSize - $drawSize) / 2.0) + $dx
		$originY = [int][Math]::Round(($frameSize - $drawSize) / 2.0) + $dy
		$graphics.DrawImage($script:canonical, [System.Drawing.Rectangle]::new($originX, $originY, $drawSize, $drawSize), 0, 0, $frameSize, $frameSize, [System.Drawing.GraphicsUnit]::Pixel)
	} finally {
		$graphics.Dispose()
	}
}

function Add-EyePulse([System.Drawing.Bitmap]$bitmap, [int]$energy, [string]$tone = 'ice') {
	$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
	$brush = [System.Drawing.SolidBrush]::new((Get-Tone $tone ([Math]::Min(255, 115 + $energy))))
	try {
		Use-PixelDrawing $graphics
		$graphics.FillRectangle($brush, 31, 25, 2, 12)
		$graphics.FillRectangle($brush, 29, 29, 6, 4)
		$graphics.FillRectangle($brush, 30, 27, 4, 8)
	} finally {
		$brush.Dispose()
		$graphics.Dispose()
	}
}

function Add-NoteSparkles([System.Drawing.Bitmap]$bitmap, [int]$frame, [int]$alpha) {
	$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
	$violetBrush = [System.Drawing.SolidBrush]::new((Get-Tone 'violet' $alpha))
	$cyanBrush = [System.Drawing.SolidBrush]::new((Get-Tone 'cyan' ([Math]::Min(255, $alpha + 45))))
	try {
		Use-PixelDrawing $graphics
		$positions = @(@(18, 16), @(45, 15), @(12, 40), @(52, 39), @(25, 8), @(39, 8))
		for ($offset = 0; $offset -lt 3; $offset++) {
			$p = $positions[($frame + $offset * 2) % $positions.Count]
			$graphics.FillRectangle($(if ($offset % 2 -eq 0) { $violetBrush } else { $cyanBrush }), $p[0], $p[1], 2, 2)
			if ($offset -eq 0) {
				$graphics.FillRectangle($cyanBrush, $p[0] - 1, $p[1] + 1, 4, 1)
			}
		}
	} finally {
		$cyanBrush.Dispose()
		$violetBrush.Dispose()
		$graphics.Dispose()
	}
}

function Add-ConductingBurst([System.Drawing.Bitmap]$bitmap, [int]$frame) {
	$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
	$radius = @(6, 12, 19, 10)[$frame]
	$alpha = @(80, 140, 220, 105)[$frame]
	$cyanPen = [System.Drawing.Pen]::new((Get-Tone 'cyan' $alpha), 1.0)
	$violetPen = [System.Drawing.Pen]::new((Get-Tone 'violet' ([Math]::Min(255, $alpha + 25))), 1.0)
	try {
		Use-PixelDrawing $graphics
		$bounds = [System.Drawing.Rectangle]::new(32 - $radius, 31 - $radius, $radius * 2, $radius * 2)
		$graphics.DrawEllipse($cyanPen, $bounds)
		$graphics.DrawLine($violetPen, [Math]::Max(1, 32 - $radius - 3), 31, [Math]::Min(62, 32 + $radius + 3), 31)
		$graphics.DrawLine($cyanPen, 32, [Math]::Max(1, 31 - $radius - 3), 32, [Math]::Min(62, 31 + $radius + 4))
		if ($frame -ge 1) {
			$graphics.DrawLine($violetPen, 12, 12, 52, 50)
			$graphics.DrawLine($violetPen, 52, 12, 12, 50)
		}
		if ($frame -eq 2) {
			$graphics.DrawLine($cyanPen, 3, 31, 61, 31)
			$graphics.DrawLine($cyanPen, 32, 2, 32, 62)
		}
	} finally {
		$violetPen.Dispose()
		$cyanPen.Dispose()
		$graphics.Dispose()
	}
}

function New-Frame([int]$dx = 0, [int]$dy = 0, [double]$scale = 1.0, [int]$ringRadius = 0, [int]$ringAlpha = 0, [int]$trailStep = -1, [int]$eyeEnergy = 0, [int]$sparkleFrame = -1) {
	$frame = New-TransparentBitmap $frameSize $frameSize
	$graphics = [System.Drawing.Graphics]::FromImage($frame)
	try {
		$graphics.Clear($script:palette.transparent)
	} finally {
		$graphics.Dispose()
	}
	if ($trailStep -ge 0) {
		Add-BeatTrails $frame $trailStep
	}
	Add-ResonanceRingBehind $frame $ringRadius $ringAlpha
	Draw-Canonical $frame $dx $dy $scale
	if ($sparkleFrame -ge 0) {
		Add-NoteSparkles $frame $sparkleFrame 170
	}
	if ($eyeEnergy -gt 0) {
		Add-EyePulse $frame $eyeEnergy
	}
	return $frame
}

function Apply-HurtGlitch([System.Drawing.Bitmap]$bitmap, [int]$frame) {
	for ($y = 0; $y -lt $frameSize; $y++) {
		for ($x = 0; $x -lt $frameSize; $x++) {
			$pixel = $bitmap.GetPixel($x, $y)
			if ($pixel.A -eq 0) {
				continue
			}
			if ($frame -eq 1 -and (($x + $y) % 2 -eq 0)) {
				$bitmap.SetPixel($x, $y, (Get-Tone 'ice' $pixel.A))
			} elseif ($frame -ne 1 -and (($x * 5 + $y * 3 + $frame) % 6 -eq 0)) {
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
			$dissolve = (($x * 13 + $y * 19 + $frame * 11) % 15) -lt ($frame * 2)
			if ($y -gt $cutoff -or $dissolve) {
				$result.SetPixel($x, $y, $script:palette.transparent)
			} elseif ($frame -ge 2) {
				$alpha = [Math]::Max(20, $pixel.A - $frame * 36)
				$result.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($alpha, $pixel.R, $pixel.G, $pixel.B))
			}
		}
	}
	$graphics = [System.Drawing.Graphics]::FromImage($result)
	$cyanBrush = [System.Drawing.SolidBrush]::new((Get-Tone 'cyan' ([Math]::Max(35, 225 - $frame * 27))))
	$violetBrush = [System.Drawing.SolidBrush]::new((Get-Tone 'violet' ([Math]::Max(35, 210 - $frame * 24))))
	try {
		Use-PixelDrawing $graphics
		$graphics.FillRectangle($cyanBrush, [Math]::Min(61, 7 + $frame * 5), [Math]::Max(1, 19 - $frame), 2, 2)
		$graphics.FillRectangle($violetBrush, [Math]::Max(1, 55 - $frame * 4), [Math]::Min(61, 35 + $frame * 3), 2, 2)
		$graphics.FillRectangle($cyanBrush, [Math]::Min(61, 24 + $frame * 3), [Math]::Min(61, 50 + $frame), 2, 2)
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
	$stem = 'null_maestro_{0}_{1}x64' -f $name, $frames.Count
	$sheetPath = Join-Path $animationRoot ($stem + '.png')
	$framePaths = @()
	for ($index = 0; $index -lt $frames.Count; $index++) {
		$framePath = Join-Path $animationRoot ('{0}_{1}.png' -f $stem, $index)
		$frames[$index].Save($framePath, [System.Drawing.Imaging.ImageFormat]::Png)
		$framePaths += ('assets/sprites/pixel_64/bosses/null_maestro/animations/{0}_{1}.png' -f $stem, $index)
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
		id = 'null_maestro'
		animation = $name
		frames = $frames.Count
		fps = $fps
		loop = $loop
		sheet = 'assets/sprites/pixel_64/bosses/null_maestro/animations/{0}.png' -f $stem
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
		# One-pixel safety margin prevents tuning forks from clipping on movement.
		$graphics.DrawImage($reference, [System.Drawing.Rectangle]::new(1, 1, 62, 62), 0, 0, $reference.Width, $reference.Height, [System.Drawing.GraphicsUnit]::Pixel)
	} finally {
		$graphics.Dispose()
	}
	$script:canonical.Save((Join-Path $outputRoot 'null_maestro_model_64.png'), [System.Drawing.Imaging.ImageFormat]::Png)

	$preview = New-TransparentBitmap 320 320
	$previewGraphics = [System.Drawing.Graphics]::FromImage($preview)
	try {
		Use-PixelDrawing $previewGraphics
		$previewGraphics.Clear($script:palette.transparent)
		$previewGraphics.DrawImage($script:canonical, [System.Drawing.Rectangle]::new(0, 0, 320, 320), 0, 0, $frameSize, $frameSize, [System.Drawing.GraphicsUnit]::Pixel)
		$preview.Save((Join-Path $outputRoot 'null_maestro_model_64_preview_5x.png'), [System.Drawing.Imaging.ImageFormat]::Png)
	} finally {
		$previewGraphics.Dispose()
		$preview.Dispose()
	}

	$entries = @()
	$idle = @()
	foreach ($index in 0..3) {
		$frame = New-Frame 0 @(-1, 0, 1, 0)[$index] 1.0 @(5, 8, 11, 8)[$index] @(30, 58, 94, 58)[$index] -1 @(28, 62, 100, 62)[$index] $index
		$idle += $frame
	}
	$entries += Write-Animation 'idle' $idle 6.0 $true

	$move = @()
	$moveOffsets = @(@(0, 1), @(1, 0), @(1, -1), @(0, -1), @(-1, 0), @(-1, 1))
	foreach ($index in 0..5) {
		$frame = New-Frame $moveOffsets[$index][0] $moveOffsets[$index][1] 0.98 5 40 $index @(40, 55, 75, 55, 40, 28)[$index] $index
		$move += $frame
	}
	$entries += Write-Animation 'move' $move 10.0 $true

	$attack = @()
	$attackSpecs = @(@(0.97, 8, 42), @(0.99, 12, 82), @(1.0, 18, 148), @(0.98, 10, 70))
	foreach ($index in 0..3) {
		$frame = New-Frame 0 0 $attackSpecs[$index][0] $attackSpecs[$index][1] $attackSpecs[$index][2] -1 @(70, 126, 200, 108)[$index] $index
		Add-ConductingBurst $frame $index
		$attack += $frame
	}
	$entries += Write-Animation 'attack' $attack 12.0 $false

	$hurt = @()
	foreach ($index in 0..2) {
		$frame = New-Frame @(-1, 1, 0)[$index] 0 0.98 0 0 -1 0 -1
		Apply-HurtGlitch $frame $index
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
		source_concept = 'assets/concepts/bosses/null_maestro_reference_generated_v1.png'
		runtime_kind = 'boss4'
		animations = $entries
	}
	[System.IO.File]::WriteAllText((Join-Path $outputRoot 'animation_manifest.json'), ($manifest | ConvertTo-Json -Depth 8), [System.Text.UTF8Encoding]::new($false))

	$readme = @(
		'# NULL MAESTRO - boss 64x64',
		'',
		'Native 64x64 RGBA pixel frames for the SILENT CORE final boss. The canonical',
		'concept is `assets/concepts/bosses/null_maestro_reference_generated_v1.png`.',
		'The runtime loads the horizontal sheets below for `boss4`.',
		'',
		'| Animation | Frames | FPS | Loop | Runtime state |',
		'| --- | ---: | ---: | :---: | --- |',
		'| `idle` | 4 | 6 | Yes | Silent core pulse and note-shard orbit |',
		'| `move` | 6 | 10 | Yes | Conducting glide and beat trails |',
		'| `attack` | 4 | 12 | No | Ring/laser command burst |',
		'| `hurt` | 3 | 10 | No | Chromatic glitch when damaged |',
		'| `death` | 6 | 8 | No | Quiet disintegration before victory UI |',
		'',
		'Each `*_Nx64.png` is the runtime spritesheet. Numbered PNG files are',
		'individual editable frames. Regenerate the complete package with:',
		'',
		'```powershell',
		'.\tools\generate_null_maestro_64.ps1',
		'```'
	) -join [Environment]::NewLine
	[System.IO.File]::WriteAllText((Join-Path $outputRoot 'README_PIXELORAMA.md'), $readme.Trim() + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
} finally {
	if ($null -ne $script:canonical) { $script:canonical.Dispose() }
	$reference.Dispose()
}

Write-Host "Generated NULL MAESTRO 64px model and 5 animation sheets in $outputRoot"
