$ErrorActionPreference = 'Stop'
$dist = Join-Path $PSScriptRoot 'dist'
$zip = Join-Path $dist 'TelexMini-Windows-preview.zip'
$checksum = $zip + '.sha256'
if (-not (Test-Path -LiteralPath $zip) -or -not (Test-Path -LiteralPath $checksum)) {
    throw 'Missing archive or SHA256 file'
}
$expected = ((Get-Content -LiteralPath $checksum -Raw).Trim() -split '\s+')[0]
$actual = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
if ($expected -ne $actual) {throw "SHA256 mismatch: expected $expected actual $actual"}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($zip)
try {
    $names = @($archive.Entries | ForEach-Object { $_.FullName })
    if (-not ($names -contains 'TelexMini.exe')) {throw 'EXE missing from ZIP'}
    if (-not ($names -contains 'HUONG-DAN.md')) {throw 'Guide missing from ZIP'}
    if (($names | Where-Object { $_ -match '(preferences\.ini|EnglishWords\.txt|VietnameseOverrides\.txt|snippets\.tsv|profiles\.tsv|\.env)' }).Count -gt 0) {
        throw 'Private user data must not be packaged'
    }
    Write-Host 'HASH_MATCH=True'
    Write-Host "PREVIEW_FILES=$($names -join ',')"
    Write-Host "SHA256=$actual"
} finally {
    $archive.Dispose()
}
