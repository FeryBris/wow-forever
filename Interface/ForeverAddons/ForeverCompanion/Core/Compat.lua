local _, FC = ...

local API = FC.API

local function safeValue(value)
    if value == nil then return nil end
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if ok and secret then return nil end
    end
    return value
end

function API:RefreshCapabilities()
    self.capabilities = {
        professions = type(GetProfessions) == "function" and type(GetProfessionInfo) == "function",
        tradeSkillRecipes = type(C_TradeSkillUI) == "table"
            and type(C_TradeSkillUI.GetBaseProfessionInfo) == "function"
            and type(C_TradeSkillUI.GetAllRecipeIDs) == "function"
            and type(C_TradeSkillUI.GetRecipeInfo) == "function",
        recipeSchematic = type(C_TradeSkillUI) == "table"
            and type(C_TradeSkillUI.GetRecipeSchematic) == "function",
        containers = type(C_Container) == "table"
            and type(C_Container.GetContainerNumFreeSlots) == "function"
            and type(C_Container.GetContainerNumSlots) == "function"
            and type(C_Container.GetContainerItemInfo) == "function",
        itemInfo = type(C_Item) == "table" and type(C_Item.GetItemInfo) == "function",
        itemInfoInstant = type(C_Item) == "table" and type(C_Item.GetItemInfoInstant) == "function",
        durability = type(GetInventoryItemDurability) == "function",
        maps = type(C_Map) == "table" and type(C_Map.GetBestMapForUnit) == "function",
        legacy = false,
        camps = false,
    }
end

function API:GetProfessionSnapshot()
    if not self.capabilities or not self.capabilities.professions then
        return nil
    end

    local ok, profession1, profession2, archaeology, fishing, cooking = pcall(GetProfessions)
    if not ok then return nil end

    local indices = { profession1, profession2, archaeology, fishing, cooking }
    local professions = {}
    for position = 1, 5 do
        local rawIndex = indices[position]
        if rawIndex ~= nil then
            local index = safeValue(rawIndex)
            if index == nil then return nil end
            local infoOk, name, icon, skillLevel, maxSkillLevel, _, _, skillLineID, skillModifier, _, _, skillLineName = pcall(GetProfessionInfo, index)
            if not infoOk then return nil end
            name = safeValue(name)
            if not name then return nil end
            professions[#professions + 1] = {
                name = name,
                icon = safeValue(icon),
                skill = tonumber(safeValue(skillLevel)) or 0,
                maxSkill = tonumber(safeValue(maxSkillLevel)) or 0,
                skillLineID = safeValue(skillLineID),
                skillModifier = tonumber(safeValue(skillModifier)) or 0,
                skillLineName = safeValue(skillLineName),
            }
        end
    end

    table.sort(professions, function(a, b)
        return tostring(a.name) < tostring(b.name)
    end)

    return professions
end

function API:GetCurrentProfessionRecipeSnapshot()
    if not self.capabilities or not self.capabilities.tradeSkillRecipes then
        return nil
    end

    local baseOk, professionInfo = pcall(C_TradeSkillUI.GetBaseProfessionInfo)
    if not baseOk or type(professionInfo) ~= "table" or safeValue(professionInfo.professionID) == nil then
        return nil
    end

    local listOk, recipeIDs = pcall(C_TradeSkillUI.GetAllRecipeIDs)
    if not listOk or type(recipeIDs) ~= "table" then
        return nil
    end

    local professionID = safeValue(professionInfo.professionID)
    local snapshot = {
        professionID = professionID,
        professionName = safeValue(professionInfo.professionName) or safeValue(professionInfo.parentProfessionName) or "Unknown",
        skillLevel = tonumber(safeValue(professionInfo.skillLevel)) or 0,
        maxSkillLevel = tonumber(safeValue(professionInfo.maxSkillLevel)) or 0,
        loaded = #recipeIDs > 0,
        complete = true,
        expectedTotal = #recipeIDs,
        recipes = {},
        learned = 0,
        unlearned = 0,
    }

    for _, rawRecipeID in ipairs(recipeIDs) do
        local recipeID = safeValue(rawRecipeID)
        if recipeID == nil then
            snapshot.complete = false
        else
            local recipeOk, recipeInfo = pcall(C_TradeSkillUI.GetRecipeInfo, recipeID)
            if recipeOk and type(recipeInfo) == "table" then
                local recipeName = safeValue(recipeInfo.name)
                if recipeName then
                    local learned = safeValue(recipeInfo.learned) == true
                    snapshot.recipes[#snapshot.recipes + 1] = {
                        recipeID = safeValue(recipeInfo.recipeID) or recipeID,
                        name = recipeName,
                        learned = learned,
                        sourceType = safeValue(recipeInfo.sourceType),
                        categoryID = safeValue(recipeInfo.categoryID),
                        skillLineAbilityID = safeValue(recipeInfo.skillLineAbilityID),
                    }
                    if learned then
                        snapshot.learned = snapshot.learned + 1
                    else
                        snapshot.unlearned = snapshot.unlearned + 1
                    end
                else
                    snapshot.complete = false
                end
            else
                snapshot.complete = false
            end
        end
    end

    snapshot.total = #snapshot.recipes
    if snapshot.total ~= snapshot.expectedTotal then snapshot.complete = false end
    return snapshot
end

