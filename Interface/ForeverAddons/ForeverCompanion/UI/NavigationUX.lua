local _, FC = ...

local UI = FC.UI

local SECONDARY_FIELDS = {
    "charactersFrame",
    "accountRecipesFrame",
    "recipeSourcesFrame",
    "goalsFrame",
    "travelRoutesFrame",
    "cacheManagerFrame",
    "dataTransferFrame",
    "globalSearchFrame",
    "settingsFrame",
    "diagnosticsFrame",
    "suggestionsFrame",
    "legacyFrame",
    "campsFrame",
    "travelFrame",
    "journeyFrame",
    "itemsFrame",
    "groupsFrame",
    "milestonesFrame",
    "professionPlannerFrame",
    "preparationChecklistFrame",
}

local SHOW_WINDOWS = {
    ShowCharacters = "charactersFrame",
    ShowAccountRecipes = "accountRecipesFrame",
    ShowRecipeSources = "recipeSourcesFrame",
    ShowGoals = "goalsFrame",
    ShowTravelRoutes = "travelRoutesFrame",
    ShowCacheManager = "cacheManagerFrame",
    ShowDataTransfer = "dataTransferFrame",
    ShowGlobalSearch = "globalSearchFrame",
    ShowSettings = "settingsFrame",
    ShowDiagnostics = "diagnosticsFrame",
    ShowSuggestions = "suggestionsFrame",
    ShowLegacyTracker = "legacyFrame",
    ShowCamps = "campsFrame",
    ShowTravel = "travelFrame",
    ShowJourney = "journeyFrame",
    ShowItems = "itemsFrame",
    ShowGroups = "groupsFrame",
    ShowMilestones = "milestonesFrame",
    ShowProfessionPlanner = "professionPlannerFrame",
    ShowPreparationChecklist = "preparationChecklistFrame",
}

local function safeShown(frame)
    return frame and type(frame.IsShown) == "function" and frame:IsShown()
end

function UI:FitCompanionFrame(frame)
    if not frame or not UIParent or type(frame.GetWidth) ~= "function" or type(frame.SetScale) ~= "function" then return end

    local frameWidth = tonumber(frame:GetWidth()) or 0
    local frameHeight = tonumber(frame:GetHeight()) or 0
    local parentWidth = type(UIParent.GetWidth) == "function" and (tonumber(UIParent:GetWidth()) or 0) or 0
    local parentHeight = type(UIParent.GetHeight) == "function" and (tonumber(UIParent:GetHeight()) or 0) or 0
    if frameWidth <= 0 or frameHeight <= 0 or parentWidth <= 0 or parentHeight <= 0 then return end

    local horizontal = math.max(100, parentWidth - 40) / frameWidth
    local vertical = math.max(100, parentHeight - 40) / frameHeight
    local scale = math.min(1, horizontal, vertical)
    scale = math.max(0.62, scale)

    frame:SetScale(scale)
    if type(frame.SetClampedToScreen) == "function" then frame:SetClampedToScreen(true) end
end

function UI:HideSecondaryCompanionWindows(exceptField)
    for _, field in ipairs(SECONDARY_FIELDS) do
        local frame = self[field]
        if field ~= exceptField and safeShown(frame) then frame:Hide() end
    end

    local main = self.frame
    if main then
        if main.fcSearchResults and safeShown(main.fcSearchResults) then main.fcSearchResults:Hide() end
        if main.fcFeatureDrawer and safeShown(main.fcFeatureDrawer) then main.fcFeatureDrawer:Hide() end
        if main.fcSearchBox and type(main.fcSearchBox.ClearFocus) == "function" then main.fcSearchBox:ClearFocus() end
    end
end

local previousCreateMainFrame = UI.CreateMainFrame
if type(previousCreateMainFrame) == "function" then
    function UI:CreateMainFrame(...)
        local frame = previousCreateMainFrame(self, ...)
        self:FitCompanionFrame(frame)
        return frame
    end
end

for methodName, frameField in pairs(SHOW_WINDOWS) do
    local method = methodName
    local field = frameField
    local previous = UI[method]
    if type(previous) == "function" then
        UI[method] = function(self, ...)
            self:HideSecondaryCompanionWindows(field)
            local result = previous(self, ...)
            self:FitCompanionFrame(self[field])
            return result
        end
    end
end

local previousToggle = UI.Toggle
if type(previousToggle) == "function" then
    function UI:Toggle(...)
        local frame = self:CreateMainFrame()
        self:FitCompanionFrame(frame)
        return previousToggle(self, ...)
    end
end
