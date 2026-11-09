local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local CATEGORY_KEYS = {
    Preparation = "CATEGORY_PREPARATION",
    Profession = "CATEGORY_PROFESSION",
    Legacy = "CATEGORY_LEGACY",
    Camp = "CATEGORY_CAMP",
    Travel = "CATEGORY_TRAVEL",
    Dungeon = "CATEGORY_DUNGEON",
    Milestone = "CATEGORY_MILESTONE",
    Goal = "CATEGORY_GOAL",
    Journey = "CATEGORY_JOURNEY",
    Crafting = "CATEGORY_CRAFTING",
    Personal = "CATEGORY_PERSONAL",
    General = "CATEGORY_GENERAL",
}

local function setText(fontString, text, color)
    if not fontString then return end
    fontString:SetText(text or "")
    color = color or Theme.colors.text
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function categoryText(value)
    local raw = tostring(value or "General")
    local key = CATEGORY_KEYS[raw]
    return key and FC:GetText(key) or raw
end

local previousRefreshGoalsView = UI.RefreshGoalsView
if type(previousRefreshGoalsView) == "function" then
    function UI:RefreshGoalsView(...)
        previousRefreshGoalsView(self, ...)
        local frame = self.goalsFrame
        if not frame or not FC.Goals then return end
        local goals = FC.Goals:GetGoals(true) or {}
        local page = math.max(1, tonumber(frame.goalPage) or 1)
        local startIndex = ((page - 1) * 9) + 1

        for index, row in ipairs(frame.rows or {}) do
            local goal = goals[startIndex + index - 1]
            if goal and row:IsShown() then
                local stateKey = goal.completed and "STATE_DONE" or (goal.enabled == false and "STATE_PAUSED" or "STATE_ACTIVE")
                local title = type(FC.Goals.GetDisplayTitle) == "function" and FC.Goals:GetDisplayTitle(goal) or tostring(goal.title or "")
                setText(row.text, string.format("#%s  [%s]  P%d  %s",
                    tostring(goal.id), FC:GetText(stateKey), tonumber(goal.priority) or 0, title),
                    goal.completed and Theme.colors.muted or Theme.colors.text)
            end
        end
    end
end

local previousRefreshMilestonesView = UI.RefreshMilestonesView
if type(previousRefreshMilestonesView) == "function" then
    function UI:RefreshMilestonesView(...)
        previousRefreshMilestonesView(self, ...)
        local frame = self.milestonesFrame
        if not frame or not FC.Milestones then return end
        local milestones = FC.Milestones:GetMilestones() or {}
        local page = math.max(1, tonumber(frame.milestonePage) or 1)
        local startIndex = ((page - 1) * 11) + 1

        for index, line in ipairs(frame.lines or {}) do
            local milestone = milestones[startIndex + index - 1]
            if milestone then
                local title = type(FC.Milestones.GetDisplayTitle) == "function" and FC.Milestones:GetDisplayTitle(milestone) or tostring(milestone.title or "")
                local description = type(FC.Milestones.GetDisplayDescription) == "function" and FC.Milestones:GetDisplayDescription(milestone) or tostring(milestone.description or "")
                setText(line, string.format("[%s] %s\n   %s", categoryText(milestone.category), title, description),
                    index <= 3 and Theme.colors.gold or Theme.colors.muted)
            end
        end
    end
end
