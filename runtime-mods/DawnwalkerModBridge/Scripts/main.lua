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

local UEHelpers = require("UEHelpers")

local COMMAND_PATH = "Mods/DawnwalkerModBridge/command.txt"
local STATUS_PATH = "Mods/DawnwalkerModBridge/status.txt"

local LastRequestId = nil

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

-- CombatComponentBase is an ActorComponent; find the one attached to the local player pawn
-- rather than FindFirstOf, which could return an AI's combat component instead.
local function GetPlayerCombatComponent()
    local playerOk, player = pcall(UEHelpers.GetPlayer)
    if not playerOk or not player or not player:IsValid() then return nil end

    local componentsOk, components = pcall(FindAllOf, "CombatComponentBase")
    if not componentsOk or not components then return nil end

    for _, component in ipairs(components) do
        if component:IsValid() then
            local ownerOk, owner = pcall(function() return component:GetOwner() end)
            if ownerOk and owner and owner:IsValid() and owner == player then
                return component
            end
        end
    end
    return nil
end

local function ApplyCommand()
    local command = ReadCommandFile()
    local status = { bridgeLoaded = 1, ok = 0 }

    if not command then
        status.commandFileFound = 0
        WriteStatusFile(status)
        return
    end
    status.commandFileFound = 1

    local settings = GetSettings()
    if settings and settings:IsValid() then
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
    if subsystem and subsystem:IsValid() then
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

    local combat = GetPlayerCombatComponent()
    if combat and combat:IsValid() then
        status.combatFound = 1
        if command.infiniteHealth == "1" then
            pcall(function() combat:SetHealthPercent(1.0) end)
        end
        if command.infiniteStamina == "1" then
            pcall(function() combat:SetStaminaPercent(1.0) end)
        end
        local hpOk, hp = pcall(function() return combat:GetHealthPercentage() end)
        local stOk, st = pcall(function() return combat:GetStaminaPercentage() end)
        status.healthPercent = hpOk and hp or "unknown"
        status.staminaPercent = stOk and st or "unknown"
    else
        status.combatFound = 0
    end

    status.ok = 1
    status.lastAppliedRequestId = LastRequestId or 0
    WriteStatusFile(status)
end

RegisterConsoleCommandHandler("dwbridge_apply", function()
    pcall(ApplyCommand)
    return true
end)

local loopStarted = pcall(function()
    LoopAsync(1000, function()
        pcall(ApplyCommand)
        return false
    end)
end)

if not loopStarted then
    print("[DawnwalkerModBridge] LoopAsync unavailable; use console command 'dwbridge_apply' to poll manually")
end

pcall(ApplyCommand)
print("[DawnwalkerModBridge] Loaded. Watching " .. COMMAND_PATH)
