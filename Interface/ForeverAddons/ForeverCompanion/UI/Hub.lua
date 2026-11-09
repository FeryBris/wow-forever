local _, FC = ...

local UI = FC.UI

-- Compatibility entry point kept for older slash-command/docs references.
-- The separate legacy Hub window was replaced by the main window's Features drawer.
function UI:ShowHub()
    local frame = self:CreateMainFrame()
    if not frame then return end

    if not frame:IsShown() then
        FC:RefreshModules("hub")
        self:SwitchTab(self.activeTab or "Overview")
        frame:Show()
    end

    if frame.fcSearchResults then frame.fcSearchResults:Hide() end
    if frame.fcSearchBox then frame.fcSearchBox:ClearFocus() end

    local drawer = frame.fcFeatureDrawer
    if drawer then
        if type(drawer.Refresh) == "function" then drawer:Refresh() end
        drawer:Show()
    end
end
