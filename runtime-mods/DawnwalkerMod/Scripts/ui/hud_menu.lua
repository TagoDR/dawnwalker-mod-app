-- ui/hud_menu.lua: Interactive in-game Canvas/HUD menu rendered directly in Unreal Engine
local Safety = require("safety")
local State = require("state")
local Combat = require("features.combat")
local Character = require("features.character")
local Movement = require("features.movement")
local Skills = require("features.skills")
local World = require("features.world")
local Inventory = require("features.inventory")
local Granter = require("gear.granter")
local Catalog = require("gear.catalog")
local Config = require("config")

local Menu = {}

Menu.IsOpen = false
Menu.ActiveTab = 1 -- 1: Combat, 2: Character, 3: Movement, 4: Skills, 5: World, 6: Gear, 7: Presets
Menu.SelectedRow = 1
Menu.GearCategoryIndex = 1
Menu.GearItemIndex = 1
Menu.GearQuantity = 1
Menu.StatusMessage = "Press [F1] to close | [Arrows] Navigate | [Enter] Select"
Menu.MessageTimer = 0

local TABS = { "Combat", "Character", "Movement", "Skills", "World", "Gear & Items", "Presets" }
Menu.Tabs = TABS

-- Colors (Linear RGBA)
local COLOR_BG = { R = 0.04, G = 0.04, B = 0.06, A = 0.94 }
local COLOR_BORDER = { R = 0.78, G = 0.63, B = 0.32, A = 1.0 } -- Antique Gold
local COLOR_BORDER_DIM = { R = 0.35, G = 0.30, B = 0.20, A = 0.8 }
local COLOR_TEXT = { R = 0.92, G = 0.92, B = 0.92, A = 1.0 }
local COLOR_TEXT_DIM = { R = 0.60, G = 0.60, B = 0.60, A = 1.0 }
local COLOR_GOLD = { R = 0.95, G = 0.78, B = 0.35, A = 1.0 }
local COLOR_ACTIVE = { R = 0.85, G = 0.25, B = 0.25, A = 1.0 } -- Crimson
local COLOR_SELECT_BG = { R = 0.25, G = 0.22, B = 0.15, A = 0.8 }

function Menu.SetMessage(text)
    Menu.StatusMessage = text
    Menu.MessageTimer = 8
end

function Menu.Toggle()
    Menu.IsOpen = not Menu.IsOpen
    local player = Safety.FindValid(function() return UEHelpers.GetPlayer() end)
    if player then
        local pc = player.Controller
        if pc and Safety.SafeIsValid(pc) then
            pcall(function()
                pc.bShowMouseCursor = Menu.IsOpen
                pc.bEnableClickEvents = Menu.IsOpen
                pc.bEnableMouseOverEvents = Menu.IsOpen
            end)
        end
    end
end

-- Navigate up/down in current tab
function Menu.Navigate(delta)
    if not Menu.IsOpen then return end
    Menu.SelectedRow = Menu.SelectedRow + delta
    if Menu.SelectedRow < 1 then Menu.SelectedRow = 1 end
end

