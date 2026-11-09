local _, FC = ...

local Inventory = {}
FC.Inventory = Inventory

local function normalize(text)
    return string.lower(tostring(text or ""))
end

local function addLocation(owner, location, count, lastSeen)
    owner.locations = owner.locations or {}
    local existing = owner.locations[location] or { count = 0 }
    existing.count = (tonumber(existing.count) or 0) + (tonumber(count) or 0)
    existing.lastSeen = lastSeen or existing.lastSeen
    owner.locations[location] = existing
end

local function addItem(accountItems, itemID, cachedItem, ownerKey, location, lastSeen)
    local count = tonumber(cachedItem and cachedItem.count) or 0
    if count <= 0 then return end

    local aggregate = accountItems[itemID]
    if not aggregate then
        aggregate = {
            itemID = itemID,
            name = cachedItem.name,
            link = cachedItem.link,
            total = 0,
            characters = {},
        }
        accountItems[itemID] = aggregate
    end

    aggregate.name = aggregate.name or cachedItem.name
    aggregate.link = aggregate.link or cachedItem.link
    aggregate.total = aggregate.total + count

    local owner = aggregate.characters[ownerKey] or { count = 0 }
    owner.count = (tonumber(owner.count) or 0) + count
    owner.lastSeen = math.max(tonumber(owner.lastSeen) or 0, tonumber(lastSeen) or 0)
    addLocation(owner, location, count, lastSeen)
    aggregate.characters[ownerKey] = owner
end

function Inventory:RebuildAccountIndex()
    if not FC.DB or not FC.DB.account then return end
    local accountItems = {}

    for characterKey, character in pairs(FC.DB.account.characters or {}) do
        local inventory = character.inventory
        if type(inventory) == "table" then
            for itemID, cachedItem in pairs(inventory.bags or {}) do
                addItem(accountItems, itemID, cachedItem, characterKey, "Bags", inventory.lastSeen)
            end

            local bank = inventory.bank
            for itemID, cachedItem in pairs(bank and bank.items or {}) do
                addItem(accountItems, itemID, cachedItem, characterKey, "Character Bank", bank.lastSeen)
            end
        end
    end

    local storage = FC.DB.account.storage
    local accountBank = storage and storage.accountBank
    for itemID, cachedItem in pairs(accountBank and accountBank.items or {}) do
        addItem(accountItems, itemID, cachedItem, "ACCOUNT", "Account Bank", accountBank.lastSeen)
    end

    FC.DB.account.items = accountItems
end

function Inventory:Scan()
    local character = FC:GetCurrentCharacter()
    if not character then return end

    local snapshot = FC.API:GetBagItemSnapshot()
    if snapshot == nil then
        FC.Logger:Debug("INVENTORY", "Bag scan unavailable; preserving last valid cache")
        return false
    end

    character.inventory = character.inventory or {}
    character.inventory.bags = snapshot
    character.inventory.lastSeen = time and time() or 0

    self:RebuildAccountIndex()

    if FC.CraftingGoals and type(FC.CraftingGoals.Refresh) == "function" then
        FC.CraftingGoals:Refresh()
    end

    FC.Logger:Debug("INVENTORY", "Scanned %d bag item type(s)", self:CountEntries(snapshot))
    return true
end

function Inventory:ScanBank(reason)
    if not self.bankOpen or not FC.API.GetBankStorageSnapshot then return end
    local character = FC:GetCurrentCharacter()
    if not character then return end

    local snapshot = FC.API:GetBankStorageSnapshot()
    if not snapshot then return end

    character.inventory = character.inventory or {}
    if snapshot.character then
        character.inventory.bank = {
            items = snapshot.character.items or {},
            tabIDs = snapshot.character.tabIDs or {},
            lastSeen = snapshot.scannedAt,
        }
    end

    FC.DB.account.storage = FC.DB.account.storage or {}
    if snapshot.account then
        FC.DB.account.storage.accountBank = {
            items = snapshot.account.items or {},
            tabIDs = snapshot.account.tabIDs or {},
            lastSeen = snapshot.scannedAt,
        }
    end

    self:RebuildAccountIndex()
    if FC.CraftingGoals and type(FC.CraftingGoals.Refresh) == "function" then
        FC.CraftingGoals:Refresh()
    end

    FC.Logger:Debug("INVENTORY", "Scanned bank storage (%s): character=%d account=%d",
        tostring(reason or "manual"),
        self:CountEntries(snapshot.character and snapshot.character.items),
        self:CountEntries(snapshot.account and snapshot.account.items))
