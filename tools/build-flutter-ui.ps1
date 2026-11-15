$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$App = Join-Path $Root 'flutter_ui'
$Release = Join-Path $App 'build\windows\x64\runner\Release'
$Destination = Join-Path $Root 'build\FlutterUI'

Push-Location $App
try {
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }
    flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'flutter analyze failed.' }
    flutter test --reporter expanded
    if ($LASTEXITCODE -ne 0) { throw 'flutter test failed.' }
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw 'flutter build windows failed.' }
} finally {
    Pop-Location
}

$Exe = Join-Path $Release 'TelexMiniSettings.exe'
if (-not (Test-Path $Exe)) { throw "Flutter Windows executable not found: $Exe" }
if (Test-Path $Destination) { Remove-Item $Destination -Recurse -Force }
New-Item -ItemType Directory -Path $Destination -Force | Out-Null
Copy-Item (Join-Path $Release '*') $Destination -Recurse -Force
Write-Host "FLUTTER_WINDOWS_UI=$Destination"
Get-ChildItem $Destination -File | Measure-Object Length -Sum | ForEach-Object {
    Write-Host ("PACKAGED_FILE_BYTES=" + $_.Sum)
}
