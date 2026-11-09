local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local function discoveryModeLabel(mode)
    mode = tostring(mode or "BALANCED"):upper()
    if mode == "EXPLORER" then return FC:GetText("DISCOVERY_MODE_EXPLORER_SHORT") end
    if mode == "GUIDE" then return FC:GetText("DISCOVERY_MODE_GUIDE_SHORT") end
    return FC:GetText("DISCOVERY_MODE_BALANCED_SHORT")
end

local function createIndicator(parent, anchor, x, y)
    local indicator = Theme:CreateStatusIndicator(parent, 13)
    indicator:SetPoint("TOPLEFT", anchor, "TOPLEFT", x, y)
    return indicator
end

local function ensurePreparationIndicators(frame)
    local page = frame and frame.pages and frame.pages.Preparation
    if not page or page.fcStatusIndicators then return end
    page.fcStatusIndicators = {}

    for index, line in ipairs(page.checkLines or {}) do
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", page.checkCard, "TOPLEFT", 36, -54 - ((index - 1) * 48))
        line:SetWidth(384)
        page.fcStatusIndicators[index] = createIndicator(page.checkCard, page.checkCard, 15, -56 - ((index - 1) * 48))
    end
end

local function refreshPreparationIndicators(frame)
    local page = frame and frame.pages and frame.pages.Preparation
    if not page then return end
    ensurePreparationIndicators(frame)

    local character = FC:GetCurrentCharacter()
    local preparation = character and character.preparation or {}
    local caps = FC.API and FC.API.capabilities or {}
    local freeSlots = tonumber(preparation.freeBagSlots)
    local durability = tonumber(preparation.lowestDurability)
    local states = {
        freeSlots and (freeSlots <= 2 and "error" or (freeSlots <= 5 and "warn" or "ok")) or "warn",
        durability and (durability <= 25 and "error" or (durability <= 50 and "warn" or "ok")) or "ok",
        "ok",
        caps.containers and "ok" or "warn",
        caps.recipeSchematic and "ok" or "warn",
        "info",
        "info",
        "info",
    }

    for index, indicator in ipairs(page.fcStatusIndicators or {}) do
        indicator:SetState(states[index] or "info")
    end
end

local function ensureJourneyIndicators(frame)
    local page = frame and frame.pages and frame.pages.Journey
    if not page or page.fcStatusIndicators then return end
    page.fcStatusIndicators = {}

    for index, line in ipairs(page.statusLines or {}) do
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", page.statusCard, "TOPLEFT", 36, -50 - ((index - 1) * 38))
        line:SetWidth(384)
        page.fcStatusIndicators[index] = createIndicator(page.statusCard, page.statusCard, 15, -52 - ((index - 1) * 38))
    end
end

local function refreshJourneyIndicators(frame)
    local page = frame and frame.pages and frame.pages.Journey
    if not page then return end
    ensureJourneyIndicators(frame)

    local caps = FC.API and FC.API.capabilities or {}
    local journey = FC.Journey and FC.Journey:GetSnapshot() or nil
    local states = {
        FC.Legacy and FC.Legacy:GetSnapshot() and "ok" or (caps.legacy and "warn" or "info"),
        FC.Travel and FC.Travel:GetSnapshot() and "ok" or (caps.travel and "warn" or "info"),
        journey and "ok" or "warn",
        FC.Camps and FC.Camps:GetSnapshot() and "ok" or (caps.camps and "warn" or "info"),
        caps.storage and "ok" or "warn",
    }

    for index, indicator in ipairs(page.fcStatusIndicators or {}) do
        if index <= #states then
            indicator:SetState(states[index])
            indicator:Show()
        else
            indicator:Hide()
        end
    end

    -- Keep internal enum names (EXPLORER/BALANCED/GUIDE) out of the user-facing
    -- status text. They remain stable DB values but the UI uses localized names.
    if journey and page.statusLines and page.statusLines[3] then
        page.statusLines[3]:SetText(FC:GetText("STATUS_JOURNEY_READY",
            #(journey.opportunities or {}), discoveryModeLabel(journey.mode)))
    end
end

local function apply(frame)
    if not frame then return end
    refreshPreparationIndicators(frame)
    refreshJourneyIndicators(frame)

    if not FC.RETAIL_BUILD and frame.subtitle then
        frame.subtitle:SetText(FC:GetText("MAIN_SUBTITLE",
            tostring(FC.Client and FC.Client.interface or "?"),
            FC.Suggestions and FC.Suggestions:Count() or 0,
            discoveryModeLabel(FC.DB and FC.DB.settings and FC.DB.settings.discoveryMode)))
    end
end

local previousCreateMainFrame = UI.CreateMainFrame
if type(previousCreateMainFrame) == "function" then
    function UI:CreateMainFrame(...)
        local frame = previousCreateMainFrame(self, ...)
        apply(frame)
        return frame
    end
end

local previousRefreshDashboard = UI.RefreshDashboard
if type(previousRefreshDashboard) == "function" then
    function UI:RefreshDashboard(...)
        previousRefreshDashboard(self, ...)
        apply(self.frame)
    end
end
