local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local function setText(fontString, text, color)
    if not fontString then return end
    color = color or Theme.colors.text
    fontString:SetText(text or "")
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function getClosestIncomplete(snapshot)
    for _, challenge in ipairs(snapshot and snapshot.challenges or {}) do
        if not challenge.completed then return challenge end
    end
    return nil
end

function UI:CreateLegacyFrame()
    if self.legacyFrame then return self.legacyFrame end

    local frame = Theme:CreatePanel(UIParent, Theme.colors.navy, Theme.colors.gold)
    frame:SetSize(760, 560)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    frame.title = Theme:CreateText(frame, "GameFontNormalHuge", "LEGACY TRACKER")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -18)
    frame.title:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])

    frame.closeButton = Theme:CreateButton(frame, "X", 32, 30)
    frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -14)
    frame.closeButton:SetScript("OnClick", function() frame:Hide() end)

    frame.refreshButton = Theme:CreateButton(frame, "Refresh", 90, 30)
    frame.refreshButton:SetPoint("RIGHT", frame.closeButton, "LEFT", -8, 0)
    frame.refreshButton:SetScript("OnClick", function()
        if FC.Legacy then FC.Legacy:Refresh("legacy-window") end
        UI:RefreshLegacyView()
    end)

    frame.pinButton = Theme:CreateButton(frame, "Pin closest", 105, 30)
    frame.pinButton:SetPoint("RIGHT", frame.refreshButton, "LEFT", -8, 0)
    frame.pinButton:SetScript("OnClick", function()
        local snapshot = FC.Legacy and FC.Legacy:GetSnapshot() or nil
        local challenge = getClosestIncomplete(snapshot)
        if not challenge or not FC.Goals then
            FC:Print("No incomplete Legacy Challenge is available to pin.")
            return
        end
        local percent = math.floor(((tonumber(challenge.progress) or 0) * 100) + 0.5)
        local ok, goal = FC.Goals:PinReference("Legacy", challenge.id, tostring(challenge.name),
            string.format("Legacy Challenge currently about %d%% complete.", percent), 72,
            { challengeID = challenge.id })
        if ok then FC:Print("Pinned Legacy goal #" .. tostring(goal.id) .. ": " .. tostring(challenge.name)) end
    end)

    frame.summary = Theme:CreateText(frame, "GameFontHighlight", "")
    frame.summary:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -62)
    frame.summary:SetWidth(716)
    frame.summary:SetJustifyH("LEFT")

    frame.categoryTitle = Theme:CreateSectionTitle(frame, "Challenge Categories")
    frame.categoryTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -104)

    frame.categoryLines = {}
    for index = 1, 8 do
        local line = Theme:CreateText(frame, "GameFontHighlightSmall", "")
        line:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -134 - ((index - 1) * 28))
        line:SetWidth(340)
        line:SetJustifyH("LEFT")
        frame.categoryLines[index] = line
    end

    frame.nextTitle = Theme:CreateSectionTitle(frame, "Closest Incomplete Challenges")
    frame.nextTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 390, -104)

    frame.challengeLines = {}
    for index = 1, 10 do
        local line = Theme:CreateText(frame, "GameFontHighlightSmall", "")
        line:SetPoint("TOPLEFT", frame, "TOPLEFT", 392, -134 - ((index - 1) * 36))
        line:SetWidth(340)
        line:SetJustifyH("LEFT")
        line:SetJustifyV("TOP")
        frame.challengeLines[index] = line
    end

    frame.note = Theme:CreateText(frame, "GameFontDisableSmall",
        "Legacy Challenges are read through public achievement APIs and can be pinned into the account goal system. Perk/allocation state stays hidden until Forever exposes a verified readable API.")
    frame.note:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 18)
    frame.note:SetWidth(716)
    frame.note:SetJustifyH("LEFT")

    self.legacyFrame = frame
    return frame
end

