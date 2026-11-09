local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

-- Most module toggles now live in UI/Settings.lua. Keep this extension only
-- for modules introduced later or companion subfeatures that need an explicit
-- recovery switch in the UI when disabled.
local EXTRA_MODULES = {
    { name = "RecipeSources", key = "RECIPE_SOURCES" },
    { name = "TravelRoutes", key = "ROUTES" },
}

local previousCreateSettingsFrame = UI.CreateSettingsFrame
function UI:CreateSettingsFrame(...)
    local frame = previousCreateSettingsFrame(self, ...)
    if frame and not frame.extraModuleButtons then
        frame.extraModuleButtons = {}
        local startIndex = #(frame.moduleButtons or {})
        for offset, moduleInfo in ipairs(EXTRA_MODULES) do
            local index = startIndex + offset
            local column = (index - 1) % 4
            local row = math.floor((index - 1) / 4)
            local button = Theme:CreateButton(frame, moduleInfo.name, 184, 38)
            button:SetPoint("TOPLEFT", frame, "TOPLEFT", 24 + (column * 194), -372 - (row * 48))
            button.moduleName = moduleInfo.name
            button.localeKey = moduleInfo.key
            button:SetScript("OnClick", function(self)
                local enabled = FC:IsModuleEnabled(self.moduleName)
                FC:SetModuleEnabled(self.moduleName, not enabled)
                UI:RefreshSettingsView()
            end)
            frame.extraModuleButtons[#frame.extraModuleButtons + 1] = button
        end
    end
    return frame
end

local previousRefreshSettingsView = UI.RefreshSettingsView
function UI:RefreshSettingsView(...)
    previousRefreshSettingsView(self, ...)
    local frame = self.settingsFrame
    for _, button in ipairs(frame and frame.extraModuleButtons or {}) do
        local enabled = FC:IsModuleEnabled(button.moduleName)
        button:SetFCText(FC:GetText(button.localeKey) .. ": " .. FC:GetText(enabled and "ENABLED" or "DISABLED"))
        button:SetFCActive(enabled)
    end
end
