local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local TOOL_KEYS = {
    ShowCharacters = "CHARACTERS",
    ShowAccountRecipes = "ACCOUNT_RECIPES",
    ShowItems = "ITEM_INTELLIGENCE",
    ShowMilestones = "MILESTONES",
    ShowSuggestions = "SMART_SUGGESTIONS",
    ShowLegacyTracker = "LEGACY",
    ShowJourney = "JOURNEY",
    ShowGoals = "GOALS",
    ShowPreparationChecklist = "PREPARATION_CHECKLIST",
    ShowCamps = "CAMPS",
    ShowTravel = "TRAVEL",
    ShowTravelRoutes = "ROUTES",
    ShowGroups = "GROUPS",
    ShowProfessionPlanner = "PROFESSION_PLANNER",
    ShowRecipeSources = "RECIPE_SOURCES",
    ShowCacheManager = "CACHE_MANAGER",
    ShowDataTransfer = "PLANNING_TRANSFER",
    ShowSettings = "SETTINGS",
    ShowDiagnostics = "DIAGNOSTICS",
}

local HEADING_KEYS = {
    ["ACCOUNT & COLLECTION"] = "FEATURE_GROUP_ACCOUNT",
    ["PROGRESS & JOURNEY"] = "FEATURE_GROUP_PROGRESS",
    ["PREPARE & TRAVEL"] = "FEATURE_GROUP_PREPARE",
    ["TOOLS"] = "FEATURE_GROUP_TOOLS",
    ["ACCOUNT & SAMMLUNG"] = "FEATURE_GROUP_ACCOUNT",
    ["FORTSCHRITT & REISE"] = "FEATURE_GROUP_PROGRESS",
    ["VORBEREITUNG & REISEN"] = "FEATURE_GROUP_PREPARE",
    ["WERKZEUGE"] = "FEATURE_GROUP_TOOLS",
}

local function setText(fontString, text, color)
    if not fontString then return end
    fontString:SetText(text or "")
    if color then fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1) end
end

local function setButton(button, key)
    if button and button.SetFCText then button:SetFCText(FC:GetText(key)) end
end

local function localizeFeatureDrawer(frame)
    local drawer = frame and frame.fcFeatureDrawer
    if not drawer then return end

    if drawer.title then drawer.title:SetText(FC:GetText("FEATURE_DRAWER_TITLE")) end

    for _, button in ipairs(drawer.entries or {}) do
        local tool = button.fcTool
        local key = tool and TOOL_KEYS[tool.method]
        if key then setButton(button, key) end
    end

    -- GetRegions exists on normal WoW frames, but keep this presentation-only
    -- pass optional so alternate frame implementations/test harnesses cannot
    -- break the entire dashboard just because region enumeration is missing.
    if type(drawer.GetRegions) == "function" then
        for _, region in ipairs({ drawer:GetRegions() }) do
            if region and region.IsObjectType and region:IsObjectType("FontString") and region.GetText then
                local current = region:GetText()
                local key = HEADING_KEYS[current]
                if key then region:SetText(FC:GetText(key)) end
            end
        end
    end
end

