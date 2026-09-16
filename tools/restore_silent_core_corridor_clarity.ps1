param(
    [string]$InputPath = (Join-Path $PSScriptRoot "..\assets\backgrounds\silent_core_route_background_concept_v1_refined_safe_junctions_hd_v1_before_corridor_clarity_v4.png"),
    [string]$OutputPath = (Join-Path $PSScriptRoot "..\assets\backgrounds\silent_core_route_background_concept_v1_refined_safe_junctions_hd_corridor_clarity_candidate.png")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# The HD atlas was deliberately built from the 1448 x 1086 route plate.  This
# restoration pass keeps every source pixel in place, then restores local
# contrast only inside existing, non-void map pixels.  It therefore improves
# blurred corridor/wall detail without changing route topology or collision.
Add-Type -AssemblyName System.Drawing
if ($null -eq ("SilentCoreCorridorClarityRestorer" -as [type])) {
    $drawingCommonAssembly = [System.Drawing.Bitmap].Assembly.Location
    $drawingPrimitivesAssembly = [System.Drawing.Rectangle].Assembly.Location
    $windowsDrawingAssemblies = @([AppDomain]::CurrentDomain.GetAssemblies() |
        Where-Object { $_.GetName().Name -like "System.Private.Windows.*" } |
        ForEach-Object { $_.Location } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($windowsDrawingAssemblies.Count -lt 2) {
        throw "The Windows drawing runtime is required to restore the Silent Core texture."
    }
    Add-Type -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class SilentCoreCorridorClarityRestorer
{
    private const int AtlasWidth = 5120;
    private const int AtlasHeight = 3840;
    private const int Radius = 4;
    private const int Threshold = 2;
    private const double Amount = 1.20;

    public static void Restore(string inputPath, string outputPath)
    {
        using (Bitmap input = new Bitmap(inputPath))
        {
            if (input.Width != AtlasWidth || input.Height != AtlasHeight)
                throw new InvalidOperationException("Silent Core clarity restoration requires the 5120 x 3840 HD atlas.");

            using (Bitmap output = new Bitmap(AtlasWidth, AtlasHeight, PixelFormat.Format32bppArgb))
            {
                Rectangle bounds = new Rectangle(0, 0, AtlasWidth, AtlasHeight);
                BitmapData inputData = null;
                BitmapData outputData = null;
                try
                {
                    inputData = input.LockBits(bounds, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
                    outputData = output.LockBits(bounds, ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
                    int byteCount = Math.Abs(inputData.Stride) * AtlasHeight;
                    byte[] source = new byte[byteCount];
                    byte[] result = new byte[byteCount];
                    Marshal.Copy(inputData.Scan0, source, 0, byteCount);

                    int pixelCount = AtlasWidth * AtlasHeight;
                    int[] luma = new int[pixelCount];
                    int[] horizontalBlur = new int[pixelCount];
                    for (int y = 0; y < AtlasHeight; y++)
                    {
                        int byteRow = y * inputData.Stride;
                        int pixelRow = y * AtlasWidth;
                        for (int x = 0; x < AtlasWidth; x++)
                        {
                            int offset = byteRow + x * 4;
                            // BGR byte order; the integer weights retain enough precision
                            // for a gentle unsharp mask without color-shifting the pink glow.
                            luma[pixelRow + x] = (54 * source[offset + 2] + 183 * source[offset + 1] + 19 * source[offset]) >> 8;
                        }
                    }

                    int window = Radius * 2 + 1;
                    for (int y = 0; y < AtlasHeight; y++)
                    {
                        int row = y * AtlasWidth;
                        int sum = 0;
                        for (int sample = -Radius; sample <= Radius; sample++)
                            sum += luma[row + Clamp(sample, 0, AtlasWidth - 1)];
                        for (int x = 0; x < AtlasWidth; x++)
                        {
                            horizontalBlur[row + x] = sum / window;
                            sum += luma[row + Clamp(x + Radius + 1, 0, AtlasWidth - 1)];
                            sum -= luma[row + Clamp(x - Radius, 0, AtlasWidth - 1)];
                        }
                    }

                    for (int x = 0; x < AtlasWidth; x++)
                    {
                        int sum = 0;
                        for (int sample = -Radius; sample <= Radius; sample++)
                            sum += horizontalBlur[Clamp(sample, 0, AtlasHeight - 1) * AtlasWidth + x];
                        for (int y = 0; y < AtlasHeight; y++)
                        {
                            int pixelIndex = y * AtlasWidth + x;
                            int offset = y * inputData.Stride + x * 4;
                            int detail = luma[pixelIndex] - (sum / window);
                            Copy(source, result, offset);
                            if (!IsVoid(source, offset) && Math.Abs(detail) >= Threshold)
                            {
                                int adjustment = (int)Math.Round(detail * Amount);
                                result[offset] = ToByte(source[offset] + adjustment);
                                result[offset + 1] = ToByte(source[offset + 1] + adjustment);
                                result[offset + 2] = ToByte(source[offset + 2] + adjustment);
                            }
                            sum += horizontalBlur[Clamp(y + Radius + 1, 0, AtlasHeight - 1) * AtlasWidth + x];
                            sum -= horizontalBlur[Clamp(y - Radius, 0, AtlasHeight - 1) * AtlasWidth + x];
                        }
                    }

                    Marshal.Copy(result, 0, outputData.Scan0, byteCount);
                }
                finally
                {
                    if (outputData != null) output.UnlockBits(outputData);
                    if (inputData != null) input.UnlockBits(inputData);
                }
                output.Save(outputPath, ImageFormat.Png);
            }
        }
    }

    private static int Clamp(int value, int minimum, int maximum)
    {
        return value < minimum ? minimum : (value > maximum ? maximum : value);
    }

    private static bool IsVoid(byte[] pixels, int offset)
    {
        return pixels[offset] <= 18 && pixels[offset + 1] <= 18 && pixels[offset + 2] <= 18;
    }

    private static void Copy(byte[] source, byte[] target, int offset)
    {
        target[offset] = source[offset];
        target[offset + 1] = source[offset + 1];
        target[offset + 2] = source[offset + 2];
        target[offset + 3] = source[offset + 3];
    }

    private static byte ToByte(int value)
    {
        return (byte)(value < 0 ? 0 : (value > 255 ? 255 : value));
    }
}
'@ -ReferencedAssemblies (@($drawingCommonAssembly, $drawingPrimitivesAssembly) + $windowsDrawingAssemblies)
}

$inputFullPath = (Resolve-Path -LiteralPath $InputPath).Path
$outputFullPath = [IO.Path]::GetFullPath($OutputPath)
if (Test-Path -LiteralPath $outputFullPath) {
    throw "Refusing to overwrite an existing clarity-restoration output: $outputFullPath"
}

[SilentCoreCorridorClarityRestorer]::Restore($inputFullPath, $outputFullPath)

$output = [System.Drawing.Image]::FromFile($outputFullPath)
try {
    [PSCustomObject]@{
        Name = Split-Path -Leaf $outputFullPath
        Width = $output.Width
        Height = $output.Height
        Bytes = (Get-Item -LiteralPath $outputFullPath).Length
        Input = Split-Path -Leaf $inputFullPath
        Method = "Source-preserving non-void 9 x 9 unsharp-mask restoration"
    }
}
finally {
    $output.Dispose()
}
