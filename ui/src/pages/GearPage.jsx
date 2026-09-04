import { useEffect, useState } from "react";
import { useTheme } from "../theme/useTheme";

import PageHeader from "../components/ui/PageHeader";
import RuneSection from "../components/ui/RuneSection";
import DWSelect from "../components/ui/DWSelect";
import DWButton from "../components/ui/DWButton";

import { GEAR_CATALOG, CLEANUP_CATALOG } from "../data/GearCatalog";

// One dropdown + "Grant" button for a single gear category (Weapon, Armor Set, Ring, Amulet).
// Granting is scoped to whichever single option is selected, instead of dumping every item at
// once - see repo memory: granting 26 items in one native tick flooded the game's own quest/
// notification system and crashed it.
function GearCategorySection({ category, options, bridge, busy, actionLabel, onAction }) {
  const [selected, setSelected] = useState(options[0].value);

  return (
    <RuneSection title={category}>
      <div style={{ display: "flex", gap: 12, alignItems: "center" }}>
        <DWSelect label={`Select ${category}`} value={selected} onChange={setSelected} options={options} />
        <DWButton
          label={`${actionLabel} ${category}`}
          onClick={() => onAction(selected)}
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

  const handleGrant = async (gearId) => {
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
    const result = await bridge.giveGearNative(gearId);
    setMessage(result.ok ? "Gear request sent to the game." : result.error);
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
      <PageHeader title="Gear" />

      {!bridge ? (
        <p style={{ opacity: 0.78 }}>Gear granting is only available in the desktop app.</p>
      ) : (
        <>
          <RuneSection title="Native Fix Status">
            <p style={{ opacity: 0.78, marginBottom: 8 }}>
              Uses the native DawnwalkerNativeFix mod: the old Lua path always granted the wrong item
              (a "Bee Smoker" quest item) because Lua's UFunction marshalling can't see FItemHandle's
              unreflected fields. The native mod copies the struct's raw bytes instead, and grants each
              request one item per engine tick so the game's own quest/notification system isn't
              flooded.
            </p>
            <p>Game running: {status?.gameRunning ? "Yes" : "No"}</p>
            <p>Native fix mod deployed: {status?.deployed ? "Yes" : "No"}</p>
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
        </>
      )}
    </div>
  );
}
