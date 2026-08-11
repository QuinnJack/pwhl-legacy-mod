[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$DatabasePath,
    [Parameter(Mandatory)] [string]$OutputPath,
    [string]$TdbAccessDll = 'D:\Games\NHL\_tools\TDBAccess\x86\tdbaccess.dll',
    [switch]$Worker
)

$ErrorActionPreference = 'Stop'
if (-not $Worker -and [Environment]::Is64BitProcess) {
    $powershell32 = Join-Path $env:WINDIR 'SysWOW64\WindowsPowerShell\v1.0\powershell.exe'
    & $powershell32 -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath -DatabasePath $DatabasePath -OutputPath $OutputPath -TdbAccessDll $TdbAccessDll -Worker
    if ($LASTEXITCODE -ne 0) { throw "32-bit localization export failed with exit code $LASTEXITCODE." }
    return
}

$dbPath = (Resolve-Path -LiteralPath $DatabasePath).Path
$dllPath = (Resolve-Path -LiteralPath $TdbAccessDll).Path
$outputFull = [IO.Path]::GetFullPath($OutputPath)
$nativeSource = @'
using System;
using System.Runtime.InteropServices;
public static class TdbLocalizationReader {
 [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] public static extern bool SetDllDirectory(string path);
 [DllImport("tdbaccess.dll", CharSet=CharSet.Unicode)] public static extern int TDBOpen(string path);
 [DllImport("tdbaccess.dll")] public static extern bool TDBClose(int db);
 [DllImport("tdbaccess.dll", CharSet=CharSet.Unicode)] public static extern int TDBFieldGetValueAsInteger(int db,string table,string field,int record);
 [DllImport("tdbaccess.dll", CharSet=CharSet.Unicode, EntryPoint="TDBFieldGetValueAsString")] public static extern bool GetString(int db,string table,string field,int record,ref string value);
}
'@
Add-Type $nativeSource
[TdbLocalizationReader]::SetDllDirectory((Split-Path -Parent $dllPath)) | Out-Null
$db = [TdbLocalizationReader]::TDBOpen($dbPath)
if ($db -lt 0) { throw "Could not open $dbPath" }
try {
    $rows = for ($record = 0; $record -lt 25782; $record++) {
        $shortValue = New-Object string([char]0, 101)
        $longValue = New-Object string([char]0, 4001)
        [void][TdbLocalizationReader]::GetString($db, 'GJCv', 'VhAs', $record, [ref]$shortValue)
        [void][TdbLocalizationReader]::GetString($db, 'GJCv', 'bYbZ', $record, [ref]$longValue)
        [pscustomobject][ordered]@{
            record = $record
            hash = [BitConverter]::ToUInt32([BitConverter]::GetBytes([TdbLocalizationReader]::TDBFieldGetValueAsInteger($db, 'GJCv', 'jKhj', $record)), 0)
            value = $shortValue.TrimEnd([char]0)
            description = $longValue.TrimEnd([char]0)
        }
    }
    $rows | Export-Csv -LiteralPath $outputFull -NoTypeInformation -Encoding UTF8
    Write-Host "Exported $($rows.Count) localization rows to $outputFull"
}
finally { [void][TdbLocalizationReader]::TDBClose($db) }
