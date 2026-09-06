# DawnwalkerMod — In-Engine UE4SS Mod for The Blood of the Dawnwalker

A 100% in-engine, pure UE4SS mod for **The Blood of the Dawnwalker**.

This mod replaces the legacy Electron desktop application and file-polling bridge with a native, zero-latency mod that runs directly inside Unreal Engine via **UE4SS**. It features an in-game interactive Canvas/HUD menu, configurable hotkeys, and a complete suite of console commands.

No external `.exe` binaries, no Node.js runtime, no file-polling lag.

---

## Features

### 1. Survivability & Combat
- **Infinite Health (God Mode)**: Multi-layered protection (`RebelAISubsystem` player invulnerability, GAS `GE_Invulnerability` gameplay effect, engine `CheatManager:God()`, and `CombatComponentBase:LockHealth()`). Gated behind post-respawn settle windows to prevent crashes.
- **Infinite Stamina & Infinite Blood**: Locks stamina and the vampire blood bar at 100%.
- **Heal & Replenish Blood**: Instant one-click or hotkey recovery for health, stamina, and all blood segments.
- **Damage Amplifier**: Watches each hostile enemy's health and scales the drop dealt by the player (1x–20x) in a dedicated 100ms loop.
- **Kill Hostiles**: Instantly eliminates all currently aggressive NPCs.
- **Difficulty Adjustments**: Live control over Action (Combat) and RPG (Exploration) difficulty tiers (`Story`, `Normal`, `Immersive`, `Hard`).

### 2. Character Progression
- **Set Player Level**: Safely forces level from 1 to 99 (levels above 99 exceed engine XP tables and are rejected).
- **Level Cap Adjustment**: Sets runtime level cap (1 to 99).
- **Quest XP Granting**: Triggers real quest reward tiers (1: Very Small to 5: Very Large), properly unlocking normal game milestones.

### 3. Movement & Camera
- **Speed & Jump Multipliers**: Smoothly scales `MaxWalkSpeed` and `JumpZVelocity` (0.1x to 5.0x) from cached base values.
- **Movement Modes**: Toggle between `Walk`, `Fly`, and `Ghost` (noclip fly) cheat modes.
- **Teleport**: Instantly teleports player pawn to aim crosshair.
- **Field of View (FOV)**: Custom FOV scaling clamped between 10° and 170°.
- **Game Speed (Slomo)**: Scales game time dilation from 0.1x to 4.0x.

### 4. Skills & Abilities
- **Trait Points**: Add, remove, or set exact unspent trait points.
- **Trait Tree**: One-click full tree unlock (`UnlockAllTraits`) or full respec (`ResetAllTraits`).
- **Vampire Mutation**: Add or remove vampire corruption / mutation charges.
- **No Cooldowns**: Eliminates ability cooldowns via `FocusAbilitiesSubsystem`.
- **Action Slots Full**: Automatically refills unlocked ability activation charges.

### 5. World & Time
- **In-Game Clock**: Set exact time of day (`HH:MM`) or advance time by hours.
- **Map & Fast Travel**: Unlock all fast travel destinations and reveal all map pins / POIs.
- **Debug Overrides**: Adjust world NPC level override (0–99) and alert level (0–9).

### 6. Gear & Inventory
- **Gear Granting**: Over 800 items and sets cataloged:
  - Complete 4-piece armor sets (equips automatically)
  - Weapons (swords, greatswords, axes, maces, hammers, knives)
  - Individual armor pieces (chest, legs, hands, feet)
  - Rings, amulets, and trinkets
  - Consumables and crafting ingredients
  - Duplicate cleanup tools
- **Economy**: Add or remove coins (`InventoryComponent:AddCurrency`).
- **Carry Weight**: Multiplier up to 100x on carry weight limit.
- **Crafting**: Unlock all crafting schematics in one click.
- **Self-Check**: Diagnoses and verifies every Unreal Engine reflection target.

---

## Installation

### Requirements:
- Windows PC
- *The Blood of the Dawnwalker* installed
- [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) (v3.0.1 or higher) installed in `Dawnwalker/Binaries/Win64/`

### Steps:
1. Locate your game's UE4SS `Mods` folder (typically `The Blood of Dawnwalker/Dawnwalker/Binaries/Win64/Mods/`).
2. Copy the contents of `runtime-mods/` into your `Mods/` folder:
   - `Mods/DawnwalkerMod/` (the main script mod)
   - `Mods/DawnwalkerNativeFix/` (the native C++ mod for item handle copying)
   - Add `DawnwalkerMod : 1` and `DawnwalkerNativeFix : 1` to `Mods/mods.txt`.
