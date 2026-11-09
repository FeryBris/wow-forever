local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local function setText(fontString, text, color)
    if not fontString then return end
    color = color or Theme.colors.text
    fontString:SetText(text or "")
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function formatRemaining(untilTime)
    local now = time and time() or 0
    local remaining = math.max(0, (tonumber(untilTime) or 0) - now)
    if remaining <= 0 then return "ready" end
    if remaining >= 3600 then return string.format("%dh %dm", math.floor(remaining / 3600), math.floor((remaining % 3600) / 60)) end
    return string.format("%dm", math.max(1, math.ceil(remaining / 60)))
end

function UI:CreateSuggestionsFrame()
    if self.suggestionsFrame then return self.suggestionsFrame end

    local frame = Theme:CreatePanel(UIParent, Theme.colors.navy, Theme.colors.gold)
    frame:SetSize(900, 650)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()
    frame.showSnoozed = false

    frame.title = Theme:CreateText(frame, "GameFontNormalHuge", "SMART SUGGESTIONS")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -18)
    frame.title:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])

    frame.closeButton = Theme:CreateButton(frame, "X", 32, 30)
    frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -14)
    frame.closeButton:SetScript("OnClick", function() frame:Hide() end)

    frame.refreshButton = Theme:CreateButton(frame, "Refresh", 90, 30)
    frame.refreshButton:SetPoint("RIGHT", frame.closeButton, "LEFT", -8, 0)
    frame.refreshButton:SetScript("OnClick", function()
        FC:RefreshModules("suggestion-manager")
        UI:RefreshSuggestionsView()
    end)

    frame.modeButton = Theme:CreateButton(frame, "Show Snoozed", 125, 30)
    frame.modeButton:SetPoint("RIGHT", frame.refreshButton, "LEFT", -8, 0)
    frame.modeButton:SetScript("OnClick", function()
        frame.showSnoozed = not frame.showSnoozed
        UI:RefreshSuggestionsView()
    end)

    frame.clearButton = Theme:CreateButton(frame, "Wake All", 95, 30)
    frame.clearButton:SetPoint("RIGHT", frame.modeButton, "LEFT", -8, 0)
    frame.clearButton:SetScript("OnClick", function()
        FC.Suggestions:ClearSnoozes()
        UI:RefreshSuggestionsView()
        if UI.frame and UI.frame:IsShown() then UI:RefreshDashboard() end
    end)

    frame.summary = Theme:CreateText(frame, "GameFontHighlight", "")
    frame.summary:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -66)
    frame.summary:SetWidth(856)
    frame.summary:SetJustifyH("LEFT")

    frame.rows = {}
    for i = 1, 8 do
        local card = Theme:CreatePanel(frame, Theme.colors.panel, Theme.colors.blueSoft)
        card:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -104 - ((i - 1) * 62))
        card:SetSize(856, 56)

        card.title = Theme:CreateText(card, "GameFontNormal", "")
        card.title:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -8)
        card.title:SetWidth(485)
        card.title:SetJustifyH("LEFT")

        card.description = Theme:CreateText(card, "GameFontHighlightSmall", "")
        card.description:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -29)
        card.description:SetWidth(485)
        card.description:SetJustifyH("LEFT")

        card.pin = Theme:CreateButton(card, "Pin Goal", 95, 30)
        card.pin:SetPoint("RIGHT", card, "RIGHT", -115, 0)
        card.pin:SetScript("OnClick", function(self)
            if not self.suggestionID then return end
            local ok, result = FC.Suggestions:PinAsGoal(self.suggestionID)
            if ok then
                FC:Print("Suggestion pinned as personal goal:", tostring(result.title))
            else
                FC:Print(result or "Unable to pin suggestion.")
            end
            UI:RefreshSuggestionsView()
        end)

        card.snooze = Theme:CreateButton(card, "Snooze 1h", 100, 30)
        card.snooze:SetPoint("RIGHT", card, "RIGHT", -8, 0)
        card.snooze:SetScript("OnClick", function(self)
            if not self.suggestionID then return end
            if self.wakeMode then
                FC.Suggestions:Unsnooze(self.suggestionID)
            else
                FC.Suggestions:Snooze(self.suggestionID, 3600)
            end
            UI:RefreshSuggestionsView()
            if UI.frame and UI.frame:IsShown() then UI:RefreshDashboard() end
        end)

        frame.rows[i] = card
    end

    frame.note = Theme:CreateText(frame, "GameFontDisableSmall",
        "Snoozing hides a suggestion for one hour but does not disable its source module. Pin Goal copies the suggestion into the persistent personal Goal system so you can keep it after the underlying suggestion changes.")
    frame.note:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 18)
    frame.note:SetWidth(856)
    frame.note:SetJustifyH("LEFT")

    self.suggestionsFrame = frame
    return frame
