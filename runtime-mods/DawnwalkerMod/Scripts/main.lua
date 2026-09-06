-- DawnwalkerMod: Complete In-Engine Mod for The Blood of the Dawnwalker
-- Pure UE4SS Lua Mod: No Electron, no external binaries, zero disk file I/O latency.
local UEHelpers = require("UEHelpers")
local Safety = require("safety")
local State = require("state")
local Combat = require("features.combat")
local Character = require("features.character")
local Movement = require("features.movement")
local Skills = require("features.skills")
local World = require("features.world")
local Inventory = require("features.inventory")
local Menu = require("ui.hud_menu")
local Keybinds = require("ui.keybinds")
local Console = require("ui.console")
local Config = require("config")

print("================================================================")
print("[DawnwalkerMod] Initializing Pure In-Engine Mod (UE4SS)...")
print("================================================================")

-- Hook Unreal Engine HUD rendering for the Canvas/HUD mod menu
pcall(function()
    RegisterHook("/Script/Engine.HUD:ReceiveDrawHUD", function(Context)
        local ok, hud = pcall(function() return Context:get() end)
        if ok and hud and Safety.SafeIsValid(hud) then
            local canvasOk, canvas = pcall(function() return hud.Canvas end)
            if canvasOk and canvas and Safety.SafeIsValid(canvas) then
                Menu.Render(canvas)
            end
        end
    end)
    print("[DawnwalkerMod] Hooked HUD ReceiveDrawHUD for in-game menu rendering")
end)

-- Main 1-second tick loop: updates telemetry and applies persistent gameplay settings
local function StartMainTickLoop()
    pcall(function()
        LoopAsync(1000, function()
            local loopOk, loopErr = pcall(function()
                -- Refresh player pawn and settle windows
                local player = Safety.RefreshPawnSettleState(function(newPlayer)
                    State.ResetPawnBases()
                    print("[DawnwalkerMod] Player pawn changed/respawned; settle window active")
                end)

                local inWorld = (player ~= nil and Safety.SafeIsValid(player))
                State.Readouts.playerFound = inWorld

                -- Stand down during cutscenes and dialogues
                if inWorld and Safety.IsCutsceneActive(player) then
                    Safety.CutsceneActive = true
                    return
                end
                if Safety.CutsceneActive then
                    Safety.CutsceneActive = false
                    Safety.CombatSettleTicksRemaining = math.max(Safety.CombatSettleTicksRemaining, 3)
                    Safety.MovementSettleTicksRemaining = math.max(Safety.MovementSettleTicksRemaining, 3)
                end

                local combatSettling = (Safety.CombatSettleTicksRemaining > 0)
                local movementSettling = (Safety.MovementSettleTicksRemaining > 0)

                -- Tick each feature module
                Combat.Tick(player, combatSettling)
                Character.Tick()
                Movement.Tick(player, movementSettling)
                Skills.Tick(player)
                World.Tick()
                Inventory.Tick(player)

                -- Passive item-name capture when in-game inventory/menu is open
                if inWorld then
                    local menuOpen = Safety.IsMenuOpen()
                    if menuOpen and not State.Internal.MenuScanDone then
                        State.Internal.MenuScanDone = true
                        local found = Inventory.DumpNewItemNames()
                        if found > 0 then
                            print(string.format("[DawnwalkerMod] Passive scan captured %d new item names", found))
                        end
                    elseif not menuOpen then
                        State.Internal.MenuScanDone = false
                    end
                end
            end)

            if not loopOk then
                print(string.format("[DawnwalkerMod] Main loop error: %s", tostring(loopErr)))
            end
            return false -- Keep async loop alive
        end)
    end)
end

-- Dedicated 100ms fast loop for reactive damage amplification
local function StartDamageAmplifierLoop()
    pcall(function()
        LoopAsync(100, function()
            local loopOk, loopErr = pcall(function()
                local multiplier = State.Multipliers.damageAmplifier or 1.0
                if multiplier <= 1.0 then
                    if next(State.Internal.AmpHealth) ~= nil then State.Internal.AmpHealth = {} end
                    return
                end

                if Safety.CutsceneActive then return end

                local playerOk, player = pcall(UEHelpers.GetPlayer)
                if not playerOk or not player or not Safety.SafeIsValid(player) then
                    State.Internal.AmpLoopLastPawnAddress = nil
                    return
                end

                local addrOk, addr = pcall(function() return player:GetAddress() end)
                if not addrOk then return end

                if addr ~= State.Internal.AmpLoopLastPawnAddress then
                    State.Internal.AmpLoopLastPawnAddress = addr
                    State.Internal.AmpLoopSettleTicks = 30
                    if next(State.Internal.AmpHealth) ~= nil then State.Internal.AmpHealth = {} end
                    return
                end

                if State.Internal.AmpLoopSettleTicks > 0 then
                    State.Internal.AmpLoopSettleTicks = State.Internal.AmpLoopSettleTicks - 1
                    return
                end

                State.Internal.LastAmplifiedCount = Combat.AmplifyDamageToAggressiveNPCs(player, multiplier)
            end)

            if not loopOk then
                print(string.format("[DawnwalkerMod] Damage amplifier loop error: %s", tostring(loopErr)))
            end
            return false -- Keep async loop alive
        end)
    end)
end

-- Initialize Keybinds and Console Commands
Keybinds.Init()
Console.Init()

-- Start Loops
StartMainTickLoop()
StartDamageAmplifierLoop()

print("================================================================")
print("[DawnwalkerMod] Successfully loaded!")
print("  Press [F1] to toggle the in-game mod menu")
print("  Use [NumPad 1-9] for instant cheat toggles")
print("  Type 'dw_menu' or 'dw_god' in the UE console (~ key)")
print("================================================================")
