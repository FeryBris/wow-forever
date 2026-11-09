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

local function distanceSquared(ax, ay, bx, by)
    ax, ay, bx, by = tonumber(ax), tonumber(ay), tonumber(bx), tonumber(by)
    if not ax or not ay or not bx or not by then return nil end
    local dx = ax - bx
    local dy = ay - by
    return dx * dx + dy * dy
end

function API:RefreshCapabilities()
    previousRefreshCapabilities(self)
    self.capabilities.questsOnMap = type(C_QuestLog) == "table"
        and type(C_QuestLog.GetQuestsOnMap) == "function"
    self.capabilities.questTitles = type(C_QuestLog) == "table"
        and type(C_QuestLog.GetTitleForQuestID) == "function"
    self.capabilities.questObjectives = type(C_QuestLog) == "table"
        and type(C_QuestLog.GetQuestObjectives) == "function"
    self.capabilities.questLines = type(C_QuestLine) == "table"
        and type(C_QuestLine.GetQuestLineInfo) == "function"
    self.capabilities.journey = self.capabilities.questsOnMap and self.capabilities.maps
end

function API:GetJourneyQuestSnapshot()
    if not self.capabilities or not self.capabilities.journey then return nil end

    local player = self:GetMapContextForUnit("player")
    if not player or not player.mapID then return nil end

    local ok, quests = pcall(C_QuestLog.GetQuestsOnMap, player.mapID)
    if not ok or type(quests) ~= "table" then return nil end

    local snapshot = {
        player = player,
        quests = {},
        scannedAt = time and time() or 0,
    }

    for _, info in ipairs(quests) do
        if type(info) == "table" then
            local questID = safeValue(info.questID)
            if type(questID) == "number" then
                local mapID = safeValue(info.mapID)
                if type(mapID) ~= "number" then mapID = player.mapID end

                local quest = {
                    questID = questID,
                    mapID = mapID,
                    x = tonumber(safeValue(info.x)),
                    y = tonumber(safeValue(info.y)),
                    isQuestStart = safeValue(info.isQuestStart) == true,
                    isDaily = safeValue(info.isDaily) == true,
                    inProgress = safeValue(info.inProgress) == true,
                    isMeta = safeValue(info.isMeta) == true,
                    isMapIndicatorQuest = safeValue(info.isMapIndicatorQuest) == true,
                    questTagType = safeValue(info.questTagType),
                    numObjectives = tonumber(safeValue(info.numObjectives)) or 0,
                }

                if self.capabilities.questTitles then
                    local titleOk, title = pcall(C_QuestLog.GetTitleForQuestID, questID)
                    if titleOk then quest.title = safeValue(title) end
                end

                if self.capabilities.questObjectives then
                    local objOk, objectives = pcall(C_QuestLog.GetQuestObjectives, questID)
                    if objOk and type(objectives) == "table" then
                        quest.objectives = {}
                        quest.completedObjectives = 0
                        for _, objective in ipairs(objectives) do
                            if type(objective) == "table" then
                                local finished = safeValue(objective.finished) == true
                                quest.objectives[#quest.objectives + 1] = {
                                    text = safeValue(objective.text),
                                    type = safeValue(objective.type),
                                    finished = finished,
                                    numFulfilled = safeValue(objective.numFulfilled),
                                    numRequired = safeValue(objective.numRequired),
                                }
                                if finished then quest.completedObjectives = quest.completedObjectives + 1 end
                            end
                        end
                        quest.objectiveCount = #quest.objectives
                    end
                end

                if self.capabilities.questLines then
                    local lineOk, lineInfo = pcall(C_QuestLine.GetQuestLineInfo, questID, player.mapID, true)
                    if lineOk and type(lineInfo) == "table" then
                        quest.questLineID = safeValue(lineInfo.questLineID)
                        quest.questLineName = safeValue(lineInfo.questLineName)
                        quest.isImportant = safeValue(lineInfo.isImportant) == true
                        quest.isLocalStory = safeValue(lineInfo.isLocalStory) == true
                    end
                end

                if quest.mapID == player.mapID then
                    quest.distanceSquared = distanceSquared(player.x, player.y, quest.x, quest.y)
                end
                snapshot.quests[#snapshot.quests + 1] = quest
            end
        end
    end

    table.sort(snapshot.quests, function(a, b)
        if a.inProgress ~= b.inProgress then return a.inProgress == true end
        if a.isImportant ~= b.isImportant then return a.isImportant == true end
        if a.distanceSquared and b.distanceSquared and a.distanceSquared ~= b.distanceSquared then
            return a.distanceSquared < b.distanceSquared
        end
        return tostring(a.title or a.questID) < tostring(b.title or b.questID)
    end)

    return snapshot
end
