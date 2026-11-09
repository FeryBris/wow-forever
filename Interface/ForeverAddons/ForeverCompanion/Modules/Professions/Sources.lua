local _, FC = ...

local Sources = {
    providers = {},
}
FC.RecipeSources = Sources

local function getStore()
    if not FC.DB or not FC.DB.account then return nil end
    FC.DB.account.recipeSources = FC.DB.account.recipeSources or {}
    return FC.DB.account.recipeSources
end

local function safeValue(value)
    if value == nil then return nil end
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if ok and secret then return nil end
    end
    return value
end

local function safeText(value)
    value = safeValue(value)
    if value == nil then return nil end
    local kind = type(value)
    if kind ~= "string" and kind ~= "number" and kind ~= "boolean" then return nil end
    return tostring(value)
end

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function copyValue(value, depth)
    depth = depth or 0
    value = safeValue(value)
    if value == nil then return nil end
    if type(value) ~= "table" then
        local kind = type(value)
        if kind == "string" or kind == "number" or kind == "boolean" then return value end
        return nil
    end
    if depth >= 5 then return nil end

    local result = {}
    for key, child in pairs(value) do
        local copiedKey = copyValue(key, depth + 1)
        local copiedChild = copyValue(child, depth + 1)
        if copiedKey ~= nil and copiedChild ~= nil then result[copiedKey] = copiedChild end
    end
    return result
end

local function tableValueByID(tbl, id)
    if type(tbl) ~= "table" then return nil end
    local numeric = tonumber(id)
    return (numeric and tbl[numeric]) or tbl[tostring(id)] or tbl[id]
end

local function recipeCache(recipeID)
    return tableValueByID(FC.DB and FC.DB.account and FC.DB.account.recipes, recipeID)
end

function Sources:SetUserNote(recipeID, sourceType, sourceName, location, notes)
    recipeID = tonumber(recipeID)
    if not recipeID then return false, FC:GetText("RECIPE_SOURCE_ERROR_RECIPE_ID") end
    local store = getStore()
    if not store then return false, FC:GetText("FORM_ERROR_DATABASE_NOT_READY") end

    sourceType = trim(sourceType)
    sourceName = trim(sourceName)
    location = trim(location)
    notes = trim(notes)
    if sourceType == "" and sourceName == "" and location == "" and notes == "" then
        store[recipeID] = nil
        store[tostring(recipeID)] = nil
        return true
    end

    store[tostring(recipeID)] = nil
    store[recipeID] = {
        recipeID = recipeID,
        sourceType = sourceType ~= "" and sourceType or "Note",
        sourceName = sourceName ~= "" and sourceName or nil,
        location = location ~= "" and location or nil,
        notes = notes ~= "" and notes or nil,
        updatedAt = time and time() or 0,
        source = "User",
    }
    return true, store[recipeID]
end

function Sources:RemoveUserNote(recipeID)
    local store = getStore()
    recipeID = tonumber(recipeID)
    if not store or not recipeID then return false end
    local existed = store[recipeID] ~= nil or store[tostring(recipeID)] ~= nil
    store[recipeID] = nil
    store[tostring(recipeID)] = nil
    return existed
end

function Sources:RegisterProvider(id, callback)
    id = trim(id)
    if id == "" then return false, "Provider ID is required." end
    if type(callback) ~= "function" then return false, "Recipe source provider must be a function." end
    if self.providers[id] then return false, "Recipe source provider already registered: " .. id end
    self.providers[id] = callback
    return true
end

function Sources:UnregisterProvider(id)
    id = tostring(id or "")
    if not self.providers[id] then return false end
    self.providers[id] = nil
    return true
end

function Sources:GetProviderCount()
    local count = 0
    for _ in pairs(self.providers) do count = count + 1 end
    return count
end

function Sources:BuildContext(recipeID)
    local recipe = recipeCache(recipeID)
    return {
        addonVersion = FC.version,
        recipeID = tonumber(recipeID) or recipeID,
        recipe = copyValue(recipe),
        character = copyValue(FC:GetCurrentCharacter()),
        discoveryMode = FC.DB and FC.DB.settings and FC.DB.settings.discoveryMode or "BALANCED",
    }
