import { useCallback, useEffect, useMemo, useState } from "react";
import { VFXContext } from "./VFXContext";

// The app's own UI visual-effect settings (not game state). Persisted locally so the chosen
// intensities survive an app restart.
const STORAGE_KEY = "dawnwalker-vfx-v1";

const DEFAULT_VFX = {
  corruption: false,
  intensity: {
    ambientHaze: 55,
    dawnRays: 60,
    dawnParticles: 70,
    nightfallMist: 55,
    corruptionFog: 50,
    themeSwitchFlare: 75,
    corruptionPulse: 75,
    runeStagger: 65,
  },
};

function readPersisted() {
  try {
    const parsed = JSON.parse(localStorage.getItem(STORAGE_KEY) || "null");
    if (!parsed || typeof parsed !== "object") return DEFAULT_VFX;
    return {
      corruption: Boolean(parsed.corruption),
      intensity: { ...DEFAULT_VFX.intensity, ...(parsed.intensity || {}) },
    };
  } catch {
    return DEFAULT_VFX;
  }
}

export default function VFXProvider({ theme, children }) {
  const [vfx, setVfx] = useState(readPersisted);

  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(vfx));
    } catch (error) {
      console.warn("[VFX] Failed to persist settings", error);
    }
  }, [vfx]);

  const setCorruption = useCallback((value) => setVfx((prev) => ({ ...prev, corruption: value })), []);
  const setEffectIntensity = useCallback(
    (effect, value) => setVfx((prev) => ({ ...prev, intensity: { ...prev.intensity, [effect]: value } })),
    []
  );
  const resetVfx = useCallback(() => setVfx(DEFAULT_VFX), []);

  const value = useMemo(
    () => ({
      theme,
      corruption: vfx.corruption,
      setCorruption,
      intensity: vfx.intensity,
      setIntensity: setEffectIntensity,
      resetVfx,
    }),
    [theme, vfx, setCorruption, setEffectIntensity, resetVfx]
  );

  return <VFXContext.Provider value={value}>{children}</VFXContext.Provider>;
}
