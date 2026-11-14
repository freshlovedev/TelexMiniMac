param([string]$OutputPath = "$PSScriptRoot\TelexMini.exe")
$ErrorActionPreference = 'Stop'
# Release guard: never replace the canonical EXE if the tests fail.
& "$PSScriptRoot\test.ps1"
if ($LASTEXITCODE -ne 0) { throw 'Tests failed; old TelexMini.exe is unchanged.' }
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) {
    $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe'
}
$wpf = Join-Path (Split-Path $compiler) 'WPF'
& $compiler /nologo /target:winexe /platform:anycpu /optimize+ /utf8output /reference:System.Windows.Forms.dll /reference:System.Drawing.dll "/reference:$wpf\UIAutomationClient.dll" "/reference:$wpf\UIAutomationTypes.dll" "/reference:$wpf\WindowsBase.dll" "/out:$OutputPath" "$PSScriptRoot\Program.cs" "$PSScriptRoot\Keyboard.cs" "$PSScriptRoot\TextEditPlan.cs" "$PSScriptRoot\Productivity.cs" "$PSScriptRoot\ProductivitySettings.cs" "$PSScriptRoot\SpellAdvisor.cs" "$PSScriptRoot\ConfigSync.cs" "$PSScriptRoot\TelexEngine.cs" "$PSScriptRoot\EnglishLexicon.cs" "$PSScriptRoot\UserPreferences.cs" "$PSScriptRoot\ModernChrome.cs" "$PSScriptRoot\DictionaryEditor.cs" "$PSScriptRoot\AdvancedSettings.cs" "$PSScriptRoot\InputContext.cs"
if ($LASTEXITCODE -ne 0) { throw 'Build failed.' }
Write-Host "Built: $OutputPath"
