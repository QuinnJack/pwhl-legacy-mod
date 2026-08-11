# Research notes

## Confirmed game workflow

- NHL Legacy roster files use EA's TDB database format.
- NHLView NG officially supports NHL 09 through NHL Legacy Edition on PS3/Xbox 360, including teams, players, ratings, transactions, and lines.
- The recompiled PC build stores user saves under `Documents/nhllegacy`; its extracted install exposes `db/nhlng.db` and `fe/loc/nhl_eng_us.db`.
- NHL Modding Studio requires both the extracted `nhlng.db` and a roster save or extracted roster DB. Its shipped relationship definitions cover team links, player-team links, roster indices, ratings, and lines.
- Team naming is not purely a roster edit: localization strings must also be updated.
- Community guidance repeatedly recommends backups because record deletion/capacity changes can corrupt TDB files. The current 2025 TDB engine contains relevant fixes, so older database tools should not be used for writes.

## PWHL scope decision

The completed 2025-26 season has eight teams and stable opening-night rosters. As of August 2026, the official PWHL site also lists Detroit, Hamilton, Las Vegas, and San Jose. Those four markets are represented in `teams.csv`, but no speculative roster is created.

## Sources

- NHLView NG: https://www.artemkh.com/nhl/nhlviewng/
- TDBView: https://www.artemkh.com/nhl/tdbview/
- TDBAccess: https://www.artemkh.com/nhl/devtools/
- NHL Legacy recomp: https://github.com/puckhead73/nhl-legacy-recomp
- PWHL 2025-26 opening-night roster hub: https://www.thepwhl.com/en/2025-26-opening-night-rosters
- Official PWHL site/team list: https://www.thepwhl.com/

Individual official roster sources are recorded in `data/teams.csv`.

