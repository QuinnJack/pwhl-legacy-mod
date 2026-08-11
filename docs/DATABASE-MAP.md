# Database map

The base `nhlng.db` contains 134 tables. The initial playable roster touches a much smaller, linked subset. Names below come from the shipped `nhlng-meta.xml`; short names are the physical four-character TDB identifiers.

| Logical table | Short | Base rows | Role in the mod |
| --- | --- | ---: | --- |
| `exhibitionteams` | `ttOk` | 252 | Team identity, colors, art/audio IDs, arena, league/division links, jersey styles |
| `exhibitionteamstrategies` | `oYeE` | 252 | Team tactics; clone from each donor unless explicitly tuned |
| `exhibitionarena` | `OEtS` | 187 | Arena name, capacity, art/audio, horns, ice/line settings |
| `exhibitionplayerbiotable` | `cPbu` | 5,632 | Player names, DOB, position, handedness, size, nationality, portrait/head/audio IDs, team and contract data |
| `exhibitionplayers` | `caBZ` | 6,087 | Player ID to bio/ratings table indirection |
| `exhibitionrostertable` | `ulGe` | 5,532 | Team assignment, jersey number, captaincy, lineup and special-team slots |
| `exhibitionskaterai` | `yvSd` | 5,066 | Skater attributes, potential, style, traits and growth |
| `exhibitiongoalieai` | `yuHm` | 566 | Goalie attributes, potential, style, traits and growth |
| `exhibitionskaterequipment` | `ajmx` | 5,066 | Skater equipment and jersey presentation |
| `exhibitiongoalieequipment` | `lVMf` | 566 | Goalie equipment, colors, mask and stick configuration |
| `stockteamjerseys` | `wgjx` | 703 | Team/art IDs, home/away variants, localization and light/dark behavior |
| `stockteamcolorstable` | `sozv` | 205 | Reusable team color palette |
| `stockteamequipmenttable` | `vbHh` | 6,000 | Team equipment color zones |
| `playernames` | `ewGB` | 4,116 | Commentary name bank/audio matching |

## Write strategy

1. Choose donor teams and donor players first; preserve record counts for the initial build.
2. Clone related donor records across all linked tables, then change stable IDs and human data.
3. Populate complete line slots before an in-game load. Missing `g1/g2`, even-strength lines, or special teams can crash or produce invalid rosters.
4. Keep art/audio IDs on known-valid donors until replacement assets exist.
5. Update both roster/team records and the localization database for visible names.
6. Save to a new candidate DB, reopen it in a second editor, and compare table counts/checksums before testing in-game.

The tracked `reports/nhlng-schema.json` is the machine-readable source of table capacities, field widths, types, and names.

