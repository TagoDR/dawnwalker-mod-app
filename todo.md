# Reconstruction Plan: Pure UE4SS In-Engine Mod for Blood of the Dawnwalker

> **Status**: Ready for Execution  
> **Target Environment**: UE4SS (Unreal Engine 4/5 Scripting System) v3.0.1+  
> **Scope**: Total elimination of Electron, Node.js, and external `.exe` binaries; complete migration to pure in-engine Lua scripts with in-game UI (Canvas/HUD and ImGui), keybinds, and console commands.

---

## 1. Executive Summary & Objective

The existing **Dawnwalker Mod App** is architected as an external Electron desktop application that communicates with the game *Blood of the Dawnwalker* via an asynchronous file-polling bridge (`command.txt` and `status.txt` on disk), accompanied by an auxiliary C++ mod (`DawnwalkerNativeFix`).

### The Problems with the Current Approach:
1. **Security & Trust**: Distributing an Electron app compiles to an arbitrary Windows `.exe` requiring full user desktop permissions, process querying via `tasklist`, directory scanning across `%LOCALAPPDATA%` and Steam libraries, and hundreds of uninspected npm dependencies. Running an untrusted external binary alongside a game is an unacceptable security risk for end users.
2. **Fragility & Latency**: Communication relies on reading and writing flat text files to disk every 100ms–1000ms. This introduces file I/O locks, requires artificial boot-handshake nonces (`bootId`), heartbeat watchdogs, and status synchronization loops.
3. **Bloat & Complexity**: The project bundles a full Chromium browser and Node runtime (~200MB memory footprint and complex packaging workflows) simply to display a few dozen toggles and sliders.

### The Target Architecture:
- **Zero External Binaries / No `.exe`**: Completely eliminate Electron, Node.js, npm dependencies, build scripts, and `.cmd` launchers.
- **Pure UE4SS Integration**: Install directly into the game's `Binaries/Win64/Mods/` directory as a native UE4SS mod (`DawnwalkerMod`).
- **Direct In-Memory Execution**: Eliminate `command.txt` and `status.txt`. Toggles, sliders, and actions call Unreal Engine functions and properties directly via UE4SS reflection with zero latency.
- **In-Game User Interface**: An in-game menu rendered directly on the game's viewport (using Unreal Engine's `AHUD`/`UCanvas` drawing API in pure Lua, with full mouse cursor and keyboard navigation, plus an optional Dear ImGui tab in UE4SS), complemented by customizable hotkeys and console commands.
- **Safe Gear Granting**: Modernize the `FItemHandle` raw-memory marshalling fix to work seamlessly inside UE4SS without file-based polling.

---

## 2. Security & Threat Model Audit

A comprehensive static security audit of the repository was conducted before planning this reconstruction:

### Audit Findings:
- **Network Traffic**: A repository-wide search across all `.js`, `.jsx`, `.lua`, `.cpp`, `.ps1`, and `.cmd` files found **zero network calls** (no `http://`, `https://`, `fetch`, `axios`, WebSockets, raw TCP/UDP sockets, Discord webhooks, or telemetry).
- **Code Execution / Eval**: No dynamic eval (`eval()`, `Function()`, obfuscated base64 payloads, or hidden shell scripts) was found.
- **Process & Filesystem Probing**:
  - `index.js` uses `child_process.execFileSync("tasklist", ...)` to check if `Dawnwalker.exe` is running.
  - `index.js` searches disk paths for Steam library folders (`libraryfolders.vdf`) and user AppData (`%LOCALAPPDATA%/Dawnwalker`).
  - `index.js` contains file copying logic for game saves.

### Threat Elimination via Migration to UE4SS:
By migrating exclusively to UE4SS Lua scripts:
1. **No Host OS Execution**: Lua scripts execute inside the UE4SS Lua sandbox running within the game's own process memory.
2. **No Arbitrary Disk/Network Privileges**: The mod will no longer run arbitrary Windows commands, inspect external processes, or access directories outside the game folder.
3. **100% Transparent Code**: All game logic is contained in readable, uncompiled Lua scripts that the user can inspect, audit, and modify directly in any text editor.