3. Launch the game!

---

## Controls & Usage

### 1. In-Game Interactive Menu
- Press **`F1`** to toggle the in-game mod menu overlay.
- Use **`Tab`** to switch between categories (`Combat`, `Character`, `Movement`, `Skills`, `World`, `Gear`, `Presets`).
- Use **`Up` / `Down` Arrow Keys** to highlight a setting or action.
- Use **`Left` / `Right` Arrow Keys** to adjust sliders or cycle dropdowns.
- Press **`Enter`** to toggle a cheat on/off or execute an action.
- Mouse cursor is automatically enabled while the menu is open.

### 2. Quick Keybinds
| Hotkey | Action |
| :--- | :--- |
| **`F1`** | Toggle In-Game Mod Menu |
| **`NumPad 1`** | Instant Heal & Stamina Refill |
| **`NumPad 2`** | Toggle Infinite Health (God Mode) |
| **`NumPad 3`** | Toggle Infinite Stamina |
| **`NumPad 4`** | Toggle Infinite Blood |
| **`NumPad 5`** | Cycle Movement Mode (`Walk` -> `Fly` -> `Ghost`) |
| **`NumPad 6`** | Teleport to Aim Crosshair |
| **`NumPad 7`** | Kill All Aggressive Hostile NPCs |
| **`NumPad 8`** | Toggle Ability Cooldowns |
| **`NumPad 9`** | Advance Time 1 Hour |

### 3. In-Game Console Commands
Press the console key (**`~`**) in-game and type any of the following:

```text
dw_menu                     - Toggle the in-game mod menu
dw_god [0|1]                - Toggle or set God Mode / Infinite Health
dw_stamina [0|1]            - Toggle or set Infinite Stamina
dw_blood [0|1]              - Toggle or set Infinite Blood
dw_heal                     - Restore health and stamina to 100%
dw_refillblood              - Refill all blood segments
dw_speed <0.1-5.0>          - Set movement speed multiplier
dw_jump <0.1-5.0>           - Set jump height multiplier
dw_fly / dw_ghost / dw_walk - Change movement mode
dw_teleport                 - Teleport to aim crosshair
dw_slomo <0.1-4.0>          - Set game time dilation
dw_fov <0.1-3.0>            - Set field of view multiplier
dw_damage <1.0-20.0>        - Set damage multiplier
dw_kill                     - Kill all aggressive enemies
dw_level <1-99>             - Set player level
dw_levelcap <1-99>          - Set player level cap
dw_xp <1-5>                 - Grant quest XP tier
dw_traits <amount>          - Add or remove trait points
dw_unlocktraits             - Unlock all traits in skill tree
dw_resettraits              - Reset / respec all traits
dw_mutation <amount>        - Add or remove vampire mutation charges
dw_cooldowns [0|1]          - Toggle ability cooldowns
dw_time <HH:MM>             - Set time of day (e.g. dw_time 20:30)
dw_fasttravel               - Unlock all fast travel destinations
dw_mappins                  - Reveal all map pins / POIs
dw_coins <amount>           - Add or remove coins
dw_weight <0.1-100.0>       - Set carry weight multiplier
dw_recipes                  - Unlock all crafting recipes
dw_selfcheck                - Run reflection diagnostic check
dw_give <gearId> [qty]      - Grant gear item or set (e.g. dw_give weapon_swordvampiric1a 1)
dw_remove <gearId>          - Remove granted gear duplicates
dw_preset <save|apply> <name> - Save or apply setting presets
```

---

## Project Structure

