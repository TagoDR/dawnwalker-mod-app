import { useTheme } from "../theme/useTheme";
import { useGameData } from "../data/useGameData";
import { useModding } from "../modding/useModding";
import { DEFAULT_COMBAT } from "../modding/gameplayDefaults";
import { useToast } from "../modding/useToast";

import RuneSection from "../components/ui/RuneSection";
import RuneStagger from "../components/ui/RuneStagger";

import DWSlider from "../components/ui/DWSlider";
import DWToggle from "../components/ui/DWToggle";
import DWSelect from "../components/ui/DWSelect";
import DWButton from "../components/ui/DWButton";

export default function CombatPage() {
  const { theme } = useTheme();
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
      <h1
        style={{
          marginBottom: "10px",
          color: theme.colors.gold,
          letterSpacing: "1px",
          textTransform: "uppercase",
        }}
      >
        Combat & Experience
      </h1>

      <div
        style={{
          height: "2px",
          background: theme.colors.divider,
          boxShadow: `0 0 10px ${theme.colors.glow}`,
          marginBottom: "20px",
        }}
      />

      {/* Rune‑staggered sections */}
      <RuneStagger index={0}>
        <RuneSection title="Player Combat Stats">
          <DWSlider
            label="Base Damage"
            value={combat.player.damage}
            onChange={(v) => updateGameplay("combat.player.damage", v)}
            min={0}
            max={500}
          />

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