local function localizeStaticMain(frame)
    if not frame then return end

    if frame.title then frame.title:SetText(FC:GetText("MAIN_TITLE")) end
    setButton(frame.refreshButton, "REFRESH")
    setButton(frame.fcFeaturesButton, "FEATURES")

    if frame.fcSearchHint then frame.fcSearchHint:SetText(FC:GetText("SEARCH_EVERYTHING")) end
    if frame.fcSearchResults and frame.fcSearchResults.title then
        frame.fcSearchResults.title:SetText(FC:GetText("SEARCH_RESULTS"))
    end
    if frame.fcSearchResults and frame.fcSearchResults.viewAllButton then
        setButton(frame.fcSearchResults.viewAllButton, "VIEW_ALL_RESULTS")
    end

    local tabs = {
        Overview = "TAB_OVERVIEW",
        Professions = "TAB_PROFESSIONS",
        Inventory = "TAB_INVENTORY",
        Preparation = "TAB_PREPARATION",
        Journey = "TAB_JOURNEY",
    }
    for name, key in pairs(tabs) do setButton(frame.tabs and frame.tabs[name], key) end

    local pages = frame.pages or {}
    local overview = pages.Overview
    if overview then
        if overview.characterCard and overview.characterCard.title then overview.characterCard.title:SetText(FC:GetText("CARD_CURRENT_CHARACTER")) end
        if overview.accountCard and overview.accountCard.title then overview.accountCard.title:SetText(FC:GetText("CARD_ACCOUNT_CHARACTERS")) end
        if overview.suggestionCard and overview.suggestionCard.title then overview.suggestionCard.title:SetText(FC:GetText("CARD_SMART_SUGGESTIONS")) end
    end

    local professions = pages.Professions
    if professions then
        if professions.skillsCard and professions.skillsCard.title then professions.skillsCard.title:SetText(FC:GetText("CARD_PROFESSION_PROGRESS")) end
        if professions.recipesCard and professions.recipesCard.title then professions.recipesCard.title:SetText(FC:GetText("CARD_KNOWN_RECIPES")) end
        if professions.goalsCard and professions.goalsCard.title then professions.goalsCard.title:SetText(FC:GetText("CARD_CRAFTING_GOALS")) end
        if professions.recipeHint then professions.recipeHint:SetText(FC:GetText("RECIPE_CACHE_HINT")) end
        if professions.goalHint then professions.goalHint:SetText(FC:GetText("CRAFTING_GOAL_HINT")) end
    end

    local inventory = pages.Inventory
    if inventory then
        if inventory.searchCard and inventory.searchCard.title then inventory.searchCard.title:SetText(FC:GetText("CARD_ACCOUNT_ITEM_SEARCH")) end
        if inventory.resultsCard and inventory.resultsCard.title then inventory.resultsCard.title:SetText(FC:GetText("CARD_CACHED_RESULTS")) end
        setButton(inventory.searchButton, "SEARCH")
        setButton(inventory.clearButton, "CLEAR")
    end

    local preparation = pages.Preparation
    if preparation then
        if preparation.checkCard and preparation.checkCard.title then preparation.checkCard.title:SetText(FC:GetText("CARD_PREPARATION_CHECKLIST")) end
        if preparation.infoCard and preparation.infoCard.title then preparation.infoCard.title:SetText(FC:GetText("CARD_DUNGEON_READY")) end
    end

    local journey = pages.Journey
    if journey then
        if journey.discoveryCard and journey.discoveryCard.title then journey.discoveryCard.title:SetText(FC:GetText("CARD_DISCOVERY_MODE")) end
        if journey.discoveryText then journey.discoveryText:SetText(FC:GetText("DISCOVERY_DESCRIPTION")) end
        for _, button in ipairs(journey.modeButtons or {}) do
            if button.mode == "EXPLORER" then setButton(button, "DISCOVERY_EXPLORER")
            elseif button.mode == "BALANCED" then setButton(button, "DISCOVERY_BALANCED")
            elseif button.mode == "GUIDE" then setButton(button, "DISCOVERY_GUIDE") end
        end
        if journey.statusCard and journey.statusCard.title then journey.statusCard.title:SetText(FC:GetText("CARD_EXPLORATION_STATUS")) end
        if journey.roadmapCard and journey.roadmapCard.title then journey.roadmapCard.title:SetText(FC:GetText("CARD_COMPANION_STATUS")) end
    end

    localizeFeatureDrawer(frame)
end

local function localizePreparation(frame)
    local page = frame and frame.pages and frame.pages.Preparation
    if not page then return end

    local character = FC:GetCurrentCharacter()
    local preparation = character and character.preparation or {}
    local freeSlots = preparation.freeBagSlots
    local durability = preparation.lowestDurability
    local caps = FC.API and FC.API.capabilities or {}

    local bagColor = freeSlots and (freeSlots <= 2 and Theme.colors.red or (freeSlots <= 5 and Theme.colors.yellow or Theme.colors.green)) or Theme.colors.muted
    local duraColor = durability and (durability <= 25 and Theme.colors.red or (durability <= 50 and Theme.colors.yellow or Theme.colors.green)) or Theme.colors.green

    setText(page.checkLines[1], freeSlots and FC:GetText("PREP_FREE_SLOTS", freeSlots) or FC:GetText("PREP_BAG_UNAVAILABLE"), bagColor)
    setText(page.checkLines[2], durability and FC:GetText("PREP_LOWEST_DURABILITY", durability) or FC:GetText("PREP_NO_DAMAGE"), duraColor)
    setText(page.checkLines[3], FC:GetText("PREP_CACHE_ACTIVE"), Theme.colors.green)
    setText(page.checkLines[4], FC:GetText(caps.containers and "PREP_INVENTORY_API_AVAILABLE" or "PREP_INVENTORY_API_UNAVAILABLE"), caps.containers and Theme.colors.green or Theme.colors.yellow)
    setText(page.checkLines[5], FC:GetText(caps.recipeSchematic and "PREP_CRAFT_API_AVAILABLE" or "PREP_CRAFT_API_UNAVAILABLE"), caps.recipeSchematic and Theme.colors.green or Theme.colors.yellow)
    setText(page.checkLines[6], FC:GetText("PREP_CLASS_CONSUMABLES"), Theme.colors.muted)
    setText(page.checkLines[7], FC:GetText("PREP_HEARTH_AMMO"), Theme.colors.muted)
    setText(page.checkLines[8], FC:GetText("PREP_CAMP"), Theme.colors.muted)

    local found = false
    for _, suggestion in ipairs(FC.Suggestions and FC.Suggestions:GetTop(12) or {}) do
        if suggestion.category == "Preparation" then found = true break end
    end
    if not found and page.infoLines and page.infoLines[1] then
        setText(page.infoLines[1], FC:GetText("PREP_NO_WARNING"), Theme.colors.green)
    end
