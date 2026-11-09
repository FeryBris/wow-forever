local addonName, FC = ...

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")

local runtimeEvents = {
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_LEVEL_UP",
    "SPELLS_CHANGED",
    "SKILL_LINES_CHANGED",
    "BAG_UPDATE_DELAYED",
    "UPDATE_INVENTORY_DURABILITY",
    "TRADE_SKILL_SHOW",
    "TRADE_SKILL_LIST_UPDATE",
    "NEW_RECIPE_LEARNED",
    "UNIT_AURA",
    "PLAYER_XP_UPDATE",
    "UPDATE_EXHAUSTION",
    "ZONE_CHANGED",
    "ZONE_CHANGED_NEW_AREA",
    "TAXIMAP_OPENED",
    "GROUP_ROSTER_UPDATE",
    "QUEST_LOG_UPDATE",
    "QUEST_ACCEPTED",
    "QUEST_TURNED_IN",
    "BANKFRAME_OPENED",
    "BANKFRAME_CLOSED",
    "PLAYERBANKSLOTS_CHANGED",
    "BANK_TABS_CHANGED",
}

local dashboardRefreshEvents = {
    PLAYER_LOGIN = true,
    PLAYER_ENTERING_WORLD = true,
    SKILL_LINES_CHANGED = true,
    BAG_UPDATE_DELAYED = true,
    UPDATE_INVENTORY_DURABILITY = true,
    TRADE_SKILL_SHOW = true,
    TRADE_SKILL_LIST_UPDATE = true,
    NEW_RECIPE_LEARNED = true,
    PLAYER_XP_UPDATE = true,
    UPDATE_EXHAUSTION = true,
    ZONE_CHANGED_NEW_AREA = true,
    TAXIMAP_OPENED = true,
    GROUP_ROSTER_UPDATE = true,
    QUEST_LOG_UPDATE = true,
    QUEST_ACCEPTED = true,
    QUEST_TURNED_IN = true,
    BANKFRAME_OPENED = true,
    PLAYERBANKSLOTS_CHANGED = true,
    BANK_TABS_CHANGED = true,
}

local function capabilityText(value)
    return value and "YES" or "NO"
end

local function countEntries(tbl)
    local count = 0
    for _ in pairs(tbl or {}) do count = count + 1 end
    return count
end

