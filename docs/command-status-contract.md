# Engine Features & Reflection Reference Sheet

This document catalogs every supported feature, Unreal Engine reflection target, class path, and function signature utilized by **DawnwalkerMod**.

---

## 1. Combat & Survivability

| Feature | Engine Class & Method / Property | Arguments & Types | Notes |
| :--- | :--- | :--- | :--- |
| **Player Invulnerability** | `/Script/DogwoodCombat.RebelAISubsystem:AddPlayerInvulnerability`<br>`RemovePlayerInvulnerability` | `(APlayerCharacter* Player)` | Primary damage immunity call. Must wait for post-respawn settle window. |
| **GAS Invulnerability** | `/Script/GameplayAbilities.AbilitySystemComponent:BP_ApplyGameplayEffectToSelf` | `(TSubclassOf<UGameplayEffect> EffectClass, float Level, FGameplayEffectContextHandle Context)` | Applies `/Game/_Dawnwalker/Abilities/Player/GE_Invulnerability.GE_Invulnerability_C`. |
| **Engine God Mode** | `/Script/Engine.CheatManager:God` | None | Engine cheat manager god mode toggle. |
| **Health Lock** | `/Script/DogwoodCombat.CombatComponentBase:LockHealth`<br>`UnlockHealth` | None | Owned by player pawn. |
| **Set Health** | `/Script/DogwoodCombat.CombatComponentBase:SetHealthPercent` | `(float InPercent)` | `1.0` = 100%. |
| **Stamina Lock** | `/Script/DogwoodCombat.CombatComponentBase:LockStamina`<br>`UnlockStamina` | None | Owned by player pawn. |
| **Set Stamina** | `/Script/DogwoodCombat.CombatComponentBase:SetStaminaPercent` | `(float InPercent)` | `1.0` = 100%. |
| **Blood Lock** | `/Script/DogwoodStats.BloodBarComponent:LockBlood`<br>`UnlockBlood` | None | Lives on `PlayerState`. |
| **Set Blood** | `/Script/DogwoodStats.BloodBarComponent:SetBloodPercent` | `(float InBloodPercent)` | `1.0` = 100%. |
| **Replenish Blood** | `/Script/DogwoodStats.BloodBarComponent:HealAndReplenishAllSegments` | None | Restores all vampire blood segments. |
| **Hostile NPCs List** | `/Script/DogwoodCombat.CombatSubsystem:GetAllAggressiveNPCActors` | Returns `TArray<AActor*>` | Returns list of hostile enemies. |
| **Enemy Kill** | `/Script/DogwoodCombat.CombatComponentBase:Kill` | None | Eliminates target actor. |
| **Action Difficulty** | `/Script/DogwoodCombat.CombatSubsystem:SetActionDifficulty` | `(int32 Difficulty)` | `0` = Story, `1` = Normal, `2` = Immersive, `3` = Hard. |
| **RPG Difficulty** | `/Script/DogwoodCombat.CombatSubsystem:SetRPGDifficulty` | `(int32 Difficulty)` | `0` = Story, `1` = Normal, `2` = Immersive, `3` = Hard. |

---

## 2. Character Progression

| Feature | Engine Class & Method / Property | Arguments & Types | Notes |
| :--- | :--- | :--- | :--- |
| **Force Level** | `/Script/DogwoodCharacterDevelopment.CharacterDevelopmentSubsystem:ForceLevelUpTo` | `(int32 Level, bool bReceiveTraitPoints)` | Clamped to `[1, 99]`. Levels >99 crash the game. |
| **Level Cap** | `/Script/DogwoodCharacterDevelopment.DogwoodCharacterDevelopmentSettings:LevelCap` | `int8` Property | Clamped to `[1, 99]`. |
| **Quest XP Grant** | `/Script/DogwoodCharacterDevelopment.CharacterDevelopmentSubsystem:AddQuestXP` | `(int32 RewardAmountEnum)` | `1` = Very Small, `2` = Small, `3` = Medium, `4` = Large, `5` = Very Large. |
| **Get Level** | `CharacterDevelopmentSubsystem:GetCurrentLevel` | Returns `int32` | Current player level. |
| **Get Current XP** | `CharacterDevelopmentSubsystem:GetCurrentXP` | Returns `int32` | Accumulated XP in current level. |
| **Get XP Requirement**| `CharacterDevelopmentSubsystem:GetCurrentLevelXPRequirement` | `(int32 Level)` -> Returns `int32` | XP needed to advance. |

---

## 3. Movement, Camera & Time Scale

