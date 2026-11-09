local _, FC = ...

local Dungeons = {}
FC.Dungeons = Dungeons

local SOURCE = "Dungeons"

function Dungeons:GetSnapshot()
    return self.snapshot or { entries = {} }
end

function Dungeons:Scan(reason)
    FC.Suggestions:ClearSource(SOURCE)
    if FC.IsModuleEnabled and not FC:IsModuleEnabled("Journey") then
        self.snapshot = {
            entries = {},
            scannedAt = time and time() or 0,
            reason = reason or "journey-disabled",
        }
        return
    end

    local available = FC.API:GetLevelAppropriateDungeonSnapshot()
    self.snapshot = {
        entries = available,
        scannedAt = time and time() or 0,
        reason = reason or "manual",
    }

    for index = 1, math.min(2, #available) do
        local dungeon = available[index]
        local levelText
        if dungeon.isScalingDungeon then
            levelText = FC:GetText("DUNGEON_SCALING_RANGE")
        elseif dungeon.minLevel and dungeon.maxLevel and dungeon.maxLevel > 0 then
            levelText = FC:GetText("DUNGEON_LEVEL_RANGE", dungeon.minLevel, dungeon.maxLevel)
        else
            levelText = FC:GetText("DUNGEON_LEVEL_PLUS", tonumber(dungeon.minLevel) or 0)
        end
        FC.Suggestions:Add({
            id = "dungeon_" .. tostring(dungeon.id),
            source = SOURCE,
            category = "Dungeon",
            priority = 40 - (index - 1),
            title = tostring(dungeon.name),
            description = FC:GetText("DUNGEON_SUGGESTION_DESC", levelText),
        })
    end
end

function Dungeons:Refresh(reason) self:Scan(reason) end

function Dungeons:OnEvent(event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_LEVEL_UP" then self:Scan(event) end
end

function Dungeons:OnDisable()
    FC.Suggestions:ClearSource(SOURCE)
    self.snapshot = { entries = {} }
end

FC:RegisterModule("Dungeons", Dungeons)
