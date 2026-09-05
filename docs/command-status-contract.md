# Command/status contract sheet

## File locations

- `Mods/DawnwalkerModBridge/command.txt`
- `Mods/DawnwalkerModBridge/status.txt`

## Command file

The command file is the app's request payload.

### Core keys

| Key | Type | Meaning | Notes |
| --- | --- | --- | --- |
| `bootId` | string | current app/game boot identifier | must match the current boot |
| `heartbeat` | number | app liveness timestamp | refreshed periodically |
| `appClosed` | `0`/`1` | app shutdown marker | `1` triggers immediate release to defaults |

### Persistent settings keys

These are runtime setting entries the Lua bridge re-applies every tick while still present.

| Key | Type | Meaning |
| --- | --- | --- |
| `levelCap` | number | runtime level cap |
| `infiniteHealth` | `0`/`1` | health lock or infinite health |
| `infiniteStamina` | `0`/`1` | stamina lock |
| `infiniteBlood` | `0`/`1` | blood lock |
| `keepActionSlotsCharged` | `0`/`1` | keep action slots charged |
| `noCooldowns` | `0`/`1` | disable cooldowns |
| `speedMultiplier` | float | movement speed scaling |
| `jumpMultiplier` | float | jump power scaling |
| `fovMultiplier` | float | field-of-view multiplier |
| `gameSpeed` | float | overall game time scaling |
| `damageMultiplier` | float | damage multiplier |
| `carryWeightMultiplier` | float | carry weight scaling |
| `actionDifficulty` | int | action difficulty level |
| `rpgDifficulty` | int | RPG difficulty level |
| `movementMode` | string | `walk`, `fly`, or `ghost` |

### One-shot action keys

| Key | Type | Meaning |
| --- | --- | --- |
| `actionId` | string | unique request id |
| `action` | string | action name |
| `actionArg` | string | optional action argument |

Examples:

- `action=healNow`
- `action=addCoins`, `actionArg=2500`
- `action=setTimeOfDay`, `actionArg=20:30`

## Status file

The status file is the runtime output report from the Lua bridge.

| Key | Type | Meaning |
| --- | --- | --- |
| `ok` | `0`/`1` | bridge is currently healthy |
| `bootId` | string | active boot identifier |
| `cutsceneActive` | `0`/`1` | whether cutscene gating is active |
| `healthLocked` | `0`/`1` | health lock status |
| `staminaLocked` | `0`/`1` | stamina lock status |
| `bloodLocked` | `0`/`1` | blood lock status |
| `actionResult` | string | last action status/result |

## Supported runtime surface

The bridge contract is intentionally narrow. The app only writes the keys that are validated by the shared bridge protocol, and the game runtime only applies those values that are known to be safe and supported.

### Supported persistent field keys

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
- `damageMultiplier`
- `carryWeightMultiplier`
- `actionDifficulty`
- `rpgDifficulty`
- `movementMode`

### Supported one-shot actions

- `grantXP`
- `addTraitPoints`
- `setTraitPoints`
- `unlockAllTraits`
- `resetAllTraits`
- `addMutationCharges`
- `addCoins`
- `unlockAllRecipes`
- `addAllIngredients`
- `unlockAllFastTravel`
- `revealAllMappins`
- `killTarget`
- `killAllAggressive`
- `teleport`
- `setTimeOfDay`
- `refillBlood`
- `healNow`

Everything else is intentionally rejected before it reaches the runtime bridge.

## Safety and compatibility rules

- command.txt is flat key/value text, not JSON
- status.txt is flat key/value text, not JSON
- app writes are blocked if the boot ID is stale
- app writes are blocked during cutscenes or unsafe world states
- app close must write `appClosed=1` to release runtime settings
- unsupported keys should be rejected before writing
- action ids should be unique and never reused without a fresh request
- the contract must stay conservative; unsupported game behavior is not added just to fill out the UI

## Example lifecycle

1. App starts and generates `bootId`.
2. App writes heartbeat and other desired runtime settings.
3. Lua bridge validates boot ID and world state.
4. Lua applies supported changes and writes status.
5. UI polls status and updates state.
6. App closes and writes `appClosed=1`.
7. Lua bridge releases settings and returns to defaults.
