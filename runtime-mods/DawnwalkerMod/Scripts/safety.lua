-- safety.lua: Crash-prevention guards, settle-window tracking, and reflection validity checks
local UEHelpers = require("UEHelpers")

local Safety = {}

Safety.LastPlayerAddress = nil
Safety.CombatSettleTicksRemaining = 0
Safety.MovementSettleTicksRemaining = 0
Safety.CombatComponentSettleTicksRemaining = 0
Safety.CutsceneActive = false

-- Crash dump analysis (0xC0000005 access violations) proved pcall does NOT catch native access violations.
-- SafeIsValid provides safe defensive checking before touching any UObject.
function Safety.SafeIsValid(object)
    if not object then return false end
    local ok, valid = pcall(function() return object:IsValid() end)
    return ok and valid == true
end

-- Compare underlying memory addresses of two UObject Lua proxies
function Safety.SameObject(a, b)
    local okA, addrA = pcall(function() return a:GetAddress() end)
    local okB, addrB = pcall(function() return b:GetAddress() end)
    return okA and okB and addrA == addrB
end

function Safety.FindValid(getter)
    local ok, object = pcall(getter)
    if ok and object and Safety.SafeIsValid(object) then return object end
    return nil
end

-- Find an ActorComponent owned specifically by the player pawn
function Safety.FindOwnedComponent(className, player)
    if not player or not Safety.SafeIsValid(player) then return nil end
    local componentsOk, components = pcall(FindAllOf, className)
    if not componentsOk or not components then return nil end

    local playerAddrOk, playerAddr = pcall(function() return player:GetAddress() end)
    if not playerAddrOk then return nil end

    for _, component in ipairs(components) do
        if Safety.SafeIsValid(component) then
            local ownerOk, owner = pcall(function() return component:GetOwner() end)
            if ownerOk and owner and Safety.SafeIsValid(owner) then
                if Safety.SameObject(owner, player) then
                    return component
                end
            end
        end
    end
    return nil
end

-- Cutscenes & dialogues swap/tear down actors under the mod's feet.
-- Mod writes must pause while any cinematic/dialogue condition is true.
function Safety.IsCutsceneActive(player)
    local cinematic = Safety.FindValid(function() return FindFirstOf("CinematicSubsystem") end)
    if cinematic then
        local ok, active = pcall(function() return cinematic:IsDialogueActive() end)
        if ok and active == true then return true end
        if player then
            local inOk, inCutscene = pcall(function() return cinematic:IsCharacterInCinematicDialogueOrCutscene(player) end)
            if inOk and inCutscene == true then return true end
        end
    end
    local focus = Safety.FindValid(function() return FindFirstOf("FocusAbilitiesSubsystem") end)
    if focus then
        local ok, mode = pcall(function() return focus:GetIsInFocusAbilityCinematicMode() end)
        if ok and mode == true then return true end
    end
    return false
end

-- Check if an in-game menu is open (HUD hidden or full-screen menu active)
function Safety.IsMenuOpen()
    local ui = Safety.FindValid(function() return FindFirstOf("UIManagerSubsystem") end)
    if ui then
        local ok, showing = pcall(function() return ui:ShouldShowGameplayWidgets() end)
        if ok and showing == false then return true end
    end
    local hud = Safety.FindValid(function() return FindFirstOf("HUDManagerSubsystem") end)
    if hud then
        local ok, visible = pcall(function() return hud:IsHUDVisible() end)
        if ok and visible == false then return true end
    end
    return false
end

-- Tracks pawn respawns and manages settle windows to prevent post-respawn crashes.
-- When the player pawn address changes, component writes must be delayed by a few ticks.
function Safety.RefreshPawnSettleState(onPawnChanged)
    local playerOk, player = pcall(UEHelpers.GetPlayer)
    if not playerOk or not player or not Safety.SafeIsValid(player) then return nil end
    local addrOk, address = pcall(function() return player:GetAddress() end)
    if not addrOk then return player end

    if address ~= Safety.LastPlayerAddress then
        Safety.LastPlayerAddress = address
        Safety.CombatSettleTicksRemaining = 3
        Safety.MovementSettleTicksRemaining = 6
        if onPawnChanged then
            pcall(onPawnChanged, player)
        end
    else
        if Safety.CombatSettleTicksRemaining > 0 then
            Safety.CombatSettleTicksRemaining = Safety.CombatSettleTicksRemaining - 1
        end
        if Safety.MovementSettleTicksRemaining > 0 then
            Safety.MovementSettleTicksRemaining = Safety.MovementSettleTicksRemaining - 1
        end
    end
    return player
end

return Safety
