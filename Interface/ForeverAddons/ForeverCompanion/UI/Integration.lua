local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local function setText(fontString, text, color)
    if not fontString then return end
    color = color or Theme.colors.text
    fontString:SetText(text or "")
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local previousCreateMainFrame = UI.CreateMainFrame
function UI:CreateMainFrame(...)
    local frame = previousCreateMainFrame(self, ...)

    if frame.fcSettingsButton and frame.fcGroupsButton then
        frame.fcSettingsButton:ClearAllPoints()
        frame.fcSettingsButton:SetPoint("RIGHT", frame.fcGroupsButton, "LEFT", -8, 0)
    end

    local page = frame.pages and frame.pages.Journey
    if page and page.roadmapCard and page.roadmapCard.title then
        page.roadmapCard.title:SetText("Companion Status")
    end
    return frame
end

local previousRefreshDashboard = UI.RefreshDashboard
function UI:RefreshDashboard(...)
    previousRefreshDashboard(self, ...)
    local page = self.frame and self.frame.pages and self.frame.pages.Journey
    if not page then return end

    local legacy = FC.Legacy and FC.Legacy:GetSnapshot() or nil
    if legacy then
        setText(page.statusLines[1], string.format("✓  Legacy Challenges\n    %d / %d complete • %d remaining",
            tonumber(legacy.completed) or 0, tonumber(legacy.total) or 0, tonumber(legacy.remaining) or 0), Theme.colors.green)
    elseif FC.API.capabilities and FC.API.capabilities.legacy then
        setText(page.statusLines[1], "•  Legacy Challenges\n    Achievement API ready; challenge data not discovered yet.", Theme.colors.yellow)
    else
        setText(page.statusLines[1], "•  Legacy Challenges\n    Capability unavailable on this client.", Theme.colors.muted)
    end

    local travel = FC.Travel and FC.Travel:GetSnapshot() or nil
    local unknown = 0
    for _, node in ipairs(travel and travel.nodes or {}) do if node.isUndiscovered == true then unknown = unknown + 1 end end
    if travel then
        setText(page.statusLines[2], string.format("✓  Travel Companion\n    %d taxi node(s) visible • %d undiscovered", #(travel.nodes or {}), unknown), Theme.colors.green)
    elseif FC.API.capabilities and FC.API.capabilities.travel then
        setText(page.statusLines[2], "•  Travel Companion\n    Map capability ready; no taxi snapshot in this context.", Theme.colors.yellow)
    else
        setText(page.statusLines[2], "•  Travel Companion\n    Taxi/map capability unavailable.", Theme.colors.muted)
    end

    local journey = FC.Journey and FC.Journey:GetSnapshot() or nil
    if journey then
        setText(page.statusLines[3], string.format("✓  Journey Engine\n    %d contextual opportunity(s) in %s mode", #(journey.opportunities or {}), tostring(journey.mode or "BALANCED")), Theme.colors.green)
    else
        setText(page.statusLines[3], "•  Journey Engine\n    Waiting for map/quest context.", Theme.colors.muted)
    end

    local camp = FC.Camps and FC.Camps:GetSnapshot() or nil
    if camp then
        setText(page.statusLines[4], string.format("✓  Camp Companion\n    Benefits: %s • %d contribution option(s)", camp.benefit and "active" or "not detected", #(camp.contributions or {})), Theme.colors.green)
    elseif FC.API.capabilities and FC.API.capabilities.camps then
        setText(page.statusLines[4], "•  Camp Companion\n    Aura capability ready; no snapshot yet.", Theme.colors.yellow)
    else
        setText(page.statusLines[4], "•  Camp Companion\n    Required public aura capability unavailable.", Theme.colors.muted)
    end

    local storage = FC.API.capabilities and FC.API.capabilities.storage
    setText(page.statusLines[5], storage
        and "✓  Account Storage\n    Character/account bank tabs are cacheable while bank UI is accessible."
        or "•  Account Storage\n    Bank API unavailable; bag cache remains active.", storage and Theme.colors.green or Theme.colors.muted)

    local roadmap = {
        "✓ Camps — benefits, rested XP, contribution/blueprint awareness",
        "✓ Travel — taxi discovery, account cache, group rendezvous helper",
        "✓ Journey — quests, dungeons, professions, Legacy, Camps, Travel, Pins",
        "✓ Item Intelligence / Goals / Groups / Milestones / Profession Planner",
        "Pending validation: real Forever runtime + deeper fixed transport datasets",
    }
    for i = 1, #page.roadmapLines do
        setText(page.roadmapLines[i], roadmap[i] or "", i <= 4 and Theme.colors.green or Theme.colors.gold)
    end
end
