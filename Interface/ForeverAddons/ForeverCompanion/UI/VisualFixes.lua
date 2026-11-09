local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local function hideButton(button)
    if not button then return end
    button:Hide()
    if type(button.EnableMouse) == "function" then button:EnableMouse(false) end
end

local function placeButton(button, point, relativeTo, relativePoint, x, y, width, height)
    if not button then return end
    button:ClearAllPoints()
    button:SetPoint(point, relativeTo, relativePoint, x, y)
    if width and height then button:SetSize(width, height) end
end

local function setOpaqueDialog(frame)
    if not frame then return end
    if frame.bg then
        frame.bg:SetColorTexture(Theme.colors.navy[1], Theme.colors.navy[2], Theme.colors.navy[3], 1)
    end
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    if type(frame.SetToplevel) == "function" then frame:SetToplevel(true) end
end

local function setPagerVisible(frame, prefix, visible)
    if not frame then return end
    local names = { "Prev", "Next", "PageText" }
    for _, suffix in ipairs(names) do
        local control = frame[prefix .. suffix]
        if control then control:SetShown(visible == true) end
    end
end

local function placePager(frame, prefix, nextPoint, relativeTo, relativePoint, x, y)
    if not frame then return end
    local nextButton = frame[prefix .. "Next"]
    local prevButton = frame[prefix .. "Prev"]
    local pageText = frame[prefix .. "PageText"]
    if not nextButton or not prevButton or not pageText then return end

    nextButton:ClearAllPoints()
    nextButton:SetPoint(nextPoint, relativeTo, relativePoint, x, y)
    prevButton:ClearAllPoints()
    prevButton:SetPoint("RIGHT", nextButton, "LEFT", -4, 0)
    pageText:ClearAllPoints()
    pageText:SetPoint("RIGHT", prevButton, "LEFT", -6, 0)
    pageText:SetWidth(55)
    pageText:SetJustifyH("RIGHT")
end

local function applyHeaderLayout(frame)
    if not frame or not frame.header then return end

    -- These legacy quick buttons are superseded by the single Features drawer.
    hideButton(frame.fcGoalsButton)
    hideButton(frame.fcSettingsButton)
    hideButton(frame.fcGroupsButton)
    hideButton(frame.fcHubButton)

    if frame.title then frame.title:SetWidth(275) end
    if frame.subtitle then frame.subtitle:SetWidth(280) end

    if frame.closeButton then
        placeButton(frame.closeButton, "TOPRIGHT", frame.header, "TOPRIGHT", -12, -13, 32, 30)
    end

    if frame.refreshButton and frame.closeButton then
        placeButton(frame.refreshButton, "RIGHT", frame.closeButton, "LEFT", -8, 0, 108, 30)
    end

    if frame.fcFeaturesButton and frame.refreshButton then
        placeButton(frame.fcFeaturesButton, "RIGHT", frame.refreshButton, "LEFT", -8, 0, 112, 30)
    end

    if frame.fcSearchBox and frame.fcFeaturesButton then
        frame.fcSearchBox:ClearAllPoints()
        frame.fcSearchBox:SetSize(248, 30)
        frame.fcSearchBox:SetPoint("RIGHT", frame.fcFeaturesButton, "LEFT", -12, 0)
    end
end

