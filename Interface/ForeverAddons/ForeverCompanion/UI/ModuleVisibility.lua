local _, FC = ...

local UI = FC.UI

local guardedViews = {
    ShowLegacyTracker = { "Legacy" },
    ShowCamps = { "Camps" },
    ShowTravel = { "Travel" },
    ShowTravelRoutes = { "Travel", "TravelRoutes" },
    ShowJourney = { "Journey" },
    ShowGoals = { "Goals" },
    ShowItems = { "Items" },
    ShowGroups = { "Groups" },
    ShowMilestones = { "Milestones" },
    ShowProfessionPlanner = { "ProfessionPlanner" },
    ShowAccountRecipes = { "AccountRecipes" },
    ShowRecipeSources = { "RecipeSources" },
    ShowPreparationChecklist = { "PreparationChecklist" },
}

local function requirementsEnabled(requirements)
    for _, moduleName in ipairs(requirements or {}) do
        if not FC:IsModuleEnabled(moduleName) then return false, moduleName end
    end
    return true
end

for methodName, requirements in pairs(guardedViews) do
    local original = UI[methodName]
    if type(original) == "function" then
        UI[methodName] = function(self, ...)
            local enabled = requirementsEnabled(requirements)
            if not enabled then
                if type(UI.ShowSettings) == "function" then UI:ShowSettings() end
                return nil
            end
            return original(self, ...)
        end
    end
end

local buttonModules = {
    fcLegacyButton = "Legacy",
    fcCampsButton = "Camps",
    fcTravelButton = "Travel",
    fcJourneyButton = "Journey",
    fcGoalsButton = "Goals",
    fcItemsButton = "Items",
    fcGroupsButton = "Groups",
    fcMilestonesButton = "Milestones",
    fcProfessionPlannerButton = "ProfessionPlanner",
    fcAccountRecipesButton = "AccountRecipes",
    fcRecipeSourcesButton = "RecipeSources",
    fcPreparationChecklistButton = "PreparationChecklist",
}

local previousRefreshDashboard = UI.RefreshDashboard
function UI:RefreshDashboard(...)
    previousRefreshDashboard(self, ...)
    local frame = self.frame
    if not frame then return end

    for field, moduleName in pairs(buttonModules) do
        local button = frame[field]
        if button then
            if FC:IsModuleEnabled(moduleName) then button:Show() else button:Hide() end
        end
    end

    if self.hubFrame and self.RefreshHubView then self:RefreshHubView() end
end
