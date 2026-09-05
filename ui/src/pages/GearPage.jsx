import { useEffect, useState } from "react";
import { useTheme } from "../theme/useTheme";

import PageHeader from "../components/ui/PageHeader";
import RuneSection from "../components/ui/RuneSection";
import RuneStagger from "../components/ui/RuneStagger";
import DWSelect from "../components/ui/DWSelect";
import DWSlider from "../components/ui/DWSlider";
import DWButton from "../components/ui/DWButton";

import { GEAR_CATALOG, CLEANUP_CATALOG, CRAFTABLE_CATALOG } from "../data/GearCatalog";
import { useBridge, commandNumber } from "../bridge/useBridge";
import BridgePanel, { Readouts, ActionRow, ButtonRow, Note } from "../bridge/BridgePanel";

// Mirrors kMaxGrantQuantity in native-mods/DawnwalkerNativeFix/dllmain.cpp.
const MAX_GRANT_AMOUNT = 99;

// Coins, crafting and carry weight go through the Lua bridge (InventoryComponent /
// CraftingSubsystem) - unlike item granting, none of these need FItemHandle marshalling.
function InventorySection() {
  const api = useBridge();
  const { status, command, busy, applyField, runAction } = api;
  const [coins, setCoins] = useState(1000);

  return (
    <BridgePanel bridgeApi={api} title="Inventory (Lua bridge)">
      <RuneStagger index={1}>
        <RuneSection title="Coins">
          <Readouts items={[["Coins", status?.coins]]} />
          <ActionRow label="Add Coins" disabled={busy} onClick={() => runAction("addCoins", coins, "Coins sent to the game.")}>
            <DWSlider label="Coin Amount" value={coins} onChange={setCoins} min={1} max={100000} step={1} />
          </ActionRow>
          <ActionRow label="Remove Coins" disabled={busy} onClick={() => runAction("addCoins", -coins, "Coin removal sent to the game.")}>
            <Note>Uses InventoryComponent:AddCurrency with a negative amount.</Note>
          </ActionRow>
        </RuneSection>
      </RuneStagger>

      <RuneStagger index={2}>
        <RuneSection title="Carry Weight">
          <Readouts
            items={[
              ["Current weight", status?.carryWeight],
              ["Weight limit", status?.carryWeightLimit],
            ]}
          />
          <DWSlider
            label="Carry Weight Multiplier"
            value={commandNumber(command, "carryWeightMultiplier", 1)}
            onChange={(v) => applyField("carryWeightMultiplier", v)}
            min={0.1}
            max={100}
            step={0.1}
          />
        </RuneSection>
      </RuneStagger>

      <RuneStagger index={3}>
        <RuneSection title="Crafting">
          <ButtonRow>
            <DWButton
              label="Unlock All Recipes"
              disabled={busy}
              onClick={() => runAction("unlockAllRecipes", null, "Recipe unlock sent to the game.")}
              data-clickpulse
              data-glow
            />
            <DWButton
              label="Log Item Names"
              disabled={busy}
              onClick={() => runAction("dumpItemNames", null, "Item names written to UE4SS.log.")}
              data-clickpulse
            />
            <DWButton
              label="Check Game Compatibility"
              disabled={busy}
              onClick={() => runAction("selfCheck", null, "Compatibility check sent to the game.")}
              data-clickpulse
            />
          </ButtonRow>
          <Readouts
            items={[
              ["Item names captured", status?.itemNamesLogged],
              ["Menu open", status?.menuOpen === "1" ? "Yes" : "No"],
              ["Last action result", status?.actionResult],
            ]}
          />
          <Note>
            CraftingSubsystem:UnlockAllCraftingRecipes. For ingredients and crafted goods, pick the exact item
            and amount from the Consumable / Ingredient lists above - the old "add ingredients for every recipe"
            call crashed the game. Item names are captured automatically whenever you open an in-game menu;
            the button forces a pass now. "Check Game Compatibility" verifies every function this app calls
            still exists - run it after a game update.
          </Note>
        </RuneSection>
      </RuneStagger>
    </BridgePanel>
  );
}