local function applyOverviewLayout(frame)
    local page = frame and frame.pages and frame.pages.Overview
    if not page then return end

    if frame.fcCharactersButton and page.accountCard then
        frame.fcCharactersButton:SetFCText(FC:GetText("CHARACTERS"))
        placeButton(frame.fcCharactersButton, "BOTTOMLEFT", page.accountCard, "BOTTOMLEFT", 14, 12, 174, 30)
        frame.fcCharactersButton:Show()
        frame.fcCharactersButton:EnableMouse(true)
    end

    if frame.fcMilestonesButton and page.accountCard then
        frame.fcMilestonesButton:SetFCText(FC:GetText("MILESTONES"))
        placeButton(frame.fcMilestonesButton, "BOTTOMRIGHT", page.accountCard, "BOTTOMRIGHT", -14, 12, 138, 30)
        frame.fcMilestonesButton:Show()
        frame.fcMilestonesButton:EnableMouse(true)
    end

    -- Suggestions.lua still creates the original shortcut. SuggestionActions.lua
    -- owns the modern management button, so keep only one visible entry point.
    hideButton(frame.fcSuggestionsButton)

    if page.suggestionLines and page.suggestionLines[8] then
        page.suggestionLines[8]:Hide()
    end
    if page.suggestionButtons and page.suggestionButtons[8] then
        page.suggestionButtons[8]:Hide()
    end

    if page.manageSuggestionsButton and page.suggestionCard then
        page.manageSuggestionsButton:SetFCText(FC:GetText("MANAGE_SUGGESTIONS"))
        placeButton(page.manageSuggestionsButton, "BOTTOMRIGHT", page.suggestionCard, "BOTTOMRIGHT", -14, 12, 180, 30)
        page.manageSuggestionsButton:Show()
        page.manageSuggestionsButton:EnableMouse(true)
    end
end

local function applyProfessionsLayout(frame)
    if not frame then return end

    -- These tools remain available from Features and global search. Removing the
    -- duplicate card shortcuts avoids title collisions at German/Retail UI scale.
    hideButton(frame.fcProfessionPlannerButton)
    hideButton(frame.fcAccountRecipesButton)
    hideButton(frame.fcRecipeSourcesButton)
end

local function applyJourneyLayout(frame)
    local page = frame and frame.pages and frame.pages.Journey
    local card = page and page.roadmapCard
    if not card then return end

    -- The fifth roadmap row is an internal validation note and used to sit below
    -- the two action buttons. Keep runtime validation in Diagnostics instead.
    if page.roadmapLines and page.roadmapLines[5] then
        page.roadmapLines[5]:Hide()
    end

    -- Reserve a clean footer for the two action buttons and keep long roadmap
    -- descriptions above it instead of letting wrapped text touch the controls.
    for index, line in ipairs(page.roadmapLines or {}) do
        if index <= 4 then
            line:SetWidth(342)
        end
    end

    if frame.fcTravelButton then
        frame.fcTravelButton:SetFCText(FC:GetText("WINDOW_TRAVEL"))
        placeButton(frame.fcTravelButton, "BOTTOMLEFT", card, "BOTTOMLEFT", 14, 12, 160, 30)
        frame.fcTravelButton:Show()
        frame.fcTravelButton:EnableMouse(true)
    end

    if frame.fcJourneyButton then
        frame.fcJourneyButton:SetFCText(FC:GetText("WINDOW_JOURNEY"))
        placeButton(frame.fcJourneyButton, "BOTTOMRIGHT", card, "BOTTOMRIGHT", -14, 12, 160, 30)
        frame.fcJourneyButton:Show()
        frame.fcJourneyButton:EnableMouse(true)
    end
end

local function applyFeatureDrawerLayout(frame)
    local drawer = frame and frame.fcFeatureDrawer
    if not drawer then return end

    drawer:SetWidth(372)
    if drawer.bg then
        drawer.bg:SetColorTexture(Theme.colors.navy[1], Theme.colors.navy[2], Theme.colors.navy[3], 1)
    end

    for _, button in ipairs(drawer.entries or {}) do
        button:SetWidth(164)
    end
end

