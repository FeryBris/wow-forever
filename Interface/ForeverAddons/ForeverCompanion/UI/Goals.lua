local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local function setText(fontString, text, color)
    if not fontString then return end
    color = color or Theme.colors.text
    fontString:SetText(text or "")
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

function UI:CreateGoalsFrame()
    if self.goalsFrame then return self.goalsFrame end

    local frame = Theme:CreatePanel(UIParent, Theme.colors.navy, Theme.colors.gold)
    frame:SetSize(780, 590)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    frame.title = Theme:CreateText(frame, "GameFontNormalHuge", "GOALS & PINS")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -18)
    frame.title:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])

    frame.closeButton = Theme:CreateButton(frame, "X", 32, 30)
    frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -14)
    frame.closeButton:SetScript("OnClick", function() frame:Hide() end)

    frame.input = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.input:SetSize(430, 30)
    frame.input:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -68)
    frame.input:SetAutoFocus(false)
    frame.input:SetTextInsets(8, 8, 0, 0)

    frame.priority = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.priority:SetSize(70, 30)
    frame.priority:SetPoint("LEFT", frame.input, "RIGHT", 12, 0)
    frame.priority:SetAutoFocus(false)
    if type(frame.priority.SetNumeric) == "function" then frame.priority:SetNumeric(true) end
    frame.priority:SetMaxLetters(3)
    frame.priority:SetText("65")

    frame.addButton = Theme:CreateButton(frame, "Pin Goal", 120, 30)
    frame.addButton:SetPoint("LEFT", frame.priority, "RIGHT", 12, 0)

    frame.help = Theme:CreateText(frame, "GameFontDisableSmall", "Goal title                                                        Priority (1-100)")
    frame.help:SetPoint("BOTTOMLEFT", frame.input, "TOPLEFT", 0, 4)

    frame.rows = {}
    for i = 1, 9 do
        local row = Theme:CreatePanel(frame, Theme.colors.panelSoft, Theme.colors.blueSoft)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -122 - ((i - 1) * 46))
        row:SetSize(732, 40)

        row.text = Theme:CreateText(row, "GameFontHighlightSmall", "")
        row.text:SetPoint("LEFT", row, "LEFT", 10, 0)
        row.text:SetWidth(490)
        row.text:SetJustifyH("LEFT")

        row.complete = Theme:CreateButton(row, "Done", 90, 28)
        row.complete:SetPoint("RIGHT", row, "RIGHT", -108, 0)
        row.complete:SetScript("OnClick", function(self)
            if self.goalID and FC.Goals then
                local goal = FC.Goals:GetGoal(self.goalID)
                if goal then FC.Goals:SetCompleted(self.goalID, not goal.completed) end
                UI:RefreshGoalsView()
                if UI.frame and UI.frame:IsShown() then UI:RefreshDashboard() end
            end
        end)

        row.remove = Theme:CreateButton(row, "Remove", 90, 28)
        row.remove:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.remove:SetScript("OnClick", function(self)
            if self.goalID and FC.Goals then
                FC.Goals:Remove(self.goalID)
                UI:RefreshGoalsView()
                if UI.frame and UI.frame:IsShown() then UI:RefreshDashboard() end
            end
        end)

        frame.rows[i] = row
    end

    local function addGoal()
        local title = frame.input:GetText() or ""
        local priority = tonumber(frame.priority:GetText()) or 65
        local ok, result = FC.Goals:Create(title, nil, "Personal", priority)
        if ok then
            frame.input:SetText("")
            frame.input:ClearFocus()
            UI:RefreshGoalsView()
            if UI.frame and UI.frame:IsShown() then UI:RefreshDashboard() end
        else
            FC:Print(result)
        end
    end
    frame.addButton:SetScript("OnClick", addGoal)
    frame.input:SetScript("OnEnterPressed", addGoal)

    frame.note = Theme:CreateText(frame, "GameFontDisableSmall",
        "Goals are account-wide and feed the Smart Suggestions/Journey engine. Crafting goals remain specialized because they also calculate materials.")
    frame.note:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 18)
    frame.note:SetWidth(732)
    frame.note:SetJustifyH("LEFT")

    self.goalsFrame = frame
    return frame
end

function UI:RefreshGoalsView()
    local frame = self.goalsFrame
    if not frame then return end
    local goals = FC.Goals and FC.Goals:GetGoals(true) or {}

    for i = 1, #frame.rows do
        local row = frame.rows[i]
        local goal = goals[i]
        if goal then
            row.goalID = goal.id
            row.complete.goalID = goal.id
            row.remove.goalID = goal.id
            row:Show()
            local state = goal.completed and "DONE" or (goal.enabled == false and "PAUSED" or "ACTIVE")
            setText(row.text, string.format("#%s  [%s]  P%d  %s", tostring(goal.id), state, tonumber(goal.priority) or 0, tostring(goal.title)),
                goal.completed and Theme.colors.muted or Theme.colors.text)
            row.complete:SetFCText(goal.completed and "Reopen" or "Done")
        else
            row.goalID = nil
            row.complete.goalID = nil
            row.remove.goalID = nil
            row:Hide()
        end
    end
end

function UI:ShowGoals()
    local frame = self:CreateGoalsFrame()
    self:RefreshGoalsView()
    frame:Show()
end

local previousCreateMainFrame = UI.CreateMainFrame
function UI:CreateMainFrame(...)
    local frame = previousCreateMainFrame(self, ...)
    if frame and not frame.fcGoalsButton and frame.header then
        local button = Theme:CreateButton(frame.header, "Goals", 80, 30)
        button:SetPoint("RIGHT", frame.refreshButton, "LEFT", -8, 0)
        button:SetScript("OnClick", function() UI:ShowGoals() end)
        frame.fcGoalsButton = button
    end
    return frame
end
