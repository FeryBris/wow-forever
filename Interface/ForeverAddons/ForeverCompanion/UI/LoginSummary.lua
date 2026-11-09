local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local function setText(fontString, text, color)
    if not fontString then return end
    color = color or Theme.colors.text
    fontString:SetText(text or "")
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function applyStatic(frame)
    if not frame then return end
    if frame.title then frame.title:SetText("FOREVER COMPANION") end
    if frame.subtitle then frame.subtitle:SetText(FC:GetText("LOGIN_QUESTION")) end
    if frame.openButton and frame.openButton.SetFCText then frame.openButton:SetFCText(FC:GetText("LOGIN_OPEN_DASHBOARD")) end
    if frame.hideButton and frame.hideButton.SetFCText then frame.hideButton:SetFCText(FC:GetText("LOGIN_HIDE")) end
end

local function showDashboard()
    FC:RefreshModules("login-summary-dashboard")
    local main = UI:CreateMainFrame()
    if type(UI.SwitchTab) == "function" then UI:SwitchTab("Overview") end
    if type(UI.RefreshDashboard) == "function" then UI:RefreshDashboard() end
    main:Show()
end

function UI:CreateLoginSummaryFrame()
    if self.loginSummaryFrame then
        applyStatic(self.loginSummaryFrame)
        return self.loginSummaryFrame
    end

    local frame = Theme:CreatePanel(UIParent, Theme.colors.navy, Theme.colors.gold)
    frame:SetSize(460, 270)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -120)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    frame.title = Theme:CreateText(frame, "GameFontNormalLarge", "FOREVER COMPANION")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -14)
    frame.title:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])

    frame.subtitle = Theme:CreateText(frame, "GameFontHighlightSmall", FC:GetText("LOGIN_QUESTION"))
    frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -4)
    frame.subtitle:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3])

    frame.closeButton = Theme:CreateButton(frame, "X", 28, 26)
    frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    frame.closeButton:SetScript("OnClick", function() frame:Hide() end)

    frame.lines = {}
    frame.lineButtons = {}
    for i = 1, 3 do
        local line = Theme:CreateText(frame, "GameFontHighlightSmall", "")
        line:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -76 - ((i - 1) * 52))
        line:SetWidth(424)
        line:SetJustifyH("LEFT")
        line:SetJustifyV("TOP")
        frame.lines[i] = line

        local hit = CreateFrame("Button", nil, frame)
        hit:SetPoint("TOPLEFT", line, "TOPLEFT", -4, 5)
        hit:SetSize(432, 48)
        hit:RegisterForClicks("LeftButtonUp")
        hit:SetScript("OnClick", function(self)
            if not self.fcSuggestion then return end
            frame:Hide()
            if type(UI.OpenSuggestion) == "function" then
                UI.OpenSuggestion(self.fcSuggestion)
            else
                showDashboard()
            end
        end)
        hit:SetScript("OnEnter", function(self)
            if not self.fcSuggestion then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(FC:GetText("SUGGESTION_OPEN_RELATED_VIEW"), 0.45, 0.82, 1.00)
            GameTooltip:Show()
        end)
        hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
        frame.lineButtons[i] = hit
    end

    frame.openButton = Theme:CreateButton(frame, FC:GetText("LOGIN_OPEN_DASHBOARD"), 150, 30)
    frame.openButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 14)
    frame.openButton:SetScript("OnClick", function()
        frame:Hide()
        showDashboard()
    end)

    frame.hideButton = Theme:CreateButton(frame, FC:GetText("LOGIN_HIDE"), 170, 30)
    frame.hideButton:SetPoint("RIGHT", frame.openButton, "LEFT", -8, 0)
    frame.hideButton:SetScript("OnClick", function()
        FC.DB.settings.showLoginSummary = false
        frame:Hide()
    end)

    self.loginSummaryFrame = frame
    return frame
end

function UI:RefreshLoginSummary()
    local frame = self:CreateLoginSummaryFrame()
    applyStatic(frame)
    local suggestions = FC.Suggestions:GetTop(3)
    for i = 1, #frame.lines do
        local suggestion = suggestions[i]
        local hit = frame.lineButtons and frame.lineButtons[i]
        if suggestion then
            local color = (suggestion.priority or 0) >= 80 and Theme.colors.red
                or ((suggestion.priority or 0) >= 60 and Theme.colors.yellow or Theme.colors.text)
            setText(frame.lines[i], string.format("%s\n   %s", tostring(suggestion.title), tostring(suggestion.description or suggestion.category or "")), color)
            if hit then
                hit.fcSuggestion = suggestion
                hit:Show()
            end
        elseif i == 1 then
            setText(frame.lines[i], FC:GetText("LOGIN_NO_URGENT"), Theme.colors.green)
            if hit then
                hit.fcSuggestion = nil
                hit:Hide()
            end
        else
            setText(frame.lines[i], "")
            if hit then
                hit.fcSuggestion = nil
                hit:Hide()
            end
        end
    end
end

function UI:ShowLoginSummary()
    if not FC.DB or not FC.DB.settings or FC.DB.settings.showLoginSummary == false then return end
    local frame = self:CreateLoginSummaryFrame()
    self:RefreshLoginSummary()
    frame:Show()
end
