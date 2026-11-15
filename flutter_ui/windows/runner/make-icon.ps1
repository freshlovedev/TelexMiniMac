param(
    [Parameter(Mandatory=$true)][string]$SourcePath,
    [Parameter(Mandatory=$true)][string]$OutputPath
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$source = [System.Drawing.Bitmap]::new($SourcePath)
try {
    $left=$source.Width; $top=$source.Height; $right=0; $bottom=0
    for($y=0;$y -lt $source.Height;$y+=2) {
        for($x=0;$x -lt $source.Width;$x+=2) {
            $c=$source.GetPixel($x,$y)
            if(($c.R -lt 238) -or ($c.G -lt 238) -or ($c.B -lt 238)) {
                if($x -lt $left){$left=$x}; if($x -gt $right){$right=$x}
                if($y -lt $top){$top=$y}; if($y -gt $bottom){$bottom=$y}
            }
        }
    }
    if($right -le $left -or $bottom -le $top){throw 'Could not locate the icon artwork.'}
    $crop=[System.Drawing.Bitmap]::new($right-$left+1,$bottom-$top+1,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    for($y=0;$y -lt $crop.Height;$y++) {
        for($x=0;$x -lt $crop.Width;$x++) {
            $c=$source.GetPixel($left+$x,$top+$y)
            # Remove only the white canvas outside the rounded-square mark; keep the white T.
            $nx=($x+0.5)/$crop.Width; $ny=($y+0.5)/$crop.Height
            $r=0.19; $cx=if($nx -lt $r){$r-$nx}elseif($nx -gt 1-$r){$nx-(1-$r)}else{0}
            $cy=if($ny -lt $r){$r-$ny}elseif($ny -gt 1-$r){$ny-(1-$r)}else{0}
            if(($cx*$cx+$cy*$cy) -gt ($r*$r) -and $c.R -gt 238 -and $c.G -gt 238 -and $c.B -gt 238) {
                $crop.SetPixel($x,$y,[System.Drawing.Color]::FromArgb(0,0,0,0))
            } else { $crop.SetPixel($x,$y,$c) }
        }
    }
    $bitmap=[System.Drawing.Bitmap]::new(256,256,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g=[System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $g.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.Clear([System.Drawing.Color]::Transparent)
        $g.DrawImage($crop,[System.Drawing.Rectangle]::new(0,0,256,256))
        $memory=[System.IO.MemoryStream]::new()
        try {
            $bitmap.Save($memory,[System.Drawing.Imaging.ImageFormat]::Png)
            $png=$memory.ToArray()
            $stream=[System.IO.File]::Open($OutputPath,[System.IO.FileMode]::Create,[System.IO.FileAccess]::Write)
            $writer=[System.IO.BinaryWriter]::new($stream)
            try {
                $writer.Write([UInt16]0);$writer.Write([UInt16]1);$writer.Write([UInt16]1)
                $writer.Write([Byte]0);$writer.Write([Byte]0);$writer.Write([Byte]0);$writer.Write([Byte]0)
                $writer.Write([UInt16]1);$writer.Write([UInt16]32)
                $writer.Write([UInt32]$png.Length);$writer.Write([UInt32]22);$writer.Write($png)
            } finally {$writer.Dispose();$stream.Dispose()}
        } finally {$memory.Dispose()}
    } finally {$g.Dispose();$bitmap.Dispose();$crop.Dispose()}
} finally {$source.Dispose()}
Write-Host "Created transparent TelexMini icon: $OutputPath"