function UI:RefreshLegacyView()
    local frame = self.legacyFrame
    if not frame then return end

    local snapshot = FC.Legacy and FC.Legacy:GetSnapshot() or nil
    if not snapshot then
        local errorText = FC.Legacy and FC.Legacy:GetLastError() or "Legacy module is not initialized"
        setText(frame.summary, "Legacy data is not available yet. " .. tostring(errorText or ""), Theme.colors.yellow)
        frame.pinButton:SetEnabled(false)
        for index = 1, #frame.categoryLines do
            setText(frame.categoryLines[index], index == 1 and "Open the Blizzard Legacy window once if the beta has not populated achievement data yet." or "", Theme.colors.muted)
        end
        for index = 1, #frame.challengeLines do setText(frame.challengeLines[index], "") end
        return
    end

    setText(frame.summary, string.format("%s  •  %d / %d complete  •  %d remaining",
        tostring(snapshot.title or "Legacy"), tonumber(snapshot.completed) or 0, tonumber(snapshot.total) or 0, tonumber(snapshot.remaining) or 0),
        snapshot.remaining == 0 and Theme.colors.green or Theme.colors.text)
    frame.pinButton:SetEnabled((tonumber(snapshot.remaining) or 0) > 0)

    for index = 1, #frame.categoryLines do
        local category = snapshot.categories and snapshot.categories[index]
        if category then
            setText(frame.categoryLines[index], string.format("%s  %d / %d", tostring(category.title or "Category"),
                tonumber(category.completed) or 0, tonumber(category.total) or 0),
                category.completed == category.total and Theme.colors.green or Theme.colors.text)
        else
            setText(frame.categoryLines[index], "")
        end
    end

    local shown = 0
    for _, challenge in ipairs(snapshot.challenges or {}) do
        if not challenge.completed and shown < #frame.challengeLines then
            shown = shown + 1
            local percent = math.floor(((tonumber(challenge.progress) or 0) * 100) + 0.5)
            local progressText = challenge.criteriaTotal and challenge.criteriaTotal > 0
                and string.format("%d/%d criteria", tonumber(challenge.criteriaCompleted) or 0, tonumber(challenge.criteriaTotal) or 0)
                or string.format("%d%%", percent)
            setText(frame.challengeLines[shown], string.format("%s\n   %s", tostring(challenge.name), progressText),
                percent >= 75 and Theme.colors.yellow or Theme.colors.text)
        end
    end

    if shown == 0 then
        setText(frame.challengeLines[1], "All discovered Legacy Challenges are complete.", Theme.colors.green)
        shown = 1
    end
    for index = shown + 1, #frame.challengeLines do setText(frame.challengeLines[index], "") end
end

function UI:ShowLegacyTracker()
    local frame = self:CreateLegacyFrame()
    if FC.Legacy then FC.Legacy:Refresh("legacy-window-open") end
    self:RefreshLegacyView()
    frame:Show()
end

local originalCreateMainFrame = UI.CreateMainFrame
function UI:CreateMainFrame(...)
    local frame = originalCreateMainFrame(self, ...)
    if frame and not frame.fcLegacyButton and frame.pages and frame.pages.Journey and frame.pages.Journey.statusCard then
        local button = Theme:CreateButton(frame.pages.Journey.statusCard, "Open Legacy Tracker", 180, 30)
        button:SetPoint("BOTTOMRIGHT", frame.pages.Journey.statusCard, "BOTTOMRIGHT", -14, 12)
        button:SetScript("OnClick", function() UI:ShowLegacyTracker() end)
        frame.fcLegacyButton = button
    end
    return frame
end

local originalRefreshDashboard = UI.RefreshDashboard
function UI:RefreshDashboard(...)
    originalRefreshDashboard(self, ...)

    local page = self.frame and self.frame.pages and self.frame.pages.Journey
    local line = page and page.statusLines and page.statusLines[1]
    if not line then return end

    local snapshot = FC.Legacy and FC.Legacy:GetSnapshot() or nil
    if snapshot then
        setText(line, string.format("✓  Legacy Challenges\n    %d / %d complete • %d remaining",
            tonumber(snapshot.completed) or 0, tonumber(snapshot.total) or 0, tonumber(snapshot.remaining) or 0), Theme.colors.green)
    elseif FC.API.capabilities and FC.API.capabilities.legacy then
        setText(line, "•  Legacy Challenges\n    Achievement API detected; waiting for challenge data.", Theme.colors.yellow)
    end
end
