# PWHL Legacy

An in-progress PWHL total-conversion mod for **NHL Legacy Edition**, initially targeting the recompiled PC build and retaining compatibility with the original PS3/Xbox 360 roster format where practical.

## Current milestone

The repository contains the first reproducible data layer:

- all eight 2025-26 opening-night PWHL teams and 184 active players;
- placeholders for the four official 2026-27 expansion markets;
- validation scripts and a safe local workspace initializer;
- an EA TDB schema exporter used to map `nhlng.db` and roster tables before mutation;
- research notes, tool inventory, implementation plan, and source links.

Game files, commercial assets, downloaded tools, and modified binary databases are deliberately excluded from Git. Contributors must provide their own legally obtained copy of NHL Legacy Edition.

## Quick start

From PowerShell in this repository:

```powershell
./scripts/Test-SourceData.ps1
./scripts/Initialize-Workspace.ps1 -GameRoot ../game -RosterPath <path-to-roster-save>
./scripts/Export-TdbSchema.ps1 `
  -DatabasePath ./work/baseline/nhlng.db `
  -TdbAccessDll ../_tools/TDBAccess/x64/tdbaccess.dll `
  -OutputPath ./reports/nhlng-schema.json
```

For an Xbox 360/recompiled roster container, add `-ContainerFormat Xbox360` when exporting its schema.

Open the working database and a roster save in **NHL Modding Studio**. Never edit the files under `../game` directly.

## Target scope

Version 0.1 targets the completed 2025-26 eight-team league because official rosters are stable and verifiable. The data model already includes Detroit, Hamilton, Las Vegas, and San Jose as 2026-27 expansion placeholders; their player rows will remain empty until official rosters are finalized.

## Repository layout

- `data/` — canonical source data, kept human-reviewable in CSV.
- `docs/` — research, field mapping, toolchain, and milestone plan.
- `scripts/` — validation, workspace setup, and TDB inspection.
- `reports/` — checked-in schema snapshots and generated audit summaries.
- `work/` — ignored local copies of game/roster databases.

## Legal

This is an unofficial fan project. PWHL, team names, and related marks belong to their respective owners. EA SPORTS and NHL Legacy Edition belong to their respective owners. No game binaries or extracted copyrighted assets are distributed here.
