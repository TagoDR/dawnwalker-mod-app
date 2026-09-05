# React-side bridge spec

This document describes the React-side contract for the live Dawnwalker bridge.

## Source of truth

The UI should treat `status.txt` as the source of truth for the current runtime state. It should not assume that browser state persisted in the app matches actual game state.

## Bridge contract expectations

The React layer should:

- poll the live bridge status periodically
- ignore stale boot IDs from previous runs
- block writes while the game is not running
- block writes during cutscenes or unsafe states
- validate each field/action before it is written
- keep status state in sync with the actual runtime file

## Bridge polling model

The UI should poll at a regular interval and update the following state values:

- `ok`
- `bootId`
- `gameRunning`
- `cutsceneActive`
- `actionResult`
- `healthLocked`
- `staminaLocked`
- `bloodLocked`

Any status value not matching the current boot should be ignored.

## Write safety model

Any runtime write should be gated by:

- game running
- bridge healthy
- no cutscene active
- valid boot ID
- supported field/action validator result

This should be enforced before the React code writes to the bridge file.

## Command shape

The React layer should write flat `key=value` data to the live bridge contract. It should not send nested JSON payloads or object blobs.

Examples:

```js
writeBridgeCommand({
  bootId,
  heartbeat: Date.now(),
  infiniteHealth: 1
});
```

```js
writeBridgeCommand({
  bootId,
  heartbeat: Date.now(),
  actionId: "nonce-123",
  action: "healNow",
  actionArg: ""
});
```

## Validation layer

The React layer should rely on the shared validators in `bridge-protocol.js` rather than ad hoc validation in page components.

This ensures:

- consistent field support
- safe ranges
- known action list enforcement
- no unsupported gameplay values are written

## View behavior

The UI should render state such as:

- bridge connected or disconnected
- game running or not
- cutscene active or not
- last action result
- active runtime locks

It should also expose a reset-to-defaults action that clears the live bridge state and returns the game to its defaults.

## Common mistakes to avoid

- persisting game state in browser storage as the primary source of truth
- writing nested objects into command files
- trusting stale boot IDs
- writing action requests during unsafe states
- allowing unsupported keys to reach the bridge
- relying on UI defaults instead of live runtime status
