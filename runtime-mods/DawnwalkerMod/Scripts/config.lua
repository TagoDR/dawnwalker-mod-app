-- config.lua: User settings, presets manager, and keybind preferences
local State = require("state")

local Config = {}
local PRESETS_FILE = "Mods/DawnwalkerMod/presets.txt"

-- Save the current active settings as a named preset
function Config.SavePreset(name)
    if not name or #name == 0 then return false, "Preset name cannot be empty" end
    local presets = Config.LoadAllPresets()
    presets[name] = {
        infiniteHealth = State.Toggles.infiniteHealth,
        infiniteStamina = State.Toggles.infiniteStamina,
        infiniteBlood = State.Toggles.infiniteBlood,
        noCooldowns = State.Toggles.noCooldowns,
        keepActionSlotsCharged = State.Toggles.keepActionSlotsCharged,
        speedMultiplier = State.Multipliers.speedMultiplier,
        jumpMultiplier = State.Multipliers.jumpMultiplier,
        fovMultiplier = State.Multipliers.fovMultiplier,
        gameSpeed = State.Multipliers.gameSpeed,
        damageAmplifier = State.Multipliers.damageAmplifier,
        carryWeightMultiplier = State.Multipliers.carryWeightMultiplier,
        levelCap = State.Gameplay.levelCap,
        actionDifficulty = State.Gameplay.actionDifficulty,
        rpgDifficulty = State.Gameplay.rpgDifficulty,
        movementMode = State.Gameplay.movementMode,
    }

    local f = io.open(PRESETS_FILE, "w")
    if not f then return false, "Failed to open presets file for writing" end

    for pName, pData in pairs(presets) do
        f:write(string.format("[preset:%s]\n", pName))
        for k, v in pairs(pData) do
            f:write(string.format("%s=%s\n", k, tostring(v)))
        end
    end
    f:close()
    return true, string.format("Preset '%s' saved successfully", name)
end

-- Apply a saved preset to live state
function Config.ApplyPreset(name)
    local presets = Config.LoadAllPresets()
    local pData = presets[name]
    if not pData then return false, string.format("Preset '%s' not found", name) end

    if pData.infiniteHealth ~= nil then State.Toggles.infiniteHealth = (pData.infiniteHealth == "true" or pData.infiniteHealth == true) end
    if pData.infiniteStamina ~= nil then State.Toggles.infiniteStamina = (pData.infiniteStamina == "true" or pData.infiniteStamina == true) end
    if pData.infiniteBlood ~= nil then State.Toggles.infiniteBlood = (pData.infiniteBlood == "true" or pData.infiniteBlood == true) end
    if pData.noCooldowns ~= nil then State.Toggles.noCooldowns = (pData.noCooldowns == "true" or pData.noCooldowns == true) end
    if pData.keepActionSlotsCharged ~= nil then State.Toggles.keepActionSlotsCharged = (pData.keepActionSlotsCharged == "true" or pData.keepActionSlotsCharged == true) end

    if pData.speedMultiplier then State.Multipliers.speedMultiplier = tonumber(pData.speedMultiplier) or 1.0 end
    if pData.jumpMultiplier then State.Multipliers.jumpMultiplier = tonumber(pData.jumpMultiplier) or 1.0 end
    if pData.fovMultiplier then State.Multipliers.fovMultiplier = tonumber(pData.fovMultiplier) or 1.0 end
    if pData.gameSpeed then State.Multipliers.gameSpeed = tonumber(pData.gameSpeed) or 1.0 end
    if pData.damageAmplifier then State.Multipliers.damageAmplifier = tonumber(pData.damageAmplifier) or 1.0 end
    if pData.carryWeightMultiplier then State.Multipliers.carryWeightMultiplier = tonumber(pData.carryWeightMultiplier) or 1.0 end

    if pData.levelCap then State.Gameplay.levelCap = tonumber(pData.levelCap) or 99 end
    if pData.actionDifficulty then State.Gameplay.actionDifficulty = tonumber(pData.actionDifficulty) or 1 end
    if pData.rpgDifficulty then State.Gameplay.rpgDifficulty = tonumber(pData.rpgDifficulty) or 1 end
    if pData.movementMode then State.Gameplay.movementMode = pData.movementMode end

    return true, string.format("Applied preset '%s'", name)
end

-- Read all presets from file
function Config.LoadAllPresets()
    local f = io.open(PRESETS_FILE, "r")
    if not f then return {} end

    local presets = {}
    local currentPreset = nil

    for line in f:lines() do
        local pName = line:match("^%[preset:(.+)%]$")
        if pName then
            currentPreset = pName
            presets[currentPreset] = {}
        elseif currentPreset then
            local k, v = line:match("^(%w+)=(.-)%s*$")
            if k then
                presets[currentPreset][k] = v
            end
        end
    end
    f:close()
    return presets
end

return Config
