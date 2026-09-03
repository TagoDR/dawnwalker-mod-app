local function log_object(label, object)
    if object and object:IsValid() then
        print(string.format("[DawnwalkerGameplayProbe] %s: %s", label, object:GetFullName()))
    end
end

local function should_log_property(name)
    local lower_name = string.lower(name or "")
    local keywords = {
        -- direct progression
        "xp", "exp", "experience", "expgain", "xpgain", "xp_gain", "exp_gain",
        "experiencegain", "experience_gain", "experiencelevel", "playerlevel",
        "level", "lvl", "rank", "tier", "grade", "prestige", "renown",
        "progression", "progress", "advancement", "growth",
        "currentlevel", "nextlevel", "current_level", "next_level",
        "experience_to_level", "xp_to_level", "exp_to_level",

        -- skill / ability / unlock
        "skill", "skills", "skillpoint", "skill_points", "skillpt", "skill_pt",
        "ability", "abilitypoint", "ability_points", "abilitypt", "ability_pt",
        "perk", "perks", "talent", "talents", "mastery", "proficiency",
        "specialization", "branch", "upgrade", "upgrades", "unlock", "unlocked",
        "unlocks", "learned", "acquired", "reward", "rewards",

        -- stats / resources / currency/values
        "attribute", "attributes", "stat", "stats", "resource", "resources",
        "points", "point", "currency", "gold", "souls", "gems", "reputation",
        "power", "strength", "vigor", "stamina", "focus", "willpower",
        "health", "mana", "energy", "charge", "combo", "score",
        "meter", "value", "values", "bonus", "modifier",

        -- hidden system names / manager-like patterns
        "system", "systems", "manager", "managers", "controller", "controllers",
        "save", "savegame", "profile", "inventory", "loadout", "bookmarks",
        "state", "status", "combat", "battle", "raid", "mission", "quest",
        "equipment", "loadout", "class", "spec", "playstyle"
    }

    for _, keyword in ipairs(keywords) do
        if string.find(lower_name, keyword, 1, true) then
            return true
        end
    end

    return false
end

local function log_progression_properties(label, object)
    if not object or not object:IsValid() then return end

    local matches = 0
    object:GetClass():ForEachProperty(function(property)
        local name = property:GetFName():ToString()
        if should_log_property(name) then
            matches = matches + 1
            print(string.format("[DawnwalkerGameplayProbe] %s property: %s.%s", label, object:GetFullName(), name))
        end
    end)

    if matches == 0 then
        print(string.format("[DawnwalkerGameplayProbe] %s matched no progression-like property names.", label))
    end
end

local function inspect_object(label, object)
    log_object(label, object)
    log_progression_properties(label, object)
end

local function object_name_looks_like_gameplay(name)
    if not name then return false end
    local lower = string.lower(name)
    local keywords = {
        -- direct progression phrases
        "progress", "progression", "advancement", "growth",
        "xp", "exp", "experience", "level", "lvl", "rank", "tier", "prestige",
        "renown", "mastery", "proficiency", "skill", "ability",
        "perk", "talent", "unlock", "unlocked", "reward", "upgrade",
        "combat", "battle", "power", "strength", "vigor", "stamina",

        -- stat / resource / manager words
        "stat", "stats", "attribute", "attributes", "resource", "resources",
        "point", "points", "currency", "inventory", "loadout", "profile",
        "save", "savegame", "status", "state", "system", "manager", "archive",
        "controller", "component", "playerstate", "character",

        -- common alternate names
        "spec", "specialization", "branch", "abilitypoint", "skillpoint",
        "talentpoint", "perkpoint", "earned", "learned", "acquired",
        "grade", "score", "meter", "modifier", "bonus", "value",
        "mission", "quest", "reputation", "fame", "infamy", "score"
    }

    for _, keyword in ipairs(keywords) do
        if string.find(lower, keyword, 1, true) then
            return true
        end
    end

    return false
end

local function inspect_gameplay_object(label, object)
    if not object or not object:IsValid() then return end

    print(string.format("[DawnwalkerGameplayProbe] %s class: %s", label, object:GetClass():GetFullName()))

    local count = 0
    object:GetClass():ForEachProperty(function(property)
        local name = property:GetFName():ToString()
        count = count + 1
        print(string.format("[DawnwalkerGameplayProbe] %s property[%d]: %s", label, count, name))
    end)

    print(string.format("[DawnwalkerGameplayProbe] %s total property count: %d", label, count))
end

local function inspect_full_object_schema(label, object)
    if not object or not object:IsValid() then return end

    print(string.format("[DawnwalkerGameplayProbe] %s full schema dump begin: %s", label, object:GetFullName()))
    local count = 0
    object:GetClass():ForEachProperty(function(property)
        local name = property:GetFName():ToString()
        count = count + 1
        print(string.format("[DawnwalkerGameplayProbe] %s full property[%d]: %s", label, count, name))
    end)
    print(string.format("[DawnwalkerGameplayProbe] %s full schema dump end: %d properties", label, count))
end

local function should_log_reference_property(name)
    local lower_name = string.lower(name or "")
    local keywords = {
        "component", "manager", "system", "state", "controller", "instance",
        "data", "inventory", "loadout", "profile", "save", "profiledata",
        "skill", "ability", "perk", "talent", "upgrade", "reward",
        "xp", "exp", "experience", "level", "rank", "tier", "progress",
        "stat", "attribute", "resource", "currency", "score", "power",
        "class", "spec", "branch", "modifier", "bonus", "quest", "mission"
    }

    for _, keyword in ipairs(keywords) do
        if string.find(lower_name, keyword, 1, true) then
            return true
        end
    end

    return false
