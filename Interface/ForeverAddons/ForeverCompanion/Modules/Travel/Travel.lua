local _, FC = ...

local Travel = {}
FC.Travel = Travel

local SOURCE = "Travel"

local function getStore()
    if not FC.DB or not FC.DB.account then return nil end
    FC.DB.account.flightPoints = FC.DB.account.flightPoints or {}
    return FC.DB.account.flightPoints
end

local function normalizeLocation(value)
    return string.lower(tostring(value or ""))
        :gsub("[%p%c]", " ")
        :gsub("%s+", " ")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
end

local function factionAllowsNode(nodeFaction, playerFaction)
    if nodeFaction == nil or nodeFaction == 0 then return true end
    if playerFaction == "Alliance" then return nodeFaction == 2 end
    if playerFaction == "Horde" then return nodeFaction == 1 end
    return true
end

local function cacheNodes(snapshot, character)
    local store = getStore()
    if not store then return end

    for _, node in ipairs(snapshot and snapshot.nodes or {}) do
        if factionAllowsNode(node.faction, character and character.faction) then
            local cached = store[node.nodeID] or { nodeID = node.nodeID, discoveredBy = {} }
            cached.name = node.name or cached.name
            cached.mapID = node.mapID or cached.mapID
            cached.x = node.x or cached.x
            cached.y = node.y or cached.y
            cached.faction = node.faction
            cached.lastSeen = time and time() or 0
            cached.discoveredBy = cached.discoveredBy or {}
            if node.isUndiscovered == false then cached.discoveredBy[character.key or FC:GetCharacterKey()] = true end
            store[node.nodeID] = cached
        end
    end
end

