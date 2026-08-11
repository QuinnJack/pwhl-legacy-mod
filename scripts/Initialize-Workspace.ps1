[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$GameRoot,
    [string]$RosterPath,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$resolvedGame = (Resolve-Path $GameRoot).Path
$baseline = Join-Path $root 'work/baseline'
$working = Join-Path $root 'work/current'

$sources = @{
    'nhlng.db' = Join-Path $resolvedGame '_compiled/db/nhlng.db'
    'draft_roster.db' = Join-Path $resolvedGame '_compiled/db/draft_roster.db'
    'dynamic_ratings.db' = Join-Path $resolvedGame '_compiled/db/dynamic_ratings.db'
    'nhlng-meta.xml' = Join-Path $resolvedGame '_compiled/db/nhlng-meta.xml'
}

foreach ($entry in $sources.GetEnumerator()) {
    if (-not (Test-Path -LiteralPath $entry.Value)) { throw "Required game file not found: $($entry.Value)" }
}

if ($RosterPath) {
    $resolvedRoster = (Resolve-Path $RosterPath).Path
    $rosterBaseline = Join-Path $baseline 'roster-save.bin'
    $rosterWorking = Join-Path $working 'roster-save.bin'
    if ($Force -or -not (Test-Path -LiteralPath $rosterBaseline)) { Copy-Item -LiteralPath $resolvedRoster -Destination $rosterBaseline -Force }
    if ($Force -or -not (Test-Path -LiteralPath $rosterWorking)) { Copy-Item -LiteralPath $rosterBaseline -Destination $rosterWorking -Force }
}

New-Item -ItemType Directory -Force $baseline, $working | Out-Null

foreach ($entry in $sources.GetEnumerator()) {
    $baseTarget = Join-Path $baseline $entry.Key
    $workTarget = Join-Path $working $entry.Key
    if ($Force -or -not (Test-Path -LiteralPath $baseTarget)) {
        Copy-Item -LiteralPath $entry.Value -Destination $baseTarget -Force
    }
    if ($Force -or -not (Test-Path -LiteralPath $workTarget)) {
        Copy-Item -LiteralPath $baseTarget -Destination $workTarget -Force
    }
}

$hashes = foreach ($name in $sources.Keys) {
    $path = Join-Path $baseline $name
    $hash = Get-FileHash -LiteralPath $path -Algorithm SHA256
    [pscustomobject]@{ file = $name; sha256 = $hash.Hash.ToLowerInvariant(); bytes = (Get-Item $path).Length }
}
if (Test-Path -LiteralPath (Join-Path $baseline 'roster-save.bin')) {
    $path = Join-Path $baseline 'roster-save.bin'
    $hash = Get-FileHash -LiteralPath $path -Algorithm SHA256
    $hashes += [pscustomobject]@{ file = 'roster-save.bin'; sha256 = $hash.Hash.ToLowerInvariant(); bytes = (Get-Item $path).Length }
}
$hashes | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $baseline 'checksums.json') -Encoding UTF8

Write-Host "Baseline and working copies prepared under $root\work."
Write-Host 'Original game files were not modified.'
