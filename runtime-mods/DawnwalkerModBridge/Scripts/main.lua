-- DawnwalkerModBridge: applies gameplay changes requested by the Dawnwalker Mod App.
-- Protocol: the Electron app writes Mods/DawnwalkerModBridge/command.txt (simple key=value lines).
-- This mod polls that file, applies changes via live reflection, and writes
-- Mods/DawnwalkerModBridge/status.txt so the app can show the result back to the user.
--
-- Verified live targets (from UE4SS_ObjectDump.txt):
--   /Script/DogwoodCharacterDevelopment.DogwoodCharacterDevelopmentSettings:LevelCap (Int8Property)
--   /Script/DogwoodCharacterDevelopment.CharacterDevelopmentSubsystem:ForceLevelUpTo(Level, bReceiveTraitPoints)
--   /Script/DogwoodCharacterDevelopment.CharacterDevelopmentSubsystem:GetCurrentLevel() / GetCurrentXP()
--   /Script/DogwoodCombat.CombatComponentBase:SetHealthPercent(InPercent) / SetStaminaPercent(InPercent)
--   /Script/DogwoodCombat.CombatComponentBase:GetHealthPercentage() / GetStaminaPercentage()
--   /Script/Engine.CharacterMovementComponent:MaxWalkSpeed / JumpZVelocity (FloatProperty)
--   /Script/Engine.PlayerCameraManager:DefaultFOV (FloatProperty)
--   /Script/Engine.CheatManager:Slomo(NewTimeDilation)
--   /Script/Engine.CheatManager:God() (toggle, no return value/getter)
--   /Script/DogwoodStats.CharacterBaseAttributeSet:Health / MaxHealth (FGameplayAttributeData
--     struct properties with CurrentValue/BaseValue floats) via
--     AbilitySystemComponent:GetAttributeSet(AttributeSetClass)

local UEHelpers = require("UEHelpers")

local COMMAND_PATH = "Mods/DawnwalkerModBridge/command.txt"
local STATUS_PATH = "Mods/DawnwalkerModBridge/status.txt"

local LastRequestId = nil
local LastNukeRequestId = nil
local LastNukeTargetResult = nil
local PendingGiveBestGear = false
local LastGiveBestGearResult = nil
local WasCombatFound = false
local ReportedLockHealthError = false
local ReportedUnlockHealthError = false
local ReportedLockStaminaError = false
local ReportedUnlockStaminaError = false
-- LockHealth() alone does not stop combat damage; the call that actually blocks it is
-- RebelAISubsystem:AddPlayerInvulnerability(Source).
local WasHealthInvulnerable = false
local ReportedAddInvulnerabilityError = false
local ReportedRemoveInvulnerabilityError = false
local WasRebelAIFound = false
-- Infinite Health/Stamina is intentionally layered across several redundant mechanisms
-- (AddPlayerInvulnerability, the GAS GE_Invulnerability effect below, native CheatManager:God(),
-- and the raw GAS Health-attribute write in ForceDirectHealthAttribute further down). The real
-- crash-on-respawn bug (see repo memory) turned out to be a settle-window race condition, not any
-- one of these mechanisms - do not remove any of them without reason, they're kept as
-- belt-and-suspenders, not because any single one was proven necessary or sufficient.
local InvulnerabilityGEClass = nil
local WasGodModeApplied = false
local ReportedGodModeApplyError = false
local ReportedGodModeRemoveError = false
local WasNativeGodModeApplied = false
local ReportedNativeGodModeError = false
local ReportedDirectHealthWriteError = false
local DirectHealthDiagLogCount = 0
local LastRawHealth = "unknown"
local LastRawMaxHealth = "unknown"
local LastDirectHealthWriteOk = 0

local function ReadCommandFile()
    local file = io.open(COMMAND_PATH, "r")
    if not file then return nil end
    local data = {}
    for line in file:lines() do
        local key, value = line:match("^(%w+)=(.-)%s*$")
        if key then data[key] = value end
    end
    file:close()
    return data
end

local function WriteStatusFile(fields)
    local file = io.open(STATUS_PATH, "w")
    if not file then return end
    for key, value in pairs(fields) do
        file:write(string.format("%s=%s\n", key, tostring(value)))
    end
    file:close()
end

local function GetSettings()
    return FindFirstOf("DogwoodCharacterDevelopmentSettings")
end

local function GetSubsystem()
    return FindFirstOf("CharacterDevelopmentSubsystem")
end

local function GetRebelAISubsystem()
    return FindFirstOf("RebelAISubsystem")
end

-- Crash dump analysis (exception 0xC0000005, read at offset 0x230 from a near-null pointer,
-- SAME faulting instruction address both before and after this pcall wrapper was added) proved
-- pcall does NOT protect against this: it's a native access violation (a real hardware fault),
-- not a Lua error, so pcall can't catch it - the only real fix is to not touch the object at all
-- while it might be in this state (see the settle-window changes below). Kept for defense in depth.
local function SafeIsValid(object)
    if not object then return false end
    local ok, valid = pcall(function() return object:IsValid() end)
    return ok and valid == true
end

-- Two Lua proxies for the same UObject aren't guaranteed to compare equal with ==;
-- compare the underlying memory address instead.
local function SameObject(a, b)
    local okA, addrA = pcall(function() return a:GetAddress() end)
    local okB, addrB = pcall(function() return b:GetAddress() end)
    return okA and okB and addrA == addrB
end

