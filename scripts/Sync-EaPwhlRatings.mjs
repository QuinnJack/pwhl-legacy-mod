import fs from "node:fs/promises";
import path from "node:path";

const repoRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname.replace(/^\/(.:)/, "$1")), "..");
const outputPath = process.argv[2] ? path.resolve(process.argv[2]) : path.join(repoRoot, "data", "ea-nhl26-pwhl-ratings.csv");
const listingUrl = "https://www.ea.com/games/nhl/ratings/conferences-ratings/pwhl/4";
const response = await fetch(listingUrl, { headers: { "User-Agent": "Mozilla/5.0 PWHL-Legacy-Mod/0.1" } });
if (!response.ok) throw new Error(`EA ratings request failed: HTTP ${response.status}`);
const html = await response.text();
const match = html.match(/<script[^>]+id=["']__NEXT_DATA__["'][^>]*>([\s\S]*?)<\/script>/i);
if (!match) throw new Error("EA page did not contain the expected __NEXT_DATA__ payload.");
const payload = JSON.parse(match[1]);

const found = new Map();
function visit(value) {
  if (!value || typeof value !== "object") return;
  if (!Array.isArray(value) && value.id != null && value.firstName && value.lastName && value.overallRating != null && value.stats) {
    found.set(String(value.id), value);
  }
  for (const child of Object.values(value)) visit(child);
}
visit(payload);

function slug(value) {
  return value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
}
function csv(value) {
  const text = value == null ? "" : String(value);
  return /[",\r\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}
function stat(player, key) { return player.stats?.[key]?.value ?? ""; }

const statColumns = {
  acceleration: "acceleration", agility: "agility", strength: "strength", aggression: "aggression",
  balance: "balance", body_checking: "bodyChecking", defensive_awareness: "defensiveAwareness",
  hand_eye: "handeye", deking: "deking", discipline: "discipline", durability: "durability",
  endurance: "endurance", faceoffs: "faceoffs", offensive_awareness: "offensiveAwareness",
  passing: "passing", poise: "poise", puck_control: "puckControl", shot_blocking: "shotBlocking",
  slapshot_accuracy: "slapshotAccuracy", slapshot_power: "slapshotPower", speed: "speed",
  stick_checking: "stickChecking", wristshot_accuracy: "wristshotAccuracy", wristshot_power: "wristshotPower",
  shot_recovery: "shotRecover", glove_high: "glovesideHigh", glove_low: "glovesideLow",
  stick_high: "sticksideHigh", stick_low: "sticksideLow", five_hole: "fiveHole", poke_check: "pokeCheck",
  positioning: "angles", rebound_control: "reboundControl", breakaway: "breakaway",
  puck_play_frequency: "puckplayingFrequency", goalie_aggression: "aggressiveness", vision: "vision"
};
const headers = ["ea_player_id", "player_name", "position", "team", "overall", ...Object.keys(statColumns), "source_url", "listing_url", "retrieved_utc"];
const retrieved = new Date().toISOString();
const rows = [...found.values()].sort((a, b) => b.overallRating - a.overallRating || a.lastName.localeCompare(b.lastName)).map(player => {
  const name = `${player.firstName} ${player.lastName}`;
  const sourceUrl = `https://www.ea.com/games/nhl/ratings/player-ratings/${slug(name)}/${player.id}`;
  return [player.id, name, player.position?.shortLabel ?? player.position?.label ?? "", player.team?.label ?? "", player.overallRating,
    ...Object.values(statColumns).map(key => stat(player, key)), sourceUrl, listingUrl, retrieved];
});
if (!rows.length) throw new Error("No EA player rating records were found.");
await fs.writeFile(outputPath, [headers, ...rows].map(row => row.map(csv).join(",")).join("\r\n") + "\r\n", "utf8");
console.log(`Saved ${rows.length} official EA NHL 26 PWHL rating records to ${outputPath}`);

