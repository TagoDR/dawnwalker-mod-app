# AGENTS.md — Agent & Developer Guidelines for DawnwalkerMod

> **Audience**: AI Coding Agents & Autonomous Developers  
> **Repository**: `TagoDR/dawnwalker-mod-app`  
> **Target Game**: *The Blood of the Dawnwalker* (Unreal Engine 5)  
> **Runtime Environment**: [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) (Unreal Engine 4/5 Scripting System) v3.0.1+

---

## 1. Project Purpose & Core Architecture

This repository contains a 100% in-engine mod for *The Blood of the Dawnwalker*. It runs entirely inside the game process via **UE4SS**, using Lua scripts and an auxiliary C++ plugin.

### Key Architectural Tenets:
1. **Zero External Executables**: Do **NOT** introduce Node.js, Electron, Python subprocesses, or compiled Windows `.exe` applications. All features must execute directly within UE4SS.
2. **Direct In-Memory State**: Do **NOT** add file-polling communication (`command.txt`, `status.txt`). All state is held in memory in [`state.lua`](file:///C:/Users/Admin/WebstormProjects/dawnwalker-mod-app-master/runtime-mods/DawnwalkerMod/Scripts/state.lua) and modified with zero latency.
3. **In-Game UI**: The user interface is rendered on the Unreal Engine viewport via `AHUD:ReceiveDrawHUD` in [`ui/hud_menu.lua`](file:///C:/Users/Admin/WebstormProjects/dawnwalker-mod-app-master/runtime-mods/DawnwalkerMod/Scripts/ui/hud_menu.lua), alongside keybinds ([`ui/keybinds.lua`](file:///C:/Users/Admin/WebstormProjects/dawnwalker-mod-app-master/runtime-mods/DawnwalkerMod/Scripts/ui/keybinds.lua)) and console commands ([`ui/console.lua`](file:///C:/Users/Admin/WebstormProjects/dawnwalker-mod-app-master/runtime-mods/DawnwalkerMod/Scripts/ui/console.lua)).

---

## 2. Directory Structure & Module Responsibilities

```text
runtime-mods/
├── DawnwalkerMod/                      # Main Pure UE4SS Script Mod
│   ├── enabled.txt                     # UE4SS loader flag ("DawnwalkerMod : 1")
│   └── Scripts/
│       ├── main.lua                    # Entry point: lifecycle, async loops, HUD hook
│       ├── safety.lua                  # Crash prevention, settle windows, SafeIsValid
│       ├── state.lua                   # In-memory toggles, multipliers, base-value cache
│       ├── config.lua                  # Presets persistence (Mods/DawnwalkerMod/presets.txt)
│       │
│       ├── features/                   # Core gameplay modification modules
│       │   ├── combat.lua              # God mode, stamina/blood lock, damage amp, kill hostiles
│       │   ├── character.lua           # Level (1-99), level cap, quest XP tiers (1-5)
│       │   ├── movement.lua            # Speed, jump, fly/ghost/walk, teleport, FOV, slomo
│       │   ├── skills.lua              # Trait points, unlocks, mutation charges, cooldowns
│       │   ├── world.lua               # Time of day, fast travel, map pins, alert/NPC level
│       │   └── inventory.lua           # Coins, carry weight limit, recipe unlocks, diagnostics
│       │
│       ├── gear/
│       │   ├── catalog.lua             # Over 800 cataloged items (weapons, armor sets, etc.)
│       │   └── granter.lua             # Interfaces with DawnwalkerNativeFix for FItemHandle
│       │
│       └── ui/
│           ├── hud_menu.lua            # In-game interactive Canvas overlay menu (F1)
│           ├── keybinds.lua            # Hotkey shortcuts (F1, NumPad 1-9)
│           └── console.lua             # In-game console commands (dw_*)
│
├── DawnwalkerNativeFix/                # Native C++ UE4SS Plugin
│   ├── enabled.txt                     # UE4SS loader flag ("DawnwalkerNativeFix : 1")
│   └── dlls/
│       └── main.dll                    # Raw FItemHandle byte-copying DLL
│
└── mods.txt                            # Master UE4SS mods list
```

---

## 3. Strict Safety & Crash-Prevention Rules

When modifying or adding features, you **MUST** adhere to the following hard-learned engine constraints (derived from crash-dump analysis of `0xC0000005` access violations):

### Rule 1: Respect the Post-Respawn Settle Window
* **The Hazard**: When the player dies and respawns, Unreal Engine constructs a new player pawn. The pawn's components (`CombatComponentBase`, `CharacterMovementComponent`, ability system components) are not fully initialized for several frames. Touching them immediately causes an unrecoverable hardware access violation that `pcall` cannot catch.
* **The Guard**: Always gate component writes behind `Safety.CombatSettleTicksRemaining` (3 ticks = ~3s) and `Safety.MovementSettleTicksRemaining` (6 ticks = ~6s). These are updated in [`safety.lua`](file:///C:/Users/Admin/WebstormProjects/dawnwalker-mod-app-master/runtime-mods/DawnwalkerMod/Scripts/safety.lua) via `Safety.RefreshPawnSettleState()`.

### Rule 2: Cutscene & Dialogue Gating
* **The Hazard**: During cutscenes and dialogues, actors are torn down or possessed by cinematic cameras. Mod writes during transitions crash the game.
* **The Guard**: Always check `Safety.IsCutsceneActive(player)` before writing attributes or running combat damage loops. When exiting a cutscene, re-baseline settle counters as if a respawn occurred.

### Rule 3: Anti-Compounding Multipliers
* **The Hazard**: Modifying properties like `MaxWalkSpeed = MaxWalkSpeed * 1.5` every tick compounds exponentially into game-breaking numbers.
* **The Guard**: Always cache the original vanilla value once in `State.BaseValues` using `State.GetBaseValue(key, object, propertyName)`. Always compute modified values as `BaseValues[key] * multiplier`.

### Rule 4: Table Bounds (Max Level 99)
* **The Hazard**: The game's XP and progression tables terminate at level 99. Requesting level 100 or higher causes the engine to read past the end of the data table and crash.
* **The Guard**: Clamping to `[1, 99]` is strictly mandatory for both player level and level cap.

### Rule 5: Pointer Validity via `SafeIsValid`
* **The Hazard**: Dangling UObject pointers in Lua cause crashes when calling methods.
* **The Guard**: Never assume an object is alive. Wrap checks with `Safety.SafeIsValid(object)`.

### Rule 6: The `FItemHandle` Struct Exception
* **The Hazard**: The game's `FItemHandle` struct contains zero reflected `UProperty` members. UE4SS Lua's UFunction marshaler converts unreflected structs into empty tables `{}`, resulting in all-zero bytes that grant placeholder items ("Bee Smoker").
* **The Solution**: Item granting must be delegated to [`granter.lua`](file:///C:/Users/Admin/WebstormProjects/dawnwalker-mod-app-master/runtime-mods/DawnwalkerMod/Scripts/gear/granter.lua) and `DawnwalkerNativeFix`, which copies the raw struct bytes via `ProcessEvent` + `memcpy`.

---

## 4. How to Add a New Feature

Follow this standard pattern when adding a new cheat, toggle, or action:

### Step 1: Add State in [`state.lua`](file:///C:/Users/Admin/WebstormProjects/dawnwalker-mod-app-master/runtime-mods/DawnwalkerMod/Scripts/state.lua)
```lua
-- In State.Toggles, State.Multipliers, or State.Gameplay:
State.Toggles.myNewCheat = false
```

### Step 2: Implement Logic in the Appropriate Module in `features/`
```lua
-- In runtime-mods/DawnwalkerMod/Scripts/features/<module>.lua
function MyModule.ApplyNewCheat(player, enabled)
    -- 1. Check safety
    if not player or not Safety.SafeIsValid(player) then return false end
    -- 2. Reflection call
    local ok, err = pcall(function()
        -- Engine call here
    end)
    return ok
end
```

### Step 3: Expose in Console Commands ([`ui/console.lua`](file:///C:/Users/Admin/WebstormProjects/dawnwalker-mod-app-master/runtime-mods/DawnwalkerMod/Scripts/ui/console.lua))
```lua
RegisterCmd("dw_mycheat", function(params)
    State.Toggles.myNewCheat = not State.Toggles.myNewCheat
    print("[DawnwalkerMod] My Cheat: " .. (State.Toggles.myNewCheat and "ON" or "OFF"))
end)
```

### Step 4: Add to In-Game Menu ([`ui/hud_menu.lua`](file:///C:/Users/Admin/WebstormProjects/dawnwalker-mod-app-master/runtime-mods/DawnwalkerMod/Scripts/ui/hud_menu.lua))
1. In `Menu.Render()`: add a `DrawRow(rowNumber, "My New Cheat", nil, true, State.Toggles.myNewCheat)`.
2. In `Menu.Select()`: add the selection handler for that row.

---

## 5. Coding Conventions

- **Language**: Lua 5.4 (as embedded in UE4SS).
- **Naming**: PascalCase for exported module tables and functions (`Combat.HealNow`), camelCase for local variables and properties (`playerAddrOk`).
- **Error Handling**: Every Unreal Engine reflection call **must** be wrapped in `pcall`. Never allow a Lua error or missing reflection target to crash the tick loop.
- **Logging**: Use `print(string.format("[DawnwalkerMod] ..."))` for mod messages. Do not flood the console on every tick; log only on state changes or errors.
- **Imports**: Require modules relative to the `Scripts/` root: `local Safety = require("safety")`, `local Combat = require("features.combat")`.
