[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$LocalizationCsv,
    [Parameter(Mandatory)] [string]$TeamsCsv,
    [Parameter(Mandatory)] [string]$DonorMapCsv,
    [Parameter(Mandatory)] [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$strings = Import-Csv -LiteralPath (Resolve-Path -LiteralPath $LocalizationCsv).Path
$teams = Import-Csv -LiteralPath (Resolve-Path -LiteralPath $TeamsCsv).Path | Group-Object team_id -AsHashTable -AsString
$donors = Import-Csv -LiteralPath (Resolve-Path -LiteralPath $DonorMapCsv).Path
$prefixes = @('NHLTEAMNAME_ABBR3','NHLTEAMNAME','NHLCITYNAME','TEAMLINE1','TEAMLINE2','TXT_NICKNAME','TXT_NICKNAME_ALT','X_XLA_TEAM','NICKLINE2')
$rows = [Collections.Generic.List[object]]::new()
foreach ($donor in $donors) {
    $team = $teams[$donor.pwhl_team_id][0]
    $matches = @($strings | Where-Object { $_.value -match "(?i)^($($prefixes -join '|'))_$([regex]::Escape($donor.localization_abbr))$" })
    foreach ($entry in $matches) {
        $prefix = ($entry.value -split '_')[0]
        $desired = switch -Regex ($entry.value) {
            '(?i)^NHLTEAMNAME_ABBR3_' { $team.abbreviation; break }
            '(?i)^X_XLA_TEAM_' { $team.abbreviation; break }
            '(?i)^NHLCITYNAME_' { $team.city; break }
            '(?i)^TEAMLINE1_' { $team.city; break }
            '(?i)^NHLTEAMNAME_' { "$($team.city) $($team.name)"; break }
            default { $team.name }
        }
        $rows.Add([pscustomobject][ordered]@{
            pwhl_team_id = $donor.pwhl_team_id
            localization_abbr = $donor.localization_abbr
            record = $entry.record
            hash = $entry.hash
            key = $entry.value
            old_value = $entry.description
            new_value = $desired
        })
    }
}
if (($rows | Group-Object pwhl_team_id | Where-Object Count -lt 7)) { throw 'Each PWHL donor must resolve at least seven localization entries.' }
$rows | Sort-Object pwhl_team_id, record | Export-Csv -LiteralPath ([IO.Path]::GetFullPath($OutputPath)) -NoTypeInformation -Encoding UTF8
Write-Host "Mapped $($rows.Count) localization entries."
