local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local originalGetDiagnosticsText = FC.GetDiagnosticsText

function FC:GetDiagnosticsText()
    local text = originalGetDiagnosticsText(self)
    local snapshot = self.Legacy and self.Legacy:GetSnapshot() or nil
    local legacyStatus

    if snapshot then
        legacyStatus = string.format("  Legacy: YES (%d/%d challenges complete)", snapshot.completed or 0, snapshot.total or 0)
    elseif self.API.capabilities and self.API.capabilities.legacy then
        legacyStatus = "  Legacy: YES (achievement API detected; challenge tree pending)"
    else
        legacyStatus = "  Legacy: NO"
    end

    text = text:gsub("  Legacy:[^\n]*", legacyStatus)

    local store = self.DB and self.DB.account and self.DB.account.legacy
    if store then
        text = text .. "\nLegacy last scan: " .. tostring(store.lastScan or "never")
        if store.lastError then
            text = text .. "\nLegacy last error: " .. tostring(store.lastError)
        end
    end

    return text
end

local function appendSessionLog(text)
    local entries = FC.Logger and FC.Logger.session or {}
    if #entries == 0 then
        return text .. "\n\nSession log: no entries"
    end

    local lines = { text, "", "Session log (latest entries):" }
    local first = math.max(1, #entries - 39)
    for index = first, #entries do
        local entry = entries[index]
        lines[#lines + 1] = string.format("[%s/%s] %s",
            tostring(entry.category or "CORE"),
            tostring(entry.level or "INFO"),
            tostring(entry.message or ""))
    end
    return table.concat(lines, "\n")
end

function UI:CreateDiagnosticsFrame()
    if self.diagnosticsFrame then
        return self.diagnosticsFrame
    end

    local frame = Theme:CreatePanel(UIParent, Theme.colors.navy, Theme.colors.gold)
    frame:SetSize(780, 580)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    frame.title = Theme:CreateText(frame, "GameFontNormalHuge", "FOREVER COMPANION DIAGNOSTICS")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -18)
    frame.title:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])

    frame.hint = Theme:CreateText(frame, "GameFontHighlightSmall", "Click inside the text, then Ctrl+A and Ctrl+C to copy it for a bug report.")
    frame.hint:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -5)
    frame.hint:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3])

    frame.closeButton = Theme:CreateButton(frame, "X", 32, 30)
    frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -14)
    frame.closeButton:SetScript("OnClick", function() frame:Hide() end)

    frame.refreshButton = Theme:CreateButton(frame, "Refresh", 90, 30)
    frame.refreshButton:SetPoint("RIGHT", frame.closeButton, "LEFT", -8, 0)
    frame.refreshButton:SetScript("OnClick", function()
        FC:RefreshModules("diagnostics")
        UI:RefreshDiagnosticsView()
    end)

    frame.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -86)
    frame.scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -42, 22)

    frame.editBox = CreateFrame("EditBox", nil, frame.scroll)
    frame.editBox:SetMultiLine(true)
    frame.editBox:SetAutoFocus(false)
    frame.editBox:SetFontObject(ChatFontNormal)
    frame.editBox:SetWidth(700)
    frame.editBox:SetTextInsets(8, 8, 8, 8)
    frame.editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    frame.editBox:SetScript("OnTextChanged", function()
        frame.scroll:UpdateScrollChildRect()
    end)
    frame.scroll:SetScrollChild(frame.editBox)

    self.diagnosticsFrame = frame
    return frame
end

function UI:RefreshDiagnosticsView()
    local frame = self:CreateDiagnosticsFrame()
    local text = appendSessionLog(FC:GetDiagnosticsText())
    frame.editBox:SetText(text)
    frame.editBox:SetCursorPosition(0)
end

function UI:ShowDiagnostics()
    local frame = self:CreateDiagnosticsFrame()
    self:RefreshDiagnosticsView()
    frame:Show()
    frame.editBox:SetFocus()
    frame.editBox:HighlightText()
end

function FC:PrintDiagnostics()
    UI:ShowDiagnostics()
end
