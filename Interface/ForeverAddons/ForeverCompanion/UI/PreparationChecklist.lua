local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local function setText(fontString, text, color)
    if not fontString then return end
    color = color or Theme.colors.text
    fontString:SetText(text or "")
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

function UI:CreatePreparationChecklistFrame()
    if self.preparationChecklistFrame then return self.preparationChecklistFrame end

    local frame = Theme:CreatePanel(UIParent, Theme.colors.navy, Theme.colors.gold)
    frame:SetSize(760, 590)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    frame.title = Theme:CreateText(frame, "GameFontNormalHuge", "WHAT DID I FORGET?")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -18)
    frame.title:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])

    frame.closeButton = Theme:CreateButton(frame, "X", 32, 30)
    frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -14)
    frame.closeButton:SetScript("OnClick", function() frame:Hide() end)

    frame.summary = Theme:CreateText(frame, "GameFontHighlight", "")
    frame.summary:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -64)
    frame.summary:SetWidth(716)
    frame.summary:SetJustifyH("LEFT")

    frame.input = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.input:SetSize(455, 30)
    frame.input:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -98)
    frame.input:SetAutoFocus(false)
    frame.input:SetTextInsets(8, 8, 0, 0)

    frame.addButton = Theme:CreateButton(frame, "Add item", 100, 30)
    frame.addButton:SetPoint("LEFT", frame.input, "RIGHT", 10, 0)

    frame.resetButton = Theme:CreateButton(frame, "Reset all", 100, 30)
    frame.resetButton:SetPoint("LEFT", frame.addButton, "RIGHT", 8, 0)

    frame.rows = {}
    for i = 1, 10 do
        local row = Theme:CreateButton(frame, "", 610, 34)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -146 - ((i - 1) * 39))
        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", row, "LEFT", 10, 0)
        row.label:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        row.label:SetJustifyH("LEFT")

        local remove = Theme:CreateButton(frame, "Remove", 90, 34)
        remove:SetPoint("LEFT", row, "RIGHT", 8, 0)

        row:SetScript("OnClick", function(self)
            if self.itemID and FC.PreparationChecklist then
                FC.PreparationChecklist:Toggle(self.itemID)
                UI:RefreshPreparationChecklistView()
                if UI.frame and UI.frame:IsShown() then UI:RefreshDashboard() end
            end
        end)
        remove:SetScript("OnClick", function(self)
            if self.itemID and FC.PreparationChecklist then
                FC.PreparationChecklist:Remove(self.itemID)
                UI:RefreshPreparationChecklistView()
                if UI.frame and UI.frame:IsShown() then UI:RefreshDashboard() end
            end
        end)

        frame.rows[i] = { toggle = row, remove = remove }
    end

    frame.clearDoneButton = Theme:CreateButton(frame, "Remove completed", 155, 30)
    frame.clearDoneButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 20)
    frame.clearDoneButton:SetScript("OnClick", function()
        if FC.PreparationChecklist then FC.PreparationChecklist:RemoveCompleted() end
        UI:RefreshPreparationChecklistView()
    end)

    frame.note = Theme:CreateText(frame, "GameFontDisableSmall",
        "This manual checklist complements the automatic bag, durability, Hearthstone and class-specific checks. It is account-wide and stays until you reset or remove items.")
    frame.note:SetPoint("BOTTOMLEFT", frame.clearDoneButton, "BOTTOMRIGHT", 16, 4)
    frame.note:SetWidth(535)
    frame.note:SetJustifyH("LEFT")

    local function addItem()
        local text = frame.input:GetText() or ""
        if FC.PreparationChecklist then
            local ok, err = FC.PreparationChecklist:Add(text)
            if ok then
                frame.input:SetText("")
                frame.input:ClearFocus()
                UI:RefreshPreparationChecklistView()
                if UI.frame and UI.frame:IsShown() then UI:RefreshDashboard() end
            elseif err then
                FC:Print(err)
            end
        end
    end

    frame.addButton:SetScript("OnClick", addItem)
    frame.input:SetScript("OnEnterPressed", addItem)
    frame.resetButton:SetScript("OnClick", function()
        if FC.PreparationChecklist then FC.PreparationChecklist:Reset() end
        UI:RefreshPreparationChecklistView()
        if UI.frame and UI.frame:IsShown() then UI:RefreshDashboard() end
    end)

    self.preparationChecklistFrame = frame
    return frame
end

function UI:RefreshPreparationChecklistView()
    local frame = self:CreatePreparationChecklistFrame()
    local checklist = FC.PreparationChecklist
    local items = checklist and checklist:GetItems() or {}
    local completed, total, open = checklist and checklist:GetProgress() or 0, 0, 0
    if checklist then completed, total, open = checklist:GetProgress() end

    setText(frame.summary, string.format("%d / %d complete • %d remaining", completed, total, open),
        open == 0 and total > 0 and Theme.colors.green or Theme.colors.text)

    for i, controls in ipairs(frame.rows) do
        local item = items[i]
        if item then
            controls.toggle.itemID = item.id
            controls.remove.itemID = item.id
            controls.toggle:Show()
            controls.remove:Show()
            controls.toggle:SetFCText((item.completed and "✓  " or "□  ") .. tostring(item.label))
            controls.toggle:SetFCActive(item.completed)
        else
            controls.toggle.itemID = nil
            controls.remove.itemID = nil
            controls.toggle:Hide()
            controls.remove:Hide()
        end
    end
end

function UI:ShowPreparationChecklist()
    local frame = self:CreatePreparationChecklistFrame()
    self:RefreshPreparationChecklistView()
    frame:Show()
end

local previousCreateMainFrame = UI.CreateMainFrame
function UI:CreateMainFrame(...)
    local frame = previousCreateMainFrame(self, ...)
    if frame and not frame.fcPreparationChecklistButton and frame.pages and frame.pages.Preparation and frame.pages.Preparation.infoCard then
        local button = Theme:CreateButton(frame.pages.Preparation.infoCard, "Personal Checklist", 160, 30)
        button:SetPoint("BOTTOMRIGHT", frame.pages.Preparation.infoCard, "BOTTOMRIGHT", -14, 12)
        button:SetScript("OnClick", function() UI:ShowPreparationChecklist() end)
        frame.fcPreparationChecklistButton = button
    end
    return frame
end
