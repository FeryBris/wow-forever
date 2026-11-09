local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local function setMuted(fontString, text)
    if not fontString then return end
    fontString:SetText(text or "")
    fontString:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], Theme.colors.muted[4] or 1)
end

local previousRefreshGoalsView = UI.RefreshGoalsView
if type(previousRefreshGoalsView) == "function" then
    function UI:RefreshGoalsView(...)
        previousRefreshGoalsView(self, ...)
        local frame = self.goalsFrame
        if not frame then return end
        if frame.help then frame.help:SetText(FC:GetText("GOALS_HELP")) end
        if frame.note then setMuted(frame.note, FC:GetText("GOALS_NOTE")) end
    end
end

local previousRefreshTravelRoutesView = UI.RefreshTravelRoutesView
if type(previousRefreshTravelRoutesView) == "function" then
    function UI:RefreshTravelRoutesView(...)
        previousRefreshTravelRoutesView(self, ...)
        local frame = self.travelRoutesFrame
        local module = FC.TravelRoutes
        if not frame or not module then return end

        local routes = module:GetAllRoutes(true) or {}
        local providerCount = module:GetProviderCount() or 0
        local userCount = #(module:GetUserRoutes(true) or {})
        if frame.summary then frame.summary:SetText(FC:GetText("ROUTES_SUMMARY", userCount, providerCount, #routes)) end
        if frame.hints then setMuted(frame.hints, FC:GetText("ROUTES_HINTS")) end
        if frame.note then setMuted(frame.note, FC:GetText("ROUTES_NOTE")) end

        if #routes == 0 and frame.rows and frame.rows[1] and frame.rows[1].text then
            setMuted(frame.rows[1].text, FC:GetText("ROUTES_EMPTY"))
        end
    end
end

local previousRefreshPreparationChecklistView = UI.RefreshPreparationChecklistView
if type(previousRefreshPreparationChecklistView) == "function" then
    function UI:RefreshPreparationChecklistView(...)
        previousRefreshPreparationChecklistView(self, ...)
        local frame = self.preparationChecklistFrame
        if frame and frame.note then setMuted(frame.note, FC:GetText("CHECKLIST_NOTE")) end
    end
end
