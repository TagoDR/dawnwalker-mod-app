# UE4SS In-Engine Mod Specification

This document defines the runtime architecture and execution model of **DawnwalkerMod** within UE4SS.

---

## 1. Runtime Lifecycle

When the game boots with UE4SS:
1. UE4SS parses `Mods/mods.txt`.
2. UE4SS loads `DawnwalkerNativeFix/dlls/main.dll` (if enabled) and calls `start_mod()`.
3. UE4SS initializes the Lua state and executes `DawnwalkerMod/Scripts/main.lua`.
4. `main.lua` hooks the HUD drawing event via `RegisterHook("/Script/Engine.HUD:ReceiveDrawHUD", ...)`.
5. Keybinds and console commands are registered.
6. Two asynchronous loops are started via `LoopAsync`:
   - **Main Loop** (1000ms interval)
   - **Damage Amplifier Loop** (100ms interval)

---

## 2. In-Memory State Model

Unlike legacy versions that communicated via disk files (`command.txt` / `status.txt`), state is held entirely in memory in `state.lua`:

* `State.Toggles`: Boolean flags (`infiniteHealth`, `infiniteStamina`, `infiniteBlood`, `noCooldowns`, `keepActionSlotsCharged`).
* `State.Multipliers`: Numeric multipliers (`speedMultiplier`, `jumpMultiplier`, `fovMultiplier`, `gameSpeed`, `damageAmplifier`, `carryWeightMultiplier`).
* `State.Gameplay`: Game adjustments (`levelCap`, `actionDifficulty`, `rpgDifficulty`, `movementMode`).
* `State.BaseValues`: Cached vanilla values to prevent compounding on repeated ticks.
* `State.Readouts`: Live telemetry polled each second (level, XP, trait points, day, time, hostile NPC count).

---

## 3. Asynchronous Execution Loops

### Main Tick Loop (1000ms):
* **Pawn Tracking**: Calls `Safety.RefreshPawnSettleState()`. Detects pawn destruction/reconstruction across deaths and level loads.
* **Cutscene Stand-Down**: Calls `Safety.IsCutsceneActive(player)`. Pauses all writes during cutscenes or dialogues.
* **Feature Module Ticking**:
  - `Combat.Tick(player, combatSettling)`
  - `Character.Tick()`
  - `Movement.Tick(player, movementSettling)`
  - `Skills.Tick(player)`
  - `World.Tick()`
  - `Inventory.Tick(player)`
* **Passive Item Name Capture**: When an in-game inventory/menu is open (`Safety.IsMenuOpen()`), scans loaded item data assets and logs newly resolved localized names to `UE4SS.log`.

### Damage Amplifier Loop (100ms):
* Runs on a tight 100ms timer to ensure bonus damage lands responsively after the player's attack.
* Queries `CombatSubsystem:GetAllAggressiveNPCActors()`.
* Tracks health percentages in `State.Internal.AmpHealth`.
* When an enemy's health decreases, calculates the delta and re-applies `delta * (multiplier - 1)` using `CombatComponentBase:SetHealthPercent()` or `Kill()`.
* Automatically settles and baselines when the player pawn address changes.

---

## 4. Crash Prevention Architecture

The mod isolates gameplay writes behind strict validation:
1. **`SafeIsValid(UObject)`**: Protects against stale pointers.
2. **`SameObject(a, b)`**: Compares raw object memory addresses (`GetAddress()`) rather than Lua userdata handles.
3. **Pawn Settle Counters**:
   - `CombatSettleTicksRemaining` (3 ticks): Gating for `CombatComponentBase` and `RebelAISubsystem:AddPlayerInvulnerability`.
   - `MovementSettleTicksRemaining` (6 ticks): Gating for `CharacterMovementComponent`.
4. **Cutscene Safety**: Gated by `CinematicSubsystem:IsDialogueActive()`, `IsCharacterInCinematicDialogueOrCutscene()`, and `FocusAbilitiesSubsystem:GetIsInFocusAbilityCinematicMode()`.
