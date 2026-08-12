[CmdletBinding()]
param(
    [string]$PlayerSourcesCsv,
    [string]$UniformAssetsCsv,
    [string]$EaRatingsCsv,
    [string]$GameRoot
)

$ErrorActionPreference = 'Stop'
if (-not $PlayerSourcesCsv) { $PlayerSourcesCsv = Join-Path $PSScriptRoot '..\data\pwhl-player-sources.csv' }
if (-not $UniformAssetsCsv) { $UniformAssetsCsv = Join-Path $PSScriptRoot '..\data\uniform-assets.csv' }
if (-not $EaRatingsCsv) { $EaRatingsCsv = Join-Path $PSScriptRoot '..\data\ea-nhl26-pwhl-ratings.csv' }
if (-not $GameRoot) { $GameRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }

$players = @(Import-Csv -LiteralPath (Resolve-Path -LiteralPath $PlayerSourcesCsv).Path)
$uniforms = @(Import-Csv -LiteralPath (Resolve-Path -LiteralPath $UniformAssetsCsv).Path)
$eaRatings = @(Import-Csv -LiteralPath (Resolve-Path -LiteralPath $EaRatingsCsv).Path)
$errors = [Collections.Generic.List[string]]::new()
$activeTeams = @('BOS','MIN','MTL','NY','OTT','SEA','TOR','VAN')

if ($players.Count -ne 184) { $errors.Add("Expected 184 player source rows; found $($players.Count).") }
if (($players.pwhl_player_id | Sort-Object -Unique).Count -ne 184) { $errors.Add('PWHL player IDs must be unique.') }
if (($players.portrait_art_id | Sort-Object -Unique).Count -ne 184) { $errors.Add('Portrait art IDs must be unique.') }
if (@($players | Where-Object { -not $_.headshot_240_url.StartsWith('https://') }).Count) { $errors.Add('Every player must have an HTTPS headshot source.') }
if (@($players | Where-Object { -not $_.media_api_url.StartsWith('https://') }).Count) { $errors.Add('Every player must have an HTTPS media endpoint.') }
if (@($players | Where-Object has_portrait -eq '0').Count -ne 13) { $errors.Add('Expected exactly 13 donor slots requiring hasportrait activation.') }
if ($eaRatings.Count -ne 50) { $errors.Add("Expected 50 EA NHL 26 PWHL rating rows; found $($eaRatings.Count).") }
if (($eaRatings.ea_player_id | Sort-Object -Unique).Count -ne $eaRatings.Count) { $errors.Add('EA player IDs must be unique.') }
if (@($eaRatings | Where-Object { -not $_.source_url.StartsWith('https://www.ea.com/') }).Count) { $errors.Add('Every EA rating row must retain its official source URL.') }
foreach ($team in $activeTeams) {
    if (@($players | Where-Object pwhl_team_id -eq $team).Count -ne 23) { $errors.Add("$team must contain 23 mapped players.") }
}

if ($uniforms.Count -ne 16) { $errors.Add("Expected 16 uniform sets; found $($uniforms.Count).") }
foreach ($team in $activeTeams) {
    $sets = @($uniforms | Where-Object team_id -eq $team)
    $setNames = @($sets | ForEach-Object { $_.PSObject.Properties['set'].Value } | Sort-Object -Unique)
    if ($sets.Count -ne 2 -or ($setNames -join ',') -ne 'Away,Home') { $errors.Add("$team must have one Home and one Away uniform row.") }
}

$targetCount = 0
foreach ($uniform in $uniforms) {
    foreach ($field in @('jersey_path','pant_path','sock_path')) {
        $targetCount++
        $target = Join-Path $GameRoot $uniform.$field
        if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { $errors.Add("Missing target file for $($uniform.team_id) $($uniform.set): $target") }
    }
}

if ($errors.Count) {
    $errors | ForEach-Object { Write-Error $_ }
    throw "Asset data validation failed with $($errors.Count) error(s)."
}

Write-Host "Asset data validation passed: $($players.Count) players, $($eaRatings.Count) official EA rating rows, $($uniforms.Count) uniform sets, $targetCount existing texture targets."