end

function Sources:GetProviderSources(recipeID)
    recipeID = tonumber(recipeID) or recipeID
    local result = {}
    local context = self:BuildContext(recipeID)

    for providerID, callback in pairs(self.providers) do
        local ok, provided = pcall(callback, recipeID, copyValue(context))
        if ok and type(provided) == "table" then
            local list = provided
            if safeValue(provided.sourceType) ~= nil or safeValue(provided.sourceName) ~= nil
                or safeValue(provided.location) ~= nil or safeValue(provided.notes) ~= nil
            then
                list = { provided }
            end
            for index, entry in ipairs(list) do
                if type(entry) == "table" then
                    local sourceType = safeText(entry.sourceType) or "Provider"
                    local sourceName = safeText(entry.sourceName)
                    local location = safeText(entry.location)
                    local notes = safeText(entry.notes)
                    local npcID = tonumber(safeValue(entry.npcID))
                    local itemID = tonumber(safeValue(entry.itemID))
                    local mapID = tonumber(safeValue(entry.mapID))
                    local x = tonumber(safeValue(entry.x))
                    local y = tonumber(safeValue(entry.y))
                    local providerEntryID = safeText(entry.id) or tostring(index)

                    if sourceName or location or notes or sourceType ~= "Provider" or npcID or itemID or mapID then
                        result[#result + 1] = {
                            id = "provider:" .. providerID .. ":" .. providerEntryID,
                            recipeID = recipeID,
                            sourceType = sourceType,
                            sourceName = sourceName,
                            location = location,
                            notes = notes,
                            npcID = npcID,
                            itemID = itemID,
                            mapID = mapID,
                            x = x,
                            y = y,
                            source = "Provider:" .. providerID,
                            metadata = copyValue(entry.metadata),
                        }
                    end
                end
            end
        elseif not ok then
            FC.Logger:Warn("PROFESSION", "Recipe source provider %s failed for %s: %s", tostring(providerID), tostring(recipeID), tostring(provided))
        end
    end
    return result
end

function Sources:GetSources(recipeID)
    recipeID = tonumber(recipeID)
    if not recipeID then return {} end
    local result = {}
    local store = getStore()
    local user = tableValueByID(store, recipeID)
    if user then result[#result + 1] = copyValue(user) end
    for _, entry in ipairs(self:GetProviderSources(recipeID)) do result[#result + 1] = entry end
    table.sort(result, function(a, b)
        if tostring(a.sourceType) == tostring(b.sourceType) then return tostring(a.sourceName or a.location or a.source) < tostring(b.sourceName or b.location or b.source) end
        return tostring(a.sourceType) < tostring(b.sourceType)
    end)
    return result
end

function Sources:GetKnownRecipeRows(query, limit)
    query = string.lower(trim(query))
    local rows = {}
    for recipeID, recipe in pairs(FC.DB and FC.DB.account and FC.DB.account.recipes or {}) do
        local name = tostring(recipe.name or ("Recipe " .. tostring(recipeID)))
        if query == "" or string.find(string.lower(name), query, 1, true) or tostring(recipeID) == query then
            local sources = self:GetSources(recipeID)
            rows[#rows + 1] = {
                recipeID = tonumber(recipeID) or recipeID,
                name = name,
                professionName = FC:GetProfessionDisplayName(recipe.professionID, recipe.professionName),
                learnedBy = copyValue(recipe.learnedBy),
                sources = sources,
            }
        end
    end
    table.sort(rows, function(a, b) return tostring(a.name) < tostring(b.name) end)
    limit = tonumber(limit) or #rows
    while #rows > limit do table.remove(rows) end
    return rows
end

function Sources:Refresh()
    self.lastRefresh = time and time() or 0
    if FC.UI and FC.UI.RefreshRecipeSourcesView then FC.UI:RefreshRecipeSourcesView() end
end

function Sources:OnInitialize()
    getStore()
end

FC:RegisterModule("RecipeSources", Sources)
