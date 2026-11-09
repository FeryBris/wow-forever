local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local function setText(fontString, text, color)
    if not fontString then return end
    color = color or Theme.colors.text
    fontString:SetText(text or "")
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

function UI:CreateDataTransferFrame()
    if self.dataTransferFrame then return self.dataTransferFrame end

    local frame = Theme:CreatePanel(UIParent, Theme.colors.navy, Theme.colors.gold)
    frame:SetSize(820, 620)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    frame.title = Theme:CreateText(frame, "GameFontNormalHuge", "PLANNING DATA TRANSFER")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -18)
    frame.title:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])

    frame.closeButton = Theme:CreateButton(frame, "X", 32, 30)
    frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -14)
    frame.closeButton:SetScript("OnClick", function() frame:Hide() end)

    frame.exportButton = Theme:CreateButton(frame, "Export Current", 130, 30)
    frame.exportButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -66)

    frame.importButton = Theme:CreateButton(frame, "Import / Merge", 130, 30)
    frame.importButton:SetPoint("LEFT", frame.exportButton, "RIGHT", 10, 0)

    frame.selectButton = Theme:CreateButton(frame, "Select All", 100, 30)
    frame.selectButton:SetPoint("LEFT", frame.importButton, "RIGHT", 10, 0)

    frame.status = Theme:CreateText(frame, "GameFontHighlightSmall", "")
    frame.status:SetPoint("LEFT", frame.selectButton, "RIGHT", 14, 0)
    frame.status:SetWidth(370)
    frame.status:SetJustifyH("LEFT")

    frame.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -110)
    frame.scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -42, 72)

    frame.editBox = CreateFrame("EditBox", nil, frame.scroll)
    frame.editBox:SetMultiLine(true)
    frame.editBox:SetAutoFocus(false)
    frame.editBox:SetFontObject(ChatFontNormal)
    frame.editBox:SetWidth(740)
    frame.editBox:SetTextInsets(8, 8, 8, 8)
    frame.editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    frame.editBox:SetScript("OnTextChanged", function() frame.scroll:UpdateScrollChildRect() end)
    frame.scroll:SetScrollChild(frame.editBox)

    frame.note = Theme:CreateText(frame, "GameFontDisableSmall", FC:GetText("TRANSFER_NOTE"))
    frame.note:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 18)
    frame.note:SetWidth(776)
    frame.note:SetJustifyH("LEFT")

    frame.exportButton:SetScript("OnClick", function()
        local text = FC.Transfer and FC.Transfer:ExportPlanningData() or ""
        frame.editBox:SetText(text)
        frame.editBox:SetFocus()
        frame.editBox:HighlightText()
        setText(frame.status, FC:GetText("TRANSFER_EXPORT_READY"), Theme.colors.green)
    end)

    frame.selectButton:SetScript("OnClick", function()
        frame.editBox:SetFocus()
        frame.editBox:HighlightText()
    end)

    frame.importButton:SetScript("OnClick", function()
        if not FC.Transfer then return end
        local ok, result = FC.Transfer:ImportPlanningData(frame.editBox:GetText())
        if ok then
            setText(frame.status, FC:GetText("TRANSFER_IMPORTED",
                tonumber(result.goals) or 0, tonumber(result.checklist) or 0, tonumber(result.crafting) or 0,
                tonumber(result.routes) or 0, tonumber(result.recipeSources) or 0, tonumber(result.skipped) or 0), Theme.colors.green)
        else
            setText(frame.status, tostring(result or FC:GetText("TRANSFER_UNSUPPORTED_HEADER")), Theme.colors.yellow)
        end
    end)

    self.dataTransferFrame = frame
    return frame
end

function UI:ShowDataTransfer()
    local frame = self:CreateDataTransferFrame()
    if frame.note then frame.note:SetText(FC:GetText("TRANSFER_NOTE")) end
    frame:Show()
end
