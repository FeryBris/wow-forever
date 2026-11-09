local _, FC = ...

local CraftingGoals = {}
FC.CraftingGoals = CraftingGoals

local function getGoalTable()
    if not FC.DB or not FC.DB.account then return nil end
    FC.DB.account.craftingGoals = FC.DB.account.craftingGoals or {}
    return FC.DB.account.craftingGoals
end

local function getAccountItemCount(itemID)
    local item = FC.DB and FC.DB.account and FC.DB.account.items and FC.DB.account.items[itemID]
    return item and tonumber(item.total) or 0
end

local function normalizeQuantity(value)
    return math.max(1, math.floor(tonumber(value) or 1))
end

local function cachedRecipe(recipeID)
    return FC.DB and FC.DB.account and FC.DB.account.recipes and FC.DB.account.recipes[tonumber(recipeID)] or nil
end

local function applyKnownRecipeMetadata(goal, recipeID, fallback)
    local recipe = cachedRecipe(recipeID)
    fallback = type(fallback) == "table" and fallback or {}
    if recipe then
        goal.name = recipe.name or goal.name or fallback.name
        goal.professionID = recipe.professionID or goal.professionID or fallback.professionID
        goal.professionName = recipe.professionName or goal.professionName or fallback.professionName
    else
        goal.name = goal.name or fallback.name
        goal.professionID = goal.professionID or fallback.professionID
        goal.professionName = goal.professionName or fallback.professionName
    end
    goal.name = goal.name or ("Recipe " .. tostring(recipeID))
end

local function applySchematic(goal, recipeID)
    local schematic = FC.API:GetRecipeSchematicSnapshot(recipeID)
    if not schematic then return false end
    goal.reagents = schematic.reagents or {}
    goal.outputItemID = schematic.outputItemID
    goal.icon = schematic.icon
    if schematic.name and not goal.name then goal.name = schematic.name end
    return true
end

function CraftingGoals:AddGoal(recipeID, quantity)
    recipeID = tonumber(recipeID)
    quantity = normalizeQuantity(quantity)
    if not recipeID then return false, FC:GetText("CRAFTING_ERROR_RECIPE_ID") end

    local recipe = cachedRecipe(recipeID)
    if not recipe then return false, FC:GetText("CRAFTING_ERROR_RECIPE_NOT_CACHED") end

    local goals = getGoalTable()
    if not goals then return false, FC:GetText("FORM_ERROR_DATABASE_NOT_READY") end

    local now = time and time() or 0
    local goal = {
        recipeID = recipeID,
        quantity = quantity,
        createdAt = now,
        updatedAt = now,
        reagents = {},
    }
    applyKnownRecipeMetadata(goal, recipeID)
    applySchematic(goal, recipeID)

    goals[recipeID] = goal
    self:Refresh()
    return true, goal
end

-- Planning-transfer recovery path. Unlike AddGoal, this deliberately permits a
-- recipe that has not yet been scanned on the target installation. The goal is
-- retained and enriched automatically the next time recipe/schematic data is available.
function CraftingGoals:ImportGoal(recipeID, quantity, fallback)
    recipeID = tonumber(recipeID)
    if not recipeID then return false, FC:GetText("CRAFTING_ERROR_RECIPE_ID") end
    local goals = getGoalTable()
    if not goals then return false, FC:GetText("FORM_ERROR_DATABASE_NOT_READY") end

    local now = time and time() or 0
    local goal = goals[recipeID] or {
        recipeID = recipeID,
        createdAt = now,
        reagents = {},
    }
    goal.quantity = normalizeQuantity(quantity)
    goal.updatedAt = now
    goal.reagents = goal.reagents or {}
    applyKnownRecipeMetadata(goal, recipeID, fallback)
    applySchematic(goal, recipeID)
    goals[recipeID] = goal
    self:Refresh()
    return true, goal
end

function CraftingGoals:RemoveGoal(recipeID)
    recipeID = tonumber(recipeID)
    local goals = getGoalTable()
    if not recipeID or not goals or not goals[recipeID] then return false end
    goals[recipeID] = nil
    FC.Suggestions:ClearSource("CraftingGoals")
    self:Refresh()
    return true
end

