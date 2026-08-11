[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$teams = Import-Csv (Join-Path $root 'data/teams.csv')
$players = Import-Csv (Join-Path $root 'data/players.csv')
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

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "Validated $($teams.Count) teams and $($players.Count) active-player rows."
Write-Host "Eight-team baseline: $($activeTeams.Count) teams x 23 players."

