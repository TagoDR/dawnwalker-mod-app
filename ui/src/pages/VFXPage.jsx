import PageHeader from "../components/ui/PageHeader";
import RuneSection from "../components/ui/RuneSection";
import RuneStagger from "../components/ui/RuneStagger";
import DWSlider from "../components/ui/DWSlider";
import DWToggle from "../components/ui/DWToggle";
import DWButton from "../components/ui/DWButton";
import { useVFX } from "../vfx/core/VFXContext";
import { useGameData } from "../data/useGameData";
import { useModding } from "../modding/useModding";
import { DEFAULT_VFX } from "../modding/gameplayDefaults";
import { useToast } from "../modding/useToast";

const sliders = [
  ["ambientHaze", "Ambient Haze"],
  ["dawnRays", "Dawn Rays"],
  ["dawnParticles", "Dawn Particles"],
  ["nightfallMist", "Nightfall Mist"],
  ["corruptionFog", "Corruption Fog"],
  ["themeSwitchFlare", "Theme Switch Flare"],
  ["corruptionPulse", "Corruption Pulse"],
  ["runeStagger", "Rune Stagger"],
];

export default function VFXPage() {
  const game = useGameData();
  const { corruption, intensity, setCorruption, setIntensity } = useVFX();
  const { updateGameplay, savePreset } = useModding();
  const toast = useToast();

  if (game.loading) {
    return <p style={{ opacity: 0.8 }}>Loading VFX settings…</p>;
  }

  function handleSave() {
    savePreset("VFX Settings Save");
    toast.push({ type: "success", text: "Saved VFX settings preset" });
  }

  function handleReset() {
    updateGameplay("vfx", DEFAULT_VFX);
    toast.push({ type: "success", text: "VFX settings reset to defaults" });
  }

  const renderSlider = ([effect, label]) => (
    <DWSlider
      key={effect}
      label={`${label} Intensity (%)`}
      max={100}
      min={0}
      onChange={(value) => setIntensity(effect, value)}
      value={intensity[effect]}
    />
  );

  return (
    <div>
      <PageHeader title="Visual Effects" />

      <RuneStagger index={0}>
        <RuneSection title="Dawn & Night Atmosphere">
          {sliders.slice(0, 4).map(renderSlider)}
        </RuneSection>
      </RuneStagger>

      <RuneStagger index={1}>
        <RuneSection title="Spell Events">
          {sliders.slice(5).map(renderSlider)}
        </RuneSection>
      </RuneStagger>

      <RuneStagger index={2}>
        <RuneSection title="Corruption">
          {renderSlider(sliders[4])}
          <DWToggle
            label="Preview Corruption"
            onChange={setCorruption}
            value={corruption}
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
