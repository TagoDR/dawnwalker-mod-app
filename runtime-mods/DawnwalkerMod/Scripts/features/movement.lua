-- features/movement.lua: Speed, jump, movement modes (fly/ghost), FOV, teleport, and game speed
local Safety = require("safety")
local State = require("state")

local Movement = {}

local function GetMovementComponent(player)
    return Safety.FindOwnedComponent("CharacterMovementComponent", player)
end

local function GetCameraManager()
    return Safety.FindValid(function() return FindFirstOf("PlayerCameraManager") end)
end

local function GetCheatManager()
    return Safety.FindValid(function() return FindFirstOf("CheatManager") end)
end

-- Teleport to player crosshair / aim point
function Movement.Teleport(player)
    local cheat = GetCheatManager()
    if not cheat then return false, "CheatManager not found" end
    local ok = pcall(function() cheat:Teleport() end)
    return ok, ok and "Teleported to aim point" or "Teleport failed"
end

-- Cycle movement mode: walk -> fly -> ghost -> walk
function Movement.CycleMode(player)
    local cur = State.Gameplay.movementMode or "walk"
    local nxt = "walk"
    if cur == "walk" then nxt = "fly"
    elseif cur == "fly" then nxt = "ghost"
    else nxt = "walk" end
    Movement.SetMode(player, nxt)
    return nxt
end

-- Set movement mode explicitly
function Movement.SetMode(player, mode)
    State.Gameplay.movementMode = mode
    local cheat = GetCheatManager()
    if cheat then
        pcall(function()
            if mode == "fly" then cheat:Fly()
            elseif mode == "ghost" then cheat:Ghost()
            else cheat:Walk() end
        end)
        State.Internal.LastAppliedMovementMode = mode
    end
end

-- Periodic movement tick: applies speed, jump, FOV, movement modes, and game speed
function Movement.Tick(player, movementSettling)
    -- Camera FOV (Camera manager survives respawn)
    local camera = GetCameraManager()
    if camera then
        local baseFov = State.GetBaseValue("fov", camera, "DefaultFOV")
        if baseFov then
            local targetFov = baseFov * (State.Multipliers.fovMultiplier or 1.0)
            targetFov = math.max(10.0, math.min(170.0, targetFov))
            pcall(function() camera.DefaultFOV = targetFov end)
        end
    end

    -- Game Speed (Slomo)
    local cheat = GetCheatManager()
    if cheat then
        local speed = State.Multipliers.gameSpeed or 1.0
        if speed ~= State.Internal.LastAppliedGameSpeed then
            pcall(function() cheat:Slomo(speed) end)
            State.Internal.LastAppliedGameSpeed = speed
        end

        -- Persistent Movement Mode
        local mode = State.Gameplay.movementMode or "walk"
        if mode ~= State.Internal.LastAppliedMovementMode then
            pcall(function()
                if mode == "fly" then cheat:Fly()
                elseif mode == "ghost" then cheat:Ghost()
                else cheat:Walk() end
            end)
            State.Internal.LastAppliedMovementMode = mode
        end
    end

    -- Skip per-pawn CharacterMovementComponent while settling after respawn
    if movementSettling or not player or not Safety.SafeIsValid(player) then
        State.Readouts.movementFound = false
        return
    end

    local movement = GetMovementComponent(player)
    if movement then
        State.Readouts.movementFound = true

        -- Walk Speed Multiplier
        local baseSpeed = State.GetBaseValue("walkSpeed", movement, "MaxWalkSpeed")
        if baseSpeed then
            local mult = State.Multipliers.speedMultiplier or 1.0
            pcall(function() movement.MaxWalkSpeed = baseSpeed * mult end)
        end

        -- Jump Multiplier
        local baseJump = State.GetBaseValue("jumpZ", movement, "JumpZVelocity")
        if baseJump then
            local mult = State.Multipliers.jumpMultiplier or 1.0
            pcall(function() movement.JumpZVelocity = baseJump * mult end)
        end
    else
        State.Readouts.movementFound = false
    end
end

return Movement
