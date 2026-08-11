[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)] [string]$DatabasePath,
    [Parameter(Mandatory)] [string]$TdbAccessDll,
    [Parameter(Mandatory)] [string]$PlayerSlotMapCsv,
    [ValidateSet('Plain', 'Xbox360')] [string]$ContainerFormat = 'Plain'
)

$ErrorActionPreference = 'Stop'
$dbPath = (Resolve-Path -LiteralPath $DatabasePath).Path
$dllPath = (Resolve-Path -LiteralPath $TdbAccessDll).Path
$players = Import-Csv -LiteralPath (Resolve-Path -LiteralPath $PlayerSlotMapCsv).Path
if ($players.Count -ne 184) { throw "Expected 184 player mappings; found $($players.Count)." }
if (($players.bio_record | Sort-Object -Unique).Count -ne 184) { throw 'Every mapped player must use a unique bio record.' }

$nativeSource = @'
using System;
using System.Runtime.InteropServices;
public static class TdbBioWriter
{
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern bool SetDllDirectory(string path);
    [DllImport("tdbaccess.dll", CallingConvention = CallingConvention.StdCall, CharSet = CharSet.Unicode)] public static extern Int32 TDBOpen(string fileName);
    [DllImport("tdbaccess.dll", CallingConvention = CallingConvention.StdCall, CharSet = CharSet.Unicode)] public static extern Int32 TDBOpenXbox360Save(string fileName);
    [DllImport("tdbaccess.dll", CallingConvention = CallingConvention.StdCall)] [return: MarshalAs(UnmanagedType.I1)] public static extern bool TDBSave(Int32 dbIndex);
    [DllImport("tdbaccess.dll", CallingConvention = CallingConvention.StdCall)] [return: MarshalAs(UnmanagedType.I1)] public static extern bool TDBClose(Int32 dbIndex);
    [DllImport("tdbaccess.dll", CallingConvention = CallingConvention.StdCall, CharSet = CharSet.Unicode)] [return: MarshalAs(UnmanagedType.I1)] public static extern bool TDBFieldSetValueAsString(Int32 dbIndex, string tableName, string fieldName, Int32 recordNumber, string newValue);
    [DllImport("tdbaccess.dll", CallingConvention = CallingConvention.StdCall, CharSet = CharSet.Unicode)] [return: MarshalAs(UnmanagedType.I1)] public static extern bool TDBFieldSetValueAsInteger(Int32 dbIndex, string tableName, string fieldName, Int32 recordNumber, Int32 newValue);
}
'@

if (-not ('TdbBioWriter' -as [type])) { Add-Type -TypeDefinition $nativeSource }
if (-not [TdbBioWriter]::SetDllDirectory((Split-Path -Parent $dllPath))) { throw 'Unable to add the TDBAccess DLL directory.' }
$db = if ($ContainerFormat -eq 'Xbox360') { [TdbBioWriter]::TDBOpenXbox360Save($dbPath) } else { [TdbBioWriter]::TDBOpen($dbPath) }
if ($db -lt 0) { throw "TDBAccess could not open $dbPath" }

try {
    foreach ($player in $players) {
        $record = [int]$player.bio_record
        if ($PSCmdlet.ShouldProcess("$dbPath bio record $record", "Write $($player.player_name)")) {
            if (-not [TdbBioWriter]::TDBFieldSetValueAsString($db, 'cPbu', 'PedH', $record, $player.first_name)) { throw "Could not write first name at bio $record." }
            if (-not [TdbBioWriter]::TDBFieldSetValueAsString($db, 'cPbu', 'RMbQ', $record, $player.last_name)) { throw "Could not write last name at bio $record." }
            if (-not [TdbBioWriter]::TDBFieldSetValueAsInteger($db, 'cPbu', 'aljv', $record, [int]$player.position_code)) { throw "Could not write position at bio $record." }
        }
    }
    if (-not $WhatIfPreference -and -not [TdbBioWriter]::TDBSave($db)) { throw "TDBAccess could not save $dbPath" }
}
finally { [void][TdbBioWriter]::TDBClose($db) }
Write-Host "Applied 184 PWHL player bios to $dbPath"
