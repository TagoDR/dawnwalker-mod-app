import { useEffect, useState, useMemo, useCallback } from "react";
import { ModdingContext } from "./ModdingContext";
import { createUnavailableGameplayAdapter } from "./gameplayAdapter";
import { mergeGameplayState } from "./mergeGameplayState";
import {
  DEFAULT_ADVANCED,
  DEFAULT_COMBAT,
  DEFAULT_DAYNIGHT,
  DEFAULT_MOVEMENT,
  DEFAULT_SKILLS,
  DEFAULT_VFX
} from "./gameplayDefaults";

const STORAGE_KEY = "dawnwalker-modding-v1";

const DEFAULT_GAMEPLAY = {
  xpMultiplier: 1.0,
  levelMultiplier: 1.0,
  skillPointMultiplier: 1.0,
  maxLevelUnlocked: 50,
  timer: { enabled: true, dayLimit: 30, speedMultiplier: 1.0, frozen: false },
  difficulty: "normal",
  enemyScalingMultiplier: 1.0,
  autoSaveIntervalMinutes: 10,
  // optional gameplay fields used by UI but not in base schema
  stamina: 100,
  cooldown: 0,
  movementSpeed: 100,
  corruptionGain: 100,
  resolveGain: 100,
  allowHybrid: true,
  eclipseIntensity: 50,
  allowTimerExtensions: true,
  // per-page namespaced settings
  advanced: DEFAULT_ADVANCED,
  combat: DEFAULT_COMBAT,
  dayNight: DEFAULT_DAYNIGHT,
  movement: DEFAULT_MOVEMENT,
  skills: DEFAULT_SKILLS,
  vfx: DEFAULT_VFX
};

// Reads persisted state once; returns null when nothing is stored yet or parsing fails
function readPersistedState() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    return JSON.parse(raw);
  } catch (e) {
    console.warn("[Modding] Failed to load modding state", e);
    return null;
  }
}

export function ModdingProvider({ children }) {
  const adapter = useMemo(() => createUnavailableGameplayAdapter(), []);
  const [gameplay, setGameplay] = useState(() => {
    const parsed = readPersistedState();
    return parsed?.gameplay ? mergeGameplayState(DEFAULT_GAMEPLAY, parsed.gameplay) : DEFAULT_GAMEPLAY;
  });

  const [presets, setPresets] = useState(() => {
    const parsed = readPersistedState();
    if (Array.isArray(parsed?.presets) && parsed.presets.length > 0) return parsed.presets;

    const starterGameplay = parsed?.gameplay ? mergeGameplayState(DEFAULT_GAMEPLAY, parsed.gameplay) : DEFAULT_GAMEPLAY;
    const starter = {
      name: "Starter Preset",
      createdAt: new Date().toISOString(),
      data: { gameplay: starterGameplay }
    };
    return [starter];
  });

  // Persist whenever gameplay or presets change
  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify({ gameplay, presets }));
    } catch (e) {
      console.warn("[Modding] Failed to persist modding state", e);
    }
  }, [gameplay, presets]);

  const updateGameplay = useCallback((path, value) => {
    setGameplay((prev) => {
      const next = { ...prev };
      const parts = path.split(".");
      let cur = next;
      for (let i = 0; i < parts.length - 1; i++) {
        const p = parts[i];
        cur[p] = { ...(cur[p] || {}) };
        cur = cur[p];
      }
      cur[parts[parts.length - 1]] = value;
      return next;
    });
  }, []);

  const savePreset = useCallback((name = `Preset ${new Date().toISOString()}`) => {
    const preset = {
      name,
      createdAt: new Date().toISOString(),
      data: { gameplay }
    };
    setPresets((p) => [preset, ...p].slice(0, 50));
  }, [gameplay]);

  const loadPreset = useCallback((index) => {
    const preset = presets[index];
    if (preset && preset.data && preset.data.gameplay) {
      setGameplay((g) => mergeGameplayState(g, preset.data.gameplay));
    } else {
      console.warn("[Modding] loadPreset failed: invalid index or preset data");
    }
  }, [presets]);

  const removePreset = useCallback((index) => {
    setPresets((p) => p.filter((_, i) => i !== index));
  }, []);

  const exportAll = useCallback(() => {
    return JSON.stringify({ gameplay, presets }, null, 2);
  }, [gameplay, presets]);

  const importAll = useCallback((jsonString) => {
    try {
      const parsed = JSON.parse(jsonString);
      if (parsed.gameplay) setGameplay((g) => mergeGameplayState(g, parsed.gameplay));
      if (Array.isArray(parsed.presets)) setPresets(parsed.presets);
      return true;
    } catch (e) {
      console.warn("[Modding] Failed to import mod data", e);
      return false;
    }
  }, []);

  const resetGameplay = useCallback(() => {
    setGameplay(DEFAULT_GAMEPLAY);
  }, []);

  const value = useMemo(
    () => ({
      gameplay,
      updateGameplay,
      savePreset,
      presets,
      loadPreset,
      removePreset,
      exportAll,
      importAll,
      resetGameplay,
      adapter
    }),
    [gameplay, presets, updateGameplay, savePreset, loadPreset, removePreset, exportAll, importAll, resetGameplay, adapter]
  );

  return <ModdingContext.Provider value={value}>{children}</ModdingContext.Provider>;
}

