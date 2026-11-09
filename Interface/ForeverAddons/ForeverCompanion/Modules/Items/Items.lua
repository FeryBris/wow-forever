local _, FC = ...

local Items = {}
FC.Items = Items

local function containsValue(values, target)
    for _, value in ipairs(values or {}) do
        if tonumber(value) == tonumber(target) then return true end
    end
    return false
end

function Items:GetBase(itemID)
    itemID = tonumber(itemID)
    if not itemID then return nil end
    self.baseCache = self.baseCache or {}
    if self.baseCache[itemID] then return self.baseCache[itemID] end
    local info = FC.API:GetItemIntelligenceBase(itemID)
    if info then self.baseCache[itemID] = info end
    return info
end

function Items:GetCraftingRelevance(itemID)
    itemID = tonumber(itemID)
    local result = { usedByGoals = {}, outputOfGoals = {} }
    for _, goal in pairs(FC.DB and FC.DB.account and FC.DB.account.craftingGoals or {}) do
        if tonumber(goal.outputItemID) == itemID then result.outputOfGoals[#result.outputOfGoals + 1] = goal end
        for _, reagent in ipairs(goal.reagents or {}) do
            if tonumber(reagent.itemID) == itemID or containsValue(reagent.alternatives, itemID) then
                result.usedByGoals[#result.usedByGoals + 1] = goal
                break
            end
        end
    end
    return result
end

function Items:GetSetPeers(setID, exceptItemID)
    local result = {}
    if not setID then return result end
    for cachedItemID, aggregate in pairs(FC.DB and FC.DB.account and FC.DB.account.items or {}) do
        cachedItemID = tonumber(cachedItemID)
        if cachedItemID and cachedItemID ~= tonumber(exceptItemID) then
            local info = self:GetBase(cachedItemID)
            if info and tonumber(info.setID) == tonumber(setID) then
                result[#result + 1] = {
                    itemID = cachedItemID,
                    name = info.name,
                    link = info.link,
                    total = tonumber(aggregate.total) or 0,
                }
            end
        end
    end
    table.sort(result, function(a, b) return tostring(a.name or a.itemID) < tostring(b.name or b.itemID) end)
    return result
end

function Items:Analyze(itemID)
    itemID = tonumber(itemID)
    if not itemID then return nil, FC:GetText("ITEM_ERROR_INVALID_ID") end
    local base = self:GetBase(itemID)
    if not base then return nil, FC:GetText("ITEM_ERROR_NOT_CACHED") end

    local aggregate = FC.DB and FC.DB.account and FC.DB.account.items and FC.DB.account.items[itemID]
    local relevance = self:GetCraftingRelevance(itemID)
    local result = {
        base = base,
        totalOwned = aggregate and tonumber(aggregate.total) or 0,
        owners = aggregate and aggregate.characters or {},
        crafting = relevance,
        setPeers = self:GetSetPeers(base.setID, itemID),
    }

    result.cachedSetPieceTypesOwned = (base.setID and result.totalOwned > 0) and 1 or 0
    if base.setID then result.cachedSetPieceTypesOwned = result.cachedSetPieceTypesOwned + #result.setPeers end
    return result
end

function Items:FindAndAnalyze(query)
    local itemID = tonumber(query)
    if not itemID and FC.Inventory then
        local matches = FC.Inventory:Find(query, 1)
        itemID = matches[1] and matches[1].itemID or nil
    end
    if not itemID then return nil, FC:GetText("ITEM_ERROR_NO_MATCH") end
    return self:Analyze(itemID)
end

function Items:Refresh()
    self.baseCache = {}
end

function Items:OnEvent(event)
    if event == "BAG_UPDATE_DELAYED" or event == "PLAYERBANKSLOTS_CHANGED" or event == "BANK_TABS_CHANGED" then
        self.baseCache = {}
    end
end

FC:RegisterModule("Items", Items)
