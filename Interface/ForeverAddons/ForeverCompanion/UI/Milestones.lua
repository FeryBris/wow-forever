local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local function setText(fontString, text, color)
    if not fontString then return end
    color = color or Theme.colors.text
    fontString:SetText(text or "")
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

function UI:CreateMilestonesFrame()
    if self.milestonesFrame then return self.milestonesFrame end

    local frame = Theme:CreatePanel(UIParent, Theme.colors.navy, Theme.colors.gold)
    frame:SetSize(760, 570)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    frame.title = Theme:CreateText(frame, "GameFontNormalHuge", "ACCOUNT MILESTONES")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -18)
    frame.title:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])

    frame.closeButton = Theme:CreateButton(frame, "X", 32, 30)
    frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -14)
    frame.closeButton:SetScript("OnClick", function() frame:Hide() end)

    frame.refreshButton = Theme:CreateButton(frame, "Refresh", 90, 30)
    frame.refreshButton:SetPoint("RIGHT", frame.closeButton, "LEFT", -8, 0)
    frame.refreshButton:SetScript("OnClick", function()
        if FC.Milestones then FC.Milestones:Refresh() end
        UI:RefreshMilestonesView()
    end)

    frame.summary = Theme:CreateText(frame, "GameFontHighlight", "")
    frame.summary:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -66)
    frame.summary:SetWidth(716)
    frame.summary:SetJustifyH("LEFT")

    frame.lines = {}
    for i = 1, 11 do
        local line = Theme:CreateText(frame, "GameFontHighlightSmall", "")
        line:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -112 - ((i - 1) * 38))
        line:SetWidth(710)
        line:SetJustifyH("LEFT")
        line:SetJustifyV("TOP")
        frame.lines[i] = line
    end

    frame.note = Theme:CreateText(frame, "GameFontDisableSmall", FC:GetText("MILESTONES_NOTE"))
    frame.note:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 18)
    frame.note:SetWidth(716)
    frame.note:SetJustifyH("LEFT")

    self.milestonesFrame = frame
    return frame
end

function UI:RefreshMilestonesView()
    local frame = self.milestonesFrame
    if not frame then return end
    local milestones = FC.Milestones and FC.Milestones:GetMilestones() or {}
    setText(frame.summary, FC:GetText("MILESTONES_SUMMARY", #milestones), Theme.colors.text)
    if frame.note then frame.note:SetText(FC:GetText("MILESTONES_NOTE")) end

    for i = 1, #frame.lines do
        local milestone = milestones[i]
        if milestone then
            setText(frame.lines[i], string.format("[%s] %s\n   %s", tostring(milestone.category or FC:GetText("CATEGORY_GENERAL")), tostring(milestone.title), tostring(milestone.description or "")),
                i <= 3 and Theme.colors.gold or Theme.colors.muted)
        elseif i == 1 then
            setText(frame.lines[i], FC:GetText("MILESTONES_EMPTY"), Theme.colors.muted)
        else
            setText(frame.lines[i], "")
        end
    end
end

function UI:ShowMilestones()
    local frame = self:CreateMilestonesFrame()
    if FC.Milestones then FC.Milestones:Refresh() end
    self:RefreshMilestonesView()
    frame:Show()
end

local previousCreateMainFrame = UI.CreateMainFrame
function UI:CreateMainFrame(...)
    local frame = previousCreateMainFrame(self, ...)
    if frame and not frame.fcMilestonesButton and frame.pages and frame.pages.Overview and frame.pages.Overview.accountCard then
        local button = Theme:CreateButton(frame.pages.Overview.accountCard, "Milestones", 120, 28)
        button:SetPoint("BOTTOMRIGHT", frame.pages.Overview.accountCard, "BOTTOMRIGHT", -12, 10)
        button:SetScript("OnClick", function() UI:ShowMilestones() end)
        frame.fcMilestonesButton = button
    end
    return frame
end
