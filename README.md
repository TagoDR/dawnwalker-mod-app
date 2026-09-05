# Dawnwalker Mod App

A Windows desktop utility for controlling supported gameplay tweaks in The Blood of Dawnwalker through a live UE4SS bridge.

This project is designed around a simple principle: only expose settings and actions that are known to be valid, and apply them only when the game is in a safe state. It avoids stale command replay, resets itself to defaults on shutdown, and focuses on real runtime-supported behavior instead of speculative or unsupported feature plumbing.

## Why this exists

The app was built to make gameplay tuning safer and more predictable:

- start from default game behavior instead of carrying old UI state across sessions
- ignore stale commands from previous boots
- avoid writing to the game during unsafe states such as cutscenes
- reset to defaults when the app closes so the game does not remain stuck in a modified state
- validate every field before sending it to the bridge

This makes the project more of a controlled runtime control panel than a broad cheat menu.

## What it does

The app communicates with a Lua runtime bridge that reads a simple command file and writes a status file back to the game mod environment. Through that bridge, it can manage a curated set of in-game settings and one-shot actions, including:

- health, stamina, and blood toggles
- movement speed, jump strength, FOV, and movement mode changes
- game speed and difficulty values
- carry weight and damage multipliers
- progression helpers such as XP, trait points, mutation charges, and level cap adjustments
- recipe unlocking and ingredient injection
- map reveal, fast-travel unlock, and time-of-day actions
- utility actions like heal, refill blood, kill target, and teleport

The app intentionally rejects unknown settings and invalid input, and the bridge enforces additional runtime safety checks before applying changes.

## Safety model

This project is intentionally conservative.

### Defaults-first behavior
On launch, the app does not restore a stale last session state. Instead, it starts from the game’s normal defaults and only applies the user’s current configuration once the game is loaded and the bridge is ready.

### Boot handshake / stale state protection
The bridge uses a per-boot identifier and only trusts commands that match the current game session. Old command files from a previous run are ignored.

### Cutscene and world-state checks
Writes are paused during unsafe states to reduce the risk of applying changes while the game is transitioning, in dialogue, or otherwise not in a stable gameplay state.

### Reset on shutdown
When the app closes, it resets the live bridge state and restores defaults instead of leaving the game stuck with a persistent override.

### Renderer bridge contract
The Electron renderer does not access the filesystem or game binaries directly. Instead, it receives a narrow, frozen `window.dawnwalker` API through the preload bridge and every call is forwarded to the main process via IPC.

This keeps the UI sandboxed while preserving the real security boundary: all gameplay writes still flow through the validated main-process bridge and the UE4SS runtime contract. The renderer is meant to display state and issue safe requests, not to manipulate the live game state directly.

## Project layout

```text
.
├── index.js                    # Electron main process and bridge logic
├── preload.js                  # Renderer bridge exposure
├── bridge-protocol.js           # Shared validation and sanitization for command inputs
├── package.json                # Root Electron app config and build scripts
├── runtime-mods/
│   └── DawnwalkerModBridge/
│       └── Scripts/
│           └── main.lua       # Live Lua bridge that reads commands and writes status
├── native-mods/                # Native C++ integration pieces
├── test/                       # Node-based tests for validation and safety logic
├── tools/                      # Utility scripts for dumps, inspection, and smoke-testing
├── ui/                         # React + Vite desktop interface
│   ├── src/
│   ├── package.json
│   └── vite.config.js
└── build/                      # Packaging / app resources
```

## Requirements

- Windows
- The Blood of Dawnwalker installed
- UE4SS-style runtime bridge support available in the game mod environment
- Node.js and npm

## Getting started

Install the dependencies:

```bash
npm install
npm --prefix ui install
```

Then run the app in development mode:

```bash
npm start
```

This builds the UI and launches the Electron desktop app.

## Development scripts

From the project root:

```bash
npm start
npm run build:ui
npm run dist
npm test
```

From the UI folder:

```bash
npm --prefix ui run dev
npm --prefix ui run build
npm --prefix ui run lint
npm --prefix ui run test
```

## Usage

1. Launch the game and make sure the bridge mod is deployed and active.
2. Start the app.
3. Use the in-app pages to change supported settings or trigger runtime actions.
4. The app validates the change, sends it through the bridge, and reports the current status back to the UI.
5. If you want to return to normal gameplay, use the reset control or close the app to trigger default-safe cleanup.

## Important notes

- This project is focused on supported runtime behavior and does not attempt to invent unsupported game features.
- Some gameplay changes are save-affecting or risky and should be used carefully.
- This is a modding and runtime utility project intended for advanced users who understand the risk profile of live game changes.

## License

This project currently uses the ISC license in the root package configuration.

## Disclaimer

This project modifies live game runtime state. Use it responsibly and at your own risk. Supported features are deliberately limited to preserve stability and avoid leaving the game in a stale or unsafe state.
