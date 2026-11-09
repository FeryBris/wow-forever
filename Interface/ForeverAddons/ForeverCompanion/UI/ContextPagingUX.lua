local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local TRAVEL_FLIGHT_PAGE_SIZE = 11
local TRAVEL_GROUP_PAGE_SIZE = 9
local JOURNEY_OPPORTUNITY_PAGE_SIZE = 10
local JOURNEY_QUEST_PAGE_SIZE = 9
local GROUP_MEMBER_PAGE_SIZE = 10

local JOURNEY_KIND_KEYS = {
    Quest = "JOURNEY_KIND_QUEST",
    Travel = "JOURNEY_KIND_TRAVEL",
    Profession = "JOURNEY_KIND_PROFESSION",
    Legacy = "JOURNEY_KIND_LEGACY",
    Camp = "JOURNEY_KIND_CAMP",
    Goal = "JOURNEY_KIND_GOAL",
}

local function setText(fontString, text, color)
    if not fontString then return end
    color = color or Theme.colors.text
    fontString:SetText(text or "")
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function t(key, ...)
    return FC:GetText(key, ...)
end

local function journeyKindText(kind)
    local key = JOURNEY_KIND_KEYS[tostring(kind or "")]
    return key and t(key) or t("JOURNEY_KIND_FALLBACK")
end

local function formatCoords(x, y)
    if not x or not y then return nil end
    return string.format("%.1f, %.1f", x * 100, y * 100)
end

local function clampPage(frame, field, count, pageSize)
    local maxPage = math.max(1, math.ceil(count / pageSize))
    frame[field] = math.max(1, math.min(tonumber(frame[field]) or 1, maxPage))
    return frame[field], maxPage, ((frame[field] - 1) * pageSize) + 1
end

local function createSectionPager(frame, prefix, anchor, offsetX)
    local nextButton = Theme:CreateButton(frame, ">", 28, 24)
    nextButton:SetPoint("RIGHT", anchor, "RIGHT", offsetX or 0, 0)
    local prevButton = Theme:CreateButton(frame, "<", 28, 24)
    prevButton:SetPoint("RIGHT", nextButton, "LEFT", -4, 0)
    local pageText = Theme:CreateText(frame, "GameFontDisableSmall", "")
    pageText:SetPoint("RIGHT", prevButton, "LEFT", -6, 0)
    pageText:SetWidth(55)
    pageText:SetJustifyH("RIGHT")
    frame[prefix .. "Prev"] = prevButton
    frame[prefix .. "Next"] = nextButton
    frame[prefix .. "PageText"] = pageText
end

local function updatePager(frame, prefix, page, maxPage)
    local prevButton = frame[prefix .. "Prev"]
    local nextButton = frame[prefix .. "Next"]
    local pageText = frame[prefix .. "PageText"]
    if prevButton then
        prevButton:SetEnabled(page > 1)
        prevButton:SetAlpha(page > 1 and 1 or 0.4)
    end
    if nextButton then
        nextButton:SetEnabled(page < maxPage)
        nextButton:SetAlpha(page < maxPage and 1 or 0.4)
    end
    if pageText then pageText:SetText(string.format("%d/%d", page, maxPage)) end
end

-- Travel --------------------------------------------------------------------
local previousCreateTravelFrame = UI.CreateTravelFrame
function UI:CreateTravelFrame(...)
    local frame = previousCreateTravelFrame(self, ...)
    if not frame or frame.fcContextPaging then return frame end
    frame.fcContextPaging = true
    frame.flightPage = 1
    frame.travelGroupPage = 1

    createSectionPager(frame, "flight", frame.flightTitle, 365)
    createSectionPager(frame, "travelGroup", frame.groupTitle, 350)

    frame.flightPrev:SetScript("OnClick", function()
        frame.flightPage = math.max(1, (frame.flightPage or 1) - 1)
        UI:RefreshTravelView()
    end)
    frame.flightNext:SetScript("OnClick", function()
        frame.flightPage = (frame.flightPage or 1) + 1
        UI:RefreshTravelView()
    end)
    frame.travelGroupPrev:SetScript("OnClick", function()
        frame.travelGroupPage = math.max(1, (frame.travelGroupPage or 1) - 1)
        UI:RefreshTravelView()
    end)
    frame.travelGroupNext:SetScript("OnClick", function()
        frame.travelGroupPage = (frame.travelGroupPage or 1) + 1
        UI:RefreshTravelView()
    end)
    return frame
end