end

function UI:RefreshSuggestionsView()
    local frame = self:CreateSuggestionsFrame()
    local activeCount = FC.Suggestions:Count(false)
    local snoozedCount = FC.Suggestions:CountSnoozed()
    local all = FC.Suggestions:GetAll(true)
    local visible = {}

    for _, suggestion in ipairs(all) do
        local isSnoozed = suggestion.snoozedUntil ~= nil
        if frame.showSnoozed == isSnoozed then visible[#visible + 1] = suggestion end
    end

    frame.modeButton:SetFCText(frame.showSnoozed and "Show Active" or "Show Snoozed")
    frame.modeButton:SetFCActive(frame.showSnoozed)
    frame.clearButton:SetAlpha(snoozedCount > 0 and 1 or 0.45)
    setText(frame.summary, string.format("%d active suggestion(s) • %d snoozed • showing %s",
        activeCount, snoozedCount, frame.showSnoozed and "snoozed suggestions" or "active suggestions"), Theme.colors.text)

    for i, card in ipairs(frame.rows) do
        local suggestion = visible[i]
        if suggestion then
            card:Show()
            card.pin.suggestionID = suggestion.id
            card.snooze.suggestionID = suggestion.id
            card.snooze.wakeMode = suggestion.snoozedUntil ~= nil
            card.pin:SetAlpha(suggestion.snoozedUntil and 0.65 or 1)
            card.snooze:SetFCText(suggestion.snoozedUntil and "Wake" or "Snooze 1h")
            local titleColor = (tonumber(suggestion.priority) or 0) >= 80 and Theme.colors.red
                or ((tonumber(suggestion.priority) or 0) >= 60 and Theme.colors.yellow or Theme.colors.text)
            setText(card.title, string.format("P%d • %s • %s", tonumber(suggestion.priority) or 0, tostring(suggestion.category), tostring(suggestion.title)), titleColor)
            local extra = suggestion.snoozedUntil and (" • wakes in " .. formatRemaining(suggestion.snoozedUntil)) or ""
            setText(card.description, tostring(suggestion.description or suggestion.source or "") .. extra, Theme.colors.muted)
        else
            card.pin.suggestionID = nil
            card.snooze.suggestionID = nil
            card:Hide()
        end
    end

    if #visible == 0 then
        frame.rows[1]:Show()
        frame.rows[1].pin.suggestionID = nil
        frame.rows[1].snooze.suggestionID = nil
        frame.rows[1].pin:SetAlpha(0)
        frame.rows[1].snooze:SetAlpha(0)
        setText(frame.rows[1].title, frame.showSnoozed and "No suggestions are currently snoozed." or "No active suggestions right now.", Theme.colors.green)
        setText(frame.rows[1].description, frame.showSnoozed and "Snoozed suggestions will appear here until they wake." or "Your current companion context has no pending suggestion.", Theme.colors.muted)
    else
        for _, card in ipairs(frame.rows) do
            card.pin:SetAlpha(card.pin.suggestionID and 1 or 0)
            card.snooze:SetAlpha(card.snooze.suggestionID and 1 or 0)
        end
    end
end

function UI:ShowSuggestions()
    local frame = self:CreateSuggestionsFrame()
    FC:RefreshModules("suggestion-window-open")
    self:RefreshSuggestionsView()
    frame:Show()
end

local previousCreateMainFrame = UI.CreateMainFrame
function UI:CreateMainFrame(...)
    local frame = previousCreateMainFrame(self, ...)
    if frame and not frame.fcSuggestionsButton and frame.pages and frame.pages.Overview and frame.pages.Overview.suggestionCard then
        local button = Theme:CreateButton(frame.pages.Overview.suggestionCard, "Manage Suggestions", 155, 28)
        button:SetPoint("BOTTOMRIGHT", frame.pages.Overview.suggestionCard, "BOTTOMRIGHT", -12, 10)
        button:SetScript("OnClick", function() UI:ShowSuggestions() end)
        frame.fcSuggestionsButton = button
    end
    return frame
end
