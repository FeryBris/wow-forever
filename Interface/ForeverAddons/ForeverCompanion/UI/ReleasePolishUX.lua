local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local function setCraftingGoalHint(page, key, color)
    if not page or not page.goalHint then return end
    page.goalHint:SetText(FC:GetText(key))
    color = color or Theme.colors.muted
    page.goalHint:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local previousCreateMainFrame = UI.CreateMainFrame
function UI:CreateMainFrame(...)
    local frame = previousCreateMainFrame(self, ...)
    if not frame or frame.fcReleasePolish then return frame end
    frame.fcReleasePolish = true

    local professions = frame.pages and frame.pages.Professions
    if professions then
        for _, button in ipairs(professions.recipeButtons or {}) do
            button:SetScript("OnClick", function(self)
                if not self.recipeID or not FC.CraftingGoals then return end

                local goals = FC.DB and FC.DB.account and FC.DB.account.craftingGoals or {}
                if goals[self.recipeID] then
                    FC.CraftingGoals:RemoveGoal(self.recipeID)
                else
                    local ok = FC.CraftingGoals:AddGoal(self.recipeID, 1)
                    if not ok then
                        setCraftingGoalHint(professions, "CRAFTING_GOAL_UPDATE_FAILED", Theme.colors.yellow)
                        return
                    end
                end

                setCraftingGoalHint(professions, "CRAFTING_GOAL_HINT", Theme.colors.muted)
                UI:RefreshDashboard()
            end)
        end
    end

    return frame
end

local previousApplyPrimaryLocalization = UI.ApplyPrimaryLocalization
function UI:ApplyPrimaryLocalization(...)
    if type(previousApplyPrimaryLocalization) == "function" then
        previousApplyPrimaryLocalization(self, ...)
    end

    local professions = self.frame and self.frame.pages and self.frame.pages.Professions
    if professions and professions.goalHint then
        local current = professions.goalHint:GetText()
        if current ~= FC:GetText("CRAFTING_GOAL_UPDATE_FAILED") then
            setCraftingGoalHint(professions, "CRAFTING_GOAL_HINT", Theme.colors.muted)
        end
    end
end