---

## 3. Legacy Architecture vs. Target UE4SS Architecture

```
LEGACY ARCHITECTURE (Untrusted, Multi-Process, File-Polled):
┌────────────────────────────────────────────────────────────┐
│ Electron Process (Untrusted .exe)                          │
│ React UI ──> IPC ──> index.js ──> Writes command.txt       │
│                                <── Polls status.txt        │
└─────────────────────────────┬──────────────────────────────┘
                              │ Disk File I/O (100ms - 1000ms)
┌─────────────────────────────▼──────────────────────────────┐
│ Game Process (Dawnwalker.exe + UE4SS)                      │
│ main.lua ──> Polls command.txt                             │
│          ──> Writes status.txt                             │
│          ──> Unreal Engine Reflection Calls                │
│ DawnwalkerNativeFix.dll ──> Polls command.txt for Gear     │
└────────────────────────────────────────────────────────────┘

TARGET ARCHITECTURE (100% In-Engine, Pure Scripts, Direct Memory):
┌────────────────────────────────────────────────────────────┐
│ Game Process (Dawnwalker.exe + UE4SS)                      │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ In-Game GUI (Canvas/HUD Overlay or ImGui)            │  │
│  │ Hotkeys (RegisterKeyBind) & Console (dw_*)           │  │
│  └──────────────────────────┬───────────────────────────┘  │
│                             │ Direct Lua Function Calls    │
│  ┌──────────────────────────▼───────────────────────────┐  │
│  │ DawnwalkerMod Core Engine (Pure Lua Scripts)         │  │
│  │ - State Manager (Zero I/O, In-Memory State)          │  │
│  │ - Settle-Window & Cutscene Crash Guards              │  │
│  │ - Unreal Engine Reflection & Subsystem Calls         │  │
│  └──────────────────────────┬───────────────────────────┘  │
│                             │ Direct C-Command / Reflection │
│  ┌──────────────────────────▼───────────────────────────┐  │
│  │ Gear Granter (NativeFix C++ Mod or Lua Bridge)        │  │
│  │ Raw ProcessEvent memcpy for FItemHandle              │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────┘
```

---

## 4. Complete Feature Inventory & Engine Reflection Specification

Every feature currently present in the Electron/React UI and `main.lua` must be mapped to in-engine Lua modules:

### 4.1. Combat & Survivability
| Feature | Engine Target / Reflection Path | Mechanism & Safety Rules |
| :--- | :--- | :--- |
| **Infinite Health (God Mode)** | `RebelAISubsystem:AddPlayerInvulnerability(player)`<br>`GE_Invulnerability` on ASC<br>`CheatManager:God()`<br>`CombatComponentBase:LockHealth()` | Multi-layered defense. Gated by `CombatSettleTicksRemaining` (3 ticks after respawn) to prevent 0xC0000005 crash. |
| **Infinite Stamina** | `CombatComponentBase:LockStamina()`<br>`CombatComponentBase:SetStaminaPercent(1.0)` | Re-applied each tick while active. Unlocks on toggle off. |
| **Infinite Blood** | `BloodBarComponent:LockBlood()`<br>`BloodBarComponent:SetBloodPercent(1.0)` | Found via `FindFirstOf("BloodBarComponent")`. Unlocks on toggle off. |
| **Heal Now** | `CombatComponentBase:SetHealthPercent(1.0)`<br>`CombatComponentBase:SetStaminaPercent(1.0)` | Instant one-shot action. |
| **Replenish Blood** | `BloodBarComponent:HealAndReplenishAllSegments()` | Instant one-shot action. |
| **Damage Amplifier** | `CombatSubsystem:GetAllAggressiveNPCActors()`<br>`CombatComponentBase:GetHealthPercentage()`<br>`CombatComponentBase:SetHealthPercent()` / `Kill()` | Runs in dedicated 100ms loop. Tracks delta health of hostile enemies and re-applies scaled reduction. 1x = Off, 2x–20x. |
| **Kill Hostiles** | `CombatSubsystem:GetAllAggressiveNPCActors()`<br>`CombatComponentBase:Kill()` | Iterates through hostile actor combat components and calls `Kill()`. |
| **Combat Difficulty** | `CombatSubsystem:SetActionDifficulty(enum)` | Values: `0` = Story, `1` = Normal, `2` = Immersive, `3` = Hard. |
| **RPG Difficulty** | `CombatSubsystem:SetRPGDifficulty(enum)` | Values: `0` = Story, `1` = Normal, `2` = Immersive, `3` = Hard. |

