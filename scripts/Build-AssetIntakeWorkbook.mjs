import fs from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";

const artifactToolPath = process.env.CODEX_ARTIFACT_TOOL_PATH || path.join(process.env.USERPROFILE || "", ".cache", "codex-runtimes", "codex-primary-runtime", "dependencies", "node", "node_modules", "@oai", "artifact-tool", "dist", "artifact_tool.mjs");
const { Workbook, SpreadsheetFile } = await import(pathToFileURL(artifactToolPath).href);

const repoRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname.replace(/^\/(.:)/, "$1")), "..");
const outputDir = process.argv[2] ? path.resolve(process.argv[2]) : path.join(repoRoot, "outputs", "pwhl-assets-20260811");

function parseCsv(text) {
  const rows = [];
  let row = [], field = "", quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"' && text[i + 1] === '"') { field += '"'; i++; }
      else if (c === '"') quoted = false;
      else field += c;
    } else if (c === '"') quoted = true;
    else if (c === ',') { row.push(field); field = ""; }
    else if (c === '\n') { row.push(field.replace(/\r$/, "")); rows.push(row); row = []; field = ""; }
    else field += c;
  }
  if (field.length || row.length) { row.push(field.replace(/\r$/, "")); rows.push(row); }
  const headers = rows.shift();
  return rows.filter(r => r.some(v => v !== "")).map(r => Object.fromEntries(headers.map((h, i) => [h.replace(/^\uFEFF/, ""), r[i] ?? ""])));
}

async function readCsv(name) {
  return parseCsv(await fs.readFile(path.join(repoRoot, "data", name), "utf8"));
}

function colName(n) {
  let s = "";
  while (n > 0) { n--; s = String.fromCharCode(65 + n % 26) + s; n = Math.floor(n / 26); }
  return s;
}

const playerSources = await readCsv("pwhl-player-sources.csv");
const uniforms = await readCsv("uniform-assets.csv");
const eaRatings = await readCsv("ea-nhl26-pwhl-ratings.csv");
const teams = Object.fromEntries((await readCsv("teams.csv")).map(t => [t.team_id, `${t.city} ${t.name}`]));
const nameKey = value => value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/[^a-z0-9]/g, "");
const eaByName = new Map(eaRatings.map(r => [nameKey(r.player_name), r]));
const numberOrBlank = value => value === "" || value == null ? "" : Number(value);

const wb = Workbook.create();
const start = wb.worksheets.add("Start Here");
const playersSheet = wb.worksheets.add("Players");
const portraitsSheet = wb.worksheets.add("Portraits");
const skaterSheet = wb.worksheets.add("Skater Ratings");
const goalieSheet = wb.worksheets.add("Goalie Ratings");
const uniformSheet = wb.worksheets.add("Uniforms");
const sourcesSheet = wb.worksheets.add("Sources");

const navy = "#14213D", purple = "#5B2A86", ice = "#EAF4FA", pale = "#F5F7FA", gold = "#F4B942";
const headerFormat = { fill: navy, font: { bold: true, color: "#FFFFFF" }, wrapText: true, verticalAlignment: "center", borders: { preset: "all", style: "thin", color: "#C9D2DC" } };
const dataFormat = { verticalAlignment: "top", wrapText: false, borders: { preset: "all", style: "thin", color: "#E1E6EB" } };

function setDataSheet(sheet, headers, rows, widths = {}) {
  sheet.showGridLines = false;
  sheet.freezePanes.freezeRows(1);
  sheet.freezePanes.freezeColumns(2);
  const endCol = colName(headers.length);
  sheet.getRange(`A1:${endCol}1`).values = [headers];
  sheet.getRange(`A1:${endCol}1`).format = headerFormat;
  sheet.getRange(`A1:${endCol}1`).format.rowHeight = 34;
  if (rows.length) {
    sheet.getRange(`A2:${endCol}${rows.length + 1}`).values = rows;
    sheet.getRange(`A2:${endCol}${rows.length + 1}`).format = dataFormat;
  }
  headers.forEach((h, i) => {
    const c = colName(i + 1);
    sheet.getRange(`${c}:${c}`).format.columnWidth = widths[h] ?? Math.min(28, Math.max(11, h.length + 2));
  });
  sheet.getRange(`A1:${endCol}${rows.length + 1}`).format.font = { name: "Aptos", size: 10 };
  sheet.getRange(`A1:${endCol}1`).format.font = { name: "Aptos Display", size: 10, bold: true, color: "#FFFFFF" };
}

