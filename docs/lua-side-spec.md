# Lua-side bridge spec

This document defines the runtime behavior of the UE4SS Lua bridge that reads `command.txt` and writes `status.txt`.

## Files involved

- `Mods/DawnwalkerModBridge/command.txt`
- `Mods/DawnwalkerModBridge/status.txt`

## Responsibilities

The Lua bridge is responsible for:

- reading the current command file
- validating that the app is still live
- checking the current boot ID
- gating writes during unsafe states
- applying valid persistent settings
- executing one-shot actions once per request
- writing the current status back to the status file
- resetting all settings to defaults when the app is gone or closes

## Boot handshake model

Each game boot creates a unique boot ID. The Lua bridge will not apply any request until the command file contains the same boot ID value.

This prevents stale commands from earlier runs being replayed after a restart.

## App liveness model

The app periodically writes a `heartbeat` value. The Lua bridge tracks.

- the last observed heartbeat
- time since the last heartbeat
- whether the app has closed (`appClosed=1`)

If the app stops sending heartbeats for a timeout window, the Lua bridge releases the runtime settings and returns to defaults.

## Safety checks

The Lua bridge must guard writes behind:

- valid player/world presence
- cutscene-safe logic
- valid boot handshake
- runtime action nonce handling
- safe object validity checks

This includes checks for:

- player existence
- combat component ownership
- world state and cutscene mode
- unsafe actor state transitions
- spawn or respawn settle windows

## Persistent settings flow

Persistent settings are keys written into `command.txt` and re-applied every tick until removed.

The bridge should:

1. read the command file
2. verify boot success
3. refresh app connection state
4. skip writes when unsafe
5. apply valid settings only
6. write status back to `status.txt`

## One-shot action flow

One-shot actions must be implemented using a nonce-like request ID to avoid stale or replayed actions.

Process:

1. app writes `actionId`, `action`, and optional `actionArg`
2. Lua reads and tracks the last action request
3. if the request matches the current nonce, it executes once
4. result is written to `status.txt`
5. failure or timeout is reported back in a safe way

## Status output contract

The Lua bridge writes status keys representing actual runtime results, including:

- `ok`
- `bootId`
- `cutsceneActive`
- `healthLocked`
- `staminaLocked`
- `bloodLocked`
- `actionResult`

If a runtime setting cannot be applied, the bridge must not silently ignore it forever. It should report the result and keep the command file in sync with the actual runtime state.

## Reset behavior

When the app has closed or is no longer connected, the Lua bridge releases its runtime overrides and brings the game back to its defaults.

This is required to prevent stale infinite stamina and other lingering runtime effects after exit.
