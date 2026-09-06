-- gear/granter.lua: Dispatches gear granting and removal to DawnwalkerNativeFix
local Granter = {}

local RequestCounter = 0
local NATIVE_COMMAND_PATH = "Mods/DawnwalkerNativeFix/command.txt"
local NATIVE_STATUS_PATH = "Mods/DawnwalkerNativeFix/status.txt"
local MAX_QUANTITY = 99

-- Grant a gear item, armor set, consumable, or ingredient
function Granter.GiveGear(gearId, quantity)
    if not gearId or type(gearId) ~= "string" or #gearId == 0 then
        return false, "Invalid gear ID"
    end

    local qty = math.max(1, math.min(MAX_QUANTITY, math.floor(tonumber(quantity) or 1)))
    RequestCounter = RequestCounter + 1

    -- 1. Try writing directly to native fix command file (supported by precompiled DLL)
    local f = io.open(NATIVE_COMMAND_PATH, "w")
    if f then
        f:write(string.format("requestId=%d\ngiveGearId=%s\ngiveGearQty=%d\n", RequestCounter, gearId, qty))
        f:close()
        return true, string.format("Grant request sent (x%d: %s)", qty, gearId)
    end

    -- 2. Fallback: try executing console command if native fix registers one
    local cmdOk = pcall(function()
        ExecuteConsoleCommand(string.format("dw_give %s %d", gearId, qty))
    end)
    if cmdOk then
        return true, string.format("Console command dw_give sent for %s", gearId)
    end

    return false, "Failed to reach DawnwalkerNativeFix (is the mod enabled in mods.txt?)"
end

-- Remove a specific gear item duplicate or sweep all granted gear
function Granter.RemoveGear(gearId)
    if not gearId or type(gearId) ~= "string" or #gearId == 0 then
        return false, "Invalid gear ID"
    end

    RequestCounter = RequestCounter + 1

    local f = io.open(NATIVE_COMMAND_PATH, "w")
    if f then
        f:write(string.format("requestId=%d\nremoveGearId=%s\n", RequestCounter, gearId))
        f:close()
        return true, string.format("Removal request sent for %s", gearId)
    end

    local cmdOk = pcall(function()
        ExecuteConsoleCommand(string.format("dw_remove %s", gearId))
    end)
    if cmdOk then
        return true, string.format("Console command dw_remove sent for %s", gearId)
    end

    return false, "Failed to reach DawnwalkerNativeFix"
end

-- Read the last status output written by DawnwalkerNativeFix
function Granter.GetStatus()
    local f = io.open(NATIVE_STATUS_PATH, "r")
    if not f then return nil end
    local status = {}
    for line in f:lines() do
        local k, v = line:match("^(%w+)=(.-)%s*$")
        if k then status[k] = v end
    end
    f:close()
    return status
end

return Granter
