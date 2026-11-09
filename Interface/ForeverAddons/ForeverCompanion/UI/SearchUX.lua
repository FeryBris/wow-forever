local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local previousCreateMainFrame = UI.CreateMainFrame
function UI:CreateMainFrame(...)
    local frame = previousCreateMainFrame(self, ...)
    if not frame or frame.fcSearchExpansion then return frame end
    frame.fcSearchExpansion = true

    local panel = frame.fcSearchResults
    if not panel then return frame end

    if panel.footer then
        panel.footer:SetWidth(315)
    end

    local viewAll = Theme:CreateButton(panel, "View all results", 150, 26)
    viewAll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 6)
    viewAll:SetScript("OnClick", function()
        local query = frame.fcSearchBox and frame.fcSearchBox:GetText() or ""
        panel:Hide()
        if frame.fcSearchBox then frame.fcSearchBox:ClearFocus() end
        if UI.ShowGlobalSearch then UI:ShowGlobalSearch(query) end
    end)
    panel.viewAllButton = viewAll

    return frame
end
