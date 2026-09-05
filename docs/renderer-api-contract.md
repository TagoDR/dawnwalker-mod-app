# Renderer API contract

The Electron renderer exposes a single frozen API object on `window.dawnwalker`.

This API is intentionally small and intentionally flat. The renderer is not allowed to access the filesystem, the game install, or the native runtime directly. Every call is routed through IPC to the main process, which then validates and forwards the request through the UE4SS bridge.

## Security model

- `contextBridge.exposeInMainWorld()` is used
- `nodeIntegration` is disabled
- `contextIsolation` is enabled
- `sandbox` is enabled
- the exposed object is frozen to prevent accidental mutation

This keeps the renderer constrained to a safe request/response interface.

## Public methods

### Installation and scanning

- `scanInstall()`
- `backupUserData()`
- `compareSaves(leftName, rightName)`

### Bridge lifecycle

- `deployBridge()`
- `bridgeStatus()`
- `getBridgeCommandState()`
- `resetBridge()`

### Persistent bridge writes

- `applyLevel(level)`
- `applyLevelCap(cap)`
- `applyInfiniteHealth(enabled)`
- `applyInfiniteStamina(enabled)`
- `applySpeedMultiplier(mult)`
- `applyJumpMultiplier(mult)`
- `applyFovMultiplier(mult)`
- `applyGameSpeed(speed)`
- `applyDamageAmplifier(value)`
- `applyBridgeField(key, value)`
- `applyBridgePreset(values)`

### One-shot actions

- `runBridgeAction(name, arg)`

### Native mod operations

- `deployNativeFix()`
- `nativeFixStatus()`
- `giveGearNative(gearId)`
- `removeGearNative(gearId)`

## Contract rules

- all methods return a Promise-like result object
- success results are `{ ok: true, ... }`
- failures are `{ ok: false, error: "..." }`
- unsupported keys, invalid ranges, and unknown actions are rejected before being written
- this contract should stay narrow and conservative; do not add UI-only or speculative methods that do not correspond to actual supported runtime behavior

## Example usage

```js
const result = await window.dawnwalker.applyInfiniteHealth(true);
if (!result.ok) {
  console.error(result.error);
}
```

## Why this matters

The renderer should remain a thin controller layer. It tells the app what to request, but it does not own gameplay state or manipulate the game directly. The validated main-process bridge is the actual boundary between the UI and the game runtime.
