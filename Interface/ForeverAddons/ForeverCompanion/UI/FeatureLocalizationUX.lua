local _, FC = ...

local UI = FC.UI

local function setButton(button, key)
    if button and button.SetFCText then button:SetFCText(FC:GetText(key)) end
end

local function setLabel(label, key)
    if label then label:SetText(FC:GetText(key)) end
end

local function localizeCamps(frame)
    if not frame then return end
    setLabel(frame.title, "WINDOW_CAMPS")
    setButton(frame.refreshButton, "REFRESH")
    setButton(frame.finderButton, "OPEN_CAMP_FINDER")
    setLabel(frame.benefitTitle, "CURRENT_CAMP_STATE")
    setLabel(frame.contributionTitle, "POTENTIAL_CONTRIBUTIONS")
    setLabel(frame.catalogTitle, "CAMP_PROGRESSION")
end

local function localizeTravel(frame)
    if not frame then return end
    setLabel(frame.title, "WINDOW_TRAVEL")
    setButton(frame.refreshButton, "REFRESH")
    setLabel(frame.flightTitle, "FLIGHT_POINTS")
    setLabel(frame.groupTitle, "GROUP_TRAVEL_OVERVIEW")
    setLabel(frame.cacheTitle, "ACCOUNT_TRAVEL_CACHE")
    if frame.routesButton then setButton(frame.routesButton, "ROUTES") end
end

local function localizeJourney(frame)
    if not frame then return end
    setLabel(frame.title, "WINDOW_JOURNEY")
    setButton(frame.refreshButton, "REFRESH")
    setLabel(frame.opportunityTitle, "JOURNEY_USEFUL_NOW")
    setLabel(frame.questTitle, "VISIBLE_QUEST_CONTEXT")
end

local function localizeItems(frame)
    if not frame then return end
    setLabel(frame.title, "WINDOW_ITEMS")
    setButton(frame.searchButton, "ANALYZE")
end

local function localizeGroups(frame)
    if not frame then return end
    setLabel(frame.title, "WINDOW_GROUPS")
    setButton(frame.refreshButton, "REFRESH")
    setLabel(frame.memberTitle, "MEMBERS_TRAVEL_CONTEXT")
    setLabel(frame.playerTitle, "YOUR_PREPARATION")
end

local function localizeMilestones(frame)
    if not frame then return end
    setLabel(frame.title, "WINDOW_MILESTONES")
    setButton(frame.refreshButton, "REFRESH")
end

local function localizeProfessionPlanner(frame)
    if not frame then return end
    setLabel(frame.title, "WINDOW_PROFESSION_PLANNER")
    setLabel(frame.stageTitle, "PROGRESSION_STEPS")
    setButton(frame.pinButton, "PIN_CAP_GOAL")
end

local function localizePreparationChecklist(frame)
    if not frame then return end
    setLabel(frame.title, "WINDOW_PREP_CHECKLIST")
    setButton(frame.addButton, "ADD_ITEM")
    setButton(frame.resetButton, "RESET_ALL")
    setButton(frame.clearDoneButton, "REMOVE_COMPLETED")
    for _, row in ipairs(frame.rows or {}) do
        setButton(row.remove, "REMOVE")
    end
end

local function localizeSuggestions(frame)
    if not frame then return end
    setLabel(frame.title, "WINDOW_SUGGESTIONS")
    setButton(frame.refreshButton, "REFRESH")
    setButton(frame.modeButton, frame.showSnoozed and "SHOW_ACTIVE" or "SHOW_SNOOZED")
    setButton(frame.clearButton, "WAKE_ALL")
    for _, card in ipairs(frame.rows or {}) do
        setButton(card.pin, "PIN_GOAL")
        if card.snooze then setButton(card.snooze, card.snooze.wakeMode and "WAKE" or "SNOOZE_1H") end
    end
end

local function localizeMainShortcuts(frame)
    if not frame then return end
    setButton(frame.fcCampsButton, "CAMPS")
    setButton(frame.fcTravelButton, "TRAVEL")
    setButton(frame.fcJourneyButton, "JOURNEY")
    setButton(frame.fcItemsButton, "ITEM_INTELLIGENCE")
    setButton(frame.fcMilestonesButton, "MILESTONES")
    setButton(frame.fcProfessionPlannerButton, "PLANNER")
    setButton(frame.fcPreparationChecklistButton, "PERSONAL_CHECKLIST")
    setButton(frame.fcSuggestionsButton, "MANAGE_SUGGESTIONS")
end

local previousCreateCampsFrame = UI.CreateCampsFrame
function UI:CreateCampsFrame(...)
    local frame = previousCreateCampsFrame(self, ...)
    localizeCamps(frame)
    return frame
end
local previousRefreshCampsView = UI.RefreshCampsView
function UI:RefreshCampsView(...)
    previousRefreshCampsView(self, ...)
    localizeCamps(self.campsFrame)
