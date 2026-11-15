$ErrorActionPreference = 'Stop'

Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class TelexMiniBridgeSmoke {
  public delegate bool EnumProc(IntPtr handle, IntPtr data);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr data);
  [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr window, EnumProc cb, IntPtr data);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr window, StringBuilder text, int count);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);
}
'@

function Get-NativeModeText {
  $engine = Get-Process -Name TelexMini -ErrorAction Stop | Select-Object -First 1
  $windows = New-Object 'System.Collections.Generic.List[System.IntPtr]'
  $collect = [TelexMiniBridgeSmoke+EnumProc]{
    param([IntPtr]$handle,[IntPtr]$unused)
    [uint32]$owner=0
    [void][TelexMiniBridgeSmoke]::GetWindowThreadProcessId($handle,[ref]$owner)
    if($owner -eq $engine.Id) {
      $title=New-Object Text.StringBuilder 256
      [void][TelexMiniBridgeSmoke]::GetWindowText($handle,$title,256)
      if($title.ToString() -like 'TelexMini*') { $windows.Add($handle) }
    }
    return $true
  }.GetNewClosure()
  [void][TelexMiniBridgeSmoke]::EnumWindows($collect,[IntPtr]::Zero)
  if($windows.Count -eq 0){throw 'Native TelexMini window not found (may not be running).' }
  $labels=New-Object 'System.Collections.Generic.List[string]'
  $children=[TelexMiniBridgeSmoke+EnumProc]{
    param([IntPtr]$handle,[IntPtr]$unused)
    $text=New-Object Text.StringBuilder 256
    [void][TelexMiniBridgeSmoke]::GetWindowText($handle,$text,256)
    if($text.Length -gt 0){$labels.Add($text.ToString())}
    return $true
  }.GetNewClosure()
  [void][TelexMiniBridgeSmoke]::EnumChildWindows($windows[0],$children,[IntPtr]::Zero)
  return @($labels | Where-Object { $_ -match '^[VE]\s*[·.]' })
}

$path=Join-Path $env:LOCALAPPDATA 'TelexMini\preferences.ini'
if(-not (Test-Path -LiteralPath $path)){throw "Preferences missing: $path"}
$original=[IO.File]::ReadAllBytes($path)
try {
  foreach($value in @('false','true')) {
    $lines=@([IO.File]::ReadAllLines($path,[Text.Encoding]::UTF8) |
      Where-Object { $_ -notmatch '^VietnameseEnabled=' })
    $lines += 'VietnameseEnabled='+$value
    [IO.File]::WriteAllLines($path,$lines,[Text.UTF8Encoding]::new($false))
    Start-Sleep -Milliseconds 1100
    $buttons=@(Get-NativeModeText)
    $prefix=if($value -eq 'true'){'V'}else{'E'}
    $found=@($buttons | Where-Object { $_ -match ('^'+$prefix+'\s*[·.]') })
    if($found.Count -eq 0) {
      throw "Native engine did not apply V/E=$value. Visible native labels: $($buttons -join ', ')"
    }
    Write-Output ("PASS native input engine mode "+$prefix+": "+$found[0])
  }
} finally {
  [IO.File]::WriteAllBytes($path,$original)
  Start-Sleep -Milliseconds 500
}
Write-Output 'PASS preferences restored byte-for-byte.'
