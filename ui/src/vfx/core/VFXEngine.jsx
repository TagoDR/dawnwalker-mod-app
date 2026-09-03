import VFXLayer from "./VFXLayer";
import { useVFX } from "./VFXContext";
import AmbientHaze from "./effects/AmbientHaze";
import CorruptionFog from "./effects/CorruptionFog";
import CorruptionPulse from "./effects/CorruptionPulse";
import DawnParticles from "./effects/DawnParticles";
import DawnRays from "./effects/DawnRays";
import NightfallMist from "./effects/NightfallMist";
import RuneStagger from "./effects/RuneStagger";
import ThemeSwitchFlare from "./effects/ThemeSwitchFlare";

export default function VFXEngine({ page }) {
  const vfx = useVFX();
  const mode = vfx?.theme?.mode;
  const intensity = vfx.intensity;
  const isDawn = mode === "dawn";
  const isNightfall = mode === "nightfall";

  return (
    <>
      <VFXLayer id="ambient">
        <AmbientHaze intensity={intensity.ambientHaze} />
      </VFXLayer>

      <VFXLayer id="theme">
        {isDawn && (
          <>
            <DawnRays intensity={intensity.dawnRays} />
            <DawnParticles intensity={intensity.dawnParticles} />
          </>
        )}
        {isNightfall && <NightfallMist intensity={intensity.nightfallMist} />}
      </VFXLayer>

      {vfx.corruption && (
        <VFXLayer id="corruption">
          <CorruptionFog intensity={intensity.corruptionFog} />
        </VFXLayer>
      )}

      <VFXLayer id="theme-switch">
        <ThemeSwitchFlare theme={mode} intensity={intensity.themeSwitchFlare} />
      </VFXLayer>

      <VFXLayer id="corruption-pulse">
        <CorruptionPulse
          corruption={vfx.corruption}
          intensity={intensity.corruptionPulse}
        />
      </VFXLayer>

      <VFXLayer id="transition">
        <RuneStagger trigger={page} intensity={intensity.runeStagger} />
      </VFXLayer>
    </>
  );
}