-- CombatComponentBase is an ActorComponent; find the one attached to the local player pawn
-- rather than FindFirstOf, which could return an AI's combat component instead.
-- NOTE: an earlier version cached the resolved component across ticks to avoid rescanning, but
-- that made the bridge's poll loop silently hang after ~1 tick (holding a Lua handle to a
-- component across ticks seems to be the actual hazard, not the FindAllOf scan cost itself).
-- Re-scan fresh every tick; this is the version that ran reliably for minutes across multiple
-- respawns before that regression.
-- A full session on 2026-09-03 19:37 never printed "Combat component found for player" even
-- once in ~45s of active, non-settling gameplay (including a death) - meaning every protection
-- gated on this lookup (health lock, stamina lock, direct GAS write) silently never ran. Log the
-- first few lookups unconditionally (found or not) to see whether components are found at all,
-- and whether the player's own address ever appears among their owners.
local CombatLookupDiagLogCount = 0
local function FindOwnedComponent(className, player)
    local componentsOk, components = pcall(FindAllOf, className)
    if not componentsOk or not components then
        if className == "CombatComponentBase" and CombatLookupDiagLogCount < 5 then
            CombatLookupDiagLogCount = CombatLookupDiagLogCount + 1
            print("[DawnwalkerModBridge] FindAllOf(CombatComponentBase) failed: " .. tostring(components))
        end
        return nil
    end

    local playerAddrOk, playerAddr = pcall(function() return player:GetAddress() end)
    local matched = nil
    local validCount, ownerMatchAttempted = 0, 0
    for _, component in ipairs(components) do
        if SafeIsValid(component) then
            validCount = validCount + 1
            local ownerOk, owner = pcall(function() return component:GetOwner() end)
            if ownerOk and owner and SafeIsValid(owner) then
                ownerMatchAttempted = ownerMatchAttempted + 1
                if SameObject(owner, player) then
                    matched = component
                    break
                end
            end
        end
    end

    if className == "CombatComponentBase" and CombatLookupDiagLogCount < 5 then
        CombatLookupDiagLogCount = CombatLookupDiagLogCount + 1
        print(string.format(
            "[DawnwalkerModBridge] CombatComponentBase scan: total=%d valid=%d ownerChecked=%d matched=%s playerAddr=%s",
            #components, validCount, ownerMatchAttempted, tostring(matched ~= nil), playerAddrOk and tostring(playerAddr) or "unknown"))
    end

    return matched
end

local function GetPlayerCombatComponent(player)
    if not player or not SafeIsValid(player) then return nil end
    return FindOwnedComponent("CombatComponentBase", player)
end

-- Same pattern as combat component: CharacterMovementComponent is an ActorComponent, find the player's.
local function GetPlayerMovementComponent(player)
    if not player or not SafeIsValid(player) then return nil end
    return FindOwnedComponent("CharacterMovementComponent", player)
end

-- Same pattern again: the player's InventoryComponent (add/equip items lives here).
local function GetPlayerInventoryComponent(player)
    if not player or not SafeIsValid(player) then return nil end
    return FindOwnedComponent("InventoryComponent", player)
end

-- Best-in-game picks (found via a one-time item-catalog scan, see repo memory for the full
-- rarity/damage/toughness table): rarity=6 "Masterpiece/Unique" tier, highest damage/toughness
-- within that tier. One weapon per type/style so the player has a real choice, but only the
-- single highest-damage one auto-equips; all four armor slots equip
-- since they don't conflict. Jewelry (rings/amulets) carries no comparable damage/toughness stat
-- (likely special-effect items instead), so all rarity=6 ones are granted for the player to pick.
local BEST_GEAR_WEAPONS = {
    { path = "/Game/_Dawnwalker/Inventory/Items/ITM_Weapon_SwordBlacksmithMasterpice2a.ITM_Weapon_SwordBlacksmithMasterpice2a", equip = false },
    { path = "/Game/_Dawnwalker/Inventory/Items/ITM_Weapon_SwordErkas1a.ITM_Weapon_SwordErkas1a", equip = false },
    { path = "/Game/_Dawnwalker/Inventory/Items/ITM_Weapon_SwordDawnwalker5a.ITM_Weapon_SwordDawnwalker5a", equip = true },
    { path = "/Game/_Dawnwalker/Inventory/Items/ITM_Weapon_MaceMaster1a.ITM_Weapon_MaceMaster1a", equip = false },
}
local BEST_GEAR_ARMOR = {
    { path = "/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_ChestUniqueAncient1a.ITM_Clothing_ChestUniqueAncient1a", equip = true },
    { path = "/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_LegsUniqueAncient1a.ITM_Clothing_LegsUniqueAncient1a", equip = true },
    { path = "/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_HandsUniqueDawnwalker2a.ITM_Clothing_HandsUniqueDawnwalker2a", equip = true },
    { path = "/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_FeetUniqueDawnwalker2a.ITM_Clothing_FeetUniqueDawnwalker2a", equip = true },
}
local BEST_GEAR_JEWELRY = {
    "/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_NewUniqueRing1.ITM_Clothing_NewUniqueRing1",
    "/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_NewUniqueRing2.ITM_Clothing_NewUniqueRing2",
    "/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_NewUniqueRing3.ITM_Clothing_NewUniqueRing3",
    "/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_NewUniqueRing4.ITM_Clothing_NewUniqueRing4",
    "/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_NewUniqueRing5.ITM_Clothing_NewUniqueRing5",
    "/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_VampiricRing.ITM_Clothing_VampiricRing",
    "/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_BakirRing.ITM_Clothing_BakirRing",
    "/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_DawnwalkersRing.ITM_Clothing_DawnwalkersRing",
    "/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_AstrologistsRing.ITM_Clothing_AstrologistsRing",
    "/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_NewUniqueAmulet1.ITM_Clothing_NewUniqueAmulet1",
    "/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_NewUniqueAmulet2.ITM_Clothing_NewUniqueAmulet2",
    "/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_NewUniqueAmulet3.ITM_Clothing_NewUniqueAmulet3",
    "/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_NewUniqueAmulet4.ITM_Clothing_NewUniqueAmulet4",
    "/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_NewUniqueAmulet5.ITM_Clothing_NewUniqueAmulet5",
    "/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_MatriarchsAmulet.ITM_Clothing_MatriarchsAmulet",
    "/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_VampiricAmulet.ITM_Clothing_VampiricAmulet",
    "/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_DawnwalkersAmulet.ITM_Clothing_DawnwalkersAmulet",
    "/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_VichosCross.ITM_Clothing_VichosCross",
}

-- GetItemHandle is a BlueprintFunctionLibrary function - called on the class's CDO
-- (the "Default__ClassName" convention), same as any other UFunction call in UE4SS Lua.
local function GetInventoryFunctionLibrary()
    local ok, lib = pcall(function()
        return StaticFindObject("/Script/DogwoodInventory.Default__InventoryBlueprintFunctionLibrary")
    end)
    if ok and lib and SafeIsValid(lib) then return lib end
    return nil
end

local function GiveBestGear(player, itemLevel)
    if not player or not SafeIsValid(player) then return "no player" end
    local inv = GetPlayerInventoryComponent(player)
    if not inv or not SafeIsValid(inv) then return "no inventory component" end
    local lib = GetInventoryFunctionLibrary()
    if not lib then return "no function library" end

    local granted, failed = 0, 0
    local function grantOne(path, equip)
        local assetOk, asset = pcall(function() return StaticFindObject(path) end)
        if not assetOk or not asset or not SafeIsValid(asset) then
            failed = failed + 1
            return
        end
        local handleOk, handle = pcall(function() return lib:GetItemHandle(player, asset, itemLevel) end)
        if not handleOk or not handle then
            failed = failed + 1
            return
        end
        local addOk = pcall(function()
            if equip then
                inv:TryAddAndEquipItem(handle, false)
            else
                inv:TryAddItem(handle, 1, false)
            end
        end)
        if addOk then granted = granted + 1 else failed = failed + 1 end
    end

    for _, w in ipairs(BEST_GEAR_WEAPONS) do grantOne(w.path, w.equip) end
    for _, a in ipairs(BEST_GEAR_ARMOR) do grantOne(a.path, a.equip) end
    for _, j in ipairs(BEST_GEAR_JEWELRY) do grantOne(j, false) end

    return string.format("granted=%d failed=%d", granted, failed)
end

-- DIAGNOSTIC (2026-09-04): GiveBestGear reports granted=N failed=0 but the item that actually
-- lands in the inventory is always wrong ("Bee Smoker" quest item) - the ItemHandle struct
-- returned by GetItemHandle is suspected to be garbage/zeroed. Its own fields aren't listed
-- anywhere in the static UE4SS_ObjectDump.txt under the expected "DogwoodInventory.ItemHandle:"
-- path, so dump them live via reflection (UScriptStruct supports ForEachProperty same as
-- UClass) plus the actual field values of one freshly-created test handle, read-only (no
-- TryAddItem/TryAddAndEquipItem call here - this cannot grant/pollute anything).
local DumpedItemHandleFields = false
local function DumpItemHandleDiagnosticsOnce(player)
    if DumpedItemHandleFields then return end
    if not player or not SafeIsValid(player) then return end
    local lib = GetInventoryFunctionLibrary()
    if not lib then return end
    DumpedItemHandleFields = true

    local structOk, struct = pcall(function() return StaticFindObject("/Script/DogwoodInventory.ItemHandle") end)
    if structOk and struct and SafeIsValid(struct) then
        local propOk, propErr = pcall(function()
            struct:ForEachProperty(function(prop)
                local nameOk, name = pcall(function() return prop:GetFName():ToString() end)
                local typeOk, ptype = pcall(function() return prop:GetClass():GetFName():ToString() end)
                print(string.format("[DawnwalkerModBridge] ItemHandle field: %s (%s)",
                    nameOk and name or "?", tostring(typeOk and ptype or "?")))
            end)
        end)
        if not propOk then
            print("[DawnwalkerModBridge] ItemHandle field dump failed: " .. tostring(propErr))
        end
    else
        print("[DawnwalkerModBridge] ItemHandle struct lookup failed")
    end

    -- Build one real handle for a known-good test item and log its resulting field values.
    local testPath = "/Game/_Dawnwalker/Inventory/Items/ITM_Weapon_SwordDawnwalker5a.ITM_Weapon_SwordDawnwalker5a"
    local assetOk, asset = pcall(function() return StaticFindObject(testPath) end)
    if assetOk and asset and SafeIsValid(asset) then
        local handleOk, handle = pcall(function() return lib:GetItemHandle(player, asset, 1) end)
        if handleOk and handle then
            print("[DawnwalkerModBridge] Test handle created for " .. testPath .. ", dumping field values:")
            if structOk and struct and SafeIsValid(struct) then
                pcall(function()
                    struct:ForEachProperty(function(prop)
                        local nameOk, name = pcall(function() return prop:GetFName():ToString() end)
                        if nameOk then
                            local valOk, val = pcall(function() return handle[name] end)
                            print(string.format("[DawnwalkerModBridge] Test handle field %s = %s",
                                name, tostring(valOk and val or "?")))
                        end
                    end)
                end)
            end
        else
            print("[DawnwalkerModBridge] Test handle creation failed: " .. tostring(handle))
        end
    else
        print("[DawnwalkerModBridge] Test item asset lookup failed for " .. testPath)
    end
end

local function GetCameraManager()
    return FindFirstOf("PlayerCameraManager")
end

local function GetCheatManager()
    return FindFirstOf("CheatManager")
end

-- Multiplier-based features need the game's original value, captured once, so repeated
-- applies each poll tick don't compound (e.g. 1.5x on top of an already-doubled value).
local BaseValues = {}
local function GetBaseValue(cacheKey, object, propertyName)
    if BaseValues[cacheKey] == nil then
        local ok, value = pcall(function() return object[propertyName] end)
        if not ok or value == nil or value <= 0 then return nil end
        BaseValues[cacheKey] = value
    end
    return BaseValues[cacheKey]
end

-- A crash was observed writing to the pawn's components within ~200ms of a respawn
-- (ClientRestartPlayerController), likely because the new pawn's CombatComponentBase /
-- CharacterMovementComponent aren't fully initialized yet. When the player pawn's address
-- changes, hold off writing to per-pawn components for a few ticks and drop cached base
-- values (they belonged to the old, now-destroyed pawn).
-- Combat gets only a 1-tick gate: skipping infinite health/stamina for a full 1.5s window
-- (the original value) left the player unprotected long enough to die again right after
-- respawning, causing a death loop. Movement (speed/jump, not survival-critical) keeps a
-- longer gate since it was equally implicated in the original crash.
local LastPlayerAddress = nil
local CombatSettleTicksRemaining = 0
local MovementSettleTicksRemaining = 0
-- Separate from CombatSettleTicksRemaining (pawn-address-change based): a 2026-09-03 crash
-- landed right as the combat component itself flipped from not-found to found after an 11
-- minute gap with NO pawn address change at all (likely a loading screen/cutscene), so the
-- address-based settle window had already expired and gave zero protection. This counter
-- gates on that transition directly, whatever caused it.
local CombatComponentSettleTicksRemaining = 0
-- The damage-multiplier write touches 13 separate GAS attributes in one go (heavier than the
-- simple Lock/SetPercent calls CombatComponentSettleTicksRemaining already protects) - crashes
-- kept recurring at the exact same point (right after this write's first-ever invocation) even
-- after lowering the multiplier and hard-capping the written values, so give this specific write
-- its own longer, independent settle window rather than assuming the general combat-component
-- settle window (3 ticks) is long enough for it too.
local DamageMultiplierSettleTicksRemaining = 0
local function RefreshPawnSettleState()
    local playerOk, player = pcall(UEHelpers.GetPlayer)
    if not playerOk or not player or not SafeIsValid(player) then return nil end
    local addrOk, address = pcall(function() return player:GetAddress() end)
    if not addrOk then return player end
    if address ~= LastPlayerAddress then
        LastPlayerAddress = address
        -- Not just a write/read gate: FindOwnedComponent itself (below) is skipped entirely
        -- while settling, since even scanning/validating a freshly-spawned component crashed
        -- (a native access violation pcall can't catch) - give it several full ticks, not one.
        CombatSettleTicksRemaining = 3
        MovementSettleTicksRemaining = 6
        BaseValues = {}
        -- The old Source pawn for AddPlayerInvulnerability is now destroyed; force a fresh
        -- Add call against the new pawn rather than assuming the grant carried over.
        WasHealthInvulnerable = false
        -- The ASC lives on the pawn's CharacterBase too - a fresh pawn means a fresh ASC, so
        -- any previously-applied GE_Invulnerability spec handle is gone with it.
        WasGodModeApplied = false
        -- CheatManagerEnablerMod logs "Constructed CheatManager" on every respawn, meaning the
        -- native God() toggle from the old CheatManager instance doesn't carry over either.
        WasNativeGodModeApplied = false
        -- New pawn means a fresh attribute set at its real default - force a re-apply rather than
        -- assuming the old pawn's value (or lack of one) still matches.
        LastAppliedDamageMultiplier = nil
    else
        if CombatSettleTicksRemaining > 0 then
            CombatSettleTicksRemaining = CombatSettleTicksRemaining - 1
        end
        if MovementSettleTicksRemaining > 0 then
            MovementSettleTicksRemaining = MovementSettleTicksRemaining - 1
        end
    end
    return player
end

-- Same raw-GAS-struct-write technique already proven safe for Health (ForceDirectHealthAttribute)
-- and behind the game's own AttackXCostReductionPercentage naming, these are the actual per-attack
-- damage output scalars - covers the player's melee, claw, unarmed, and magic attacks so any
-- weapon/ability the player uses benefits. Cached per-attribute base value (via the shared
-- BaseValues table, cleared on every respawn) so repeated ticks don't compound the multiplier.
local DAMAGE_MULTIPLIER_ATTRS = { "MeleeDamageMultiplier", "ClawsDamageMultiplier", "UnarmedDamageMultiplier", "MagicDamageMultiplier" }
local DamageMultiplierDiagLogCount = 0
local LastAppliedDamageMultiplier = nil

-- Diagnostics (2026-09-03) showed these hold their real per-hit magnitude (hundreds) in
-- CurrentValue while BaseValue stays 0 - some other system (the equipped weapon, most likely)
-- drives CurrentValue via a GameplayEffect modifier, unlike the near-inert 0/0 XDamageMultiplier
-- attrs above. Skipped: BaseUnarmedDamage/BaseMagicDamage/Damage/DealtDamage/HybridDamage, which
-- read 0.0 even in CurrentValue (nothing to multiply).
local BASE_DAMAGE_VALUE_ATTRS = {
    "WeaponDamageMin", "WeaponDamageMax", "BaseMeleeDamage",
    "BaseUnarmedDamageMin", "BaseUnarmedDamageMax",
    "BaseClawsDamageMin", "BaseClawsDamageMax",
    "BaseAbilityDamage", "BaseVampireAbilityDamage"
}

local function ApplyDamageMultiplier(player, multiplier)
    local ascOk, asc = pcall(function() return player.AbilitySystemComponent end)
    if not ascOk or not asc or not SafeIsValid(asc) then return end
    if not CharacterAttributeSetClass or not SafeIsValid(CharacterAttributeSetClass) then
        local classOk, class = pcall(function()
            return StaticFindObject("/Script/DogwoodStats.CharacterBaseAttributeSet")
        end)
        if classOk and class then CharacterAttributeSetClass = class end
    end
    if not CharacterAttributeSetClass then return end
    local attrSetOk, attrSet = pcall(function() return asc:GetAttributeSet(CharacterAttributeSetClass) end)
    if not attrSetOk or not attrSet or not SafeIsValid(attrSet) then return end

    local diagLog = DamageMultiplierDiagLogCount < 10
    if diagLog then DamageMultiplierDiagLogCount = DamageMultiplierDiagLogCount + 1 end

    for _, attrName in ipairs(DAMAGE_MULTIPLIER_ATTRS) do
        local cacheKey = "dmgMult_" .. attrName
        if BaseValues[cacheKey] == nil then
            -- Don't gate on base > 0: if the game's real default for these is 0 (an additive
            -- "no bonus" convention rather than a 1.0 "neutral multiplier" convention), that
            -- gate would silently never cache anything and this whole feature would be a no-op.
            local readOk, base = pcall(function() return attrSet[attrName].BaseValue end)
            if readOk and base ~= nil then BaseValues[cacheKey] = base end
        end
        local base = BaseValues[cacheKey]
        local writeOk
        if base then
            -- Diagnostics (2026-09-03) showed these read 0.0 by default, not 1.0 - the game
            -- treats them as an additive "extra damage" bonus on top of the weapon's own damage,
            -- not a scalar multiplier. Convert our 1x-is-neutral slider value into that convention:
            -- multiplier=1 -> +0 (no change), multiplier=10 -> +9 (base damage plus 900%).
            -- Hard-capped at 200 regardless of multiplier (defense-in-depth, see repo memory) -
            -- extreme absolute values here are the leading crash suspect, not the multiplier
            -- itself.
            local bonus = math.min(base + (multiplier - 1), 200)
            writeOk = pcall(function()
                attrSet[attrName].CurrentValue = bonus
                attrSet[attrName].BaseValue = bonus
            end)
        end
        if diagLog then
            print(string.format(
                "[DawnwalkerModBridge] DamageMultiplier diag: %s base=%s multiplier=%s writeOk=%s",
                attrName, tostring(base), tostring(multiplier), tostring(writeOk)))
        end
    end

    for _, attrName in ipairs(BASE_DAMAGE_VALUE_ATTRS) do
        local cacheKey = "dmgBaseVal_" .. attrName
        if BaseValues[cacheKey] == nil then
            -- Cache CurrentValue (not BaseValue, which is 0 here) as the multiplication anchor.
            local readOk, current = pcall(function() return attrSet[attrName].CurrentValue end)
            if readOk and current ~= nil and current > 0 then BaseValues[cacheKey] = current end
        end
        local base = BaseValues[cacheKey]
        local writeOk
        if base then
            -- Real per-hit damage magnitude, so a genuine scalar multiply is the right convention
            -- here (unlike the additive bonus used for the 0-based XDamageMultiplier attrs above).
            -- Hard-capped at 20000 regardless of multiplier (defense-in-depth, see repo memory) -
            -- extreme absolute values here are the leading crash suspect, not the multiplier itself.
            writeOk = pcall(function() attrSet[attrName].CurrentValue = math.min(base * multiplier, 20000) end)
        end
        if diagLog then
            print(string.format(
                "[DawnwalkerModBridge] DamageValue diag: %s base=%s multiplier=%s writeOk=%s",
                attrName, tostring(base), tostring(multiplier), tostring(writeOk)))
        end
    end
end

-- Read-only, independent of ApplyDamageMultiplier's write cadence - lets us see whether the raw
-- write actually holds over time or gets silently reverted (e.g. by the ASC's own aggregator
-- recalculating CurrentValue from BaseValue + active GameplayEffect modifiers on some other
-- trigger), since the game showing no extra damage despite writeOk=true could mean either the
-- write isn't read by the damage formula at all, or it's read but doesn't stay set.
local function ReadDamageMultiplierLiveValue(player)
    local ascOk, asc = pcall(function() return player.AbilitySystemComponent end)
    if not ascOk or not asc or not SafeIsValid(asc) then return nil end
    if not CharacterAttributeSetClass or not SafeIsValid(CharacterAttributeSetClass) then return nil end
    local attrSetOk, attrSet = pcall(function() return asc:GetAttributeSet(CharacterAttributeSetClass) end)
    if not attrSetOk or not attrSet or not SafeIsValid(attrSet) then return nil end
    local currentOk, currentVal = pcall(function() return attrSet.MeleeDamageMultiplier.CurrentValue end)
    local baseOk, baseVal = pcall(function() return attrSet.MeleeDamageMultiplier.BaseValue end)
    return currentOk and currentVal or nil, baseOk and baseVal or nil
end

-- Same steady-hold check as ReadDamageMultiplierLiveValue, but for one of the real damage-
-- magnitude attrs (unlike MeleeDamageMultiplier, this one is actively GE-driven at rest, so it's
-- not yet confirmed our direct write survives whatever recomputes it).
local function ReadWeaponDamageLiveValue(player)
    local ascOk, asc = pcall(function() return player.AbilitySystemComponent end)
    if not ascOk or not asc or not SafeIsValid(asc) then return nil end
    if not CharacterAttributeSetClass or not SafeIsValid(CharacterAttributeSetClass) then return nil end
    local attrSetOk, attrSet = pcall(function() return asc:GetAttributeSet(CharacterAttributeSetClass) end)
    if not attrSetOk or not attrSet or not SafeIsValid(attrSet) then return nil end
    local currentOk, currentVal = pcall(function() return attrSet.WeaponDamageMax.CurrentValue end)
    return currentOk and currentVal or nil
end

local function ApplyCommand()
    local player = RefreshPawnSettleState()
    local combatSettling = CombatSettleTicksRemaining > 0
    local movementSettling = MovementSettleTicksRemaining > 0

    -- ItemHandle diagnostic isn't tied to a specific pawn, but still wait for the settle window
    -- since it does create a real handle via the inventory function library.
    if not combatSettling and not movementSettling then
        pcall(function() DumpItemHandleDiagnosticsOnce(player) end)
    end

    local command = ReadCommandFile()
    local status = { bridgeLoaded = 1, ok = 0 }

    if not command then
        status.commandFileFound = 0
        WriteStatusFile(status)
        return
    end
    status.commandFileFound = 1

    local settings = GetSettings()
    if settings and SafeIsValid(settings) then
        status.settingsFound = 1
        if command.levelCap then
            local cap = tonumber(command.levelCap)
            -- Same table-bounds risk as setLevel; keep the cap within what the level tables actually cover.
            if cap and cap >= 1 and cap <= 99 then
                local applied = pcall(function() settings.LevelCap = math.floor(cap) end)
                status.levelCapApplied = applied and 1 or 0
            else
                status.levelCapApplied = 0
                status.levelCapRejected = "out_of_range"
            end
        end
        local capOk, capValue = pcall(function() return settings.LevelCap end)
        status.levelCap = capOk and capValue or "unknown"
    else
        status.settingsFound = 0
    end

    local subsystem = GetSubsystem()
    if subsystem and SafeIsValid(subsystem) then
        status.subsystemFound = 1

        local requestId = command.requestId
        if requestId and requestId ~= LastRequestId then
            LastRequestId = requestId
            if command.setLevel then
                local level = tonumber(command.setLevel)
                -- Levels above 99 read past the end of the game's level/XP tables and crash it.
                if level and level >= 1 and level <= 99 then
                    local applied = pcall(function() subsystem:ForceLevelUpTo(math.floor(level), true) end)
                    status.setLevelApplied = applied and 1 or 0
                else
                    status.setLevelApplied = 0
                    status.setLevelRejected = "out_of_range"
                end
            end
            if command.giveBestGear == "1" then
                -- DISABLED (2026-09-04): GetItemHandle is confirmed to produce a broken handle -
                -- every grant call reports success but the wrong item (a "Bee Smoker" quest item)
                -- actually lands in the inventory, flooding it. Do NOT re-enable
                -- (set PendingGiveBestGear = true here) until DumpItemHandleDiagnosticsOnce's
                -- output below has been reviewed and the real cause fixed.
                LastGiveBestGearResult = "disabled: wrong-item bug not yet fixed - see repo memory"
            end
        end

        if PendingGiveBestGear then
            if combatSettling or movementSettling then
                LastGiveBestGearResult = "pending: waiting for pawn to settle"
            else
                local levelOk, curLevel = pcall(function() return subsystem:GetCurrentLevel() end)
                local itemLevel = (levelOk and tonumber(curLevel)) or 1
                local resultOk, result = pcall(function() return GiveBestGear(player, math.floor(itemLevel)) end)
                LastGiveBestGearResult = resultOk and result or ("error: " .. tostring(result))
                PendingGiveBestGear = false
                print("[DawnwalkerModBridge] GiveBestGear: " .. tostring(LastGiveBestGearResult))
            end
        end
        status.giveBestGearResult = LastGiveBestGearResult

        local levelOk, level = pcall(function() return subsystem:GetCurrentLevel() end)
        local xpOk, xp = pcall(function() return subsystem:GetCurrentXP() end)
        status.currentLevel = levelOk and level or "unknown"
        status.currentXP = xpOk and xp or "unknown"
    else
        status.subsystemFound = 0
    end

    -- REVISED (2026-09-03): a crash dump landed at the exact second a fresh pawn spawned in
    -- and AddPlayerInvulnerability fired against it with zero delay - this call was previously
    -- assumed safe on the theory that touching just the pawn+RebelAI subsystem (not the
    -- per-pawn CombatComponentBase) avoided the respawn crash class, but that assumption looks
    -- wrong. Gate it behind the same combat settle window as everything else that touches a
    -- freshly-spawned pawn.
    local rebelAI = GetRebelAISubsystem()
    if not combatSettling and player and SafeIsValid(player) and rebelAI and SafeIsValid(rebelAI) then
        status.rebelAIFound = 1
        if not WasRebelAIFound then
            print("[DawnwalkerModBridge] RebelAI subsystem found")
            WasRebelAIFound = true
        end
        if command.infiniteHealth == "1" then
            if not WasHealthInvulnerable then
                local addOk, addErr = pcall(function() rebelAI:AddPlayerInvulnerability(player) end)
                if addOk then
                    WasHealthInvulnerable = true
                    print("[DawnwalkerModBridge] AddPlayerInvulnerability applied")
                elseif not ReportedAddInvulnerabilityError then
                    print("[DawnwalkerModBridge] AddPlayerInvulnerability failed: " .. tostring(addErr))
                    ReportedAddInvulnerabilityError = true
                end
            end
        else
            if WasHealthInvulnerable then
                local removeOk, removeErr = pcall(function() rebelAI:RemovePlayerInvulnerability(player) end)
                if removeOk then
                    WasHealthInvulnerable = false
                elseif not ReportedRemoveInvulnerabilityError then
                    print("[DawnwalkerModBridge] RemovePlayerInvulnerability failed: " .. tostring(removeErr))
                    ReportedRemoveInvulnerabilityError = true
                end
            end
        end
        status.healthInvulnerable = WasHealthInvulnerable and 1 or 0
    else
        status.rebelAIFound = 0
        WasRebelAIFound = false
        WasHealthInvulnerable = false
    end

    -- REAL FIX ATTEMPT #4: apply/remove the game's own GAS invulnerability effect via the
    -- player's AbilitySystemComponent. Gated behind the combat settle window since the ASC
    -- lives on the same freshly-spawned pawn as CombatComponentBase (same crash risk class).
    if not combatSettling and player and SafeIsValid(player) then
        local ascOk, asc = pcall(function() return player.AbilitySystemComponent end)
        if ascOk and asc and SafeIsValid(asc) then
            if not InvulnerabilityGEClass or not SafeIsValid(InvulnerabilityGEClass) then
                local classOk, class = pcall(function()
                    return StaticFindObject("/Game/_Dawnwalker/Combat/Effects/Persistent/GE_Invulnerability.GE_Invulnerability_C")
                end)
                if classOk and class then InvulnerabilityGEClass = class end
            end
            if InvulnerabilityGEClass then
                status.godModeClassFound = 1
                if command.infiniteHealth == "1" then
                    if not WasGodModeApplied then
                        local applyOk, applyErr = pcall(function()
                            local context = asc:MakeEffectContext()
                            local spec = asc:MakeOutgoingSpec(InvulnerabilityGEClass, 1.0, context)
                            asc:BP_ApplyGameplayEffectSpecToSelf(spec)
                        end)
                        if applyOk then
                            WasGodModeApplied = true
                            print("[DawnwalkerModBridge] GE_Invulnerability applied via ASC")
                        elseif not ReportedGodModeApplyError then
                            print("[DawnwalkerModBridge] GE_Invulnerability apply failed: " .. tostring(applyErr))
                            ReportedGodModeApplyError = true
                        end
                    end
                else
                    if WasGodModeApplied then
                        local removeOk, removeErr = pcall(function()
                            asc:RemoveActiveGameplayEffectBySourceEffect(InvulnerabilityGEClass, nil, -1)
                        end)
                        if removeOk then
                            WasGodModeApplied = false
                        elseif not ReportedGodModeRemoveError then
                            print("[DawnwalkerModBridge] GE_Invulnerability remove failed: " .. tostring(removeErr))
                            ReportedGodModeRemoveError = true
                        end
                    end
                end
            else
                status.godModeClassFound = 0
            end
        end
        status.godModeApplied = WasGodModeApplied and 1 or 0
    end

    status.combatSettling = combatSettling and 1 or 0
    if combatSettling then
        -- Don't even call GetPlayerCombatComponent here: FindOwnedComponent scans and calls
        -- :IsValid()/:GetOwner() on every CombatComponentBase in the world, and that scan itself
        -- is what crashed (a native access violation, not a catchable Lua error) right on the
        -- tick a freshly-spawned pawn's component was found. Skip touching combat entirely
        -- until the settle window passes.
        status.combatFound = WasCombatFound and 1 or 0
    else
        local combat = GetPlayerCombatComponent(player)
        if combat and SafeIsValid(combat) then
            if not WasCombatFound then
                print("[DawnwalkerModBridge] Combat component found for player")
                WasCombatFound = true
                CombatComponentSettleTicksRemaining = 3
                DamageMultiplierSettleTicksRemaining = 10
            end
            status.combatFound = 1
            local componentSettling = CombatComponentSettleTicksRemaining > 0
            status.combatComponentSettling = componentSettling and 1 or 0
            if componentSettling then
                -- Don't touch this component at all yet: it just transitioned from not-found to
                -- found (independent of any pawn-address change, e.g. after a loading screen or
                -- cutscene), the exact same hazard class as a freshly-spawned pawn.
                CombatComponentSettleTicksRemaining = CombatComponentSettleTicksRemaining - 1
            else
                if DamageMultiplierSettleTicksRemaining > 0 then
                    DamageMultiplierSettleTicksRemaining = DamageMultiplierSettleTicksRemaining - 1
                end
            -- SetHealthPercent(1.0) alone only corrects health once per poll (1s); combat damage
            -- lands in real time and can still kill the player in the gap between polls. LockHealth
            -- freezes the stat against damage entirely, which is what actually stops death - the
            -- percent set just makes sure it's full at the moment we lock it.
            local lockHealthOk, lockHealthErr, unlockHealthOk, unlockHealthErr
            if command.infiniteHealth == "1" then
                pcall(function() combat:SetHealthPercent(1.0) end)
                lockHealthOk, lockHealthErr = pcall(function() combat:LockHealth() end)
            else
                unlockHealthOk, unlockHealthErr = pcall(function() combat:UnlockHealth() end)
            end
            local lockStaminaOk, lockStaminaErr, unlockStaminaOk, unlockStaminaErr
            if command.infiniteStamina == "1" then
                pcall(function() combat:SetStaminaPercent(1.0) end)
                lockStaminaOk, lockStaminaErr = pcall(function() combat:LockStamina() end)
            else
                unlockStaminaOk, unlockStaminaErr = pcall(function() combat:UnlockStamina() end)
            end
            -- pcall swallows native/Lua errors silently by design - log the first failure of each
            -- kind once so a broken Lock/Unlock call doesn't look identical to a working one.
            if lockHealthOk == false and not ReportedLockHealthError then
                print("[DawnwalkerModBridge] LockHealth failed: " .. tostring(lockHealthErr))
                ReportedLockHealthError = true
            end
            if unlockHealthOk == false and not ReportedUnlockHealthError then
                print("[DawnwalkerModBridge] UnlockHealth failed: " .. tostring(unlockHealthErr))
                ReportedUnlockHealthError = true
            end
            if lockStaminaOk == false and not ReportedLockStaminaError then
                print("[DawnwalkerModBridge] LockStamina failed: " .. tostring(lockStaminaErr))
                ReportedLockStaminaError = true
            end
            if unlockStaminaOk == false and not ReportedUnlockStaminaError then
                print("[DawnwalkerModBridge] UnlockStamina failed: " .. tostring(unlockStaminaErr))
                ReportedUnlockStaminaError = true
            end
            if command.damageMultiplier then
                local dmgMult = tonumber(command.damageMultiplier)
                -- Lowered from 50 to 10 (2026-09-04): every crash correlated with this feature in
                -- the native-mod testing session had damageMultiplier=50 active, and the resulting
                -- raw-written attribute values at 50x were extreme (e.g. 724 base * 50 = 36200,
                -- vs a real per-hit magnitude in the hundreds) - a plausible trigger for whatever
                -- downstream system (damage-number UI, overkill/gib logic, etc.) reads these
                -- values next. 10x still gives a very noticeable damage boost with far less
                -- extreme absolute numbers.
                if dmgMult and dmgMult >= 0.1 and dmgMult <= 10 then
                    -- Unlike health/stamina, nothing fights this value back tick-to-tick - only
                    -- touch the raw struct when the pawn is new or the requested value actually
                    -- changed, instead of every 1s poll, to cut exposure to this write's crash risk.
                    if dmgMult ~= LastAppliedDamageMultiplier and DamageMultiplierSettleTicksRemaining <= 0 then
                        -- Same raw-struct-write hazard as ForceDirectHealthAttribute: bypasses all
                        -- engine-side validity checks, so skip it once the game considers the
                        -- character dead (fail-open on error, same as the health path).
                        local aliveOk, isAlive = pcall(function() return combat:IsAlive() end)
                        if not (aliveOk and isAlive == false) then
                            ApplyDamageMultiplier(player, dmgMult)
                            LastAppliedDamageMultiplier = dmgMult
                        end
                    end
                    status.damageMultiplierApplied = 1
                else
                    status.damageMultiplierApplied = 0
                    status.damageMultiplierRejected = "out_of_range"
                end
            end
            -- Read-only check every tick, independent of the write-on-change gate above, so we
            -- can see in status.txt/UE4SS.log whether the value drifts back down on its own.
            local liveCurrent, liveBase = ReadDamageMultiplierLiveValue(player)
            status.damageMultiplierLiveCurrent = liveCurrent
            status.damageMultiplierLiveBase = liveBase
            status.weaponDamageMaxLiveCurrent = ReadWeaponDamageLiveValue(player)
            status.healthLocked = (lockHealthOk == true) and 1 or 0
            status.staminaLocked = (lockStaminaOk == true) and 1 or 0
            local hpOk, hp = pcall(function() return combat:GetHealthPercentage() end)
            local stOk, st = pcall(function() return combat:GetStaminaPercentage() end)
            status.healthPercent = hpOk and hp or "unknown"
            status.staminaPercent = stOk and st or "unknown"
            -- REAL FIX ATTEMPT #6 diagnostics: raw GAS attribute values written by the fast
            -- loop's ForceDirectHealthAttribute, separate from the (possibly-derived) values above.
            status.rawHealth = LastRawHealth
            status.rawMaxHealth = LastRawMaxHealth
            status.directHealthWriteOk = LastDirectHealthWriteOk
            end
        else
            WasCombatFound = false
            CombatComponentSettleTicksRemaining = 0
            status.combatFound = 0
        end
    end

    status.movementSettling = movementSettling and 1 or 0
    if movementSettling then
        -- Same reasoning as combat above: skip the discovery scan itself during settling.
        status.movementFound = 0
    else
        local movement = GetPlayerMovementComponent(player)
        if movement and SafeIsValid(movement) then
            status.movementFound = 1
            local baseWalkSpeed = GetBaseValue("walkSpeed", movement, "MaxWalkSpeed")
            if baseWalkSpeed and command.speedMultiplier then
                local mult = tonumber(command.speedMultiplier)
                -- Keep multipliers within a sane range; extreme speed can shove the player through geometry.
                if mult and mult >= 0.1 and mult <= 5 then
                    local applied = pcall(function() movement.MaxWalkSpeed = baseWalkSpeed * mult end)
                    status.speedMultiplierApplied = applied and 1 or 0
                else
                    status.speedMultiplierApplied = 0
                    status.speedMultiplierRejected = "out_of_range"
                end
            end

            local baseJumpZ = GetBaseValue("jumpZ", movement, "JumpZVelocity")
            if baseJumpZ and command.jumpMultiplier then
                local mult = tonumber(command.jumpMultiplier)
                if mult and mult >= 0.1 and mult <= 5 then
                    local applied = pcall(function() movement.JumpZVelocity = baseJumpZ * mult end)
                    status.jumpMultiplierApplied = applied and 1 or 0
                else
                    status.jumpMultiplierApplied = 0
                    status.jumpMultiplierRejected = "out_of_range"
                end
            end
        else
            status.movementFound = 0
        end
    end

    local camera = GetCameraManager()
    if camera and SafeIsValid(camera) then
        status.cameraFound = 1
        local baseFov = GetBaseValue("fov", camera, "DefaultFOV")
        if baseFov and command.fovMultiplier then
            local mult = tonumber(command.fovMultiplier)
            -- Clamp the resulting FOV itself (not just the multiplier): UE cameras get unstable well
            -- outside the ~10-170 degree range regardless of what multiplier produced it.
            if mult and mult >= 0.1 and mult <= 5 then
                local newFov = baseFov * mult
                if newFov >= 10 and newFov <= 170 then
                    local applied = pcall(function() camera.DefaultFOV = newFov end)
                    status.fovMultiplierApplied = applied and 1 or 0
                else
                    status.fovMultiplierApplied = 0
                    status.fovMultiplierRejected = "out_of_range"
                end
            else
                status.fovMultiplierApplied = 0
                status.fovMultiplierRejected = "out_of_range"
            end
        end
    else
        status.cameraFound = 0
    end

    local cheatManager = GetCheatManager()
    if cheatManager and SafeIsValid(cheatManager) then
        status.cheatManagerFound = 1
        if command.gameSpeed then
            local speed = tonumber(command.gameSpeed)
            -- Slomo clamps internally, but keep our own bound too so 0/negative values can't be sent.
            if speed and speed >= 0.1 and speed <= 4 then
                local applied = pcall(function() cheatManager:Slomo(speed) end)
                status.gameSpeedApplied = applied and 1 or 0
            else
                status.gameSpeedApplied = 0
                status.gameSpeedRejected = "out_of_range"
            end
        end

        -- REAL FIX ATTEMPT #5: native God() cheat toggle, see comment near WasNativeGodModeApplied.
        if not combatSettling then
            if command.infiniteHealth == "1" then
                if not WasNativeGodModeApplied then
                    local godOk, godErr = pcall(function() cheatManager:God() end)
                    if godOk then
                        WasNativeGodModeApplied = true
                        print("[DawnwalkerModBridge] Native God() cheat toggled on")
                    elseif not ReportedNativeGodModeError then
                        print("[DawnwalkerModBridge] Native God() cheat failed: " .. tostring(godErr))
                        ReportedNativeGodModeError = true
                    end
                end
            else
                if WasNativeGodModeApplied then
                    local godOk = pcall(function() cheatManager:God() end)
                    if godOk then
                        WasNativeGodModeApplied = false
                    end
                end
            end
        end
        status.nativeGodModeApplied = WasNativeGodModeApplied and 1 or 0

        -- The stat-based Damage Multiplier writes successfully and holds steady (confirmed via
        -- ReadDamageMultiplierLiveValue/ReadWeaponDamageLiveValue) but has never been shown to
        -- affect real combat damage in this game - the actual damage calculation appears to read
        -- from somewhere else entirely (see repo memory's extensive "DAMAGE MULTIPLIER" saga).
        -- DamageTarget is the engine's own stock CheatManager function (bound to the "damage"
        -- console command in any UE game) - it traces to whatever the player is currently aiming
        -- at and applies real damage through the actual damage pipeline, guaranteed to work since
        -- it's not a custom Dogwood attribute, it's stock Unreal Engine cheat functionality.
        local nukeRequestId = command.nukeRequestId
        if nukeRequestId and nukeRequestId ~= LastNukeRequestId then
            LastNukeRequestId = nukeRequestId
            local amount = tonumber(command.nukeDamage)
            if amount and amount > 0 and amount <= 999999 then
                local dmgOk, dmgErr = pcall(function() cheatManager:DamageTarget(amount) end)
                LastNukeTargetResult = dmgOk and "ok" or ("failed: " .. tostring(dmgErr))
            else
                LastNukeTargetResult = "failed: out_of_range"
            end
        end
        status.nukeTargetResult = LastNukeTargetResult
    else
        status.cheatManagerFound = 0
    end

    status.ok = 1
    status.lastAppliedRequestId = LastRequestId or 0
    WriteStatusFile(status)
end

RegisterConsoleCommandHandler("dwbridge_apply", function()
    pcall(ApplyCommand)
    return true
end)

-- CONFIRMED (2026-09-03) via a bare LoopAsync(1000, print-only) diagnostic mod running
-- side-by-side: the return-value convention is what the original code assumed all along -
-- "return false" keeps the loop going (it ticked 90+ times with no issue). The earlier "fires
-- once then dies" pattern was actually caused by this code returning "true" (stop) instead,
-- from an incorrect fix. Reverted to a single persistent registration with "return false".
local function StartTickLoop()
    pcall(function()
        LoopAsync(1000, function()
            local ok, err = pcall(ApplyCommand)
            if not ok then
                print("[DawnwalkerModBridge] ApplyCommand error: " .. tostring(err))
            end
            return false
        end)
    end)
end

-- REMOVED (2026-09-03): deferring the hook's own work to an async loop (setting a flag,
-- nothing else, in the hook body) did NOT stop the crash - it still landed within ~33ms of the
-- same respawn event with our hook doing nothing but a boolean write. That means the crash risk
-- is from having a 3rd native detour registered on ClientRestart at all (alongside
-- CheatManagerEnablerMod's and one other mod's own hooks on the same function), not from
-- anything our callback body does. Removed the RegisterHook call entirely; the existing 1000ms
-- StartTickLoop above still detects the pawn address change and reapplies everything, just up
-- to ~1s slower after a respawn instead of near-instant.

-- REMOVED (2026-09-03): this hook never fired for the player's own combat component in any
-- live test (only ever logged other actors' calls), so it was confirmed dead weight. With 17
-- crash dumps accumulated today (one landing at the exact timestamp of the last "death" event),
-- and this hook installed on a hot native combat-path function that fires constantly for every
-- actor in the world, it's now a crash-risk suspect with zero upside. Removed rather than kept
-- "harmless" - RegisterHook on BP_ApplyAttackDamage and its pre/post callbacks are gone.

-- Stopgap while the real damage-application entry point is still unconfirmed: a much
-- tighter dedicated poll (100ms instead of the main 1000ms tick) shrinks the death window
-- 10x. Doesn't fix a one-shot kill that exceeds max health in a single hit, but should cover
-- ordinary sustained combat damage. Kept separate from ApplyCommand/StartTickLoop so it
-- doesn't add the file-read and settings/level/camera work to this hot path.
local function ForceDirectHealthAttribute(player)
    local ascOk, asc = pcall(function() return player.AbilitySystemComponent end)
    if not ascOk or not asc or not SafeIsValid(asc) then return end

    if not CharacterAttributeSetClass or not SafeIsValid(CharacterAttributeSetClass) then
        local classOk, class = pcall(function()
            return StaticFindObject("/Script/DogwoodStats.CharacterBaseAttributeSet")
        end)
        if classOk and class then CharacterAttributeSetClass = class end
    end
    if not CharacterAttributeSetClass then return end

    local attrSetOk, attrSet = pcall(function() return asc:GetAttributeSet(CharacterAttributeSetClass) end)
    if not attrSetOk or not attrSet or not SafeIsValid(attrSet) then return end

    local readOk, maxHealth = pcall(function() return attrSet.MaxHealth.CurrentValue end)
    if not readOk or not maxHealth or maxHealth <= 0 then return end

    local currentOk, currentHealth = pcall(function() return attrSet.Health.CurrentValue end)
    LastRawHealth = currentOk and currentHealth or "unknown"
    LastRawMaxHealth = maxHealth

    -- Log the first few raw readings unconditionally - this is the evidence that confirms or
    -- refutes the "SetHealthPercent is a derived value" theory on the next live combat test.
    if DirectHealthDiagLogCount < 10 then
        DirectHealthDiagLogCount = DirectHealthDiagLogCount + 1
        print(string.format("[DawnwalkerModBridge] Raw GAS health: current=%s max=%s",
            tostring(LastRawHealth), tostring(LastRawMaxHealth)))
    end

    local writeOk, writeErr = pcall(function()
        attrSet.Health.CurrentValue = maxHealth
        attrSet.Health.BaseValue = maxHealth
    end)
    LastDirectHealthWriteOk = writeOk and 1 or 0
    if not writeOk and not ReportedDirectHealthWriteError then
        print("[DawnwalkerModBridge] Direct Health attribute write failed: " .. tostring(writeErr))
        ReportedDirectHealthWriteError = true
    end
end

local function StartFastHealthStaminaLoop()
    -- ROOT CAUSE (2026-09-03): this loop only ever read the shared CombatSettleTicksRemaining
    -- counter, which is exclusively refreshed by RefreshPawnSettleState - itself only called from
    -- the slower 1000ms ApplyCommand loop. For up to ~1s after every respawn (until the next slow
    -- tick notices the pawn address changed), this counter is stale/zero, so this 100ms loop kept
    -- scanning/writing the brand-new pawn's combat component completely unguarded. Isolation
    -- testing (disabling this loop entirely stopped a crash that survived removing every other
    -- suspect) confirmed this race is live. Fix: track address changes independently here too, on
    -- this loop's own schedule, so the gate reacts within one 100ms tick instead of waiting on
    -- the other loop.
    local fastLoopLastAddress = nil
    local fastLoopSettleTicksRemaining = 0
    pcall(function()
        LoopAsync(100, function()
            local ok, err = pcall(function()
                local playerOk, player = pcall(UEHelpers.GetPlayer)
                if not playerOk or not player or not SafeIsValid(player) then return end
                local addrOk, address = pcall(function() return player:GetAddress() end)
                if addrOk then
                    if address ~= fastLoopLastAddress then
                        fastLoopLastAddress = address
                        fastLoopSettleTicksRemaining = 30 -- 30 * 100ms = 3s, own independent gate
                    elseif fastLoopSettleTicksRemaining > 0 then
                        fastLoopSettleTicksRemaining = fastLoopSettleTicksRemaining - 1
                    end
                end
                if fastLoopSettleTicksRemaining > 0 then return end
                if CombatSettleTicksRemaining > 0 then return end
                local command = ReadCommandFile()
                if not command then return end
                local combat = GetPlayerCombatComponent(player)
                if not combat or not SafeIsValid(combat) then return end
                -- Screenshot evidence (2026-09-03) showed a fatal crash dump written at the exact
                -- instant of a death screen - our raw attribute write in ForceDirectHealthAttribute
                -- bypasses all engine-side validity checks, so it's a plausible cause if it fires
                -- while the character is already being torn down for death. Skip all health/stamina
                -- writes once the game itself considers the character dead (fail-open on error so a
                -- broken IsAlive() call doesn't silently disable protection during normal combat).
                local aliveOk, isAlive = pcall(function() return combat:IsAlive() end)
                if aliveOk and isAlive == false then return end
                if command.infiniteHealth == "1" then
                    pcall(function() combat:SetHealthPercent(1.0) end)
                    ForceDirectHealthAttribute(player)
                end
                if command.infiniteStamina == "1" then
                    pcall(function() combat:SetStaminaPercent(1.0) end)
                end
            end)
            if not ok then
                print("[DawnwalkerModBridge] Fast health/stamina loop error: " .. tostring(err))
            end
            return false
        end)
    end)
end
StartFastHealthStaminaLoop()

StartTickLoop()

pcall(ApplyCommand)
print("[DawnwalkerModBridge] Loaded. Watching " .. COMMAND_PATH)