### 4.2. Character Progression
| Feature | Engine Target / Reflection Path | Mechanism & Safety Rules |
| :--- | :--- | :--- |
| **Player Level** | `CharacterDevelopmentSubsystem:ForceLevelUpTo(level, true)` | Range: `1` to `99`. **CRITICAL**: Never set above 99 (table overflow crashes game). |
| **Level Cap** | `DogwoodCharacterDevelopmentSettings:LevelCap` | Range: `1` to `99`. Restores base value when reset. |
| **Grant XP** | `CharacterDevelopmentSubsystem:AddQuestXP(tier)` | Tier: `1` (Very Small) to `5` (Very Large). Triggers standard quest XP distribution. |
| **Readouts** | `GetCurrentLevel()`, `GetCurrentXP()`, `GetCurrentLevelXPRequirement(level)` | Polled to display in UI. |

### 4.3. Movement & Camera
| Feature | Engine Target / Reflection Path | Mechanism & Safety Rules |
| :--- | :--- | :--- |
| **Speed Multiplier** | `CharacterMovementComponent:MaxWalkSpeed` | Cached `BaseValues.walkSpeed * multiplier`. Range: `0.1` to `5.0`. Gated by 6 settle ticks. |
| **Jump Multiplier** | `CharacterMovementComponent:JumpZVelocity` | Cached `BaseValues.jumpZ * multiplier`. Range: `0.1` to `5.0`. Gated by 6 settle ticks. |
| **Movement Mode** | `CheatManager:Walk()`, `Fly()`, `Ghost()` | Engine cheat modes. Re-applied after respawn if active. |
| **Teleport** | `CheatManager:Teleport()` | Teleports player pawn to raycast aim point. |
| **Field of View** | `PlayerCameraManager:DefaultFOV` | Range: `0.1` to `5.0`. Clamped between `10.0` and `170.0` degrees to prevent camera inversion. |
| **Game Speed (Slomo)** | `CheatManager:Slomo(speed)` | Range: `0.1` to `4.0`. `1.0` is standard speed. |

### 4.4. Skills & Abilities
| Feature | Engine Target / Reflection Path | Mechanism & Safety Rules |
| :--- | :--- | :--- |
| **Add/Remove Trait Points** | `CharacterDevelopmentSubsystem:ReceiveTraitPoints(delta)` | Range: `-999` to `+999`. Negative removes unspent points only. |
| **Set Trait Points** | `CharacterDevelopmentSubsystem:SetTraitPointsAmount(total)` | Range: `0` to `999`. |
| **Unlock All Traits** | `CharacterDevelopmentSubsystem:UnlockAllTraits(true, true, true, false)` | Full tree unlock. |
| **Reset All Traits** | `CharacterDevelopmentSubsystem:ResetAllTraits()` | Full tree respec. |
| **Mutation Charges** | `CharacterDevelopmentSubsystem:AddMutationCharges(delta)` | Range: `-999` to `+999`. Controls vampire corruption charges. |
| **No Cooldowns** | `FocusAbilitiesSubsystem:ToggleDisablingAllCooldowns_Debug()` | Polled via `AreCooldownsEnabled_Debug()`. |
| **Keep Action Slots Full** | `PlayerAttributeSet:ChargedActionSlots` & `UnlockedActionSlots` | Continuously refills charged ability slots up to current unlocked capacity. |