local function findMeetingAnchor(group)
    local byMap = {}
    for _, member in ipairs(group or {}) do
        if member.mapID and member.x and member.y then
            byMap[member.mapID] = byMap[member.mapID] or {}
            byMap[member.mapID][#byMap[member.mapID] + 1] = member
        end
    end

    local bestMapMembers
    for _, members in pairs(byMap) do
        if #members >= 2 and (not bestMapMembers or #members > #bestMapMembers) then bestMapMembers = members end
    end
    if not bestMapMembers then return nil end

    local bestMember
    local bestScore
    for _, candidate in ipairs(bestMapMembers) do
        local score = 0
        for _, other in ipairs(bestMapMembers) do
            local dx = candidate.x - other.x
            local dy = candidate.y - other.y
            score = score + (dx * dx) + (dy * dy)
        end
        if not bestScore or score < bestScore then bestScore, bestMember = score, candidate end
    end

    if not bestMember then return nil end
    return {
        mapID = bestMember.mapID,
        mapName = bestMember.mapName,
        x = bestMember.x,
        y = bestMember.y,
        anchorName = bestMember.playerName,
        memberCount = #bestMapMembers,
    }
end

local function routeMatchesCurrentContext(route, snapshot)
    local player = snapshot and snapshot.player
    if not route or not player then return false end

    local metadata = type(route.metadata) == "table" and route.metadata or {}
    local originMapID = tonumber(metadata.originMapID or metadata.mapID)
    if originMapID and tonumber(player.mapID) == originMapID then return true end

    local origin = normalizeLocation(route.origin)
    local mapName = normalizeLocation(player.mapName)
    if origin == "" or mapName == "" then return false end
    if origin == mapName then return true end

    if #origin >= 5 and #mapName >= 5 then
        if string.find(origin, mapName, 1, true) or string.find(mapName, origin, 1, true) then
            return true
        end
    end
    return false
end

local function findRelevantRoutes(snapshot)
    local result = {}
    if not snapshot or not FC.TravelRoutes or not FC:IsModuleEnabled("TravelRoutes") then return result end

    for _, route in ipairs(FC.TravelRoutes:GetAllRoutes(false) or {}) do
        if routeMatchesCurrentContext(route, snapshot) then
            result[#result + 1] = route
        end
    end

    table.sort(result, function(a, b)
        if tostring(a.routeType) == tostring(b.routeType) then return tostring(a.name) < tostring(b.name) end
        return tostring(a.routeType) < tostring(b.routeType)
    end)
    return result
end

local function addSuggestions(snapshot, character, meetingPoint, relevantRoutes)
    FC.Suggestions:ClearSource(SOURCE)
    local mode = FC.DB and FC.DB.settings and FC.DB.settings.discoveryMode or "BALANCED"

    if snapshot then
        local undiscovered = {}
        for _, node in ipairs(snapshot.nodes or {}) do
            if node.isUndiscovered == true and factionAllowsNode(node.faction, character and character.faction) then undiscovered[#undiscovered + 1] = node end
        end

        if #undiscovered > 0 then
            local first = undiscovered[1]
            local description
            if mode == "EXPLORER" then
                description = FC:GetText("SUGG_TRAVEL_FLIGHT_EXPLORER_DESC", #undiscovered)
            elseif mode == "GUIDE" and first.x and first.y then
                description = FC:GetText("SUGG_TRAVEL_FLIGHT_GUIDE_DESC", tostring(first.name or FC:GetText("SUGG_TRAVEL_UNKNOWN_FLIGHT")), first.x * 100, first.y * 100)
            else
                description = FC:GetText("SUGG_TRAVEL_FLIGHT_BALANCED_DESC", tostring(first.name or FC:GetText("SUGG_TRAVEL_AN_UNDISCOVERED_FLIGHT")))
            end

            FC.Suggestions:Add({
                id = "travel_unknown_flight_point",
                source = SOURCE,
                category = "Travel",
                priority = 46,
                title = FC:GetText("SUGG_TRAVEL_FLIGHT_TITLE"),
                description = description,
                metadata = {
                    dedupeKey = mode == "EXPLORER" and "travel-undiscovered-flight" or "travel-undiscovered-summary",
                },
            })
        end
    end

    if meetingPoint then
        local description = FC:GetText("SUGG_TRAVEL_MEETING_DESC", meetingPoint.memberCount, tostring(meetingPoint.mapName or FC:GetText("SUGG_TRAVEL_SAME_MAP")), tostring(meetingPoint.anchorName or FC:GetText("SUGG_TRAVEL_CENTRAL_MEMBER")))
        if mode == "GUIDE" and meetingPoint.x and meetingPoint.y then
            description = description .. FC:GetText("SUGG_TRAVEL_ANCHOR_DESC", meetingPoint.x * 100, meetingPoint.y * 100)
        end
        FC.Suggestions:Add({
            id = "travel_group_meeting_anchor",
            source = SOURCE,
            category = "Travel",
            priority = 35,
            title = FC:GetText("SUGG_TRAVEL_MEETING_TITLE"),
            description = description,
        })
    end

    for index = 1, math.min(2, #(relevantRoutes or {})) do
        local route = relevantRoutes[index]
        local description
        if mode == "EXPLORER" then
            description = FC:GetText("SUGG_TRAVEL_ROUTE_EXPLORER_DESC")
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

        FC.Suggestions:Add({
            id = "travel_route_" .. tostring(route.id or index),
            source = SOURCE,
            category = "Travel",
            priority = route.source and string.find(tostring(route.source), "Provider:", 1, true) and 43 or 40,
            title = FC:GetText("SUGG_TRAVEL_ROUTE_TITLE", tostring(route.name or FC:GetText("SUGG_TRAVEL_SAVED_ROUTE"))),
            description = description,
            metadata = {
                routeID = route.id,
                routeType = route.routeType,
                routeSource = route.source,
            },
        })
    end
end

function Travel:GetSnapshot()
    local character = FC:GetCurrentCharacter()
    return character and character.travelSnapshot or nil
end

function Travel:GetGroupSnapshot() return self.groupSnapshot or {} end
function Travel:GetMeetingPoint() return self.meetingPoint end
function Travel:GetRelevantRoutes() return self.relevantRoutes or {} end

function Travel:Scan(reason)
    local character = FC:GetCurrentCharacter()
    if not character then return end

    local snapshot = FC.API:GetTaxiSnapshot()
    if snapshot then
        snapshot.reason = reason or "manual"
        character.travelSnapshot = snapshot
        cacheNodes(snapshot, character)
    end

    self.groupSnapshot = FC.API:GetGroupTravelSnapshot()
    self.meetingPoint = findMeetingAnchor(self.groupSnapshot)
    self.relevantRoutes = findRelevantRoutes(snapshot or character.travelSnapshot)
    addSuggestions(snapshot or character.travelSnapshot, character, self.meetingPoint, self.relevantRoutes)
    FC.Logger:Debug("TRAVEL", "Travel snapshot: nodes=%d group=%d meeting=%s routes=%d",
        snapshot and #(snapshot.nodes or {}) or 0,
        #(self.groupSnapshot or {}),
        self.meetingPoint and "yes" or "no",
        #(self.relevantRoutes or {}))
end

function Travel:Refresh(reason) self:Scan(reason) end

function Travel:OnEvent(event)
    if event == "PLAYER_LOGIN"
        or event == "PLAYER_ENTERING_WORLD"
        or event == "ZONE_CHANGED"
        or event == "ZONE_CHANGED_NEW_AREA"
        or event == "TAXIMAP_OPENED"
        or event == "GROUP_ROSTER_UPDATE"
    then
        self:Scan(event)
        if FC.UI and FC.UI.RefreshTravelView then FC.UI:RefreshTravelView() end
    end
end

FC:RegisterModule("Travel", Travel)
