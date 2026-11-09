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

function API:RefreshCapabilities()
    previousRefreshCapabilities(self)
    self.capabilities.itemSets = type(C_Item) == "table"
        and type(C_Item.GetItemSetInfo) == "function"
    self.capabilities.itemSpecs = type(C_Item) == "table"
        and type(C_Item.GetItemSpecInfo) == "function"
end

function API:GetItemIntelligenceBase(itemID)
    itemID = tonumber(itemID)
    if not itemID or not self.capabilities or not self.capabilities.itemInfo then return nil end

    local ok, name, link, quality, itemLevel, minLevel, itemType, itemSubType, stackCount, equipLoc, icon,
        sellPrice, classID, subClassID, bindType, expansionID, setID, isCraftingReagent, description = pcall(C_Item.GetItemInfo, itemID)
    name = ok and safeValue(name) or nil
    if not name then return nil end

    local result = {
        itemID = itemID,
        name = name,
        link = safeValue(link),
        quality = safeValue(quality),
        itemLevel = safeValue(itemLevel),
        minLevel = safeValue(minLevel),
        itemType = safeValue(itemType),
        itemSubType = safeValue(itemSubType),
        stackCount = safeValue(stackCount),
        equipLoc = safeValue(equipLoc),
        icon = safeValue(icon),
        sellPrice = safeValue(sellPrice),
        classID = safeValue(classID),
        subClassID = safeValue(subClassID),
        bindType = safeValue(bindType),
        expansionID = safeValue(expansionID),
        setID = safeValue(setID),
        isCraftingReagent = safeValue(isCraftingReagent) == true,
        description = safeValue(description),
    }

    if result.setID and self.capabilities.itemSets then
        local setOk, setName = pcall(C_Item.GetItemSetInfo, result.setID)
        if setOk then result.setName = safeValue(setName) end
    end

    if self.capabilities.itemSpecs then
        local specOk, specs = pcall(C_Item.GetItemSpecInfo, itemID)
        if specOk and type(specs) == "table" then
            result.specIDs = {}
            for _, rawSpecID in ipairs(specs) do
                local specID = safeValue(rawSpecID)
                if type(specID) == "number" then result.specIDs[#result.specIDs + 1] = specID end
            end
        end
    end
    return result
end
