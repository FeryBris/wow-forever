-- Finds a dungeon's map by name when the uiMapID stored in FDJ.DUNGEON_MAPS
-- has no map art on this client (map IDs can differ between client builds).
-- Scans the client's map list once per dungeon and caches the result.
local FDJ = _G.ForeverDungeonJournal_NS
if not FDJ then return end

local cache = {}

local function Norm(s)
    if type(s) ~= "string" then return nil end
    return (s:lower():gsub("[^%w\128-\255]", ""))
end

local function HasArt(id)
    local ok, layers = pcall(C_Map.GetMapArtLayers, id)
    if not ok or type(layers) ~= "table" or not layers[1] then return false end
    local ok2, tex = pcall(C_Map.GetMapArtLayerTextures, id, 1)
    return ok2 and type(tex) == "table" and #tex > 0
end

function FDJ.FindMapArtID(dungeonName, floorData)
    if not (C_Map and C_Map.GetMapInfo and C_Map.GetMapArtLayers and C_Map.GetMapArtLayerTextures) then return nil end
    if type(dungeonName) ~= "string" then return nil end
    local spec = FDJ.DUNGEON_MAPS and FDJ.DUNGEON_MAPS[dungeonName]
    local floorIndex = 1
    for i, f in ipairs(spec and spec.floors or {}) do if f == floorData then floorIndex = i end end

    local found = cache[dungeonName]
    if found == nil then
        local wanted = {}
        local base = dungeonName:gsub("^.-:%s*", "")
        for _, n in ipairs({ dungeonName, base, FDJ.LocalizeDungeonName and FDJ.LocalizeDungeonName(dungeonName) }) do
            local k = Norm(n)
            if k and k ~= "" then wanted[k] = true end
        end
        found = {}
        for id = 1, 3000 do
            local ok, info = pcall(C_Map.GetMapInfo, id)
            if ok and type(info) == "table" and wanted[Norm(info.name) or ""] and HasArt(id) then
                found[#found + 1] = id
            end
        end
        cache[dungeonName] = found
    end
    return found[floorIndex] or found[1]
end