end

function Inventory:CountEntries(tbl)
    local count = 0
    for _ in pairs(tbl or {}) do count = count + 1 end
    return count
end

function Inventory:Find(query, limit)
    local matches = {}
    local textQuery = normalize(query)
    local numericID = tonumber(query)
    if textQuery == "" then return matches end

    for itemID, item in pairs(FC.DB.account.items or {}) do
        local name = item.name or ""
        local matchesID = numericID and tonumber(itemID) == numericID
        local matchesName = not numericID and string.find(normalize(name), textQuery, 1, true) ~= nil
        if matchesID or matchesName then matches[#matches + 1] = item end
    end

    table.sort(matches, function(a, b)
        if (a.total or 0) == (b.total or 0) then
            return normalize(a.name or a.itemID) < normalize(b.name or b.itemID)
        end
        return (a.total or 0) > (b.total or 0)
    end)

    limit = tonumber(limit) or 10
    while #matches > limit do table.remove(matches) end
    return matches
end

function Inventory:GetFreshnessSummary()
    local now = time and time() or 0
    local result = { characters = 0, staleCharacters = 0, accountBankAge = nil }
    for _, character in pairs(FC.DB and FC.DB.account and FC.DB.account.characters or {}) do
        result.characters = result.characters + 1
        local lastSeen = character.inventory and character.inventory.lastSeen
        if now > 0 and tonumber(lastSeen) and (now - lastSeen) > 86400 then
            result.staleCharacters = result.staleCharacters + 1
        end
    end
    local accountBank = FC.DB and FC.DB.account and FC.DB.account.storage and FC.DB.account.storage.accountBank
    if now > 0 and accountBank and tonumber(accountBank.lastSeen) then
        result.accountBankAge = now - accountBank.lastSeen
    end
    return result
end

function Inventory:PrintSearch(query)
    local matches = self:Find(query, 10)
    if #matches == 0 then
        FC:Print("No cached item matches '" .. tostring(query) .. "'.")
        FC:Print("Only bags/banks previously scanned by Forever Companion are included.")
        return
    end

    FC:Print(string.format("Cached account item search for '%s':", tostring(query)))
    for _, item in ipairs(matches) do
        local label = item.link or item.name or ("Item " .. tostring(item.itemID))
        FC:Print(string.format("%s x%d", label, tonumber(item.total) or 0))

        local owners = {}
        for ownerKey, owner in pairs(item.characters or {}) do
            owners[#owners + 1] = { key = ownerKey, data = owner }
        end
        table.sort(owners, function(a, b)
            if (a.data.count or 0) == (b.data.count or 0) then return a.key < b.key end
            return (a.data.count or 0) > (b.data.count or 0)
        end)

        for _, owner in ipairs(owners) do
            local locations = {}
            for location, data in pairs(owner.data.locations or {}) do
                locations[#locations + 1] = string.format("%s %d", location, tonumber(data.count) or 0)
            end
            table.sort(locations)
            FC:Print(string.format("  %s: %d%s", owner.key, tonumber(owner.data.count) or 0,
                #locations > 0 and (" (" .. table.concat(locations, ", ") .. ")") or ""))
        end
    end
end

function Inventory:Refresh()
    self:Scan()
    if self.bankOpen then self:ScanBank("refresh") end
end

function Inventory:OnEvent(event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "BAG_UPDATE_DELAYED" then
        self:Scan()
    elseif event == "BANKFRAME_OPENED" then
        self.bankOpen = true
        self:ScanBank(event)
    elseif event == "BANKFRAME_CLOSED" then
        self.bankOpen = false
    elseif event == "PLAYERBANKSLOTS_CHANGED" or event == "BANK_TABS_CHANGED" then
        self:ScanBank(event)
    end
end

FC:RegisterModule("Inventory", Inventory)
