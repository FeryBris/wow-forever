local _, FC = ...

local API = FC.API
local previousRefreshCapabilities = API.RefreshCapabilities

local function safeValue(value)
    if value == nil then return nil end
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if ok and secret then return nil end
    end
    return value
end

local function getItemMetadata(itemID, entry)
    if not itemID or not entry then return end
    if API.capabilities and API.capabilities.itemInfoInstant then
        local ok, _, _, _, _, _, classID, subClassID = pcall(C_Item.GetItemInfoInstant, itemID)
        if ok then
            entry.classID = safeValue(classID)
            entry.subClassID = safeValue(subClassID)
        end
    end
    if API.capabilities and API.capabilities.itemInfo then
        local ok, name, link = pcall(C_Item.GetItemInfo, itemID)
        if ok then
            entry.name = safeValue(name)
            entry.link = entry.link or safeValue(link)
        end
    end
end

function API:RefreshCapabilities()
    previousRefreshCapabilities(self)
    self.capabilities.bankTabs = type(C_Bank) == "table"
        and type(C_Bank.FetchPurchasedBankTabIDs) == "function"
    self.capabilities.bankTypes = type(C_Bank) == "table"
        and type(C_Bank.FetchViewableBankTypes) == "function"
    self.capabilities.bankView = type(C_Bank) == "table"
        and type(C_Bank.CanViewBank) == "function"
    self.capabilities.storage = self.capabilities.bankTabs and self.capabilities.containers
end

function API:GetBankTypeValues()
    local values = {}
    if not self.capabilities or not self.capabilities.bankTypes then
        return values, nil
    end

    local ok, result = pcall(C_Bank.FetchViewableBankTypes)
    if not ok or type(result) ~= "table" then return values, false end

    for _, bankType in ipairs(result) do
        local value = safeValue(bankType)
        if value ~= nil then values[#values + 1] = value end
    end
    return values, true
end

function API:GetPurchasedBankTabIDs(bankType)
    if not self.capabilities or not self.capabilities.bankTabs or bankType == nil then return {}, false end
    if self.capabilities.bankView then
        local viewOk, canView = pcall(C_Bank.CanViewBank, bankType)
        canView = viewOk and safeValue(canView) or nil
        if not viewOk or canView == false or canView == nil then return {}, false end
    end

    local ok, tabIDs = pcall(C_Bank.FetchPurchasedBankTabIDs, bankType)
    if not ok or type(tabIDs) ~= "table" then return {}, false end
    local result = {}
    local seen = {}
    for _, rawTabID in ipairs(tabIDs) do
        local tabID = safeValue(rawTabID)
        if type(tabID) == "number" and not seen[tabID] then
            seen[tabID] = true
            result[#result + 1] = tabID
        end
    end
    table.sort(result)
    return result, true
end

function API:GetContainerItemSnapshot(containerIDs)
    if not self.capabilities or not self.capabilities.containers then return nil, false end

    containerIDs = containerIDs or {}
    if #containerIDs == 0 then return {}, true end

    local snapshot = {}
    local successfulContainers = 0
    for _, bagID in ipairs(containerIDs) do
        local okSlots, numSlots = pcall(C_Container.GetContainerNumSlots, bagID)
        if okSlots and type(numSlots) == "number" then
            successfulContainers = successfulContainers + 1
            for slot = 1, numSlots do
                local okItem, info = pcall(C_Container.GetContainerItemInfo, bagID, slot)
                if okItem and type(info) == "table" then
                    local itemID = safeValue(info.itemID)
                    if type(itemID) == "number" then
                        local entry = snapshot[itemID]
                        if not entry then
                            entry = {
                                itemID = itemID,
                                count = 0,
                                link = safeValue(info.hyperlink),
                                iconFileID = safeValue(info.iconFileID),
                                containers = {},
                            }
                            snapshot[itemID] = entry
                        end
                        local count = tonumber(safeValue(info.stackCount)) or 1
                        entry.count = entry.count + count
                        entry.containers[bagID] = (entry.containers[bagID] or 0) + count
                        entry.link = entry.link or safeValue(info.hyperlink)
                    end
                end
            end
        end
    end

    -- Bank caches are replaced as a whole, so a partial tab read must never be
    -- treated as authoritative. Preserve the previous snapshot instead.
    if successfulContainers ~= #containerIDs then return nil, false end
    for itemID, entry in pairs(snapshot) do getItemMetadata(itemID, entry) end
    return snapshot, true
end

function API:GetBankStorageSnapshot()
    if not self.capabilities or not self.capabilities.storage then return nil end

    local enumBankType = type(Enum) == "table" and Enum.BankType or nil
    local characterType = enumBankType and enumBankType.Character or 0
    local accountType = enumBankType and enumBankType.Account or 2
    local visible, visibleOk = self:GetBankTypeValues()
    if visibleOk == false then return nil end

    local visibleSet = {}
    for _, bankType in ipairs(visible) do visibleSet[bankType] = true end

    local result = {
        character = nil,
        account = nil,
        scannedAt = time and time() or 0,
    }
    local scannedAny = false

    if #visible == 0 or visibleSet[characterType] then
        local ids, idsOk = self:GetPurchasedBankTabIDs(characterType)
        if idsOk then
            local items, itemsOk = self:GetContainerItemSnapshot(ids)
            if itemsOk then
                result.character = {
                    bankType = characterType,
                    tabIDs = ids,
                    items = items,
                }
                scannedAny = true
            end
        end
    end

    if #visible == 0 or visibleSet[accountType] then
        local ids, idsOk = self:GetPurchasedBankTabIDs(accountType)
        if idsOk then
            local items, itemsOk = self:GetContainerItemSnapshot(ids)
            if itemsOk then
                result.account = {
                    bankType = accountType,
                    tabIDs = ids,
                    items = items,
                }
                scannedAny = true
            end
        end
    end

    if not scannedAny then return nil end
    return result
end
