param([string]$OutputPath = '')
if (-not $OutputPath) {
  $base=if(Test-Path (Join-Path $PSScriptRoot 'Resources')){$PSScriptRoot}else{Split-Path $PSScriptRoot -Parent}
  $OutputPath=Join-Path $base 'Resources\TelexMini-Icon-Teal.png'
}
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$size=1024
$bitmap=[System.Drawing.Bitmap]::new($size,$size,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g=[System.Drawing.Graphics]::FromImage($bitmap)
try {
    $g.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.Clear([System.Drawing.Color]::Transparent)
    $rounded=[System.Drawing.Drawing2D.GraphicsPath]::new()
    try {
        $x=15;$y=15;$w=994;$h=994;$r=263;$diameter=$r*2
        $rounded.AddArc($x,$y,$diameter,$diameter,180,90)
        $rounded.AddArc($x+$w-$diameter,$y,$diameter,$diameter,270,90)
        $rounded.AddArc($x+$w-$diameter,$y+$h-$diameter,$diameter,$diameter,0,90)
        $rounded.AddArc($x,$y+$h-$diameter,$diameter,$diameter,90,90)
        $rounded.CloseFigure()
        $start=[System.Drawing.Color]::FromArgb(255,8,187,169)
        $end=[System.Drawing.Color]::FromArgb(255,22,117,181)
        $brush=[System.Drawing.Drawing2D.LinearGradientBrush]::new(
            [System.Drawing.Point]::new(0,0),[System.Drawing.Point]::new(1024,1024),$start,$end)
        try {$g.FillPath($brush,$rounded)} finally {$brush.Dispose()}
    } finally {$rounded.Dispose()}
    $pen=[System.Drawing.Pen]::new([System.Drawing.Color]::White,108)
    try {
        $pen.StartCap=[System.Drawing.Drawing2D.LineCap]::Round
        $pen.EndCap=[System.Drawing.Drawing2D.LineCap]::Round
        $pen.LineJoin=[System.Drawing.Drawing2D.LineJoin]::Round
        # Two arrow heads and opposed strokes; the mark is not a letter.
        $g.DrawLine($pen,246,358,737,358)
        $g.DrawLines($pen,[System.Drawing.Point[]]@(
            [System.Drawing.Point]::new(594,225),
            [System.Drawing.Point]::new(747,358),
            [System.Drawing.Point]::new(594,491)))
        $g.DrawLine($pen,778,666,287,666)
        $g.DrawLines($pen,[System.Drawing.Point[]]@(
            [System.Drawing.Point]::new(430,533),
            [System.Drawing.Point]::new(277,666),
            [System.Drawing.Point]::new(430,799)))
    } finally {$pen.Dispose()}
    $parent=Split-Path -Parent $OutputPath
    if(-not(Test-Path $parent)){New-Item -ItemType Directory -Force $parent|Out-Null}
    $bitmap.Save($OutputPath,[System.Drawing.Imaging.ImageFormat]::Png)
    Write-Output ('BRAND_ICON='+$OutputPath)
} finally {$g.Dispose();$bitmap.Dispose()}
