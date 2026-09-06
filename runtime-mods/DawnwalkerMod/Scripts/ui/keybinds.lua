-- ui/keybinds.lua: Hotkey bindings for instant toggles and menu navigation
local Safety = require("safety")
local State = require("state")
local Menu = require("ui.hud_menu")
local Combat = require("features.combat")
local Movement = require("features.movement")
local Skills = require("features.skills")
local World = require("features.world")

local Keybinds = {}

local function Notify(msg)
    print(string.format("[DawnwalkerMod] %s", msg))
    local player = Safety.FindValid(function() return UEHelpers.GetPlayer() end)
    if player then
        local pc = player.Controller
        if pc and Safety.SafeIsValid(pc) then
            pcall(function() pc:ClientMessage(string.format("[DawnwalkerMod] %s", msg)) end)
        end
    end
end

function Keybinds.Init()
    -- Menu Toggle (F1)
    pcall(RegisterKeyBind, Key.F1, function()
        Menu.Toggle()
    end)

    -- Menu Navigation Keys
    pcall(RegisterKeyBind, Key.TAB, function()
        if Menu.IsOpen then
            local numTabs = Menu.Tabs and #Menu.Tabs or 7
            Menu.ActiveTab = (Menu.ActiveTab % numTabs) + 1
            Menu.SelectedRow = 1
        end
    end)

    pcall(RegisterKeyBind, Key.UP, function()
        if Menu.IsOpen then Menu.Navigate(-1) end
    end)

    pcall(RegisterKeyBind, Key.DOWN, function()
        if Menu.IsOpen then Menu.Navigate(1) end
    end)

    pcall(RegisterKeyBind, Key.LEFT, function()
        if Menu.IsOpen then Menu.Adjust(-1) end
    end)

    pcall(RegisterKeyBind, Key.RIGHT, function()
        if Menu.IsOpen then Menu.Adjust(1) end
    end)

    pcall(RegisterKeyBind, Key.ENTER, function()
        if Menu.IsOpen then Menu.Select() end
    end)

    -- Quick Shortcut Keys (NumPad)
    -- NumPad 1: Heal Now
    pcall(RegisterKeyBind, Key.NUM_ONE, function()
        local player = Safety.FindValid(function() return UEHelpers.GetPlayer() end)
        local ok, msg = Combat.HealNow(player)
        Notify(msg)
    end)

    -- NumPad 2: Toggle Infinite Health (God Mode)
    pcall(RegisterKeyBind, Key.NUM_TWO, function()
        State.Toggles.infiniteHealth = not State.Toggles.infiniteHealth
        Notify("Infinite Health (God Mode): " .. (State.Toggles.infiniteHealth and "ON" or "OFF"))
    end)

    -- NumPad 3: Toggle Infinite Stamina
    pcall(RegisterKeyBind, Key.NUM_THREE, function()
        State.Toggles.infiniteStamina = not State.Toggles.infiniteStamina
        Notify("Infinite Stamina: " .. (State.Toggles.infiniteStamina and "ON" or "OFF"))
    end)

    -- NumPad 4: Toggle Infinite Blood
    pcall(RegisterKeyBind, Key.NUM_FOUR, function()
        State.Toggles.infiniteBlood = not State.Toggles.infiniteBlood
        Notify("Infinite Blood: " .. (State.Toggles.infiniteBlood and "ON" or "OFF"))
    end)

    -- NumPad 5: Cycle Movement Mode (Walk -> Fly -> Ghost)
    pcall(RegisterKeyBind, Key.NUM_FIVE, function()
        local player = Safety.FindValid(function() return UEHelpers.GetPlayer() end)
        local mode = Movement.CycleMode(player)
        Notify("Movement Mode: " .. mode:upper())
    end)

    -- NumPad 6: Teleport to Aim Point
    pcall(RegisterKeyBind, Key.NUM_SIX, function()
        local player = Safety.FindValid(function() return UEHelpers.GetPlayer() end)
        local ok, msg = Movement.Teleport(player)
        Notify(msg)
    end)

    -- NumPad 7: Kill All Aggressive Hostiles
    pcall(RegisterKeyBind, Key.NUM_SEVEN, function()
        local player = Safety.FindValid(function() return UEHelpers.GetPlayer() end)
        local ok, msg = Combat.KillAllAggressive(player)
        Notify(msg)
    end)

    -- NumPad 8: Toggle Ability Cooldowns
    pcall(RegisterKeyBind, Key.NUM_EIGHT, function()
        local ok, msg = Skills.ToggleCooldowns()
        Notify(msg)
    end)

    -- NumPad 9: Advance Time 1 Hour
    pcall(RegisterKeyBind, Key.NUM_NINE, function()
        local ok, msg = World.AdvanceTime(1.0)
        Notify(msg)
    end)

    print("[DawnwalkerMod] Keybinds registered: [F1] Menu | [NumPad 1-9] Cheats")
end

return Keybinds