local function applyPreparationChecklistLayout(frame)
    if not frame then return end

    -- 760px window: reserve explicit widths for German button labels instead of
    -- chaining the original 455 + 100 + 100 controls beyond the available row.
    if frame.input then
        frame.input:ClearAllPoints()
        frame.input:SetSize(350, 30)
        frame.input:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -98)
    end

    if frame.addButton and frame.input then
        frame.addButton:ClearAllPoints()
        frame.addButton:SetSize(150, 30)
        frame.addButton:SetPoint("LEFT", frame.input, "RIGHT", 10, 0)
    end

    if frame.resetButton and frame.addButton then
        frame.resetButton:ClearAllPoints()
        frame.resetButton:SetSize(140, 30)
        frame.resetButton:SetPoint("LEFT", frame.addButton, "RIGHT", 8, 0)
    end
end

local function ensureTravelIndicators(frame)
    if not frame or frame.fcTravelIndicators then return end
    frame.fcTravelIndicators = {}
    for index, line in ipairs(frame.flightLines or {}) do
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", frame, "TOPLEFT", 44, -136 - ((index - 1) * 36))
        line:SetWidth(366)
        local indicator = Theme:CreateStatusIndicator(frame, 9)
        indicator:SetPoint("TOPLEFT", frame, "TOPLEFT", 25, -140 - ((index - 1) * 36))
        indicator:Hide()
        frame.fcTravelIndicators[index] = indicator
    end
end

local function applyTravelDialogLayout(frame)
    if not frame then return end
    setOpaqueDialog(frame)
    ensureTravelIndicators(frame)

    if frame.flightTitle then
        frame.flightTitle:ClearAllPoints()
        frame.flightTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -104)
    end
    if frame.groupTitle then
        frame.groupTitle:ClearAllPoints()
        frame.groupTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 438, -104)
    end

    placePager(frame, "flight", "TOPLEFT", frame, "TOPLEFT", 386, -96)
    placePager(frame, "travelGroup", "TOPRIGHT", frame, "TOPRIGHT", -22, -96)

    for index, line in ipairs(frame.groupLines or {}) do
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", frame, "TOPLEFT", 444, -136 - ((index - 1) * 40))
        line:SetWidth(366)
    end

    if frame.cacheTitle then
        frame.cacheTitle:ClearAllPoints()
        frame.cacheTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 444, -480)
    end
    if frame.cacheText and frame.cacheTitle then
        frame.cacheText:ClearAllPoints()
        frame.cacheText:SetPoint("TOPLEFT", frame.cacheTitle, "BOTTOMLEFT", 2, -12)
        frame.cacheText:SetWidth(366)
    end
end