### 4.5. World & Time
| Feature | Engine Target / Reflection Path | Mechanism & Safety Rules |
| :--- | :--- | :--- |
| **Set Time of Day** | `TimeSystemImpl:SetTime(Hour, Minute, 0, true)` | 24-hour format (`00:00` to `23:59`). |
| **Unlock Fast Travel** | `MappinSystemBlueprintLibrary:DebugUnlockAllFastTravelDestinations(journal)` | Found via `StaticFindObject` and `OpenWorldJournalImpl`. |
| **Reveal All Map Pins** | `OpenWorldJournalInterface:RevealAllMappins` | Contextual interface call on `OpenWorldJournalImpl`. |
| **NPC Level Override** | `DWSystemBlueprintFunctionLibrary:SetNpcLevelOverride(player, level)` | Range: `0` (reset) to `99`. |
| **Alert Level** | `CourtSubsystem:SetAlertLevelByInt(level)` | Range: `0` to `9`. |

### 4.6. Inventory, Economy & Crafting
| Feature | Engine Target / Reflection Path | Mechanism & Safety Rules |
| :--- | :--- | :--- |
| **Add/Remove Coins** | `InventoryComponent:AddCurrency(0, amount)` | Currency enum `0` = Coins. Range: `-999,999` to `+999,999`. |
| **Carry Weight Multiplier** | `InventoryComponent:WeightLimit` | Multiplies base carry weight limit. Range: `0.1` to `100.0`. |
| **Unlock All Recipes** | `CraftingSubsystem:UnlockAllCraftingRecipes()` | Unlocks every crafting schematic in the game. |
| **Dump Item Names** | Scans `ItemConsumableDataAsset`, `ItemIngredientDataAsset`, `ItemWeaponDataAsset`, `ItemClothingDataAsset` | Dumps localized `ItemName` FText to `UE4SS.log`. |
| **Self Check** | Scans all required UClasses and UObjects | Reports health status of all reflection hooks to `UE4SS.log`. |

### 4.7. Gear Granting & Removal (The `FItemHandle` Problem)
- **Root Cause**: The game's `FItemHandle` struct contains zero reflected `UProperty` members. UE4SS Lua's UFunction marshaler converts unreflected structs into empty Lua tables `{}`. Passing this to `TryAddItem` sends all-zero memory, creating placeholder items ("Bee Smoker").
- **Solution in C++ Mod (`DawnwalkerNativeFix`)**: Uses raw `ProcessEvent` + `std::memcpy` of the struct bytes directly between `GetItemHandle` and `TryAddItem`.
- **Refactoring for Pure UE4SS**:
  - `DawnwalkerNativeFix.dll` is already a UE4SS mod (`Mods/DawnwalkerNativeFix/dlls/main.dll`), NOT an external executable.
  - Currently, it polls `Mods/DawnwalkerNativeFix/command.txt`.
  - Refactoring replaces the file-polling with a registered console command (`dw_give <gearId> <qty>` and `dw_remove <gearId>`), callable directly from the in-game Lua UI or console via `ExecuteConsoleCommand()`.

---

## 5. Target Project Directory Structure

All legacy Node.js/Electron files will be removed. The resulting workspace will contain only the UE4SS mod:

