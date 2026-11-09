local _, FC = ...

local function countEntries(tbl)
    local count = 0
    for _ in pairs(tbl or {}) do count = count + 1 end
    return count
end

local previousGetDiagnosticsText = FC.GetDiagnosticsText
function FC:GetDiagnosticsText()
    local base = type(previousGetDiagnosticsText) == "function" and previousGetDiagnosticsText(self) or "Forever Companion Diagnostics"
    local account = self.DB and self.DB.account or {}
    local lines = {
        base,
        "UI-first planning data:",
        "  Recipe source notes: " .. tostring(countEntries(account.recipeSources)),
        "  Custom travel routes: " .. tostring(countEntries(account.travelRoutes)),
        "  Preparation checklist: " .. tostring(countEntries(account.preparationChecklist and account.preparationChecklist.items)),
        "  Snoozed suggestions: " .. tostring(countEntries(account.suggestionState and account.suggestionState.snoozed)),
        "  Recipe source providers: " .. tostring(self.RecipeSources and self.RecipeSources:GetProviderCount() or 0),
        "  Travel route providers: " .. tostring(self.TravelRoutes and self.TravelRoutes:GetProviderCount() or 0),
    }
    return table.concat(lines, "\n")
end
