local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local previousCreateSettingsFrame = UI.CreateSettingsFrame
function UI:CreateSettingsFrame(...)
    local frame = previousCreateSettingsFrame(self, ...)
    if frame and not frame.loginSummaryButton then
        local button = Theme:CreateButton(frame, "", 220, 34)
        button:SetPoint("LEFT", frame.debugButton, "RIGHT", 12, 0)
        button:SetScript("OnClick", function()
            FC.DB.settings.showLoginSummary = not (FC.DB.settings.showLoginSummary ~= false)
            UI:RefreshSettingsView()
        end)
        frame.loginSummaryButton = button
    end
    return frame
end

local previousRefreshSettingsView = UI.RefreshSettingsView
function UI:RefreshSettingsView(...)
    previousRefreshSettingsView(self, ...)
    local frame = self.settingsFrame
    if not frame or not frame.loginSummaryButton then return end
    local enabled = FC.DB and FC.DB.settings and FC.DB.settings.showLoginSummary ~= false
    frame.loginSummaryButton:SetFCText("Login summary: " .. FC:GetText(enabled and "ENABLED" or "DISABLED"))
    frame.loginSummaryButton:SetFCActive(enabled)
end
