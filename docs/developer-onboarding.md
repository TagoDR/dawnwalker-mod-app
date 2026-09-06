# Developer Onboarding Guide

Welcome to the **DawnwalkerMod** codebase. This project is an in-engine, pure UE4SS mod for *The Blood of the Dawnwalker*. It runs inside the game process without any external applications, executables, or background processes.

---

## 1. Quick Setup & Installation

### Requirements:
- Windows 10/11
- *The Blood of the Dawnwalker* installed
- [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) (v3.0.1 or higher) installed in your game directory (`Dawnwalker/Binaries/Win64/`)

### Deploying the Mod for Testing:
1. Locate your game's UE4SS `Mods` directory:
   `The Blood of Dawnwalker\Dawnwalker\Binaries\Win64\Mods\`
2. Copy the folders from `runtime-mods/` into `Mods/`:
   - `Mods/DawnwalkerMod/`
   - `Mods/DawnwalkerNativeFix/`
3. Make sure both mods are enabled in `Mods/mods.txt`:
   ```text
   DawnwalkerMod : 1
   DawnwalkerNativeFix : 1
   ```
4. Launch the game.

---

## 2. Architecture Overview

```text
Game Launch (Dawnwalker.exe)
  └── UE4SS loads Mods/mods.txt
        ├── Loads DawnwalkerNativeFix/dlls/main.dll (C++ Plugin)
        └── Executes DawnwalkerMod/Scripts/main.lua
              ├── safety.lua    (Settle windows, cutscene guards, pointer checks)
              ├── state.lua     (In-memory toggles, multipliers, base values)
              ├── config.lua    (Presets manager: Mods/DawnwalkerMod/presets.txt)
              ├── features/     (Combat, Character, Movement, Skills, World, Inventory)
              ├── gear/         (Item catalog & native fix granter)
              └── ui/           (Canvas HUD menu on F1, keybinds, console commands)
```

### Key Modules:
- **`main.lua`**: Entry point. Hooks `AHUD:ReceiveDrawHUD` for menu rendering and starts two asynchronous loops:
  - **1000ms Main Tick Loop**: Refreshes player pawn, checks settle windows and cutscene status, and ticks all feature modules.
  - **100ms Fast Loop**: Reactive damage amplifier that tracks hostile NPC health deltas and re-applies scaled damage.
- **`safety.lua`**: Protects against game engine crashes. Settle-window tracking delays writes after player pawn respawn.
- **`state.lua`**: Single source of truth for in-memory toggles, multipliers, base values, and live readouts. Zero disk polling.
- **`ui/hud_menu.lua`**: Draws the interactive mod menu directly onto the Unreal Engine canvas.
- **`ui/keybinds.lua`**: Registers hotkeys (`F1`, `NumPad 1`–`9`) via UE4SS `RegisterKeyBind`.
- **`ui/console.lua`**: Registers in-game console commands (`dw_*`) via `RegisterConsoleCommandHandler`.

---

## 3. Development Workflow & Debugging

### Live Diagnostics via `UE4SS.log`:
- All mod output is written to `Dawnwalker/Binaries/Win64/UE4SS.log`.
- To watch live output during development:
  ```powershell
  Get-Content -Path "..\Dawnwalker\Binaries\Win64\UE4SS.log" -Wait -Tail 30
  ```

### In-Game Testing:
- Open the Unreal Engine console with the **`~`** (tilde) key.
- Test commands directly:
  ```text
  dw_god 1          - Enables God Mode
  dw_heal           - Restores health and stamina
  dw_speed 2.0      - Sets movement speed to 2x
  dw_give weapon_swordvampiric1a 1 - Grants The Vrakhir sword
  dw_selfcheck      - Runs reflection verification across all game classes
  ```
- Toggle the in-game GUI with **`F1`**.

---

## 4. How to Work Safely

1. **Always wrap reflection calls in `pcall`**: If a game patch renames a Blueprint function or property, `pcall` prevents the mod from crashing.
2. **Never set player level or level cap above 99**: The game's XP curve tables end at level 99; higher values read invalid memory.
3. **Respect settle windows**: Never write to newly spawned player pawn components without verifying `Safety.CombatSettleTicksRemaining == 0`.
4. **Always cache base values**: Multipliers must scale from `BaseValues`, never compounding on top of already modified properties.