end

local function localizeJourneyStatus(frame)
    local page = frame and frame.pages and frame.pages.Journey
    if not page then return end

    local legacy = FC.Legacy and FC.Legacy:GetSnapshot() or nil
    if legacy then
        setText(page.statusLines[1], FC:GetText("STATUS_LEGACY_READY", tonumber(legacy.completed) or 0, tonumber(legacy.total) or 0, tonumber(legacy.remaining) or 0), Theme.colors.green)
    elseif FC.API.capabilities and FC.API.capabilities.legacy then
        setText(page.statusLines[1], FC:GetText("STATUS_LEGACY_WAITING"), Theme.colors.yellow)
    else
        setText(page.statusLines[1], FC:GetText("STATUS_LEGACY_UNAVAILABLE"), Theme.colors.muted)
    end

    local travel = FC.Travel and FC.Travel:GetSnapshot() or nil
    local unknown = 0
    for _, node in ipairs(travel and travel.nodes or {}) do if node.isUndiscovered == true then unknown = unknown + 1 end end
    if travel then
        setText(page.statusLines[2], FC:GetText("STATUS_TRAVEL_READY", #(travel.nodes or {}), unknown), Theme.colors.green)
    elseif FC.API.capabilities and FC.API.capabilities.travel then
        setText(page.statusLines[2], FC:GetText("STATUS_TRAVEL_WAITING"), Theme.colors.yellow)
    else
        setText(page.statusLines[2], FC:GetText("STATUS_TRAVEL_UNAVAILABLE"), Theme.colors.muted)
    end

    local journey = FC.Journey and FC.Journey:GetSnapshot() or nil
    if journey then
        setText(page.statusLines[3], FC:GetText("STATUS_JOURNEY_READY", #(journey.opportunities or {}), tostring(journey.mode or "BALANCED")), Theme.colors.green)
    else
        setText(page.statusLines[3], FC:GetText("STATUS_JOURNEY_WAITING"), Theme.colors.muted)
    end

    local camp = FC.Camps and FC.Camps:GetSnapshot() or nil
    if camp then
        setText(page.statusLines[4], FC:GetText("STATUS_CAMPS_READY", FC:GetText(camp.benefit and "STATUS_CAMPS_ACTIVE" or "STATUS_CAMPS_NOT_DETECTED"), #(camp.contributions or {})), Theme.colors.green)
    elseif FC.API.capabilities and FC.API.capabilities.camps then
        setText(page.statusLines[4], FC:GetText("STATUS_CAMPS_WAITING"), Theme.colors.yellow)
    else
        setText(page.statusLines[4], FC:GetText("STATUS_CAMPS_UNAVAILABLE"), Theme.colors.muted)
    end

    local storage = FC.API.capabilities and FC.API.capabilities.storage
    setText(page.statusLines[5], FC:GetText(storage and "STATUS_STORAGE_READY" or "STATUS_STORAGE_UNAVAILABLE"), storage and Theme.colors.green or Theme.colors.muted)

    local roadmap = { "ROADMAP_CAMPS", "ROADMAP_TRAVEL", "ROADMAP_JOURNEY", "ROADMAP_FEATURES", "ROADMAP_VALIDATION" }
    for i, key in ipairs(roadmap) do setText(page.roadmapLines[i], FC:GetText(key), i <= 4 and Theme.colors.green or Theme.colors.gold) end
end

function UI:ApplyPrimaryLocalization()
    local frame = self.frame
    if not frame then return end
    localizeStaticMain(frame)
    if frame.subtitle then
        frame.subtitle:SetText(FC:GetText("MAIN_SUBTITLE", tostring(FC.Client.interface or "?"), FC.Suggestions and FC.Suggestions:Count() or 0, tostring(FC.DB and FC.DB.settings and FC.DB.settings.discoveryMode or "BALANCED")))
    end
    localizePreparation(frame)
    localizeJourneyStatus(frame)
end

local previousCreateMainFrame = UI.CreateMainFrame
function UI:CreateMainFrame(...)
    local frame = previousCreateMainFrame(self, ...)
    localizeStaticMain(frame)
    return frame
end

local previousRefreshDashboard = UI.RefreshDashboard
function UI:RefreshDashboard(...)
    previousRefreshDashboard(self, ...)
    self:ApplyPrimaryLocalization()
end

if UI.RefreshSettingsView then
    local previousRefreshSettingsView = UI.RefreshSettingsView
    function UI:RefreshSettingsView(...)
        previousRefreshSettingsView(self, ...)
        self:ApplyPrimaryLocalization()
    end
end
