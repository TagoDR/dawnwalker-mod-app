// One-off generator: turns the ItemConsumable/ItemIngredient asset list scraped from
// UE4SS_ObjectDump.txt into the C++ kSimpleItemOptions table and the JS CRAFTABLE_CATALOG.
// Usage: node tools/gencraftables.js <paths.txt>
const fs = require("fs");

const lines = fs
  .readFileSync(process.argv[2], "utf8")
  .split(/\r?\n/)
  .map((l) => l.trim())
  .filter((l) => l.startsWith("/Game/"));

const entries = lines.map((path) => {
  const asset = path.split(".").pop();
  const m = /^ITM_(Consumable|Ingredient)_(.+?)(\d*)$/.exec(asset);
  const kind = m[1].toLowerCase();
  const family = m[2];
  const number = m[3];
  const words = family.replace(/([a-z0-9])([A-Z])/g, "$1 $2");
  return {
    id: `${kind}_${family.toLowerCase()}${number}`,
    label: number ? `${words} ${number}` : words,
    kind,
    path,
  };
});

const cpp = entries
  .map((e) => `        {"${e.id}", STR("${e.path}")},`)
  .join("\n");

const js = (kind) =>
  entries
    .filter((e) => e.kind === kind)
    .map((e) => `      { value: "${e.id}", label: "${e.label}" },`)
    .join("\n");

fs.writeFileSync("tools/out-craftables.cpp.txt", cpp);
fs.writeFileSync("tools/out-craftables.consumable.txt", js("consumable"));
fs.writeFileSync("tools/out-craftables.ingredient.txt", js("ingredient"));
console.log(`${entries.length} entries written`);
