# PWHL Asset and Ratings Pipeline

This is the working plan for portraits, ratings, and uniforms after the eight PWHL teams have been installed into the AHL slots. It is designed for bulk work, reviewable source data, and repeatable game builds.

## Recommended collection format

Use `outputs/pwhl-assets-20260811/PWHL-Asset-Intake.xlsx` as the human-facing intake file. It already contains every player, official PWHL player ID, donor portrait slot, and every home/away uniform file target.

Do not collect 184 separate headshots manually. `scripts/Sync-PwhlPlayerSources.ps1` maps the source roster to the league feed and records the official headshot, media, profile, and statistics endpoints. Manual collection should focus on:

1. Scouting judgments that cannot be inferred from public statistics: skating, physicality, defensive reads, shot quality, consistency, and potential.
2. High-resolution uniform references: front, back, and side views; crest and shoulder patches; exact colours; number/name font references.
3. Exceptions flagged by portrait QA, such as a poor crop, old team jersey, or missing high-resolution media.

Keep source URLs and notes in the workbook. Never paste over an imported value without changing its source type to `Manual override` and explaining why.

## Toolchain used by established Legacy mods

### Preferred current tools

- **NHL Modding Studio 0.1.0-beta.3**: roster and asset editor. The installed build exposes direct portrait-from-PNG commands, portrait export, historical matching, player editing, and EA rating calculations. This is the preferred portrait installer because it handles the paired front-end portrait assets.
- **Heck Texture Editor v1.1**: opens Recompiled Edition `.rx2`, PS3 `.rpsgl`, and BIG archives; imports/replaces PNG or DDS; preserves the platform texture container; and provides jersey/pant/sock previews. This is the preferred uniform texture tool.
- **NHLView NG**: useful for checking player portrait IDs and ratings in the roster database.
- **EA BIG TOOL 1.3**: retained for older/manual archive rebuild workflows where file order and compression must match the original.
- **TDBAccess**: safe for scripted numeric roster fields after the display-to-storage rating conversion is verified. It is not used to rewrite localization text.

### Older community workflow found in the Discord export and public mod threads

Legacy mods commonly used QuickBMS/Fight Night scripts, NHL Legacy Texture Patcher, Noesis, Blender 2.79, EA BIG Tool, BIG File Extractor, and NHLView NG. Those tools still help with unusual archives and models, but the local NHL Modding Studio and Heck Texture Editor remove much of the fragile manual work.

The Discord tutorials repeatedly warn that BIG member order, compression, texture dimensions, mipmaps, and platform format must be preserved. For jerseys, the community naming rule is `texlib_STYLE_TEAMARTID_VARIANT`; style `1` is the Reebok Edge-era model used by the selected donors. The database/equipment variant can be one greater than the filename variant, so it must be checked in game instead of guessed.

## Portrait pipeline

### Source and preparation

1. Run `scripts/Sync-PwhlPlayerSources.ps1` to refresh the 184-player source map.
2. Prefer the highest-resolution `primary` image returned by the player's media endpoint. Fall back to the official 240×240 headshot URL.
3. Create a transparent, square PNG with a consistent crop: head centered, shoulders visible, no text, and enough space above the hair/helmet.
4. Produce one contact sheet per team and mark `Crop QA` in the workbook. This is faster and more reliable than reviewing images one at a time.

### Installation

1. Back up both portrait trees before the batch: `fe/ion/artassets/playerheads/` and `fe/ion/artassets/playerheadssmall/`.
2. Use the player's existing `portrait_art_id` as the destination slot. The current roster map has 184 unique donor slots, so no new portrait-number allocation is needed.
3. Import the PNG with NHL Modding Studio's portrait replacement function. It should update the full and small front-end assets as a pair.
4. Set the roster `hasportrait` flag for the 13 mapped slots that currently contain `0`.
5. Verify one team in menus, gameplay presentation, and roster screens before batching the remaining seven.

Do not rename portrait files to the player's bio/game ID. NHL Legacy links portraits through the roster portrait-art field; a portrait slot can be unrelated to the player's game ID.

## Ratings pipeline

### Source hierarchy