// One dropdown + amount + action button for a single catalog category (Weapon, Armor Set, Ring,
// Amulet, Consumable, Ingredient, Cleanup). Granting is scoped to whichever single option is
// selected, instead of dumping every item at once - see repo memory: granting 26 items in one
// native tick flooded the game's own quest/notification system and crashed it.
function GearCategorySection({ category, options, bridge, busy, actionLabel, onAction, showAmount = false }) {
  const [selected, setSelected] = useState(options[0].value);
  const [amount, setAmount] = useState(1);

  return (
    <RuneSection title={category}>
      <div style={{ display: "flex", gap: 12, alignItems: "center", flexWrap: "wrap" }}>
        <DWSelect label={`Select ${category}`} value={selected} onChange={setSelected} options={options} />
        {showAmount && (
          <div style={{ minWidth: 200 }}>
            <DWSlider label="Amount" value={amount} onChange={setAmount} min={1} max={MAX_GRANT_AMOUNT} step={1} />
          </div>
        )}
        <DWButton
          label={`${actionLabel} ${category}`}
          onClick={() => onAction(selected, amount)}
          disabled={!bridge || busy}
          data-clickpulse
          data-glow
        />
      </div>
    </RuneSection>
  );
}

export default function GearPage() {
  const { theme } = useTheme();
  const bridge = typeof window !== "undefined" ? window.dawnwalker : null;
  const [status, setStatus] = useState(null);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState(null);

  useEffect(() => {
    if (!bridge) return undefined;
    let cancelled = false;
    const poll = async () => {
      try {
        const result = await bridge.nativeFixStatus();
        if (!cancelled) setStatus(result);
      } catch {
        if (!cancelled) setStatus({ ok: false, error: "Failed to reach the native fix mod" });
      }
    };
    poll();
    const interval = setInterval(poll, 3000);
    return () => {
      cancelled = true;
      clearInterval(interval);
    };
  }, [bridge]);

  const handleGrant = async (gearId, amount = 1) => {
    setBusy(true);
    setMessage(null);
    if (!status?.deployed) {
      const deployResult = await bridge.deployNativeFix();
      if (!deployResult.ok) {
        setMessage(deployResult.error);
        setBusy(false);
        return;
      }
    }
    const result = await bridge.giveGearNative(gearId, amount);
    setMessage(result.ok ? `Request sent to the game (x${amount}).` : result.error);
    setBusy(false);
  };

  const handleRemove = async (gearId) => {
    setBusy(true);
    setMessage(null);
    if (!status?.deployed) {
      const deployResult = await bridge.deployNativeFix();
      if (!deployResult.ok) {
        setMessage(deployResult.error);
        setBusy(false);
        return;
      }
    }
    const result = await bridge.removeGearNative(gearId);
    setMessage(result.ok ? "Removal request sent to the game." : result.error);
    setBusy(false);
  };

  return (
    <div>
      <PageHeader title="Gear & Inventory" />

      {!bridge ? (
        <p style={{ opacity: 0.78 }}>Gear granting is only available in the desktop app.</p>
      ) : (
        <>
          <RuneSection title="Native Gear Mod Status">
            <p style={{ opacity: 0.78, marginBottom: 8 }}>
              Item granting uses the native DawnwalkerNativeFix C++ mod: UE4SS Lua can't marshal the game's
              FItemHandle struct (it has no reflected fields), so the native mod copies its raw bytes instead and
              grants one item per engine tick so the game's quest/notification systems aren't flooded.
            </p>
            <p>Game running: {status?.gameRunning ? "Yes" : "No"}</p>
            <p>Native mod deployed: {status?.deployed ? "Yes" : "No"}</p>
            <p>Last grant result: {status?.giveGearResult ?? "not yet requested"}</p>
            <p>Last granted gear id: {status?.giveGearId ?? "none"}</p>
            <p>Last removal result: {status?.removeGearResult ?? "not yet requested"}</p>
            {message && <p style={{ color: theme.colors.gold, marginTop: 8 }}>{message}</p>}
          </RuneSection>

          {GEAR_CATALOG.map(({ category, options }) => (
            <GearCategorySection
              key={category}
              category={category}
              options={options}
              bridge={bridge}
              busy={busy}
              actionLabel="Grant"
              onAction={handleGrant}
              showAmount
            />
          ))}

          {CRAFTABLE_CATALOG.map(({ category, options }) => (
            <GearCategorySection
              key={category}
              category={category}
              options={options}
              bridge={bridge}
              busy={busy}
              actionLabel="Grant"
              onAction={handleGrant}
              showAmount
            />
          ))}

          {CLEANUP_CATALOG.map(({ category, options }) => (
            <GearCategorySection
              key={category}
              category={category}
              options={options}
              bridge={bridge}
              busy={busy}
              actionLabel="Remove"
              onAction={handleRemove}
            />
          ))}

          <InventorySection />
        </>
      )}
    </div>
  );
}