const playerHeaders = ["Team", "Player", "Position", "Game ID", "Bio record", "Portrait art ID", "Has portrait", "PWHL player ID", "Official position", "Jersey", "Birthdate", "Shoots", "Height", "Hometown", "Donor/source match"];
const playerRows = playerSources.map(p => [p.pwhl_team_id, p.player_name, p.position_group, Number(p.game_id), Number(p.bio_record), Number(p.portrait_art_id), Number(p.has_portrait), Number(p.pwhl_player_id), p.official_position, p.official_jersey, p.birthdate, p.shoots, p.height, p.hometown, p.match_method]);
setDataSheet(playersSheet, playerHeaders, playerRows, { Player: 24, Hometown: 24, "Donor/source match": 27 });
playersSheet.getRange(`D2:H${playerRows.length + 1}`).format.numberFormat = "0";

const portraitHeaders = ["Team", "Player", "PWHL player ID", "Portrait art ID", "Existing flag", "Official 240px headshot", "High-res media endpoint", "Status", "Crop QA", "Prepared PNG", "Notes"];
const portraitRows = playerSources.map(p => [p.pwhl_team_id, p.player_name, Number(p.pwhl_player_id), Number(p.portrait_art_id), Number(p.has_portrait), p.headshot_240_url, p.media_api_url, p.portrait_status, p.portrait_qa, "", p.notes]);
setDataSheet(portraitsSheet, portraitHeaders, portraitRows, { Player: 24, "Official 240px headshot": 42, "High-res media endpoint": 52, "Prepared PNG": 32, Notes: 30 });
portraitsSheet.getRange(`H2:H${portraitRows.length + 1}`).dataValidation = { rule: { type: "list", values: ["Source mapped", "Downloaded", "Prepared", "Imported", "Approved", "Blocked"] } };
portraitsSheet.getRange(`I2:I${portraitRows.length + 1}`).dataValidation = { rule: { type: "list", values: ["Not reviewed", "Needs work", "Approved"] } };
portraitsSheet.getRange(`H2:K${portraitRows.length + 1}`).format.fill = "#FFF9E8";

const skaterAttrs = ["Overall", "Slap shot power", "Wrist shot power", "Slap accuracy", "Wrist accuracy", "Faceoffs", "Offensive awareness", "Defensive awareness", "Strength", "Discipline", "Stick checking", "Balance", "Puck control", "Speed", "Acceleration", "Poise", "Deking", "Endurance", "Potential", "Passing", "Body checking", "Aggression", "Agility", "Durability", "Hand-eye", "Shot blocking"];
const skaterHeaders = ["Team", "Player", "Position", "Source type", "Source URL", ...skaterAttrs, "Review status", "Scout/rationale notes"];
const skaterRatingFields = ["overall", "slapshot_power", "wristshot_power", "slapshot_accuracy", "wristshot_accuracy", "faceoffs", "offensive_awareness", "defensive_awareness", "strength", "discipline", "stick_checking", "balance", "puck_control", "speed", "acceleration", "poise", "deking", "endurance", null, "passing", "body_checking", "aggression", "agility", "durability", "hand_eye", "shot_blocking"];
const skaterRows = playerSources.filter(p => p.position_group !== "G").map(p => {
  const ea = eaByName.get(nameKey(p.player_name));
  return [p.pwhl_team_id, p.player_name, p.position_group, ea ? "EA official" : "", ea?.source_url ?? "", ...skaterRatingFields.map(f => ea && f ? numberOrBlank(ea[f]) : ""), ea ? "Draft" : "Not started", ea ? "Imported from EA NHL 26; review Legacy gameplay scale before approval." : ""];
});
setDataSheet(skaterSheet, skaterHeaders, skaterRows, { Player: 24, "Source type": 21, "Source URL": 42, "Review status": 17, "Scout/rationale notes": 38 });
const skaterRatingStart = 6, skaterRatingEnd = skaterRatingStart + skaterAttrs.length - 1;
skaterSheet.getRange(`${colName(skaterRatingStart)}2:${colName(skaterRatingEnd)}${skaterRows.length + 1}`).dataValidation = { rule: { type: "whole", operator: "between", formula1: 36, formula2: 99 } };
skaterSheet.getRange(`D2:D${skaterRows.length + 1}`).dataValidation = { rule: { type: "list", values: ["EA official", "Calibrated formula", "Manual override"] } };
skaterSheet.getRange(`${colName(skaterRatingEnd + 1)}2:${colName(skaterRatingEnd + 1)}${skaterRows.length + 1}`).dataValidation = { rule: { type: "list", values: ["Not started", "Draft", "Needs review", "Approved"] } };
skaterSheet.getRange(`D2:${colName(skaterRatingEnd)}${skaterRows.length + 1}`).format.fill = ice;

