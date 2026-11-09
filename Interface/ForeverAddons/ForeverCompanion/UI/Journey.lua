local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local function setText(fontString, text, color)
    if not fontString then return end
    color = color or Theme.colors.text
    fontString:SetText(text or "")
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

function UI:CreateJourneyFrame()
    if self.journeyFrame then return self.journeyFrame end

    local frame = Theme:CreatePanel(UIParent, Theme.colors.navy, Theme.colors.gold)
    frame:SetSize(850, 620)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    frame.title = Theme:CreateText(frame, "GameFontNormalHuge", "JOURNEY COMPANION")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -18)
    frame.title:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])

    frame.closeButton = Theme:CreateButton(frame, "X", 32, 30)
    frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -14)
    frame.closeButton:SetScript("OnClick", function() frame:Hide() end)

    frame.refreshButton = Theme:CreateButton(frame, "Refresh", 90, 30)
    frame.refreshButton:SetPoint("RIGHT", frame.closeButton, "LEFT", -8, 0)
    frame.refreshButton:SetScript("OnClick", function()
        FC:RefreshModules("journey-window")
        UI:RefreshJourneyView()
    end)

    frame.summary = Theme:CreateText(frame, "GameFontHighlight", "")
    frame.summary:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -62)
    frame.summary:SetWidth(806)
    frame.summary:SetJustifyH("LEFT")

    frame.opportunityTitle = Theme:CreateSectionTitle(frame, "Useful Things You Can Do Now")
    frame.opportunityTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -104)

    frame.opportunityLines = {}
    for i = 1, 10 do
        local line = Theme:CreateText(frame, "GameFontHighlightSmall", "")
        line:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -136 - ((i - 1) * 43))
        line:SetWidth(500)
        line:SetJustifyH("LEFT")
        line:SetJustifyV("TOP")
        frame.opportunityLines[i] = line
    end

    frame.questTitle = Theme:CreateSectionTitle(frame, "Visible Quest Context")
    frame.questTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 548, -104)

    frame.questLines = {}
    for i = 1, 9 do
        local line = Theme:CreateText(frame, "GameFontHighlightSmall", "")
        line:SetPoint("TOPLEFT", frame, "TOPLEFT", 550, -136 - ((i - 1) * 42))
        line:SetWidth(276)
        line:SetJustifyH("LEFT")
        line:SetJustifyV("TOP")
        frame.questLines[i] = line
    end

    frame.note = Theme:CreateText(frame, "GameFontDisableSmall",
        "Journey is advisory only. It does not accept quests, set protected objectives, move your character or force a leveling route. Suggestions are intentionally filtered by your Discovery Mode.")
    frame.note:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 18)
    frame.note:SetWidth(806)
    frame.note:SetJustifyH("LEFT")

    self.journeyFrame = frame
    return frame
end

function UI:RefreshJourneyView()
    local frame = self.journeyFrame
    if not frame then return end

    local snapshot = FC.Journey and FC.Journey:GetSnapshot() or nil
    if not snapshot then
        setText(frame.summary, "Journey context has not been scanned yet.", Theme.colors.muted)
        return
    end

    local questCount = snapshot.quests and #(snapshot.quests.quests or {}) or 0
    setText(frame.summary, string.format("Discovery Mode: %s  •  %d contextual opportunity(s)  •  %d visible quest POI(s)",
        tostring(snapshot.mode or "BALANCED"), #(snapshot.opportunities or {}), questCount), Theme.colors.text)

    for i = 1, #frame.opportunityLines do
        local opportunity = snapshot.opportunities and snapshot.opportunities[i]
        if opportunity then
            local prefix = tostring(opportunity.kind or "Journey")
            local color = (opportunity.priority or 0) >= 65 and Theme.colors.gold
                or ((opportunity.priority or 0) >= 50 and Theme.colors.yellow or Theme.colors.text)
            setText(frame.opportunityLines[i], string.format("[%s] %s\n   %s", prefix, tostring(opportunity.title), tostring(opportunity.description or "")), color)
        elseif i == 1 then
            setText(frame.opportunityLines[i], "No contextual opportunity is currently available.", Theme.colors.green)
        else
            setText(frame.opportunityLines[i], "")
        end
    end

    local mode = snapshot.mode or "BALANCED"
    local quests = snapshot.quests and snapshot.quests.quests or {}
    for i = 1, #frame.questLines do
        local quest = quests[i]
        if quest then
            local title = quest.title or ("Quest " .. tostring(quest.questID))
            if mode == "EXPLORER" and not quest.inProgress then
                title = "Nearby quest opportunity"
            end
            local progress = quest.objectiveCount and quest.objectiveCount > 0
                and string.format("%d/%d objectives", tonumber(quest.completedObjectives) or 0, tonumber(quest.objectiveCount) or 0)
                or (quest.inProgress and "In progress" or "Available")
            local coords = mode == "GUIDE" and quest.x and quest.y
                and string.format(" • %.1f, %.1f", quest.x * 100, quest.y * 100) or ""
            setText(frame.questLines[i], string.format("%s\n   %s%s", tostring(title), progress, coords), quest.inProgress and Theme.colors.green or Theme.colors.muted)
        elseif i == 1 then
            setText(frame.questLines[i], "No quest POIs exposed on this map.", Theme.colors.muted)
        else
            setText(frame.questLines[i], "")
        end
    end
end

function UI:ShowJourney()
    local frame = self:CreateJourneyFrame()
    if FC.Journey then FC.Journey:Refresh("journey-window-open") end
    self:RefreshJourneyView()
    frame:Show()
end

local previousCreateMainFrame = UI.CreateMainFrame
function UI:CreateMainFrame(...)
    local frame = previousCreateMainFrame(self, ...)
    if frame and not frame.fcJourneyButton and frame.pages and frame.pages.Journey and frame.pages.Journey.roadmapCard then
        local button = Theme:CreateButton(frame.pages.Journey.roadmapCard, "Open Journey Companion", 180, 30)
        button:SetPoint("BOTTOMRIGHT", frame.pages.Journey.roadmapCard, "BOTTOMRIGHT", -14, 12)
        button:SetScript("OnClick", function() UI:ShowJourney() end)
        frame.fcJourneyButton = button
    end
    return frame
end
