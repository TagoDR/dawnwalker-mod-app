import { useEffect, useState } from "react";
import { useTheme } from "../theme/useTheme";
import { useGameData } from "../data/useGameData";
import { useModding } from "../modding/useModding";

import PageHeader from "../components/ui/PageHeader";
import RuneSection from "../components/ui/RuneSection";
import RuneStagger from "../components/ui/RuneStagger";
import DWSlider from "../components/ui/DWSlider";
import DWToggle from "../components/ui/DWToggle";
import DWSelect from "../components/ui/DWSelect";
import DWButton from "../components/ui/DWButton";

// Talks to the UE4SS bridge mod (runtime-mods/DawnwalkerModBridge) through the Electron main process.
// This is the only section on this page that actually changes the running game; everything
// else on this page is a cosmetic profile stored in localStorage.
function LiveGameBridge() {
  const { theme } = useTheme();
  const bridge = typeof window !== "undefined" ? window.dawnwalker : null;
  const [status, setStatus] = useState(null);
  const [levelInput, setLevelInput] = useState(20);
  const [levelCapInput, setLevelCapInput] = useState(99);
  const [infiniteHealth, setInfiniteHealth] = useState(false);
  const [infiniteStamina, setInfiniteStamina] = useState(false);
  const [speedMultiplier, setSpeedMultiplier] = useState(1);
  const [jumpMultiplier, setJumpMultiplier] = useState(1);
  const [fovMultiplier, setFovMultiplier] = useState(1);
  const [gameSpeed, setGameSpeed] = useState(1);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState(null);

  useEffect(() => {
    if (!bridge) return undefined;
    let cancelled = false;
    const poll = async () => {
      try {
        const result = await bridge.bridgeStatus();
        if (!cancelled) setStatus(result);
      } catch {
        if (!cancelled) setStatus({ ok: false, error: "Failed to reach the bridge" });
      }
    };
    poll();
    const interval = setInterval(poll, 3000);
    return () => {
      cancelled = true;
      clearInterval(interval);
    };
  }, [bridge]);

  // Re-hydrate the sliders/toggles from the actual last-applied values: this page mounts fresh
  // every time the user navigates back to it, so without this everything would appear reset to
  // its default (1x/off) even though the game is still running with the real values applied.
  useEffect(() => {
    if (!bridge) return;
    let cancelled = false;
    (async () => {
      try {
        const state = await bridge.getBridgeCommandState();
        if (cancelled || !state) return;
        if (state.setLevel !== undefined) setLevelInput(Number(state.setLevel));
        if (state.levelCap !== undefined) setLevelCapInput(Number(state.levelCap));
        if (state.infiniteHealth !== undefined) setInfiniteHealth(state.infiniteHealth === "1" || state.infiniteHealth === 1);
        if (state.infiniteStamina !== undefined) setInfiniteStamina(state.infiniteStamina === "1" || state.infiniteStamina === 1);
        if (state.speedMultiplier !== undefined) setSpeedMultiplier(Number(state.speedMultiplier));
        if (state.jumpMultiplier !== undefined) setJumpMultiplier(Number(state.jumpMultiplier));
        if (state.fovMultiplier !== undefined) setFovMultiplier(Number(state.fovMultiplier));
        if (state.gameSpeed !== undefined) setGameSpeed(Number(state.gameSpeed));
      } catch {
        // Non-fatal: controls just fall back to their hardcoded defaults.
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [bridge]);

  if (!bridge) {
    return <p style={{ opacity: 0.78 }}>The live game bridge is only available in the desktop app.</p>;
  }

  const deployed = status?.deployed;

  const handleDeploy = async () => {
    setBusy(true);
    setMessage(null);
    const result = await bridge.deployBridge();
    setMessage(result.ok ? "Bridge mod deployed. Restart the game if it's already running." : result.error);
    setBusy(false);
  };

  const handleSetLevel = async () => {
    setBusy(true);
    setMessage(null);
    const result = await bridge.applyLevel(levelInput);
    setMessage(result.ok ? "Level change sent to the game." : result.error);
    setBusy(false);
  };

  const handleSetLevelCap = async () => {
    setBusy(true);
    setMessage(null);
    const result = await bridge.applyLevelCap(levelCapInput);
    setMessage(result.ok ? "Level cap change sent to the game." : result.error);
    setBusy(false);
  };

  const handleGiveBestGear = async () => {
    setBusy(true);
    setMessage(null);
    const result = await bridge.giveBestGear();
    setMessage(result.ok ? "Best gear request sent to the game." : result.error);
    setBusy(false);
  };

  const handleToggleInfiniteHealth = async (value) => {
    setInfiniteHealth(value);
    const result = await bridge.applyInfiniteHealth(value);
    setMessage(result.ok ? null : result.error);
  };

  const handleToggleInfiniteStamina = async (value) => {
    setInfiniteStamina(value);
    const result = await bridge.applyInfiniteStamina(value);
    setMessage(result.ok ? null : result.error);
  };

  const handleSpeedMultiplier = async (value) => {
    setSpeedMultiplier(value);
    const result = await bridge.applySpeedMultiplier(value);
    setMessage(result.ok ? null : result.error);
  };

  const handleJumpMultiplier = async (value) => {
    setJumpMultiplier(value);
    const result = await bridge.applyJumpMultiplier(value);
    setMessage(result.ok ? null : result.error);
  };

  const handleFovMultiplier = async (value) => {
    setFovMultiplier(value);
    const result = await bridge.applyFovMultiplier(value);
    setMessage(result.ok ? null : result.error);
  };

  const handleGameSpeed = async (value) => {
    setGameSpeed(value);
    const result = await bridge.applyGameSpeed(value);
    setMessage(result.ok ? null : result.error);
  };

  return (
    <RuneSection title="Live Game Bridge (UE4SS)">
      <p style={{ opacity: 0.78, marginBottom: 12 }}>
        Applies real changes to a running game via the DawnwalkerModBridge UE4SS mod. Verified against
        <code> CharacterDevelopmentSubsystem</code> and <code>DogwoodCharacterDevelopmentSettings</code>.
      </p>
      <p style={{ opacity: 0.85, marginBottom: 12, color: theme.colors.gold }}>
        Stay at or below 99. The game's level/XP tables don't have entries above that, and requesting a
        higher level can crash the game.
      </p>

      <p>Game running: {status?.gameRunning ? "Yes" : "No"}</p>
      <p>Bridge mod deployed: {deployed ? "Yes" : "No"}</p>
      {deployed && (
        <>
          <p>Current level: {status?.currentLevel ?? "unknown"}</p>
          <p>Current XP: {status?.currentXP ?? "unknown"}</p>
          <p>Level cap: {status?.levelCap ?? "unknown"}</p>
          <p>Health: {status?.healthPercent ?? "unknown"}</p>
          <p>Stamina: {status?.staminaPercent ?? "unknown"}</p>
          <p>Walk speed: {status?.movementFound ? "tracked" : "unknown"}</p>
          <p>Give best gear result: {status?.giveBestGearResult ?? "not yet requested"}</p>
        </>
      )}
      {message && <p style={{ color: theme.colors.gold }}>{message}</p>}

      {!deployed ? (
        <DWButton label="Deploy Bridge Mod" onClick={handleDeploy} disabled={busy} data-clickpulse data-glow />
      ) : (
        <div style={{ display: "flex", flexDirection: "column", gap: 12, marginTop: 8 }}>
          <div style={{ display: "flex", gap: 12, alignItems: "center" }}>
            <DWSlider label="Set Player Level" value={levelInput} onChange={setLevelInput} min={1} max={99} />
            <DWButton label="Apply Level" onClick={handleSetLevel} disabled={busy} data-clickpulse data-glow />
          </div>
          <div style={{ display: "flex", gap: 12, alignItems: "center" }}>
            <DWSlider label="Level Cap" value={levelCapInput} onChange={setLevelCapInput} min={1} max={99} />
            <DWButton label="Apply Level Cap" onClick={handleSetLevelCap} disabled={busy} data-clickpulse data-glow />
          </div>
          <DWToggle label="Infinite Health" value={infiniteHealth} onChange={handleToggleInfiniteHealth} />
          <DWToggle label="Infinite Stamina" value={infiniteStamina} onChange={handleToggleInfiniteStamina} />
          <DWSlider
            label="Player Speed Multiplier"
            value={speedMultiplier}
            onChange={handleSpeedMultiplier}
            min={0.1}
            max={5}
            step={0.1}
          />
          <DWSlider
            label="Jump Height Multiplier"
            value={jumpMultiplier}
            onChange={handleJumpMultiplier}
            min={0.1}
            max={5}
            step={0.1}
          />
          <DWSlider
            label="Field of View Multiplier"
            value={fovMultiplier}
            onChange={handleFovMultiplier}
            min={0.1}
            max={5}
            step={0.1}
          />
          <DWSlider
            label="Game Speed"
            value={gameSpeed}
            onChange={handleGameSpeed}
            min={0.1}
            max={4}
            step={0.1}
          />
          <div style={{ display: "flex", gap: 12, alignItems: "center" }}>
            <DWButton
              label="Give Best Gear (disabled)"
              onClick={handleGiveBestGear}
              disabled
              data-clickpulse
              data-glow
            />
            <span style={{ opacity: 0.78, fontSize: "0.9em" }}>
              Temporarily disabled: this granted the wrong item (a "Bee Smoker" quest item) instead
              of the intended gear, flooding inventories. Do not re-enable until the underlying
              GetItemHandle bug is fixed.
            </span>
          </div>
        </div>
      )}
    </RuneSection>
  );
}

export default function GameplayPage() {
  const game = useGameData();
  const {
    gameplay,
    updateGameplay,
    savePreset,
    presets,
    loadPreset,
    resetGameplay
  } = useModding();

  if (game.loading) return <p style={{ opacity: 0.8 }}>Loading game data…</p>;

  return (
    <div>
      <PageHeader title="Gameplay Profile" />

      <RuneStagger index={0}>
        <LiveGameBridge />
      </RuneStagger>

      <RuneStagger index={1}>
        <RuneSection title="Core Gameplay Settings">
          <DWSlider label="XP Gain Multiplier" value={gameplay.xpMultiplier} onChange={(v) => updateGameplay("xpMultiplier", v)} min={0} max={500} />
          <DWSlider label="Stamina Regeneration" value={gameplay.stamina} onChange={(v) => updateGameplay("stamina", v)} min={0} max={200} />
          <DWSlider label="Ability Cooldown Reduction" value={gameplay.cooldown} onChange={(v) => updateGameplay("cooldown", v)} min={0} max={100} />
          <DWSlider label="Movement Speed" value={gameplay.movementSpeed} onChange={(v) => updateGameplay("movementSpeed", v)} min={50} max={300} />
          <DWToggle label="Enable Debug Mode" value={gameplay.debug ?? false} onChange={(v) => updateGameplay("debug", v)} />
          <DWSelect label="Difficulty Preset" value={gameplay.difficulty} onChange={(v) => updateGameplay("difficulty", v)} options={["story","normal","hard","nightfall"]} />
        </RuneSection>
      </RuneStagger>

      <RuneStagger index={2}>
        <RuneSection title="Corruption & Resolve">
          <DWSlider label="Corruption Gain Rate" value={gameplay.corruptionGain} onChange={(v) => updateGameplay("corruptionGain", v)} min={0} max={300} />
          <DWSlider label="Resolve Gain Rate" value={gameplay.resolveGain} onChange={(v) => updateGameplay("resolveGain", v)} min={0} max={300} />
          <DWToggle label="Allow Hybrid Skills" value={gameplay.allowHybrid} onChange={(v) => updateGameplay("allowHybrid", v)} />
        </RuneSection>
      </RuneStagger>

      <RuneStagger index={3}>
        <RuneSection title="Day / Night Cycle">
          <DWSlider label="Day Length (Minutes)" value={gameplay.timer.dayLimit} onChange={(v) => updateGameplay("timer.dayLimit", v)} min={5} max={120} />
          <DWSlider label="Night Length (Minutes)" value={gameplay.timer.nightLength ?? gameplay.timer.dayLimit} onChange={(v) => updateGameplay("timer.nightLength", v)} min={5} max={120} />
          <DWSlider label="Red Eclipse Intensity" value={gameplay.eclipseIntensity} onChange={(v) => updateGameplay("eclipseIntensity", v)} min={0} max={100} />
        </RuneSection>
      </RuneStagger>

      <RuneStagger index={4}>
        <RuneSection title="Story Timer">
          <DWSlider label="Days Remaining" value={gameplay.timer.dayLimit} onChange={(v) => updateGameplay("timer.dayLimit", v)} min={0} max={30} />
          <DWToggle label="Pause Countdown" value={gameplay.timer.frozen} onChange={(v) => updateGameplay("timer.frozen", v)} />
          <DWToggle label="Allow Timer Extensions" value={gameplay.allowTimerExtensions ?? true} onChange={(v) => updateGameplay("allowTimerExtensions", v)} />
        </RuneSection>
      </RuneStagger>

      <div style={{ marginTop: 18, display: "flex", gap: 12 }}>
        <DWButton label="Save Preset" onClick={() => savePreset("Manual Save")} data-clickpulse data-glow />
        <DWButton label="Reset to Defaults" onClick={resetGameplay} />
        <DWSelect
          label="Load Preset"
          value={""}
          onChange={(v) => {
            const idx = parseInt(v, 10);
            if (!Number.isNaN(idx)) loadPreset(idx);
          }}
          options={presets.map((p, i) => `${i}: ${p.name}`)}
        />
      </div>
    </div>
  );
}
