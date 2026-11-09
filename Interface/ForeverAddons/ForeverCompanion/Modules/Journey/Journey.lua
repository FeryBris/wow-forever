local _, FC = ...

local Journey = {}
FC.Journey = Journey

local SOURCE = "Journey"

local function moduleEnabled(name)
    return type(FC.IsModuleEnabled) ~= "function" or FC:IsModuleEnabled(name)
end

local function addOpportunity(list, opportunity)
    if type(opportunity) ~= "table" or not opportunity.id or not opportunity.title then return end
    list[#list + 1] = opportunity
end

local function questProgressText(quest)
    local total = tonumber(quest.objectiveCount) or 0
    local completed = tonumber(quest.completedObjectives) or 0
    if total > 0 then return FC:GetText("JOURNEY_QUEST_PROGRESS", completed, total) end
    if quest.inProgress then return FC:GetText("JOURNEY_QUEST_IN_PROGRESS") end
    if quest.isQuestStart then return FC:GetText("JOURNEY_QUEST_START") end
    return FC:GetText("JOURNEY_QUEST_OPPORTUNITY")
end

local function collectQuestOpportunities(snapshot, mode, list)
    if not snapshot then return end
    local limit = mode == "EXPLORER" and 3 or 6
    local count = 0

    for _, quest in ipairs(snapshot.quests or {}) do
        if count >= limit then break end
        if quest.inProgress or quest.isQuestStart or quest.isImportant or quest.isLocalStory then
            count = count + 1
            local title = quest.title or FC:GetText("JOURNEY_QUEST_FALLBACK_TITLE", tostring(quest.questID))
            local description = questProgressText(quest)
            if quest.questLineName and mode ~= "EXPLORER" then
                description = description .. " • " .. tostring(quest.questLineName)
            end
            if mode == "GUIDE" and quest.x and quest.y then
                description = description .. string.format(" • %.1f, %.1f", quest.x * 100, quest.y * 100)
            end
            if mode == "EXPLORER" and not quest.inProgress then
                title = FC:GetText("JOURNEY_QUEST_NEARBY")
            end

            addOpportunity(list, {
                id = "quest_" .. tostring(quest.questID),
                kind = "Quest",
                title = title,
                description = description,
                priority = quest.inProgress and 68 or (quest.isImportant and 62 or 48),
                questID = quest.questID,
                mapID = quest.mapID,
                x = quest.x,
                y = quest.y,
            })
        end
    end
end

local function collectTravelOpportunities(mode, list)
    if not moduleEnabled("Travel") then return end

    local snapshot = FC.Travel and FC.Travel:GetSnapshot() or nil
    if snapshot then
        local undiscovered = {}
        for _, node in ipairs(snapshot.nodes or {}) do
            if node.isUndiscovered == true then undiscovered[#undiscovered + 1] = node end
        end

        if mode == "EXPLORER" and #undiscovered > 0 then
            addOpportunity(list, {
                id = "flight_undiscovered_group",
                kind = "Travel",
                title = FC:GetText("JOURNEY_TRAVEL_UNDISCOVERED_TITLE"),
                description = FC:GetText("SUGG_TRAVEL_FLIGHT_EXPLORER_DESC", #undiscovered),
                priority = 52,
                dedupeKey = "travel-undiscovered-flight",
            })
        else
            for index = 1, math.min(3, #undiscovered) do
                local node = undiscovered[index]
                local title = tostring(node.name or FC:GetText("JOURNEY_TRAVEL_UNDISCOVERED_FALLBACK"))
                local description = FC:GetText("JOURNEY_TRAVEL_UNDISCOVERED_DESC")
                if mode == "GUIDE" and node.x and node.y then
                    description = description .. string.format(" • %.1f, %.1f", node.x * 100, node.y * 100)
                end
                addOpportunity(list, {
                    id = "flight_" .. tostring(node.nodeID),
                    kind = "Travel",
                    title = title,
                    description = description,
                    priority = 52,
                    nodeID = node.nodeID,
                    dedupeKey = "flight-node:" .. tostring(node.nodeID),
                })
            end
        end
    end

    if moduleEnabled("TravelRoutes") and FC.Travel and type(FC.Travel.GetRelevantRoutes) == "function" then
        local routes = FC.Travel:GetRelevantRoutes()
        for index = 1, math.min(2, #routes) do
            local route = routes[index]
            local title = mode == "EXPLORER"
                and FC:GetText("JOURNEY_ROUTE_AREA_TITLE")
                or tostring(route.name or FC:GetText("JOURNEY_ROUTE_FALLBACK_TITLE"))
            local description
            if mode == "EXPLORER" then
                description = FC:GetText("JOURNEY_ROUTE_EXPLORER_DESC")
            elseif mode == "GUIDE" then
                description = string.format("%s → %s%s",
                    tostring(route.origin or FC:GetText("SUGG_TRAVEL_CURRENT_AREA")),
                    tostring(route.destination or FC:GetText("SUGG_TRAVEL_DESTINATION")),
                    route.notes and (" • " .. tostring(route.notes)) or "")
            else
                description = string.format("%s → %s",
                    tostring(route.origin or FC:GetText("SUGG_TRAVEL_CURRENT_AREA")),
                    tostring(route.destination or FC:GetText("SUGG_TRAVEL_DESTINATION")))
            end

            addOpportunity(list, {
                id = "route_" .. tostring(route.id or index),
                kind = "Travel",
                title = title,
                description = description,
                priority = 44,
                routeID = route.id,
            })
        end
    end
end

local function collectProfessionOpportunities(list)
    if not moduleEnabled("Professions") then return end
    local character = FC:GetCurrentCharacter()
    for _, profession in ipairs(character and character.professions or {}) do
        local skill = tonumber(profession.skill) or 0
        local maxSkill = tonumber(profession.maxSkill) or 0
        if maxSkill > 0 and skill < maxSkill then
            local remaining = maxSkill - skill
            if remaining <= math.max(10, math.floor(maxSkill * 0.15)) then
                local professionID = profession.skillLineID or profession.name
                addOpportunity(list, {
                    id = "profession_" .. tostring(professionID),
                    kind = "Profession",
                    title = FC:GetText("JOURNEY_PROFESSION_TITLE", FC:GetProfessionDisplayName(profession)),
                    description = FC:GetText("JOURNEY_PROFESSION_DESC", skill, maxSkill, remaining),
                    priority = 55,
                    professionID = professionID,
                    dedupeKey = "profession-cap:" .. tostring(professionID),
                })
            end
        end
    end
end

local function collectLegacyOpportunities(mode, list)
    if not moduleEnabled("Legacy") then return end
    local snapshot = FC.Legacy and FC.Legacy:GetSnapshot() or nil
    if not snapshot then return end

    local count = 0
    for _, challenge in ipairs(snapshot.challenges or {}) do
        if not challenge.completed and (tonumber(challenge.progress) or 0) > 0 and count < 3 then
            count = count + 1
            local percent = math.floor(((tonumber(challenge.progress) or 0) * 100) + 0.5)
            addOpportunity(list, {
                id = "legacy_" .. tostring(challenge.id),
                kind = "Legacy",
                title = mode == "EXPLORER" and FC:GetText("JOURNEY_LEGACY_TITLE") or tostring(challenge.name),
                description = FC:GetText("JOURNEY_LEGACY_DESC", percent),
                priority = 50 + math.floor(percent / 10),
                challengeID = challenge.id,
            })
        end
    end
end

local function collectCampOpportunities(list)
    if not moduleEnabled("Camps") then return end
    local snapshot = FC.Camps and FC.Camps:GetSnapshot() or nil
    if not snapshot or snapshot.benefit then return end
    local contribution = snapshot.contributions and snapshot.contributions[1]
    if contribution then
        addOpportunity(list, {
            id = "camp_" .. tostring(contribution.skillLineID),
            kind = "Camp",
            title = FC:GetText("JOURNEY_CAMP_TITLE"),
            description = FC:GetText("JOURNEY_CAMP_DESC",
                FC:GetProfessionDisplayName(contribution.skillLineID, contribution.professionName), tostring(contribution.feature)),
            priority = 38,
            professionID = contribution.skillLineID,
        })
    end
end

local function collectPinnedGoals(list)
    if not moduleEnabled("Goals") or not FC.Goals or type(FC.Goals.GetGoals) ~= "function" then return end
    for _, goal in ipairs(FC.Goals:GetGoals()) do
        if goal.enabled ~= false then
            local metadata = goal.metadata or {}
            local dedupeKey = metadata.kind == "Profession" and metadata.targetID
                and ("profession-cap:" .. tostring(metadata.targetID)) or nil
            addOpportunity(list, {
                id = "goal_" .. tostring(goal.id),
                kind = "Goal",
                title = type(FC.Goals.GetDisplayTitle) == "function" and FC.Goals:GetDisplayTitle(goal) or goal.title,
                description = type(FC.Goals.GetDisplayDescription) == "function" and FC.Goals:GetDisplayDescription(goal)
                    or goal.description or FC:GetText("JOURNEY_PINNED_GOAL"),
                priority = tonumber(goal.priority) or 65,
                goalID = goal.id,
                professionID = metadata.kind == "Profession" and metadata.targetID or nil,
                dedupeKey = dedupeKey,
            })
        end
    end
end

local function sortOpportunities(list)
    table.sort(list, function(a, b)
        if (a.priority or 0) == (b.priority or 0) then
            return tostring(a.title) < tostring(b.title)
        end
        return (a.priority or 0) > (b.priority or 0)
    end)
end

local function suggestionMetadata(opportunity)
    local metadata = {}
    local fields = { "dedupeKey", "goalID", "routeID", "challengeID", "questID", "professionID", "nodeID" }
    local hasValue = false
    for _, field in ipairs(fields) do
        if opportunity[field] ~= nil then
            metadata[field] = opportunity[field]
            hasValue = true
        end
    end
    return hasValue and metadata or nil
end

local function submitSuggestions(list)
    FC.Suggestions:ClearSource(SOURCE)
    for index = 1, math.min(4, #list) do
        local opportunity = list[index]
        FC.Suggestions:Add({
            id = "journey_" .. tostring(opportunity.id),
            source = SOURCE,
            category = opportunity.kind or "Journey",
            priority = tonumber(opportunity.priority) or 40,
            title = opportunity.title,
            description = opportunity.description,
            metadata = suggestionMetadata(opportunity),
        })
    end
end

function Journey:GetSnapshot()
    return self.snapshot
end

function Journey:Scan(reason)
    local mode = FC.DB and FC.DB.settings and FC.DB.settings.discoveryMode or "BALANCED"
    local questSnapshot = FC.API:GetJourneyQuestSnapshot()
    local opportunities = {}

    collectPinnedGoals(opportunities)
    collectQuestOpportunities(questSnapshot, mode, opportunities)
    collectTravelOpportunities(mode, opportunities)
    collectProfessionOpportunities(opportunities)
    collectLegacyOpportunities(mode, opportunities)
    collectCampOpportunities(opportunities)
    sortOpportunities(opportunities)

    self.snapshot = {
        mode = mode,
        quests = questSnapshot,
        opportunities = opportunities,
        scannedAt = time and time() or 0,
        reason = reason or "manual",
    }
    submitSuggestions(opportunities)
    FC.Logger:Debug("JOURNEY", "Journey snapshot: quests=%d opportunities=%d mode=%s", questSnapshot and #(questSnapshot.quests or {}) or 0, #opportunities, mode)
end

function Journey:Refresh(reason)
    self:Scan(reason)
end

function Journey:OnEnable()
    self:Scan("enable")
    if FC.Dungeons and type(FC.Dungeons.Scan) == "function" then FC.Dungeons:Scan("journey-enabled") end
end

function Journey:OnDisable()
    FC.Suggestions:ClearSource(SOURCE)
    FC.Suggestions:ClearSource("Dungeons")
    self.snapshot = nil
    if FC.Dungeons then FC.Dungeons.snapshot = { entries = {} } end
end

function Journey:OnEvent(event)
    if event == "PLAYER_LOGIN"
        or event == "PLAYER_ENTERING_WORLD"
        or event == "QUEST_LOG_UPDATE"
        or event == "QUEST_ACCEPTED"
        or event == "QUEST_TURNED_IN"
        or event == "ZONE_CHANGED"
        or event == "ZONE_CHANGED_NEW_AREA"
        or event == "SKILL_LINES_CHANGED"
    then
        self:Scan(event)
        if FC.UI and FC.UI.RefreshJourneyView then FC.UI:RefreshJourneyView() end
    end
end

FC:RegisterModule("Journey", Journey)