const goalieAttrs = ["Overall", "Glove high", "Glove low", "Stick high", "Stick low", "Five-hole", "Consistency", "Breakaway", "Rebound control", "Paddle down", "Poke check", "Speed", "Poise", "Positioning", "Endurance", "Potential", "Vision", "Shot recovery", "Passing", "Aggression", "Agility", "Durability"];
const goalieHeaders = ["Team", "Player", "Source type", "Source URL", ...goalieAttrs, "Review status", "Scout/rationale notes"];
const goalieRatingFields = ["overall", "glove_high", "glove_low", "stick_high", "stick_low", "five_hole", null, "breakaway", "rebound_control", null, "poke_check", "speed", "poise", "positioning", "endurance", null, "vision", "shot_recovery", "passing", "goalie_aggression", "agility", "durability"];
const goalieRows = playerSources.filter(p => p.position_group === "G").map(p => {
  const ea = eaByName.get(nameKey(p.player_name));
  return [p.pwhl_team_id, p.player_name, ea ? "EA official" : "", ea?.source_url ?? "", ...goalieRatingFields.map(f => ea && f ? numberOrBlank(ea[f]) : ""), ea ? "Draft" : "Not started", ea ? "Imported from EA NHL 26; consistency, paddle-down, and potential still require review." : ""];
});
setDataSheet(goalieSheet, goalieHeaders, goalieRows, { Player: 24, "Source type": 21, "Source URL": 42, "Review status": 17, "Scout/rationale notes": 38 });
const goalieRatingStart = 5, goalieRatingEnd = goalieRatingStart + goalieAttrs.length - 1;
goalieSheet.getRange(`${colName(goalieRatingStart)}2:${colName(goalieRatingEnd)}${goalieRows.length + 1}`).dataValidation = { rule: { type: "whole", operator: "between", formula1: 36, formula2: 99 } };
goalieSheet.getRange(`C2:C${goalieRows.length + 1}`).dataValidation = { rule: { type: "list", values: ["EA official", "Calibrated formula", "Manual override"] } };
goalieSheet.getRange(`${colName(goalieRatingEnd + 1)}2:${colName(goalieRatingEnd + 1)}${goalieRows.length + 1}`).dataValidation = { rule: { type: "list", values: ["Not started", "Draft", "Needs review", "Approved"] } };
goalieSheet.getRange(`C2:${colName(goalieRatingEnd)}${goalieRows.length + 1}`).format.fill = ice;

