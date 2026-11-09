local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local function setText(fontString, text, color)
    if not fontString then return end
    color = color or Theme.colors.text
    fontString:SetText(text or "")
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function formatCoords(x, y)
    if not x or not y then return nil end
    return string.format("%.1f, %.1f", x * 100, y * 100)
end

function UI:CreateTravelFrame()
    if self.travelFrame then return self.travelFrame end

    local frame = Theme:CreatePanel(UIParent, Theme.colors.navy, Theme.colors.gold)
    frame:SetSize(840, 610)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    frame.title = Theme:CreateText(frame, "GameFontNormalHuge", "TRAVEL COMPANION")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -18)
    frame.title:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])

    frame.closeButton = Theme:CreateButton(frame, "X", 32, 30)
    frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -14)
    frame.closeButton:SetScript("OnClick", function() frame:Hide() end)

    frame.refreshButton = Theme:CreateButton(frame, "Refresh", 90, 30)
    frame.refreshButton:SetPoint("RIGHT", frame.closeButton, "LEFT", -8, 0)
    frame.refreshButton:SetScript("OnClick", function()
        if FC.Travel then FC.Travel:Refresh("travel-window") end
        UI:RefreshTravelView()
    end)

    frame.summary = Theme:CreateText(frame, "GameFontHighlight", "")
    frame.summary:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -62)
    frame.summary:SetWidth(796)
    frame.summary:SetJustifyH("LEFT")

    frame.flightTitle = Theme:CreateSectionTitle(frame, "Flight Points")
    frame.flightTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -104)

    frame.flightLines = {}
    for i = 1, 11 do
        local line = Theme:CreateText(frame, "GameFontHighlightSmall", "")
        line:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -136 - ((i - 1) * 36))
        line:SetWidth(390)
        line:SetJustifyH("LEFT")
        line:SetJustifyV("TOP")
        frame.flightLines[i] = line
    end

    frame.groupTitle = Theme:CreateSectionTitle(frame, "Group Travel Overview")
    frame.groupTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 438, -104)

    frame.groupLines = {}
    for i = 1, 9 do
        local line = Theme:CreateText(frame, "GameFontHighlightSmall", "")
        line:SetPoint("TOPLEFT", frame, "TOPLEFT", 440, -136 - ((i - 1) * 40))
        line:SetWidth(372)
        line:SetJustifyH("LEFT")
        line:SetJustifyV("TOP")
        frame.groupLines[i] = line
    end

    frame.cacheTitle = Theme:CreateSectionTitle(frame, "Account Travel Cache")
    frame.cacheTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 438, -480)
    frame.cacheText = Theme:CreateText(frame, "GameFontHighlightSmall", "")
    frame.cacheText:SetPoint("TOPLEFT", frame.cacheTitle, "BOTTOMLEFT", 2, -12)
    frame.cacheText:SetWidth(372)
    frame.cacheText:SetJustifyH("LEFT")

    frame.note = Theme:CreateText(frame, "GameFontDisableSmall",
        "Forever Companion only reports public map/taxi data. It never starts travel, clicks taxi nodes, sets protected routes or automates movement.")
    frame.note:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 18)
    frame.note:SetWidth(796)
    frame.note:SetJustifyH("LEFT")

    self.travelFrame = frame
    return frame
end

function UI:RefreshTravelView()
    local frame = self.travelFrame
    if not frame then return end

    local snapshot = FC.Travel and FC.Travel:GetSnapshot() or nil
    local mode = FC.DB and FC.DB.settings and FC.DB.settings.discoveryMode or "BALANCED"
    if not snapshot then
        setText(frame.summary, "Travel data is not available in the current map context.", Theme.colors.muted)
        for _, line in ipairs(frame.flightLines) do setText(line, "") end
    else
        local player = snapshot.player or {}
        local mapName = player.mapName or player.name or ("Map " .. tostring(player.mapID or "?"))
        local coords = formatCoords(player.x, player.y)
        setText(frame.summary, string.format("Current map: %s%s  •  Discovery mode: %s",
            tostring(mapName), coords and (" @ " .. coords) or "", tostring(mode)), Theme.colors.text)

        local shown = 0
        for _, node in ipairs(snapshot.nodes or {}) do
            if shown >= #frame.flightLines then break end
            shown = shown + 1
            local status = node.isUndiscovered == true and "UNKNOWN" or "KNOWN"
            local label = node.name or ("Flight point " .. tostring(node.nodeID))
            local detail = ""
            if mode == "GUIDE" then
                local nodeCoords = formatCoords(node.x, node.y)
                if nodeCoords then detail = " @ " .. nodeCoords end
            elseif mode == "EXPLORER" and node.isUndiscovered == true then
                label = "Undiscovered flight point"
            end
            setText(frame.flightLines[shown], string.format("%s  %s%s", status == "UNKNOWN" and "?" or "✓", tostring(label), detail),
                status == "UNKNOWN" and Theme.colors.yellow or Theme.colors.muted)
        end
        for i = shown + 1, #frame.flightLines do setText(frame.flightLines[i], "") end
        if shown == 0 then setText(frame.flightLines[1], "No taxi nodes were exposed for the current map hierarchy.", Theme.colors.muted) end
    end

    local group = FC.Travel and FC.Travel:GetGroupSnapshot() or {}
    for i = 1, #frame.groupLines do
        local member = group[i]
        if member then
            local mapLabel = member.mapName or ("Map " .. tostring(member.mapID or "?"))
            local coords = mode == "GUIDE" and formatCoords(member.x, member.y) or nil
            setText(frame.groupLines[i], string.format("%s\n   %s%s", tostring(member.playerName or member.unit or "Member"), tostring(mapLabel), coords and (" @ " .. coords) or ""), Theme.colors.text)
        elseif i == 1 then
            setText(frame.groupLines[i], "No group travel context is currently available.", Theme.colors.muted)
        else
            setText(frame.groupLines[i], "")
        end
    end

    local count = 0
    local discovered = 0
    for _, node in pairs(FC.DB and FC.DB.account and FC.DB.account.flightPoints or {}) do
        count = count + 1
        if next(node.discoveredBy or {}) then discovered = discovered + 1 end
    end
    setText(frame.cacheText, string.format("%d flight-point record(s) cached across scanned characters; %d have been seen as discovered by at least one character.", count, discovered), Theme.colors.muted)
end

function UI:ShowTravel()
    local frame = self:CreateTravelFrame()
    if FC.Travel then FC.Travel:Refresh("travel-window-open") end
    self:RefreshTravelView()
    frame:Show()
end

local previousCreateMainFrame = UI.CreateMainFrame
function UI:CreateMainFrame(...)
    local frame = previousCreateMainFrame(self, ...)
    if frame and not frame.fcTravelButton and frame.pages and frame.pages.Journey and frame.pages.Journey.roadmapCard then
        local button = Theme:CreateButton(frame.pages.Journey.roadmapCard, "Open Travel Companion", 180, 30)
        button:SetPoint("BOTTOMLEFT", frame.pages.Journey.roadmapCard, "BOTTOMLEFT", 14, 12)
        button:SetScript("OnClick", function() UI:ShowTravel() end)
        frame.fcTravelButton = button
    end
    return frame
end
