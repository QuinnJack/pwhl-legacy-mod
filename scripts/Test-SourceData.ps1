[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$teams = Import-Csv (Join-Path $root 'data/teams.csv')
$players = Import-Csv (Join-Path $root 'data/players.csv')
$donorPath = Join-Path $root 'data/donor-teams.csv'
$slotMapPath = Join-Path $root 'data/player-slot-map.csv'
$localizationMapPath = Join-Path $root 'data/localization-map.csv'
$errors = [System.Collections.Generic.List[string]]::new()

$duplicateTeams = $teams | Group-Object team_id | Where-Object Count -ne 1
foreach ($item in $duplicateTeams) { $errors.Add("Duplicate team_id: $($item.Name)") }

$knownTeams = @{}
foreach ($team in $teams) { $knownTeams[$team.team_id] = $true }

foreach ($player in $players) {
    if (-not $knownTeams.ContainsKey($player.team_id)) { $errors.Add("Unknown team for $($player.player_name): $($player.team_id)") }
    if ($player.position_group -notin @('F', 'D', 'G')) { $errors.Add("Invalid position for $($player.player_name): $($player.position_group)") }
    if ([string]::IsNullOrWhiteSpace($player.player_name)) { $errors.Add('Blank player name') }
}

$duplicates = $players | Group-Object team_id, player_name | Where-Object Count -gt 1
foreach ($item in $duplicates) { $errors.Add("Duplicate player row: $($item.Name)") }

$activeTeams = $teams | Where-Object status -eq 'active'
foreach ($team in $activeTeams) {
    $roster = $players | Where-Object team_id -eq $team.team_id
    $counts = @{
        F = @($roster | Where-Object position_group -eq 'F').Count
        D = @($roster | Where-Object position_group -eq 'D').Count
        G = @($roster | Where-Object position_group -eq 'G').Count
    }
    if ($roster.Count -ne 23) { $errors.Add("$($team.team_id) has $($roster.Count) active players; expected 23") }
    if ($counts.F -ne 13 -or $counts.D -ne 7 -or $counts.G -ne 3) {
        $errors.Add("$($team.team_id) position mix is F=$($counts.F), D=$($counts.D), G=$($counts.G); expected 13/7/3")
    }
}

if (Test-Path -LiteralPath $donorPath) {
    $donors = Import-Csv -LiteralPath $donorPath
    if ($donors.Count -ne 8) { $errors.Add("Donor map has $($donors.Count) rows; expected 8") }
    if (($donors.pwhl_team_id | Sort-Object -Unique).Count -ne 8) { $errors.Add('Donor PWHL team IDs must be unique') }
    if (($donors.donor_record | Sort-Object -Unique).Count -ne 8) { $errors.Add('Donor database records must be unique') }
}

if (Test-Path -LiteralPath $slotMapPath) {
    $slotMap = Import-Csv -LiteralPath $slotMapPath
    if ($slotMap.Count -ne 184) { $errors.Add("Player-slot map has $($slotMap.Count) rows; expected 184") }
    foreach ($field in @('bio_record', 'roster_record', 'player_index', 'game_id')) {
        if (($slotMap.$field | Sort-Object -Unique).Count -ne 184) { $errors.Add("Player-slot map field '$field' must be unique") }
    }
    $sourceKeys = @($players | ForEach-Object { "$($_.team_id)|$($_.player_name)|$($_.position_group)" } | Sort-Object)
    $mappedKeys = @($slotMap | ForEach-Object { "$($_.pwhl_team_id)|$($_.player_name)|$($_.position_group)" } | Sort-Object)
    if (Compare-Object $sourceKeys $mappedKeys) { $errors.Add('Player-slot map does not exactly match canonical players.csv') }
}
if (Test-Path -LiteralPath $localizationMapPath) {
    $localizationMap = Import-Csv -LiteralPath $localizationMapPath
    if ($localizationMap.Count -lt 56) { $errors.Add("Localization map has only $($localizationMap.Count) rows; expected at least seven per team") }
    if (($localizationMap.record | Sort-Object -Unique).Count -ne $localizationMap.Count) { $errors.Add('Localization records must be unique') }
    if (($localizationMap | Group-Object pwhl_team_id | Where-Object Count -lt 7)) { $errors.Add('Every active team must have at least seven localization entries') }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "Validated $($teams.Count) teams and $($players.Count) active-player rows."
Write-Host "Eight-team baseline: $($activeTeams.Count) teams x 23 players."
if (Test-Path -LiteralPath $slotMapPath) { Write-Host 'Validated 184 unique donor player, roster, bio, and ratings links.' }
