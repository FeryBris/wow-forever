local _, FC = ...

local LoginSummary = {}

function LoginSummary:ShowDelayed()
    if not FC.DB or not FC.DB.settings or FC.DB.settings.showLoginSummary == false then return end
    local callback = function()
        if self.enabled and FC.UI and FC.UI.ShowLoginSummary then
            FC:RefreshModules("login-summary")
            FC.UI:ShowLoginSummary()
        end
    end
    if C_Timer and C_Timer.After then C_Timer.After(1.0, callback) else callback() end
end

function LoginSummary:OnEvent(event)
    if event == "PLAYER_LOGIN" then self:ShowDelayed() end
end

FC:RegisterModule("LoginSummary", LoginSummary)