local function getItemDetails(itemID)
    if not itemID or type(C_Item) ~= "table" or type(C_Item.GetItemInfo) ~= "function" then
        return nil, nil, nil
    end

    local ok, name, link, _, _, _, _, _, _, icon = pcall(C_Item.GetItemInfo, itemID)
    if not ok then
        return nil, nil, nil
    end
    return safeValue(name), safeValue(link), safeValue(icon)
end

function API:GetRecipeSchematicSnapshot(recipeID)
    recipeID = tonumber(recipeID)
    if not recipeID or not self.capabilities or not self.capabilities.recipeSchematic then
        return nil
    end

    local ok, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
    if not ok or type(schematic) ~= "table" then
        return nil
    end

    local snapshot = {
        recipeID = safeValue(schematic.recipeID) or recipeID,
        name = safeValue(schematic.name),
        icon = safeValue(schematic.icon),
        outputItemID = safeValue(schematic.outputItemID),
        quantityMin = tonumber(safeValue(schematic.quantityMin)) or 1,
        quantityMax = tonumber(safeValue(schematic.quantityMax)) or tonumber(safeValue(schematic.quantityMin)) or 1,
        reagents = {},
    }

    for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
        if type(slot) == "table" and safeValue(slot.required) ~= false and not (safeValue(slot.hiddenInCraftingForm) == true) then
            local alternatives = {}
            for _, reagent in ipairs(slot.reagents or {}) do
                if type(reagent) == "table" then
                    local reagentItemID = safeValue(reagent.itemID)
                    if type(reagentItemID) == "number" then
                        alternatives[#alternatives + 1] = reagentItemID
                    end
                end
            end

            if #alternatives > 0 then
                local itemID = #alternatives == 1 and alternatives[1] or nil
                local name, link, icon = getItemDetails(itemID)
                snapshot.reagents[#snapshot.reagents + 1] = {
                    itemID = itemID,
                    name = name,
                    link = link,
                    icon = icon,
                    quantityRequired = tonumber(safeValue(slot.quantityRequired)) or 0,
                    ambiguous = #alternatives > 1,
                    alternatives = alternatives,
                    reagentType = safeValue(slot.reagentType),
                    slotIndex = safeValue(slot.slotIndex),
                }
            end
        end
    end

    return snapshot
end

function API:GetBagItemSnapshot()
    if not self.capabilities or not self.capabilities.containers then
        return nil
    end

    local snapshot = {}
    local successfulBags = 0
    for bag = 0, 4 do
        local slotsOk, numSlots = pcall(C_Container.GetContainerNumSlots, bag)
        if slotsOk and type(numSlots) == "number" then
            successfulBags = successfulBags + 1
            for slot = 1, numSlots do
                local infoOk, itemInfo = pcall(C_Container.GetContainerItemInfo, bag, slot)
                if infoOk and type(itemInfo) == "table" then
                    local itemID = safeValue(itemInfo.itemID)
                    if type(itemID) == "number" then
                        local count = tonumber(safeValue(itemInfo.stackCount)) or 1
                        local entry = snapshot[itemID]
                        if not entry then
                            entry = {
                                itemID = itemID,
                                count = 0,
                                link = safeValue(itemInfo.hyperlink),
                                iconFileID = safeValue(itemInfo.iconFileID),
                            }
                            snapshot[itemID] = entry
                        end
                        entry.count = entry.count + count
                        local hyperlink = safeValue(itemInfo.hyperlink)
                        if not entry.link and hyperlink then
                            entry.link = hyperlink
                        end

                        if self.capabilities.itemInfoInstant and entry.classID == nil then
                            local instantOk, _, _, _, _, _, classID, subClassID = pcall(C_Item.GetItemInfoInstant, itemID)
                            if instantOk then
                                entry.classID = safeValue(classID)
                                entry.subClassID = safeValue(subClassID)
                            end
                        end
                    end
                end
            end
        end
    end

    -- A partial bag scan is not authoritative. Preserve the previous cache
    -- instead of making items from a temporarily unreadable bag disappear.
    if successfulBags ~= 5 then return nil end

    if self.capabilities.itemInfo then
        for itemID, entry in pairs(snapshot) do
            local itemOk, itemName, itemLink = pcall(C_Item.GetItemInfo, itemID)
            if itemOk then
                entry.name = safeValue(itemName)
                entry.link = entry.link or safeValue(itemLink)
            end
        end
    end

    return snapshot
end

function API:GetFreeBagSlots()
    if not self.capabilities or not self.capabilities.containers then
        return nil
    end

    local total = 0
    local successfulBags = 0
    for bag = 0, 4 do
        local ok, freeSlots = pcall(C_Container.GetContainerNumFreeSlots, bag)
        if ok and type(freeSlots) == "number" then
            successfulBags = successfulBags + 1
            total = total + freeSlots
        end
    end
    -- Never turn a partial read into an artificially low free-slot warning.
    if successfulBags ~= 5 then return nil end
    return total
end

function API:GetLowestDurabilityPercent()
    if not self.capabilities or not self.capabilities.durability then
        return nil
    end

    local lowest = nil
    for slot = 1, 19 do
        local ok, current, maximum = pcall(GetInventoryItemDurability, slot)
        current = ok and tonumber(safeValue(current)) or nil
        maximum = ok and tonumber(safeValue(maximum)) or nil
        if current and maximum and maximum > 0 then
            local percent = (current / maximum) * 100
            if not lowest or percent < lowest then lowest = percent end
        end
    end
    return lowest
end
