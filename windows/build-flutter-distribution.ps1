param(
    [string]$FlutterExecutable = "D:\Tools\flutter\bin\flutter.bat"
)
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$App = Join-Path $Root 'flutter_ui'
$Release = Join-Path $App 'build\windows\x64\runner\Release'
$Destination = Join-Path $Root 'build\TelexMini-Windows-x64'
$Archive = Join-Path $Root 'build\TelexMini-Windows-x64.zip'
$TempEngine = Join-Path $Root 'build\TelexMini-Native-Checked.exe'
New-Item -ItemType Directory -Force -Path (Join-Path $Root 'build') | Out-Null

if (-not (Test-Path -LiteralPath $FlutterExecutable)) {
    $flutter = Get-Command flutter -ErrorAction SilentlyContinue
    if ($null -eq $flutter) { throw 'Flutter SDK not found. Set -FlutterExecutable.' }
    $FlutterExecutable = $flutter.Source
}

# The existing build script reruns the complete Telex/VNI regression suite.
& (Join-Path $Root 'build.ps1') -OutputPath $TempEngine
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $TempEngine)) {
    throw 'Native TelexMini engine did not pass its guarded build.'
}

Push-Location $App
try {
    & $FlutterExecutable pub get
    if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency resolution failed.' }
    & $FlutterExecutable analyze
    if ($LASTEXITCODE -ne 0) { throw 'Flutter analysis failed.' }
    & $FlutterExecutable test --reporter expanded
    if ($LASTEXITCODE -ne 0) { throw 'Flutter widget tests failed.' }
    & $FlutterExecutable build windows --release
    if ($LASTEXITCODE -ne 0) { throw 'Flutter Windows release build failed.' }
} finally {
    Pop-Location
}

foreach ($relative in @('TelexMiniSettings.exe','flutter_windows.dll','data\flutter_assets')) {
    if (-not (Test-Path -LiteralPath (Join-Path $Release $relative))) {
        throw "Missing Flutter release component: $relative"
    }
}

# Assemble a standalone, portable two-process desktop bundle.
if (Test-Path -LiteralPath $Destination) { Remove-Item $Destination -Recurse -Force }
New-Item -ItemType Directory -Force -Path $Destination | Out-Null
Copy-Item -Path (Join-Path $Release '*') -Destination $Destination -Recurse -Force
Copy-Item -LiteralPath $TempEngine -Destination (Join-Path $Destination 'TelexMini.exe') -Force
$instructions = @'
TelexMini desktop for Windows (Flutter UI + native input engine)
----------------------------------------------------------------
Launch TelexMini.exe. The native engine stays in the system tray and
opens the shared Flutter Settings UI automatically.
The V/E status is always shown by the tray icon.
The Flutter executable is TelexMiniSettings.exe, which may also be
opened directly. Both applications must stay in the same folder.

Settings and user dictionaries are stored outside the package under
%LOCALAPPDATA%\TelexMini. No typed text history is saved.
'@
Set-Content -LiteralPath (Join-Path $Destination 'START-HERE.txt') -Value $instructions -Encoding UTF8
if (Test-Path -LiteralPath $Archive) { Remove-Item $Archive -Force }
Compress-Archive -Path (Join-Path $Destination '*') -DestinationPath $Archive -CompressionLevel Optimal

$check = @('TelexMini.exe','TelexMiniSettings.exe','flutter_windows.dll','data\flutter_assets')
foreach ($relative in $check) {
    if (-not (Test-Path -LiteralPath (Join-Path $Destination $relative))) { throw "Package verification failed: $relative" }
}
$size = (Get-ChildItem $Destination -File -Recurse | Measure-Object -Property Length -Sum).Sum
$zipInfo = Get-Item -LiteralPath $Archive
Write-Output ('NATIVE=' + (Join-Path $Destination 'TelexMini.exe'))
Write-Output ('FLUTTER=' + (Join-Path $Destination 'TelexMiniSettings.exe'))
Write-Output ('PACKAGE=' + $Archive)
Write-Output ('UNCOMPRESSED_MB=' + [math]::Round($size / 1MB,2))
Write-Output ('ARCHIVE_MB=' + [math]::Round($zipInfo.Length / 1MB,2))
Write-Output ('ARCHIVE_LAST_WRITTEN=' + $zipInfo.LastWriteTime)
