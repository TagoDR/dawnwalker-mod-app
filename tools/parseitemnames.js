// Parses the dumpItemNames output out of UE4SS.log. UE4SS packs many same-tick print() calls onto
// ONE physical line, so entries are split on the next "[timestamp]" rather than on newlines.
const fs = require("fs");

const log = process.argv[2];
const text = fs.readFileSync(log, "utf8");

const entryRe = /ItemName: (\S+) (\/Game\/\S+?) = (.*?)(?=\[\d{4}-\d{2}-\d{2} |\r|\n|$)/g;

const byAsset = new Map();
let missing = 0;
let match;
while ((match = entryRe.exec(text)) !== null) {
  const [, className, path, rawName] = match;
  const name = rawName.trim();
  const asset = path.split(".").pop();
  if (!name || name.includes("MISSING STRING TABLE ENTRY")) {
    missing += 1;
    if (!byAsset.has(asset)) byAsset.set(asset, { className, name: null });
    continue;
  }
  // A later run may resolve a name an earlier run couldn't - always prefer a real name.
  byAsset.set(asset, { className, name });
}

const resolved = [...byAsset.values()].filter((e) => e.name).length;
console.log(`assets seen: ${byAsset.size}  resolved: ${resolved}  missing-entry hits: ${missing}`);

const byClass = {};
for (const [asset, { className, name }] of byAsset) {
  (byClass[className] ??= []).push({ asset, name });
}
for (const [className, items] of Object.entries(byClass)) {
  const got = items.filter((i) => i.name).length;
  console.log(`  ${className}: ${got}/${items.length} named`);
}

fs.writeFileSync(
  "tools/out-itemnames.json",
  JSON.stringify(Object.fromEntries([...byAsset].map(([k, v]) => [k, v.name])), null, 2),
);
console.log("\nsample:");
for (const [asset, { name }] of [...byAsset].filter(([, v]) => v.name).slice(0, 12)) {
  console.log(`  ${asset} = ${name}`);
}
