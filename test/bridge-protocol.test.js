const test = require("node:test");
const assert = require("node:assert/strict");

const { sanitizeField, sanitizePreset, sanitizeAction, BRIDGE_FIELD_SANITIZERS, BRIDGE_ACTIONS } = require("../bridge-protocol");

test("sanitizeField clamps numeric fields to the same ranges main.lua enforces", () => {
  assert.deepEqual(sanitizeField("levelCap", 200), { ok: true, key: "levelCap", value: 99 });
  assert.deepEqual(sanitizeField("levelCap", 0), { ok: true, key: "levelCap", value: 1 });
  assert.deepEqual(sanitizeField("speedMultiplier", 9), { ok: true, key: "speedMultiplier", value: 5 });
  assert.deepEqual(sanitizeField("damageAmplifier", 50), { ok: true, key: "damageAmplifier", value: 20 });
  assert.deepEqual(sanitizeField("actionDifficulty", 2.7), { ok: true, key: "actionDifficulty", value: 2 });
  assert.deepEqual(sanitizeField("carryWeightMultiplier", 0.5), { ok: true, key: "carryWeightMultiplier", value: 0.5 });
});

test("sanitizeField normalizes toggles and rejects unknown keys or garbage", () => {
  assert.deepEqual(sanitizeField("infiniteBlood", true), { ok: true, key: "infiniteBlood", value: 1 });
  assert.deepEqual(sanitizeField("infiniteBlood", "1"), { ok: true, key: "infiniteBlood", value: 1 });
  assert.deepEqual(sanitizeField("noCooldowns", false), { ok: true, key: "noCooldowns", value: 0 });
  assert.equal(sanitizeField("speedMultiplier", "fast").ok, false);
  assert.equal(sanitizeField("speedMultiplier", null).ok, false);
  assert.equal(sanitizeField("giveBestGear", 1).ok, false);
  assert.equal(sanitizeField("__proto__", 1).ok, false);
});

test("movementMode only accepts the three engine cheat modes", () => {
  assert.deepEqual(sanitizeField("movementMode", "ghost"), { ok: true, key: "movementMode", value: "ghost" });
  assert.equal(sanitizeField("movementMode", "noclip").ok, false);
});

test("sanitizePreset keeps valid persistent fields and drops everything else", () => {
  const result = sanitizePreset({
    infiniteHealth: "1",
    speedMultiplier: "1.5",
    movementMode: "fly",
    requestId: 12,
    setLevel: 99,
    actionId: 4,
    bogus: "x",
    gameSpeed: "way too fast",
  });
  assert.deepEqual(result, { ok: true, patch: { infiniteHealth: 1, speedMultiplier: 1.5, movementMode: "fly" } });
  assert.equal(sanitizePreset({ requestId: 1 }).ok, false);
  assert.equal(sanitizePreset(null).ok, false);
});

test("sanitizeAction validates arguments per action and rejects no-op adds", () => {
  assert.deepEqual(sanitizeAction("grantXP", 5), { ok: true, name: "grantXP", arg: 5 });
  assert.deepEqual(sanitizeAction("grantXP", 9), { ok: true, name: "grantXP", arg: 5 });
  assert.deepEqual(sanitizeAction("addTraitPoints", -3), { ok: true, name: "addTraitPoints", arg: -3 });
  assert.equal(sanitizeAction("addCoins", 0).ok, false);
  assert.deepEqual(sanitizeAction("setTraitPoints", 0), { ok: true, name: "setTraitPoints", arg: 0 });
  assert.deepEqual(sanitizeAction("unlockAllTraits", "ignored"), { ok: true, name: "unlockAllTraits", arg: "" });
  assert.deepEqual(sanitizeAction("setTimeOfDay", "07:30"), { ok: true, name: "setTimeOfDay", arg: "07:30" });
  assert.equal(sanitizeAction("setTimeOfDay", "25:00").ok, false);
  assert.equal(sanitizeAction("setTimeOfDay", "noon").ok, false);
  assert.equal(sanitizeAction("giveBestGear").ok, false);
  assert.equal(sanitizeAction("toString").ok, false);
});

test("every action and field the UI can send is known to the Lua mod", () => {
  const fs = require("node:fs");
  const path = require("node:path");
  const lua = fs.readFileSync(path.join(__dirname, "..", "runtime-mods", "DawnwalkerModBridge", "Scripts", "main.lua"), "utf8");
  for (const action of Object.keys(BRIDGE_ACTIONS)) {
    assert.ok(lua.includes(`name == "${action}"`), `main.lua has no RunAction branch for "${action}"`);
  }
  for (const field of Object.keys(BRIDGE_FIELD_SANITIZERS)) {
    assert.ok(lua.includes(`command.${field}`), `main.lua never reads command.${field}`);
  }
});
