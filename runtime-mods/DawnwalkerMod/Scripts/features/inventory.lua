-- features/inventory.lua: Economy (coins), carry weight scaling, recipe unlocking, and reflection diagnostics
local Safety = require("safety")
local State = require("state")

local Inventory = {}

local ITEM_NAME_DUMP_CLASSES = {
    "ItemConsumableDataAsset",
    "ItemIngredientDataAsset",
    "ItemWeaponDataAsset",
    "ItemClothingDataAsset",
}

local SELF_CHECK_CLASSES = {
    "DogwoodCharacterDevelopmentSettings",
    "CharacterDevelopmentSubsystem",
    "CombatSubsystem",
    "RebelAISubsystem",
    "TimeSystemImpl",
    "CraftingSubsystem",
    "OpenWorldJournalImpl",
    "CourtSubsystem",
    "PlayerCameraManager",
    "CheatManager",
    "UIManagerSubsystem",
    "HUDManagerSubsystem",
    "BloodBarComponent",
}

local SELF_CHECK_OBJECTS = {
    "/Script/DogwoodMap.Default__MappinSystemBlueprintLibrary",
    "/Script/DogwoodMap.OpenWorldJournalInterface:RevealAllMappins",
    "/Script/DogwoodSystem.Default__DWSystemBlueprintFunctionLibrary",
    "/Game/_Dawnwalker/Abilities/Player/GE_Invulnerability.GE_Invulnerability_C",
}

local function GetPlayerInventory(player)
    return Safety.FindOwnedComponent("InventoryComponent", player)
end

local function GetCraftingSubsystem()
    return Safety.FindValid(function() return FindFirstOf("CraftingSubsystem") end)
end

-- Add or remove currency (coins)
function Inventory.AddCoins(player, amount)
    local inv = GetPlayerInventory(player)
    if not inv then return false, "InventoryComponent not found" end
    local delta = math.floor(tonumber(amount) or 0)
    if delta == 0 then return false, "Amount cannot be 0" end

    local ok = pcall(function() inv:AddCurrency(0, delta) end)
    return ok, ok and string.format("Coins adjusted by %+d", delta) or "Failed to modify coins"
end

-- Unlock all crafting recipes
function Inventory.UnlockAllRecipes()
    local crafting = GetCraftingSubsystem()
    if not crafting then return false, "CraftingSubsystem not found" end

    local ok = pcall(function() crafting:UnlockAllCraftingRecipes() end)
    return ok, ok and "All crafting recipes unlocked" or "Failed to unlock crafting recipes"
end

-- Inspect loaded item data assets and dump newly seen localized names to UE4SS.log
function Inventory.DumpNewItemNames()
    local count = 0
    for _, className in ipairs(ITEM_NAME_DUMP_CLASSES) do
        local listOk, assets = pcall(FindAllOf, className)
        if listOk and assets then
            for _, asset in ipairs(assets) do
                if Safety.SafeIsValid(asset) then
                    local pathOk, fullName = pcall(function() return asset:GetFullName() end)
                    if pathOk and fullName and not State.Internal.LoggedItemNames[fullName] then
                        local textOk, text = pcall(function() return asset.ItemName end)
                        local label = textOk and tostring(text) or nil
                        if label and #label > 0 and not label:match("^%s*$") then
                            State.Internal.LoggedItemNames[fullName] = true
                            State.Internal.LoggedItemNameCount = State.Internal.LoggedItemNameCount + 1
                            count = count + 1
                            print(string.format("[DawnwalkerMod] ItemName: %s = %s", tostring(fullName), label))
                        end
                    end
                end
            end
        end
    end
    return count
end

-- Compatibility check: verifies every engine class and reflection target
function Inventory.SelfCheck()
    local missing = {}
    local total = 0

    for _, className in ipairs(SELF_CHECK_CLASSES) do
        total = total + 1
        local ok, obj = pcall(FindFirstOf, className)
        if not ok or not obj or not Safety.SafeIsValid(obj) then
            table.insert(missing, "class " .. className)
        end
    end

    for _, path in ipairs(SELF_CHECK_OBJECTS) do
        total = total + 1
        local ok, obj = pcall(function() return StaticFindObject(path) end)
        if not ok or not obj then
            table.insert(missing, path)
        end
    end

    print(string.format("[DawnwalkerMod] SelfCheck: %d checked, %d missing", total, #missing))
    for _, miss in ipairs(missing) do
        print("[DawnwalkerMod] Missing reflection target: " .. miss)
    end

    if #missing == 0 then
        return true, string.format("All %d reflection targets verified successfully", total)
    else
        return false, string.format("%d of %d targets missing (%s)", #missing, total, table.concat(missing, ", "):sub(1, 200))
    end
end

-- Periodic inventory tick: updates coin and weight telemetry, enforces carry weight multiplier
function Inventory.Tick(player)
    local inv = GetPlayerInventory(player)
    if inv then
        State.Readouts.inventoryFound = true

        -- Coins
        local coinsOk, coins = pcall(function() return inv:GetCurrencyAmount(0) end)
        if coinsOk and coins then State.Readouts.coins = coins end

        -- Carry weight telemetry
        local wtOk, wt = pcall(function() return inv:GetCurrentWeight() end)
        if wtOk and wt then State.Readouts.carryWeight = wt end

        -- Carry weight limit scaling
        local baseLimit = State.GetBaseValue("weightLimit", inv, "WeightLimit")
        if baseLimit then
            local mult = State.Multipliers.carryWeightMultiplier or 1.0
            pcall(function() inv.WeightLimit = baseLimit * mult end)
        end

        local limitOk, limit = pcall(function() return inv:GetWeightLimit() end)
        if limitOk and limit then State.Readouts.carryWeightLimit = limit end
    else
        State.Readouts.inventoryFound = false
    end
end

return Inventory
