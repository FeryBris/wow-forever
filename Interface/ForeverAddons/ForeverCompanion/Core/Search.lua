local _, FC = ...

local Search = {}
FC.Search = Search

local KIND_KEYS = {
    Character = "SEARCH_KIND_CHARACTER",
    Item = "SEARCH_KIND_ITEM",
    Recipe = "SEARCH_KIND_RECIPE",
    Goal = "SEARCH_KIND_GOAL",
    Legacy = "SEARCH_KIND_LEGACY",
    Route = "SEARCH_KIND_ROUTE",
    Checklist = "SEARCH_KIND_CHECKLIST",
}

local function moduleEnabled(name)
    return type(FC.IsModuleEnabled) ~= "function" or FC:IsModuleEnabled(name)
end

local function normalize(value)
    return string.lower(tostring(value or ""))
end

local function contains(value, query)
    if query == "" then return false end
    return string.find(normalize(value), query, 1, true) ~= nil
end

local function add(results, entry)
    if type(entry) ~= "table" or not entry.title then return end
    if entry.kind and not entry.kindLabel then
        local key = KIND_KEYS[entry.kind]
        entry.kindLabel = key and FC:GetText(key) or tostring(entry.kind)
    end
    results[#results + 1] = entry
end

local function scoreText(title, subtitle, query)
    local titleText = normalize(title)
    if titleText == query then return 100 end
    if string.sub(titleText, 1, #query) == query then return 85 end
    if string.find(titleText, query, 1, true) then return 70 end
    if contains(subtitle, query) then return 45 end
    return 0
end

local function recipeSourceSearchText(recipeID)
    if not moduleEnabled("RecipeSources") then return "", 0 end
    if not FC.RecipeSources or type(FC.RecipeSources.GetSources) ~= "function" then return "", 0 end
    local parts = {}
    local sources = FC.RecipeSources:GetSources(recipeID)
    for _, source in ipairs(sources) do
        parts[#parts + 1] = tostring(source.sourceType or "")
        parts[#parts + 1] = tostring(source.sourceName or "")
        parts[#parts + 1] = tostring(source.location or "")
        parts[#parts + 1] = tostring(source.notes or "")
    end
    return table.concat(parts, " "), #sources
end

function Search:Query(query, limit)
    query = normalize(query):gsub("^%s+", ""):gsub("%s+$", "")
    local results = {}
    if query == "" then return results end

    local account = FC.DB and FC.DB.account or {}

    for key, character in pairs(account.characters or {}) do
        local className = FC:GetClassDisplayName(character)
        local subtitle = FC:GetText("SEARCH_CHARACTER_SUBTITLE", tonumber(character.level) or 0, className, tostring(character.realm or ""))
        local rawNames = tostring(character.className or "") .. " " .. tostring(character.classFile or "")
        local score = scoreText(character.name or key, subtitle .. " " .. key .. " " .. rawNames, query)
        if score > 0 then
            add(results, { kind = "Character", id = key, title = character.name or key, subtitle = subtitle, score = score })
        end
    end

    if moduleEnabled("Items") then
        for itemID, item in pairs(account.items or {}) do
            local title = item.name or ("Item " .. tostring(itemID))
            local subtitle = FC:GetText("SEARCH_ITEM_SUBTITLE", tostring(itemID), tonumber(item.total) or 0)
            local score = tonumber(query) == tonumber(itemID) and 100 or scoreText(title, subtitle, query)
            if score > 0 then
                add(results, { kind = "Item", id = tonumber(itemID) or itemID, title = title, subtitle = subtitle, score = score })
            end
        end
    end

    if moduleEnabled("AccountRecipes") or moduleEnabled("RecipeSources") then
        for recipeID, recipe in pairs(account.recipes or {}) do
            local title = recipe.name or (FC:GetText("SEARCH_RECIPE_FALLBACK") .. " " .. tostring(recipeID))
            local owners = 0
            for _, learned in pairs(recipe.learnedBy or {}) do if learned then owners = owners + 1 end end
            local sourceText, sourceCount = recipeSourceSearchText(recipeID)
            local sourceSuffix = sourceCount > 0 and FC:GetText("SEARCH_RECIPE_SOURCE_SUFFIX", sourceCount) or ""
            local professionName = FC:GetProfessionDisplayName(recipe.professionID, recipe.professionName or FC:GetText("SEARCH_RECIPE_FALLBACK"))
            local subtitle = FC:GetText("SEARCH_RECIPE_SUBTITLE", professionName, owners, sourceSuffix)
            local score = tonumber(query) == tonumber(recipeID) and 100 or scoreText(title, subtitle .. " " .. tostring(recipe.professionName or ""), query)
            if score == 0 and contains(sourceText, query) then score = 55 end
            if score > 0 then
                add(results, { kind = "Recipe", id = tonumber(recipeID) or recipeID, title = title, subtitle = subtitle, score = score })
            end
        end
    end

    if moduleEnabled("Goals") and FC.Goals and type(FC.Goals.GetGoals) == "function" then
        for _, goal in ipairs(FC.Goals:GetGoals(true)) do
            local title = type(FC.Goals.GetDisplayTitle) == "function" and FC.Goals:GetDisplayTitle(goal) or goal.title
            local description = type(FC.Goals.GetDisplayDescription) == "function" and FC.Goals:GetDisplayDescription(goal) or goal.description
            local completeSuffix = goal.completed and FC:GetText("SEARCH_GOAL_COMPLETE_SUFFIX") or ""
            local subtitle = FC:GetText("SEARCH_GOAL_SUBTITLE", tostring(goal.category or FC:GetText("SEARCH_GOAL_FALLBACK")), tonumber(goal.priority) or 0, completeSuffix)
            local score = scoreText(title, (description or "") .. " " .. subtitle, query)
            if score > 0 then
                add(results, { kind = "Goal", id = goal.id, title = title, subtitle = subtitle, score = score })
            end
        end
    end

    if moduleEnabled("Legacy") then
        local legacy = account.legacy and account.legacy.snapshot
        for _, challenge in ipairs(legacy and legacy.challenges or {}) do
            local percent = math.floor(((tonumber(challenge.progress) or 0) * 100) + 0.5)
            local subtitle = FC:GetText("SEARCH_LEGACY_SUBTITLE", challenge.completed and 100 or percent)
            local score = scoreText(challenge.name, challenge.description or subtitle, query)
            if score > 0 then
                add(results, { kind = "Legacy", id = challenge.id, title = challenge.name, subtitle = subtitle, score = score })
            end
        end
    end

    if moduleEnabled("TravelRoutes") and FC.TravelRoutes and type(FC.TravelRoutes.GetAllRoutes) == "function" then
        for _, route in ipairs(FC.TravelRoutes:GetAllRoutes(true)) do
            local subtitle = FC:GetText("SEARCH_ROUTE_SUBTITLE", tostring(route.routeType or FC:GetText("SEARCH_ROUTE_FALLBACK")), tostring(route.origin or "?"), tostring(route.destination or "?"))
            local score = scoreText(route.name, subtitle .. " " .. tostring(route.notes or ""), query)
            if score > 0 then
                add(results, { kind = "Route", id = route.id, title = route.name, subtitle = subtitle, score = score })
            end
        end
    end

    if moduleEnabled("PreparationChecklist") and FC.PreparationChecklist and type(FC.PreparationChecklist.GetItems) == "function" then
        for _, item in ipairs(FC.PreparationChecklist:GetItems()) do
            local label = type(FC.PreparationChecklist.GetDisplayLabel) == "function"
                and FC.PreparationChecklist:GetDisplayLabel(item) or tostring(item.label or "")
            local subtitle = FC:GetText(item.completed and "SEARCH_CHECKLIST_COMPLETE" or "SEARCH_CHECKLIST_OPEN")
            local score = scoreText(label, subtitle, query)
            if score > 0 then
                add(results, { kind = "Checklist", id = item.id, title = label, subtitle = subtitle, score = score })
            end
        end
    end

    table.sort(results, function(a, b)
        if a.score == b.score then
            if a.kind == b.kind then return tostring(a.title) < tostring(b.title) end
            return tostring(a.kind) < tostring(b.kind)
        end
        return a.score > b.score
    end)

    limit = tonumber(limit) or 20
    while #results > limit do table.remove(results) end
    return results
end
