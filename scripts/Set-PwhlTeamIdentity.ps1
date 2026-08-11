[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)] [string]$DatabasePath,
    [Parameter(Mandatory)] [string]$TdbAccessDll,
    [Parameter(Mandatory)] [string]$TeamsCsv,
    [Parameter(Mandatory)] [string]$DonorMapCsv,
    [ValidateSet('Plain', 'Xbox360')] [string]$ContainerFormat = 'Plain'
)

$ErrorActionPreference = 'Stop'
$dbPath = (Resolve-Path -LiteralPath $DatabasePath).Path
$dllPath = (Resolve-Path -LiteralPath $TdbAccessDll).Path
$teams = Import-Csv -LiteralPath (Resolve-Path -LiteralPath $TeamsCsv).Path |
    Where-Object status -eq 'active' | Group-Object team_id -AsHashTable -AsString
$donors = Import-Csv -LiteralPath (Resolve-Path -LiteralPath $DonorMapCsv).Path
if ($donors.Count -ne 8) { throw "Expected eight donor mappings; found $($donors.Count)." }
if (($donors.donor_record | Sort-Object -Unique).Count -ne 8) { throw 'Donor records must be unique.' }

$nativeSource = @'
using System;
using System.Runtime.InteropServices;
public static class TdbTeamWriter
{
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern bool SetDllDirectory(string path);
    [DllImport("tdbaccess.dll", CallingConvention = CallingConvention.StdCall, CharSet = CharSet.Unicode)] public static extern Int32 TDBOpen(string fileName);
    [DllImport("tdbaccess.dll", CallingConvention = CallingConvention.StdCall, CharSet = CharSet.Unicode)] public static extern Int32 TDBOpenXbox360Save(string fileName);
    [DllImport("tdbaccess.dll", CallingConvention = CallingConvention.StdCall)] [return: MarshalAs(UnmanagedType.I1)] public static extern bool TDBSave(Int32 dbIndex);
    [DllImport("tdbaccess.dll", CallingConvention = CallingConvention.StdCall)] [return: MarshalAs(UnmanagedType.I1)] public static extern bool TDBClose(Int32 dbIndex);
    [DllImport("tdbaccess.dll", CallingConvention = CallingConvention.StdCall, CharSet = CharSet.Unicode)] [return: MarshalAs(UnmanagedType.I1)] public static extern bool TDBFieldSetValueAsString(Int32 dbIndex, string tableName, string fieldName, Int32 recordNumber, string newValue);
}
'@

if (-not ('TdbTeamWriter' -as [type])) { Add-Type -TypeDefinition $nativeSource }
if (-not [TdbTeamWriter]::SetDllDirectory((Split-Path -Parent $dllPath))) { throw 'Unable to add the TDBAccess DLL directory.' }
$db = if ($ContainerFormat -eq 'Xbox360') { [TdbTeamWriter]::TDBOpenXbox360Save($dbPath) } else { [TdbTeamWriter]::TDBOpen($dbPath) }
if ($db -lt 0) { throw "TDBAccess could not open $dbPath" }

try {
    foreach ($donor in $donors) {
        if (-not $teams.ContainsKey($donor.pwhl_team_id)) { throw "No active team row exists for '$($donor.pwhl_team_id)'." }
        $team = $teams[$donor.pwhl_team_id][0]
        $record = [int]$donor.donor_record
        $fullName = "$($team.city) $($team.name)"
        $values = [ordered]@{ JkmY = $fullName; ITNQ = $team.city; nnsx = $team.abbreviation }
        if ($PSCmdlet.ShouldProcess("$dbPath record $record", "Rename donor to $fullName")) {
            foreach ($entry in $values.GetEnumerator()) {
                if (-not [TdbTeamWriter]::TDBFieldSetValueAsString($db, 'ttOk', $entry.Key, $record, $entry.Value)) {
                    throw "Unable to write ttOk.$($entry.Key) at record $record."
                }
            }
        }
    }
    if (-not $WhatIfPreference -and -not [TdbTeamWriter]::TDBSave($db)) { throw "TDBAccess could not save $dbPath" }
}
finally { [void][TdbTeamWriter]::TDBClose($db) }
Write-Host "Applied eight PWHL team identities to $dbPath"
