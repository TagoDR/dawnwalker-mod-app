-- features/character.lua: Player level, XP granting, and level cap management
local Safety = require("safety")
local State = require("state")

local Character = {}

local function GetSubsystem()
    return Safety.FindValid(function() return FindFirstOf("CharacterDevelopmentSubsystem") end)
end

local function GetSettings()
    return Safety.FindValid(function() return FindFirstOf("DogwoodCharacterDevelopmentSettings") end)
end

-- Force player level (clamped 1-99; levels >99 exceed engine tables and crash)
function Character.SetLevel(targetLevel)
    local subsystem = GetSubsystem()
    if not subsystem then return false, "CharacterDevelopmentSubsystem not found" end
    local lvl = math.floor(tonumber(targetLevel) or 1)
    if lvl < 1 or lvl > 99 then return false, "Level must be between 1 and 99" end

    local ok = pcall(function() subsystem:ForceLevelUpTo(lvl, true) end)
    return ok, ok and string.format("Level set to %d", lvl) or "Failed to set level"
end

-- Set the maximum level cap
function Character.SetLevelCap(cap)
    local settings = GetSettings()
    if not settings then return false, "DogwoodCharacterDevelopmentSettings not found" end
    local c = math.floor(tonumber(cap) or 99)
    if c < 1 or c > 99 then return false, "Level cap must be between 1 and 99" end

    if State.Internal.OriginalLevelCap == nil then
        local origOk, orig = pcall(function() return settings.LevelCap end)
        if origOk and type(orig) == "number" then State.Internal.OriginalLevelCap = orig end
    end

    local ok = pcall(function() settings.LevelCap = c end)
    if ok then State.Gameplay.levelCap = c end
    return ok, ok and string.format("Level cap set to %d", c) or "Failed to set level cap"
end

-- Grant quest experience reward tier (1=Very Small to 5=Very Large)
function Character.GrantXP(tier)
    local subsystem = GetSubsystem()
    if not subsystem then return false, "CharacterDevelopmentSubsystem not found" end
    local t = math.floor(tonumber(tier) or 5)
    if t < 1 or t > 5 then return false, "Reward tier must be between 1 and 5" end

    local ok, amount = pcall(function() return subsystem:AddQuestXP(t) end)
    return ok, ok and string.format("Granted quest XP reward (tier %d)", t) or "Failed to grant XP"
end

-- Periodic character tick: updates level telemetry and enforces persistent level cap
function Character.Tick()
    local settings = GetSettings()
    if settings then
        if State.Gameplay.levelCap then
            pcall(function() settings.LevelCap = math.floor(State.Gameplay.levelCap) end)
        end
        local capOk, cap = pcall(function() return settings.LevelCap end)
        if capOk and cap then State.Readouts.levelCap = cap end
    end

    local subsystem = GetSubsystem()
    if subsystem then
        local lvlOk, lvl = pcall(function() return subsystem:GetCurrentLevel() end)
        if lvlOk and lvl then State.Readouts.currentLevel = lvl end

        local xpOk, xp = pcall(function() return subsystem:GetCurrentXP() end)
        if xpOk and xp then State.Readouts.currentXP = xp end

        if lvlOk and type(lvl) == "number" then
            local reqOk, req = pcall(function() return subsystem:GetCurrentLevelXPRequirement(lvl) end)
            if reqOk and req then State.Readouts.xpRequirement = req end
        end
    end
end

return Character