```text
Mods/
├── DawnwalkerMod/
│   ├── enabled.txt                     # UE4SS activation flag
│   └── Scripts/
│       ├── main.lua                    # Entry point: lifecycle, async loops, event registration
│       ├── config.lua                  # User settings, keybind mappings, defaults, preset storage
│       ├── state.lua                   # In-memory mod state, base value caching, live stats
│       ├── safety.lua                  # Settle windows, cutscene detection, SafeIsValid wrappers
│       │
│       ├── features/
│       │   ├── combat.lua              # God mode, stamina, blood, damage amp, kill hostiles, difficulty
│       │   ├── character.lua           # Level, level cap, XP reward tiers
│       │   ├── movement.lua            # Speed, jump, movement modes (fly/ghost), teleport, FOV, slomo
│       │   ├── skills.lua              # Trait points, unlock/reset traits, mutation charges, cooldowns
│       │   ├── world.lua               # Time of day, fast travel, map pins, NPC/alert levels
│       │   └── inventory.lua           # Coins, carry weight, crafting recipes, self-check
│       │
│       ├── gear/
│       │   ├── catalog.lua             # Pure Lua conversion of all armor sets, weapons, rings, etc.
│       │   └── granter.lua             # Gear grant dispatcher (invoking native bridge or console cmd)
│       │
│       └── ui/
│           ├── hud_menu.lua            # In-game interactive Canvas/HUD overlay (pure Lua GUI)
│           ├── keybinds.lua            # Hotkey listeners (F1 toggle, cheats shortcuts)
│           └── console.lua             # In-game console command handlers (dw_god, dw_heal, etc.)
│
└── DawnwalkerNativeFix/                # (Optional / Recommended for Item Granting)
    ├── enabled.txt
    └── dlls/
        └── main.dll                    # Native C++ mod for raw FItemHandle memcpy
```

---

## 6. In-Game User Interface Specification

To replace the React web UI without any external window, the mod will implement a dual-layer in-game UI:

### 6.1. Primary UI: Interactive Canvas / HUD Overlay (`hud_menu.lua`)
- **Technology**: Built using Unreal Engine's `AHUD:ReceiveDrawHUD` or `PostRender` hook in pure Lua.
- **Activation**: Toggle with hotkey `F1` (or `Insert`).
- **Input Handling**:
  - When opened: sets `PlayerController.bShowMouseCursor = true`, sets input mode to Game & UI (or traps mouse/keyboard events).
  - When closed: restores normal cursor state and full game input.
  - Full keyboard navigation supported as a fail-safe (Arrow Keys to navigate, Enter/Space to toggle, `[`/`]` to adjust sliders).
- **Aesthetic**: Dark Gothic theme matching Dawnwalker:
  - Background: Semi-transparent charcoal/obsidian panel (`RGBA(18, 18, 22, 0.92)`).
  - Borders: Antique gold accent (`RGBA(198, 160, 82, 1.0)`).
  - Active text / glows: Crimson and pale gold.
- **Layout**:
  - **Header**: Title, game status (Pawn tracked, Combat status, Aggressive enemies count, Current time).
  - **Tab Bar**: Horizontal tabs:
    1. `[ Combat ]`
    2. `[ Character ]`
    3. `[ Movement ]`
    4. `[ Skills ]`
    5. `[ World ]`
    6. `[ Inventory & Gear ]`
    7. `[ Presets & Settings ]`
  - **Body Panel**: Renders interactive widgets for the active tab:
    - **Toggle Button**: `[X] Infinite Health`, `[ ] No Cooldowns` (clickable box with instant feedback).
    - **Slider / Stepper**: `< [ - ]  Speed: 1.5x  [ + ] >` (click buttons or drag slider).
    - **Action Button**: `[ HEAL NOW ]`, `[ KILL HOSTILES ]`, `[ UNLOCK ALL RECIPES ]`.
    - **Dropdown / Selector**: Item category picker and item selector with search or scroll.
  - **Footer**: Hotkey hint (`[F1] Close Menu | [NumPad 1] Heal | [NumPad 2] God Mode`).

### 6.2. Alternative UI: UE4SS Dear ImGui Tab (via C++ NativeFix)
- UE4SS contains an internal Dear ImGui renderer.
- `DawnwalkerNativeFix` can optionally register an ImGui tab using `register_tab()` in C++.
- When the UE4SS GUI is opened (default `F10`), a "Dawnwalker Mod" tab appears with full ImGui widgets (checkboxes, drag floats, combo boxes with search filters, and tree views).

