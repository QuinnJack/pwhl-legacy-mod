[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$PlayersCsv,
    [Parameter(Mandatory)] [string]$DonorMapCsv,
    [Parameter(Mandatory)] [string]$PlayerBiosCsv,
    [Parameter(Mandatory)] [string]$PlayerIndexCsv,
    [Parameter(Mandatory)] [string]$RosterSlotsCsv,
    [Parameter(Mandatory)] [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$players = Import-Csv -LiteralPath (Resolve-Path -LiteralPath $PlayersCsv).Path
$donors = Import-Csv -LiteralPath (Resolve-Path -LiteralPath $DonorMapCsv).Path
$bios = Import-Csv -LiteralPath (Resolve-Path -LiteralPath $PlayerBiosCsv).Path
$indexes = Import-Csv -LiteralPath (Resolve-Path -LiteralPath $PlayerIndexCsv).Path
$slots = Import-Csv -LiteralPath (Resolve-Path -LiteralPath $RosterSlotsCsv).Path
$indexByKey = @{}; foreach ($row in $indexes) { $indexByKey[$row.qEfv] = $row }
$bioById = @{}; foreach ($row in $bios) { $bioById[$row.zIBw] = $row }

$lineFields = @('WPGf','Imzy','aAvX','ctKP','pfiv','opNr','bSAb','PGhZ','PufE','Adsx','BvDt','OQOd','IkTY','CLEN','TbGw','Sxps','Jmcc','pOUV','lxRC','mxhB')
function Test-LineSlot($slot) {
    foreach ($field in $lineFields) { if ($slot.$field -eq '1') { return $true } }
    return $false
}
function Split-PlayerName([string]$name) {
    $parts = $name.Trim() -split '\s+'
    if ($parts.Count -lt 2) { return @($name, '') }
    return @(($parts[0..($parts.Count - 2)] -join ' '), $parts[-1])
}

$result = [Collections.Generic.List[object]]::new()
foreach ($donor in $donors) {
    $teamPlayers = @($players | Where-Object team_id -eq $donor.pwhl_team_id)
    if ($teamPlayers.Count -ne 23) { throw "$($donor.pwhl_team_id) must have exactly 23 source players." }
    $joined = foreach ($slot in ($slots | Where-Object BSXd -eq $donor.donor_team_id)) {
        $index = $indexByKey[$slot.TWSX]
        $bio = if ($index) { $bioById[$index.qFky] }
        if ($bio) {
            [pscustomobject]@{
                Slot = $slot
                Bio = $bio
                IsLine = Test-LineSlot $slot
                IsG1 = $slot.WPGf -eq '1'
                IsG2 = $slot.Imzy -eq '1'
            }
        }
    }
    $goalSlots = @($joined | Where-Object { $_.Bio.aljv -eq '4' } | Sort-Object @{e='IsG1';Descending=$true}, @{e='IsG2';Descending=$true}, @{e='IsLine';Descending=$true}, @{e={[int]$_.Slot.record}} | Select-Object -First 3)
    $defenseSlots = @($joined | Where-Object { $_.Bio.aljv -eq '3' -and $_.Bio.record -notin $goalSlots.Bio.record } | Sort-Object @{e='IsLine';Descending=$true}, @{e={[int]$_.Slot.record}} | Select-Object -First 7)
    $used = @($goalSlots.Bio.record + $defenseSlots.Bio.record)
    if ($defenseSlots.Count -lt 7) {
        $defenseSlots += @($joined | Where-Object { $_.Bio.record -notin $used -and -not $_.IsLine } | Sort-Object { [int]$_.Slot.record } | Select-Object -First (7 - $defenseSlots.Count))
    }
    $used = @($goalSlots.Bio.record + $defenseSlots.Bio.record)
    $forwardSlots = @($joined | Where-Object { $_.Bio.record -notin $used -and $_.Bio.aljv -in @('0','1','2') } | Sort-Object @{e='IsLine';Descending=$true}, @{e={[int]$_.Slot.record}} | Select-Object -First 13)
    if ($forwardSlots.Count -lt 13) {
        $used += @($forwardSlots.Bio.record)
        $forwardSlots += @($joined | Where-Object { $_.Bio.record -notin $used -and -not $_.IsLine } | Sort-Object { [int]$_.Slot.record } | Select-Object -First (13 - $forwardSlots.Count))
    }
    if ($goalSlots.Count -ne 3 -or $defenseSlots.Count -ne 7 -or $forwardSlots.Count -ne 13) {
        throw "$($donor.pwhl_team_id) donor cannot provide a safe 13F/7D/3G mapping."
    }

    $groups = [ordered]@{
        F = @($forwardSlots)
        D = @($defenseSlots)
        G = @($goalSlots)
    }
    foreach ($groupName in $groups.Keys) {
        $source = @($teamPlayers | Where-Object position_group -eq $groupName)
        $targets = $groups[$groupName]
        if ($source.Count -ne $targets.Count) { throw "$($donor.pwhl_team_id) $groupName source/target count mismatch." }
        for ($i = 0; $i -lt $source.Count; $i++) {
            $nameParts = Split-PlayerName $source[$i].player_name
            $target = $targets[$i]
            $result.Add([pscustomobject][ordered]@{
                pwhl_team_id = $donor.pwhl_team_id
                player_name = $source[$i].player_name
                first_name = $nameParts[0]
                last_name = $nameParts[1]
                position_group = $groupName
                position_code = if ($groupName -eq 'D') { 3 } elseif ($groupName -eq 'G') { 4 } else { [int]$target.Bio.aljv }
                donor_team_id = $donor.donor_team_id
                roster_record = $target.Slot.record
                player_index = $target.Slot.TWSX
                game_id = $target.Bio.zIBw
                bio_record = $target.Bio.record
                donor_player = "$($target.Bio.PedH) $($target.Bio.RMbQ)"
                donor_position_code = $target.Bio.aljv
                jersey = $target.Slot.tRVs
                line_assigned = $target.IsLine
            })
        }
    }
}

if ($result.Count -ne 184) { throw "Expected 184 mapped players; found $($result.Count)." }
$outputFull = [IO.Path]::GetFullPath($OutputPath)
$result | Export-Csv -LiteralPath $outputFull -NoTypeInformation -Encoding UTF8
Write-Host "Mapped $($result.Count) PWHL players to line-safe donor records in $outputFull"
