# In-Game Menu Architecture & State Management Specification

This document details the in-engine menu structure, state synchronization model, and feature matrix of **DawnwalkerMod**.

---

## 1. Direct-to-State Architecture

In legacy versions, user interactions traversed multiple layers (React UI -> IPC Bridge -> Node.js Main -> File Write -> Lua Poller). 

In **DawnwalkerMod v2.0+**:
- **Direct Table Binding**: The menu directly reads from and writes to the global `State` table in [`state.lua`](file:///C:/Users/Admin/WebstormProjects/dawnwalker-mod-app-master/runtime-mods/DawnwalkerMod/Scripts/state.lua).
- **Synchronous Updates**: When a player toggles a cheat or steps a multiplier, the change is written immediately to memory and picked up by the feature module in the same frame or on the next loop cycle.
- **No Virtual DOM Overhead**: The Canvas HUD renders state on demand each frame with minimal memory footprint.

---

## 2. Feature Matrix & Tab Breakdown

The in-game menu (`ui/hud_menu.lua`) organizes features across seven intuitive tabs:

### Tab 1: Combat & Survivability
| Row / Control | Type | State Binding | Underlying Engine Mechanism |
| :--- | :--- | :--- | :--- |
| **God Mode** | Toggle | `State.Toggles.infiniteHealth` | `RebelAISubsystem:AddPlayerInvulnerability`, GAS `GE_Invulnerability`, `LockHealth()` |
| **Infinite Stamina** | Toggle | `State.Toggles.infiniteStamina` | `CombatComponentBase:LockStamina()`, `SetStaminaPercent(1.0)` |
| **Infinite Blood** | Toggle | `State.Toggles.infiniteBlood` | `BloodBarComponent:LockBlood()`, `SetBloodPercent(1.0)` |
| **Instant Heal** | Action | One-shot trigger | Restores HP to 100%, refuels stamina, refills all vampire blood segments |
| **Damage Multiplier** | Stepper | `State.Multipliers.damageAmplifier` | Scaled damage loop (1.0x to 20.0x) tracking enemy health deltas |
| **Kill Hostiles** | Action | One-shot trigger | Queries `GetAllAggressiveNPCActors()` and calls `CombatComponentBase:Kill()` |
| **Action Difficulty** | Cycle | `State.Gameplay.actionDifficulty` | `CombatSubsystem:SetActionDifficulty(0-3)` (Story, Normal, Immersive, Hard) |
| **RPG Difficulty** | Cycle | `State.Gameplay.rpgDifficulty` | `CombatSubsystem:SetRPGDifficulty(0-3)` (Story, Normal, Immersive, Hard) |

### Tab 2: Character Progression
| Row / Control | Type | State Binding | Underlying Engine Mechanism |
| :--- | :--- | :--- | :--- |
| **Player Level** | Stepper | Direct engine call | `CharacterDevelopmentSubsystem:ForceLevelUpTo(Level, true)` clamped `[1, 99]` |
| **Level Cap** | Stepper | `State.Gameplay.levelCap` | `DogwoodCharacterDevelopmentSettings:LevelCap` clamped `[1, 99]` |
| **Quest XP Reward** | Action | Enum `[1, 5]` | `CharacterDevelopmentSubsystem:AddQuestXP(RewardTier)` |
| **Current Level** | Readout | `State.Readouts.level` | Current character level queried from engine |
| **XP Progress** | Readout | `State.Readouts.xp` / `xpRequired` | Real-time XP progress bar and numbers |

### Tab 3: Movement & Camera
| Row / Control | Type | State Binding | Underlying Engine Mechanism |
| :--- | :--- | :--- | :--- |
| **Movement Speed** | Stepper | `State.Multipliers.speedMultiplier` | `CharacterMovementComponent:MaxWalkSpeed` scaled from cached base value |
| **Jump Height** | Stepper | `State.Multipliers.jumpMultiplier` | `CharacterMovementComponent:JumpZVelocity` scaled from cached base value |
| **Movement Mode** | Cycle | `State.Gameplay.movementMode` | `CheatManager:Fly()`, `Ghost()`, or `Walk()` |
| **Teleport** | Action | One-shot trigger | `CheatManager:Teleport()` to player camera line-trace hit point |
| **Field of View** | Stepper | `State.Multipliers.fovMultiplier` | `PlayerCameraManager:DefaultFOV` scaled `[10.0, 170.0]` |
| **Game Speed** | Stepper | `State.Multipliers.gameSpeed` | `CheatManager:Slomo(Dilation)` `[0.1, 4.0]` |

### Tab 4: Skills & Abilities
| Row / Control | Type | State Binding | Underlying Engine Mechanism |
| :--- | :--- | :--- | :--- |
| **Trait Points** | Stepper | Direct engine call | `CharacterDevelopmentSubsystem:ReceiveTraitPoints(Delta)` |
| **Unlock All Traits** | Action | One-shot trigger | Loops trait progression tree and activates all unlocked perks |
| **Reset All Traits** | Action | One-shot trigger | Respecs all perks and refunds spent trait points |
| **Vampire Mutation** | Stepper | Direct engine call | Modifies mutation / corruption charge counter |
| **No Cooldowns** | Toggle | `State.Toggles.noCooldowns` | Resets ability cooldown timers via `FocusAbilitiesSubsystem` |
| **Keep Slots Charged** | Toggle | `State.Toggles.keepActionSlotsCharged` | Continuously tops up unlocked ability activation charges |

### Tab 5: World & Environment
| Row / Control | Type | State Binding | Underlying Engine Mechanism |
| :--- | :--- | :--- | :--- |
| **Time of Day** | Stepper | Direct engine call | `DayNightSubsystem:SetTimeOfDay(Hours, Minutes)` |
| **Advance Time** | Action | One-shot trigger | Advances world clock forward by 1 hour |
| **Fast Travel** | Action | One-shot trigger | Unlocks all map fast-travel waypoints |
| **Reveal Map Pins** | Action | One-shot trigger | Discovers and reveals all POIs, shrines, and points of interest |
| **NPC Level Override**| Stepper | `State.Gameplay.npcLevelOverride` | Sets global world NPC level scaling |
| **Alert Level** | Stepper | `State.Gameplay.alertLevel` | Sets town/guard hostility and alert status |

### Tab 6: Gear & Inventory Catalog
| Row / Control | Type | State Binding | Underlying Engine Mechanism |
| :--- | :--- | :--- | :--- |
| **Category Filter** | Cycle | Catalog filter | Weapons, Armor Sets, Armor Pieces, Accessories, Consumables |
| **Catalog Item List**| List | Catalog selection | 800+ cataloged items with display names and internal IDs |
| **Grant Item / Set** | Action | One-shot trigger | Calls `granter.lua` -> `DawnwalkerNativeFix` (byte-level `FItemHandle` copy) |
| **Remove Duplicates**| Action | One-shot trigger | Cleans up inventory duplicate item handles |
| **Add Coins** | Action | Quantity prompt | `InventoryComponent:AddCurrency(Amount)` |
| **Carry Weight** | Stepper | `State.Multipliers.carryWeightMultiplier` | Multiplies maximum inventory weight limit (up to 100x) |
| **Unlock Recipes** | Action | One-shot trigger | Unlocks all crafting schematics in player recipe registry |

### Tab 7: Configuration & Presets
| Row / Control | Type | State Binding | Underlying Engine Mechanism |
| :--- | :--- | :--- | :--- |
| **Save Preset** | Action | Preset name input | Serializes current `State` values to `Mods/DawnwalkerMod/presets.txt` |
| **Apply Preset** | Action | Preset selector | Loads and validates saved preset values from `presets.txt` |
| **Reset to Defaults**| Action | One-shot trigger | Restores all settings to vanilla game defaults |

---

## 3. Real-Time Telemetry & Visual Feedback

The menu renders a persistent status footer displaying real-time engine telemetry polled on the 1000ms loop:
- **Level & XP**: Shows current level and progression toward next level.
- **World Time & Day**: Shows current in-game day number and 24-hour clock.
- **Aggressive Enemies**: Displays count of hostile NPCs currently targeting the player.
- **Safety Indicators**: Warns the player if a cinematic cutscene is active or if post-respawn settle windows are counting down.

### Onscreen HUD Notifications
When actions are executed or hotkeys are pressed, feedback is delivered directly to the player via:
- **`APlayerController:ClientMessage(Message)`**: Standard Unreal Engine onscreen chat/message toast.
- **`UE4SS.log`**: Detailed diagnostics logged to disk for developer auditing.