### 6.3. Quick Keybinds (`keybinds.lua`)
For instant gameplay tweaks during combat without opening the menu:
| Keybind | Action | Notification Message |
| :--- | :--- | :--- |
| `F1` | Toggle In-Game Mod Menu | *"Dawnwalker Menu: Open / Closed"* |
| `NumPad 1` / `Alt+H` | Instant Heal & Stamina Refill | *"Health & Stamina Restored"* |
| `NumPad 2` / `Alt+G` | Toggle Infinite Health (God Mode) | *"Infinite Health: ON / OFF"* |
| `NumPad 3` / `Alt+S` | Toggle Infinite Stamina | *"Infinite Stamina: ON / OFF"* |
| `NumPad 4` / `Alt+B` | Toggle Infinite Blood | *"Infinite Blood: ON / OFF"* |
| `NumPad 5` / `Alt+M` | Cycle Movement Mode (`Walk` -> `Fly` -> `Ghost`) | *"Movement: Fly / Ghost / Walk"* |
| `NumPad 6` / `Alt+T` | Teleport to Aim Point | *"Teleported to aim point"* |
| `NumPad 7` / `Alt+K` | Kill All Aggressive Enemies | *"Killed N hostile enemies"* |
| `NumPad 8` / `Alt+C` | Toggle No Cooldowns | *"Ability Cooldowns: Disabled / Enabled"* |
| `NumPad 9` / `Alt+Z` | Fast Forward Time (Advance 1 Hour) | *"Time Advanced 1 Hour"* |

### 6.4. In-Game Console Commands (`console.lua`)
Registered with `RegisterConsoleCommandHandler()` for power users:
- `dw_menu`: Toggles the mod menu.
- `dw_god [0|1]`: Sets or toggles Infinite Health.
- `dw_stamina [0|1]`: Sets or toggles Infinite Stamina.
- `dw_blood [0|1]`: Sets or toggles Infinite Blood.
- `dw_heal`: Heals health and stamina to 100%.
- `dw_refillblood`: Refills all blood segments.
- `dw_speed <float>`: Sets movement speed multiplier (`0.1`–`5.0`).
- `dw_jump <float>`: Sets jump velocity multiplier (`0.1`–`5.0`).
- `dw_fly` / `dw_ghost` / `dw_walk`: Changes movement mode.
- `dw_teleport`: Teleports to aim crosshair.
- `dw_slomo <float>`: Sets game speed / time dilation (`0.1`–`4.0`).
- `dw_fov <float>`: Sets FOV multiplier.
- `dw_damage <float>`: Sets damage amplifier (`1.0`–`20.0`).
- `dw_kill`: Kills all aggressive enemies.
- `dw_level <int>`: Forces player level (`1`–`99`).
- `dw_levelcap <int>`: Sets level cap (`1`–`99`).
- `dw_xp <1-5>`: Grants quest XP tier.
- `dw_traits <int>`: Adds or removes trait points (`-999` to `+999`).
- `dw_unlocktraits`: Unlocks all traits in skill tree.
- `dw_resettraits`: Resets all traits.
- `dw_mutation <int>`: Adds or removes mutation charges.
- `dw_cooldowns [0|1]`: Toggles ability cooldowns.
- `dw_time <HH:MM>`: Sets time of day.
- `dw_fasttravel`: Unlocks all fast travel destinations.
- `dw_mappins`: Reveals all map pins.
- `dw_coins <int>`: Adds or removes coins (`-999999` to `+999999`).
- `dw_weight <float>`: Sets carry weight multiplier (`0.1`–`100.0`).
- `dw_recipes`: Unlocks all crafting recipes.
- `dw_give <gearId> [qty]`: Grants gear item or set.
- `dw_remove <gearId>`: Removes granted gear duplicate.
- `dw_preset <save|load|list> <name>`: Manages presets directly in-game.

---

## 7. Crash Prevention & Settle-Window Model

The original project had extensive crash-dump analysis (exception `0xC0000005`, access violation at offset `0x230`). These hard-learned safety rules **must be strictly preserved** in the new Lua scripts:

1. **Respawn & Pawn Settle Window**:
   - Freshly spawned pawns have uninitialized components. Calling `AddPlayerInvulnerability` or touching `CombatComponentBase` immediately upon respawn causes a fatal access violation that `pcall` cannot catch.
   - Guard: Maintain `CombatSettleTicksRemaining` (3 ticks = ~3 seconds) and `MovementSettleTicksRemaining` (6 ticks) whenever `Player:GetAddress()` changes.
