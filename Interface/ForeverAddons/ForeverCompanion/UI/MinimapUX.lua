local _, FC = ...

local UI = FC.UI
local MinimapButton = UI.Minimap

if not MinimapButton then return end

local function showFreshDashboard(reason)
    FC:RefreshModules(reason or "minimap-open")
    local frame = UI:CreateMainFrame()
    if type(UI.RefreshDashboard) == "function" then UI:RefreshDashboard() end
    frame:Show()
    return frame
end

local previousCreate = MinimapButton.Create
function MinimapButton:Create(...)
    local button = previousCreate(self, ...)
    if not button or button.fcPrimaryUX then return button end
    button.fcPrimaryUX = true

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Forever Companion", 1.00, 0.82, 0.28)
        GameTooltip:AddLine(FC:GetText("MINIMAP_TAGLINE"), 0.45, 0.82, 1.00)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(FC:GetText("MINIMAP_LEFT_CLICK"), FC:GetText("MINIMAP_LEFT_ACTION"), 1, 1, 1, 0.70, 0.90, 1.00)
        GameTooltip:AddDoubleLine(FC:GetText("MINIMAP_RIGHT_CLICK"), FC:GetText("MINIMAP_RIGHT_ACTION"), 1, 1, 1, 0.70, 0.90, 1.00)
        GameTooltip:AddDoubleLine(FC:GetText("MINIMAP_MIDDLE_CLICK"), FC:GetText("MINIMAP_MIDDLE_ACTION"), 1, 1, 1, 0.70, 0.90, 1.00)
        GameTooltip:AddDoubleLine(FC:GetText("MINIMAP_DRAG"), FC:GetText("MINIMAP_DRAG_ACTION"), 1, 1, 1, 0.70, 0.90, 1.00)
        GameTooltip:Show()
    end)

    button:SetScript("OnClick", function(self, mouseButton)
        if self.ignoreNextClick then
            self.ignoreNextClick = nil
            return
        end

        local frame = UI:CreateMainFrame()
        if mouseButton == "LeftButton" then
            if frame:IsShown() then
                frame:Hide()
            else
                showFreshDashboard("minimap-left")
            end
        elseif mouseButton == "RightButton" then
            frame = showFreshDashboard("minimap-right")
            if frame.fcFeatureDrawer then
                if frame.fcFeatureDrawer.Refresh then frame.fcFeatureDrawer:Refresh() end
                frame.fcFeatureDrawer:Show()
            end
        elseif mouseButton == "MiddleButton" then
            frame = showFreshDashboard("minimap-middle")
            if frame.fcFeatureDrawer then frame.fcFeatureDrawer:Hide() end
            if frame.fcSearchBox then
                frame.fcSearchBox:SetFocus()
                frame.fcSearchBox:HighlightText()
            end
        end
    end)

    return button
end
