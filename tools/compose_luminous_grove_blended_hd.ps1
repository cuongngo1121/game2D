param(
    [string]$BasePath = (Join-Path $PSScriptRoot "..\assets\backgrounds\luminous_grove_route_background_concept_v1_seamless_hd_v3.png"),
    [string]$DetailPath = (Join-Path $PSScriptRoot "..\assets\backgrounds\luminous_grove_route_background_concept_v1_tiled_restored_hd_v2.png"),
    [string]$OutputPath = (Join-Path $PSScriptRoot "..\assets\backgrounds\luminous_grove_route_background_concept_v1_blended_section_hd_v4.png"),
    [string]$PreviewPath = "",
    [int[]]$PreviewCropAtlas = @(),
    [string]$OverridePath = "",
    [int[]]$OverrideAtlasRect = @(),
    [switch]$AllowOverrideVoid,
    [ValidateRange(1, 128)]
    [int]$OverrideFeatherArtPixels = 28,
    [switch]$PreviewOnly,
    [ValidateRange(1, 128)]
    [int]$FeatherArtPixels = 28
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

# The tiled plate has richer restored material inside each room, but its hard
# crop edges can visibly tear at a corridor junction. This composer keeps the
# continuous v3 plate at every section boundary and crossfades into the v2
# details over a soft native-art-pixel border. No geometry is moved.
if ($null -eq ("LuminousGroveSectionBlender" -as [type])) {
	$drawingCommonAssembly = [System.Drawing.Bitmap].Assembly.Location
	$drawingPrimitivesAssembly = [System.Drawing.Rectangle].Assembly.Location
	$windowsDrawingAssemblies = @([AppDomain]::CurrentDomain.GetAssemblies() |
		Where-Object { $_.GetName().Name -like "System.Private.Windows.*" } |
		ForEach-Object { $_.Location } |
		Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
	if ($windowsDrawingAssemblies.Count -lt 2) {
		throw "The Windows drawing runtime is required to compose the Luminous Grove texture."
	}
    Add-Type -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class LuminousGroveSectionBlender
{
    private static Bitmap ToPArgb(Image source)
    {
        Bitmap result = new Bitmap(source.Width, source.Height, PixelFormat.Format32bppPArgb);
        using (Graphics graphics = Graphics.FromImage(result))
        {
            graphics.DrawImage(source, new Rectangle(0, 0, result.Width, result.Height));
        }
        return result;
    }

    private static bool ShouldOverlayRefinedPixel(byte[] pixels, int offset)
    {
        // ImageGen sections are rectangular but the authored route is not.
        // Their surrounding opaque near-black void must not erase a floor or
        // wall from an overlapping neighbour underneath it.
        const byte voidThreshold = 14;
        return pixels[offset] > voidThreshold
            || pixels[offset + 1] > voidThreshold
            || pixels[offset + 2] > voidThreshold;
    }

    public static void Blend(string basePath, string detailPath, string outputPath, Rectangle[] sections, int featherPixels)
    {
        using (Image baseFile = Image.FromFile(basePath))
        using (Image detailFile = Image.FromFile(detailPath))
        {
            if (baseFile.Width != detailFile.Width || baseFile.Height != detailFile.Height)
            {
                throw new InvalidOperationException("The continuous and section-detail plates must share the same dimensions.");
            }

            using (Bitmap baseImage = ToPArgb(baseFile))
            using (Bitmap detailImage = ToPArgb(detailFile))
            using (Bitmap output = ToPArgb(baseFile))
            {
                Rectangle atlas = new Rectangle(0, 0, output.Width, output.Height);
                BitmapData baseData = null;
                BitmapData detailData = null;
                BitmapData outputData = null;
                try
                {
                    baseData = baseImage.LockBits(atlas, ImageLockMode.ReadOnly, PixelFormat.Format32bppPArgb);
                    detailData = detailImage.LockBits(atlas, ImageLockMode.ReadOnly, PixelFormat.Format32bppPArgb);
                    outputData = output.LockBits(atlas, ImageLockMode.ReadWrite, PixelFormat.Format32bppPArgb);

                    int byteCount = Math.Abs(baseData.Stride) * output.Height;
                    byte[] basePixels = new byte[byteCount];
                    byte[] detailPixels = new byte[byteCount];
                    byte[] outputPixels = new byte[byteCount];
                    Marshal.Copy(baseData.Scan0, basePixels, 0, byteCount);
                    Marshal.Copy(detailData.Scan0, detailPixels, 0, byteCount);
                    Buffer.BlockCopy(basePixels, 0, outputPixels, 0, byteCount);

                    foreach (Rectangle requested in sections)
                    {
                        Rectangle section = Rectangle.Intersect(atlas, requested);
                        for (int y = section.Top; y < section.Bottom; y++)
                        {
                            int row = y * outputData.Stride;
                            for (int x = section.Left; x < section.Right; x++)
                            {
                                int edgeDistance = Math.Min(
                                    Math.Min(x - section.Left, section.Right - 1 - x),
                                    Math.Min(y - section.Top, section.Bottom - 1 - y));
                                double normalized = Math.Max(0.0, Math.Min(1.0, (edgeDistance + 1.0) / featherPixels));
                                // Smoothstep prevents a visible brightness band at the end of the fade.
                                double alpha = normalized * normalized * (3.0 - 2.0 * normalized);
                                int offset = row + x * 4;
                                for (int channel = 0; channel < 4; channel++)
                                {
                                    outputPixels[offset + channel] = (byte)Math.Round(
                                        basePixels[offset + channel] * (1.0 - alpha) + detailPixels[offset + channel] * alpha);
                                }
                            }
                        }
                    }

                    Marshal.Copy(outputPixels, 0, outputData.Scan0, byteCount);
                }
                finally
                {
                    if (outputData != null) output.UnlockBits(outputData);
                    if (detailData != null) detailImage.UnlockBits(detailData);
                    if (baseData != null) baseImage.UnlockBits(baseData);
                }
                output.Save(outputPath, ImageFormat.Png);
            }
        }
    }

    public static void Overlay(string basePath, string overridePath, string outputPath, Rectangle target, int featherPixels, bool allowOverrideVoid)
    {
        using (Image baseFile = Image.FromFile(basePath))
        using (Image overrideFile = Image.FromFile(overridePath))
        using (Bitmap output = ToPArgb(baseFile))
        using (Bitmap overrideImage = new Bitmap(target.Width, target.Height, PixelFormat.Format32bppPArgb))
        {
            Rectangle atlas = new Rectangle(0, 0, output.Width, output.Height);
            if (!atlas.Contains(target))
            {
                throw new InvalidOperationException("The refined section must remain inside the destination atlas.");
            }
            using (Graphics graphics = Graphics.FromImage(overrideImage))
            {
                graphics.DrawImage(overrideFile, new Rectangle(0, 0, target.Width, target.Height));
            }

            BitmapData outputData = null;
            BitmapData overrideData = null;
            try
            {
                outputData = output.LockBits(atlas, ImageLockMode.ReadWrite, PixelFormat.Format32bppPArgb);
                overrideData = overrideImage.LockBits(new Rectangle(0, 0, target.Width, target.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppPArgb);
                int outputByteCount = Math.Abs(outputData.Stride) * output.Height;
                int overrideByteCount = Math.Abs(overrideData.Stride) * target.Height;
                byte[] outputPixels = new byte[outputByteCount];
                byte[] overridePixels = new byte[overrideByteCount];
                Marshal.Copy(outputData.Scan0, outputPixels, 0, outputByteCount);
                Marshal.Copy(overrideData.Scan0, overridePixels, 0, overrideByteCount);

                for (int y = 0; y < target.Height; y++)
                {
                    int outputRow = (target.Y + y) * outputData.Stride;
                    int overrideRow = y * overrideData.Stride;
                    for (int x = 0; x < target.Width; x++)
                    {
                        int edgeDistance = Math.Min(
                            Math.Min(x, target.Width - 1 - x),
                            Math.Min(y, target.Height - 1 - y));
                        double normalized = Math.Max(0.0, Math.Min(1.0, (edgeDistance + 1.0) / featherPixels));
                        double alpha = normalized * normalized * (3.0 - 2.0 * normalized);
                        int outputOffset = outputRow + (target.X + x) * 4;
                        int overrideOffset = overrideRow + x * 4;
                        if (!allowOverrideVoid && !ShouldOverlayRefinedPixel(overridePixels, overrideOffset))
                        {
                            continue;
                        }
                        for (int channel = 0; channel < 4; channel++)
                        {
                            outputPixels[outputOffset + channel] = (byte)Math.Round(
                                outputPixels[outputOffset + channel] * (1.0 - alpha) + overridePixels[overrideOffset + channel] * alpha);
                        }
                    }
                }

                Marshal.Copy(outputPixels, 0, outputData.Scan0, outputByteCount);
            }
            finally
            {
                if (overrideData != null) overrideImage.UnlockBits(overrideData);
                if (outputData != null) output.UnlockBits(outputData);
            }
            output.Save(outputPath, ImageFormat.Png);
        }
    }
}
'@ -ReferencedAssemblies (@($drawingCommonAssembly, $drawingPrimitivesAssembly) + $windowsDrawingAssemblies)
}

$sections = @(
    @{ Name = "combat_1"; X = 0; Y = 700; W = 360; H = 386 },
    @{ Name = "combat_2"; X = 120; Y = 480; W = 620; H = 330 },
    @{ Name = "combat_3"; X = 630; Y = 350; W = 430; H = 330 },
    @{ Name = "support"; X = 620; Y = 160; W = 310; H = 330 },
    @{ Name = "combat_4"; X = 970; Y = 300; W = 330; H = 350 },
    @{ Name = "boss"; X = 1120; Y = 60; W = 328; H = 350 }
)

$baseFullPath = (Resolve-Path -LiteralPath $BasePath).Path
$detailFullPath = (Resolve-Path -LiteralPath $DetailPath).Path
$outputFullPath = [IO.Path]::GetFullPath($OutputPath)
if (Test-Path -LiteralPath $outputFullPath) {
	if (-not $PreviewOnly) {
		throw "Refusing to overwrite existing asset: $outputFullPath"
	}
}
elseif ($PreviewOnly) {
	throw "Cannot create a preview because the blended texture does not exist: $outputFullPath"
}

$baseImage = [System.Drawing.Image]::FromFile($baseFullPath)
try {
    $nativeWidth = 1448.0
    $nativeHeight = 1086.0
    $atlasWidth = $baseImage.Width
    $atlasHeight = $baseImage.Height
    $featherPixels = [Math]::Round($FeatherArtPixels * [Math]::Min($atlasWidth / $nativeWidth, $atlasHeight / $nativeHeight))
	$overrideFullPath = ""
	$overrideRectangle = [System.Drawing.Rectangle]::Empty
	$overrideFeatherPixels = 0
	if (-not [string]::IsNullOrWhiteSpace($OverridePath)) {
		if ($OverrideAtlasRect.Count -ne 4) {
			throw "OverrideAtlasRect must contain exactly four values: X Y Width Height."
		}
		$overrideFullPath = (Resolve-Path -LiteralPath $OverridePath).Path
		$overrideRectangle = [System.Drawing.Rectangle]::new($OverrideAtlasRect[0], $OverrideAtlasRect[1], $OverrideAtlasRect[2], $OverrideAtlasRect[3])
		$atlasRectangle = [System.Drawing.Rectangle]::new(0, 0, $atlasWidth, $atlasHeight)
		if ([System.Drawing.Rectangle]::Intersect($atlasRectangle, $overrideRectangle) -ne $overrideRectangle) {
			throw "OverrideAtlasRect must remain inside the atlas."
		}
		$overrideFeatherPixels = [Math]::Round($OverrideFeatherArtPixels * [Math]::Min($atlasWidth / $nativeWidth, $atlasHeight / $nativeHeight))
	}
    $rectangles = [System.Drawing.Rectangle[]]::new($sections.Count)
    for ($index = 0; $index -lt $sections.Count; $index++) {
        $section = $sections[$index]
        $rectangles[$index] = [System.Drawing.Rectangle]::new(
            [Math]::Round($section.X * $atlasWidth / $nativeWidth),
            [Math]::Round($section.Y * $atlasHeight / $nativeHeight),
            [Math]::Round($section.W * $atlasWidth / $nativeWidth),
            [Math]::Round($section.H * $atlasHeight / $nativeHeight)
        )
    }
}
finally {
    $baseImage.Dispose()
}

if (-not $PreviewOnly) {
	if ([string]::IsNullOrWhiteSpace($overrideFullPath)) {
		[LuminousGroveSectionBlender]::Blend($baseFullPath, $detailFullPath, $outputFullPath, $rectangles, $featherPixels)
	}
	else {
		[LuminousGroveSectionBlender]::Overlay($baseFullPath, $overrideFullPath, $outputFullPath, $overrideRectangle, $overrideFeatherPixels, $AllowOverrideVoid.IsPresent)
	}
}

$output = [System.Drawing.Image]::FromFile($outputFullPath)
try {
	if (-not [string]::IsNullOrWhiteSpace($PreviewPath)) {
		$previewFullPath = [IO.Path]::GetFullPath($PreviewPath)
		$previewDirectory = Split-Path -Parent $previewFullPath
		[IO.Directory]::CreateDirectory($previewDirectory) | Out-Null
		$crop = [System.Drawing.Rectangle]::new(0, 0, $output.Width, $output.Height)
		if ($PreviewCropAtlas.Count -gt 0) {
			if ($PreviewCropAtlas.Count -ne 4) {
				throw "PreviewCropAtlas must contain exactly four values: X Y Width Height."
			}
			$requestedCrop = [System.Drawing.Rectangle]::new($PreviewCropAtlas[0], $PreviewCropAtlas[1], $PreviewCropAtlas[2], $PreviewCropAtlas[3])
			$crop = [System.Drawing.Rectangle]::Intersect($crop, $requestedCrop)
			if ($crop.Width -le 0 -or $crop.Height -le 0) {
				throw "PreviewCropAtlas does not overlap the blended atlas."
			}
		}
		$previewScale = [Math]::Min(1280.0 / $crop.Width, 960.0 / $crop.Height)
		$preview = [System.Drawing.Bitmap]::new([Math]::Max(1, [Math]::Round($crop.Width * $previewScale)), [Math]::Max(1, [Math]::Round($crop.Height * $previewScale)), [System.Drawing.Imaging.PixelFormat]::Format32bppPArgb)
		$graphics = [System.Drawing.Graphics]::FromImage($preview)
		try {
			$graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
			$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
			$graphics.DrawImage($output, [System.Drawing.Rectangle]::new(0, 0, $preview.Width, $preview.Height), $crop.X, $crop.Y, $crop.Width, $crop.Height, [System.Drawing.GraphicsUnit]::Pixel)
			$preview.Save($previewFullPath, [System.Drawing.Imaging.ImageFormat]::Png)
		}
		finally {
			$graphics.Dispose()
			$preview.Dispose()
		}
	}
    [PSCustomObject]@{
        Name = Split-Path -Leaf $outputFullPath
        Width = $output.Width
        Height = $output.Height
        Bytes = (Get-Item -LiteralPath $outputFullPath).Length
        FeatherArtPixels = $FeatherArtPixels
        FeatherAtlasPixels = $featherPixels
    }
}
finally {
    $output.Dispose()
}
