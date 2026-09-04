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
local WasCombatFound = false
local ReportedLockHealthError = false
local ReportedUnlockHealthError = false
local ReportedLockStaminaError = false
local ReportedUnlockStaminaError = false
-- LockHealth() alone (below) runs with no Lua error but does NOT actually stop combat
-- damage from landing - confirmed live: health still dropped with healthLocked=1. The
-- function that actually blocks damage is RebelAISubsystem:AddPlayerInvulnerability(Source).
local WasHealthInvulnerable = false
local ReportedAddInvulnerabilityError = false
local ReportedRemoveInvulnerabilityError = false
local WasRebelAIFound = false
-- REAL FIX ATTEMPT #4: this game uses Unreal's GameplayAbilities plugin (GAS) for Health -
-- /Script/DogwoodStats.CharacterBaseAttributeSet has Health/MaxHealth as GAS attributes, and
-- the player's DawnwalkerCharacterBase:AbilitySystemComponent (class DawnwalkerAbilitySystemComponent)
-- is a real ASC. The game ships its own native invulnerability effect,
-- /Game/_Dawnwalker/Combat/Effects/Persistent/GE_Invulnerability.GE_Invulnerability_C, applyable
-- through the ASC's own BlueprintCallable functions (MakeEffectContext/MakeOutgoingSpec/
-- BP_ApplyGameplayEffectSpecToSelf) - this is how the GAME ITSELF would grant invulnerability
-- (e.g. during scripted sequences), not a guessed "toggle a flag" API.
local InvulnerabilityGEClass = nil
local WasGodModeApplied = false
local ReportedGodModeApplyError = false
local ReportedGodModeRemoveError = false
-- REAL FIX ATTEMPT #4 CONFIRMED WRONG (2026-09-03): GE_Invulnerability applied cleanly via the
-- ASC (no error, godModeApplied=1 for 4+ minutes) but the player still died in 3 hits - this GE
-- likely only grants a cosmetic tag, it does not actually gate the damage pipeline.
-- REAL FIX ATTEMPT #5: toggle Unreal's own native CheatManager:God() cheat. This is the stock
-- engine "god mode" command (bound to the console "god" command) - unlike our own guessed toggle
-- APIs, this is the actual mechanism the engine's own cheat system uses to stop damage. It has no
-- getter, so track our own applied flag and only call it on rising/falling edge to avoid
-- re-toggling it back off on every tick.
local WasNativeGodModeApplied = false
local ReportedNativeGodModeError = false
-- REAL FIX ATTEMPT #5 CONFIRMED WRONG (2026-09-03): native God() toggled on with no error
-- (nativeGodModeApplied=1) yet the player still died in a fast 3-hit combo, health dropping in
-- large chunks with NO recovery between hits at all - even though the 100ms SetHealthPercent(1.0)
-- poll should have partially clawed it back if that call actually reached the value death checks
-- against. Working theory: SetHealthPercent/GetHealthPercentage on CombatComponentBase are a
-- derived/display value, while the real authoritative value is the GAS attribute
-- /Script/DogwoodStats.CharacterBaseAttributeSet:Health (a FGameplayAttributeData struct with its
-- own BaseValue/CurrentValue), fetched off the ASC via GetAttributeSet(AttributeSetClass).
-- REAL FIX ATTEMPT #6: on the fast 100ms loop, fetch the ASC's CharacterBaseAttributeSet instance
-- directly and force both Health.CurrentValue and Health.BaseValue to MaxHealth.CurrentValue,
-- bypassing SetHealthPercent entirely. Also records the raw values seen so status.txt can confirm
-- or refute the theory on the next live test regardless of whether the write itself works.
local CharacterAttributeSetClass = nil
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
            writeOk = pcall(function()
                attrSet[attrName].CurrentValue = base * multiplier
                attrSet[attrName].BaseValue = base * multiplier
            end)
        end
        if diagLog then
            local currentOk, currentVal = pcall(function() return attrSet[attrName].CurrentValue end)
            print(string.format(
                "[DawnwalkerModBridge] DamageMultiplier diag: %s base=%s multiplier=%s writeOk=%s currentAfterWrite=%s",
                attrName, tostring(base), tostring(multiplier), tostring(writeOk), tostring(currentOk and currentVal or "unknown")))
        end
    end
end

local function ApplyCommand()
    local player = RefreshPawnSettleState()
    local combatSettling = CombatSettleTicksRemaining > 0
    local movementSettling = MovementSettleTicksRemaining > 0

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
        end

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
            end
            status.combatFound = 1
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
                -- Wide range on purpose (up to a guaranteed one-shot-kill multiplier) - unlike
                -- speed/jump this can't clip the player through geometry, so there's no physics
                -- reason to keep it tight.
                if dmgMult and dmgMult >= 0.1 and dmgMult <= 50 then
                    -- Same raw-struct-write hazard as ForceDirectHealthAttribute: bypasses all
                    -- engine-side validity checks, so skip it once the game considers the
                    -- character dead (fail-open on error, same as the health path).
                    local aliveOk, isAlive = pcall(function() return combat:IsAlive() end)
                    if not (aliveOk and isAlive == false) then
                        ApplyDamageMultiplier(player, dmgMult)
                    end
                    status.damageMultiplierApplied = 1
                else
                    status.damageMultiplierApplied = 0
                    status.damageMultiplierRejected = "out_of_range"
                end
            end
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
        else
            WasCombatFound = false
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

