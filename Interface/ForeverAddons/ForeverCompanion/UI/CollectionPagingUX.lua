local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local GOAL_PAGE_SIZE = 9
local CHECKLIST_PAGE_SIZE = 10
local ROUTE_PAGE_SIZE = 10
local SUGGESTION_PAGE_SIZE = 8
local MILESTONE_PAGE_SIZE = 11

local CATEGORY_KEYS = {
    Preparation = "CATEGORY_PREPARATION",
    Profession = "CATEGORY_PROFESSION",
    Legacy = "CATEGORY_LEGACY",
    Camp = "CATEGORY_CAMP",
    Travel = "CATEGORY_TRAVEL",
    Dungeon = "CATEGORY_DUNGEON",
    Milestone = "CATEGORY_MILESTONE",
    Goal = "CATEGORY_GOAL",
    Journey = "CATEGORY_JOURNEY",
    Crafting = "CATEGORY_CRAFTING",
    Personal = "CATEGORY_PERSONAL",
    General = "CATEGORY_GENERAL",
}

local function setText(fontString, text, color)
    if not fontString then return end
    color = color or Theme.colors.text
    fontString:SetText(text or "")
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function categoryText(value)
    local text = tostring(value or "General")
    local key = CATEGORY_KEYS[text]
    return key and FC:GetText(key) or text
end

local function clampPage(frame, field, count, pageSize)
    local maxPage = math.max(1, math.ceil(count / pageSize))
    frame[field] = math.max(1, math.min(tonumber(frame[field]) or 1, maxPage))
    return frame[field], maxPage, ((frame[field] - 1) * pageSize) + 1
end

local function createHeaderPager(frame, prefix, rightAnchor)
    local nextButton = Theme:CreateButton(frame, ">", 30, 26)
    nextButton:SetPoint("RIGHT", rightAnchor, "LEFT", -8, 0)
    local prevButton = Theme:CreateButton(frame, "<", 30, 26)
    prevButton:SetPoint("RIGHT", nextButton, "LEFT", -5, 0)
    local pageText = Theme:CreateText(frame, "GameFontHighlightSmall", "")
    pageText:SetPoint("RIGHT", prevButton, "LEFT", -8, 0)
    pageText:SetWidth(90)
    pageText:SetJustifyH("RIGHT")

    frame[prefix .. "Prev"] = prevButton
    frame[prefix .. "Next"] = nextButton
    frame[prefix .. "PageText"] = pageText
    return prevButton, nextButton, pageText
end

local function updatePager(prevButton, nextButton, pageText, page, maxPage)
    if prevButton then
        prevButton:SetEnabled(page > 1)
        prevButton:SetAlpha(page > 1 and 1 or 0.4)
    end
    if nextButton then
        nextButton:SetEnabled(page < maxPage)
        nextButton:SetAlpha(page < maxPage and 1 or 0.4)
    end
    if pageText then pageText:SetText(string.format("%d / %d", page, maxPage)) end
end

-- Goals ---------------------------------------------------------------------
local previousCreateGoalsFrame = UI.CreateGoalsFrame
function UI:CreateGoalsFrame(...)
    local frame = previousCreateGoalsFrame(self, ...)
    if not frame or frame.fcCollectionPaging then return frame end
    frame.fcCollectionPaging = true
    frame.goalPage = 1

    local prev, nextButton = createHeaderPager(frame, "goal", frame.closeButton)
    prev:SetScript("OnClick", function()
        frame.goalPage = math.max(1, (frame.goalPage or 1) - 1)
        UI:RefreshGoalsView()
    end)
    nextButton:SetScript("OnClick", function()
        frame.goalPage = (frame.goalPage or 1) + 1
        UI:RefreshGoalsView()
    end)
    return frame
end