const uniformHeaders = ["Team", "Team name", "Set", "Donor team", "Art ID", "Style", "File variant", "Jersey path", "Pant path", "Sock path", "Front reference URL", "Back reference URL", "Side reference URL", "Crest asset", "Shoulder patch asset", "Number font reference", "Name font reference", "Primary hex", "Secondary hex", "Accent hex", "Status", "QA status", "Notes"];
const uniformRows = uniforms.map(u => [u.team_id, u.team_name, u.set, u.donor_name, Number(u.team_art_id), Number(u.style), Number(u.variant), u.jersey_path, u.pant_path, u.sock_path, u.front_reference_url, u.back_reference_url, u.side_reference_url, u.crest_asset, u.shoulder_patch_asset, u.number_font_reference, u.name_font_reference, u.primary_hex, u.secondary_hex, u.accent_hex, u.status, u.qa_status, u.notes]);
setDataSheet(uniformSheet, uniformHeaders, uniformRows, { "Team name": 24, "Donor team": 25, "Jersey path": 47, "Pant path": 47, "Sock path": 47, "Front reference URL": 42, "Back reference URL": 42, "Side reference URL": 42, "Crest asset": 28, "Shoulder patch asset": 28, "Number font reference": 28, "Name font reference": 28, Notes: 34 });
uniformSheet.getRange(`K2:W${uniformRows.length + 1}`).format.fill = "#FFF9E8";
uniformSheet.getRange(`U2:U${uniformRows.length + 1}`).dataValidation = { rule: { type: "list", values: ["References needed", "Ready to build", "Texture draft", "In-game test", "Approved", "Blocked"] } };
uniformSheet.getRange(`V2:V${uniformRows.length + 1}`).dataValidation = { rule: { type: "list", values: ["Not reviewed", "Needs work", "Approved"] } };

const sourceHeaders = ["Source", "Use", "URL", "Provenance / caution"];
const sourceRows = [
  ["Official PWHL/HockeyTech feed", "Rosters, player IDs, profiles, statistics, headshot/media links", "https://github.com/IsabelleLefebvre97/PWHL-Data-Reference", "Credit the PWHL and HockeyTech; media remains property of its owner."],
  ["EA NHL 26 PWHL ratings", "Primary ratings anchor and individual full-attribute pages", "https://www.ea.com/games/nhl/ratings/conferences-ratings/pwhl/4", "Record individual page URLs; do not redistribute EA artwork."],
  ["Official PWHL home jerseys", "Consistent front/product reference photography", "https://shop.thepwhl.com/collections/home-jerseys", "Supplement with on-ice back/side photos."],
  ["PWHL team identities", "Official names, marks, colours, and launch references", "https://www.thepwhl.com/en/news/2024/september/09/new-names-new-logos-new-looks-re-introducing-the-inaugural-pwhl-six", "Marks and uniforms remain their owners' intellectual property."],
  ["Legacy texture-modding community", "Container formats, filenames, mipmaps, jersey texture maps", "https://forums.operationsports.com/forums/ea-sports-nhl-legacy/926860-xbox-360-legacy-texture-modding.html", "Cross-checked against the local Discord export and installed tools."],
  ["Local Discord export", "Community tutorials, templates, tool links, naming rules, and failure modes", path.join(path.dirname(repoRoot), "discord textbackup"), "Local research input; not distributed in this repository."]
];
setDataSheet(sourcesSheet, sourceHeaders, sourceRows, { Source: 30, Use: 48, URL: 78, "Provenance / caution": 62 });

