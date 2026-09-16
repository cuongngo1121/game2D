param(
    [string]$GeometryPath = (Join-Path $PSScriptRoot "..\assets\backgrounds\luminous_grove_route_background_concept_v1_boundary_cleanup_source_v10.png"),
    [string]$SectionDirectory = (Join-Path $PSScriptRoot "..\assets\backgrounds\luminous_grove_sections_v10"),
    [string]$OutputPath = (Join-Path $PSScriptRoot "..\assets\backgrounds\luminous_grove_route_background_concept_v1_refined_boundary_cleanup_hd_v10.png"),
    [ValidateRange(0.0, 1.0)]
    [double]$MaximumMaterialAlpha = 0.42,
    [ValidateRange(0.0, 1.0)]
    [double]$MaximumWallAlpha = 0.94,
    [string]$CombatOnePath = "",
    [switch]$UseFloorPolygonMask,
    [switch]$DirectSectionStitch,
    [ValidateRange(1, 100)]
    [int]$SectionEdgeFeatherAtlasPixels = 100
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

# The source image is the geometry authority.  HD section images restore both
# floor and wall material only where their own non-void pixels agree with that
# layout.  Overlaps stay on the source geometry, and the authored floor polygon
# keeps a simple collision-facing inner margin for boundary editing.
if ($null -eq ("LuminousGroveV10Composer" -as [type])) {
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
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

public static class LuminousGroveV10Composer
{
    private const int VoidChannelThreshold = 18;
    private const int GeometryMarginAtlasPixels = 100;
    private const int FloorEdgeMarginAtlasPixels = 68;
    private const int FloorEdgeFeatherAtlasPixels = 56;
    private const int WallEdgeMarginAtlasPixels = 16;
    private const int WallEdgeFeatherAtlasPixels = 32;
    // This covers the full outer metal frame of every approved source room;
    // ownership still resolves against the nearest floor polygon, so adjacent
    // source rectangles cannot overwrite each other merely by overlapping.
    private const int DirectSectionWallReachAtlasPixels = 360;
    private const double MaximumMaterialAlpha = 0.42;
    // The section order is Combat 1, Combat 2, Combat 3, Support, Combat 4,
    // Boss.  These are the authored LV3 floor polygons in native 1448 x 1086
    // coordinates, not inferred image regions.  A baked detail layer can use
    // them to preserve every wall, door, void and boundary-editing margin.
    private static readonly double[][] NativeFloorPolygons = new double[][]
    {
        new double[] { 46,792, 264,800, 264,952, 46,952 },
        new double[] { 160,555, 580,555, 580,600, 650,600, 650,520, 700,520, 700,710, 255,710, 255,805, 192,808, 184,704, 160,700 },
        new double[] { 690,410, 885,410, 885,445, 1025,445, 1025,575, 900,575, 900,605, 700,605, 700,570, 650,570, 650,520, 690,520 },
        new double[] { 680,210, 830,210, 830,350, 795,350, 795,540, 690,540, 690,450, 740,450, 740,350, 680,350 },
        new double[] { 1040,370, 1220,370, 1220,560, 1050,560, 1050,520, 1000,520, 1000,445, 1040,445 },
        new double[] { 1200,125, 1405,125, 1405,330, 1250,330, 1250,395, 1195,395, 1195,300, 1160,300, 1160,210, 1200,210 }
    };

    private static Bitmap ToPArgb(Image source)
    {
        Bitmap result = new Bitmap(source.Width, source.Height, PixelFormat.Format32bppPArgb);
        using (Graphics graphics = Graphics.FromImage(result))
        {
            graphics.CompositingMode = CompositingMode.SourceCopy;
            graphics.CompositingQuality = CompositingQuality.HighQuality;
            graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
            graphics.SmoothingMode = SmoothingMode.HighQuality;
            graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;
            graphics.DrawImage(source, new Rectangle(0, 0, result.Width, result.Height));
        }
        return result;
    }

    private static Bitmap BuildGeometryPlate(Image source, int width, int height)
    {
        Bitmap plate = new Bitmap(width, height, PixelFormat.Format32bppPArgb);
        using (Graphics graphics = Graphics.FromImage(plate))
        {
            graphics.CompositingMode = CompositingMode.SourceCopy;
            graphics.CompositingQuality = CompositingQuality.HighQuality;
            graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
            graphics.SmoothingMode = SmoothingMode.HighQuality;
            graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;
            graphics.DrawImage(source, new Rectangle(0, 0, width, height));
        }
        return plate;
    }

    private static Bitmap ScaleSection(Image source, int width, int height)
    {
        Bitmap scaled = new Bitmap(width, height, PixelFormat.Format32bppPArgb);
        using (Graphics graphics = Graphics.FromImage(scaled))
        {
            graphics.CompositingMode = CompositingMode.SourceCopy;
            graphics.CompositingQuality = CompositingQuality.HighQuality;
            graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
            graphics.SmoothingMode = SmoothingMode.HighQuality;
            graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;
            graphics.DrawImage(source, new Rectangle(0, 0, width, height));
        }
        return scaled;
    }

    private static bool IsVoid(byte[] pixels, int offset)
    {
        return pixels[offset] < VoidChannelThreshold
            && pixels[offset + 1] < VoidChannelThreshold
            && pixels[offset + 2] < VoidChannelThreshold;
    }

    private static bool IsCyanGeometryHighlight(byte[] pixels, int offset)
    {
        int blue = pixels[offset];
        int green = pixels[offset + 1];
        int red = pixels[offset + 2];
        return (green > 105 && blue > 65 && green > red * 3 / 2)
            || blue + green + red > 440;
    }

    private static bool IsVoidAt(byte[] geometry, int stride, int width, int height, int x, int y)
    {
        return x < 0 || x >= width || y < 0 || y >= height
            || IsVoid(geometry, y * stride + x * 4);
    }

    private static bool IsNearVoid(byte[] geometry, int stride, int width, int height, int x, int y)
    {
        return IsVoidAt(geometry, stride, width, height, x - GeometryMarginAtlasPixels, y)
            || IsVoidAt(geometry, stride, width, height, x + GeometryMarginAtlasPixels, y)
            || IsVoidAt(geometry, stride, width, height, x, y - GeometryMarginAtlasPixels)
            || IsVoidAt(geometry, stride, width, height, x, y + GeometryMarginAtlasPixels)
            || IsVoidAt(geometry, stride, width, height, x - GeometryMarginAtlasPixels, y - GeometryMarginAtlasPixels)
            || IsVoidAt(geometry, stride, width, height, x - GeometryMarginAtlasPixels, y + GeometryMarginAtlasPixels)
            || IsVoidAt(geometry, stride, width, height, x + GeometryMarginAtlasPixels, y - GeometryMarginAtlasPixels)
            || IsVoidAt(geometry, stride, width, height, x + GeometryMarginAtlasPixels, y + GeometryMarginAtlasPixels);
    }

    private static double SmoothStep(double value)
    {
        double clamped = Math.Max(0.0, Math.Min(1.0, value));
        return clamped * clamped * (3.0 - 2.0 * clamped);
    }

    private static PointF[] BuildFloorPolygon(int sectionIndex, int width, int height)
    {
        double[] native = NativeFloorPolygons[sectionIndex];
        PointF[] result = new PointF[native.Length / 2];
        for (int point = 0; point < result.Length; point++)
        {
            result[point] = new PointF(
                (float)(native[point * 2] * width / 1448.0),
                (float)(native[point * 2 + 1] * height / 1086.0));
        }
        return result;
    }

    private static bool IsInsideFloor(PointF[] polygon, double x, double y)
    {
        bool inside = false;
        for (int current = 0, previous = polygon.Length - 1; current < polygon.Length; previous = current++)
        {
            PointF a = polygon[current];
            PointF b = polygon[previous];
            bool crossesY = (a.Y > y) != (b.Y > y);
            if (crossesY && x < (b.X - a.X) * (y - a.Y) / (b.Y - a.Y) + a.X)
            {
                inside = !inside;
            }
        }
        return inside;
    }

    private static double DistanceToSegment(PointF start, PointF end, double x, double y)
    {
        double dx = end.X - start.X;
        double dy = end.Y - start.Y;
        double lengthSquared = dx * dx + dy * dy;
        if (lengthSquared <= 0.0001)
        {
            dx = x - start.X;
            dy = y - start.Y;
            return Math.Sqrt(dx * dx + dy * dy);
        }
        double projection = ((x - start.X) * dx + (y - start.Y) * dy) / lengthSquared;
        projection = Math.Max(0.0, Math.Min(1.0, projection));
        double closestX = start.X + projection * dx;
        double closestY = start.Y + projection * dy;
        dx = x - closestX;
        dy = y - closestY;
        return Math.Sqrt(dx * dx + dy * dy);
    }

    private static double SafeFloorAlpha(PointF[] polygon, double x, double y)
    {
        if (!IsInsideFloor(polygon, x, y))
        {
            return 0.0;
        }
        double edgeDistance = Double.MaxValue;
        for (int point = 0; point < polygon.Length; point++)
        {
            edgeDistance = Math.Min(edgeDistance, DistanceToSegment(
                polygon[point], polygon[(point + 1) % polygon.Length], x, y));
        }
        return SmoothStep((edgeDistance - FloorEdgeMarginAtlasPixels) / FloorEdgeFeatherAtlasPixels);
    }

    private static double SafeWallAlpha(PointF[] polygon, double x, double y)
    {
        if (polygon == null || IsInsideFloor(polygon, x, y))
        {
            return 0.0;
        }
        double edgeDistance = Double.MaxValue;
        for (int point = 0; point < polygon.Length; point++)
        {
            edgeDistance = Math.Min(edgeDistance, DistanceToSegment(
                polygon[point], polygon[(point + 1) % polygon.Length], x, y));
        }
        return SmoothStep((edgeDistance - WallEdgeMarginAtlasPixels) / WallEdgeFeatherAtlasPixels);
    }

    private static double DistanceToFloorPolygon(PointF[] polygon, double x, double y)
    {
        if (IsInsideFloor(polygon, x, y))
        {
            return 0.0;
        }
        double edgeDistance = Double.MaxValue;
        for (int point = 0; point < polygon.Length; point++)
        {
            edgeDistance = Math.Min(edgeDistance, DistanceToSegment(
                polygon[point], polygon[(point + 1) % polygon.Length], x, y));
        }
        return edgeDistance;
    }

    private static bool IsDirectSectionOwner(int sectionIndex, PointF[][] floorPolygons, double x, double y)
    {
        double ownDistance = DistanceToFloorPolygon(floorPolygons[sectionIndex], x, y);
        if (ownDistance > DirectSectionWallReachAtlasPixels)
        {
            return false;
        }
        for (int candidateIndex = 0; candidateIndex < floorPolygons.Length; candidateIndex++)
        {
            if (candidateIndex == sectionIndex)
            {
                continue;
            }
            double candidateDistance = DistanceToFloorPolygon(floorPolygons[candidateIndex], x, y);
            if (candidateDistance < ownDistance - 0.01
                || (Math.Abs(candidateDistance - ownDistance) <= 0.01 && candidateIndex < sectionIndex))
            {
                return false;
            }
        }
        return true;
    }

    private static byte[] BuildSectionCoverage(Rectangle[] sections, int width, int height)
    {
        byte[] coverage = new byte[width * height];
        Rectangle atlas = new Rectangle(0, 0, width, height);
        foreach (Rectangle requested in sections)
        {
            Rectangle section = Rectangle.Intersect(atlas, requested);
            for (int y = section.Top; y < section.Bottom; y++)
            {
                int row = y * width;
                for (int x = section.Left; x < section.Right; x++)
                {
                    if (coverage[row + x] < byte.MaxValue)
                    {
                        coverage[row + x]++;
                    }
                }
            }
        }
        return coverage;
    }

    public static void Compose(string geometryPath, string sectionDirectory, string outputPath, string[] names, int[] rectangleValues, int atlasWidth, int atlasHeight, double maximumMaterialAlpha, double maximumWallAlpha, string combatOnePath, bool useFloorPolygonMask, bool directSectionStitch, int sectionEdgeFeatherAtlasPixels)
    {
        if (names.Length * 4 != rectangleValues.Length)
        {
            throw new ArgumentException("Each section needs X, Y, width, and height.");
        }
        Rectangle[] sections = new Rectangle[names.Length];
        for (int index = 0; index < names.Length; index++)
        {
            sections[index] = new Rectangle(
                rectangleValues[index * 4],
                rectangleValues[index * 4 + 1],
                rectangleValues[index * 4 + 2],
                rectangleValues[index * 4 + 3]);
        }
        PointF[][] allFloorPolygons = new PointF[sections.Length][];
        for (int index = 0; index < allFloorPolygons.Length; index++)
        {
            allFloorPolygons[index] = BuildFloorPolygon(index, atlasWidth, atlasHeight);
        }

        using (Image geometryFile = Image.FromFile(geometryPath))
        using (Bitmap geometry = BuildGeometryPlate(geometryFile, atlasWidth, atlasHeight))
        using (Bitmap output = ToPArgb(geometry))
        {
            Rectangle atlas = new Rectangle(0, 0, atlasWidth, atlasHeight);
            byte[] coverage = BuildSectionCoverage(sections, atlasWidth, atlasHeight);
            BitmapData geometryData = null;
            BitmapData outputData = null;
            try
            {
                geometryData = geometry.LockBits(atlas, ImageLockMode.ReadOnly, PixelFormat.Format32bppPArgb);
                outputData = output.LockBits(atlas, ImageLockMode.ReadWrite, PixelFormat.Format32bppPArgb);
                int geometryByteCount = Math.Abs(geometryData.Stride) * atlasHeight;
                int outputByteCount = Math.Abs(outputData.Stride) * atlasHeight;
                byte[] geometryPixels = new byte[geometryByteCount];
                byte[] outputPixels = new byte[outputByteCount];
                Marshal.Copy(geometryData.Scan0, geometryPixels, 0, geometryByteCount);
                Marshal.Copy(outputData.Scan0, outputPixels, 0, outputByteCount);

                for (int sectionIndex = 0; sectionIndex < sections.Length; sectionIndex++)
                {
                    Rectangle section = Rectangle.Intersect(atlas, sections[sectionIndex]);
                    PointF[] floorPolygon = (useFloorPolygonMask || directSectionStitch)
                        ? allFloorPolygons[sectionIndex]
                        : null;
                    string sectionPath = names[sectionIndex] == "combat_1" && !String.IsNullOrWhiteSpace(combatOnePath)
                        ? combatOnePath
                        : Path.Combine(sectionDirectory, names[sectionIndex] + "_refined_hd.png");
                    if (!File.Exists(sectionPath))
                    {
                        throw new FileNotFoundException("Missing HD material section.", sectionPath);
                    }
                    using (Image sectionFile = Image.FromFile(sectionPath))
                    using (Bitmap detail = ScaleSection(sectionFile, section.Width, section.Height))
                    {
                        BitmapData detailData = null;
                        try
                        {
                            detailData = detail.LockBits(new Rectangle(0, 0, detail.Width, detail.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppPArgb);
                             int detailByteCount = Math.Abs(detailData.Stride) * detail.Height;
                             byte[] detailPixels = new byte[detailByteCount];
                             Marshal.Copy(detailData.Scan0, detailPixels, 0, detailByteCount);

                             for (int y = 0; y < section.Height; y++)
                            {
                                int sourceY = section.Top + y;
                                int geometryRow = sourceY * geometryData.Stride;
                                int outputRow = sourceY * outputData.Stride;
                                int detailRow = y * detailData.Stride;
                                for (int x = 0; x < section.Width; x++)
                                {
                                    int sourceX = section.Left + x;
                                    int geometryOffset = geometryRow + sourceX * 4;
                                    int outputOffset = outputRow + sourceX * 4;
                                    int detailOffset = detailRow + x * 4;
                                    int coverageOffset = sourceY * atlasWidth + sourceX;
                                    // Overlaps restore the geometry plate completely, rather than choosing one rectangular crop.
                                    if ((!directSectionStitch && coverage[coverageOffset] > 1)
                                        || IsVoid(geometryPixels, geometryOffset)
                                        || (!directSectionStitch && IsVoid(detailPixels, detailOffset)))
                                    {
                                        continue;
                                    }
                                    if (directSectionStitch
                                        && !IsDirectSectionOwner(sectionIndex, allFloorPolygons, sourceX, sourceY))
                                    {
                                        continue;
                                    }
                                    // Direct stitch consumes the six approved source images as
                                    // the visible map plate.  It retains only void and overlap
                                    // safety; it does not leave a broad low-resolution geometry
                                    // blend across the rooms.
                                    double floorAlpha = directSectionStitch
                                        ? 0.0
                                        : (useFloorPolygonMask ? SafeFloorAlpha(floorPolygon, sourceX, sourceY) : 1.0);
                                    double wallAlpha = directSectionStitch
                                        ? 1.0
                                        : (useFloorPolygonMask ? SafeWallAlpha(floorPolygon, sourceX, sourceY) : 0.0);
                                    if (floorAlpha <= 0.0 && wallAlpha <= 0.0)
                                    {
                                        continue;
                                    }
                                    // The inner playable floor keeps its wide clean boundary
                                    // buffer.  Outside that polygon, the authored HD section
                                    // restores wall panels and cyan fixtures that otherwise
                                    // remain a 3.536x upscale of the small geometry plate.
                                    if (wallAlpha <= 0.0
                                        && (IsCyanGeometryHighlight(geometryPixels, geometryOffset)
                                            || IsNearVoid(geometryPixels, geometryData.Stride, atlasWidth, atlasHeight, sourceX, sourceY)))
                                    {
                                        continue;
                                    }
                                    int edgeDistance = Math.Min(
                                        Math.Min(x, section.Width - 1 - x),
                                        Math.Min(y, section.Height - 1 - y));
                                    double alpha = directSectionStitch
                                        ? 1.0
                                        : SmoothStep((edgeDistance + 1.0) / sectionEdgeFeatherAtlasPixels)
                                            * (maximumMaterialAlpha * floorAlpha + maximumWallAlpha * wallAlpha);
                                    for (int channel = 0; channel < 3; channel++)
                                    {
                                        outputPixels[outputOffset + channel] = (byte)Math.Round(
                                            geometryPixels[geometryOffset + channel] * (1.0 - alpha)
                                            + detailPixels[detailOffset + channel] * alpha);
                                    }
                                    outputPixels[outputOffset + 3] = geometryPixels[geometryOffset + 3];
                                }
                            }
                        }
                        finally
                        {
                            if (detailData != null) detail.UnlockBits(detailData);
                        }
                    }
                }
                Marshal.Copy(outputPixels, 0, outputData.Scan0, outputByteCount);
            }
            finally
            {
                if (outputData != null) output.UnlockBits(outputData);
                if (geometryData != null) geometry.UnlockBits(geometryData);
            }
            output.Save(outputPath, ImageFormat.Png);
        }
    }
}
'@ -ReferencedAssemblies (@($drawingCommonAssembly, $drawingPrimitivesAssembly) + $windowsDrawingAssemblies)
}

$geometryFullPath = (Resolve-Path -LiteralPath $GeometryPath).Path
$sectionDirectoryFullPath = (Resolve-Path -LiteralPath $SectionDirectory).Path
$outputFullPath = [IO.Path]::GetFullPath($OutputPath)
$combatOneFullPath = ""
if (-not [string]::IsNullOrWhiteSpace($CombatOnePath)) {
    $combatOneFullPath = (Resolve-Path -LiteralPath $CombatOnePath).Path
}
if (Test-Path -LiteralPath $outputFullPath) {
    throw "Refusing to overwrite existing runtime asset: $outputFullPath"
}

$geometry = [System.Drawing.Image]::FromFile($geometryFullPath)
try {
    if ($geometry.Width -ne 1448 -or $geometry.Height -ne 1086) {
        throw "Geometry source must stay in native LV3 art space (1448 x 1086)."
    }
}
finally {
    $geometry.Dispose()
}

$sectionDefinitions = @(
    @{ Name = "combat_1"; X = 0; Y = 700; W = 360; H = 386 },
    @{ Name = "combat_2"; X = 120; Y = 480; W = 620; H = 330 },
    @{ Name = "combat_3"; X = 630; Y = 350; W = 430; H = 330 },
    @{ Name = "support"; X = 620; Y = 160; W = 310; H = 330 },
    @{ Name = "combat_4"; X = 970; Y = 300; W = 330; H = 350 },
    @{ Name = "boss"; X = 1120; Y = 60; W = 328; H = 350 }
)
$atlasWidth = 5120
$atlasHeight = 3840
$rectangleValues = [System.Collections.Generic.List[int]]::new()
$names = [System.Collections.Generic.List[string]]::new()
foreach ($section in $sectionDefinitions) {
    $names.Add($section.Name)
    $rectangleValues.Add([Math]::Round($section.X * $atlasWidth / 1448.0))
    $rectangleValues.Add([Math]::Round($section.Y * $atlasHeight / 1086.0))
    $rectangleValues.Add([Math]::Round($section.W * $atlasWidth / 1448.0))
    $rectangleValues.Add([Math]::Round($section.H * $atlasHeight / 1086.0))
}

[LuminousGroveV10Composer]::Compose(
    $geometryFullPath,
    $sectionDirectoryFullPath,
    $outputFullPath,
    $names.ToArray(),
    $rectangleValues.ToArray(),
    $atlasWidth,
    $atlasHeight,
    $MaximumMaterialAlpha,
    $MaximumWallAlpha,
    $combatOneFullPath,
    $UseFloorPolygonMask.IsPresent,
    $DirectSectionStitch.IsPresent,
    $SectionEdgeFeatherAtlasPixels)

$output = [System.Drawing.Image]::FromFile($outputFullPath)
try {
    [PSCustomObject]@{
        Name = Split-Path -Leaf $outputFullPath
        Width = $output.Width
        Height = $output.Height
        Bytes = (Get-Item -LiteralPath $outputFullPath).Length
        GeometrySource = Split-Path -Leaf $geometryFullPath
        SectionCount = $names.Count
        MaximumMaterialAlpha = $MaximumMaterialAlpha
        MaximumWallAlpha = $MaximumWallAlpha
        CombatOneSource = if ([string]::IsNullOrWhiteSpace($combatOneFullPath)) { "combat_1_refined_hd.png" } else { Split-Path -Leaf $combatOneFullPath }
        FloorPolygonMask = $UseFloorPolygonMask.IsPresent
        DirectSectionStitch = $DirectSectionStitch.IsPresent
        DirectSectionOwnership = if ($DirectSectionStitch.IsPresent) { "Nearest floor polygon, lower index tie-break" } else { "n/a" }
        SectionEdgeFeatherAtlasPixels = $SectionEdgeFeatherAtlasPixels
        OverlapPolicy = if ($DirectSectionStitch.IsPresent) { "Later approved section source" } else { "Restore geometry plate" }
    }
}
finally {
    $output.Dispose()
}
