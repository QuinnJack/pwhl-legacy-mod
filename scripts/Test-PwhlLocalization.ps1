[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$DatabasePath,
    [Parameter(Mandatory)] [string]$LocalizationMapCsv,
    [string]$TdbAccessDll = 'D:\Games\NHL\_tools\TDBAccess\x86\tdbaccess.dll',
    [switch]$Worker
)

$ErrorActionPreference = 'Stop'
if (-not $Worker -and [Environment]::Is64BitProcess) {
    $powershell32 = Join-Path $env:WINDIR 'SysWOW64\WindowsPowerShell\v1.0\powershell.exe'
    & $powershell32 -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath -DatabasePath $DatabasePath -LocalizationMapCsv $LocalizationMapCsv -TdbAccessDll $TdbAccessDll -Worker
    if ($LASTEXITCODE -ne 0) { throw "32-bit localization test failed with exit code $LASTEXITCODE." }
    return
}

$dbPath = (Resolve-Path -LiteralPath $DatabasePath).Path
$dllPath = (Resolve-Path -LiteralPath $TdbAccessDll).Path
$entries = Import-Csv -LiteralPath (Resolve-Path -LiteralPath $LocalizationMapCsv).Path
$nativeSource = @'
using System;
using System.Runtime.InteropServices;
public static class TdbLocalizationVerifier {
 [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] public static extern bool SetDllDirectory(string path);
 [DllImport("tdbaccess.dll", CharSet=CharSet.Unicode)] public static extern int TDBOpen(string path);
 [DllImport("tdbaccess.dll")] public static extern bool TDBClose(int db);
 [DllImport("tdbaccess.dll", CharSet=CharSet.Unicode, EntryPoint="TDBFieldGetValueAsString")] public static extern bool GetString(int db,string table,string field,int record,ref string value);
}
'@
Add-Type $nativeSource
[TdbLocalizationVerifier]::SetDllDirectory((Split-Path -Parent $dllPath)) | Out-Null
$db = [TdbLocalizationVerifier]::TDBOpen($dbPath)
if ($db -lt 0) { throw "Could not open $dbPath" }
$errors = [Collections.Generic.List[string]]::new()
try {
    foreach ($entry in $entries) {
        $value = New-Object string([char]0, 4001)
        if (-not [TdbLocalizationVerifier]::GetString($db, 'GJCv', 'bYbZ', [int]$entry.record, [ref]$value)) {
            $errors.Add("Could not read $($entry.key).")
            continue
        }
        $actual = $value.TrimEnd([char]0)
        if ($actual -ne $entry.new_value) { $errors.Add("$($entry.key): expected '$($entry.new_value)', got '$actual'.") }
    }
}
finally { [void][TdbLocalizationVerifier]::TDBClose($db) }
if ($errors.Count) { $errors | ForEach-Object { Write-Error $_ }; exit 1 }
Write-Host "Verified $($entries.Count) PWHL localization values in $dbPath"
