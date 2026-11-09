local _, FC = ...

local Planner = {}
FC.ProfessionPlanner = Planner

local function findProfession(skillLineID)
    local character = FC:GetCurrentCharacter()
    for _, profession in ipairs(character and character.professions or {}) do
        if tonumber(profession.skillLineID) == tonumber(skillLineID) then return profession end
    end
    return nil
end

local function recipeStatsFor(profession)
    local character = FC:GetCurrentCharacter()
    if not character or not profession then return nil end
    if profession.skillLineID and character.recipeStats and character.recipeStats[profession.skillLineID] then
        return character.recipeStats[profession.skillLineID]
    end
    for _, stats in pairs(character.recipeStats or {}) do
        if stats.professionName == profession.name then return stats end
    end
    return nil
end

local function craftingGoalsFor(profession)
    local result = {}
    if FC.IsModuleEnabled and not FC:IsModuleEnabled("CraftingGoals") then return result end
    for _, goal in pairs(FC.DB and FC.DB.account and FC.DB.account.craftingGoals or {}) do
        if tonumber(goal.professionID) == tonumber(profession.skillLineID) or goal.professionName == profession.name then
            result[#result + 1] = goal
        end
    end
    table.sort(result, function(a, b) return tostring(a.name) < tostring(b.name) end)
    return result
end

local function campsAvailable()
    if FC.IsModuleEnabled and not FC:IsModuleEnabled("Camps") then return false end
    return FC.API and FC.API.capabilities and FC.API.capabilities.camps == true
end

function Planner:BuildPlan(skillLineID, targetSkill)
    local profession = findProfession(skillLineID)
    if not profession then return nil, FC:GetText("PROF_PLAN_NOT_ON_CHARACTER") end

    local displayName = FC:GetProfessionDisplayName(profession)
    local current = math.max(0, math.floor(tonumber(profession.skill) or 0))
    local maxSkill = math.max(current, math.floor(tonumber(profession.maxSkill) or current))
    targetSkill = math.floor(tonumber(targetSkill) or maxSkill)
    targetSkill = math.max(current, math.min(targetSkill, maxSkill))
    local plan = {
        skillLineID = profession.skillLineID,
        name = displayName,
        current = current,
        maxSkill = maxSkill,
        target = targetSkill,
        remaining = math.max(0, targetSkill - current),
        stages = {},
        recipeStats = recipeStatsFor(profession),
        craftingGoals = craftingGoalsFor(profession),
        campTiers = {},
    }

    local campDefinition = campsAvailable() and FC.CampData and FC.CampData.professions[profession.skillLineID] or nil
    if campDefinition then
        for index, tier in ipairs(campDefinition.tiers or {}) do
            plan.campTiers[#plan.campTiers + 1] = {
                tier = index,
                skill = tier.skill,
                feature = tier.name,
                reached = current >= (tonumber(tier.skill) or math.huge),
            }
            if current < tier.skill and tier.skill <= targetSkill then
                plan.stages[#plan.stages + 1] = {
                    skill = tier.skill,
                    title = FC:GetText("PROF_PLAN_CAMP_TIER_TITLE", index),
                    description = FC:GetText("PROF_PLAN_CAMP_TIER_DESC", tostring(tier.name), tonumber(tier.skill) or 0),
                }
            end
        end
    end

    if plan.recipeStats then
        plan.stages[#plan.stages + 1] = {
            skill = current,
            title = FC:GetText("PROF_PLAN_RECIPE_CACHE_TITLE"),
            description = FC:GetText("PROF_PLAN_RECIPE_CACHE_DESC",
                tonumber(plan.recipeStats.learned) or 0, tonumber(plan.recipeStats.total) or 0, tonumber(plan.recipeStats.unlearned) or 0),
        }
    end

    for _, goal in ipairs(plan.craftingGoals) do
        local progress = FC.CraftingGoals and FC.CraftingGoals:GetProgress(goal) or nil
        plan.stages[#plan.stages + 1] = {
            skill = current,
            title = FC:GetText("PROF_PLAN_CRAFT_GOAL_TITLE", tostring(goal.name)),
            description = progress and (progress.ready and FC:GetText("PROF_PLAN_MATERIALS_READY")
                or FC:GetText("PROF_PLAN_MATERIALS_MISSING", tonumber(progress.missingKinds) or 0))
                or FC:GetText("PROF_PLAN_TRACKED_GOAL"),
        }
    end

    plan.stages[#plan.stages + 1] = {
        skill = targetSkill,
        title = FC:GetText(targetSkill == maxSkill and "PROF_PLAN_CAP_TITLE" or "PROF_PLAN_TARGET_TITLE"),
        description = FC:GetText("PROF_PLAN_TARGET_DESC", targetSkill, maxSkill, displayName),
    }

    table.sort(plan.stages, function(a, b)
        if (a.skill or 0) == (b.skill or 0) then return tostring(a.title) < tostring(b.title) end
        return (a.skill or 0) < (b.skill or 0)
    end)
    return plan
end

function Planner:GetAvailableProfessions()
    local result = {}
    local character = FC:GetCurrentCharacter()
    for _, profession in ipairs(character and character.professions or {}) do result[#result + 1] = profession end
    table.sort(result, function(a, b)
        return FC:GetProfessionDisplayName(a) < FC:GetProfessionDisplayName(b)
    end)
    return result
end

function Planner:Refresh()
    self.lastRefresh = time and time() or 0
end

function Planner:OnEvent(event)
    if event == "SKILL_LINES_CHANGED" or event == "TRADE_SKILL_LIST_UPDATE" or event == "NEW_RECIPE_LEARNED" then
        self:Refresh()
        if FC.UI and FC.UI.RefreshProfessionPlannerView then FC.UI:RefreshProfessionPlannerView() end
    end
end

FC:RegisterModule("ProfessionPlanner", Planner)