end

local function log_reference_properties(label, object)
    if not object or not object:IsValid() then return end

    local matches = 0
    object:GetClass():ForEachProperty(function(property)
        local name = property:GetFName():ToString()
        if should_log_reference_property(name) then
            matches = matches + 1
            print(string.format("[DawnwalkerGameplayProbe] %s reference property: %s.%s", label, object:GetFullName(), name))
        end
    end)

    if matches == 0 then
        print(string.format("[DawnwalkerGameplayProbe] %s had no manager-like or progression-like reference property names.", label))
    end
end

local function log_candidate_object(label, object)
    if not object or not object:IsValid() then return end

    local full_name = object:GetFullName() or ""
    local class_name = object:GetClass():GetFullName() or ""
    if object_name_looks_like_gameplay(full_name) or object_name_looks_like_gameplay(class_name) then
        print(string.format("[DawnwalkerGameplayProbe] %s candidate object: %s | class: %s", label, full_name, class_name))
    end
end

local function dump_nested_object_references(label, object, depth, seen)
    if not object or not object:IsValid() then return end
    if depth > 4 then return end
    if seen and seen[object] then return end
    if seen then seen[object] = true end

    local full_name = object:GetFullName() or "(unknown)"
    print(string.format("[DawnwalkerGameplayProbe] %s recursive node[%d]: %s", label, depth, full_name))

    object:GetClass():ForEachProperty(function(property)
        local prop_name = property:GetFName():ToString()
        local lower_name = string.lower(prop_name or "")
        local is_object_like = string.find(lower_name, "component", 1, true)
            or string.find(lower_name, "manager", 1, true)
            or string.find(lower_name, "system", 1, true)
            or string.find(lower_name, "state", 1, true)
            or string.find(lower_name, "controller", 1, true)
            or string.find(lower_name, "inventory", 1, true)
            or string.find(lower_name, "loadout", 1, true)
            or string.find(lower_name, "profile", 1, true)
            or string.find(lower_name, "progress", 1, true)
            or string.find(lower_name, "skill", 1, true)
            or string.find(lower_name, "ability", 1, true)
            or string.find(lower_name, "level", 1, true)
            or string.find(lower_name, "rank", 1, true)
            or string.find(lower_name, "tier", 1, true)
            or string.find(lower_name, "upgrade", 1, true)
            or string.find(lower_name, "reward", 1, true)
            or string.find(lower_name, "resource", 1, true)
            or string.find(lower_name, "currency", 1, true)
            or string.find(lower_name, "stat", 1, true)
            or string.find(lower_name, "attribute", 1, true)
            or string.find(lower_name, "quest", 1, true)
            or string.find(lower_name, "mission", 1, true)
            or string.find(lower_name, "save", 1, true)

        if is_object_like then
            print(string.format("[DawnwalkerGameplayProbe] %s nested reference property: %s.%s", label, full_name, prop_name))
        end
    end)
end

NotifyOnNewObject("/Script/Engine.PlayerController", function(object)
    inspect_object("PlayerController", object)
    inspect_full_object_schema("PlayerControllerFullSchema", object)
    log_candidate_object("PlayerControllerCandidate", object)
end)

NotifyOnNewObject("/Script/Engine.Character", function(object)
    inspect_object("Character", object)
    inspect_full_object_schema("CharacterFullSchema", object)
    log_candidate_object("CharacterCandidate", object)
end)

NotifyOnNewObject("/Script/Engine.PlayerState", function(object)
    inspect_object("PlayerState", object)
    inspect_full_object_schema("PlayerStateFullSchema", object)
    log_candidate_object("PlayerStateCandidate", object)
end)

NotifyOnNewObject("/Script/Engine.Actor", function(object)
    log_candidate_object("ActorCandidate", object)
end)

NotifyOnNewObject("/Script/Engine.Component", function(object)
    log_candidate_object("ComponentCandidate", object)
end)

RegisterHook("/Script/Engine.PlayerController:ClientRestart", function(self)
    local player_controller = self:get()
    inspect_object("ClientRestartPlayerController", player_controller)
    inspect_object("PlayerPawn", player_controller.Pawn)
    inspect_object("PlayerState", player_controller.PlayerState)

    local pawn = player_controller.Pawn
    local player_state = player_controller.PlayerState
    if pawn and pawn:IsValid() and string.find(pawn:GetClass():GetFName():ToString(), "BP_PlayerCharacter", 1, true) then
        inspect_full_object_schema("GameplayPawnFullSchema", pawn)
        inspect_gameplay_object("GameplayPawn", pawn)
        log_reference_properties("GameplayPawnRefs", pawn)
        dump_nested_object_references("GameplayPawnRecursive", pawn, 0, {})
    end
    if player_state and player_state:IsValid() and string.find(player_state:GetClass():GetFName():ToString(), "BP_PlayerState", 1, true) then
        inspect_full_object_schema("GameplayPlayerStateFullSchema", player_state)
        inspect_gameplay_object("GameplayPlayerState", player_state)
        log_reference_properties("GameplayPlayerStateRefs", player_state)
        dump_nested_object_references("GameplayPlayerStateRecursive", player_state, 0, {})
    end
    if player_controller and player_controller:IsValid() then
        inspect_full_object_schema("PlayerControllerFullSchema", player_controller)
        log_reference_properties("PlayerControllerRefs", player_controller)
        dump_nested_object_references("PlayerControllerRecursive", player_controller, 0, {})
    end
end)

print("[DawnwalkerGameplayProbe] Loaded. No gameplay values were changed.")