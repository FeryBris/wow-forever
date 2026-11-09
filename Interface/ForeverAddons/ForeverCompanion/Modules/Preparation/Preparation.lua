local _, FC = ...

local Preparation = {}
FC.Preparation = Preparation

local HEARTHSTONE_ITEM_ID = 6948
local PROJECTILE_CLASS_ID = 6

local function getBagItemCount(character, itemID)
    local bags = character and character.inventory and character.inventory.bags
    local entry = bags and bags[itemID]
    return entry and tonumber(entry.count) or 0
end

local function getProjectileCount(character)
    local total = 0
    local bags = character and character.inventory and character.inventory.bags
    for _, item in pairs(bags or {}) do
        if tonumber(item.classID) == PROJECTILE_CLASS_ID then
            total = total + (tonumber(item.count) or 0)
        end
    end
    return total
end

function Preparation:Scan()
    FC.Suggestions:ClearSource("Preparation")

    local character = FC:GetCurrentCharacter()
    if not character then
        return
    end

    local freeBagSlots = FC.API:GetFreeBagSlots()
    local lowestDurability = FC.API:GetLowestDurabilityPercent()
    local hearthstoneCount = getBagItemCount(character, HEARTHSTONE_ITEM_ID)
    local projectileCount = character.classFile == "HUNTER" and getProjectileCount(character) or nil

    character.preparation = character.preparation or {}
    character.preparation.freeBagSlots = freeBagSlots
    character.preparation.lowestDurability = lowestDurability
    character.preparation.hearthstoneCount = hearthstoneCount
    character.preparation.projectileCount = projectileCount
    character.preparation.lastSeen = time()

    if freeBagSlots ~= nil then
        if freeBagSlots <= 2 then
            FC.Suggestions:Add({
                id = "preparation_bags_critical",
                source = "Preparation",
                category = "Preparation",
                priority = 92,
                title = FC:GetText("SUGG_BAGS_CRITICAL_TITLE"),
                description = FC:GetText("SUGG_FREE_SLOTS_DESC", freeBagSlots),
            })
        elseif freeBagSlots <= 5 then
            FC.Suggestions:Add({
                id = "preparation_bags_low",
                source = "Preparation",
                category = "Preparation",
                priority = 72,
                title = FC:GetText("SUGG_BAGS_LOW_TITLE"),
                description = FC:GetText("SUGG_FREE_SLOTS_DESC", freeBagSlots),
            })
        end
    end

    if lowestDurability ~= nil then
        if lowestDurability <= 25 then
            FC.Suggestions:Add({
                id = "preparation_durability_critical",
                source = "Preparation",
                category = "Preparation",
                priority = 96,
                title = FC:GetText("SUGG_DURABILITY_CRITICAL_TITLE"),
                description = FC:GetText("SUGG_DURABILITY_DESC", lowestDurability),
            })
        elseif lowestDurability <= 50 then
            FC.Suggestions:Add({
                id = "preparation_durability_low",
                source = "Preparation",
                category = "Preparation",
                priority = 78,
                title = FC:GetText("SUGG_DURABILITY_LOW_TITLE"),
                description = FC:GetText("SUGG_DURABILITY_DESC", lowestDurability),
            })
        end
    end

    if projectileCount ~= nil then
        if projectileCount <= 100 then
            FC.Suggestions:Add({
                id = "preparation_hunter_ammo_critical",
                source = "Preparation",
                category = "Preparation",
                priority = 90,
                title = FC:GetText("SUGG_AMMO_CRITICAL_TITLE"),
                description = FC:GetText("SUGG_AMMO_DESC", projectileCount),
            })
        elseif projectileCount <= 300 then
            FC.Suggestions:Add({
                id = "preparation_hunter_ammo_low",
                source = "Preparation",
                category = "Preparation",
                priority = 70,
                title = FC:GetText("SUGG_AMMO_LOW_TITLE"),
                description = FC:GetText("SUGG_AMMO_DESC", projectileCount),
            })
        end
    end
end

function Preparation:Refresh()
    self:Scan()
end

function Preparation:OnEvent(event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "BAG_UPDATE_DELAYED" or event == "UPDATE_INVENTORY_DURABILITY" then
        self:Scan()
    end
end

FC:RegisterModule("Preparation", Preparation)
