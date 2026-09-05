import { useCallback, useEffect, useRef, useState } from "react";

// Shared access to the UE4SS bridge (runtime-mods/DawnwalkerModBridge) via the Electron preload.
// - `status` is the game-reported status.txt, polled every 3s.
// - `command` mirrors the main process's desired-state (command.txt) so controls can re-hydrate
//   after a page remount instead of snapping back to defaults.
// - Every game launch (and every app start) begins at the game's defaults: when the main process
//   sees a new game boot it drops all settings, and this hook re-hydrates so the controls follow.
export function useBridge() {
  const bridge = typeof window !== "undefined" ? window.dawnwalker : null;
  const [status, setStatus] = useState(null);
  const [command, setCommand] = useState(null);
  const [message, setMessage] = useState(null);
  const [busy, setBusy] = useState(false);
  const mounted = useRef(true);
  const seenBootResets = useRef(null);

  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
    };
  }, []);

  const refreshCommand = useCallback(async () => {
    if (!bridge) return;
    try {
      const state = await bridge.getBridgeCommandState();
      if (mounted.current) setCommand(state || {});
    } catch {
      if (mounted.current) setCommand({});
    }
  }, [bridge]);

  useEffect(() => {
    if (!bridge) return undefined;
    let cancelled = false;
    const poll = async () => {
      try {
        const result = await bridge.bridgeStatus();
        if (cancelled) return;
        setStatus(result);
        const resets = result?.bootResets;
        if (resets !== undefined && resets !== seenBootResets.current) {
          const isRestart = seenBootResets.current !== null && resets > seenBootResets.current;
          seenBootResets.current = resets;
          refreshCommand();
          if (isRestart) setMessage("The game restarted - everything is back at game defaults. Apply a preset once you're loaded in.");
        }
      } catch {
        if (!cancelled) setStatus({ ok: false, error: "Failed to reach the bridge" });
      }
    };
    // Hydrate the controls first so they never flash their hardcoded defaults on remount.
    const start = async () => {
      await refreshCommand();
      if (!cancelled) await poll();
    };
    start();
    const interval = setInterval(poll, 3000);
    return () => {
      cancelled = true;
      clearInterval(interval);
    };
  }, [bridge, refreshCommand]);

  const deploy = useCallback(async () => {
    if (!bridge) return { ok: false };
    setBusy(true);
    setMessage(null);
    const result = await bridge.deployBridge();
    if (mounted.current) {
      setMessage(result.ok ? "Bridge mod deployed. Restart the game if it's already running." : result.error);
      setBusy(false);
    }
    return result;
  }, [bridge]);

  const applyField = useCallback(async (key, value) => {
    if (!bridge) return { ok: false };
    setCommand((prev) => ({ ...(prev || {}), [key]: value }));
    const result = await bridge.applyBridgeField(key, value);
    if (mounted.current) setMessage(result.ok ? null : result.error);
    return result;
  }, [bridge]);

  const runAction = useCallback(async (name, arg, sentMessage = "Request sent to the game.") => {
    if (!bridge) return { ok: false };
    setBusy(true);
    setMessage(null);
    const result = await bridge.runBridgeAction(name, arg);
    if (mounted.current) {
      setMessage(result.ok ? sentMessage : result.error);
      setBusy(false);
    }
    return result;
  }, [bridge]);

  const applyPreset = useCallback(async (values) => {
    if (!bridge) return { ok: false };
    const result = await bridge.applyBridgePreset(values);
    if (result.ok) setCommand((prev) => ({ ...(prev || {}), ...values }));
    if (mounted.current) setMessage(result.ok ? "Preset applied to the game." : result.error);
    return result;
  }, [bridge]);

  const resetAll = useCallback(async () => {
    if (!bridge) return { ok: false };
    setBusy(true);
    const result = await bridge.resetBridge();
    if (mounted.current) {
      setCommand({});
      setMessage(result.ok ? "All live settings cleared - the game is back at its defaults." : result.error);
      setBusy(false);
    }
    return result;
  }, [bridge]);

  return { bridge, status, command, message, setMessage, busy, setBusy, deploy, applyField, runAction, applyPreset, resetAll };
}

// Helpers for reading command.txt values (all stored as strings) back into control state.
export function commandNumber(command, key, fallback) {
  const value = Number(command?.[key]);
  return Number.isFinite(value) && command?.[key] !== undefined && command?.[key] !== "" ? value : fallback;
}

export function commandFlag(command, key) {
  const value = command?.[key];
  return value === 1 || value === "1" || value === true;
}

export function commandString(command, key, fallback) {
  const value = command?.[key];
  return value === undefined || value === null || value === "" ? fallback : String(value);
}

export function formatReadout(value) {
  if (value === undefined || value === null || value === "") return "—";
  const numeric = Number(value);
  if (Number.isFinite(numeric) && String(value).includes(".")) return numeric.toFixed(2);
  return String(value);
}
