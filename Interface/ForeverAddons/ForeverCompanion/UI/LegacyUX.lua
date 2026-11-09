local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme
local PAGE_SIZE = 10

local function setText(fontString, text, color)
    if not fontString then return end
    color = color or Theme.colors.text
    fontString:SetText(text or "")
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function setButton(button, key)
    if button and button.SetFCText then button:SetFCText(FC:GetText(key)) end
end

local function incompleteChallenges(snapshot)
    local result = {}
    for _, challenge in ipairs(snapshot and snapshot.challenges or {}) do
        if not challenge.completed then result[#result + 1] = challenge end
    end
    table.sort(result, function(a, b)
        local ap = tonumber(a.progress) or 0
        local bp = tonumber(b.progress) or 0
        if ap == bp then return tostring(a.name or "") < tostring(b.name or "") end
        return ap > bp
    end)
    return result
end

local function refreshPage(frame)
    local snapshot = FC.Legacy and FC.Legacy:GetSnapshot() or nil
    if not snapshot then return end
    local challenges = incompleteChallenges(snapshot)
    local maxPage = math.max(1, math.ceil(#challenges / PAGE_SIZE))
    frame.legacyPage = math.max(1, math.min(tonumber(frame.legacyPage) or 1, maxPage))
    local startIndex = ((frame.legacyPage - 1) * PAGE_SIZE) + 1

    for i = 1, #frame.challengeLines do
        local challenge = challenges[startIndex + i - 1]
        if challenge then
            local percent = math.floor(((tonumber(challenge.progress) or 0) * 100) + 0.5)
            local progressText = challenge.criteriaTotal and challenge.criteriaTotal > 0
                and FC:GetText("LEGACY_CRITERIA_PROGRESS", tonumber(challenge.criteriaCompleted) or 0, tonumber(challenge.criteriaTotal) or 0)
                or string.format("%d%%", percent)
            setText(frame.challengeLines[i], string.format("%s\n   %s", tostring(challenge.name), progressText),
                percent >= 75 and Theme.colors.yellow or Theme.colors.text)
        else
            setText(frame.challengeLines[i], "")
        end
    end

    if #challenges == 0 then
        setText(frame.challengeLines[1], FC:GetText("LEGACY_ALL_COMPLETE"), Theme.colors.green)
    end

    frame.legacyPrev:SetEnabled(frame.legacyPage > 1)
    frame.legacyNext:SetEnabled(frame.legacyPage < maxPage)
    frame.legacyPrev:SetAlpha(frame.legacyPage > 1 and 1 or 0.4)
    frame.legacyNext:SetAlpha(frame.legacyPage < maxPage and 1 or 0.4)
    frame.legacyPageText:SetText(string.format("%d / %d", frame.legacyPage, maxPage))
end

local function applyStatic(frame)
    if not frame then return end
    if frame.title then frame.title:SetText(FC:GetText("WINDOW_LEGACY")) end
    setButton(frame.refreshButton, "REFRESH")
    setButton(frame.pinButton, "PIN_CLOSEST")
    if frame.categoryTitle then frame.categoryTitle:SetText(FC:GetText("CHALLENGE_CATEGORIES")) end
    if frame.nextTitle then frame.nextTitle:SetText(FC:GetText("CLOSEST_INCOMPLETE")) end
end

local previousCreateLegacyFrame = UI.CreateLegacyFrame
function UI:CreateLegacyFrame(...)
    local frame = previousCreateLegacyFrame(self, ...)
    if not frame then return frame end
    applyStatic(frame)
    if frame.fcLegacyUX then return frame end
    frame.fcLegacyUX = true
    frame.legacyPage = 1

    frame.legacyNext = Theme:CreateButton(frame, ">", 30, 26)
    frame.legacyNext:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -100)
    frame.legacyPrev = Theme:CreateButton(frame, "<", 30, 26)
    frame.legacyPrev:SetPoint("RIGHT", frame.legacyNext, "LEFT", -5, 0)
    frame.legacyPageText = Theme:CreateText(frame, "GameFontHighlightSmall", "")
    frame.legacyPageText:SetPoint("RIGHT", frame.legacyPrev, "LEFT", -8, 0)
    frame.legacyPageText:SetWidth(70)
    frame.legacyPageText:SetJustifyH("RIGHT")

    frame.legacyPrev:SetScript("OnClick", function()
        frame.legacyPage = math.max(1, (frame.legacyPage or 1) - 1)
        refreshPage(frame)
    end)
    frame.legacyNext:SetScript("OnClick", function()
        frame.legacyPage = (frame.legacyPage or 1) + 1
        refreshPage(frame)
    end)

    frame.actionStatus = Theme:CreateText(frame, "GameFontHighlightSmall", "")
    frame.actionStatus:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -22, -66)
    frame.actionStatus:SetWidth(330)
    frame.actionStatus:SetJustifyH("RIGHT")

    frame.pinButton:SetScript("OnClick", function()
        local snapshot = FC.Legacy and FC.Legacy:GetSnapshot() or nil
        local challenges = incompleteChallenges(snapshot)
        local challenge = challenges[1]
        if not challenge or not FC.Goals then
            setText(frame.actionStatus, FC:GetText("LEGACY_PIN_UNAVAILABLE"), Theme.colors.yellow)
            return
        end
        local percent = math.floor(((tonumber(challenge.progress) or 0) * 100) + 0.5)
        local ok, result = FC.Goals:PinReference(
            "Legacy",
            challenge.id,
            tostring(challenge.name),
            FC:GetText("LEGACY_GOAL_DESCRIPTION", percent),
            72,
            { challengeID = challenge.id }
        )
        setText(frame.actionStatus, ok and FC:GetText("LEGACY_PINNED") or tostring(result or FC:GetText("LEGACY_PIN_UNAVAILABLE")), ok and Theme.colors.green or Theme.colors.yellow)
        if ok and UI.frame and UI.frame:IsShown() then UI:RefreshDashboard() end
    end)
    return frame
end

local previousRefreshLegacyView = UI.RefreshLegacyView
function UI:RefreshLegacyView(...)
    previousRefreshLegacyView(self, ...)
    local frame = self.legacyFrame
    if not frame then return end
    applyStatic(frame)
    if frame.fcLegacyUX then refreshPage(frame) end
end

local previousCreateMainFrame = UI.CreateMainFrame
function UI:CreateMainFrame(...)
    local frame = previousCreateMainFrame(self, ...)
    setButton(frame and frame.fcLegacyButton, "OPEN_LEGACY_TRACKER")
    return frame
end

local previousRefreshDashboard = UI.RefreshDashboard
function UI:RefreshDashboard(...)
    previousRefreshDashboard(self, ...)
    setButton(self.frame and self.frame.fcLegacyButton, "OPEN_LEGACY_TRACKER")
end

local previousRefreshSettingsView = UI.RefreshSettingsView
function UI:RefreshSettingsView(...)
    previousRefreshSettingsView(self, ...)
    applyStatic(self.legacyFrame)
    setButton(self.frame and self.frame.fcLegacyButton, "OPEN_LEGACY_TRACKER")
end
