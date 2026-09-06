# Protocol & Native Interfaces Reference

This document is the canonical reference for the runtime interfaces, native plugin communication, and configuration persistence protocols in **DawnwalkerMod**.

---

## 1. Architectural Shift: Zero-Latency In-Memory State

In legacy versions, the mod used a file-polling IPC architecture (`command.txt` and `status.txt` polled every 200–500ms by an external Electron application). 

In **DawnwalkerMod v2.0+**:
- **Zero File Polling**: All feature toggles, multipliers, and live game telemetry reside in memory within [`state.lua`](file:///C:/Users/Admin/WebstormProjects/dawnwalker-mod-app-master/runtime-mods/DawnwalkerMod/Scripts/state.lua).
- **Zero Latency**: Actions invoked from the in-game HUD menu, keybinds, or console commands execute synchronously in the same frame or within the 100ms/1000ms engine tick cycles.
- **Direct Engine Reflection**: Gameplay parameters are modified directly using UE4SS reflection calls against Unreal Engine subsystem singletons and player pawn components.

---

## 2. Presets Persistence Protocol (`presets.txt`)

User presets are persisted in a flat, human-readable key-value format located at:
`The Blood of Dawnwalker\Dawnwalker\Binaries\Win64\Mods\DawnwalkerMod\presets.txt`

### File Format Specification
```ini
# DawnwalkerMod Presets Configuration
# Section header defines the preset name
[Default]
infiniteHealth=0
infiniteStamina=0
infiniteBlood=0
noCooldowns=0
keepActionSlotsCharged=0
speedMultiplier=1.00
jumpMultiplier=1.00
fovMultiplier=1.00
gameSpeed=1.00
damageAmplifier=1.00
carryWeightMultiplier=1.00
levelCap=99
actionDifficulty=1
rpgDifficulty=1
movementMode=Walk

[GodMode]
infiniteHealth=1
infiniteStamina=1
infiniteBlood=1
noCooldowns=1
keepActionSlotsCharged=1
damageAmplifier=5.00
speedMultiplier=1.50
jumpMultiplier=1.20
fovMultiplier=1.00
gameSpeed=1.00
carryWeightMultiplier=10.00
levelCap=99
actionDifficulty=0
rpgDifficulty=0
movementMode=Walk
```

### Parser Rules ([`config.lua`](file:///C:/Users/Admin/WebstormProjects/dawnwalker-mod-app-master/runtime-mods/DawnwalkerMod/Scripts/config.lua))
- Lines starting with `#` or `;` are treated as comments and ignored.
- Section headers `[PresetName]` demarcate distinct saved profiles.
- Key-value pairs are delimited by `=` with whitespace trimmed.
- Boolean keys accept `1`/`0` or `true`/`false`.
- Float values are parsed via `tonumber()` and validated against safe bounds before application.
- Unknown keys are preserved or safely ignored without throwing runtime exceptions.

---

## 3. Native Plugin Interface (`DawnwalkerNativeFix`)

### The Problem: `FItemHandle` Struct Marshalling
The game's inventory system relies on an engine struct named `FItemHandle`. This struct contains **zero reflected `UProperty` members**. 
- When UE4SS Lua attempts to pass an unreflected struct into `UFunction` calls such as `InventoryComponent:TryAddItem(FItemHandle)`, the Lua-to-C++ marshaler constructs an empty table `{}`.
- Passing an uninitialized struct with all-zero bytes results in the game granting a placeholder fallback item ("Bee Smoker") instead of the desired item.

### The Solution: Byte-Level `memcpy` via C++ Mod
To resolve this, the project includes a compiled UE4SS native C++ plugin located at:
`The Blood of Dawnwalker\Dawnwalker\Binaries\Win64\Mods\DawnwalkerNativeFix/dlls/main.dll`

`DawnwalkerNativeFix` implements raw `ProcessEvent` invocation and directly copies the 32-byte `FItemHandle` memory buffer into the engine call parameters.

### IPC Command Protocol (`DawnwalkerNativeFix/command.txt`)
When [`granter.lua`](file:///C:/Users/Admin/WebstormProjects/dawnwalker-mod-app-master/runtime-mods/DawnwalkerMod/Scripts/gear/granter.lua) dispatches an item grant request:

1. **File Path**: `Mods/DawnwalkerNativeFix/command.txt`
2. **Command Format**:
   ```txt
   nonce=1725487600-98765
   action=giveGear
   gearId=weapon_swordvampiric1a
   quantity=1
   ```
3. **Console Command Fallback**: If the native mod exposes the console command handler, `granter.lua` also attempts execution via:
   ```text
   dw_native_give <gearId> <quantity>
   ```
4. **Execution Cycle**:
   - `DawnwalkerNativeFix` detects the fresh `nonce`.
   - Looks up the item asset path in its internal registry or uses the resolved `UItemDataAsset` handle.
   - Invokes `TryAddItem` with the populated byte buffer.
   - Clears or updates `command.txt` upon completion.

---

## 4. In-Game Console Command Protocol

All mod commands are registered into the Unreal Engine console subsystem via UE4SS `RegisterConsoleCommandHandler`:

| Command Signature | Parameter Parsing | Target Module | Description |
| :--- | :--- | :--- | :--- |
| `dw_menu` | None | `ui/hud_menu.lua` | Toggles in-game Canvas HUD overlay |
| `dw_god [0\|1]` | Optional boolean | `features/combat.lua` | Toggles or sets God Mode |
| `dw_heal` | None | `features/combat.lua` | Instantly replenishes HP & Stamina |
| `dw_refillblood` | None | `features/combat.lua` | Refills all vampire blood segments |
| `dw_speed <float>` | Clamped `[0.1, 5.0]` | `features/movement.lua` | Sets movement speed multiplier |
| `dw_jump <float>` | Clamped `[0.1, 5.0]` | `features/movement.lua` | Sets jump height multiplier |
| `dw_fly` / `dw_ghost` / `dw_walk` | None | `features/movement.lua` | Sets cheat movement mode |
| `dw_teleport` | None | `features/movement.lua` | Teleports pawn to raycast crosshair |
| `dw_slomo <float>` | Clamped `[0.1, 4.0]` | `features/movement.lua` | Sets game time dilation |
| `dw_fov <float>` | Clamped `[0.1, 3.0]` | `features/movement.lua` | Sets camera FOV multiplier |
| `dw_damage <float>` | Clamped `[1.0, 20.0]` | `features/combat.lua` | Sets damage amplifier ratio |
| `dw_kill` | None | `features/combat.lua` | Kills all aggressive hostile NPCs |
| `dw_level <int>` | Clamped `[1, 99]` | `features/character.lua` | Forces character level |
| `dw_levelcap <int>` | Clamped `[1, 99]` | `features/character.lua` | Sets character progression level cap |
| `dw_xp <1-5>` | Enum `[1, 5]` | `features/character.lua` | Grants quest XP reward tier |
| `dw_traits <int>` | Signed integer | `features/skills.lua` | Adds or removes trait points |
| `dw_unlocktraits` | None | `features/skills.lua` | Unlocks all trait tree skills |
| `dw_resettraits` | None | `features/skills.lua` | Resets all trait tree skills |
| `dw_mutation <int>` | Signed integer | `features/skills.lua` | Modifies vampire mutation charges |
| `dw_cooldowns [0\|1]`| Optional boolean | `features/skills.lua` | Toggles ability cooldown removal |
| `dw_time <HH:MM>` | 24-hour time string | `features/world.lua` | Sets exact world clock time |
| `dw_fasttravel` | None | `features/world.lua` | Unlocks all fast travel waypoints |
| `dw_mappins` | None | `features/world.lua` | Unlocks and reveals all map pins |
| `dw_coins <int>` | Signed integer | `features/inventory.lua` | Adds or removes currency |
| `dw_weight <float>` | Clamped `[0.1, 100.0]`| `features/inventory.lua` | Scales inventory carry weight limit |
| `dw_recipes` | None | `features/inventory.lua` | Unlocks all crafting schematics |
| `dw_selfcheck` | None | `features/inventory.lua` | Runs engine reflection diagnostics |
| `dw_give <id> [qty]` | String ID, optional int | `gear/granter.lua` | Grants item or full armor set |
| `dw_remove <id>` | String ID | `gear/granter.lua` | Removes item from inventory |
| `dw_preset <save\|apply> <name>` | Mode & name strings | `config.lua` | Saves or applies configuration preset |

---

## 5. Live Telemetry & Readouts Protocol

Every 1000ms, the main async loop queries engine subsystems and updates `State.Readouts`:

```lua
State.Readouts = {
    level = 1,              -- CharacterDevelopmentSubsystem:GetCurrentLevel()
    xp = 0,                 -- CharacterDevelopmentSubsystem:GetCurrentXP()
    xpRequired = 1000,      -- CharacterDevelopmentSubsystem:GetCurrentLevelXPRequirement()
    traitPoints = 0,        -- CharacterDevelopmentSubsystem:GetUnspentTraitPoints()
    worldDay = 1,           -- DayNightSubsystem:GetDayNumber()
    worldTime = "12:00",    -- DayNightSubsystem:GetFormattedTime()
    hostileCount = 0,       -- Length of CombatSubsystem:GetAllAggressiveNPCActors()
    cutsceneActive = false, -- Safety.IsCutsceneActive()
    combatSettling = false, -- Safety.CombatSettleTicksRemaining > 0
    movementSettling = false-- Safety.MovementSettleTicksRemaining > 0
}
```

This telemetry is rendered live on the HUD menu footer and utilized by safety guards to prevent invalid engine writes.