function FC:GetDiagnosticsText()
    local capabilities = self.API.capabilities or {}
    local character = self:GetCurrentCharacter()
    local goals = self.Goals and self.Goals:GetGoals(true) or {}
    local camp = self.Camps and self.Camps:GetSnapshot() or nil
    local travel = self.Travel and self.Travel:GetSnapshot() or nil
    local journey = self.Journey and self.Journey:GetSnapshot() or nil

    local lines = {
        "Forever Companion Diagnostics",
        "Addon version: " .. tostring(self.version),
        "Client version: " .. tostring(self.Client.version),
        "Build: " .. tostring(self.Client.build),
        "Interface: " .. tostring(self.Client.interface),
        "Forever detected: " .. capabilityText(self.Client.isForever),
        "DB version: " .. tostring(self.DB and self.DB.dbVersion or "not loaded"),
        "Character: " .. tostring(character and character.key or "not scanned"),
        "Cached characters: " .. tostring(countEntries(self.DB and self.DB.account and self.DB.account.characters)),
        "Cached account items: " .. tostring(countEntries(self.DB and self.DB.account and self.DB.account.items)),
        "Cached flight points: " .. tostring(countEntries(self.DB and self.DB.account and self.DB.account.flightPoints)),
        "Cached recipes: " .. tostring(countEntries(self.DB and self.DB.account and self.DB.account.recipes)),
        "Crafting goals: " .. tostring(countEntries(self.DB and self.DB.account and self.DB.account.craftingGoals)),
        "Personal goals: " .. tostring(#goals),
        "Capabilities:",
        "  Professions: " .. capabilityText(capabilities.professions),
        "  Recipe cache: " .. capabilityText(capabilities.tradeSkillRecipes),
        "  Recipe schematic: " .. capabilityText(capabilities.recipeSchematic),
        "  Containers: " .. capabilityText(capabilities.containers),
        "  Bank storage: " .. capabilityText(capabilities.storage),
        "  Item info: " .. capabilityText(capabilities.itemInfo),
        "  Durability: " .. capabilityText(capabilities.durability),
        "  Maps: " .. capabilityText(capabilities.maps),
        "  Taxi nodes: " .. capabilityText(capabilities.taxiNodes),
        "  Quests on map: " .. capabilityText(capabilities.questsOnMap),
        "  Legacy: " .. capabilityText(capabilities.legacy),
        "  Camps: " .. capabilityText(capabilities.camps),
        "  Travel: " .. capabilityText(capabilities.travel),
        "  Journey: " .. capabilityText(capabilities.journey),
        "Runtime snapshots:",
        "  Camp: " .. (camp and "YES" or "NO"),
        "  Travel nodes: " .. tostring(travel and #(travel.nodes or {}) or 0),
        "  Journey opportunities: " .. tostring(journey and #(journey.opportunities or {}) or 0),
        "Discovery mode: " .. tostring(self.DB and self.DB.settings and self.DB.settings.discoveryMode or "unknown"),
        "Locale setting: " .. tostring(self.DB and self.DB.settings and self.DB.settings.locale or "AUTO"),
        "Minimap button: " .. ((self.DB and self.DB.settings and self.DB.settings.minimapButton ~= false) and "ON" or "OFF"),
        "Suggestions: " .. tostring(self.Suggestions:Count()),
    }

    return table.concat(lines, "\n")
end

function FC:PrintDiagnostics()
    for line in self:GetDiagnosticsText():gmatch("[^\n]+") do self:Print(line) end
end

function FC:PrintCharacters()
    local characters = {}
    for _, character in pairs(self.DB.account.characters or {}) do characters[#characters + 1] = character end

    table.sort(characters, function(a, b)
        if (a.level or 0) == (b.level or 0) then return tostring(a.name) < tostring(b.name) end
        return (a.level or 0) > (b.level or 0)
    end)

    FC:Print(string.format("Cached characters: %d", #characters))
    for _, character in ipairs(characters) do
        FC:Print(string.format("%s — Level %d %s (%s)", tostring(character.name or "Unknown"), tonumber(character.level) or 0,
            tostring(character.className or ""), tostring(character.realm or "Unknown Realm")))
    end
end

local function showHelp()
    FC:Print("Commands:")
    FC:Print("/fc - toggle dashboard")
    FC:Print("/fc refresh - rescan enabled modules")
    FC:Print("/fc camps | travel | journey | legacy - open companion views")
    FC:Print("/fc item <name or ID> - search cached bags and banks")
    FC:Print("/fc characters - list cached characters")
    FC:Print("/fc goal <recipeID> [quantity] - pin a crafting goal")
    FC:Print("/fc ungoal <recipeID> - remove a crafting goal")
    FC:Print("/fc goals - show crafting shopping list")
    FC:Print("/fc pin <title> - add a personal goal")
    FC:Print("/fc pins - list personal goals")
    FC:Print("/fc done <goalID> - complete/reopen a personal goal")
    FC:Print("/fc unpin <goalID> - remove a personal goal")
    FC:Print("/fc mode explorer|balanced|guide - set Discovery Mode")
    FC:Print("/fc settings - open settings")
    FC:Print("/fc minimap on|off|toggle - control the minimap launcher")
    FC:Print("/fc debug on|off - toggle debug logging")
    FC:Print("/fc dump - open copyable diagnostics")
    FC:Print("/fc version - print client/addon version")
end

local function handleGoal(argument)
    local recipeID, quantity = tostring(argument or ""):match("^(%d+)%s*(%d*)$")
    if not recipeID then FC:Print("Usage: /fc goal <recipeID> [quantity]"); return end

    local ok, result = FC.CraftingGoals:AddGoal(tonumber(recipeID), tonumber(quantity) or 1)
    if ok then
        FC:Print(string.format("Pinned crafting goal: %s x%d", tostring(result.name), tonumber(result.quantity) or 1))
        if FC.UI and FC.UI.frame and FC.UI.frame:IsShown() then FC.UI:RefreshDashboard() end
    else
        FC:Print(result)
    end
end

local function handlePin(argument)
    if not FC.Goals then FC:Print("Goal system is unavailable."); return end
    local title = tostring(argument or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if title == "" then FC:Print("Usage: /fc pin <title>"); return end
    local ok, goal = FC.Goals:Create(title, nil, "Personal", 65)
    if ok then FC:Print("Pinned personal goal #" .. tostring(goal.id) .. ": " .. tostring(goal.title)) else FC:Print(goal) end
end

local function handleMode(argument)
    local value = string.upper(tostring(argument or ""))
    local allowed = { EXPLORER = true, BALANCED = true, GUIDE = true }
    if not allowed[value] then FC:Print("Usage: /fc mode explorer|balanced|guide"); return end

    FC.DB.settings.discoveryMode = value
    if FC.Travel and FC:IsModuleEnabled("Travel") then FC.Travel:Refresh("mode-change") end
    if FC.Journey and FC:IsModuleEnabled("Journey") then FC.Journey:Refresh("mode-change") end
    FC:Print("Discovery Mode set to " .. value .. ".")
    if FC.UI and FC.UI.frame and FC.UI.frame:IsShown() then FC.UI:RefreshDashboard() end
end

local function handleMinimap(argument)
    local value = string.lower(tostring(argument or ""))
    local minimap = FC.UI and FC.UI.Minimap
    if not minimap then FC:Print("Minimap launcher is unavailable."); return end

    if value == "on" or value == "show" then
        minimap:Create(); minimap:SetShown(true); FC:Print("Minimap launcher enabled.")
    elseif value == "off" or value == "hide" then
        minimap:SetShown(false); FC:Print("Minimap launcher disabled. Use /fc minimap on to show it again.")
    elseif value == "toggle" or value == "" then
        minimap:Create()
        local currentlyEnabled = FC.DB.settings.minimapButton ~= false
        minimap:SetShown(not currentlyEnabled)
        FC:Print("Minimap launcher " .. (currentlyEnabled and "disabled." or "enabled."))
    else
        FC:Print("Usage: /fc minimap on|off|toggle")
    end
end

local function handleSlashCommand(message)
    message = tostring(message or "")
    local command, argument = message:match("^(%S*)%s*(.-)$")
    command = string.lower(command or "")

    if command == "" then
        FC.UI:Toggle()
    elseif command == "refresh" then
        FC:RefreshModules("slash"); FC:Print("Data refreshed.")
    elseif command == "camps" or command == "camp" then
        if FC.UI.ShowCamps then FC.UI:ShowCamps() end
    elseif command == "travel" then
        if FC.UI.ShowTravel then FC.UI:ShowTravel() end
    elseif command == "journey" then
        if FC.UI.ShowJourney then FC.UI:ShowJourney() end
    elseif command == "legacy" then
        if FC.UI.ShowLegacyTracker then FC.UI:ShowLegacyTracker() end
    elseif command == "settings" or command == "options" then
        if FC.UI.ShowSettings then FC.UI:ShowSettings() end
    elseif command == "item" then
        if argument == "" then FC:Print("Usage: /fc item <name or item ID>") else FC.Inventory:PrintSearch(argument) end
    elseif command == "characters" or command == "chars" then
        FC:PrintCharacters()
    elseif command == "goal" then
        handleGoal(argument)
    elseif command == "ungoal" or command == "removegoal" then
        local recipeID = tonumber(argument)
        if recipeID and FC.CraftingGoals:RemoveGoal(recipeID) then
            FC:Print("Removed crafting goal for recipe " .. recipeID .. ".")
        else
            FC:Print("No crafting goal found for that recipe ID.")
        end
    elseif command == "goals" then
        FC.CraftingGoals:PrintGoals()
    elseif command == "pin" then
        handlePin(argument)
    elseif command == "pins" then
        if FC.Goals then FC.Goals:PrintGoals() end
    elseif command == "unpin" then
        if FC.Goals and FC.Goals:Remove(argument) then FC:Print("Removed personal goal #" .. tostring(argument) .. ".") else FC:Print("Unknown personal goal ID.") end
    elseif command == "done" then
        local goal = FC.Goals and FC.Goals:GetGoal(argument)
        if goal then
            local completed = not goal.completed
            FC.Goals:SetCompleted(argument, completed)
            FC:Print(string.format("Goal #%s is now %s.", tostring(argument), completed and "complete" or "active"))
        else
            FC:Print("Unknown personal goal ID.")
        end
    elseif command == "mode" then
        handleMode(argument)
    elseif command == "minimap" then
        handleMinimap(argument)
    elseif command == "dump" or command == "diagnostics" then
        FC:PrintDiagnostics()
    elseif command == "version" then
        FC:Print(string.format("Addon %s | Client %s | Interface %s", tostring(FC.version), tostring(FC.Client.version), tostring(FC.Client.interface)))
    elseif command == "debug" then
        argument = string.lower(argument or "")
        if argument == "on" then FC.DB.settings.debug = true; FC:Print("Debug logging enabled.")
        elseif argument == "off" then FC.DB.settings.debug = false; FC:Print("Debug logging disabled.")
        else FC:Print("Debug logging is", FC.DB.settings.debug and "ON" or "OFF") end
    else
        showHelp()
    end
end

-- Expose a stable hook before ADDON_LOADED so later extension files can wrap the
-- handler. The actual SlashCmdList registration happens only after initialization.
FC.HandleSlashCommand = handleSlashCommand

local function safeRegisterRuntimeEvent(event)
    local ok, result = pcall(eventFrame.RegisterEvent, eventFrame, event)
    if not ok or result == false then
        FC.Logger:Debug("CORE", "Event unavailable on this client: %s", tostring(event))
    end
end

local function initializeAddon()
    FC:DetectClient()
    FC:InitializeDatabase()
    FC.API:RefreshCapabilities()
    FC:InitializeModules()

    for _, event in ipairs(runtimeEvents) do safeRegisterRuntimeEvent(event) end

    SLASH_FOREVERCOMPANION1 = "/fc"
    SLASH_FOREVERCOMPANION2 = "/forevercompanion"
    SlashCmdList.FOREVERCOMPANION = FC.HandleSlashCommand or handleSlashCommand

    FC.ready = true
    FC.Logger:Debug("CORE", "Loaded on client %s (interface %s)", tostring(FC.Client.version), tostring(FC.Client.interface))
    if not FC.Client.isForever then FC.Logger:Warn("CORE", "This build is intended for WoW Forever (16xxx interface).") end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon ~= addonName then return end
        initializeAddon()
        return
    end

    FC:DispatchModuleEvent(event, ...)

    if dashboardRefreshEvents[event] and FC.UI and FC.UI.frame and FC.UI.frame:IsShown() then
        FC.UI:RefreshDashboard()
    end
end)
