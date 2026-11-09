local _, FC = ...

local AccountRecipes = {}
FC.AccountRecipes = AccountRecipes

local function countTrue(tbl)
    local count = 0
    for _, value in pairs(tbl or {}) do
        if value then count = count + 1 end
    end
    return count
end

local function currentCharacterKey()
    return FC.GetCharacterKey and FC:GetCharacterKey() or nil
end

function AccountRecipes:GetProfessionSummaries()
    local summaries = {}
    local byKey = {}
    local currentKey = currentCharacterKey()

    for recipeID, recipe in pairs(FC.DB and FC.DB.account and FC.DB.account.recipes or {}) do
        local professionID = recipe.professionID or 0
        local professionName = FC:GetProfessionDisplayName(professionID, recipe.professionName or "Unknown")
        local key = tostring(professionID ~= 0 and professionID or professionName)
        local summary = byKey[key]
        if not summary then
            summary = {
                professionID = professionID,
                professionName = professionName,
                totalSeen = 0,
                learnedSomewhere = 0,
                currentSeen = 0,
                currentLearned = 0,
                crossCharacterOpportunities = 0,
            }
            byKey[key] = summary
            summaries[#summaries + 1] = summary
        end

        summary.totalSeen = summary.totalSeen + 1
        local learnedCount = countTrue(recipe.learnedBy)
        if learnedCount > 0 then summary.learnedSomewhere = summary.learnedSomewhere + 1 end

        if currentKey and recipe.seenBy and recipe.seenBy[currentKey] then
            summary.currentSeen = summary.currentSeen + 1
            if recipe.learnedBy and recipe.learnedBy[currentKey] then
                summary.currentLearned = summary.currentLearned + 1
            elseif learnedCount > 0 then
                summary.crossCharacterOpportunities = summary.crossCharacterOpportunities + 1
            end
        end
    end

    table.sort(summaries, function(a, b)
        if a.totalSeen == b.totalSeen then return tostring(a.professionName) < tostring(b.professionName) end
        return a.totalSeen > b.totalSeen
    end)
    return summaries
end

function AccountRecipes:GetCrossCharacterOpportunities(limit)
    local currentKey = currentCharacterKey()
    local result = {}
    if not currentKey then return result end

    for recipeID, recipe in pairs(FC.DB and FC.DB.account and FC.DB.account.recipes or {}) do
        local currentSaw = recipe.seenBy and recipe.seenBy[currentKey]
        local currentKnows = recipe.learnedBy and recipe.learnedBy[currentKey]
        if currentSaw and not currentKnows then
            local owners = {}
            for characterKey, learned in pairs(recipe.learnedBy or {}) do
                if learned and characterKey ~= currentKey then owners[#owners + 1] = characterKey end
            end
            if #owners > 0 then
                table.sort(owners)
                result[#result + 1] = {
                    recipeID = tonumber(recipeID) or recipeID,
                    name = recipe.name or ("Recipe " .. tostring(recipeID)),
                    professionID = recipe.professionID,
                    professionName = FC:GetProfessionDisplayName(recipe.professionID, recipe.professionName or "Unknown"),
                    learnedBy = owners,
                    sourceType = recipe.sourceType,
                    categoryID = recipe.categoryID,
                    lastSeen = recipe.lastSeen,
                }
            end
        end
    end

    table.sort(result, function(a, b)
        if a.professionName == b.professionName then return tostring(a.name) < tostring(b.name) end
        return tostring(a.professionName) < tostring(b.professionName)
    end)

    limit = tonumber(limit) or #result
    while #result > limit do table.remove(result) end
    return result
end

function AccountRecipes:GetRecipeOwners(recipeID)
    local recipe = FC.DB and FC.DB.account and FC.DB.account.recipes and FC.DB.account.recipes[tonumber(recipeID) or recipeID]
    if not recipe then return nil end
    local owners = {}
    for characterKey, learned in pairs(recipe.learnedBy or {}) do
        if learned then owners[#owners + 1] = characterKey end
    end
    table.sort(owners)
    return {
        recipeID = tonumber(recipeID) or recipeID,
        name = recipe.name,
        professionID = recipe.professionID,
        professionName = FC:GetProfessionDisplayName(recipe.professionID, recipe.professionName),
        learnedBy = owners,
        seenBy = recipe.seenBy,
        lastSeen = recipe.lastSeen,
    }
end

function AccountRecipes:GetAccountSummary()
    local total = 0
    local learned = 0
    local recipes = FC.DB and FC.DB.account and FC.DB.account.recipes or {}
    for _, recipe in pairs(recipes) do
        total = total + 1
        if countTrue(recipe.learnedBy) > 0 then learned = learned + 1 end
    end
    return {
        totalSeen = total,
        learnedSomewhere = learned,
        professionCount = #self:GetProfessionSummaries(),
        crossCharacterOpportunities = #self:GetCrossCharacterOpportunities(),
    }
end

function AccountRecipes:Refresh()
    self.lastRefresh = time and time() or 0
end

function AccountRecipes:OnEvent(event)
    if event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" or event == "NEW_RECIPE_LEARNED" then
        self:Refresh()
        if FC.UI and FC.UI.RefreshAccountRecipesView then FC.UI:RefreshAccountRecipesView() end
    end
end

FC:RegisterModule("AccountRecipes", AccountRecipes)
