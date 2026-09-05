// Merges real in-game names (tools/out-itemnames.json) into both catalogs in
// ui/src/data/GearCatalog.js. Craftable ids are derivable from the asset name; gear ids come from
// the id -> asset index tools/gengear.js writes alongside the catalog it generates.
// Re-runnable: only replaces a label when a real name is known for that id.
const fs = require("fs");

const names = require("../tools/out-itemnames.json");
const gearIndex = require("../tools/gear-index.json");
const catalogPath = "ui/src/data/GearCatalog.js";
let text = fs.readFileSync(catalogPath, "utf8");

const idToName = new Map();

// Craftables: id was generated from the asset name, so invert that.
for (const [asset, name] of Object.entries(names)) {
  if (!name) continue;
  const m = /^ITM_(Consumable|Ingredient)_(.+?)(\d*)$/.exec(asset);
  if (!m) continue;
  idToName.set(`${m[1].toLowerCase()}_${m[2].toLowerCase()}${m[3]}`, name);
}

// Gear singles: straight id -> asset lookup. Armor sets are absent from the index by design -
// one piece's name would be a misleading label for a four-piece set.
for (const [id, asset] of Object.entries(gearIndex)) {
  const name = names[asset];
  if (name) idToName.set(id, name);
}

let updated = 0;
const changes = [];
for (const [id, rawName] of idToName) {
  if (rawName.includes("OBSOLETE")) continue;
  const name = rawName.replace(/"/g, "'");
  const line = new RegExp(`(\\{ value: "${id}", label: ")([^"]*)(" \\})`);
  const found = line.exec(text);
  if (!found) continue;
  // Preserve the "(auto-equips)" hint the catalog adds to equipping entries.
  const suffix = found[2].includes("(auto-equips)") ? " (auto-equips)" : "";
  if (found[2] === name + suffix) continue;
  text = text.replace(line, `$1${name}${suffix}$3`);
  updated += 1;
  changes.push(`${id}: ${found[2]} -> ${name}${suffix}`);
}

fs.writeFileSync(catalogPath, text);
console.log(`updated ${updated} labels`);
for (const line of changes) console.log("  " + line);