local previousRefreshTravelView = UI.RefreshTravelView
function UI:RefreshTravelView(...)
    previousRefreshTravelView(self, ...)
    local frame = self.travelFrame
    if not frame or not frame.fcContextPaging then return end

    local snapshot = FC.Travel and FC.Travel:GetSnapshot() or nil
    local mode = FC.DB and FC.DB.settings and FC.DB.settings.discoveryMode or "BALANCED"
    local nodes = snapshot and snapshot.nodes or {}
    local flightPage, flightMax, flightStart = clampPage(frame, "flightPage", #nodes, TRAVEL_FLIGHT_PAGE_SIZE)

    for i = 1, #frame.flightLines do
        local node = nodes[flightStart + i - 1]
        if node then
            local unknown = node.isUndiscovered == true
            local label = node.name or t("TRAVEL_FLIGHT_POINT_FALLBACK", tostring(node.nodeID))
            local detail = ""
            if mode == "GUIDE" then
                local coords = formatCoords(node.x, node.y)
                if coords then detail = " @ " .. coords end
            elseif mode == "EXPLORER" and unknown then
                label = t("TRAVEL_UNDISCOVERED_FLIGHT_POINT")
            end
            setText(frame.flightLines[i], string.format("%s  %s%s", unknown and "?" or "✓", tostring(label), detail),
                unknown and Theme.colors.yellow or Theme.colors.muted)
        elseif i == 1 and #nodes == 0 then
            setText(frame.flightLines[i], t("TRAVEL_NO_TAXI_NODES"), Theme.colors.muted)
        else
            setText(frame.flightLines[i], "")
        end
    end
    updatePager(frame, "flight", flightPage, flightMax)

    local group = FC.Travel and FC.Travel:GetGroupSnapshot() or {}
    local groupPage, groupMax, groupStart = clampPage(frame, "travelGroupPage", #group, TRAVEL_GROUP_PAGE_SIZE)
    for i = 1, #frame.groupLines do
        local member = group[groupStart + i - 1]
        if member then
            local mapLabel = member.mapName or t("MAP_FALLBACK", tostring(member.mapID or "?"))
            local coords = mode == "GUIDE" and formatCoords(member.x, member.y) or nil
            setText(frame.groupLines[i], string.format("%s\n   %s%s", tostring(member.playerName or member.unit or t("MEMBER_FALLBACK")), tostring(mapLabel), coords and (" @ " .. coords) or ""), Theme.colors.text)
        elseif i == 1 and #group == 0 then
            setText(frame.groupLines[i], t("TRAVEL_NO_GROUP_CONTEXT"), Theme.colors.muted)
        else
            setText(frame.groupLines[i], "")
        end
    end
    updatePager(frame, "travelGroup", groupPage, groupMax)
end

-- Journey -------------------------------------------------------------------
local previousCreateJourneyFrame = UI.CreateJourneyFrame
function UI:CreateJourneyFrame(...)
    local frame = previousCreateJourneyFrame(self, ...)
    if not frame or frame.fcContextPaging then return frame end
    frame.fcContextPaging = true
    frame.opportunityPage = 1
    frame.questPage = 1

    createSectionPager(frame, "opportunity", frame.opportunityTitle, 480)
    createSectionPager(frame, "quest", frame.questTitle, 255)

    frame.opportunityPrev:SetScript("OnClick", function()
        frame.opportunityPage = math.max(1, (frame.opportunityPage or 1) - 1)
        UI:RefreshJourneyView()
    end)
    frame.opportunityNext:SetScript("OnClick", function()
        frame.opportunityPage = (frame.opportunityPage or 1) + 1
        UI:RefreshJourneyView()
    end)
    frame.questPrev:SetScript("OnClick", function()
        frame.questPage = math.max(1, (frame.questPage or 1) - 1)
        UI:RefreshJourneyView()
    end)
    frame.questNext:SetScript("OnClick", function()
        frame.questPage = (frame.questPage or 1) + 1
        UI:RefreshJourneyView()
    end)
    return frame
end

local previousRefreshJourneyView = UI.RefreshJourneyView
function UI:RefreshJourneyView(...)
    previousRefreshJourneyView(self, ...)
    local frame = self.journeyFrame
    if not frame or not frame.fcContextPaging then return end
    local snapshot = FC.Journey and FC.Journey:GetSnapshot() or nil
    if not snapshot then return end

    local opportunities = snapshot.opportunities or {}
    local opportunityPage, opportunityMax, opportunityStart = clampPage(frame, "opportunityPage", #opportunities, JOURNEY_OPPORTUNITY_PAGE_SIZE)
    for i = 1, #frame.opportunityLines do
        local opportunity = opportunities[opportunityStart + i - 1]
        if opportunity then
            local prefix = journeyKindText(opportunity.kind)
            local color = (opportunity.priority or 0) >= 65 and Theme.colors.gold
                or ((opportunity.priority or 0) >= 50 and Theme.colors.yellow or Theme.colors.text)
            setText(frame.opportunityLines[i], string.format("[%s] %s\n   %s", prefix, tostring(opportunity.title), tostring(opportunity.description or "")), color)
        elseif i == 1 and #opportunities == 0 then
            setText(frame.opportunityLines[i], t("JOURNEY_NO_CONTEXTUAL_OPPORTUNITY"), Theme.colors.green)
        else
            setText(frame.opportunityLines[i], "")
        end
    end
    updatePager(frame, "opportunity", opportunityPage, opportunityMax)

    local mode = snapshot.mode or "BALANCED"
    local quests = snapshot.quests and snapshot.quests.quests or {}
    local questPage, questMax, questStart = clampPage(frame, "questPage", #quests, JOURNEY_QUEST_PAGE_SIZE)
    for i = 1, #frame.questLines do
        local quest = quests[questStart + i - 1]
        if quest then
            local title = quest.title or t("JOURNEY_QUEST_FALLBACK", tostring(quest.questID))
            if mode == "EXPLORER" and not quest.inProgress then title = t("JOURNEY_NEARBY_QUEST") end
            local progress = quest.objectiveCount and quest.objectiveCount > 0
                and t("JOURNEY_OBJECTIVE_PROGRESS", tonumber(quest.completedObjectives) or 0, tonumber(quest.objectiveCount) or 0)
                or (quest.inProgress and t("JOURNEY_IN_PROGRESS") or t("JOURNEY_AVAILABLE"))
            local coords = mode == "GUIDE" and quest.x and quest.y
                and string.format(" • %.1f, %.1f", quest.x * 100, quest.y * 100) or ""
            setText(frame.questLines[i], string.format("%s\n   %s%s", tostring(title), progress, coords), quest.inProgress and Theme.colors.green or Theme.colors.muted)
        elseif i == 1 and #quests == 0 then
            setText(frame.questLines[i], t("JOURNEY_NO_QUEST_POIS"), Theme.colors.muted)
        else
            setText(frame.questLines[i], "")
        end
    end
    updatePager(frame, "quest", questPage, questMax)
end

-- Group preparation ---------------------------------------------------------
local previousCreateGroupsFrame = UI.CreateGroupsFrame
function UI:CreateGroupsFrame(...)
    local frame = previousCreateGroupsFrame(self, ...)
    if not frame or frame.fcContextPaging then return frame end
    frame.fcContextPaging = true
    frame.memberPage = 1

    createSectionPager(frame, "member", frame.memberTitle, 405)
    frame.memberPrev:SetScript("OnClick", function()
        frame.memberPage = math.max(1, (frame.memberPage or 1) - 1)
        UI:RefreshGroupsView()
    end)
    frame.memberNext:SetScript("OnClick", function()
        frame.memberPage = (frame.memberPage or 1) + 1
        UI:RefreshGroupsView()
    end)
    return frame
end

local previousRefreshGroupsView = UI.RefreshGroupsView
function UI:RefreshGroupsView(...)
    previousRefreshGroupsView(self, ...)
    local frame = self.groupsFrame
    if not frame or not frame.fcContextPaging then return end
    local snapshot = FC.Groups and FC.Groups:GetSnapshot() or nil
    local members = snapshot and snapshot.members or {}
    local page, maxPage, startIndex = clampPage(frame, "memberPage", #members, GROUP_MEMBER_PAGE_SIZE)

    for i = 1, #frame.memberLines do
        local member = members[startIndex + i - 1]
        if member then
            local state = not member.connected and t("GROUP_OFFLINE") or (member.deadOrGhost and t("GROUP_DEAD_GHOST") or t("GROUP_READY_TO_TRAVEL"))
            local map = member.mapName or (member.mapID and t("MAP_FALLBACK", tostring(member.mapID)) or t("GROUP_MAP_UNAVAILABLE"))
            local memberLine = t("GROUP_MEMBER_LINE",
                tostring(member.name or t("MEMBER_FALLBACK")),
                tostring(member.level or "?"),
                tostring(member.className or ""))
            setText(frame.memberLines[i], string.format("%s\n   %s • %s", memberLine, map, state),
                member.connected and (member.deadOrGhost and Theme.colors.yellow or Theme.colors.text) or Theme.colors.red)
        else
            setText(frame.memberLines[i], "")
        end
    end
    updatePager(frame, "member", page, maxPage)
end
