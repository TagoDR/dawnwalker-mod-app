# Developer onboarding guide

This project is a runtime-sensitive desktop app for Dawnwalker that communicates with a live UE4SS bridge. It is not a generic settings-only UI and it should not behave like one.

## Core architecture

The app is split into a few layers:

- Electron main process: manages the desktop app and bridge command file writes.
- React UI: reads live status and sends state changes to the bridge.
- Lua bridge: reads command.txt, applies safe runtime changes, and writes status.txt.
- Runtime validation layer: central sanitization for bridge fields and actions.

## Important design constraints

### 1. Defaults-first behavior

The app intentionally does not restore stale UI state on launch. Every game launch starts at the game defaults. The UI can apply a preset only after the game is loaded and the bridge has acknowledged the current boot.

### 2. Boot-ID handshake

The bridge only trusts commands that match the current boot. Out-of-date command files are ignored.

### 3. Heartbeat + close reset

The app writes a heartbeat while it is alive. If the heartbeat stops, or if the app is closing and writes `appClosed=1`, the Lua bridge releases any runtime override and restores default behavior.

### 4. Cutscene safety

Bridge writes are paused during cutscenes or other unsafe transitions. This prevents the app from writing while the game is unstable.

### 5. Validation happens before writes

The app must validate every field before writing to the bridge. Unknown keys, invalid numeric ranges, and unsupported actions must be rejected.

## Where to look first

- `index.js`: Electron bridge orchestration and command/status handling
- `bridge-protocol.js`: shared field and action validators
- `runtime-mods/DawnwalkerModBridge/Scripts/main.lua`: runtime Lua behavior and safety enforcement
- `ui/src/bridge/useBridge.js`: React-side bridge integration with polling and state hydration
- `ui/src/bridge/BridgePanel.jsx`: bridge status and reset UI

## How to work safely

1. Treat `status.txt` as the authoritative runtime status.
2. Treat `command.txt` as the current requested state.
3. Never rely on browser local state to drive live game behavior.
4. Keep all new fields/commands aligned with the bridge validator.
5. Use boot-aware writes and heartbeat-safe resets.
6. Avoid unsupported or speculative game mutations.

## What not to do

- Do not reintroduce localStorage-based gameplay persistence as the primary runtime source.
- Do not send arbitrary nested JSON payloads to the bridge.
- Do not bypass the validator.
- Do not write runtime commands during cutscenes or unknown world states.
- Do not assume the game is always safe to modify.

## Verification checklist

Before considering a change safe:

- status file still reports correct values
- command file still uses the required flat key/value format
- heartbeat and boot handshake still work
- app close still resets the bridge state
- no stale writes survive a reboot
- lint/build/tests still pass

## Useful commands

```bash
npm --prefix ui run lint
npm --prefix ui run build
node --test
```

## Safety principle

This app is a runtime control layer for a live game, not a generic mod menu. The highest priority is always safe default behavior and stale-state prevention.
