local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local SOURCE_ACTIONS = {
    Legacy = "ShowLegacyTracker",
    Camps = "ShowCamps",
    Travel = "ShowTravel",
    Journey = "ShowJourney",
    Dungeons = "ShowJourney",
    Goals = "ShowGoals",
    Groups = "ShowGroups",
    Milestones = "ShowMilestones",
    ProfessionPlanner = "ShowProfessionPlanner",
    Professions = "ShowProfessionPlanner",
    CraftingGoals = "ShowProfessionPlanner",
    AccountRecipes = "ShowAccountRecipes",
    PreparationChecklist = "ShowPreparationChecklist",
}

local CATEGORY_ACTIONS = {
    Quest = "ShowJourney",
    Legacy = "ShowLegacyTracker",
    Camp = "ShowCamps",
    Travel = "ShowTravel",
    Journey = "ShowJourney",
    Dungeon = "ShowJourney",
    Goal = "ShowGoals",
    Personal = "ShowGoals",
    Group = "ShowGroups",
    Profession = "ShowProfessionPlanner",
    Preparation = "ShowPreparationChecklist",
    Inventory = "ShowItems",
}

local function exactTarget(suggestion)
    local metadata = type(suggestion and suggestion.metadata) == "table" and suggestion.metadata or {}

    if metadata.goalID ~= nil and FC:IsModuleEnabled("Goals") and type(UI.ShowGoals) == "function" then
        return "ShowGoals", metadata.goalID
    end
    if metadata.challengeID ~= nil and FC:IsModuleEnabled("Legacy") and type(UI.ShowLegacyTracker) == "function" then
        return "ShowLegacyTracker", metadata.challengeID
    end
    if metadata.routeID ~= nil
        and FC:IsModuleEnabled("Travel")
        and FC:IsModuleEnabled("TravelRoutes")
        and type(UI.ShowTravelRoutes) == "function"
    then
        return "ShowTravelRoutes", metadata.routeID
    end
    return nil, nil
end

local function resolveAction(suggestion)
    if not suggestion then return nil, nil end

    local exactMethod, exactID = exactTarget(suggestion)
    if exactMethod then return exactMethod, exactID end

    local source = tostring(suggestion.source or "")
    -- Journey is an aggregator. When it has no exact target, the category is
    -- more useful than the generic source (e.g. Camp -> Camps, Dungeon -> Journey).
    if source == "Journey" and CATEGORY_ACTIONS[suggestion.category] then
        return CATEGORY_ACTIONS[suggestion.category], nil
    end
    if SOURCE_ACTIONS[source] then return SOURCE_ACTIONS[source], nil end
    if CATEGORY_ACTIONS[suggestion.category] then return CATEGORY_ACTIONS[suggestion.category], nil end
    return "ShowSuggestions", nil
end

local function openSuggestion(suggestion)
    local method, targetID = resolveAction(suggestion)
    local callback = method and UI[method]
    if type(callback) == "function" then
        callback(UI, targetID)
        return true
    end
    if type(UI.ShowSuggestions) == "function" then
        UI:ShowSuggestions()
        return true
    end
    return false
end

UI.OpenSuggestion = openSuggestion

local previousCreateMainFrame = UI.CreateMainFrame
function UI:CreateMainFrame(...)
    local frame = previousCreateMainFrame(self, ...)
    if not frame or frame.fcSuggestionActions then return frame end
    frame.fcSuggestionActions = true

    local page = frame.pages and frame.pages.Overview
    if not page or not page.suggestionCard or not page.suggestionLines then return frame end

    page.suggestionButtons = {}
    for i, line in ipairs(page.suggestionLines) do
        local hit = CreateFrame("Button", nil, page.suggestionCard)
        hit:SetPoint("TOPLEFT", line, "TOPLEFT", -6, 5)
        hit:SetSize(426, 48)
        hit:RegisterForClicks("LeftButtonUp")
        hit:SetScript("OnClick", function(self)
            openSuggestion(self.fcSuggestion)
        end)
        hit:SetScript("OnEnter", function(self)
            if not self.fcSuggestion then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(tostring(self.fcSuggestion.title or FC:GetText("SMART_SUGGESTIONS")), 1.00, 0.82, 0.28)
            if self.fcSuggestion.description then
                GameTooltip:AddLine(tostring(self.fcSuggestion.description), 1, 1, 1, true)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(FC:GetText("SUGGESTION_OPEN_RELATED_VIEW"), 0.45, 0.82, 1.00)
            GameTooltip:Show()
        end)
        hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
        page.suggestionButtons[i] = hit
    end

    local manage = Theme:CreateButton(page.suggestionCard, FC:GetText("MANAGE_SUGGESTIONS"), 150, 28)
    manage:SetPoint("BOTTOMRIGHT", page.suggestionCard, "BOTTOMRIGHT", -12, 10)
    manage:SetScript("OnClick", function()
        if UI.ShowSuggestions then UI:ShowSuggestions() end
    end)
    page.manageSuggestionsButton = manage

    return frame
end

local previousRefreshDashboard = UI.RefreshDashboard
function UI:RefreshDashboard(...)
    previousRefreshDashboard(self, ...)
    local page = self.frame and self.frame.pages and self.frame.pages.Overview
    if not page or not page.suggestionButtons then return end

    if page.manageSuggestionsButton and page.manageSuggestionsButton.SetFCText then
        page.manageSuggestionsButton:SetFCText(FC:GetText("MANAGE_SUGGESTIONS"))
    end

    local suggestions = FC.Suggestions and FC.Suggestions:GetTop(#page.suggestionButtons) or {}
    for i, button in ipairs(page.suggestionButtons) do
        local suggestion = suggestions[i]
        button.fcSuggestion = suggestion
        button:SetShown(suggestion ~= nil)
    end
end