2. **Combat Component Settle Window**:
   - If `CombatComponentBase` transitions from unresolvable to resolvable without a pawn address change (e.g. after a loading screen or cutscene), enforce a 3-tick delay (`CombatComponentSettleTicksRemaining`).
3. **Cutscene Safety**:
   - While `IsCutsceneActive(player)` is `true`, all persistent writes, damage amplification, and actions are paused. On exit from a cutscene, re-initialize settle counters as if a respawn occurred.
4. **Anti-Compounding Multiplier Cache**:
   - `BaseValues` table stores original game values (base walk speed, base jump, base FOV, base weight limit). Multipliers always scale from `BaseValues`, never from the current modified property.
5. **Table Boundary Safety**:
   - Player level and level cap must never exceed `99`. The game's XP curve tables end at level 99; higher numbers read unmapped engine memory.

---

## 8. Files to Deprecate and Remove

The following files and folders belong to the untrusted Electron/Node.js stack and must be deleted during reconstruction:

```text
FILES TO REMOVE:
├── package.json
├── package-lock.json
├── index.js
├── preload.js
├── bridge-protocol.js
├── mods-dir-resolver.js
├── Open Dawnwalker Mod App.cmd
├── Open Dawnwalker Mod App (Select Mods Folder).cmd
├── build/                                [all files]
├── ui/                                   [all files]
└── test/                                 [all files]
```

---

## 9. Reconstruction Roadmap & Execution Checklist

### Phase 1: Security Cleanup & Workspace Preparation
- [x] Verify that no background Node/Electron processes are running.
- [x] Back up `runtime-mods/` and `native-mods/` to preserve reference logic.
- [x] Remove `package.json`, `package-lock.json`, `index.js`, `preload.js`, `bridge-protocol.js`, and `mods-dir-resolver.js`.
- [x] Remove the `.cmd` launcher files and the `build/`, `ui/`, and `test/` directories.
- [x] Initialize the clean target directory: `runtime-mods/DawnwalkerMod/`.

### Phase 2: Gear & Data Catalog Porting
- [x] Parse `ui/src/data/GearCatalog.js` and `tools/gear-index.json` into a clean Lua module `catalog.lua`.
- [x] Include all 4-piece Armor Sets (e.g. `set_bloodslave1a`, `set_epic1a`–`9a`, `set_master1a`–`9a`, `set_superior1a`–`6a`, unique sets).
- [x] Include all Weapons (swords, axes, maces, hammers, knives, unique weapons).
- [x] Include all Armor Pieces (chest, legs, hands, feet).
- [x] Include all Rings, Amulets, and Trinkets.
- [x] Include all Consumables and Crafting Ingredients from `CRAFTABLE_CATALOG`.
- [x] Include Cleanup options (`cleanup_monastery_map`, `cleanup_all_granted_gear`).

### Phase 3: Core Lua Engine Architecture
- [x] Implement `safety.lua`:
  - [x] `SafeIsValid(UObject)` helper.
  - [x] `SameObject(a, b)` memory-address comparison.
  - [x] `IsCutsceneActive(player)` detection.
  - [x] Pawn settle state tracker (`RefreshPawnSettleState`).
- [x] Implement `state.lua`:
  - [x] In-memory active toggles (`infiniteHealth`, `infiniteStamina`, `infiniteBlood`, `noCooldowns`, etc.).
  - [x] Active multipliers (`speedMultiplier`, `jumpMultiplier`, `fovMultiplier`, `gameSpeed`, `damageAmplifier`, `carryWeightMultiplier`).
  - [x] Base value cache (`BaseValues.walkSpeed`, `BaseValues.jumpZ`, `BaseValues.fov`, `BaseValues.weightLimit`).
  - [x] Hostile enemy health tracker for damage amplification (`AmpHealth`).
