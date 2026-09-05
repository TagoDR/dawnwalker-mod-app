# Dawnwalker bridge protocol reference

This document is the canonical reference for the live UE4SS bridge used by the Dawnwalker Mod App.

## Overview

The app and the Lua bridge communicate through simple flat `key=value` files stored in the game install under the UE4SS Mods folder.

- Command file: `Mods/DawnwalkerModBridge/command.txt`
- Status file: `Mods/DawnwalkerModBridge/status.txt`

The Electron app writes the command file. The Lua bridge reads it, applies supported runtime changes, and writes status back.

## Command file contract

The command file is plain text, one entry per line.

Example:

```txt
bootId=1725487600-123456
heartbeat=1725487600123
infiniteHealth=1
speedMultiplier=1.5
actionId=1725487600-abc123
action=healNow
actionArg=
```

### Required fields

- `bootId`: current app/game session identifier; must match the current boot before runtime writes are accepted.
- `heartbeat`: monotonic-ish timestamp used to prove the app is still alive.
- `appClosed`: set to `1` when the app exits so the Lua bridge releases default-safe state immediately.

### Persistent settings

These are stored as flat keys and are re-applied every tick by the Lua bridge while still present in command.txt.

Examples:

- `levelCap`
- `infiniteHealth`
- `infiniteStamina`
- `infiniteBlood`
- `keepActionSlotsCharged`
- `noCooldowns`
- `speedMultiplier`
- `jumpMultiplier`
- `fovMultiplier`
- `gameSpeed`
- `damageAmplifier`
- `carryWeightMultiplier`
- `actionDifficulty`
- `rpgDifficulty`
- `movementMode`

### One-shot actions

Actions are written with a nonce-based request so they are only executed once per matching request.

Required keys:

- `actionId`: unique request id
- `action`: action name
- `actionArg`: optional argument

Examples:

- `action=healNow`
- `action=unlockAllTraits`
- `action=setTimeOfDay`, `actionArg=20:30`
- `action=addCoins`, `actionArg=2500`

### Validation rules

All writes should go through the shared bridge validators before being written to disk.

- Unknown fields are rejected.
- Invalid numeric ranges are clamped or rejected.
- Boolean-like values are normalized to `0` or `1`.
- One-shot actions must be validated against the allowed action list.

## Status file contract

The Lua bridge writes flat key/value lines to the status file.

Example:

```txt
ok=1
bootId=1725487600-123456
cutsceneActive=0
healthLocked=1
staminaLocked=0
bloodLocked=0
actionResult=ok
```

### Expected keys

- `ok`: bridge is successfully responding and applied logic is healthy.
- `bootId`: active game boot identifier.
- `awaitingHandshake`: `1` when the game has not yet acknowledged the active app boot.
- `appConnected`: `1` while the app heartbeat is still live; `0` when the app has disconnected.
- `cutsceneActive`: `1` when unsafe cutscene conditions are active.
- `healthLocked`: `1` if health lock state is active.
- `staminaLocked`: `1` if stamina lock state is active.
- `bloodLocked`: `1` if blood lock state is active.
- `actionResult`: last one-shot action status or result string.

Note: `gameRunning` is app-side state, not a Lua status file field. It is set by the Electron process based on process detection and can be read from the app API layer.

## Safety model

The runtime bridge intentionally refuses unsafe writes.

### Boot safety

The Lua bridge ignores stale command files until the command file contains the current boot ID. This prevents old sessions from replaying onto a new game boot.

### Heartbeat safety

The Electron app writes a fresh heartbeat periodically. If the heartbeat stops or the app reports `appClosed=1`, the Lua bridge releases the active settings and restores defaults.

### Cutscene safety

The bridge pauses all setting writes while the game is in a cutscene or other unsafe world state.

### Defaults-first behavior

Every app start and every game launch begins from the game defaults. The app only applies changes after a valid handshake and safe world state.

## File format rules

- The file format is newline-delimited `key=value` text.
- Empty lines are ignored.
- Values are strings, not JSON objects.
- The app should never write nested objects to the command file.
- The Lua bridge should treat the file as a flat state map.

## Integration guidance

When adding a new bridge field or action:

1. Add the validator to the shared bridge protocol.
2. Add the runtime handler to the Lua bridge.
3. Add the corresponding output fields to the status contract.
4. Test that the app resets to defaults correctly on shutdown.
5. Validate that stale boot IDs and cutscenes remain safe.