```text
.
├── agents.md                           # Guidelines & safety constraints for AI agents / devs
├── README.md                           # Mod overview, installation & user guide
├── todo.md                             # Reconstruction plan, security audit & checklist
├── runtime-mods/
│   ├── DawnwalkerMod/                  # Main In-Engine UE4SS Mod
│   │   ├── enabled.txt
│   │   └── Scripts/
│   │       ├── main.lua                # Main entry point & async loops
│   │       ├── safety.lua              # Settle-window guards & crash prevention
│   │       ├── state.lua               # In-memory mod state & live telemetry
│   │       ├── config.lua              # Presets manager (presets.txt)
│   │       ├── features/
│   │       │   ├── combat.lua          # Health, stamina, blood, damage amp, kill hostiles
│   │       │   ├── character.lua       # Level, level cap, quest XP tiers
│   │       │   ├── movement.lua        # Speed, jump, fly/ghost, teleport, FOV, slomo
│   │       │   ├── skills.lua          # Traits, mutation, cooldowns, action slots
│   │       │   ├── world.lua           # Time of day, fast travel, map pins, alert level
│   │       │   └── inventory.lua       # Coins, carry weight, crafting, diagnostics
│   │       ├── gear/
│   │       │   ├── catalog.lua         # Complete 800+ item & gear catalog
│   │       │   └── granter.lua         # Gear granting dispatcher (DawnwalkerNativeFix)
│   │       └── ui/
│   │           ├── hud_menu.lua        # In-game interactive Canvas/HUD overlay (F1)
│   │           ├── keybinds.lua        # Hotkey listener (F1, NumPad 1-9)
│   │           └── console.lua         # In-game console commands (dw_*)
│   ├── DawnwalkerNativeFix/            # Native C++ Mod (raw FItemHandle memcpy)
│   │   ├── enabled.txt
│   │   └── dlls/
│   │       └── main.dll                # Precompiled UE4SS C++ plugin
│   └── mods.txt                        # Master UE4SS mod activation list
├── native-mods/                        # C++ source code for DawnwalkerNativeFix
│   ├── CMakeLists.txt
│   ├── README.md
│   ├── dist/
│   │   └── DawnwalkerNativeFix.dll
│   └── DawnwalkerNativeFix/
│       ├── CMakeLists.txt
│       └── dllmain.cpp
├── tools/                              # Asset extraction and inspection tools
│   ├── dumpsig.ps1
│   ├── dumpmods.ps1
│   ├── gengear.js
│   ├── gencraftables.js
│   └── gear-index.json
└── docs/                               # Developer reference documentation
    ├── developer-onboarding.md         # Quick start & development workflow
    ├── lua-side-spec.md                # Runtime lifecycle, loops & state model
    ├── command-status-contract.md      # Unreal Engine reflection reference sheet
    ├── protocol-reference.md           # Presets format, console API & native IPC
    ├── renderer-api-contract.md        # Canvas HUD menu layout & input handling
    └── react-side-spec.md              # In-game menu 7-tab feature matrix & state
```

---

## Documentation & Developer Guidelines

Comprehensive reference documentation is provided in the repository:

- [**`agents.md`**](file:///C:/Users/Admin/WebstormProjects/dawnwalker-mod-app-master/agents.md) — Crucial safety rules, crash prevention guidelines, and pattern for adding new features.
- [**`docs/developer-onboarding.md`**](file:///C:/Users/Admin/WebstormProjects/dawnwalker-mod-app-master/docs/developer-onboarding.md) — Local testing, setup, and live debugging with `UE4SS.log`.
- [**`docs/lua-side-spec.md`**](file:///C:/Users/Admin/WebstormProjects/dawnwalker-mod-app-master/docs/lua-side-spec.md) — UE4SS runtime lifecycle, asynchronous loops, and in-memory state model.
- [**`docs/command-status-contract.md`**](file:///C:/Users/Admin/WebstormProjects/dawnwalker-mod-app-master/docs/command-status-contract.md) — Reflection cheat sheet covering all game subsystems, functions, arguments, and safe ranges.
- [**`docs/protocol-reference.md`**](file:///C:/Users/Admin/WebstormProjects/dawnwalker-mod-app-master/docs/protocol-reference.md) — Presets file format (`presets.txt`), console command signatures, and native C++ plugin IPC.
- [**`docs/renderer-api-contract.md`**](file:///C:/Users/Admin/WebstormProjects/dawnwalker-mod-app-master/docs/renderer-api-contract.md) — Canvas HUD menu overlay architecture, color palettes, and input state machine.
- [**`docs/react-side-spec.md`**](file:///C:/Users/Admin/WebstormProjects/dawnwalker-mod-app-master/docs/react-side-spec.md) — Menu 7-tab feature matrix, direct-to-state synchronization, and telemetry footer.
- [**`todo.md`**](file:///C:/Users/Admin/WebstormProjects/dawnwalker-mod-app-master/todo.md) — Complete reconstruction plan, security audit findings, and verified completion checklist.

---

## Safety & Crash Prevention

This mod incorporates extensive crash prevention rules derived from engine crash-dump analysis:
1. **Pawn Respawn Settle Window**: Automatically delays component writes for 3–6 seconds upon respawning to prevent fatal access violations (`0xC0000005`).
2. **Cutscene Gating**: Pauses all gameplay modifications and damage amplification while cinematic cutscenes or dialogues are active.
3. **No Attribute Table Overflow**: Clamps player level and level cap to 99 to avoid unmapped memory reads in the engine's progression curve tables.
4. **Anti-Compounding Multipliers**: Multipliers always calculate from cached base properties, preventing compounding scaling on repeated applies.
