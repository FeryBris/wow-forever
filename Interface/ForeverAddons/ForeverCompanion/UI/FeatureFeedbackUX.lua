local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local function setStatus(label, text, isError)
    if not label then return end
    label:SetText(text or "")
    local color = isError and Theme.colors.yellow or Theme.colors.green
    label:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local previousCreateProfessionPlannerFrame = UI.CreateProfessionPlannerFrame
function UI:CreateProfessionPlannerFrame(...)
    local frame = previousCreateProfessionPlannerFrame(self, ...)
    if not frame or frame.fcActionFeedback then return frame end
    frame.fcActionFeedback = true

    local status = Theme:CreateText(frame, "GameFontHighlightSmall", "")
    status:SetPoint("BOTTOMRIGHT", frame.pinButton, "TOPRIGHT", 0, 8)
    status:SetWidth(330)
    status:SetJustifyH("RIGHT")
    frame.actionStatus = status

    frame.pinButton:SetScript("OnClick", function()
        if not frame.currentPlan or not FC.Goals then
            setStatus(status, FC:GetText("PROFESSION_GOAL_FAILED"), true)
            return
        end
        local plan = frame.currentPlan
        local ok, result = FC.Goals:PinReference(
            "Profession",
            plan.skillLineID,
            FC:GetText("PROF_PLAN_PIN_TITLE", tonumber(plan.target) or 0, tostring(plan.name)),
            FC:GetText("PROF_PLAN_PIN_DESC", tonumber(plan.current) or 0, tonumber(plan.target) or 0),
            66,
            { targetSkill = plan.target }
        )
        setStatus(status, ok and FC:GetText("PROFESSION_GOAL_PINNED") or tostring(result or FC:GetText("PROFESSION_GOAL_FAILED")), not ok)
        if ok and UI.frame and UI.frame:IsShown() then UI:RefreshDashboard() end
    end)
    return frame
end

local previousCreatePreparationChecklistFrame = UI.CreatePreparationChecklistFrame
function UI:CreatePreparationChecklistFrame(...)
    local frame = previousCreatePreparationChecklistFrame(self, ...)
    if not frame or frame.fcActionFeedback then return frame end
    frame.fcActionFeedback = true

    local status = Theme:CreateText(frame, "GameFontHighlightSmall", "")
    status:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -130)
    status:SetWidth(700)
    status:SetJustifyH("LEFT")
    frame.actionStatus = status

    local function addItem()
        local text = frame.input:GetText() or ""
        if not FC.PreparationChecklist then
            setStatus(status, FC:GetText("CHECKLIST_ADD_FAILED"), true)
            return
        end
        local ok, result = FC.PreparationChecklist:Add(text)
        if ok then
            frame.input:SetText("")
            frame.input:ClearFocus()
            setStatus(status, FC:GetText("CHECKLIST_ITEM_ADDED"), false)
            UI:RefreshPreparationChecklistView()
            if UI.frame and UI.frame:IsShown() then UI:RefreshDashboard() end
        else
            setStatus(status, tostring(result or FC:GetText("CHECKLIST_ADD_FAILED")), true)
        end
    end

    frame.addButton:SetScript("OnClick", addItem)
    frame.input:SetScript("OnEnterPressed", addItem)
    return frame
end

local previousCreateSuggestionsFrame = UI.CreateSuggestionsFrame
function UI:CreateSuggestionsFrame(...)
    local frame = previousCreateSuggestionsFrame(self, ...)
    if not frame or frame.fcActionFeedback then return frame end
    frame.fcActionFeedback = true

    local status = Theme:CreateText(frame, "GameFontHighlightSmall", "")
    status:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -22, -69)
    status:SetWidth(360)
    status:SetJustifyH("RIGHT")
    frame.actionStatus = status

    for _, card in ipairs(frame.rows or {}) do
        card.pin:SetScript("OnClick", function(self)
            if not self.suggestionID then return end
            local ok, result = FC.Suggestions:PinAsGoal(self.suggestionID)
            setStatus(status, ok and FC:GetText("SUGGESTION_PINNED") or tostring(result or FC:GetText("SUGGESTION_PIN_FAILED")), not ok)
            UI:RefreshSuggestionsView()
            if ok and UI.frame and UI.frame:IsShown() then UI:RefreshDashboard() end
        end)
    end
    return frame
end

local previousCreateCampsFrame = UI.CreateCampsFrame
function UI:CreateCampsFrame(...)
    local frame = previousCreateCampsFrame(self, ...)
    if not frame or frame.fcActionFeedback then return frame end
    frame.fcActionFeedback = true

    frame.finderButton:SetScript("OnClick", function()
        if not FC.CampFinder then
            setStatus(frame.finderStatus, FC:GetText("CAMP_FINDER_FAILED"), true)
            return
        end
        local ok = FC.CampFinder:OpenMap()
        if not ok then
            setStatus(frame.finderStatus, FC:GetText("CAMP_FINDER_FAILED"), true)
            return
        end

        local provider = FC.CampFinder:GetDetectedProvider()
        if provider then
            setStatus(frame.finderStatus, FC:GetText("CAMP_FINDER_PROVIDER",
                tostring(provider.name or provider.id or "Provider"),
                provider.version and (" " .. tostring(provider.version)) or ""), false)
        else
            setStatus(frame.finderStatus, FC:GetText("CAMP_FINDER_NONE"), false)
        end
    end)
    return frame
end
