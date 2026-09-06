-- features/world.lua: In-game clock, map reveal, fast-travel unlocking, and world debug overrides
local Safety = require("safety")
local State = require("state")

local World = {}

local function GetTimeSystem()
    return Safety.FindValid(function() return FindFirstOf("TimeSystemImpl") end)
end

local function GetOpenWorldJournal()
    return Safety.FindValid(function() return FindFirstOf("OpenWorldJournalImpl") end)
end

local function GetCourtSubsystem()
    return Safety.FindValid(function() return FindFirstOf("CourtSubsystem") end)
end

-- Set the in-game clock (hour 0-23, minute 0-59)
function World.SetTime(hour, minute)
    local timeSystem = GetTimeSystem()
    if not timeSystem then return false, "TimeSystemImpl not found" end
    local h = math.max(0, math.min(23, math.floor(tonumber(hour) or 12)))
    local m = math.max(0, math.min(59, math.floor(tonumber(minute) or 0)))

    local ok = pcall(function() timeSystem:SetTime(h, m, 0, true) end)
    return ok, ok and string.format("Time set to %02d:%02d", h, m) or "Failed to set time"
end

-- Advance time by N hours
function World.AdvanceTime(hours)
    local timeSystem = GetTimeSystem()
    if not timeSystem then return false, "TimeSystemImpl not found" end
    local delta = tonumber(hours) or 1.0
    local cur = State.Readouts.dayTimeHours or 12.0
    local nxt = (cur + delta) % 24.0
    local h = math.floor(nxt)
    local m = math.floor((nxt - h) * 60)
    return World.SetTime(h, m)
end

-- Unlock all fast travel points across the map
function World.UnlockAllFastTravel()
    local journal = GetOpenWorldJournal()
    if not journal then return false, "OpenWorldJournalImpl not found" end

    local libOk, lib = pcall(function()
        return StaticFindObject("/Script/DogwoodMap.Default__MappinSystemBlueprintLibrary")
    end)
    if not libOk or not lib or not Safety.SafeIsValid(lib) then
        return false, "MappinSystemBlueprintLibrary not found"
    end

    local ok = pcall(function() lib:DebugUnlockAllFastTravelDestinations(journal) end)
    return ok, ok and "All fast travel destinations unlocked" or "Failed to unlock fast travel"
end

-- Reveal all map pins / icons on the open world map
function World.RevealAllMappins()
    local journal = GetOpenWorldJournal()
    if not journal then return false, "OpenWorldJournalImpl not found" end

    local fnOk, fn = pcall(function()
        return StaticFindObject("/Script/DogwoodMap.OpenWorldJournalInterface:RevealAllMappins")
    end)
    if not fnOk or not fn or not Safety.SafeIsValid(fn) then
        return false, "RevealAllMappins function not found"
    end

    local ok = pcall(function() fn(journal) end)
    return ok, ok and "All map pins revealed" or "Failed to reveal map pins"
end

-- Override world NPC level (0 = normal scaling, 1-99 = forced level)
function World.SetNpcLevelOverride(player, level)
    if not player or not Safety.SafeIsValid(player) then return false, "Player pawn not ready" end
    local lvl = math.max(0, math.min(99, math.floor(tonumber(level) or 0)))

    local libOk, lib = pcall(function()
        return StaticFindObject("/Script/DogwoodSystem.Default__DWSystemBlueprintFunctionLibrary")
    end)
    if not libOk or not lib or not Safety.SafeIsValid(lib) then
        return false, "DWSystemBlueprintFunctionLibrary not found"
    end

    local ok = pcall(function() lib:SetNpcLevelOverride(player, lvl) end)
    return ok, ok and string.format("NPC level override set to %d", lvl) or "Failed to set NPC level override"
end

-- Set world alert level (0 to 9)
function World.SetAlertLevel(level)
    local court = GetCourtSubsystem()
    if not court then return false, "CourtSubsystem not found" end
    local lvl = math.max(0, math.min(9, math.floor(tonumber(level) or 0)))

    local ok = pcall(function() court:SetAlertLevelByInt(lvl) end)
    return ok, ok and string.format("Alert level set to %d", lvl) or "Failed to set alert level"
end

-- Periodic world tick: updates day, story deadline day, and time-of-day telemetry
function World.Tick()
    local timeSystem = GetTimeSystem()
    if timeSystem then
        local dayOk, day = pcall(function() return timeSystem:GetCurrentDay() end)
        if dayOk and day then State.Readouts.currentDay = day end

        local goalOk, goal = pcall(function() return timeSystem:GetMainGoalDay() end)
        if goalOk and goal then State.Readouts.mainGoalDay = goal end

        local timeOk, hours = pcall(function() return timeSystem:GetCurrentDayTimeAsFloat() end)
        if timeOk and hours then State.Readouts.dayTimeHours = hours end
    end
end

return World
