param([switch]$Integration, [switch]$Benchmark)
$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) {
    $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe'
}
$testDirectory = Join-Path $env:TEMP ('TelexMiniNativeTests-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $testDirectory | Out-Null
$testExe = Join-Path $testDirectory 'TelexMiniTests.exe'
& (Join-Path $PSScriptRoot 'native_engine\build-native.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Native C++ engine test/build failed.' }
Copy-Item (Join-Path $PSScriptRoot 'native_engine\build\Release\TelexMiniEngine.dll') $testDirectory -Force
Copy-Item (Join-Path $PSScriptRoot 'native_engine\build\english_seed.txt') $testDirectory -Force
$wpf = Join-Path (Split-Path $compiler) 'WPF'
try {
    & $compiler /nologo /target:exe /main:TelexMini.Tests /utf8output /reference:System.Windows.Forms.dll /reference:System.Drawing.dll "/reference:$wpf\UIAutomationClient.dll" "/reference:$wpf\UIAutomationTypes.dll" "/reference:$wpf\WindowsBase.dll" "/out:$testExe" "$PSScriptRoot\Tests.cs" "$PSScriptRoot\WindowsPerfBench.cs" "$PSScriptRoot\BilingualCorpus.cs" "$PSScriptRoot\UiText.cs" "$PSScriptRoot\Program.cs" "$PSScriptRoot\StableRuntime.cs" "$PSScriptRoot\Keyboard.cs" "$PSScriptRoot\SmartTextFeatures.cs" "$PSScriptRoot\NativeComposer.cs" "$PSScriptRoot\ClipboardMacroSnapshot.cs" "$PSScriptRoot\ExpansionUndo.cs" "$PSScriptRoot\TextEditPlan.cs" "$PSScriptRoot\Productivity.cs" "$PSScriptRoot\ProductivitySettings.cs" "$PSScriptRoot\SpellAdvisor.cs" "$PSScriptRoot\ConfigSync.cs" "$PSScriptRoot\TelexEngine.cs" "$PSScriptRoot\EnglishLexicon.cs" "$PSScriptRoot\UserPreferences.cs" "$PSScriptRoot\ModernChrome.cs" "$PSScriptRoot\TrayMenuStyle.cs" "$PSScriptRoot\DictionaryEditor.cs" "$PSScriptRoot\AdvancedSettings.cs" "$PSScriptRoot\InputContext.cs"
    if ($LASTEXITCODE -ne 0) { throw 'Test compilation failed.' }
    # The Unicode oracle belongs to the source tree, not the temporary
    # test EXE. Resolve paths correctly even when invoked from elsewhere.
    Push-Location -LiteralPath $PSScriptRoot
    try {
        if ($Benchmark) { & $testExe --benchmark } elseif ($Integration) { & $testExe --integration } else { & $testExe }
        if ($LASTEXITCODE -ne 0) { throw 'Tests failed.' }
    } finally {
        Pop-Location
    }
} finally {
    if (Test-Path -LiteralPath $testDirectory) { Remove-Item -LiteralPath $testDirectory -Recurse -Force }
}
