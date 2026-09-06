-- features/combat.lua: Combat, survivability, damage scaling, and enemy utilities
local Safety = require("safety")
local State = require("state")

local Combat = {}

local InvulnerabilityGEClass = nil

local function GetRebelAISubsystem()
    return Safety.FindValid(function() return FindFirstOf("RebelAISubsystem") end)
end

local function GetCombatSubsystem()
    return Safety.FindValid(function() return FindFirstOf("CombatSubsystem") end)
end

local function GetBloodBarComponent()
    return Safety.FindValid(function() return FindFirstOf("BloodBarComponent") end)
end

local function GetPlayerCombatComponent(player)
    return Safety.FindOwnedComponent("CombatComponentBase", player)
end

-- Collect addresses of all hostile NPCs tracked by the combat subsystem
function Combat.GetAggressiveNpcAddresses()
    local combatSubsystem = GetCombatSubsystem()
    if not combatSubsystem then return nil, 0 end
    local actorsOk, actors = pcall(function() return combatSubsystem:GetAllAggressiveNPCActors() end)
    if not actorsOk or type(actors) ~= "table" then return nil, 0 end
    local addresses = {}
    local count = 0
    for _, param in ipairs(actors) do
        local getOk, actor = pcall(function() return param:get() end)
        if not getOk or not actor then actor = param end
        if actor and Safety.SafeIsValid(actor) then
            local addrOk, addr = pcall(function() return actor:GetAddress() end)
            if addrOk then
                addresses[addr] = true
                count = count + 1
            end
        end
    end
    return addresses, count
end

-- Kill all combat components owned by specific actor addresses
local function KillCombatComponentsOwnedBy(ownerAddresses, skipAddress)
    local componentsOk, components = pcall(FindAllOf, "CombatComponentBase")
    if not componentsOk or not components then return 0 end
    local killed = 0
    for _, component in ipairs(components) do
        if Safety.SafeIsValid(component) then
            local ownerOk, owner = pcall(function() return component:GetOwner() end)
            if ownerOk and owner and Safety.SafeIsValid(owner) then
                local addrOk, addr = pcall(function() return owner:GetAddress() end)
                if addrOk and addr ~= skipAddress and ownerAddresses[addr] then
                    local aliveOk, alive = pcall(function() return component:IsAlive() end)
                    if not (aliveOk and alive == false) then
                        local killOk = pcall(function() component:Kill() end)
                        if killOk then killed = killed + 1 end
                    end
                end
            end
        end
    end
    return killed
end

-- Fast loop damage amplifier: re-applies damage dealt by the player to hostile NPCs scaled by multiplier
function Combat.AmplifyDamageToAggressiveNPCs(player, multiplier)
    local addresses, count = Combat.GetAggressiveNpcAddresses()
    if not addresses or count == 0 then
        if next(State.Internal.AmpHealth) ~= nil then State.Internal.AmpHealth = {} end
        return 0
    end

    local componentsOk, components = pcall(FindAllOf, "CombatComponentBase")
    if not componentsOk or not components then return 0 end

    local playerAddrOk, playerAddr = pcall(function() return player:GetAddress() end)
    local skipAddress = playerAddrOk and playerAddr or nil

    local seen = {}
    local amplified = 0
    for _, component in ipairs(components) do
        if Safety.SafeIsValid(component) then
            local ownerOk, owner = pcall(function() return component:GetOwner() end)
            if ownerOk and owner and Safety.SafeIsValid(owner) then
                local addrOk, addr = pcall(function() return owner:GetAddress() end)
                if addrOk and addr ~= skipAddress and addresses[addr] then
                    seen[addr] = true
                    local aliveOk, alive = pcall(function() return component:IsAlive() end)
                    if not (aliveOk and alive == false) then
                        local hpOk, hp = pcall(function() return component:GetHealthPercentage() end)
                        if hpOk and type(hp) == "number" then
                            local previous = State.Internal.AmpHealth[addr]
                            if previous and hp < previous then
                                local extra = (previous - hp) * (multiplier - 1)
                                local wanted = hp - extra
                                if wanted <= 0 then
                                    if pcall(function() component:Kill() end) then amplified = amplified + 1 end
                                    State.Internal.AmpHealth[addr] = nil
                                elseif pcall(function() component:SetHealthPercent(wanted) end) then
                                    State.Internal.AmpHealth[addr] = wanted
                                    amplified = amplified + 1
                                else
                                    State.Internal.AmpHealth[addr] = hp
                                end
                            else
                                State.Internal.AmpHealth[addr] = hp
                            end
                        end
                    end
                end
            end
        end
    end
    for addr in pairs(State.Internal.AmpHealth) do
        if not seen[addr] then State.Internal.AmpHealth[addr] = nil end
    end
    return amplified
end

-- One-shot heal action
function Combat.HealNow(player)
    local combat = GetPlayerCombatComponent(player)
    if not combat then return false, "Combat component not found" end
    local ok = pcall(function()
        combat:SetHealthPercent(1.0)
        combat:SetStaminaPercent(1.0)
    end)
    return ok, ok and "Health and stamina fully restored" or "Failed to heal"
end

-- One-shot blood refill action
function Combat.RefillBlood()
    local bloodBar = GetBloodBarComponent()
    if not bloodBar then return false, "Blood bar component not found" end
    local ok = pcall(function() bloodBar:HealAndReplenishAllSegments() end)
    return ok, ok and "Blood fully replenished" or "Failed to replenish blood"
end

