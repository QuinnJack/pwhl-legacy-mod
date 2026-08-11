# Implementation plan

## Phase 0 — safe foundation (in progress)

- Inventory the extracted recompiled game and community tools.
- Preserve checksums for pristine databases and work only on copies.
- Track structured source data and scripts in GitHub; exclude game/tool binaries.
- Export the `nhlng.db` and roster schemas to identify exact team, player, line, arena, localization, and art relationships.

Exit condition: source data validates, working DB copies are reproducible, and the base schemas are documented.

## Phase 1 — playable eight-team roster

- Select eight low-impact donor teams with compatible roster/line slots.
- Map all 184 active 2025-26 players into roster tables.
- Add dates, handedness, jersey numbers, nationality, height/weight, positions, and conservative ratings.
- Build valid forward, defense, power-play, penalty-kill, extra-attacker, and goalie lines.
- Rename teams in roster and localization databases.
- Round-trip save through NHL Modding Studio/NHLView NG and load in-game.

Exit condition: all eight teams can play exhibition games without crashes, duplicate IDs, invalid lines, or missing mandatory players.

## Phase 2 — identity and presentation

- Assign donor art IDs and document every collision.
- Replace primary/secondary logos, scorebug marks, uniforms, socks, goalie gear, ice, boards, menus, and loading art.
- Map arenas and crowd colors.
- Add safe commentary-name matches where existing audio permits; never ship proprietary extracted audio.

Exit condition: each team is visually distinct in menus and gameplay, with home/away uniform contrast verified.

## Phase 3 — league behavior

- Prototype an eight-team season structure using an existing league slot.
- Update schedules, playoff qualification, standings labels, trophies, and league strings where the executable/data model permits.
- Tune gameplay and physical attributes for a balanced PWHL scale.

Exit condition: a season can be started, saved, advanced, and completed.

## Phase 4 — 2026-27 expansion

- Populate Detroit, Hamilton, Las Vegas, and San Jose after official rosters are final.
- Test whether adding teams is stable; otherwise ship an alternate 12-team donor mapping.
- Update schedule/playoff structures and art packages.

## Phase 5 — packaging and QA

- Produce a patcher or file-overlay package that requires a user-owned game install.
- Add checksum gates so patches only apply to supported baselines.
- Maintain smoke-test and regression checklists for exhibition, season, save/load, shootout, and multiplayer.
- Publish releases without original game files, downloaded third-party tools, or unlicensed source assets.

