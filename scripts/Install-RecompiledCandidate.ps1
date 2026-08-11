[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ProjectRoot,
    [string]$GameRoot = 'D:\Games\NHL\game',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
$candidate = Join-Path $ProjectRoot 'work\build\phase1\nhlng.db'
$baseline = Join-Path $ProjectRoot 'work\baseline\nhlng.db'
$target = Join-Path $GameRoot '_compiled\db\nhlng.db'
foreach ($path in @($candidate, $baseline, $target)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required file not found: $path" }
}

$running = Get-Process -Name nhllegacy -ErrorAction SilentlyContinue
if ($running) { throw 'Close NHL Legacy before installing the candidate database.' }

$candidateHash = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash
$baselineHash = (Get-FileHash -LiteralPath $baseline -Algorithm SHA256).Hash
$targetHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
if (-not $Force -and $targetHash -notin @($baselineHash, $candidateHash)) {
    throw "The installed database has an unknown checksum ($targetHash). Use -Force only after preserving those changes."
}
if ($targetHash -eq $candidateHash) {
    Write-Host 'The current Phase 1 candidate is already installed.'
    return
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = Join-Path $ProjectRoot "work\deploy-backups\$stamp"
if ($PSCmdlet.ShouldProcess($target, 'Back up and install the Phase 1 candidate')) {
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
    Copy-Item -LiteralPath $target -Destination (Join-Path $backupDir 'nhlng.db')
    [ordered]@{
        created_local = (Get-Date).ToString('o')
        original_path = $target
        original_sha256 = $targetHash
        candidate_sha256 = $candidateHash
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $backupDir 'manifest.json') -Encoding UTF8
    Copy-Item -LiteralPath $candidate -Destination $target -Force
    $installedHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
    if ($installedHash -ne $candidateHash) { throw 'Installed database checksum does not match the candidate.' }
    Write-Host "Installed Phase 1 database. Backup: $backupDir"
}
