param([switch]$SkipOracle)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$build=Join-Path $PSScriptRoot 'build'
New-Item -Force -ItemType Directory $build | Out-Null
$source=[IO.File]::ReadAllText((Join-Path $root 'EnglishLexicon.cs'))
$m=[regex]::Match($source,'const string CoreWords = @"([^"]+)";',[Text.RegularExpressions.RegexOptions]::Singleline)
if(-not $m.Success) {throw 'Cannot extract core English words'}
$words=($m.Groups[1].Value -split '\s+' | Where-Object {$_ -match '^[a-z]{1,64}$'} | Sort-Object -Unique)
[IO.File]::WriteAllLines((Join-Path $build 'english_seed.txt'),$words,[Text.UTF8Encoding]::new($false))
if(-not $SkipOracle) {
    $csc=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    & $csc /nologo /optimize+ /target:exe /utf8output "/out:$build\oracle.exe" (Join-Path $PSScriptRoot 'oracle.cs') (Join-Path $root 'TelexEngine.cs') (Join-Path $root 'EnglishLexicon.cs') (Join-Path $root 'Productivity.cs') (Join-Path $root 'UserPreferences.cs')
    if($LASTEXITCODE -ne 0){throw 'Legacy oracle compile failed'}
    Push-Location $root
    try {
        & (Join-Path $build 'oracle.exe') (Join-Path $build 'oracle.tsv')
        if($LASTEXITCODE -ne 0){throw 'Oracle generation failed'}
    } finally {Pop-Location}
}
$cmake='C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
& $cmake -S $PSScriptRoot -B $build -G 'Visual Studio 17 2022' -A x64
if($LASTEXITCODE -ne 0){throw 'Native C++ configure failed'}
& $cmake --build $build --config Release
if($LASTEXITCODE -ne 0){throw 'Native C++ build failed'}
$tests=Join-Path $build 'Release\telexmini_core_tests.exe'
$userDir=Join-Path $env:LOCALAPPDATA 'TelexMini'
& $tests (Join-Path $build 'oracle.tsv') (Join-Path $build 'english_seed.txt') (Join-Path $userDir 'EnglishWords.txt') (Join-Path $userDir 'VietnameseOverrides.txt')
if($LASTEXITCODE -ne 0){throw 'Native engine mismatched bilingual oracle'}
Write-Output ('NATIVE_CORE='+ (Join-Path $build 'Release\TelexMiniEngine.dll'))