-- One-shot kill all aggressive enemies action
function Combat.KillAllAggressive(player)
    local addresses, count = Combat.GetAggressiveNpcAddresses()
    if not addresses or count == 0 then return true, "No aggressive enemies nearby" end
    local playerAddrOk, playerAddr = pcall(function() return player:GetAddress() end)
    local killed = KillCombatComponentsOwnedBy(addresses, playerAddrOk and playerAddr or nil)
    return true, string.format("Killed %d of %d aggressive enemies", killed, count)
end

-- Periodic combat tick: applies persistent toggles, difficulties, and updates telemetry
function Combat.Tick(player, combatSettling)
    local combatSubsystem = GetCombatSubsystem()
    if combatSubsystem then
        -- Telemetry: inCombat & aggressive count
        local inCombatOk, inCombat = pcall(function() return combatSubsystem:GetIsInCombat() end)
        State.Readouts.inCombat = inCombatOk and inCombat == true
        local countOk, count = pcall(function() return combatSubsystem:GetAggressiveNpcCount() end)
        State.Readouts.aggressiveNpcCount = countOk and count or 0

        -- Difficulty settings
        local actionDiff = State.Gameplay.actionDifficulty
        if actionDiff ~= State.Internal.LastAppliedActionDifficulty then
            if State.Internal.OriginalActionDifficulty == nil then
                local origOk, orig = pcall(function() return combatSubsystem:GetActionDifficultyLevel() end)
                if origOk and type(orig) == "number" then State.Internal.OriginalActionDifficulty = orig end
            end
            pcall(function() combatSubsystem:SetActionDifficulty(actionDiff) end)
            State.Internal.LastAppliedActionDifficulty = actionDiff
        end

        local rpgDiff = State.Gameplay.rpgDifficulty
        if rpgDiff ~= State.Internal.LastAppliedRPGDifficulty then
            pcall(function() combatSubsystem:SetRPGDifficulty(rpgDiff) end)
            State.Internal.LastAppliedRPGDifficulty = rpgDiff
        end
    end

    -- Blood Bar (Lives on PlayerState)
    local bloodBar = GetBloodBarComponent()
    if bloodBar then
        local bloodOk, blood = pcall(function() return bloodBar.BloodAmount end)
        State.Readouts.bloodPercent = bloodOk and blood or 1.0

        if State.Toggles.infiniteBlood then
            pcall(function()
                bloodBar:SetBloodPercent(1.0)
                bloodBar:LockBlood()
            end)
            State.Internal.WasBloodLocked = true
        elseif State.Internal.WasBloodLocked then
            pcall(function() bloodBar:UnlockBlood() end)
            State.Internal.WasBloodLocked = false
        end
    end

    -- Skip per-pawn combat components while settling after respawn
    if combatSettling or not player or not Safety.SafeIsValid(player) then
        State.Readouts.combatFound = false
        return
    end

    -- Invulnerability via RebelAISubsystem
    local rebelAI = GetRebelAISubsystem()
    if rebelAI then
        if State.Toggles.infiniteHealth then
            if not State.Internal.WasHealthInvulnerable then
                local addOk = pcall(function() rebelAI:AddPlayerInvulnerability(player) end)
                if addOk then State.Internal.WasHealthInvulnerable = true end
            end
        elseif State.Internal.WasHealthInvulnerable then
            local remOk = pcall(function() rebelAI:RemovePlayerInvulnerability(player) end)
            if remOk then State.Internal.WasHealthInvulnerable = false end
        end
    end

    local combat = GetPlayerCombatComponent(player)
    if combat then
        State.Readouts.combatFound = true
        local hpOk, hp = pcall(function() return combat:GetHealthPercentage() end)
        State.Readouts.healthPercent = hpOk and hp or 1.0
        local stOk, st = pcall(function() return combat:GetStaminaPercentage() end)
        State.Readouts.staminaPercent = stOk and st or 1.0

        -- Infinite Health
        if State.Toggles.infiniteHealth then
            pcall(function()
                combat:SetHealthPercent(1.0)
                combat:LockHealth()
            end)
            -- Redundant GAS Invulnerability Effect
            if not State.Internal.WasGodModeApplied then
                local ascOk, asc = pcall(function() return player.AbilitySystemComponent end)
                if ascOk and asc and Safety.SafeIsValid(asc) then
                    if not InvulnerabilityGEClass or not Safety.SafeIsValid(InvulnerabilityGEClass) then
                        local clOk, cl = pcall(function()
                            return StaticFindObject("/Game/_Dawnwalker/Abilities/Player/GE_Invulnerability.GE_Invulnerability_C")
                        end)
                        if clOk and cl then InvulnerabilityGEClass = cl end
                    end
                    if InvulnerabilityGEClass then
                        local applyOk = pcall(function() asc:BP_ApplyGameplayEffectToSelf(InvulnerabilityGEClass, 1.0, asc:MakeEffectContext()) end)
                        if applyOk then State.Internal.WasGodModeApplied = true end
                    end
                end
            end
        else
            if State.Internal.WasGodModeApplied then
                pcall(function() combat:UnlockHealth() end)
                State.Internal.WasGodModeApplied = false
            end
        end

        -- Infinite Stamina
        if State.Toggles.infiniteStamina then
            pcall(function()
                combat:SetStaminaPercent(1.0)
                combat:LockStamina()
            end)
        else
            pcall(function() combat:UnlockStamina() end)
        end
    else
        State.Readouts.combatFound = false
    end
end

return Combat