local previousRefreshGoalsView = UI.RefreshGoalsView
function UI:RefreshGoalsView(...)
    previousRefreshGoalsView(self, ...)
    local frame = self.goalsFrame
    if not frame or not frame.fcCollectionPaging then return end

    local goals = FC.Goals and FC.Goals:GetGoals(true) or {}
    local page, maxPage, startIndex = clampPage(frame, "goalPage", #goals, GOAL_PAGE_SIZE)

    for i, row in ipairs(frame.rows or {}) do
        local goal = goals[startIndex + i - 1]
        if goal then
            row.goalID = goal.id
            row.complete.goalID = goal.id
            row.remove.goalID = goal.id
            row:Show()
            local stateKey = goal.completed and "STATE_DONE" or (goal.enabled == false and "STATE_PAUSED" or "STATE_ACTIVE")
            local displayTitle = type(FC.Goals.GetDisplayTitle) == "function" and FC.Goals:GetDisplayTitle(goal) or goal.title
            setText(row.text, string.format("#%s  [%s]  P%d  %s", tostring(goal.id), FC:GetText(stateKey), tonumber(goal.priority) or 0, tostring(displayTitle)),
                goal.completed and Theme.colors.muted or Theme.colors.text)
            row.complete:SetFCText(FC:GetText(goal.completed and "REOPEN" or "DONE"))
            row.remove:SetFCText(FC:GetText("REMOVE"))
        else
            row.goalID = nil
            row.complete.goalID = nil
            row.remove.goalID = nil
            row:Hide()
        end
    end

    updatePager(frame.goalPrev, frame.goalNext, frame.goalPageText, page, maxPage)
end

-- Personal preparation checklist -------------------------------------------
local previousCreatePreparationChecklistFrame = UI.CreatePreparationChecklistFrame
function UI:CreatePreparationChecklistFrame(...)
    local frame = previousCreatePreparationChecklistFrame(self, ...)
    if not frame or frame.fcCollectionPaging then return frame end
    frame.fcCollectionPaging = true
    frame.checklistPage = 1

    local prev, nextButton = createHeaderPager(frame, "checklist", frame.closeButton)
    prev:SetScript("OnClick", function()
        frame.checklistPage = math.max(1, (frame.checklistPage or 1) - 1)
        UI:RefreshPreparationChecklistView()
    end)
    nextButton:SetScript("OnClick", function()
        frame.checklistPage = (frame.checklistPage or 1) + 1
        UI:RefreshPreparationChecklistView()
    end)
    return frame
end

local previousRefreshPreparationChecklistView = UI.RefreshPreparationChecklistView
function UI:RefreshPreparationChecklistView(...)
    previousRefreshPreparationChecklistView(self, ...)
    local frame = self.preparationChecklistFrame
    if not frame or not frame.fcCollectionPaging then return end

    local items = FC.PreparationChecklist and FC.PreparationChecklist:GetItems() or {}
    local page, maxPage, startIndex = clampPage(frame, "checklistPage", #items, CHECKLIST_PAGE_SIZE)

    for i, controls in ipairs(frame.rows or {}) do
        local item = items[startIndex + i - 1]
        if item then
            controls.toggle.itemID = item.id
            controls.remove.itemID = item.id
            controls.toggle:Show()
            controls.remove:Show()
            local displayLabel = type(FC.PreparationChecklist.GetDisplayLabel) == "function"
                and FC.PreparationChecklist:GetDisplayLabel(item) or item.label
            controls.toggle:SetFCText((item.completed and "✓  " or "□  ") .. tostring(displayLabel or ""))
            controls.toggle:SetFCActive(item.completed)
            controls.remove:SetFCText(FC:GetText("REMOVE"))
        else
            controls.toggle.itemID = nil
            controls.remove.itemID = nil
            controls.toggle:Hide()
            controls.remove:Hide()
        end
    end

    updatePager(frame.checklistPrev, frame.checklistNext, frame.checklistPageText, page, maxPage)
end

-- Travel route library ------------------------------------------------------
local previousCreateTravelRoutesFrame = UI.CreateTravelRoutesFrame
function UI:CreateTravelRoutesFrame(...)
    local frame = previousCreateTravelRoutesFrame(self, ...)
    if not frame or frame.fcCollectionPaging then return frame end
    frame.fcCollectionPaging = true
    frame.routePage = 1

    local prev, nextButton = createHeaderPager(frame, "route", frame.closeButton)
    prev:SetScript("OnClick", function()
        frame.routePage = math.max(1, (frame.routePage or 1) - 1)
        UI:RefreshTravelRoutesView()
    end)
    nextButton:SetScript("OnClick", function()
        frame.routePage = (frame.routePage or 1) + 1
        UI:RefreshTravelRoutesView()
    end)
    return frame
end

local previousRefreshTravelRoutesView = UI.RefreshTravelRoutesView
function UI:RefreshTravelRoutesView(...)
    previousRefreshTravelRoutesView(self, ...)
    local frame = self.travelRoutesFrame
    local module = FC.TravelRoutes
    if not frame or not frame.fcCollectionPaging or not module then return end

    local routes = module:GetAllRoutes(true)
    local page, maxPage, startIndex = clampPage(frame, "routePage", #routes, ROUTE_PAGE_SIZE)

    for i, card in ipairs(frame.rows or {}) do
        local route = routes[startIndex + i - 1]
        if route then
            card:Show()
            local endpoints = route.origin and route.destination and (route.origin .. " → " .. route.destination) or tostring(route.name)
            local source = route.source or "User"
            local displaySource = source == "User" and FC:GetText("ROUTE_SOURCE_USER") or source
            local detail = route.notes and route.notes ~= "" and (" • " .. route.notes) or ""
            setText(card.text, string.format("[%s] %s • %s%s", tostring(route.routeType or FC:GetText("SEARCH_ROUTE_FALLBACK")), tostring(endpoints), tostring(displaySource), detail),
                route.enabled == false and Theme.colors.muted or Theme.colors.text)

            local isUser = source == "User"
            card.toggle.routeID = isUser and route.id or nil
            card.toggle.routeEnabled = route.enabled ~= false
            card.remove.routeID = isUser and route.id or nil
            card.toggle:SetFCText(FC:GetText(route.enabled == false and "ENABLE" or "PAUSE"))
            card.remove:SetFCText(FC:GetText("REMOVE"))
            card.toggle:SetShown(isUser)
            card.remove:SetShown(isUser)
        else
            card:Hide()
        end
    end

    if #routes == 0 and frame.rows and frame.rows[1] then
        frame.rows[1]:Show()
        frame.rows[1].toggle.routeID = nil
        frame.rows[1].remove.routeID = nil
        frame.rows[1].toggle:Hide()
        frame.rows[1].remove:Hide()
    end

    updatePager(frame.routePrev, frame.routeNext, frame.routePageText, page, maxPage)
end

-- Smart suggestions ---------------------------------------------------------
local function formatRemaining(untilTime)
    local now = time and time() or 0
    local remaining = math.max(0, (tonumber(untilTime) or 0) - now)
    if remaining <= 0 then return FC:GetText("SUGGESTION_WAKE_READY") end
    if remaining >= 3600 then
        return FC:GetText("DURATION_HOURS_MINUTES", math.floor(remaining / 3600), math.floor((remaining % 3600) / 60))
    end
    return FC:GetText("DURATION_MINUTES", math.max(1, math.ceil(remaining / 60)))
end

local function visibleSuggestions(frame)
    local result = {}
    for _, suggestion in ipairs(FC.Suggestions and FC.Suggestions:GetAll(true) or {}) do
        local isSnoozed = suggestion.snoozedUntil ~= nil
        if frame.showSnoozed == isSnoozed then result[#result + 1] = suggestion end
    end
    return result
end

local previousCreateSuggestionsFrame = UI.CreateSuggestionsFrame
function UI:CreateSuggestionsFrame(...)
    local frame = previousCreateSuggestionsFrame(self, ...)
    if not frame or frame.fcCollectionPaging then return frame end
    frame.fcCollectionPaging = true
    frame.suggestionPage = 1

    frame.note:SetWidth(570)
    frame.suggestionNext = Theme:CreateButton(frame, ">", 30, 26)
    frame.suggestionNext:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 18)
    frame.suggestionPrev = Theme:CreateButton(frame, "<", 30, 26)
    frame.suggestionPrev:SetPoint("RIGHT", frame.suggestionNext, "LEFT", -5, 0)
    frame.suggestionPageText = Theme:CreateText(frame, "GameFontHighlightSmall", "")
    frame.suggestionPageText:SetPoint("RIGHT", frame.suggestionPrev, "LEFT", -8, 0)
    frame.suggestionPageText:SetWidth(90)
    frame.suggestionPageText:SetJustifyH("RIGHT")

    frame.suggestionPrev:SetScript("OnClick", function()
        frame.suggestionPage = math.max(1, (frame.suggestionPage or 1) - 1)
        UI:RefreshSuggestionsView()
    end)
    frame.suggestionNext:SetScript("OnClick", function()
        frame.suggestionPage = (frame.suggestionPage or 1) + 1
        UI:RefreshSuggestionsView()
    end)

    local originalModeClick = frame.modeButton:GetScript("OnClick")
    frame.modeButton:SetScript("OnClick", function(...)
        frame.suggestionPage = 1
        if originalModeClick then originalModeClick(...) end
    end)
    return frame
end

local previousRefreshSuggestionsView = UI.RefreshSuggestionsView
function UI:RefreshSuggestionsView(...)
    previousRefreshSuggestionsView(self, ...)
    local frame = self.suggestionsFrame
    if not frame or not frame.fcCollectionPaging then return end

    local visible = visibleSuggestions(frame)
    local page, maxPage, startIndex = clampPage(frame, "suggestionPage", #visible, SUGGESTION_PAGE_SIZE)

    for i, card in ipairs(frame.rows or {}) do
        local suggestion = visible[startIndex + i - 1]
        if suggestion then
            card:Show()
            card.pin.suggestionID = suggestion.id
            card.snooze.suggestionID = suggestion.id
            card.snooze.wakeMode = suggestion.snoozedUntil ~= nil
            card.pin:Show()
            card.snooze:Show()
            card.pin:SetFCText(FC:GetText("PIN_GOAL"))
            card.snooze:SetFCText(FC:GetText(suggestion.snoozedUntil and "WAKE" or "SNOOZE_1H"))
            local titleColor = (tonumber(suggestion.priority) or 0) >= 80 and Theme.colors.red
                or ((tonumber(suggestion.priority) or 0) >= 60 and Theme.colors.yellow or Theme.colors.text)
            setText(card.title, string.format("P%d • %s • %s", tonumber(suggestion.priority) or 0, categoryText(suggestion.category), tostring(suggestion.title)), titleColor)
            local extra = suggestion.snoozedUntil and (" • " .. FC:GetText("SUGGESTION_WAKES_IN", formatRemaining(suggestion.snoozedUntil))) or ""
            setText(card.description, tostring(suggestion.description or suggestion.source or "") .. extra, Theme.colors.muted)
        else
            card.pin.suggestionID = nil
            card.snooze.suggestionID = nil
            card:Hide()
        end
    end

    if #visible == 0 and frame.rows and frame.rows[1] then
        frame.rows[1]:Show()
        frame.rows[1].pin.suggestionID = nil
        frame.rows[1].snooze.suggestionID = nil
        frame.rows[1].pin:Hide()
        frame.rows[1].snooze:Hide()
    end

    updatePager(frame.suggestionPrev, frame.suggestionNext, frame.suggestionPageText, page, maxPage)
end

-- Account milestones --------------------------------------------------------
local previousCreateMilestonesFrame = UI.CreateMilestonesFrame
function UI:CreateMilestonesFrame(...)
    local frame = previousCreateMilestonesFrame(self, ...)
    if not frame or frame.fcCollectionPaging then return frame end
    frame.fcCollectionPaging = true
    frame.milestonePage = 1

    local prev, nextButton = createHeaderPager(frame, "milestone", frame.refreshButton)
    prev:SetScript("OnClick", function()
        frame.milestonePage = math.max(1, (frame.milestonePage or 1) - 1)
        UI:RefreshMilestonesView()
    end)
    nextButton:SetScript("OnClick", function()
        frame.milestonePage = (frame.milestonePage or 1) + 1
        UI:RefreshMilestonesView()
    end)
    return frame
end

local previousRefreshMilestonesView = UI.RefreshMilestonesView
function UI:RefreshMilestonesView(...)
    previousRefreshMilestonesView(self, ...)
    local frame = self.milestonesFrame
    if not frame or not frame.fcCollectionPaging then return end

    local milestones = FC.Milestones and FC.Milestones:GetMilestones() or {}
    local page, maxPage, startIndex = clampPage(frame, "milestonePage", #milestones, MILESTONE_PAGE_SIZE)

    for i, line in ipairs(frame.lines or {}) do
        local globalIndex = startIndex + i - 1
        local milestone = milestones[globalIndex]
        if milestone then
            setText(line, string.format("[%s] %s\n   %s", categoryText(milestone.category or FC:GetText("MILESTONE_CATEGORY_GENERAL")), tostring(milestone.title), tostring(milestone.description or "")),
                globalIndex <= 3 and Theme.colors.gold or Theme.colors.muted)
        elseif i == 1 and #milestones == 0 then
            setText(line, FC:GetText("MILESTONE_NONE_RECORDED"), Theme.colors.muted)
        else
            setText(line, "")
        end
    end

    updatePager(frame.milestonePrev, frame.milestoneNext, frame.milestonePageText, page, maxPage)
end