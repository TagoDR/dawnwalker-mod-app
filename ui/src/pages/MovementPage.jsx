import { useGameData } from "../data/useGameData";
import { useModding } from "../modding/useModding";
import { DEFAULT_MOVEMENT } from "../modding/gameplayDefaults";
import { useToast } from "../modding/useToast";

import PageHeader from "../components/ui/PageHeader";
import RuneSection from "../components/ui/RuneSection";
import RuneStagger from "../components/ui/RuneStagger";

import DWSlider from "../components/ui/DWSlider";
import DWToggle from "../components/ui/DWToggle";
import DWButton from "../components/ui/DWButton";

export default function MovementPage() {
  const game = useGameData();
  const { gameplay, updateGameplay, savePreset } = useModding();
  const toast = useToast();
  const { movement } = gameplay;

  if (game.loading) {
    return <p style={{ opacity: 0.8 }}>Loading movement data…</p>;
  }

  function handleSave() {
    savePreset("Movement Settings Save");
    toast.push({ type: "success", text: "Saved Movement settings preset" });
  }

  function handleReset() {
    updateGameplay("movement", DEFAULT_MOVEMENT);
    toast.push({ type: "success", text: "Movement settings reset to defaults" });
  }

  return (
    <div>
      <PageHeader title="Movement & Stamina" />

      {/* Rune‑staggered sections */}
      <RuneStagger index={0}>
        <RuneSection title="Basic Movement">
          <DWSlider
            label="Walk Speed (%)"
            value={movement.basic.walkSpeed}
            onChange={(v) => updateGameplay("movement.basic.walkSpeed", v)}
            min={50}
            max={200}
          />

          <DWSlider
            label="Run Speed (%)"
            value={movement.basic.runSpeed}
            onChange={(v) => updateGameplay("movement.basic.runSpeed", v)}
            min={50}
            max={300}
          />

          <DWSlider
            label="Sprint Speed (%)"
            value={movement.basic.sprintSpeed}
            onChange={(v) => updateGameplay("movement.basic.sprintSpeed", v)}
            min={50}
            max={400}
          />

          <DWSlider
            label="Jump Height (%)"
            value={movement.basic.jumpHeight}
            onChange={(v) => updateGameplay("movement.basic.jumpHeight", v)}
            min={50}
            max={300}
          />

          <DWToggle
            label="Enable Fall Damage"
            value={movement.basic.fallDamage}
            onChange={(v) => updateGameplay("movement.basic.fallDamage", v)}
          />
        </RuneSection>
      </RuneStagger>

      <RuneStagger index={1}>
        <RuneSection title="Stamina & Climbing">
          <DWSlider
            label="Stamina Drain Rate"
            value={movement.stamina.drain}
            onChange={(v) => updateGameplay("movement.stamina.drain", v)}
            min={0}
            max={50}
          />

          <DWSlider
            label="Stamina Regeneration"
            value={movement.stamina.regen}
            onChange={(v) => updateGameplay("movement.stamina.regen", v)}
            min={0}
            max={100}
          />

          <DWSlider
            label="Climb Speed (%)"
            value={movement.stamina.climbSpeed}
            onChange={(v) => updateGameplay("movement.stamina.climbSpeed", v)}
            min={50}
            max={200}
          />
        </RuneSection>
      </RuneStagger>

      <RuneStagger index={2}>
        <RuneSection title="Dash Mechanics">
          <DWToggle
            label="Enable Dash Ability"
            value={movement.dash.enabled}
            onChange={(v) => updateGameplay("movement.dash.enabled", v)}
          />

          <DWSlider
            label="Dash Cooldown (Seconds)"
            value={movement.dash.cooldown}
            onChange={(v) => updateGameplay("movement.dash.cooldown", v)}
            min={0}
            max={10}
          />

          <DWSlider
            label="Dash Distance (Meters)"
            value={movement.dash.distance}
            onChange={(v) => updateGameplay("movement.dash.distance", v)}
            min={1}
            max={30}
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
