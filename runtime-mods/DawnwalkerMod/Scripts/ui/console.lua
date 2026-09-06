-- ui/console.lua: In-game console command handlers (dw_*)
local Safety = require("safety")
local State = require("state")
local Menu = require("ui.hud_menu")
local Combat = require("features.combat")
local Character = require("features.character")
local Movement = require("features.movement")
local Skills = require("features.skills")
local World = require("features.world")
local Inventory = require("features.inventory")
local Granter = require("gear.granter")
local Config = require("config")

local Console = {}

local function RegisterCmd(name, handler)
    pcall(RegisterConsoleCommandHandler, name, function(params)
        local ok, err = pcall(handler, params)
        if not ok then
            print(string.format("[DawnwalkerMod] Error executing %s: %s", name, tostring(err)))
        end
        return true
    end)
end

function Console.Init()
    -- Menu toggle
    RegisterCmd("dw_menu", function()
        Menu.Toggle()
    end)

    -- God Mode / Infinite Health
    RegisterCmd("dw_god", function(params)
        local val = params and params[1]
        if val == "1" or val == "true" or val == "on" then
            State.Toggles.infiniteHealth = true
        elseif val == "0" or val == "false" or val == "off" then
            State.Toggles.infiniteHealth = false
        else
            State.Toggles.infiniteHealth = not State.Toggles.infiniteHealth
        end
        print(string.format("[DawnwalkerMod] God Mode: %s", State.Toggles.infiniteHealth and "ON" or "OFF"))
    end)

    -- Infinite Stamina
    RegisterCmd("dw_stamina", function(params)
        local val = params and params[1]
        if val == "1" or val == "true" or val == "on" then
            State.Toggles.infiniteStamina = true
        elseif val == "0" or val == "false" or val == "off" then
            State.Toggles.infiniteStamina = false
        else
            State.Toggles.infiniteStamina = not State.Toggles.infiniteStamina
        end
        print(string.format("[DawnwalkerMod] Infinite Stamina: %s", State.Toggles.infiniteStamina and "ON" or "OFF"))
    end)

    -- Infinite Blood
    RegisterCmd("dw_blood", function(params)
        local val = params and params[1]
        if val == "1" or val == "true" or val == "on" then
            State.Toggles.infiniteBlood = true
        elseif val == "0" or val == "false" or val == "off" then
            State.Toggles.infiniteBlood = false
        else
            State.Toggles.infiniteBlood = not State.Toggles.infiniteBlood
        end
        print(string.format("[DawnwalkerMod] Infinite Blood: %s", State.Toggles.infiniteBlood and "ON" or "OFF"))
    end)

    -- Heal
    RegisterCmd("dw_heal", function()
        local player = Safety.FindValid(function() return UEHelpers.GetPlayer() end)
        local ok, msg = Combat.HealNow(player)
        print(string.format("[DawnwalkerMod] %s", msg))
    end)

    -- Refill Blood
    RegisterCmd("dw_refillblood", function()
        local ok, msg = Combat.RefillBlood()
        print(string.format("[DawnwalkerMod] %s", msg))
    end)

    -- Speed Multiplier
    RegisterCmd("dw_speed", function(params)
        local mult = tonumber(params and params[1]) or 1.0
        State.Multipliers.speedMultiplier = math.max(0.1, math.min(5.0, mult))
        print(string.format("[DawnwalkerMod] Speed Multiplier: %.1fx", State.Multipliers.speedMultiplier))
    end)

    -- Jump Multiplier
    RegisterCmd("dw_jump", function(params)
        local mult = tonumber(params and params[1]) or 1.0
        State.Multipliers.jumpMultiplier = math.max(0.1, math.min(5.0, mult))
        print(string.format("[DawnwalkerMod] Jump Multiplier: %.1fx", State.Multipliers.jumpMultiplier))
    end)

    -- Movement Modes
    RegisterCmd("dw_fly", function()
        local player = Safety.FindValid(function() return UEHelpers.GetPlayer() end)
        Movement.SetMode(player, "fly")
        print("[DawnwalkerMod] Movement Mode: FLY")
    end)

    RegisterCmd("dw_ghost", function()
        local player = Safety.FindValid(function() return UEHelpers.GetPlayer() end)
        Movement.SetMode(player, "ghost")
        print("[DawnwalkerMod] Movement Mode: GHOST")
    end)

    RegisterCmd("dw_walk", function()
        local player = Safety.FindValid(function() return UEHelpers.GetPlayer() end)
        Movement.SetMode(player, "walk")
        print("[DawnwalkerMod] Movement Mode: WALK")
    end)

    -- Teleport
    RegisterCmd("dw_teleport", function()
        local player = Safety.FindValid(function() return UEHelpers.GetPlayer() end)
        local ok, msg = Movement.Teleport(player)
        print(string.format("[DawnwalkerMod] %s", msg))
    end)

    -- Game Speed (Slomo)
    RegisterCmd("dw_slomo", function(params)
        local spd = tonumber(params and params[1]) or 1.0
        State.Multipliers.gameSpeed = math.max(0.1, math.min(4.0, spd))
        print(string.format("[DawnwalkerMod] Game Speed: %.1fx", State.Multipliers.gameSpeed))
    end)

    -- FOV Multiplier
    RegisterCmd("dw_fov", function(params)
        local fov = tonumber(params and params[1]) or 1.0
        State.Multipliers.fovMultiplier = math.max(0.1, math.min(3.0, fov))
        print(string.format("[DawnwalkerMod] FOV Multiplier: %.1fx", State.Multipliers.fovMultiplier))
    end)

    -- Damage Amplifier
    RegisterCmd("dw_damage", function(params)
        local amp = tonumber(params and params[1]) or 1.0
        State.Multipliers.damageAmplifier = math.max(1.0, math.min(20.0, amp))
        print(string.format("[DawnwalkerMod] Damage Amplifier: %.1fx", State.Multipliers.damageAmplifier))
    end)

    -- Kill Hostiles
    RegisterCmd("dw_kill", function()
        local player = Safety.FindValid(function() return UEHelpers.GetPlayer() end)
        local ok, msg = Combat.KillAllAggressive(player)
        print(string.format("[DawnwalkerMod] %s", msg))
    end)

    -- Player Level
    RegisterCmd("dw_level", function(params)
        local lvl = tonumber(params and params[1])
        if lvl then
            local ok, msg = Character.SetLevel(lvl)
            print(string.format("[DawnwalkerMod] %s", msg))
        else
            print("[DawnwalkerMod] Usage: dw_level <1-99>")
        end
    end)

    -- Level Cap
    RegisterCmd("dw_levelcap", function(params)
        local cap = tonumber(params and params[1])
        if cap then
            local ok, msg = Character.SetLevelCap(cap)
            print(string.format("[DawnwalkerMod] %s", msg))
        else
            print("[DawnwalkerMod] Usage: dw_levelcap <1-99>")
        end
    end)

    -- Grant XP
    RegisterCmd("dw_xp", function(params)
        local tier = tonumber(params and params[1]) or 5
        local ok, msg = Character.GrantXP(tier)
        print(string.format("[DawnwalkerMod] %s", msg))
    end)

    -- Trait Points
    RegisterCmd("dw_traits", function(params)
        local delta = tonumber(params and params[1])
        if delta then
            local ok, msg = Skills.AddTraitPoints(delta)
            print(string.format("[DawnwalkerMod] %s", msg))
        else
            print("[DawnwalkerMod] Usage: dw_traits <amount>")
        end
    end)

    -- Unlock / Reset Traits
    RegisterCmd("dw_unlocktraits", function()
        local ok, msg = Skills.UnlockAllTraits()
        print(string.format("[DawnwalkerMod] %s", msg))
    end)

    RegisterCmd("dw_resettraits", function()
        local ok, msg = Skills.ResetAllTraits()
        print(string.format("[DawnwalkerMod] %s", msg))
    end)

    -- Mutation Charges
    RegisterCmd("dw_mutation", function(params)
        local delta = tonumber(params and params[1])
        if delta then
            local ok, msg = Skills.AddMutationCharges(delta)
            print(string.format("[DawnwalkerMod] %s", msg))
        else
            print("[DawnwalkerMod] Usage: dw_mutation <amount>")
        end
    end)

    -- No Cooldowns
    RegisterCmd("dw_cooldowns", function(params)
        local val = params and params[1]
        if val == "1" or val == "true" or val == "on" then
            State.Toggles.noCooldowns = true
        elseif val == "0" or val == "false" or val == "off" then
            State.Toggles.noCooldowns = false
        else
            Skills.ToggleCooldowns()
        end
        print(string.format("[DawnwalkerMod] Cooldowns Disabled: %s", State.Toggles.noCooldowns and "YES" or "NO"))
    end)

    -- Time of Day
    RegisterCmd("dw_time", function(params)
        local timeStr = params and params[1] or ""
        local h, m = timeStr:match("^(%d+):(%d+)$")
        if h and m then
            local ok, msg = World.SetTime(tonumber(h), tonumber(m))
            print(string.format("[DawnwalkerMod] %s", msg))
        else
            print("[DawnwalkerMod] Usage: dw_time <HH:MM> (e.g. dw_time 12:00)")
        end
    end)

    -- Fast Travel & Map
    RegisterCmd("dw_fasttravel", function()
        local ok, msg = World.UnlockAllFastTravel()
        print(string.format("[DawnwalkerMod] %s", msg))
    end)

    RegisterCmd("dw_mappins", function()
        local ok, msg = World.RevealAllMappins()
        print(string.format("[DawnwalkerMod] %s", msg))
    end)

    -- Economy & Weight
    RegisterCmd("dw_coins", function(params)
        local amount = tonumber(params and params[1])
        if amount then
            local player = Safety.FindValid(function() return UEHelpers.GetPlayer() end)
            local ok, msg = Inventory.AddCoins(player, amount)
            print(string.format("[DawnwalkerMod] %s", msg))
        else
            print("[DawnwalkerMod] Usage: dw_coins <amount>")
        end
    end)

    RegisterCmd("dw_weight", function(params)
        local mult = tonumber(params and params[1]) or 1.0
        State.Multipliers.carryWeightMultiplier = math.max(0.1, math.min(100.0, mult))
        print(string.format("[DawnwalkerMod] Carry Weight Multiplier: %.1fx", State.Multipliers.carryWeightMultiplier))
    end)

    -- Recipes & Check
    RegisterCmd("dw_recipes", function()
        local ok, msg = Inventory.UnlockAllRecipes()
        print(string.format("[DawnwalkerMod] %s", msg))
    end)

    RegisterCmd("dw_selfcheck", function()
        local ok, msg = Inventory.SelfCheck()
        print(string.format("[DawnwalkerMod] %s", msg))
    end)

    -- Gear Granting / Removal
    RegisterCmd("dw_give", function(params)
        local gearId = params and params[1]
        local qty = tonumber(params and params[2]) or 1
        if gearId then
            local ok, msg = Granter.GiveGear(gearId, qty)
            print(string.format("[DawnwalkerMod] %s", msg))
        else
            print("[DawnwalkerMod] Usage: dw_give <gearId> [quantity]")
        end
    end)

    RegisterCmd("dw_remove", function(params)
        local gearId = params and params[1]
        if gearId then
            local ok, msg = Granter.RemoveGear(gearId)
            print(string.format("[DawnwalkerMod] %s", msg))
        else
            print("[DawnwalkerMod] Usage: dw_remove <gearId>")
        end
    end)

    -- Presets
    RegisterCmd("dw_preset", function(params)
        local action = params and params[1]
        local name = params and params[2] or "Default"
        if action == "save" then
            local ok, msg = Config.SavePreset(name)
            print(string.format("[DawnwalkerMod] %s", msg))
        elseif action == "apply" or action == "load" then
            local ok, msg = Config.ApplyPreset(name)
            print(string.format("[DawnwalkerMod] %s", msg))
        else
            print("[DawnwalkerMod] Usage: dw_preset <save|apply> <preset_name>")
        end
    end)

    print("[DawnwalkerMod] In-game console commands registered (type 'dw_menu' or 'dw_god')")
end

return Console
