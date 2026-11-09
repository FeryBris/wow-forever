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
    self.capabilities.randomDungeons = type(GetNumRandomDungeons) == "function"
        and type(GetLFGRandomDungeonInfo) == "function"
end

function API:GetLevelAppropriateDungeonSnapshot()
    if not self.capabilities or not self.capabilities.randomDungeons then return {} end

    local level = 0
    if type(UnitLevel) == "function" then
        local levelOk, rawLevel = pcall(UnitLevel, "player")
        level = levelOk and tonumber(safeValue(rawLevel)) or 0
    end

    local okCount, rawCount = pcall(GetNumRandomDungeons)
    local count = okCount and tonumber(safeValue(rawCount)) or nil
    if not count then return {} end

    local result = {}
    for index = 1, count do
        local ok, id, name, typeID, subtypeID, minLevel, maxLevel, recLevel, minRecLevel, maxRecLevel,
            expansionLevel, groupID, textureFilename, difficultyID, maxPlayers, description, isHoliday,
            bonusRepAmount, minPlayers, isTimeWalker, name2, minGearLevel, isScalingDungeon = pcall(GetLFGRandomDungeonInfo, index)

        id = ok and safeValue(id) or nil
        name = ok and safeValue(name) or nil
        if id and name then
            minLevel = tonumber(safeValue(minLevel)) or 0
            maxLevel = tonumber(safeValue(maxLevel)) or 0
            local scaling = safeValue(isScalingDungeon) == true
            local withinMinimum = level >= minLevel
            local withinMaximum = maxLevel <= 0 or level <= maxLevel or scaling
            if withinMinimum and withinMaximum then
                result[#result + 1] = {
                    id = id,
                    name = name,
                    typeID = safeValue(typeID),
                    subtypeID = safeValue(subtypeID),
                    minLevel = minLevel,
                    maxLevel = maxLevel,
                    recLevel = tonumber(safeValue(recLevel)),
                    minRecLevel = tonumber(safeValue(minRecLevel)),
                    maxRecLevel = tonumber(safeValue(maxRecLevel)),
                    maxPlayers = tonumber(safeValue(maxPlayers)),
                    minPlayers = tonumber(safeValue(minPlayers)),
                    description = safeValue(description),
                    isHoliday = safeValue(isHoliday) == true,
                    isTimeWalker = safeValue(isTimeWalker) == true,
                    minGearLevel = tonumber(safeValue(minGearLevel)),
                    isScalingDungeon = scaling,
                }
            end
        end
    end

    table.sort(result, function(a, b)
        local aRec = tonumber(a.recLevel) or tonumber(a.minLevel) or 0
        local bRec = tonumber(b.recLevel) or tonumber(b.minLevel) or 0
        local aDelta = math.abs(level - aRec)
        local bDelta = math.abs(level - bRec)
        if aDelta == bDelta then return tostring(a.name) < tostring(b.name) end
        return aDelta < bDelta
    end)
    return result
end
