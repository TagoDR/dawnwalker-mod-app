-- features/skills.lua: Trait points, trait tree unlocks/respec, vampire mutation, and cooldown toggles
local Safety = require("safety")
local State = require("state")

local Skills = {}

local PlayerAttributeSetClass = nil
local MAX_ACTION_SLOTS = 5

local function GetSubsystem()
    return Safety.FindValid(function() return FindFirstOf("CharacterDevelopmentSubsystem") end)
end

local function GetFocusAbilitiesSubsystem()
    return Safety.FindValid(function() return FindFirstOf("FocusAbilitiesSubsystem") end)
end

-- Add or remove unspent trait (skill) points
function Skills.AddTraitPoints(amount)
    local subsystem = GetSubsystem()
    if not subsystem then return false, "CharacterDevelopmentSubsystem not found" end
    local delta = math.floor(tonumber(amount) or 0)
    if delta == 0 then return false, "Amount cannot be 0" end

    local ok = pcall(function() subsystem:ReceiveTraitPoints(delta) end)
    return ok, ok and string.format("Trait points adjusted by %+d", delta) or "Failed to modify trait points"
end

-- Set unspent trait points to an exact total
function Skills.SetTraitPoints(total)
    local subsystem = GetSubsystem()
    if not subsystem then return false, "CharacterDevelopmentSubsystem not found" end
    local val = math.max(0, math.floor(tonumber(total) or 0))

    local ok = pcall(function() subsystem:SetTraitPointsAmount(val) end)
    return ok, ok and string.format("Trait points set to %d", val) or "Failed to set trait points"
end

-- Unlock entire trait tree (unlock, unblock, unhide)
function Skills.UnlockAllTraits()
    local subsystem = GetSubsystem()
    if not subsystem then return false, "CharacterDevelopmentSubsystem not found" end

    local ok = pcall(function() subsystem:UnlockAllTraits(true, true, true, false) end)
    return ok, ok and "All traits unlocked" or "Failed to unlock traits"
end

-- Full trait tree respec
function Skills.ResetAllTraits()
    local subsystem = GetSubsystem()
    if not subsystem then return false, "CharacterDevelopmentSubsystem not found" end

    local ok = pcall(function() subsystem:ResetAllTraits() end)
    return ok, ok and "All traits reset" or "Failed to reset traits"
end

-- Add or remove vampire corruption / mutation charges
function Skills.AddMutationCharges(amount)
    local subsystem = GetSubsystem()
    if not subsystem then return false, "CharacterDevelopmentSubsystem not found" end
    local delta = math.floor(tonumber(amount) or 0)
    if delta == 0 then return false, "Amount cannot be 0" end

    local ok = pcall(function() subsystem:AddMutationCharges(delta) end)
    return ok, ok and string.format("Mutation charges adjusted by %+d", delta) or "Failed to modify mutation charges"
end

-- Toggle ability cooldowns
function Skills.ToggleCooldowns()
    local focus = GetFocusAbilitiesSubsystem()
    if not focus then return false, "FocusAbilitiesSubsystem not found" end

    local ok = pcall(function() focus:ToggleDisablingAllCooldowns_Debug() end)
    if ok then
        State.Toggles.noCooldowns = not State.Toggles.noCooldowns
    end
    return ok, ok and (State.Toggles.noCooldowns and "Cooldowns disabled" or "Cooldowns enabled") or "Failed to toggle cooldowns"
end

-- Keeps the player's ability activation charges topped up
local function ApplyActionSlotsOverride(player, enabled)
    local focus = Safety.FindOwnedComponent("CombatFocusComponent", player)
    if not focus or not Safety.SafeIsValid(focus) then return false end

    if not enabled then
        if State.Internal.WasActionSlotsOverridden then
            pcall(function() focus:ResetSlotsChargedOverride() end)
            State.Internal.WasActionSlotsOverridden = false
        end
        return false
    end

    local slots = 0
    local ascOk, asc = pcall(function() return player.AbilitySystemComponent end)
    if ascOk and asc and Safety.SafeIsValid(asc) then
        if not PlayerAttributeSetClass or not Safety.SafeIsValid(PlayerAttributeSetClass) then
            local classOk, class = pcall(function()
                return StaticFindObject("/Script/DogwoodStats.PlayerAttributeSet")
            end)
            if classOk and class then PlayerAttributeSetClass = class end
        end
        if PlayerAttributeSetClass then
            local attrSetOk, attrSet = pcall(function() return asc:GetAttributeSet(PlayerAttributeSetClass) end)
            if attrSetOk and attrSet and Safety.SafeIsValid(attrSet) then
                local readOk, unlocked = pcall(function() return attrSet.UnlockedActionSlots.CurrentValue end)
                if readOk and unlocked and unlocked > 0 then slots = unlocked end
            end
        end
    end
    if slots <= 0 then slots = MAX_ACTION_SLOTS end

    local writeOk = pcall(function() focus:SetSlotsChargedOverride(slots) end)
    if writeOk then State.Internal.WasActionSlotsOverridden = true end
    return writeOk
end

-- Periodic skills tick: updates trait and mutation telemetry, handles cooldown and slot overrides
function Skills.Tick(player)
    local subsystem = GetSubsystem()
    if subsystem then
        local tpOk, tp = pcall(function() return subsystem:GetTraitPointAmount() end)
        if tpOk and tp then State.Readouts.traitPoints = tp end

        local mcOk, mc = pcall(function() return subsystem:GetCurrentMutationCharges() end)
        if mcOk and mc then State.Readouts.mutationCharges = mc end

        local mlOk, ml = pcall(function() return subsystem:GetCurrentMutationLevel() end)
        if mlOk and ml then State.Readouts.mutationLevel = ml end
    end

    -- Cooldowns management
    local focus = GetFocusAbilitiesSubsystem()
    if focus then
        local cdOk, areEnabled = pcall(function() return focus:AreCooldownsEnabled_Debug() end)
        if cdOk then
            State.Readouts.cooldownsDisabled = (areEnabled == false)
            if State.Toggles.noCooldowns and areEnabled == true then
                pcall(function() focus:ToggleDisablingAllCooldowns_Debug() end)
            elseif not State.Toggles.noCooldowns and areEnabled == false then
                pcall(function() focus:ToggleDisablingAllCooldowns_Debug() end)
            end
        end
    end

    -- Action slots charging
    if player and Safety.SafeIsValid(player) then
        ApplyActionSlotsOverride(player, State.Toggles.keepActionSlotsCharged)
    end
end

return Skills
