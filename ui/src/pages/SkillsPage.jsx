import { useGameData } from "../data/useGameData";
import { useModding } from "../modding/useModding";
import { DEFAULT_SKILLS } from "../modding/gameplayDefaults";
import { useToast } from "../modding/useToast";

import PageHeader from "../components/ui/PageHeader";
import RuneSection from "../components/ui/RuneSection";
import RuneStagger from "../components/ui/RuneStagger";

import DWSlider from "../components/ui/DWSlider";
import DWToggle from "../components/ui/DWToggle";
import DWSelect from "../components/ui/DWSelect";
import DWButton from "../components/ui/DWButton";

export default function SkillsPage() {
  const game = useGameData();
  const { gameplay, updateGameplay, savePreset } = useModding();
  const toast = useToast();
  const { skills } = gameplay;

  if (game.loading) {
    return <p style={{ opacity: 0.8 }}>Loading skill data…</p>;
  }

  function handleSave() {
    savePreset("Skills Settings Save");
    toast.push({ type: "success", text: "Saved Skills settings preset" });
  }

  function handleReset() {
    updateGameplay("skills", DEFAULT_SKILLS);
    toast.push({ type: "success", text: "Skills settings reset to defaults" });
  }

  return (
    <div>
      <PageHeader title="Skills & Progression" />

      {/* Rune‑staggered sections */}
      <RuneStagger index={0}>
        <RuneSection title="Skill Point Allocation">
          <DWSlider
            label="Available Skill Points"
            value={skills.points.skillPoints}
            onChange={(v) => updateGameplay("skills.points.skillPoints", v)}
            min={0}
            max={100}
          />

          <DWSlider
            label="Passive Boost Strength"
            value={skills.points.passiveBoost}
            onChange={(v) => updateGameplay("skills.points.passiveBoost", v)}
            min={0}
            max={50}
          />

          <DWSlider
            label="Skill Unlock Rate"
            value={skills.points.unlockRate}
            onChange={(v) => updateGameplay("skills.points.unlockRate", v)}
            min={0}
            max={200}
          />

          <DWToggle
            label="Enable Hybrid Skills"
            value={skills.points.hybridSkills}
            onChange={(v) => updateGameplay("skills.points.hybridSkills", v)}
          />

          <DWSelect
            label="Skill Preset"
            value={skills.points.skillPreset}
            onChange={(v) => updateGameplay("skills.points.skillPreset", v)}
            options={["Balanced", "Aggressive", "Defensive", "Nightfall"]}
          />
        </RuneSection>
      </RuneStagger>

      <RuneStagger index={1}>
        <RuneSection title="Combat Skill Attributes">
          <DWSlider
            label="Magic Power"
            value={skills.attributes.magicPower}
            onChange={(v) => updateGameplay("skills.attributes.magicPower", v)}
            min={0}
            max={200}
          />

          <DWSlider
            label="Weapon Mastery"
            value={skills.attributes.weaponMastery}
            onChange={(v) => updateGameplay("skills.attributes.weaponMastery", v)}
            min={0}
            max={200}
          />

          <DWSlider
            label="Stealth Rating"
            value={skills.attributes.stealthRating}
            onChange={(v) => updateGameplay("skills.attributes.stealthRating", v)}
            min={0}
            max={200}
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
