Add-Type -AssemblyName System.Drawing
$repairCode = @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;

public static class MapRepairComposer {
    static double Smooth(double t) {
        t = Math.Max(0, Math.Min(1, t));
        return t * t * (3 - 2 * t);
    }
    static double Box(int x, int y, int l, int t, int r, int b, int feather) {
        if (x <= l || x >= r || y <= t || y >= b) return 0;
        double d = Math.Min(Math.Min(x-l, r-x), Math.Min(y-t, b-y));
        return Smooth(d / feather);
    }
    static double Mask(int x, int y) {
        double a = Box(x,y,30,65,285,354,18);
        double b = Box(x,y,136,746,326,988,24);
        double c = Box(x,y,239,932,536,1228,27);
        return Math.Max(a, Math.Max(b,c));
    }
    static byte[] Read(Bitmap bmp) {
        BitmapData d = bmp.LockBits(new Rectangle(0,0,bmp.Width,bmp.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        byte[] bytes = new byte[bmp.Width*bmp.Height*4];
        for(int y=0;y<bmp.Height;y++) Marshal.Copy(IntPtr.Add(d.Scan0,y*d.Stride), bytes,y*bmp.Width*4,bmp.Width*4);
        bmp.UnlockBits(d);
        return bytes;
    }
    public static string Run(string source, string generated, string folder) {
        const int ox=4032, oy=400, pw=768, ph=1408;
        using(Bitmap original = new Bitmap(source))
        using(Bitmap generatedBitmap = new Bitmap(generated))
        using(Bitmap patch = new Bitmap(pw,ph,PixelFormat.Format32bppArgb)) {
            using(Graphics g = Graphics.FromImage(patch)) {
                g.CompositingMode = CompositingMode.SourceCopy;
                g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                using(ImageAttributes ia = new ImageAttributes()) {
                    ia.SetWrapMode(WrapMode.TileFlipXY);
                    g.DrawImage(generatedBitmap,new Rectangle(0,0,pw,ph),0,0,generatedBitmap.Width,generatedBitmap.Height,GraphicsUnit.Pixel,ia);
                }
            }
            byte[] before=Read(original), after=(byte[])before.Clone(), painted=Read(patch);
            for(int y=0;y<ph;y++) for(int x=0;x<pw;x++) {
                double a=Mask(x,y);
                if(a<=0) continue;
                int p=(y*pw+x)*4, q=((oy+y)*original.Width+ox+x)*4;
                for(int c=0;c<3;c++) after[q+c]=(byte)Math.Round(before[q+c]*(1-a)+painted[p+c]*a);
            }
            string finalPath=System.IO.Path.Combine(folder,"luminous_grove_route_background_repaired_hd_v29.png");
            using(Bitmap final = new Bitmap(original.Width,original.Height,PixelFormat.Format32bppArgb)) {
                BitmapData d=final.LockBits(new Rectangle(0,0,final.Width,final.Height),ImageLockMode.WriteOnly,PixelFormat.Format32bppArgb);
                for(int y=0;y<final.Height;y++) Marshal.Copy(after,y*final.Width*4,IntPtr.Add(d.Scan0,y*d.Stride),final.Width*4);
                final.UnlockBits(d);
                final.Save(finalPath,ImageFormat.Png);
                using(Bitmap crop=final.Clone(new Rectangle(3840,288,1248,1664),PixelFormat.Format32bppArgb)) crop.Save(System.IO.Path.Combine(folder,"boss-room-repaired-detail.png"),ImageFormat.Png);
            }
            int changed=0, outside=0, alpha=0;
            using(Bitmap saved=new Bitmap(finalPath)) {
                byte[] savedBytes=Read(saved);
                for(int y=0;y<original.Height;y++) for(int x=0;x<original.Width;x++) {
                    int q=(y*original.Width+x)*4;
                    if(before[q+3]!=savedBytes[q+3]) alpha++;
                    bool diff=false;
                    for(int c=0;c<4;c++) if(before[q+c]!=savedBytes[q+c]) diff=true;
                    if(diff) {
                        changed++;
                        if(Mask(x-ox,y-oy)<=0) outside++;
                    }
                }
            }
            return "{\"width\":"+original.Width+",\"height\":"+original.Height+",\"changed_pixels\":"+changed+",\"total_pixels\":"+(original.Width*original.Height)+",\"changed_outside_repair_masks\":"+outside+",\"alpha_changes\":"+alpha+",\"generated_patch_width\":"+generatedBitmap.Width+",\"generated_patch_height\":"+generatedBitmap.Height+",\"native_patch_width\":"+pw+",\"native_patch_height\":"+ph+",\"format\":\"PNG\"}";
        }
    }
}
'@
Add-Type -TypeDefinition $repairCode -ReferencedAssemblies System.Drawing
$repairFolder = $PSScriptRoot
$repairSource = 'C:\Users\Anoth\Downloads\luminous_grove_route_background_user_six_boss_junction_repaired_hd_v28.png'
$repairGenerated = Join-Path $repairFolder 'generated-repair-strip.png'
$repairResult = [MapRepairComposer]::Run($repairSource,$repairGenerated,$repairFolder)
$repairResult | Set-Content -LiteralPath (Join-Path $repairFolder 'verification.json') -Encoding utf8
$repairResult