| Feature | Engine Class & Method / Property | Arguments & Types | Notes |
| :--- | :--- | :--- | :--- |
| **Walk Speed** | `/Script/Engine.CharacterMovementComponent:MaxWalkSpeed` | `float` Property | Scaled from cached `BaseValues.walkSpeed`. Multiplier `[0.1, 5.0]`. |
| **Jump Height** | `/Script/Engine.CharacterMovementComponent:JumpZVelocity` | `float` Property | Scaled from cached `BaseValues.jumpZ`. Multiplier `[0.1, 5.0]`. |
| **Fly Mode** | `/Script/Engine.CheatManager:Fly` | None | Engine cheat flight mode. |
| **Ghost Mode** | `/Script/Engine.CheatManager:Ghost` | None | Engine cheat noclip flight mode. |
| **Walk Mode** | `/Script/Engine.CheatManager:Walk` | None | Restores normal ground walking. |
| **Teleport** | `/Script/Engine.CheatManager:Teleport` | None | Teleports pawn to raycast aim point. |
| **Field of View** | `/Script/Engine.PlayerCameraManager:DefaultFOV` | `float` Property | Clamped between `10.0` and `170.0` degrees. |
| **Game Speed** | `/Script/Engine.CheatManager:Slomo` | `(float NewTimeDilation)` | Range `[0.1, 4.0]`. `1.0` is normal speed. |

---

## 4. Skills & Abilities

| Feature | Engine Class & Method / Property | Arguments & Types | Notes |
| :--- | :--- | :--- | :--- |
| **Receive Points** | `/Script/DogwoodCharacterDevelopment.CharacterDevelopmentSubsystem:ReceiveTraitPoints` | `(int32 Value)` | Delta `[-999, 999]`. Negative removes unspent points. |
| **Set Points** | `/Script/DogwoodCharacterDevelopment.CharacterDevelopmentSubsystem:SetTraitPointsAmount` | `(int32 Value)` | Total unspent points `[0, 999]`. |
| **Unlock All Traits** | `/Script/DogwoodCharacterDevelopment.CharacterDevelopmentSubsystem:UnlockAllTraits` | `(bool bUnlock, bool bUnblock, bool bUnhide, bool bUnblockNextLevelOnly)` | Called with `(true, true, true, false)`. |
| **Reset Traits** | `/Script/DogwoodCharacterDevelopment.CharacterDevelopmentSubsystem:ResetAllTraits` | None | Full trait tree respec. |
| **Mutation Charges** | `/Script/DogwoodCharacterDevelopment.CharacterDevelopmentSubsystem:AddMutationCharges` | `(int32 ChargeValue)` | Delta `[-999, 999]`. Controls vampire corruption. |
| **Toggle Cooldowns** | `/Script/DogwoodFocus.FocusAbilitiesSubsystem:ToggleDisablingAllCooldowns_Debug` | None | Eliminates ability cooldowns. |
| **Check Cooldowns** | `/Script/DogwoodFocus.FocusAbilitiesSubsystem:AreCooldownsEnabled_Debug` | Returns `bool` | Queries cooldown state. |
| **Action Slots Override**| `/Script/DogwoodCombat.CombatFocusComponent:SetSlotsChargedOverride` | `(int32 Slots)` | Automatically keeps activation charges full. |

---

## 5. World & Time

| Feature | Engine Class & Method / Property | Arguments & Types | Notes |
| :--- | :--- | :--- | :--- |
| **Set Time** | `/Script/DogwoodSystem.TimeSystemImpl:SetTime` | `(int32 Hour, int32 Minute, int32 Second, bool bAbsoluteTime)` | Sets in-game clock (`00:00` to `23:59`). |
| **Unlock Fast Travel**| `/Script/DogwoodMap.MappinSystemBlueprintLibrary:DebugUnlockAllFastTravelDestinations` | `(UObject* OpenWorldJournal)` | Unlocks all fast travel destinations on map. |
| **Reveal Map Pins** | `/Script/DogwoodMap.OpenWorldJournalInterface:RevealAllMappins` | `(UObject* Context)` | Called with `OpenWorldJournalImpl` as explicit context. |
| **NPC Level Override**| `/Script/DogwoodSystem.Default__DWSystemBlueprintFunctionLibrary:SetNpcLevelOverride` | `(AActor* Player, int32 Level)` | Range `[0, 99]`. `0` resets to normal scaling. |
| **Alert Level** | `/Script/DogwoodSystem.CourtSubsystem:SetAlertLevelByInt` | `(int32 AlertLevel)` | Range `[0, 9]`. |

---

## 6. Inventory & Economy

| Feature | Engine Class & Method / Property | Arguments & Types | Notes |
| :--- | :--- | :--- | :--- |
| **Add Currency** | `/Script/DogwoodInventory.InventoryComponent:AddCurrency` | `(int32 CurrencyType, int32 Quantity)` | Type `0` = Coins. Range `[-999999, 999999]`. |
| **Carry Weight Limit**| `/Script/DogwoodInventory.InventoryComponent:WeightLimit` | `float` Property | Scaled from base weight limit. Multiplier `[0.1, 100.0]`. |
| **Unlock Recipes** | `/Script/DogwoodInventory.CraftingSubsystem:UnlockAllCraftingRecipes` | None | Unlocks all crafting schematics. |
