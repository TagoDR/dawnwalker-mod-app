import { useEffect, useState } from "react";
import { useTheme } from "../theme/useTheme";
import { useGameData } from "../data/useGameData";
import { useModding } from "../modding/useModding";
import { DEFAULT_COMBAT } from "../modding/gameplayDefaults";
import { useToast } from "../modding/useToast";

import PageHeader from "../components/ui/PageHeader";
import RuneSection from "../components/ui/RuneSection";
import RuneStagger from "../components/ui/RuneStagger";

import DWSlider from "../components/ui/DWSlider";
import DWToggle from "../components/ui/DWToggle";
import DWSelect from "../components/ui/DWSelect";
import DWButton from "../components/ui/DWButton";

// Talks to the UE4SS bridge mod (runtime-mods/DawnwalkerModBridge) through the Electron main process.
// Everything else on this page is a cosmetic profile stored in localStorage (see useModding/updateGameplay).
function DamageMultiplierControl() {
  const { theme } = useTheme();
  const bridge = typeof window !== "undefined" ? window.dawnwalker : null;
  const [damageMultiplier, setDamageMultiplier] = useState(1);
  const [applied, setApplied] = useState(null);
  const [message, setMessage] = useState(null);

  useEffect(() => {
    if (!bridge) return undefined;
    let cancelled = false;
    const poll = async () => {
      try {
        const result = await bridge.bridgeStatus();
        if (!cancelled) setApplied(result?.damageMultiplierApplied === "1");
      } catch {
        if (!cancelled) setApplied(null);
      }
    };
    poll();
    const interval = setInterval(poll, 3000);
    return () => {
      cancelled = true;
      clearInterval(interval);
    };
  }, [bridge]);

  // This component mounts fresh every time the user navigates back to Combat & Experience, so
  // without this the slider would show 1x again even though the real applied value is still set.
  useEffect(() => {
    if (!bridge) return undefined;
    let cancelled = false;
    (async () => {
      try {
        const state = await bridge.getBridgeCommandState();
        if (!cancelled && state?.damageMultiplier !== undefined) {
          setDamageMultiplier(Number(state.damageMultiplier));
        }
      } catch {
        // Non-fatal: falls back to the default slider value.
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [bridge]);

  if (!bridge) {
    return <p style={{ opacity: 0.78 }}>The live game bridge is only available in the desktop app.</p>;
  }

  const handleDamageMultiplier = async (value) => {
    setDamageMultiplier(value);
    const result = await bridge.applyDamageMultiplier(value);
    setMessage(result.ok ? null : result.error);
  };

  return (
    <>
      <DWSlider
        label="Damage Multiplier"
        value={damageMultiplier}
        onChange={handleDamageMultiplier}
        min={0.1}
        max={10}
        step={0.1}
      />
      <p style={{ opacity: 0.78 }}>Applied to the running game: {applied ? "Yes" : "No"}</p>
      <p style={{ opacity: 0.78, fontSize: "0.85em" }}>
        Note: this writes real game attributes and holds steady, but has not been confirmed to
        actually change combat damage - the game's real damage formula may read a different value
        entirely. Use "Nuke Target" below for a guaranteed damage effect instead.
      </p>
      {message && <p style={{ color: theme.colors.gold }}>{message}</p>}
    </>
  );
}

// Uses the engine's own stock CheatManager:DamageTarget(Amount) - deals real damage to whatever
// the player is currently aiming at, through the actual damage pipeline (not a custom Dogwood
// attribute like the multiplier above, so it's guaranteed to work).
function NukeTargetControl() {
  const { theme } = useTheme();
  const bridge = typeof window !== "undefined" ? window.dawnwalker : null;
  const [amount, setAmount] = useState(5000);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState(null);

  if (!bridge) return null;

  const handleNuke = async () => {
    setBusy(true);
    setMessage(null);
    const result = await bridge.nukeTarget(amount);
    setMessage(result.ok ? "Damage request sent to the game." : result.error);
    setBusy(false);
  };

  return (
    <div style={{ marginTop: 16 }}>
      <DWSlider label="Nuke Target - Damage Amount" value={amount} onChange={setAmount} min={1} max={999999} step={1} />
      <DWButton label="Nuke Target" onClick={handleNuke} disabled={busy} data-clickpulse data-glow />
      <p style={{ opacity: 0.78, fontSize: "0.85em", marginTop: 6 }}>
        Deals this much damage to whatever you're currently aiming at.
      </p>
      {message && <p style={{ color: theme.colors.gold }}>{message}</p>}
    </div>
  );
}

export default function CombatPage() {
  const game = useGameData();
  const { gameplay, updateGameplay, savePreset } = useModding();
  const toast = useToast();
  const { combat } = gameplay;

  if (game.loading) {
    return <p style={{ opacity: 0.8 }}>Loading combat data…</p>;
  }

  function handleSave() {
    savePreset("Combat Settings Save");
    toast.push({ type: "success", text: "Saved Combat settings preset" });
  }

  function handleReset() {
    updateGameplay("combat", DEFAULT_COMBAT);
    toast.push({ type: "success", text: "Combat settings reset to defaults" });
  }

  return (
    <div>
      <PageHeader title="Combat & Experience" />

      {/* Rune‑staggered sections */}
      <RuneStagger index={0}>
        <RuneSection title="Player Combat Stats">
          <DamageMultiplierControl />
          <NukeTargetControl />

          <DWSlider
            label="Critical Chance (%)"
            value={combat.player.critChance}
            onChange={(v) => updateGameplay("combat.player.critChance", v)}
            min={0}
            max={100}
          />

          <DWSlider
            label="Critical Damage (%)"
            value={combat.player.critDamage}
            onChange={(v) => updateGameplay("combat.player.critDamage", v)}
            min={100}
            max={500}
          />

          <DWSlider
            label="Attack Speed (%)"
            value={combat.player.attackSpeed}
            onChange={(v) => updateGameplay("combat.player.attackSpeed", v)}
            min={50}
            max={300}
          />
        </RuneSection>
      </RuneStagger>

      <RuneStagger index={1}>
        <RuneSection title="Enemy Combat Stats">
          <DWSlider
            label="Enemy Health (%)"
            value={combat.enemy.health}
            onChange={(v) => updateGameplay("combat.enemy.health", v)}
            min={50}
            max={300}
          />

          <DWSlider
            label="Enemy Damage (%)"
            value={combat.enemy.damage}
            onChange={(v) => updateGameplay("combat.enemy.damage", v)}
            min={50}
            max={300}
          />

          <DWSlider
            label="Enemy Aggression"
            value={combat.enemy.aggro}
            onChange={(v) => updateGameplay("combat.enemy.aggro", v)}
            min={0}
            max={100}
          />
        </RuneSection>
      </RuneStagger>

      <RuneStagger index={2}>
        <RuneSection title="Combat Mechanics">
          <DWSelect
            label="Stealth Difficulty"
            value={combat.mechanics.stealthDifficulty}
            onChange={(v) => updateGameplay("combat.mechanics.stealthDifficulty", v)}
            options={["Story", "Normal", "Hard", "Nightfall"]}
          />

          <DWSlider
            label="Parry Window (ms)"
            value={combat.mechanics.parryWindow}
            onChange={(v) => updateGameplay("combat.mechanics.parryWindow", v)}
            min={50}
            max={500}
          />

          <DWToggle
            label="Enable Auto-Aim Assist"
            value={combat.mechanics.autoAim}
            onChange={(v) => updateGameplay("combat.mechanics.autoAim", v)}
          />
        </RuneSection>
      </RuneStagger>

      <RuneStagger index={3}>
        <RuneSection title="Boss Fight Tuning">
          <DWSlider
            label="Boss Health (%)"
            value={combat.boss.health}
            onChange={(v) => updateGameplay("combat.boss.health", v)}
            min={50}
            max={500}
          />

          <DWSlider
            label="Boss Damage (%)"
            value={combat.boss.damage}
            onChange={(v) => updateGameplay("combat.boss.damage", v)}
            min={50}
            max={500}
          />

          <DWSlider
            label="Phase Transition Speed (%)"
            value={combat.boss.phaseSpeed}
            onChange={(v) => updateGameplay("combat.boss.phaseSpeed", v)}
            min={50}
            max={300}
          />
        </RuneSection>
      </RuneStagger>

      <div style={{ marginTop: 18, display: "flex", gap: 12 }}>
        <DWButton label="Save Preset" onClick={handleSave} data-clickpulse data-glow />
        <DWButton label="Reset to Defaults" onClick={handleReset} />
      </div>
    </div>
  );
}
