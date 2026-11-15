param([switch]$Integration)
$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) {
    $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe'
}
$testExe = Join-Path $env:TEMP ('TelexMiniTests-' + [Guid]::NewGuid().ToString('N') + '.exe')
$wpf = Join-Path (Split-Path $compiler) 'WPF'
try {
    & $compiler /nologo /target:exe /main:TelexMini.Tests /utf8output /reference:System.Windows.Forms.dll /reference:System.Drawing.dll "/reference:$wpf\UIAutomationClient.dll" "/reference:$wpf\UIAutomationTypes.dll" "/reference:$wpf\WindowsBase.dll" "/out:$testExe" "$PSScriptRoot\Tests.cs" "$PSScriptRoot\UiText.cs" "$PSScriptRoot\Program.cs" "$PSScriptRoot\Keyboard.cs" "$PSScriptRoot\TextEditPlan.cs" "$PSScriptRoot\Productivity.cs" "$PSScriptRoot\ProductivitySettings.cs" "$PSScriptRoot\SpellAdvisor.cs" "$PSScriptRoot\ConfigSync.cs" "$PSScriptRoot\TelexEngine.cs" "$PSScriptRoot\EnglishLexicon.cs" "$PSScriptRoot\UserPreferences.cs" "$PSScriptRoot\ModernChrome.cs" "$PSScriptRoot\DictionaryEditor.cs" "$PSScriptRoot\AdvancedSettings.cs" "$PSScriptRoot\InputContext.cs"
    if ($LASTEXITCODE -ne 0) { throw 'Test compilation failed.' }
    # The Unicode oracle belongs to the source tree, not the temporary
    # test EXE. Resolve paths correctly even when invoked from elsewhere.
    Push-Location -LiteralPath $PSScriptRoot
    try {
        if ($Integration) { & $testExe --integration } else { & $testExe }
        if ($LASTEXITCODE -ne 0) { throw 'Tests failed.' }
    } finally {
        Pop-Location
    }
} finally {
    if (Test-Path -LiteralPath $testExe) { Remove-Item -LiteralPath $testExe }
}
