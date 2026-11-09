local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local function setStatus(label, text, isError)
    if not label then return end
    label:SetText(text or "")
    local color = isError and Theme.colors.yellow or Theme.colors.green
    label:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local previousCreateGoalsFrame = UI.CreateGoalsFrame
function UI:CreateGoalsFrame(...)
    local frame = previousCreateGoalsFrame(self, ...)
    if not frame or frame.fcInlineFeedback then return frame end
    frame.fcInlineFeedback = true

    local status = Theme:CreateText(frame, "GameFontHighlightSmall", "")
    status:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -104)
    status:SetWidth(720)
    status:SetJustifyH("LEFT")
    frame.actionStatus = status

    local function addGoal()
        local title = frame.input:GetText() or ""
        local priority = tonumber(frame.priority:GetText()) or 65
        local ok, result = FC.Goals:Create(title, nil, "Personal", priority)
        if ok then
            frame.input:SetText("")
            frame.input:ClearFocus()
            setStatus(status, FC:GetText("GOAL_PINNED"), false)
            UI:RefreshGoalsView()
            if UI.frame and UI.frame:IsShown() then UI:RefreshDashboard() end
        else
            setStatus(status, tostring(result or FC:GetText("GOAL_CREATE_FAILED")), true)
        end
    end
    frame.addButton:SetScript("OnClick", addGoal)
    frame.input:SetScript("OnEnterPressed", addGoal)
    return frame
end

local previousCreateTravelRoutesFrame = UI.CreateTravelRoutesFrame
function UI:CreateTravelRoutesFrame(...)
    local frame = previousCreateTravelRoutesFrame(self, ...)
    if not frame or frame.fcInlineFeedback then return frame end
    frame.fcInlineFeedback = true

    local status = Theme:CreateText(frame, "GameFontHighlightSmall", "")
    status:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 42)
    status:SetWidth(856)
    status:SetJustifyH("LEFT")
    frame.actionStatus = status

    local function addRoute()
        if not FC.TravelRoutes then return end
        local ok, result = FC.TravelRoutes:Create(nil, frame.origin:GetText(), frame.destination:GetText(), frame.notes:GetText(), frame.routeType:GetText())
        if ok then
            frame.origin:SetText("")
            frame.destination:SetText("")
            frame.notes:SetText("")
            setStatus(status, FC:GetText("ROUTE_ADDED"), false)
            UI:RefreshTravelRoutesView()
        else
            setStatus(status, tostring(result or FC:GetText("ROUTE_ADD_FAILED")), true)
        end
    end
    frame.addButton:SetScript("OnClick", addRoute)
    frame.notes:SetScript("OnEnterPressed", addRoute)
    return frame
end

local previousCreateRecipeSourcesFrame = UI.CreateRecipeSourcesFrame
function UI:CreateRecipeSourcesFrame(...)
    local frame = previousCreateRecipeSourcesFrame(self, ...)
    if not frame or frame.fcInlineFeedback then return frame end
    frame.fcInlineFeedback = true

    local status = Theme:CreateText(frame.detail, "GameFontHighlightSmall", "")
    status:SetPoint("LEFT", frame.remove, "RIGHT", 10, 0)
    status:SetWidth(105)
    status:SetJustifyH("LEFT")
    frame.actionStatus = status

    frame.save:SetScript("OnClick", function()
        if not frame.selectedRecipeID or not FC.RecipeSources then
            setStatus(status, FC:GetText("SELECT_RECIPE_FIRST"), true)
            return
        end
        local ok, err = FC.RecipeSources:SetUserNote(
            frame.selectedRecipeID,
            frame.selectedSourceType or "Other",
            frame.sourceName:GetText(),
            frame.location:GetText(),
            frame.notes:GetText()
        )
        if not ok then
            setStatus(status, tostring(err or FC:GetText("SAVE_FAILED")), true)
            return
        end
        setStatus(status, FC:GetText("SAVED"), false)
        FC.RecipeSources:Refresh()
        UI:RefreshRecipeSourcesView()
    end)

    frame.remove:SetScript("OnClick", function()
        if not frame.selectedRecipeID or not FC.RecipeSources then
            setStatus(status, FC:GetText("SELECT_RECIPE_FIRST"), true)
            return
        end
        local removed = FC.RecipeSources:RemoveUserNote(frame.selectedRecipeID)
        frame.selectedSourceType = "Other"
        frame.sourceName:SetText("")
        frame.location:SetText("")
        frame.notes:SetText("")
        setStatus(status, removed and FC:GetText("REMOVED") or FC:GetText("NO_NOTE_REMOVE"), not removed)
        FC.RecipeSources:Refresh()
        UI:RefreshRecipeSourcesView()
    end)
    return frame
end
