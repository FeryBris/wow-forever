local _, FC = ...

local CampFinder = {}
FC.CampFinder = CampFinder

function CampFinder:GetDetectedProvider()
    if type(_G.SmoreSkills) == "table" then
        return {
            id = "SmoreSkills",
            name = "S'more Skills",
            version = _G.SmoreSkills.VERSION,
        }
    end
    return nil
end

function CampFinder:OpenMap()
    local opened = false
    if type(ToggleWorldMap) == "function" then
        local ok = pcall(ToggleWorldMap)
        opened = ok
    elseif type(WorldMapFrame) == "table" or type(WorldMapFrame) == "userdata" then
        local ok = pcall(function() WorldMapFrame:Show() end)
        opened = ok
    end

    if not opened then
        return false, FC:GetText("CAMP_FINDER_FAILED")
    end
    return true, self:GetDetectedProvider()
end

function CampFinder:GetStatusText()
    local provider = self:GetDetectedProvider()
    if provider then
        return FC:GetText("CAMP_FINDER_PROVIDER",
            provider.name,
            provider.version and (" " .. tostring(provider.version)) or "")
    end
    return FC:GetText("CAMP_FINDER_NONE")
end