start.showGridLines = false;
start.getRange("A1:H2").merge();
start.getRange("A1:H2").values = [["PWHL Legacy — Pictures, Ratings & Jerseys Intake"]];
start.getRange("A1:H2").format = { fill: purple, font: { name: "Aptos Display", size: 22, bold: true, color: "#FFFFFF" }, verticalAlignment: "center" };
start.getRange("A4:H4").merge();
start.getRange("A4:H4").values = [["Fill yellow/blue cells only. Keep every source URL and explain manual rating overrides."]];
start.getRange("A4:H4").format = { fill: gold, font: { bold: true, color: "#14213D" }, wrapText: true };
start.getRange("A6:B12").values = [["Progress", "Count"], ["Players mapped", ""], ["Portrait sources mapped", ""], ["Portraits approved", ""], ["EA official rating rows", ""], ["Skater ratings approved", ""], ["Goalie ratings approved", ""]];
start.getRange("A6:B6").format = headerFormat;
start.getRange("A7:A12").format = { fill: pale, font: { bold: true }, borders: { preset: "all", style: "thin", color: "#D8DEE6" } };
start.getRange("B7:B12").formulas = [[`=COUNTA(Players!B2:B${playerRows.length + 1})`], [`=COUNTIF(Portraits!H2:H${portraitRows.length + 1},"Source mapped")`], [`=COUNTIF(Portraits!I2:I${portraitRows.length + 1},"Approved")`], [`=COUNTIF('Skater Ratings'!D2:D${skaterRows.length + 1},"EA official")+COUNTIF('Goalie Ratings'!C2:C${goalieRows.length + 1},"EA official")`], [`=COUNTIF('Skater Ratings'!${colName(skaterRatingEnd + 1)}2:${colName(skaterRatingEnd + 1)}${skaterRows.length + 1},"Approved")`], [`=COUNTIF('Goalie Ratings'!${colName(goalieRatingEnd + 1)}2:${colName(goalieRatingEnd + 1)}${goalieRows.length + 1},"Approved")`]];
start.getRange("B7:B12").format = { fill: "#FFFFFF", font: { bold: true, color: purple }, numberFormat: "0", borders: { preset: "all", style: "thin", color: "#D8DEE6" } };
start.getRange("D6:H6").merge(); start.getRange("D6:H6").values = [["Best bulk workflow"]]; start.getRange("D6:H6").format = headerFormat;
start.getRange("D7:H13").merge();
start.getRange("D7:H13").values = [["1. Portraits: refresh official IDs → download high-res primary media → consistent transparent crop → team contact-sheet QA → Modding Studio batch import.\n\n2. Ratings: EA individual page where available → calibrated PWHL-stat first pass → manual scouting only for unmeasured traits → approve one team before league batch.\n\n3. Jerseys: collect front/back/side + crest/patch/font references → build Boston home/away pilot → Heck Texture Editor 3D preview → in-game lighting/fit test → reuse the approved layered template."]];
start.getRange("D7:H13").format = { fill: ice, wrapText: true, verticalAlignment: "top", borders: { preset: "all", style: "thin", color: "#B9D2E3" }, font: { size: 11 } };
start.getRange("A14:H14").merge(); start.getRange("A14:H14").values = [["Rating values are displayed 36–99. The suspected six-bit database conversion (display − 36) must be verified before bulk writing."]];
start.getRange("A14:H14").format = { fill: "#FDECEC", font: { color: "#9B1C1C", bold: true }, wrapText: true };
start.getRange("A16:H16").merge(); start.getRange("A16:H16").values = [["Attribution: Official statistics and media provided by the Professional Women's Hockey League and HockeyTech."]];
start.getRange("A16:H16").format = { font: { italic: true, color: "#4B5563" }, wrapText: true };
start.getRange("A:A").format.columnWidth = 29; start.getRange("B:B").format.columnWidth = 14;
for (const c of ["C","D","E","F","G","H"]) start.getRange(`${c}:${c}`).format.columnWidth = 18;
start.getRange("4:4").format.rowHeight = 30; start.getRange("7:13").format.rowHeight = 29; start.getRange("14:14").format.rowHeight = 32;

await fs.mkdir(outputDir, { recursive: true });
const out = await SpreadsheetFile.exportXlsx(wb);
const outputPath = path.join(outputDir, "PWHL-Asset-Intake.xlsx");
await out.save(outputPath);

const previewDir = path.join(outputDir, "previews");
await fs.mkdir(previewDir, { recursive: true });
for (const sheetName of ["Start Here", "Players", "Portraits", "Skater Ratings", "Goalie Ratings", "Uniforms", "Sources"]) {
  const preview = await wb.render({ sheetName, autoCrop: "all", scale: 0.65, format: "png" });
  await fs.writeFile(path.join(previewDir, `${sheetName.replace(/[^a-z0-9]+/gi, "-").toLowerCase()}.png`), new Uint8Array(await preview.arrayBuffer()));
}

const inspection = await wb.inspect({ kind: "workbook,sheet,formula", maxChars: 12000, tableMaxRows: 8, tableMaxCols: 12 });
await fs.writeFile(path.join(outputDir, "workbook-inspection.txt"), inspection.ndjson ?? String(inspection), "utf8");
const errors = await wb.inspect({ kind: "match", searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A", options: { useRegex: true, maxResults: 100 }, maxChars: 8000 });
await fs.writeFile(path.join(outputDir, "formula-error-scan.txt"), errors.ndjson ?? String(errors), "utf8");
const eaMatched = playerSources.filter(p => eaByName.has(nameKey(p.player_name))).length;
console.log(JSON.stringify({ outputPath, sheets: 7, players: playerRows.length, skaters: skaterRows.length, goalies: goalieRows.length, eaMatched, uniforms: uniformRows.length }));