- [x] Implement feature modules under `features/`:
  - [x] `combat.lua`: Multi-layered God Mode, stamina/blood locks, damage amplifier loop, heal actions, difficulty setters.
  - [x] `character.lua`: ForceLevelUpTo, LevelCap property setter, AddQuestXP.
  - [x] `movement.lua`: MaxWalkSpeed, JumpZVelocity, CheatManager Fly/Ghost/Walk, Teleport, Slomo, DefaultFOV.
  - [x] `skills.lua`: ReceiveTraitPoints, SetTraitPointsAmount, UnlockAllTraits, ResetAllTraits, AddMutationCharges, cooldown toggles, action slots refill loop.
  - [x] `world.lua`: TimeSystemImpl SetTime, FastTravel unlock, RevealAllMappins, NPC level override, Alert level.
  - [x] `inventory.lua`: AddCurrency, WeightLimit property setter, UnlockAllCraftingRecipes, SelfCheck diagnostic scan.

### Phase 4: In-Game Interactive Canvas/HUD Menu
- [x] Implement `ui/hud_menu.lua`:
  - [x] Hook `AHUD:ReceiveDrawHUD` or `PostRender`.
  - [x] Implement input state manager (toggle on `F1` or `Insert`, enable mouse cursor via `bShowMouseCursor`, capture mouse clicks and keyboard arrows).
  - [x] Draw background window, gold border accents, title bar, and system status readouts.
  - [x] Implement tab switcher (`Combat`, `Character`, `Movement`, `Skills`, `World`, `Gear`, `Settings`).
  - [x] Implement UI widgets:
    - [x] `DrawToggle(label, isChecked, onClick)`
    - [x] `DrawSlider(label, value, min, max, step, onChange)`
    - [x] `DrawButton(label, onClick)`
    - [x] `DrawDropdown(label, options, selected, onSelect)`
    - [x] `DrawReadout(label, value)`
  - [x] Connect all UI widgets to the corresponding feature modules in `features/`.

### Phase 5: Keybinds & In-Game Console Commands
- [x] Implement `ui/keybinds.lua`:
  - [x] Register `F1` for menu toggle.
  - [x] Register `NumPad 1`–`9` and `Alt+Key` shortcuts for God Mode, Heal, Stamina, Blood, Fly, Teleport, Kill Hostiles, Cooldowns, and Time.
  - [x] Display in-game HUD feedback toasts using `PlayerController:ClientMessage()`.
- [x] Implement `ui/console.lua`:
  - [x] Register all `dw_*` console commands with `RegisterConsoleCommandHandler`.
  - [x] Implement argument parsing and validation mirroring `bridge-protocol.js` safety rules.

### Phase 6: Gear Granter & NativeFix Modernization
- [x] Setup `DawnwalkerNativeFix` in `runtime-mods/DawnwalkerNativeFix/dlls/main.dll` using precompiled DLL.
- [x] Implement `gear/granter.lua`:
  - [x] Expose `GrantGear(gearId, quantity)` and `RemoveGear(gearId)` to the in-game Lua menu.
  - [x] Dispatches commands directly to NativeFix and executes console commands.

### Phase 7: Configuration & Presets
- [x] Implement `config.lua`:
  - [x] Load/save user preferences to `Mods/DawnwalkerMod/presets.txt` using structured format.
  - [x] Preset manager: Save named setups and apply them with one click or command.

### Phase 8: Deployment & User Readiness
- [x] Update `runtime-mods/mods.txt` with active `DawnwalkerMod : 1` and `DawnwalkerNativeFix : 1`.
- [x] Generate comprehensive, clean `README.md` with detailed installation, in-game controls, hotkeys, and console command references.

---

## 10. Master Instruction for Subsequent Agents / Developers

This `todo.md` document contains the complete, authoritative specification for the reconstructed Blood of the Dawnwalker mod. **No other legacy files need to be consulted.** Follow the 8 execution phases in order, adhering strictly to the settle-window crash guards and reflection targets detailed in Sections 4, 6, and 7.
