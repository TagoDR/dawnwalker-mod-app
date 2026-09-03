import { useMemo, useCallback } from "react";
import { VFXContext } from "./VFXContext";
import { useModding } from "../../modding/useModding";

export default function VFXProvider({ theme, children }) {
  const { gameplay, updateGameplay } = useModding();
  const { corruption, intensity } = gameplay.vfx;

  const setCorruption = useCallback(
    (value) => updateGameplay("vfx.corruption", value),
    [updateGameplay]
  );

  // Update intensity for a single effect
  const setEffectIntensity = useCallback(
    (effect, value) => updateGameplay(`vfx.intensity.${effect}`, value),
    [updateGameplay]
  );

  const value = useMemo(
    () => ({
      theme,
      corruption,
      setCorruption,
      intensity,
      setIntensity: setEffectIntensity
    }),
    [theme, corruption, intensity, setCorruption, setEffectIntensity],
  );

  return <VFXContext.Provider value={value}>{children}</VFXContext.Provider>;
}
