param(
    [string]$FlutterExecutable = "D:\Tools\flutter\bin\flutter.bat",
    [ValidatePattern('^[a-zA-Z0-9._-]+$')][string]$ReleaseFolderName = 'TelexMini-Windows-x64'
)
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
# The Windows standalone workspace keeps Flutter beside the native sources;
# a cloned cross-platform repository keeps Flutter at the repository root.
$FlutterRoot = if (Test-Path (Join-Path $Root 'flutter_ui')) { $Root } else { Split-Path $Root -Parent }
$App = Join-Path $FlutterRoot 'flutter_ui'
$Release = Join-Path $App 'build\windows\x64\runner\Release'
$Destination = Join-Path (Join-Path $Root 'build') $ReleaseFolderName
$Archive = Join-Path (Join-Path $Root 'build') ($ReleaseFolderName+'.zip')
$TempEngine = Join-Path $Root 'build\TelexMini-Native-Checked.exe'
New-Item -ItemType Directory -Force -Path (Join-Path $Root 'build') | Out-Null

# Generate the same geometric bilingual-switch brand icon used in the Flutter UI.
$NewIcon = Join-Path $Root 'Resources\TelexMini-New-Icon.png'
if (Test-Path -LiteralPath $NewIcon) {
    Copy-Item -LiteralPath $NewIcon -Destination (Join-Path $FlutterRoot 'Resources\TelexMini-Icon-Teal.png') -Force
    New-Item -ItemType Directory -Force -Path (Join-Path $App 'assets') | Out-Null
    Copy-Item -LiteralPath $NewIcon -Destination (Join-Path $App 'assets\telexmini-icon.png') -Force
} else {
    & (Join-Path $Root 'render-brand-icon.ps1') -OutputPath (Join-Path $FlutterRoot 'Resources\TelexMini-Icon-Teal.png')
}
if (-not (Test-Path -LiteralPath (Join-Path $Root 'Resources\TelexMini-Icon-Teal.png'))) { throw 'Brand artwork generation failed.' }
& (Join-Path $Root 'make-icon.ps1') -SourcePath (Join-Path $Root 'Resources\TelexMini-Icon-Teal.png') -OutputPath (Join-Path $FlutterRoot 'flutter_ui\windows\runner\resources\app_icon.ico')
if (-not (Test-Path -LiteralPath (Join-Path $Root 'flutter_ui\windows\runner\resources\app_icon.ico'))) { throw 'Flutter executable icon generation failed.' }

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

# Release hardening: deterministic, offline, key-safe stress and latency statistics.
$benchReport = Join-Path $Root 'build\perf-benchmark-latest.txt'
& (Join-Path $Root 'test.ps1') -Benchmark *>&1 | Out-File -LiteralPath $benchReport -Encoding utf8
if ($LASTEXITCODE -ne 0) { throw 'Native performance stress checks failed; installed files unchanged.' }