end

local previousCreateTravelFrame = UI.CreateTravelFrame
function UI:CreateTravelFrame(...)
    local frame = previousCreateTravelFrame(self, ...)
    localizeTravel(frame)
    return frame
end
local previousRefreshTravelView = UI.RefreshTravelView
function UI:RefreshTravelView(...)
    previousRefreshTravelView(self, ...)
    localizeTravel(self.travelFrame)
end

local previousCreateJourneyFrame = UI.CreateJourneyFrame
function UI:CreateJourneyFrame(...)
    local frame = previousCreateJourneyFrame(self, ...)
    localizeJourney(frame)
    return frame
end
local previousRefreshJourneyView = UI.RefreshJourneyView
function UI:RefreshJourneyView(...)
    previousRefreshJourneyView(self, ...)
    localizeJourney(self.journeyFrame)
end

local previousCreateItemsFrame = UI.CreateItemsFrame
function UI:CreateItemsFrame(...)
    local frame = previousCreateItemsFrame(self, ...)
    localizeItems(frame)
    return frame
end
local previousRefreshItemsView = UI.RefreshItemsView
function UI:RefreshItemsView(...)
    previousRefreshItemsView(self, ...)
    localizeItems(self.itemsFrame)
end

local previousCreateGroupsFrame = UI.CreateGroupsFrame
function UI:CreateGroupsFrame(...)
    local frame = previousCreateGroupsFrame(self, ...)
    localizeGroups(frame)
    return frame
end
local previousRefreshGroupsView = UI.RefreshGroupsView
function UI:RefreshGroupsView(...)
    previousRefreshGroupsView(self, ...)
    localizeGroups(self.groupsFrame)
end

local previousCreateMilestonesFrame = UI.CreateMilestonesFrame
function UI:CreateMilestonesFrame(...)
    local frame = previousCreateMilestonesFrame(self, ...)
    localizeMilestones(frame)
    return frame
end
local previousRefreshMilestonesView = UI.RefreshMilestonesView
function UI:RefreshMilestonesView(...)
    previousRefreshMilestonesView(self, ...)
    localizeMilestones(self.milestonesFrame)
end

local previousCreateProfessionPlannerFrame = UI.CreateProfessionPlannerFrame
function UI:CreateProfessionPlannerFrame(...)
    local frame = previousCreateProfessionPlannerFrame(self, ...)
    localizeProfessionPlanner(frame)
    return frame
end
local previousRefreshProfessionPlannerView = UI.RefreshProfessionPlannerView
function UI:RefreshProfessionPlannerView(...)
    previousRefreshProfessionPlannerView(self, ...)
    localizeProfessionPlanner(self.professionPlannerFrame)
end

local previousCreatePreparationChecklistFrame = UI.CreatePreparationChecklistFrame
function UI:CreatePreparationChecklistFrame(...)
    local frame = previousCreatePreparationChecklistFrame(self, ...)
    localizePreparationChecklist(frame)
    return frame
end
local previousRefreshPreparationChecklistView = UI.RefreshPreparationChecklistView
function UI:RefreshPreparationChecklistView(...)
    previousRefreshPreparationChecklistView(self, ...)
    localizePreparationChecklist(self.preparationChecklistFrame)
end

local previousCreateSuggestionsFrame = UI.CreateSuggestionsFrame
function UI:CreateSuggestionsFrame(...)
    local frame = previousCreateSuggestionsFrame(self, ...)
    localizeSuggestions(frame)
    return frame
end
local previousRefreshSuggestionsView = UI.RefreshSuggestionsView
function UI:RefreshSuggestionsView(...)
    previousRefreshSuggestionsView(self, ...)
    localizeSuggestions(self.suggestionsFrame)
end

local previousCreateMainFrame = UI.CreateMainFrame
function UI:CreateMainFrame(...)
    local frame = previousCreateMainFrame(self, ...)
    localizeMainShortcuts(frame)
    return frame
end

local previousRefreshDashboard = UI.RefreshDashboard
function UI:RefreshDashboard(...)
    previousRefreshDashboard(self, ...)
    localizeMainShortcuts(self.frame)
end

local previousRefreshSettingsView = UI.RefreshSettingsView
function UI:RefreshSettingsView(...)
    previousRefreshSettingsView(self, ...)
    localizeCamps(self.campsFrame)
    localizeTravel(self.travelFrame)
    localizeJourney(self.journeyFrame)
    localizeItems(self.itemsFrame)
    localizeGroups(self.groupsFrame)
    localizeMilestones(self.milestonesFrame)
    localizeProfessionPlanner(self.professionPlannerFrame)
    localizePreparationChecklist(self.preparationChecklistFrame)
    localizeSuggestions(self.suggestionsFrame)
    localizeMainShortcuts(self.frame)
end
