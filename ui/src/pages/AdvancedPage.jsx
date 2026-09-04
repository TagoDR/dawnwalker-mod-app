import { useGameData } from "../data/useGameData";
import { useModding } from "../modding/useModding";
import { DEFAULT_ADVANCED } from "../modding/gameplayDefaults";
import { useToast } from "../modding/useToast";

import PageHeader from "../components/ui/PageHeader";
import RuneSection from "../components/ui/RuneSection";
import RuneStagger from "../components/ui/RuneStagger";

import DWSlider from "../components/ui/DWSlider";
import DWToggle from "../components/ui/DWToggle";
import DWSelect from "../components/ui/DWSelect";
import DWButton from "../components/ui/DWButton";

export default function AdvancedPage() {
  const game = useGameData();
  const { gameplay, updateGameplay, savePreset } = useModding();
  const toast = useToast();
  const { advanced } = gameplay;

  if (game.loading) {
    return <p style={{ opacity: 0.8 }}>Loading advanced settings…</p>;
  }

  function handleSave() {
    savePreset("Advanced Settings Save");
    toast.push({ type: "success", text: "Saved Advanced settings preset" });
  }

  function handleReset() {
    updateGameplay("advanced", DEFAULT_ADVANCED);
    toast.push({ type: "success", text: "Advanced settings reset to defaults" });
  }

  return (
    <div>
      <PageHeader title="Advanced Tuning" />

      {/* Rune‑staggered sections */}
      <RuneStagger index={0}>
        <RuneSection title="AI Behavior">
          <DWSelect
            label="AI Difficulty"
            value={advanced.ai.difficulty}
            onChange={(v) => updateGameplay("advanced.ai.difficulty", v)}
            options={["Story", "Normal", "Hard", "Nightfall"]}
          />

          <DWSlider
            label="AI Reaction Time (ms)"
            value={advanced.ai.reactionTime}
            onChange={(v) => updateGameplay("advanced.ai.reactionTime", v)}
            min={50}
            max={1000}
          />

          <DWSlider
            label="AI Accuracy (%)"
            value={advanced.ai.accuracy}
            onChange={(v) => updateGameplay("advanced.ai.accuracy", v)}
            min={0}
            max={100}
          />
        </RuneSection>
      </RuneStagger>

      <RuneStagger index={1}>
        <RuneSection title="Physics & Simulation">
          <DWSlider
            label="Gravity Strength (%)"
            value={advanced.physics.gravity}
            onChange={(v) => updateGameplay("advanced.physics.gravity", v)}
            min={50}
            max={200}
          />

          <DWSlider
            label="Ragdoll Force (%)"
            value={advanced.physics.ragdollForce}
            onChange={(v) => updateGameplay("advanced.physics.ragdollForce", v)}
            min={50}
            max={300}
          />

          <DWToggle
            label="Enable Collision Damage"
            value={advanced.physics.collisionDamage}
            onChange={(v) => updateGameplay("advanced.physics.collisionDamage", v)}
          />
        </RuneSection>
      </RuneStagger>

      <RuneStagger index={2}>
        <RuneSection title="Graphics & Rendering">
          <DWSlider
            label="Render Distance (%)"
            value={advanced.graphics.renderDistance}
            onChange={(v) => updateGameplay("advanced.graphics.renderDistance", v)}
            min={50}
            max={200}
          />

          <DWSelect
            label="Shadow Quality"
            value={advanced.graphics.shadowQuality}
            onChange={(v) => updateGameplay("advanced.graphics.shadowQuality", v)}
            options={["Low", "Medium", "High", "Ultra"]}
          />

          <DWSlider
            label="Particle Density (%)"
            value={advanced.graphics.particleDensity}
            onChange={(v) => updateGameplay("advanced.graphics.particleDensity", v)}
            min={0}
            max={100}
          />
        </RuneSection>
      </RuneStagger>

      <RuneStagger index={3}>
        <RuneSection title="Developer Tools">
          <DWToggle
            label="Enable Debug Logs"
            value={advanced.devTools.debugLogs}
            onChange={(v) => updateGameplay("advanced.devTools.debugLogs", v)}
          />

          <DWToggle
            label="Enable Profiling Mode"
            value={advanced.devTools.profilingMode}
            onChange={(v) => updateGameplay("advanced.devTools.profilingMode", v)}
          />

          <DWToggle
            label="Enable Hot Reload"
            value={advanced.devTools.hotReload}
            onChange={(v) => updateGameplay("advanced.devTools.hotReload", v)}
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