function CraftingGoals:GetGoals()
    local result = {}
    for _, goal in pairs(getGoalTable() or {}) do result[#result + 1] = goal end
    table.sort(result, function(a, b) return tostring(a.name or a.recipeID) < tostring(b.name or b.recipeID) end)
    return result
end

function CraftingGoals:GetProgress(goal)
    local progress = { ready = true, knownReagents = 0, missingKinds = 0, reagents = {} }

    for _, reagent in ipairs(goal and goal.reagents or {}) do
        local quantityRequired = tonumber(reagent.quantityRequired) or 0
        local needed = quantityRequired * normalizeQuantity(goal.quantity)
        local available = reagent.itemID and getAccountItemCount(reagent.itemID) or 0
        local missing = math.max(0, needed - available)
        local row = {
            itemID = reagent.itemID,
            name = reagent.name,
            icon = reagent.icon,
            needed = needed,
            available = available,
            missing = missing,
            ambiguous = reagent.ambiguous,
            alternatives = reagent.alternatives,
        }
        progress.reagents[#progress.reagents + 1] = row

        if reagent.itemID then
            progress.knownReagents = progress.knownReagents + 1
            if missing > 0 then
                progress.ready = false
                progress.missingKinds = progress.missingKinds + 1
            end
        elseif reagent.ambiguous then
            progress.ready = false
        end
    end

    if #progress.reagents == 0 then progress.ready = false end
    return progress
end

function CraftingGoals:Refresh()
    FC.Suggestions:ClearSource("CraftingGoals")

    for _, goal in ipairs(self:GetGoals()) do
        goal.quantity = normalizeQuantity(goal.quantity)
        local progress = self:GetProgress(goal)
        goal.updatedAt = time and time() or 0
        goal.ready = progress.ready
        goal.missingKinds = progress.missingKinds

        if progress.ready then
            FC.Suggestions:Add({
                id = "crafting_goal_ready_" .. tostring(goal.recipeID),
                source = "CraftingGoals",
                category = "Profession",
                priority = 62,
                title = FC:GetText("SUGG_CRAFT_READY_TITLE", goal.name),
                description = FC:GetText("SUGG_CRAFT_READY_DESC", goal.quantity),
            })
        elseif progress.knownReagents > 0 then
            FC.Suggestions:Add({
                id = "crafting_goal_missing_" .. tostring(goal.recipeID),
                source = "CraftingGoals",
                category = "Profession",
                priority = 58,
                title = FC:GetText("SUGG_CRAFT_MISSING_TITLE", goal.name),
                description = FC:GetText("SUGG_CRAFT_MISSING_DESC", progress.missingKinds),
            })
        end
    end
end

function CraftingGoals:PrintGoals()
    local goals = self:GetGoals()
    if #goals == 0 then FC:Print("No crafting goals pinned."); return end

    FC:Print(string.format("Crafting goals: %d", #goals))
    for _, goal in ipairs(goals) do
        local progress = self:GetProgress(goal)
        FC:Print(string.format("%s (recipe %d) x%d%s",
            tostring(goal.name), tonumber(goal.recipeID) or 0, normalizeQuantity(goal.quantity),
            progress.ready and " — READY" or ""))

        for _, reagent in ipairs(progress.reagents) do
            if reagent.itemID then
                FC:Print(string.format("  %s: %d / %d%s",
                    tostring(reagent.name or ("Item " .. reagent.itemID)), reagent.available, reagent.needed,
                    reagent.missing > 0 and string.format(" (%d missing)", reagent.missing) or ""))
            elseif reagent.ambiguous then
                FC:Print("  Choice reagent: select a material in the profession window to resolve it.")
            end
        end
    end
end

function CraftingGoals:RefreshRecipeData(recipeID)
    recipeID = tonumber(recipeID)
    local goals = getGoalTable()
    local goal = goals and goals[recipeID]
    if not goal then return end

    applyKnownRecipeMetadata(goal, recipeID)
    applySchematic(goal, recipeID)
    goal.updatedAt = time and time() or 0
end

function CraftingGoals:RefreshAllRecipeData()
    for _, goal in ipairs(self:GetGoals()) do self:RefreshRecipeData(goal.recipeID) end
    self:Refresh()
end

function CraftingGoals:OnEvent(event)
    if event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" or event == "NEW_RECIPE_LEARNED" then
        self:RefreshAllRecipeData()
    elseif event == "BAG_UPDATE_DELAYED" or event == "PLAYER_LOGIN" or event == "PLAYERBANKSLOTS_CHANGED" or event == "BANK_TABS_CHANGED" then
        self:Refresh()
    end
end

FC:RegisterModule("CraftingGoals", CraftingGoals)
