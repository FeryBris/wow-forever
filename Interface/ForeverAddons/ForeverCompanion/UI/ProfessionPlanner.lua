local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local function setText(fontString, text, color)
    if not fontString then return end
    color = color or Theme.colors.text
    fontString:SetText(text or "")
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

function UI:CreateProfessionPlannerFrame()
    if self.professionPlannerFrame then return self.professionPlannerFrame end

    local frame = Theme:CreatePanel(UIParent, Theme.colors.navy, Theme.colors.gold)
    frame:SetSize(780, 580)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    frame.title = Theme:CreateText(frame, "GameFontNormalHuge", "PROFESSION PLANNER")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -18)
    frame.title:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])

    frame.closeButton = Theme:CreateButton(frame, "X", 32, 30)
    frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -14)
    frame.closeButton:SetScript("OnClick", function() frame:Hide() end)

    frame.professionButtons = {}
    for i = 1, 5 do
        local button = Theme:CreateButton(frame, "", 138, 32)
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", 24 + ((i - 1) * 146), -72)
        button:SetScript("OnClick", function(self)
            frame.selectedSkillLineID = self.skillLineID
            UI:RefreshProfessionPlannerView()
        end)
        frame.professionButtons[i] = button
    end

    frame.summary = Theme:CreateText(frame, "GameFontHighlight", "")
    frame.summary:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -122)
    frame.summary:SetWidth(732)
    frame.summary:SetJustifyH("LEFT")

    frame.stageTitle = Theme:CreateSectionTitle(frame, "Progression Steps")
    frame.stageTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -162)

    frame.stageLines = {}
    for i = 1, 9 do
        local line = Theme:CreateText(frame, "GameFontHighlightSmall", "")
        line:SetPoint("TOPLEFT", frame, "TOPLEFT", 26, -196 - ((i - 1) * 38))
        line:SetWidth(710)
        line:SetJustifyH("LEFT")
        line:SetJustifyV("TOP")
        frame.stageLines[i] = line
    end

    frame.pinButton = Theme:CreateButton(frame, "Pin cap as goal", 160, 30)
    frame.pinButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 46)
    frame.pinButton:SetScript("OnClick", function()
        if not frame.currentPlan or not FC.Goals then return end
        local plan = frame.currentPlan
        FC.Goals:PinReference("Profession", plan.skillLineID,
            string.format("Reach %d %s", tonumber(plan.target) or 0, tostring(plan.name)),
            string.format("Current progress: %d/%d", tonumber(plan.current) or 0, tonumber(plan.target) or 0), 66,
            { targetSkill = plan.target })
        FC:Print("Profession goal pinned.")
    end)

    frame.note = Theme:CreateText(frame, "GameFontDisableSmall",
        "The planner uses observed profession skill, cached recipes, crafting goals and known camp thresholds. It does not invent leveling routes or claim an optimal recipe path without source data.")
    frame.note:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 18)
    frame.note:SetWidth(732)
    frame.note:SetJustifyH("LEFT")

    self.professionPlannerFrame = frame
    return frame
end

function UI:RefreshProfessionPlannerView()
    local frame = self.professionPlannerFrame
    if not frame then return end
    local professions = FC.ProfessionPlanner and FC.ProfessionPlanner:GetAvailableProfessions() or {}

    local selectedExists = false
    for i = 1, #frame.professionButtons do
        local button = frame.professionButtons[i]
        local profession = professions[i]
        if profession then
            button.skillLineID = profession.skillLineID
            button:SetFCText(tostring(profession.name))
            button:SetFCActive(frame.selectedSkillLineID == profession.skillLineID)
            button:Show()
            if frame.selectedSkillLineID == profession.skillLineID then selectedExists = true end
        else
            button.skillLineID = nil
            button:Hide()
        end
    end

    if not selectedExists and professions[1] then frame.selectedSkillLineID = professions[1].skillLineID end

    local plan, err
    if FC.ProfessionPlanner then
        plan, err = FC.ProfessionPlanner:BuildPlan(frame.selectedSkillLineID)
    else
        err = "Profession Planner module is unavailable."
    end
    frame.currentPlan = plan

    for _, button in ipairs(frame.professionButtons) do
        if button:IsShown() then button:SetFCActive(button.skillLineID == frame.selectedSkillLineID) end
    end

    if not plan then
        setText(frame.summary, err or "No profession data is currently available.", Theme.colors.muted)
        for _, line in ipairs(frame.stageLines) do setText(line, "") end
        frame.pinButton:Hide()
        return
    end

    frame.pinButton:Show()
    setText(frame.summary, string.format("%s: %d/%d  •  %d skill point(s) to target", tostring(plan.name), tonumber(plan.current) or 0, tonumber(plan.target) or 0, tonumber(plan.remaining) or 0), Theme.colors.text)
    for i = 1, #frame.stageLines do
        local stage = plan.stages and plan.stages[i]
        if stage then
            setText(frame.stageLines[i], string.format("@ %d  %s\n   %s", tonumber(stage.skill) or 0, tostring(stage.title), tostring(stage.description or "")),
                (tonumber(stage.skill) or 0) <= (tonumber(plan.current) or 0) and Theme.colors.green or Theme.colors.text)
        else
            setText(frame.stageLines[i], "")
        end
    end
end

function UI:ShowProfessionPlanner()
    local frame = self:CreateProfessionPlannerFrame()
    self:RefreshProfessionPlannerView()
    frame:Show()
end

local previousCreateMainFrame = UI.CreateMainFrame
function UI:CreateMainFrame(...)
    local frame = previousCreateMainFrame(self, ...)
    if frame and not frame.fcProfessionPlannerButton and frame.pages and frame.pages.Professions and frame.pages.Professions.skillsCard then
        local button = Theme:CreateButton(frame.pages.Professions.skillsCard, "Planner", 100, 26)
        button:SetPoint("TOPRIGHT", frame.pages.Professions.skillsCard, "TOPRIGHT", -10, -9)
        button:SetScript("OnClick", function() UI:ShowProfessionPlanner() end)
        frame.fcProfessionPlannerButton = button
    end
    return frame
end