1. **EA official**: copy a player's NHL 26 PWHL attributes when an individual EA ratings page exists. These attributes map most directly to Legacy and should be treated as the anchor.
2. **Calibrated formula**: for players without a full EA page, use official PWHL season/career statistics, role, usage, position, age, and goalie results to create a first pass calibrated to the EA PWHL distribution.
3. **Manual scouting override**: use video/scouting evidence for attributes box scores do not measure. Record the rationale.

Do not infer skating, checking, defensive awareness, hand-eye, or discipline directly from goals and points. Statistics can guide overall tier, shooting/passing, and goalie performance, but they are not a complete scouting model.

`scripts/Sync-EaPwhlRatings.mjs` extracts the official machine-readable ratings payload and preserves an individual source URL for every row. The current workbook automatically pre-fills all 50 exact roster matches; the remaining 134 players stay blank for calibrated/formula and scouting work.

### Legacy fields already identified

Skater fields include overall, slap/wrist power and accuracy, faceoffs, offensive/defensive awareness, strength, discipline, stick checking, balance, puck control, speed, acceleration, poise, deking, endurance, potential, passing, body checking, aggression, agility, durability, hand-eye, and shot blocking.

Goalie fields include overall, glove/stick high and low, five-hole, consistency, breakaway, rebound control, paddle down, poke check, speed, poise, positioning, endurance, potential, vision, shot recovery, passing, aggression, agility, and durability.

The database schema stores most attributes in six bits. The apparent conversion is `stored value = displayed rating - 36`, but this must be confirmed against known NHLView NG values before the first bulk write. The intake workbook intentionally uses familiar displayed ratings from 36–99.

### Quality rules

- Keep `Overall` formula-driven until the attribute set is approved; do not tune individual attributes merely to force a target overall.
- Record `EA official`, `Calibrated formula`, or `Manual override` on every row.
- Review team distributions and position groups, not only stars.
- Pilot one team, test in gameplay, then freeze the scale before rating the rest of the league.

## Uniform pipeline

### What to collect per team

For both home and away sets, supply a clear full-front photo, a back photo showing name/number placement, a side or three-quarter photo, crest and shoulder-patch artwork, official/product URLs and colours, font close-ups, and any sponsor or championship patches that should be included.

Official shop photography is usually the best base because lighting and garment views are consistent. Game photos are best for fit, sleeve placement, helmets, pants, socks, and on-ice colour checks.

### Texture construction

Build one layered master file per team, then derive Home and Away. Preserve editable layers for fabric colour, striping, crest, shoulder patches, nameplate, numbers, stitching, and sponsors.

The jersey texture set uses `cm` for colour/diffuse, `nm` for normal, `sm` for specular, `am` for ambient where present, and `rm` for refraction where present. The normal-map alpha channel matters: a bad or missing alpha can make the whole jersey look unnaturally glossy.

Use the exact donor paths in `data/uniform-assets.csv`. Import replacements through Heck Texture Editor, keep the original dimensions/compression/mipmap structure, and inspect the full kit in its 3D viewer before launching the game. Front-end jersey thumbnails live separately; approve gameplay uniforms first, then replace thumbnails.

## Rollout order

1. **Boston pilot**: home/away portraits, ratings, jersey/pants/socks, and menu thumbnail.
2. Validate donor-slot linkage, rating scale, lighting, kit fit, and menu display.
3. Freeze the templates and automated transforms.
4. Batch the remaining seven teams.
5. Run a league-wide contact-sheet review, rating-distribution review, and in-game smoke test.

## Source and rights notes

- PWHL statistics/media feed: credit the Professional Women's Hockey League and HockeyTech.
- EA ratings: store the page URL and use attributes as factual reference data; do not redistribute EA site artwork.
- Team names, logos, uniforms, and league photography remain their owners' intellectual property. Keep the project clearly noncommercial and distribute transformed mod assets, not scraped source-photo archives.

## Key research references

- PWHL data reference: https://github.com/IsabelleLefebvre97/PWHL-Data-Reference
- EA NHL 26 PWHL ratings: https://www.ea.com/games/nhl/ratings/conferences-ratings/pwhl/4
- Official PWHL jersey shop: https://shop.thepwhl.com/collections/home-jerseys
- Community texture thread: https://forums.operationsports.com/forums/ea-sports-nhl-legacy/926860-xbox-360-legacy-texture-modding.html
