[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [string]$LocalizationDatabasePath,
    [string]$TdbAccessDll = 'D:\Games\NHL\_tools\TDBAccess\x64\tdbaccess.dll'
)

$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
$baseline = Join-Path $ProjectRoot 'work\baseline'
$build = Join-Path $ProjectRoot 'work\build\phase1'
$teams = Join-Path $ProjectRoot 'data\teams.csv'
$donors = Join-Path $ProjectRoot 'data\donor-teams.csv'
$writer = Join-Path $PSScriptRoot 'Set-PwhlTeamIdentity.ps1'
$bioWriter = Join-Path $PSScriptRoot 'Set-PwhlPlayerBios.ps1'
$localizationVerifier = Join-Path $PSScriptRoot 'Test-PwhlLocalization.ps1'
$exporter = Join-Path $PSScriptRoot 'Export-TdbTable.ps1'
$playerMap = Join-Path $ProjectRoot 'data\player-slot-map.csv'
$localizationMap = Join-Path $ProjectRoot 'data\localization-map.csv'
if (-not $LocalizationDatabasePath) {
    $LocalizationDatabasePath = Join-Path $ProjectRoot 'work\localization\nhl_eng_us.db'
}
if (-not (Test-Path -LiteralPath $LocalizationDatabasePath -PathType Leaf)) {
    throw "Native-saved localization database not found: $LocalizationDatabasePath. Apply data/localization-map.csv in NHL Modding Studio and save a copy at this path."
}
New-Item -ItemType Directory -Force -Path $build | Out-Null
Copy-Item -LiteralPath (Join-Path $baseline 'nhlng.db') -Destination (Join-Path $build 'nhlng.db') -Force
Copy-Item -LiteralPath (Join-Path $baseline 'roster-save.bin') -Destination (Join-Path $build 'roster-save.bin') -Force
& $localizationVerifier -DatabasePath $LocalizationDatabasePath -LocalizationMapCsv $localizationMap
Copy-Item -LiteralPath $LocalizationDatabasePath -Destination (Join-Path $build 'nhl_eng_us.db') -Force
& $writer -DatabasePath (Join-Path $build 'nhlng.db') -TdbAccessDll $TdbAccessDll -TeamsCsv $teams -DonorMapCsv $donors
& $writer -DatabasePath (Join-Path $build 'roster-save.bin') -TdbAccessDll $TdbAccessDll -TeamsCsv $teams -DonorMapCsv $donors -ContainerFormat Xbox360
& $bioWriter -DatabasePath (Join-Path $build 'nhlng.db') -TdbAccessDll $TdbAccessDll -PlayerSlotMapCsv $playerMap
& $bioWriter -DatabasePath (Join-Path $build 'roster-save.bin') -TdbAccessDll $TdbAccessDll -PlayerSlotMapCsv $playerMap -ContainerFormat Xbox360
& $exporter -DatabasePath (Join-Path $build 'nhlng.db') -TdbAccessDll $TdbAccessDll -Table ttOk -OutputPath (Join-Path $build 'nhlng-teams.csv')
& $exporter -DatabasePath (Join-Path $build 'roster-save.bin') -TdbAccessDll $TdbAccessDll -Table ttOk -ContainerFormat Xbox360 -OutputPath (Join-Path $build 'roster-teams.csv')
$manifest = [ordered]@{
    generated_utc = [DateTime]::UtcNow.ToString('o')
    stage = 'phase1-team-identity-and-player-bios'
    files = @(
        Get-FileHash -LiteralPath (Join-Path $build 'nhlng.db') -Algorithm SHA256 | Select-Object Path, Hash
        Get-FileHash -LiteralPath (Join-Path $build 'roster-save.bin') -Algorithm SHA256 | Select-Object Path, Hash
        Get-FileHash -LiteralPath (Join-Path $build 'nhl_eng_us.db') -Algorithm SHA256 | Select-Object Path, Hash
    )
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $build 'manifest.json') -Encoding UTF8
Write-Host "Built Phase 1 candidate files in $build"
