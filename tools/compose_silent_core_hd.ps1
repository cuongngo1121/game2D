param(
    [string]$GeometryPath = (Join-Path $PSScriptRoot "..\assets\backgrounds\silent_core_route_background_concept_v1.png"),
    [string]$MaterialPath = (Join-Path $PSScriptRoot "..\assets\backgrounds\silent_core_route_background_concept_v1_material_detail_v1.png"),
    [string]$OutputPath = (Join-Path $PSScriptRoot "..\assets\backgrounds\silent_core_route_background_concept_v1_refined_safe_junctions_hd_v1.png")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# SILENT CORE is deliberately composed from one continuous material pass, rather
# than six opaque room rectangles.  The source plate supplies every void, wall,
# doorway and corner; the ImageGen result contributes material detail only where
# the source already contains map pixels.  Collision remains in 1448 x 1086
# native art space and does not depend on this HD output.
Add-Type -AssemblyName System.Drawing
if ($null -eq ("SilentCoreHdComposer" -as [type])) {
    # PowerShell 7 exposes System.Drawing through forwarded assemblies. Reuse
    # the reference-resolution pattern from the existing LV3 composer so this
    # script stays portable across the project's configured Windows runtime.
    $drawingCommonAssembly = [System.Drawing.Bitmap].Assembly.Location
    $drawingPrimitivesAssembly = [System.Drawing.Rectangle].Assembly.Location
    $windowsDrawingAssemblies = @([AppDomain]::CurrentDomain.GetAssemblies() |
        Where-Object { $_.GetName().Name -like "System.Private.Windows.*" } |
        ForEach-Object { $_.Location } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($windowsDrawingAssemblies.Count -lt 2) {
        throw "The Windows drawing runtime is required to compose the Silent Core texture."
    }
    Add-Type -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class SilentCoreHdComposer
{
    private const int NativeWidth = 1448;
    private const int NativeHeight = 1086;
    private const int AtlasWidth = 5120;
    private const int AtlasHeight = 3840;

    public static void Compose(string geometryPath, string materialPath, string outputPath)
    {
        using (Image geometrySource = Image.FromFile(geometryPath))
        using (Image materialSource = Image.FromFile(materialPath))
        {
            if (geometrySource.Width != NativeWidth || geometrySource.Height != NativeHeight)
                throw new InvalidOperationException("Geometry source must remain in native 1448 x 1086 art space.");
            if (materialSource.Width != NativeWidth || materialSource.Height != NativeHeight)
                throw new InvalidOperationException("Material pass must stay aligned to native 1448 x 1086 art space.");

            using (Bitmap geometry = Scale(geometrySource))
            using (Bitmap material = Scale(materialSource))
            using (Bitmap output = new Bitmap(AtlasWidth, AtlasHeight, PixelFormat.Format32bppPArgb))
            {
                Rectangle bounds = new Rectangle(0, 0, AtlasWidth, AtlasHeight);
                BitmapData geometryData = null;
                BitmapData materialData = null;
                BitmapData outputData = null;
                try
                {
                    geometryData = geometry.LockBits(bounds, ImageLockMode.ReadOnly, PixelFormat.Format32bppPArgb);
                    materialData = material.LockBits(bounds, ImageLockMode.ReadOnly, PixelFormat.Format32bppPArgb);
                    outputData = output.LockBits(bounds, ImageLockMode.WriteOnly, PixelFormat.Format32bppPArgb);
                    int bytes = Math.Abs(geometryData.Stride) * AtlasHeight;
                    byte[] geometryPixels = new byte[bytes];
                    byte[] materialPixels = new byte[bytes];
                    byte[] outputPixels = new byte[bytes];
                    Marshal.Copy(geometryData.Scan0, geometryPixels, 0, bytes);
                    Marshal.Copy(materialData.Scan0, materialPixels, 0, bytes);

                    for (int y = 0; y < AtlasHeight; y++)
                    {
                        int row = y * geometryData.Stride;
                        for (int x = 0; x < AtlasWidth; x++)
                        {
                            int offset = row + x * 4;
                            // The near-black exterior is copied from the geometry plate
                            // without blending, so material enhancement cannot create a
                            // false floor, void rectangle, or silhouette shift.
                            if (IsVoid(geometryPixels, offset))
                            {
                                CopyPixel(geometryPixels, outputPixels, offset);
                                continue;
                            }

                            // The detail pass was generated from the same continuous
                            // source map.  A restrained mix adds its high-frequency metal
                            // treatment while retaining the source plate as the dominant
                            // topology reference throughout the full atlas.
                            const double detailAlpha = 0.78;
                            for (int channel = 0; channel < 3; channel++)
                            {
                                outputPixels[offset + channel] = (byte)Math.Round(
                                    geometryPixels[offset + channel] * (1.0 - detailAlpha)
                                    + materialPixels[offset + channel] * detailAlpha);
                            }
                            outputPixels[offset + 3] = geometryPixels[offset + 3];
                        }
                    }
                    Marshal.Copy(outputPixels, 0, outputData.Scan0, bytes);
                }
                finally
                {
                    if (outputData != null) output.UnlockBits(outputData);
                    if (materialData != null) material.UnlockBits(materialData);
                    if (geometryData != null) geometry.UnlockBits(geometryData);
                }
                output.Save(outputPath, ImageFormat.Png);
            }
        }
    }

    private static Bitmap Scale(Image source)
    {
        Bitmap target = new Bitmap(AtlasWidth, AtlasHeight, PixelFormat.Format32bppPArgb);
        using (Graphics graphics = Graphics.FromImage(target))
        {
            graphics.CompositingMode = CompositingMode.SourceCopy;
            graphics.CompositingQuality = CompositingQuality.HighQuality;
            graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
            graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;
            graphics.SmoothingMode = SmoothingMode.HighQuality;
            graphics.DrawImage(source, new Rectangle(0, 0, AtlasWidth, AtlasHeight));
        }
        return target;
    }

    private static bool IsVoid(byte[] pixels, int offset)
    {
        return pixels[offset] <= 18 && pixels[offset + 1] <= 18 && pixels[offset + 2] <= 18;
    }

    private static void CopyPixel(byte[] source, byte[] target, int offset)
    {
        target[offset] = source[offset];
        target[offset + 1] = source[offset + 1];
        target[offset + 2] = source[offset + 2];
        target[offset + 3] = source[offset + 3];
    }
}
'@ -ReferencedAssemblies (@($drawingCommonAssembly, $drawingPrimitivesAssembly) + $windowsDrawingAssemblies)
}

$geometryFullPath = (Resolve-Path -LiteralPath $GeometryPath).Path
$materialFullPath = (Resolve-Path -LiteralPath $MaterialPath).Path
$outputFullPath = [IO.Path]::GetFullPath($OutputPath)
if (Test-Path -LiteralPath $outputFullPath) {
    throw "Refusing to overwrite existing runtime asset: $outputFullPath"
}

[SilentCoreHdComposer]::Compose($geometryFullPath, $materialFullPath, $outputFullPath)

$output = [System.Drawing.Image]::FromFile($outputFullPath)
try {
    [PSCustomObject]@{
        Name = Split-Path -Leaf $outputFullPath
        Width = $output.Width
        Height = $output.Height
        Bytes = (Get-Item -LiteralPath $outputFullPath).Length
        GeometrySource = Split-Path -Leaf $geometryFullPath
        MaterialSource = Split-Path -Leaf $materialFullPath
        Method = "Single continuous source-aligned material blend; geometry plate retains void/topology"
    }
}
finally {
    $output.Dispose()
}
