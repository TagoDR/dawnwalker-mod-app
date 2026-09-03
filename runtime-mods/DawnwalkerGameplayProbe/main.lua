local function log_object(label, object)
    if object and object:IsValid() then
        print(string.format("[DawnwalkerGameplayProbe] %s: %s", label, object:GetFullName()))
    end
end

NotifyOnNewObject("/Script/Engine.PlayerController", function(object)
    log_object("PlayerController", object)
end)

NotifyOnNewObject("/Script/Engine.Character", function(object)
    log_object("Character", object)
end)

NotifyOnNewObject("/Script/Engine.PlayerState", function(object)
    log_object("PlayerState", object)
end)

print("[DawnwalkerGameplayProbe] Loaded. No gameplay values were changed.")