param([switch]$SkipBuild)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $SkipBuild) {
    & (Join-Path $root 'build.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Build failed; no preview package.' }
}
$exe = Join-Path $root 'TelexMini.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw 'Missing TelexMini.exe' }
$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$temp = Join-Path $env:TEMP ('TelexMini-Preview-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
try {
    Copy-Item -LiteralPath $exe -Destination (Join-Path $temp 'TelexMini.exe')
    Copy-Item -LiteralPath (Join-Path $root 'HUONG-DAN.md') -Destination (Join-Path $temp 'HUONG-DAN.md')
    $readme = "TelexMini Windows preview only. Unsigned build. Verify SHA-256 before use. Portable Mode: enable from Advanced Settings and restart."
    [System.IO.File]::WriteAllText((Join-Path $temp 'README.txt'),$readme,[System.Text.Encoding]::UTF8)
    $zip = Join-Path $dist 'TelexMini-Windows-preview.zip'
    if (Test-Path $zip) {Remove-Item $zip -Force}
    Compress-Archive -Path (Join-Path $temp '*') -DestinationPath $zip -CompressionLevel Optimal
    $digest = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
    [System.IO.File]::WriteAllText($zip+'.sha256',"$digest  TelexMini-Windows-preview.zip"+[Environment]::NewLine)
    Write-Host 'PREVIEW ONLY: unsigned, no automatic updater installation.'
    Write-Host "Archive: $zip"
    Write-Host "SHA256: $digest"
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
