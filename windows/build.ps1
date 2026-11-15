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
$iconSource = Join-Path $PSScriptRoot 'Resources\TelexMini-Icon-Teal.png'
if (-not (Test-Path -LiteralPath $iconSource)) {
    $iconSource = Join-Path $PSScriptRoot '..\Resources\TelexMini-Icon-Teal.png'
}
$iconPath = Join-Path $env:TEMP ('TelexMini-AppIcon-' + [Guid]::NewGuid().ToString('N') + '.ico')
if (-not (Test-Path -LiteralPath $iconSource)) { throw 'Missing TelexMini app icon source.' }
& (Join-Path $PSScriptRoot 'make-icon.ps1') -SourcePath $iconSource -OutputPath $iconPath
if ($LASTEXITCODE -ne 0) { throw 'App icon generation failed; old EXE is unchanged.' }
try {
& $compiler /nologo /target:winexe /platform:anycpu /optimize+ /utf8output "/win32icon:$iconPath" /reference:System.Windows.Forms.dll /reference:System.Drawing.dll "/reference:$wpf\UIAutomationClient.dll" "/reference:$wpf\UIAutomationTypes.dll" "/reference:$wpf\WindowsBase.dll" "/out:$OutputPath" "$PSScriptRoot\UiText.cs" "$PSScriptRoot\Program.cs" "$PSScriptRoot\Keyboard.cs" "$PSScriptRoot\NativeComposer.cs" "$PSScriptRoot\ClipboardMacroSnapshot.cs" "$PSScriptRoot\ExpansionUndo.cs" "$PSScriptRoot\TextEditPlan.cs" "$PSScriptRoot\Productivity.cs" "$PSScriptRoot\ProductivitySettings.cs" "$PSScriptRoot\SpellAdvisor.cs" "$PSScriptRoot\ConfigSync.cs" "$PSScriptRoot\TelexEngine.cs" "$PSScriptRoot\EnglishLexicon.cs" "$PSScriptRoot\UserPreferences.cs" "$PSScriptRoot\ModernChrome.cs" "$PSScriptRoot\TrayMenuStyle.cs" "$PSScriptRoot\DictionaryEditor.cs" "$PSScriptRoot\AdvancedSettings.cs" "$PSScriptRoot\InputContext.cs"
$compileExit = $LASTEXITCODE
} finally {
    if (Test-Path -LiteralPath $iconPath) { Remove-Item -LiteralPath $iconPath -Force }
}
if ($compileExit -ne 0) { throw 'Build failed.' }
$nativeDir=Split-Path $OutputPath -Parent
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'native_engine\build\Release\TelexMiniEngine.dll') -Destination (Join-Path $nativeDir 'TelexMiniEngine.dll') -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'native_engine\build\english_seed.txt') -Destination (Join-Path $nativeDir 'english_seed.txt') -Force
Write-Host "Built: $OutputPath"
