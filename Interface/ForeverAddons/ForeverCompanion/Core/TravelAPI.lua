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

local function safeBooleanCall(callback, ...)
    if type(callback) ~= "function" then return nil end
    local ok, value = pcall(callback, ...)
    if not ok then return nil end
    value = safeValue(value)
    if value == nil then return nil end
    return value == true
end

local function safeCountCall(callback, ...)
    if type(callback) ~= "function" then return 0 end
    local ok, value = pcall(callback, ...)
    if not ok then return 0 end
    return math.max(0, tonumber(safeValue(value)) or 0)
end

local function safeXY(position)
    if not position then return nil, nil end
    if type(position.GetXY) == "function" then
        local ok, x, y = pcall(position.GetXY, position)
        if ok then return tonumber(safeValue(x)), tonumber(safeValue(y)) end
    end
    local okX, x = pcall(function() return position.x end)
    local okY, y = pcall(function() return position.y end)
    if okX and okY then return tonumber(safeValue(x)), tonumber(safeValue(y)) end
    return nil, nil
end

local function distanceSquared(ax, ay, bx, by)
    ax, ay, bx, by = tonumber(ax), tonumber(ay), tonumber(bx), tonumber(by)
    if not ax or not ay or not bx or not by then return nil end
    local dx = ax - bx
    local dy = ay - by
    return dx * dx + dy * dy
end

function API:RefreshCapabilities()
    previousRefreshCapabilities(self)
    self.capabilities.mapInfo = type(C_Map) == "table" and type(C_Map.GetMapInfo) == "function"
    self.capabilities.mapPosition = type(C_Map) == "table" and type(C_Map.GetPlayerMapPosition) == "function"
    self.capabilities.taxiNodes = type(C_TaxiMap) == "table" and type(C_TaxiMap.GetTaxiNodesForMap) == "function"
    self.capabilities.travel = self.capabilities.maps and self.capabilities.mapInfo
end

function API:GetMapContextForUnit(unit)
    unit = unit or "player"
    if not self.capabilities or not self.capabilities.maps then return nil end
    local okMap, rawMapID = pcall(C_Map.GetBestMapForUnit, unit)
    local mapID = okMap and safeValue(rawMapID) or nil
    if type(mapID) ~= "number" then return nil end

    local context = { mapID = mapID, unit = unit }
    if self.capabilities.mapInfo then
        local okInfo, info = pcall(C_Map.GetMapInfo, mapID)
        if okInfo and type(info) == "table" then
            context.mapName = safeValue(info.name)
            context.mapType = safeValue(info.mapType)
            context.parentMapID = safeValue(info.parentMapID)
        end
    end

    if self.capabilities.mapPosition then
        local okPos, position = pcall(C_Map.GetPlayerMapPosition, mapID, unit)
        if okPos and position then
            context.x, context.y = safeXY(position)
        end
    end
    return context
end

function API:GetTaxiSnapshot()
    if not self.capabilities or not self.capabilities.taxiNodes then return nil end
    local playerContext = self:GetMapContextForUnit("player")
    if not playerContext then return nil end

    local mapIDs = {}
    local seenMaps = {}
    local mapID = playerContext.mapID
    for _ = 1, 5 do
        if type(mapID) ~= "number" or seenMaps[mapID] then break end
        seenMaps[mapID] = true
        mapIDs[#mapIDs + 1] = mapID

        if not self.capabilities.mapInfo then break end
        local okInfo, info = pcall(C_Map.GetMapInfo, mapID)
        if not okInfo or type(info) ~= "table" then break end
        local parentMapID = safeValue(info.parentMapID)
        if type(parentMapID) ~= "number" or parentMapID == 0 then break end
        mapID = parentMapID
    end

    local nodes = {}
    local seenNodes = {}
    for _, candidateMapID in ipairs(mapIDs) do
        local okNodes, mapNodes = pcall(C_TaxiMap.GetTaxiNodesForMap, candidateMapID)
        if okNodes and type(mapNodes) == "table" then
            for _, node in ipairs(mapNodes) do
                if type(node) == "table" then
                    local nodeID = safeValue(node.nodeID)
                    if (type(nodeID) == "number" or type(nodeID) == "string") and not seenNodes[nodeID] then
                        seenNodes[nodeID] = true
                        local x, y = safeXY(node.position)
                        nodes[#nodes + 1] = {
                            nodeID = nodeID,
                            mapID = candidateMapID,
                            name = safeValue(node.name),
                            faction = safeValue(node.faction),
                            atlasName = safeValue(node.atlasName),
                            textureKit = safeValue(node.textureKit),
                            isUndiscovered = safeValue(node.isUndiscovered) == true,
                            x = x,
                            y = y,
                            distanceSquared = candidateMapID == playerContext.mapID and distanceSquared(playerContext.x, playerContext.y, x, y) or nil,
                        }
                    end
                end
            end
        end
    end

    table.sort(nodes, function(a, b)
        if a.isUndiscovered ~= b.isUndiscovered then
            return a.isUndiscovered == true
        end
        if a.distanceSquared and b.distanceSquared and a.distanceSquared ~= b.distanceSquared then
            return a.distanceSquared < b.distanceSquared
        end
        return tostring(a.name or a.nodeID) < tostring(b.name or b.nodeID)
    end)

    return {
        player = playerContext,
        nodes = nodes,
        mapIDs = mapIDs,
        scannedAt = time and time() or 0,
    }
end

function API:GetGroupTravelSnapshot()
    local result = {}
    local units = {}

    local inRaid = safeBooleanCall(IsInRaid)
    local inGroup = safeBooleanCall(IsInGroup)
    if inRaid == true then
        local count = safeCountCall(GetNumGroupMembers)
        for i = 1, count do units[#units + 1] = "raid" .. i end
    elseif inGroup == true then
        units[#units + 1] = "player"
        local count = safeCountCall(GetNumSubgroupMembers)
        for i = 1, count do units[#units + 1] = "party" .. i end
    else
        units[1] = "player"
    end

    for _, unit in ipairs(units) do
        local exists = true
        if type(UnitExists) == "function" then
            local existsValue = safeBooleanCall(UnitExists, unit)
            exists = existsValue ~= false
        end
        if exists then
            local context = self:GetMapContextForUnit(unit)
            if context then
                local okName, playerName = pcall(UnitName, unit)
                context.playerName = okName and safeValue(playerName) or unit
                if not context.playerName then context.playerName = unit end
                result[#result + 1] = context
            end
        end
    end
    return result
end