-- Navigate left/right (adjust sliders / change options)
function Menu.Adjust(delta)
    if not Menu.IsOpen then return end
    local tab = Menu.ActiveTab

    if tab == 1 then -- Combat
        if Menu.SelectedRow == 6 then -- Damage Amplifier
            State.Multipliers.damageAmplifier = math.max(1.0, math.min(20.0, (State.Multipliers.damageAmplifier or 1.0) + delta * 0.5))
            Menu.SetMessage(string.format("Damage Amplifier: %.1fx", State.Multipliers.damageAmplifier))
        elseif Menu.SelectedRow == 7 then -- Combat Difficulty
            local cur = State.Gameplay.actionDifficulty or 1
            State.Gameplay.actionDifficulty = math.max(0, math.min(3, cur + delta))
            local names = { [0] = "Story", [1] = "Normal", [2] = "Immersive", [3] = "Hard" }
            Menu.SetMessage("Combat Difficulty: " .. (names[State.Gameplay.actionDifficulty] or "Custom"))
        elseif Menu.SelectedRow == 8 then -- RPG Difficulty
            local cur = State.Gameplay.rpgDifficulty or 1
            State.Gameplay.rpgDifficulty = math.max(0, math.min(3, cur + delta))
            local names = { [0] = "Story", [1] = "Normal", [2] = "Immersive", [3] = "Hard" }
            Menu.SetMessage("RPG Difficulty: " .. (names[State.Gameplay.rpgDifficulty] or "Custom"))
        end

    elseif tab == 2 then -- Character
        if Menu.SelectedRow == 1 then -- Level
            local player = Safety.FindValid(function() return UEHelpers.GetPlayer() end)
            local cur = State.Readouts.currentLevel or 1
            local nxt = math.max(1, math.min(99, cur + delta))
            Character.SetLevel(nxt)
            Menu.SetMessage("Level: " .. nxt)
        elseif Menu.SelectedRow == 2 then -- Level Cap
            local cur = State.Gameplay.levelCap or 99
            local nxt = math.max(1, math.min(99, cur + delta))
            Character.SetLevelCap(nxt)
            Menu.SetMessage("Level Cap: " .. nxt)
        elseif Menu.SelectedRow == 3 then -- XP Grant
            local tiers = { "Very Small (1)", "Small (2)", "Medium (3)", "Large (4)", "Very Large (5)" }
            Menu.XpTier = math.max(1, math.min(5, (Menu.XpTier or 5) + delta))
            Menu.SetMessage("XP Reward Size: " .. tiers[Menu.XpTier])
        end

    elseif tab == 3 then -- Movement
        if Menu.SelectedRow == 1 then -- Speed Multiplier
            State.Multipliers.speedMultiplier = math.max(0.1, math.min(5.0, (State.Multipliers.speedMultiplier or 1.0) + delta * 0.1))
            Menu.SetMessage(string.format("Speed: %.1fx", State.Multipliers.speedMultiplier))
        elseif Menu.SelectedRow == 2 then -- Jump Multiplier
            State.Multipliers.jumpMultiplier = math.max(0.1, math.min(5.0, (State.Multipliers.jumpMultiplier or 1.0) + delta * 0.1))
            Menu.SetMessage(string.format("Jump: %.1fx", State.Multipliers.jumpMultiplier))
        elseif Menu.SelectedRow == 3 then -- Movement Mode
            local player = Safety.FindValid(function() return UEHelpers.GetPlayer() end)
            local mode = Movement.CycleMode(player)
            Menu.SetMessage("Movement Mode: " .. mode:upper())
        elseif Menu.SelectedRow == 5 then -- FOV Multiplier
            State.Multipliers.fovMultiplier = math.max(0.1, math.min(3.0, (State.Multipliers.fovMultiplier or 1.0) + delta * 0.1))
            Menu.SetMessage(string.format("FOV: %.1fx", State.Multipliers.fovMultiplier))
        elseif Menu.SelectedRow == 6 then -- Game Speed
            State.Multipliers.gameSpeed = math.max(0.1, math.min(4.0, (State.Multipliers.gameSpeed or 1.0) + delta * 0.1))
            Menu.SetMessage(string.format("Game Speed: %.1fx", State.Multipliers.gameSpeed))
        end

    elseif tab == 4 then -- Skills
        if Menu.SelectedRow == 1 then -- Trait points delta
            Menu.TraitDelta = math.max(1, math.min(100, (Menu.TraitDelta or 5) + delta * 5))
            Menu.SetMessage(string.format("Trait Point Step: %d", Menu.TraitDelta))
        elseif Menu.SelectedRow == 5 then -- Mutation charges delta
            Menu.MutationDelta = math.max(1, math.min(50, (Menu.MutationDelta or 1) + delta))
            Menu.SetMessage(string.format("Mutation Charge Step: %d", Menu.MutationDelta))
        end

    elseif tab == 5 then -- World
        if Menu.SelectedRow == 1 then -- Time Hour
            Menu.TargetHour = math.max(0, math.min(23, (Menu.TargetHour or 12) + delta))
            Menu.SetMessage(string.format("Target Hour: %02d:00", Menu.TargetHour))
        elseif Menu.SelectedRow == 4 then -- NPC Level Override
            Menu.NpcLevel = math.max(0, math.min(99, (Menu.NpcLevel or 0) + delta))
            local player = Safety.FindValid(function() return UEHelpers.GetPlayer() end)
            World.SetNpcLevelOverride(player, Menu.NpcLevel)
            Menu.SetMessage(string.format("NPC Level: %d (0=Default)", Menu.NpcLevel))
        elseif Menu.SelectedRow == 5 then -- Alert Level
            Menu.AlertLevel = math.max(0, math.min(9, (Menu.AlertLevel or 0) + delta))
            World.SetAlertLevel(Menu.AlertLevel)
            Menu.SetMessage(string.format("Alert Level: %d", Menu.AlertLevel))
        end

    elseif tab == 6 then -- Gear
        local allCats = {}
        for _, c in ipairs(Catalog.Gear or {}) do table.insert(allCats, c) end
        for _, c in ipairs(Catalog.Craftables or {}) do table.insert(allCats, c) end
        for _, c in ipairs(Catalog.Cleanup or {}) do table.insert(allCats, c) end

        if Menu.SelectedRow == 1 then -- Change Category
            Menu.GearCategoryIndex = math.max(1, math.min(#allCats, Menu.GearCategoryIndex + delta))
            Menu.GearItemIndex = 1
            local cat = allCats[Menu.GearCategoryIndex]
            Menu.SetMessage("Category: " .. (cat and cat.category or "None"))
        elseif Menu.SelectedRow == 2 then -- Change Item in Category
            local cat = allCats[Menu.GearCategoryIndex]
            local opts = cat and cat.options or {}
            Menu.GearItemIndex = math.max(1, math.min(#opts, Menu.GearItemIndex + delta))
            local item = opts[Menu.GearItemIndex]
            Menu.SetMessage("Item: " .. (item and item.label or "None"))
        elseif Menu.SelectedRow == 3 then -- Quantity
            Menu.GearQuantity = math.max(1, math.min(99, Menu.GearQuantity + delta))
            Menu.SetMessage("Quantity: " .. Menu.GearQuantity)
        end
    end
end

-- Execute current selected row / action
function Menu.Select()
    if not Menu.IsOpen then return end
    local tab = Menu.ActiveTab
    local player = Safety.FindValid(function() return UEHelpers.GetPlayer() end)

    if tab == 1 then -- Combat
        if Menu.SelectedRow == 1 then
            State.Toggles.infiniteHealth = not State.Toggles.infiniteHealth
            Menu.SetMessage("Infinite Health: " .. (State.Toggles.infiniteHealth and "ON" or "OFF"))
        elseif Menu.SelectedRow == 2 then
            State.Toggles.infiniteStamina = not State.Toggles.infiniteStamina
            Menu.SetMessage("Infinite Stamina: " .. (State.Toggles.infiniteStamina and "ON" or "OFF"))
        elseif Menu.SelectedRow == 3 then
            State.Toggles.infiniteBlood = not State.Toggles.infiniteBlood
            Menu.SetMessage("Infinite Blood: " .. (State.Toggles.infiniteBlood and "ON" or "OFF"))
        elseif Menu.SelectedRow == 4 then
            local ok, msg = Combat.HealNow(player)
            Menu.SetMessage(msg)
        elseif Menu.SelectedRow == 5 then
            local ok, msg = Combat.RefillBlood()
            Menu.SetMessage(msg)
        elseif Menu.SelectedRow == 9 then
            local ok, msg = Combat.KillAllAggressive(player)
            Menu.SetMessage(msg)
        end

    elseif tab == 2 then -- Character
        if Menu.SelectedRow == 3 then
            local ok, msg = Character.GrantXP(Menu.XpTier or 5)
            Menu.SetMessage(msg)
        end

    elseif tab == 3 then -- Movement
        if Menu.SelectedRow == 3 then
            local mode = Movement.CycleMode(player)
            Menu.SetMessage("Movement Mode: " .. mode:upper())
        elseif Menu.SelectedRow == 4 then
            local ok, msg = Movement.Teleport(player)
            Menu.SetMessage(msg)
        end

    elseif tab == 4 then -- Skills
        if Menu.SelectedRow == 1 then
            local ok, msg = Skills.AddTraitPoints(Menu.TraitDelta or 5)
            Menu.SetMessage(msg)
        elseif Menu.SelectedRow == 2 then
            local ok, msg = Skills.AddTraitPoints(-(Menu.TraitDelta or 5))
            Menu.SetMessage(msg)
        elseif Menu.SelectedRow == 3 then
            local ok, msg = Skills.UnlockAllTraits()
            Menu.SetMessage(msg)
        elseif Menu.SelectedRow == 4 then
            local ok, msg = Skills.ResetAllTraits()
            Menu.SetMessage(msg)
        elseif Menu.SelectedRow == 5 then
            local ok, msg = Skills.AddMutationCharges(Menu.MutationDelta or 1)
            Menu.SetMessage(msg)
        elseif Menu.SelectedRow == 6 then
            local ok, msg = Skills.ToggleCooldowns()
            Menu.SetMessage(msg)
        elseif Menu.SelectedRow == 7 then
            State.Toggles.keepActionSlotsCharged = not State.Toggles.keepActionSlotsCharged
            Menu.SetMessage("Keep Action Slots Charged: " .. (State.Toggles.keepActionSlotsCharged and "ON" or "OFF"))
        end

    elseif tab == 5 then -- World
        if Menu.SelectedRow == 1 then
            local ok, msg = World.SetTime(Menu.TargetHour or 12, 0)
            Menu.SetMessage(msg)
        elseif Menu.SelectedRow == 2 then
            local ok, msg = World.UnlockAllFastTravel()
            Menu.SetMessage(msg)
        elseif Menu.SelectedRow == 3 then
            local ok, msg = World.RevealAllMappins()
            Menu.SetMessage(msg)
        end

    elseif tab == 6 then -- Gear
        local allCats = {}
        for _, c in ipairs(Catalog.Gear or {}) do table.insert(allCats, c) end
        for _, c in ipairs(Catalog.Craftables or {}) do table.insert(allCats, c) end
        for _, c in ipairs(Catalog.Cleanup or {}) do table.insert(allCats, c) end

        local cat = allCats[Menu.GearCategoryIndex]
        local opts = cat and cat.options or {}
        local item = opts[Menu.GearItemIndex]

        if Menu.SelectedRow == 4 and item then
            if cat.category == "Cleanup" then
                local ok, msg = Granter.RemoveGear(item.value)
                Menu.SetMessage(msg)
            else
                local ok, msg = Granter.GiveGear(item.value, Menu.GearQuantity or 1)
                Menu.SetMessage(msg)
            end
        elseif Menu.SelectedRow == 5 then
            local ok, msg = Inventory.AddCoins(player, 5000)
            Menu.SetMessage(msg)
        elseif Menu.SelectedRow == 6 then
            local ok, msg = Inventory.UnlockAllRecipes()
            Menu.SetMessage(msg)
        elseif Menu.SelectedRow == 7 then
            local ok, msg = Inventory.SelfCheck()
            Menu.SetMessage(msg)
        end

    elseif tab == 7 then -- Presets
        if Menu.SelectedRow == 1 then
            local ok, msg = Config.SavePreset("QuickSave")
            Menu.SetMessage(msg)
        elseif Menu.SelectedRow == 2 then
            local ok, msg = Config.ApplyPreset("QuickSave")
            Menu.SetMessage(msg)
        elseif Menu.SelectedRow == 3 then
            State.ResetToDefaults()
            Menu.SetMessage("All settings reset to defaults")
        end
    end
end

-- Render the menu on HUD Canvas
function Menu.Render(Canvas)
    if not Menu.IsOpen or not Canvas then return end

    local screenW = Canvas.SizeX or 1920
    local screenH = Canvas.SizeY or 1080

    local menuW = 720
    local menuH = 620
    local startX = (screenW - menuW) / 2
    local startY = (screenH - menuH) / 2

    -- Helper to draw text safely
    local function DrawText(text, x, y, color, scale)
        pcall(function()
            Canvas:K2_DrawText(
                nil,
                text,
                { X = x, Y = y },
                { X = scale or 1.0, Y = scale or 1.0 },
                color or COLOR_TEXT,
                0,
                { R = 0, G = 0, B = 0, A = 1 },
                { X = 1, Y = 1 },
                false,
                false,
                false,
                { R = 0, G = 0, B = 0, A = 1 }
            )
        end)
    end

    -- Helper to draw a box
    local function DrawBox(x, y, w, h, color, thickness)
        pcall(function()
            Canvas:K2_DrawBox(
                { X = x, Y = y },
                { X = w, Y = h },
                thickness or 1.0,
                color or COLOR_BORDER
            )
        end)
    end

    -- Draw Main Window Outline & Frame
    DrawBox(startX, startY, menuW, menuH, COLOR_BORDER, 2.0)
    DrawBox(startX + 3, startY + 3, menuW - 6, menuH - 6, COLOR_BORDER_DIM, 1.0)

    -- Header Title
    DrawText("BLOOD OF THE DAWNWALKER - IN-GAME MOD", startX + 24, startY + 16, COLOR_GOLD, 1.25)
    DrawText("[F1] Close | [Tab] Switch Category | [Arrows] Navigate | [Enter] Select", startX + 24, startY + 44, COLOR_TEXT_DIM, 0.85)

    -- Tab Bar
    local tabY = startY + 70
    local tabX = startX + 20
    for i, name in ipairs(TABS) do
        local isCur = (i == Menu.ActiveTab)
        local tabColor = isCur and COLOR_GOLD or COLOR_TEXT_DIM
        if isCur then
            DrawBox(tabX - 4, tabY - 2, 90, 24, COLOR_BORDER, 1.5)
        end
        DrawText(name, tabX, tabY + 2, tabColor, 0.95)
        tabX = tabX + 96
    end

    DrawBox(startX + 16, tabY + 28, menuW - 32, 1, COLOR_BORDER_DIM, 1.0)

    -- Content Area
    local contentY = tabY + 40
    local lineSpacing = 32

    local function DrawRow(rowIndex, label, valueStr, isToggle, isChecked)
        local isSel = (rowIndex == Menu.SelectedRow)
        local y = contentY + (rowIndex - 1) * lineSpacing

        if isSel then
            DrawBox(startX + 20, y - 4, menuW - 40, 28, COLOR_GOLD, 1.0)
        end

        local textColor = isSel and COLOR_GOLD or COLOR_TEXT
        DrawText(label, startX + 32, y, textColor, 1.0)

        if isToggle then
            local checkStr = isChecked and "[ ON ]" or "[ OFF ]"
            local checkCol = isChecked and COLOR_ACTIVE or COLOR_TEXT_DIM
            DrawText(checkStr, startX + menuW - 140, y, checkCol, 1.0)
        elseif valueStr then
            DrawText(valueStr, startX + menuW - 200, y, textColor, 1.0)
        end
    end

    -- Tab Contents
    if Menu.ActiveTab == 1 then -- Combat
        DrawRow(1, "Infinite Health (God Mode)", nil, true, State.Toggles.infiniteHealth)
        DrawRow(2, "Infinite Stamina", nil, true, State.Toggles.infiniteStamina)
        DrawRow(3, "Infinite Blood", nil, true, State.Toggles.infiniteBlood)
        DrawRow(4, "[ HEAL HEALTH & STAMINA NOW ]", "Execute", false)
        DrawRow(5, "[ REFILL BLOOD SEGMENTS NOW ]", "Execute", false)
        DrawRow(6, "Damage Amplifier", string.format("< %.1fx >", State.Multipliers.damageAmplifier or 1.0), false)
        DrawRow(7, "Combat Difficulty", string.format("< %d >", State.Gameplay.actionDifficulty or 1), false)
        DrawRow(8, "RPG Difficulty", string.format("< %d >", State.Gameplay.rpgDifficulty or 1), false)
        DrawRow(9, "[ KILL ALL AGGRESSIVE HOSTILES ]", "Execute", false)

    elseif Menu.ActiveTab == 2 then -- Character
        DrawRow(1, "Set Player Level", string.format("< %d >", State.Readouts.currentLevel or 1), false)
        DrawRow(2, "Level Cap", string.format("< %d >", State.Gameplay.levelCap or 99), false)
        DrawRow(3, "Grant Quest Experience (XP)", string.format("< Tier %d >", Menu.XpTier or 5), false)
        DrawRow(4, string.format("Current XP: %s / %s", tostring(State.Readouts.currentXP or 0), tostring(State.Readouts.xpRequirement or "Max")), nil, false)

    elseif Menu.ActiveTab == 3 then -- Movement
        DrawRow(1, "Player Speed Multiplier", string.format("< %.1fx >", State.Multipliers.speedMultiplier or 1.0), false)
        DrawRow(2, "Jump Height Multiplier", string.format("< %.1fx >", State.Multipliers.jumpMultiplier or 1.0), false)
        DrawRow(3, "Movement Mode", string.format("< %s >", (State.Gameplay.movementMode or "walk"):upper()), false)
        DrawRow(4, "[ TELEPORT TO AIM POINT ]", "Execute", false)
        DrawRow(5, "Field of View (FOV)", string.format("< %.1fx >", State.Multipliers.fovMultiplier or 1.0), false)
        DrawRow(6, "Game Speed (Slomo)", string.format("< %.1fx >", State.Multipliers.gameSpeed or 1.0), false)

    elseif Menu.ActiveTab == 4 then -- Skills
        DrawRow(1, "Add Unspent Trait Points", string.format("< +%d >", Menu.TraitDelta or 5), false)
        DrawRow(2, "Remove Unspent Trait Points", string.format("< -%d >", Menu.TraitDelta or 5), false)
        DrawRow(3, "[ UNLOCK ENTIRE TRAIT TREE ]", "Execute", false)
        DrawRow(4, "[ RESET / RESPEC ALL TRAITS ]", "Execute", false)
        DrawRow(5, "Vampire Mutation Charges", string.format("< +%d >", Menu.MutationDelta or 1), false)
        DrawRow(6, "No Ability Cooldowns", nil, true, State.Toggles.noCooldowns)
        DrawRow(7, "Keep Action Slots Charged", nil, true, State.Toggles.keepActionSlotsCharged)
        DrawRow(8, string.format("Unspent Points: %s | Mutation: Level %s (%s)", tostring(State.Readouts.traitPoints or 0), tostring(State.Readouts.mutationLevel or 0), tostring(State.Readouts.mutationCharges or 0)), nil, false)

    elseif Menu.ActiveTab == 5 then -- World
        DrawRow(1, "Set Time of Day", string.format("< %02d:00 >", Menu.TargetHour or 12), false)
        DrawRow(2, "[ UNLOCK ALL FAST TRAVEL POINTS ]", "Execute", false)
        DrawRow(3, "[ REVEAL ALL MAP PINS ]", "Execute", false)
        DrawRow(4, "Override World NPC Level", string.format("< %d >", Menu.NpcLevel or 0), false)
        DrawRow(5, "Set World Alert Level", string.format("< %d >", Menu.AlertLevel or 0), false)
        DrawRow(6, string.format("Current Day: %s | Deadline Day: %s", tostring(State.Readouts.currentDay or 1), tostring(State.Readouts.mainGoalDay or 30)), nil, false)

    elseif Menu.ActiveTab == 6 then -- Gear
        local allCats = {}
        for _, c in ipairs(Catalog.Gear or {}) do table.insert(allCats, c) end
        for _, c in ipairs(Catalog.Craftables or {}) do table.insert(allCats, c) end
        for _, c in ipairs(Catalog.Cleanup or {}) do table.insert(allCats, c) end

        local cat = allCats[Menu.GearCategoryIndex]
        local catName = cat and cat.category or "None"
        local opts = cat and cat.options or {}
        local item = opts[Menu.GearItemIndex]
        local itemName = item and item.label or "None"

        DrawRow(1, "Category", string.format("< %s (%d/%d) >", catName, Menu.GearCategoryIndex, #allCats), false)
        DrawRow(2, "Item", string.format("< %s >", itemName:sub(1, 28)), false)
        DrawRow(3, "Quantity", string.format("< %d >", Menu.GearQuantity or 1), false)
        DrawRow(4, catName == "Cleanup" and "[ REMOVE ITEM DUPLICATES ]" or "[ GRANT SELECTED GEAR / ITEM ]", "Execute", false)
        DrawRow(5, "[ ADD 5,000 COINS ]", "Execute", false)
        DrawRow(6, "[ UNLOCK ALL CRAFTING RECIPES ]", "Execute", false)
        DrawRow(7, "[ RUN COMPATIBILITY SELF CHECK ]", "Execute", false)

    elseif Menu.ActiveTab == 7 then -- Presets
        DrawRow(1, "[ SAVE SETTINGS AS PRESET ]", "Execute", false)
        DrawRow(2, "[ LOAD PRESET ]", "Execute", false)
        DrawRow(3, "[ RESET ALL CHEATS TO VANILLA ]", "Execute", false)
    end

    -- Footer Status Line
    DrawBox(startX + 16, startY + menuH - 44, menuW - 32, 1, COLOR_BORDER_DIM, 1.0)
    DrawText(Menu.StatusMessage or "", startX + 24, startY + menuH - 32, COLOR_GOLD, 0.95)
end

return Menu