# Assemble a standalone, portable two-process desktop bundle.
# The tests/build run first. Only close our own active TelexMini installation
# once all release artifacts have been verified; otherwise Windows locks Flutter DLLs.
if (Test-Path -LiteralPath $Destination) {
    $previous = Join-Path $Root 'build\TelexMini-Windows-previous'
    New-Item -ItemType Directory -Force -Path $previous | Out-Null
    foreach ($name in @('TelexMini.exe', 'TelexMiniSettings.exe')) {
        $oldPath = Join-Path $Destination $name
        if (Test-Path -LiteralPath $oldPath) { Copy-Item $oldPath (Join-Path $previous $name) -Force }
    }
    Get-Process TelexMini,TelexMiniSettings -ErrorAction SilentlyContinue | Where-Object {
        $_.Path -and $_.Path.StartsWith($Destination, [StringComparison]::OrdinalIgnoreCase)
    } | Stop-Process -Force
    Start-Sleep -Milliseconds 1100
    Remove-Item $Destination -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $Destination | Out-Null
Copy-Item -Path (Join-Path $Release '*') -Destination $Destination -Recurse -Force
Copy-Item -LiteralPath $TempEngine -Destination (Join-Path $Destination 'TelexMini.exe') -Force
Copy-Item -LiteralPath (Join-Path $Root 'native_engine\build\Release\TelexMiniEngine.dll') -Destination (Join-Path $Destination 'TelexMiniEngine.dll') -Force
Copy-Item -LiteralPath (Join-Path $Root 'native_engine\build\english_seed.txt') -Destination (Join-Path $Destination 'english_seed.txt') -Force
$instructions = @'
TelexMini 2.3.1 - Windows Telex w/ư hotfix and bilingual typing update
----------------------------------------------------------------
Launch TelexMini.exe. The native engine stays in the system tray and
opens the shared Flutter Settings UI automatically.
The V/E status is always shown by the tray icon.
Close the Flutter Settings window (X button or close icon) to free
UI memory while the independent native engine continues in the tray.
Left-click the tray V/E icon to open Settings again.
Windows uses the native C++ Telex/VNI engine with a non-admin keyboard hook.
No system input-method registration or UAC is needed to run it.
The Flutter executable is TelexMiniSettings.exe, which may also be
opened directly. Both applications must stay in the same folder.

Settings and user dictionaries are stored outside the package under
%LOCALAPPDATA%\TelexMini. No typed text history is saved.
'@
Set-Content -LiteralPath (Join-Path $Destination 'START-HERE.txt') -Value $instructions -Encoding UTF8
if (Test-Path -LiteralPath $Archive) { Remove-Item $Archive -Force }
Compress-Archive -Path (Join-Path $Destination '*') -DestinationPath $Archive -CompressionLevel Optimal

$check = @('TelexMini.exe','TelexMiniEngine.dll','english_seed.txt','TelexMiniSettings.exe','flutter_windows.dll','data\flutter_assets')
foreach ($relative in $check) {
    if (-not (Test-Path -LiteralPath (Join-Path $Destination $relative))) { throw "Package verification failed: $relative" }
}
$size = (Get-ChildItem $Destination -File -Recurse | Measure-Object -Property Length -Sum).Sum
$zipInfo = Get-Item -LiteralPath $Archive

# Verify the actual portable ZIP, not just the loose build directory.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$package = [System.IO.Compression.ZipFile]::OpenRead($Archive)
try {
    $entries = @($package.Entries | ForEach-Object { $_.FullName.Replace('\','/') })
    foreach($required in @(
        'TelexMini.exe',
        'TelexMiniEngine.dll',
        'english_seed.txt',
        'TelexMiniSettings.exe',
        'flutter_windows.dll',
        'data/flutter_assets/assets/telexmini-icon.png'
    )) {
        if($entries -notcontains $required) {
            throw "ZIP verification failed: $required"
        }
    }
} finally {
    $package.Dispose()
}
if((Get-FileHash (Join-Path $Destination 'TelexMini.exe') -Algorithm SHA256).Hash -ne
   (Get-FileHash $TempEngine -Algorithm SHA256).Hash) {
    throw 'Packaged native engine hash does not match the tested build.'
}
$audit = [ordered]@{
    product = 'TelexMini'
    version = '2.4.0-native-preview'
    platform = 'Windows x64'
    mode = 'portable release'
    built_utc = [DateTime]::UtcNow.ToString('o')
    native_regression = 'pass'
    native_composer = 'C++ TelexMiniEngine.dll; Windows hook transport retained'
    input_backend = 'Windows per-user keyboard hook; no administrator privileges'
    bilingual_corpus = 'pass'
    flutter_analyze = 'pass'
    flutter_widget_tests = 'pass'
    simulated_stress = 'pass'
    interactive_typing = 'verify separately in visible Windows test'
    packaged_files_verified = $true
    native_exe_sha256 = (Get-FileHash (Join-Path $Destination 'TelexMini.exe') -Algorithm SHA256).Hash
    composer_dll_sha256 = (Get-FileHash (Join-Path $Destination 'TelexMiniEngine.dll') -Algorithm SHA256).Hash
    flutter_exe_sha256 = (Get-FileHash (Join-Path $Destination 'TelexMiniSettings.exe') -Algorithm SHA256).Hash
    zip_sha256 = (Get-FileHash $Archive -Algorithm SHA256).Hash
    zip_size_bytes = $zipInfo.Length
    stores_typing_history = $false
}
$auditPath = Join-Path (Join-Path $Root 'build') ($ReleaseFolderName+'-audit.json')
$audit | ConvertTo-Json -Depth 3 | Set-Content -Path $auditPath -Encoding UTF8
Write-Output ('AUDIT=' + $auditPath)

Write-Output ('NATIVE=' + (Join-Path $Destination 'TelexMini.exe'))
Write-Output ('FLUTTER=' + (Join-Path $Destination 'TelexMiniSettings.exe'))
Write-Output ('PACKAGE=' + $Archive)
Write-Output ('UNCOMPRESSED_MB=' + [math]::Round($size / 1MB,2))
Write-Output ('ARCHIVE_MB=' + [math]::Round($zipInfo.Length / 1MB,2))
Write-Output ('ARCHIVE_LAST_WRITTEN=' + $zipInfo.LastWriteTime)
