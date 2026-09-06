-- state.lua: In-memory mod state, configuration, and base-value caching
local State = {}

-- Active feature toggles
State.Toggles = {
    infiniteHealth = false,
    infiniteStamina = false,
    infiniteBlood = false,
    noCooldowns = false,
    keepActionSlotsCharged = false,
}

-- Active multiplier settings
State.Multipliers = {
    speedMultiplier = 1.0,
    jumpMultiplier = 1.0,
    fovMultiplier = 1.0,
    gameSpeed = 1.0,
    damageAmplifier = 1.0,
    carryWeightMultiplier = 1.0,
}

-- Gameplay adjustments
State.Gameplay = {
    levelCap = 99,
    actionDifficulty = 1, -- 0=Story, 1=Normal, 2=Immersive, 3=Hard
    rpgDifficulty = 1,
    movementMode = "walk", -- "walk", "fly", "ghost"
}

-- Cached original game values to prevent compounding multipliers
State.BaseValues = {
    walkSpeed = nil,
    jumpZ = nil,
    fov = nil,
    weightLimit = nil,
}

-- Internal tracking states
State.Internal = {
    AmpHealth = {},
    LastAmplifiedCount = 0,
    WasHealthInvulnerable = false,
    WasGodModeApplied = false,
    WasNativeGodModeApplied = false,
    WasBloodLocked = false,
    WasActionSlotsOverridden = false,
    CooldownsDisabledByUs = false,
    OriginalActionDifficulty = nil,
    OriginalLevelCap = nil,
    LastAppliedMovementMode = nil,
    LastAppliedRPGDifficulty = nil,
    LastAppliedGameSpeed = nil,
    LoggedItemNames = {},
    LoggedItemNameCount = 0,
    AmpLoopLastPawnAddress = nil,
    AmpLoopSettleTicks = 0,
    MenuScanDone = false,
    LastActionResult = "None",
}

-- Live telemetry readouts from the game
State.Readouts = {
    playerFound = false,
    combatFound = false,
    movementFound = false,
    inventoryFound = false,
    currentLevel = 1,
    currentXP = 0,
    xpRequirement = 0,
    levelCap = 99,
    traitPoints = 0,
    mutationCharges = 0,
    mutationLevel = 0,
    coins = 0,
    carryWeight = 0,
    carryWeightLimit = 0,
    currentDay = 1,
    mainGoalDay = 30,
    dayTimeHours = 12.0,
    inCombat = false,
    aggressiveNpcCount = 0,
    healthPercent = 1.0,
    staminaPercent = 1.0,
    bloodPercent = 1.0,
    cooldownsDisabled = false,
}

-- Helper to safely get base values once
function State.GetBaseValue(cacheKey, object, propertyName)
    if State.BaseValues[cacheKey] == nil then
        local ok, value = pcall(function() return object[propertyName] end)
        if ok and value ~= nil and value > 0 then
            State.BaseValues[cacheKey] = value
        end
    end
    return State.BaseValues[cacheKey]
end

-- Reset per-pawn base values when player respawns (FOV survives respawn)
function State.ResetPawnBases()
    State.BaseValues.walkSpeed = nil
    State.BaseValues.jumpZ = nil
    State.BaseValues.weightLimit = nil
    State.Internal.WasHealthInvulnerable = false
    State.Internal.WasGodModeApplied = false
    State.Internal.WasNativeGodModeApplied = false
    State.Internal.WasBloodLocked = false
    State.Internal.WasActionSlotsOverridden = false
    State.Internal.AmpHealth = {}
    State.Internal.LastAppliedMovementMode = nil
    State.Internal.LastAppliedRPGDifficulty = nil
end

-- Reset all mod settings back to vanilla defaults
function State.ResetToDefaults()
    State.Toggles.infiniteHealth = false
    State.Toggles.infiniteStamina = false
    State.Toggles.infiniteBlood = false
    State.Toggles.noCooldowns = false
    State.Toggles.keepActionSlotsCharged = false

    State.Multipliers.speedMultiplier = 1.0
    State.Multipliers.jumpMultiplier = 1.0
    State.Multipliers.fovMultiplier = 1.0
    State.Multipliers.gameSpeed = 1.0
    State.Multipliers.damageAmplifier = 1.0
    State.Multipliers.carryWeightMultiplier = 1.0

    State.Gameplay.levelCap = 99
    State.Gameplay.movementMode = "walk"
    State.Gameplay.actionDifficulty = State.Internal.OriginalActionDifficulty or 1
    State.Gameplay.rpgDifficulty = 1
end

return State
