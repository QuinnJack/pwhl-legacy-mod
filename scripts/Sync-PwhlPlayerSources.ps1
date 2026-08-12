[CmdletBinding()]
param(
    [string]$PlayerSlotMap,
    [string]$PlayerBiosCsv,
    [string]$OutputPath,
    [int]$SeasonId = 8
)

$ErrorActionPreference = 'Stop'
if (-not $PlayerSlotMap) { $PlayerSlotMap = Join-Path $PSScriptRoot '..\data\player-slot-map.csv' }
if (-not $PlayerBiosCsv) { $PlayerBiosCsv = Join-Path $PSScriptRoot '..\work\installed-player-bios.csv' }
if (-not $OutputPath) { $OutputPath = Join-Path $PSScriptRoot '..\data\pwhl-player-sources.csv' }
$apiBase = 'https://lscluster.hockeytech.com/feed/index.php'
$apiKey = '446521baf8c38984'
$teamIds = [ordered]@{ BOS = 1; MIN = 2; MTL = 3; NY = 4; OTT = 5; SEA = 8; TOR = 6; VAN = 9 }
$aliases = @{
    'samisbell' = 'samanthaisbell'
    'jesskondas' = 'jessicakondas'
}

function ConvertTo-NameKey([string]$Value) {
    $decomposed = $Value.Normalize([Text.NormalizationForm]::FormD)
    $builder = [Text.StringBuilder]::new()
    foreach ($character in $decomposed.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($character) -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$builder.Append($character)
        }
    }
    return ([regex]::Replace($builder.ToString().ToLowerInvariant(), '[^a-z0-9]', ''))
}

function Get-PwhlJson([hashtable]$Parameters) {
    $parameters = [ordered]@{} + $Parameters
    $parameters.key = $apiKey
    $parameters.client_code = 'pwhl'
    $query = ($parameters.GetEnumerator() | ForEach-Object {
        '{0}={1}' -f [uri]::EscapeDataString([string]$_.Key), [uri]::EscapeDataString([string]$_.Value)
    }) -join '&'
    $temporaryFile = [IO.Path]::GetTempFileName()
    try {
        & curl.exe --fail --silent --show-error --location "$apiBase`?$query" --output $temporaryFile
        if ($LASTEXITCODE -ne 0) { throw "PWHL request failed for $($Parameters.view)." }
        return Get-Content -LiteralPath $temporaryFile -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    finally {
        Remove-Item -LiteralPath $temporaryFile -Force -ErrorAction SilentlyContinue
    }
}

$slots = Import-Csv -LiteralPath (Resolve-Path -LiteralPath $PlayerSlotMap).Path
$biosByRecord = @{}
if (Test-Path -LiteralPath $PlayerBiosCsv) {
    foreach ($bio in (Import-Csv -LiteralPath $PlayerBiosCsv)) { $biosByRecord[[string]$bio.record] = $bio }
}
$rosters = @{}
foreach ($teamCode in $teamIds.Keys) {
    $payload = Get-PwhlJson @{ feed = 'modulekit'; view = 'roster'; team_id = $teamIds[$teamCode]; season_id = $SeasonId }
    $rosters[$teamCode] = @($payload.SiteKit.Roster)
}
$allRosterPlayers = @($rosters.Values | ForEach-Object { $_ }) | Sort-Object player_id -Unique

$rows = foreach ($slot in $slots) {
    $requestedKey = ConvertTo-NameKey $slot.player_name
    $lookupKey = if ($aliases.ContainsKey($requestedKey)) { $aliases[$requestedKey] } else { $requestedKey }
    $match = @($allRosterPlayers | Where-Object { (ConvertTo-NameKey $_.name) -eq $lookupKey })
    $matchMethod = if ($requestedKey -eq $lookupKey) { 'league-roster-normalized-name' } else { 'curated-alias' }

    # Knight moved after the source roster was assembled, but her stable league player ID remains valid.
    if ($match.Count -eq 0 -and $requestedKey -eq 'hilaryknight') {
        $match = @([pscustomobject]@{
            player_id = '13'; name = 'Hilary Knight'; position = 'RW'; tp_jersey_number = '21'
            birthdate = '1989-07-12'; shoots = 'R'; height_hyphenated = '5-11'; hometown = 'Sun Valley, ID'
            player_image = 'https://assets.leaguestat.com/pwhl/240x240/13.jpg'
        })
        $matchMethod = 'stable-player-id-fallback'
    }
    if ($match.Count -ne 1) { throw "Expected one PWHL source match for '$($slot.player_name)' on $($slot.pwhl_team_id); found $($match.Count)." }

    $player = $match[0]
    $playerId = [int]$player.player_id
    $bio = $biosByRecord[[string]$slot.bio_record]
    [pscustomobject][ordered]@{
        pwhl_team_id = $slot.pwhl_team_id
        player_name = $slot.player_name
        position_group = $slot.position_group
        game_id = $slot.game_id
        bio_record = $slot.bio_record
        portrait_art_id = if ($bio) { $bio.rnOl } else { '' }
        has_portrait = if ($bio) { $bio.LcvS } else { '' }
        pwhl_player_id = $playerId
        official_name = $player.name
        official_position = $player.position
        official_jersey = $player.tp_jersey_number
        birthdate = $player.birthdate
        shoots = $player.shoots
        height = $player.height_hyphenated
        hometown = $player.hometown
        headshot_240_url = $player.player_image
        media_api_url = "$apiBase`?feed=modulekit&view=player&category=media&player_id=$playerId&key=$apiKey&client_code=pwhl"
        profile_api_url = "$apiBase`?feed=modulekit&view=player&category=profile&player_id=$playerId&key=$apiKey&client_code=pwhl"
        season_stats_api_url = "$apiBase`?feed=modulekit&view=player&category=seasonstats&player_id=$playerId&key=$apiKey&client_code=pwhl"
        match_method = $matchMethod
        portrait_status = 'Source mapped'
        portrait_qa = 'Not reviewed'
        attribution = 'Official statistics and media provided by the Professional Women''s Hockey League and HockeyTech.'
        notes = ''
    }
}

$outputFull = [IO.Path]::GetFullPath($OutputPath)
$rows | Sort-Object pwhl_team_id, player_name | Export-Csv -LiteralPath $outputFull -NoTypeInformation -Encoding UTF8
Write-Host "Mapped $($rows.Count) player records to official PWHL IDs in $outputFull"