local function refreshTravelDialogPolish(frame)
    if not frame then return end
    applyTravelDialogLayout(frame)

    local snapshot = FC.Travel and FC.Travel:GetSnapshot() or nil
    local nodes = snapshot and snapshot.nodes or {}
    local group = FC.Travel and FC.Travel:GetGroupSnapshot() or {}
    local page = math.max(1, tonumber(frame.flightPage) or 1)
    local startIndex = ((page - 1) * 11) + 1
    local mode = FC.DB and FC.DB.settings and FC.DB.settings.discoveryMode or "BALANCED"

    setPagerVisible(frame, "flight", #nodes > 11)
    setPagerVisible(frame, "travelGroup", #group > 9)

    for index, indicator in ipairs(frame.fcTravelIndicators or {}) do
        local node = nodes[startIndex + index - 1]
        if node then
            local unknown = node.isUndiscovered == true
            indicator:SetState(unknown and "warn" or "ok")
            indicator:Show()

            local label = node.name or FC:GetText("TRAVEL_FLIGHT_POINT_FALLBACK", tostring(node.nodeID))
            local detail = ""
            if mode == "GUIDE" and node.x and node.y then
                detail = string.format(" @ %.1f, %.1f", node.x * 100, node.y * 100)
            elseif mode == "EXPLORER" and unknown then
                label = FC:GetText("TRAVEL_UNDISCOVERED_FLIGHT_POINT")
            end
            if frame.flightLines and frame.flightLines[index] then
                frame.flightLines[index]:SetText(tostring(label) .. detail)
                frame.flightLines[index]:SetTextColor(
                    (unknown and Theme.colors.yellow or Theme.colors.muted)[1],
                    (unknown and Theme.colors.yellow or Theme.colors.muted)[2],
                    (unknown and Theme.colors.yellow or Theme.colors.muted)[3], 1)
            end
        else
            indicator:Hide()
        end
    end
end

local function applyJourneyDialogLayout(frame)
    if not frame then return end
    setOpaqueDialog(frame)
    placePager(frame, "opportunity", "TOPLEFT", frame, "TOPLEFT", 500, -96)
    placePager(frame, "quest", "TOPRIGHT", frame, "TOPRIGHT", -22, -96)
end

local function refreshJourneyDialogPolish(frame)
    if not frame then return end
    applyJourneyDialogLayout(frame)
    local snapshot = FC.Journey and FC.Journey:GetSnapshot() or nil
    local opportunities = snapshot and snapshot.opportunities or {}
    local quests = snapshot and snapshot.quests and snapshot.quests.quests or {}
    setPagerVisible(frame, "opportunity", #opportunities > 10)
    setPagerVisible(frame, "quest", #quests > 9)
end

local function applyVisualFixes(frame)
    if not frame then return end
    applyHeaderLayout(frame)
    applyOverviewLayout(frame)
    applyProfessionsLayout(frame)
    applyJourneyLayout(frame)
    applyFeatureDrawerLayout(frame)
end

local previousCreatePreparationChecklistFrame = UI.CreatePreparationChecklistFrame
if type(previousCreatePreparationChecklistFrame) == "function" then
    function UI:CreatePreparationChecklistFrame(...)
        local frame = previousCreatePreparationChecklistFrame(self, ...)
        applyPreparationChecklistLayout(frame)
        return frame
    end
end

local previousCreateTravelFrame = UI.CreateTravelFrame
if type(previousCreateTravelFrame) == "function" then
    function UI:CreateTravelFrame(...)
        local frame = previousCreateTravelFrame(self, ...)
        applyTravelDialogLayout(frame)
        return frame
    end
end

local previousRefreshTravelView = UI.RefreshTravelView
if type(previousRefreshTravelView) == "function" then
    function UI:RefreshTravelView(...)
        previousRefreshTravelView(self, ...)
        refreshTravelDialogPolish(self.travelFrame)
    end
end

local previousCreateJourneyFrame = UI.CreateJourneyFrame
if type(previousCreateJourneyFrame) == "function" then
    function UI:CreateJourneyFrame(...)
        local frame = previousCreateJourneyFrame(self, ...)
        applyJourneyDialogLayout(frame)
        return frame
    end
end

local previousRefreshJourneyView = UI.RefreshJourneyView
if type(previousRefreshJourneyView) == "function" then
    function UI:RefreshJourneyView(...)
        previousRefreshJourneyView(self, ...)
        refreshJourneyDialogPolish(self.journeyFrame)
    end
end

local previousCreateMainFrame = UI.CreateMainFrame
if type(previousCreateMainFrame) == "function" then
    function UI:CreateMainFrame(...)
        local frame = previousCreateMainFrame(self, ...)
        applyVisualFixes(frame)
        return frame
    end
end

local previousRefreshDashboard = UI.RefreshDashboard
if type(previousRefreshDashboard) == "function" then
    function UI:RefreshDashboard(...)
        previousRefreshDashboard(self, ...)
        applyVisualFixes(self.frame)
    end
end

local previousApplyPrimaryLocalization = UI.ApplyPrimaryLocalization
if type(previousApplyPrimaryLocalization) == "function" then
    function UI:ApplyPrimaryLocalization(...)
        previousApplyPrimaryLocalization(self, ...)
        applyVisualFixes(self.frame)
        applyPreparationChecklistLayout(self.preparationChecklistFrame)
        applyTravelDialogLayout(self.travelFrame)
        applyJourneyDialogLayout(self.journeyFrame)
    end
end
