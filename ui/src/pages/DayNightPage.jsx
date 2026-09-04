import { useGameData } from "../data/useGameData";
import { useModding } from "../modding/useModding";
import { DEFAULT_DAYNIGHT } from "../modding/gameplayDefaults";
import { useToast } from "../modding/useToast";

import PageHeader from "../components/ui/PageHeader";
import RuneSection from "../components/ui/RuneSection";
import RuneStagger from "../components/ui/RuneStagger";

import DWSlider from "../components/ui/DWSlider";
import DWToggle from "../components/ui/DWToggle";
import DWButton from "../components/ui/DWButton";

export default function DayNightPage() {
  const game = useGameData();
  const { gameplay, updateGameplay, savePreset } = useModding();
  const toast = useToast();
  const { dayNight } = gameplay;

  if (game.loading) {
    return <p style={{ opacity: 0.8 }}>Loading day/night data…</p>;
  }

  function handleSave() {
    savePreset("Day / Night Settings Save");
    toast.push({ type: "success", text: "Saved Day / Night settings preset" });
  }

  function handleReset() {
    updateGameplay("dayNight", DEFAULT_DAYNIGHT);
    toast.push({ type: "success", text: "Day / Night settings reset to defaults" });
  }

  return (
    <div>
      <PageHeader title="Day / Night & Timer" />

      {/* Rune‑staggered sections */}
      <RuneStagger index={0}>
        <RuneSection title="Cycle Length">
          <DWSlider
            label="Day Length (Minutes)"
            value={dayNight.cycle.dayLength}
            onChange={(v) => updateGameplay("dayNight.cycle.dayLength", v)}
            min={5}
            max={120}
          />

          <DWSlider
            label="Night Length (Minutes)"
            value={dayNight.cycle.nightLength}
            onChange={(v) => updateGameplay("dayNight.cycle.nightLength", v)}
            min={5}
            max={120}
          />

          <DWSlider
            label="Red Eclipse Intensity"
            value={dayNight.cycle.eclipseIntensity}
            onChange={(v) => updateGameplay("dayNight.cycle.eclipseIntensity", v)}
            min={0}
            max={100}
          />
        </RuneSection>
      </RuneStagger>

      <RuneStagger index={1}>
        <RuneSection title="Season System">
          <DWSlider
            label="Season Length (Days)"
            value={dayNight.season.length}
            onChange={(v) => updateGameplay("dayNight.season.length", v)}
            min={5}
            max={120}
          />

          <DWToggle
            label="Enable Seasonal Boosts"
            value={dayNight.season.boost}
            onChange={(v) => updateGameplay("dayNight.season.boost", v)}
          />
        </RuneSection>
      </RuneStagger>

      <RuneStagger index={2}>
        <RuneSection title="Weather & Atmosphere">
          <DWSlider
            label="Weather Randomness"
            value={dayNight.weather.randomness}
            onChange={(v) => updateGameplay("dayNight.weather.randomness", v)}
            min={0}
            max={100}
          />

          <DWSlider
            label="Storm Chance (%)"
            value={dayNight.weather.stormChance}
            onChange={(v) => updateGameplay("dayNight.weather.stormChance", v)}
            min={0}
            max={100}
          />

          <DWSlider
            label="Fog Density (%)"
            value={dayNight.weather.fogDensity}
            onChange={(v) => updateGameplay("dayNight.weather.fogDensity", v)}
            min={0}
            max={100}
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
