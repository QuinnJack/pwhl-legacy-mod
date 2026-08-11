[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ProjectRoot,
    [string]$GameRoot = 'D:\Games\NHL\game',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
$candidateDb = Join-Path $ProjectRoot 'work\build\phase1\nhlng.db'
$baselineDb = Join-Path $ProjectRoot 'work\baseline\nhlng.db'
$targetDb = Join-Path $GameRoot '_compiled\db\nhlng.db'
$candidateLoc = Join-Path $ProjectRoot 'work\build\phase1\nhl_eng_us.db'
$baselineLoc = Join-Path $ProjectRoot 'work\baseline\nhl_eng_us.db'
$targetLoc = Join-Path $GameRoot '_compiled\fe\loc\nhl_eng_us.db'
$localizationMap = Join-Path $ProjectRoot 'data\localization-map.csv'
$localizationVerifier = Join-Path $PSScriptRoot 'Test-PwhlLocalization.ps1'
foreach ($path in @($candidateDb, $baselineDb, $targetDb, $candidateLoc, $baselineLoc, $targetLoc)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required file not found: $path" }
}

$running = Get-Process -Name nhllegacy -ErrorAction SilentlyContinue
if ($running) { throw 'Close NHL Legacy before installing the candidate database.' }
& $localizationVerifier -DatabasePath $candidateLoc -LocalizationMapCsv $localizationMap

$candidateDbHash = (Get-FileHash -LiteralPath $candidateDb -Algorithm SHA256).Hash
$baselineDbHash = (Get-FileHash -LiteralPath $baselineDb -Algorithm SHA256).Hash
$targetDbHash = (Get-FileHash -LiteralPath $targetDb -Algorithm SHA256).Hash
$candidateLocHash = (Get-FileHash -LiteralPath $candidateLoc -Algorithm SHA256).Hash
$baselineLocHash = (Get-FileHash -LiteralPath $baselineLoc -Algorithm SHA256).Hash
$targetLocHash = (Get-FileHash -LiteralPath $targetLoc -Algorithm SHA256).Hash
if (-not $Force -and $targetDbHash -notin @($baselineDbHash, $candidateDbHash)) {
    throw "The installed roster database has an unknown checksum ($targetDbHash). Use -Force only after preserving those changes."
}
if (-not $Force -and $targetLocHash -notin @($baselineLocHash, $candidateLocHash)) {
    throw "The installed localization database has an unknown checksum ($targetLocHash). Use -Force only after preserving those changes."
}
if ($targetDbHash -eq $candidateDbHash -and $targetLocHash -eq $candidateLocHash) {
    Write-Host 'The current Phase 1 candidate is already installed.'
    return
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = Join-Path $ProjectRoot "work\deploy-backups\$stamp"
if ($PSCmdlet.ShouldProcess($GameRoot, 'Back up and install the Phase 1 roster and localization databases')) {
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
    Copy-Item -LiteralPath $targetDb -Destination (Join-Path $backupDir 'nhlng.db')
    Copy-Item -LiteralPath $targetLoc -Destination (Join-Path $backupDir 'nhl_eng_us.db')
    [ordered]@{
        created_local = (Get-Date).ToString('o')
        roster_original_path = $targetDb
        roster_original_sha256 = $targetDbHash
        roster_candidate_sha256 = $candidateDbHash
        localization_original_path = $targetLoc
        localization_original_sha256 = $targetLocHash
        localization_candidate_sha256 = $candidateLocHash
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $backupDir 'manifest.json') -Encoding UTF8
    Copy-Item -LiteralPath $candidateDb -Destination $targetDb -Force
    Copy-Item -LiteralPath $candidateLoc -Destination $targetLoc -Force
    $installedDbHash = (Get-FileHash -LiteralPath $targetDb -Algorithm SHA256).Hash
    $installedLocHash = (Get-FileHash -LiteralPath $targetLoc -Algorithm SHA256).Hash
    if ($installedDbHash -ne $candidateDbHash -or $installedLocHash -ne $candidateLocHash) { throw 'An installed checksum does not match the candidate.' }
    Write-Host "Installed Phase 1 database. Backup: $backupDir"
}
