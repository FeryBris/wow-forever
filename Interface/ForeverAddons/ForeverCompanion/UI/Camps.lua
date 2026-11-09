local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local function setText(fontString, text, color)
    if not fontString then return end
    color = color or Theme.colors.text
    fontString:SetText(text or "")
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function formatDuration(seconds)
    seconds = tonumber(seconds) or 0
    if seconds <= 0 then return "expired" end
    if seconds >= 3600 then
        return string.format("%dh %02dm", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60))
    end
    return string.format("%dm %02ds", math.floor(seconds / 60), math.floor(seconds % 60))
end

function UI:CreateCampsFrame()
    if self.campsFrame then return self.campsFrame end

    local frame = Theme:CreatePanel(UIParent, Theme.colors.navy, Theme.colors.gold)
    frame:SetSize(900, 650)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    frame.title = Theme:CreateText(frame, "GameFontNormalHuge", "CAMP COMPANION")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -18)
    frame.title:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])

    frame.closeButton = Theme:CreateButton(frame, "X", 32, 30)
    frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -14)
    frame.closeButton:SetScript("OnClick", function() frame:Hide() end)

    frame.refreshButton = Theme:CreateButton(frame, "Refresh", 90, 30)
    frame.refreshButton:SetPoint("RIGHT", frame.closeButton, "LEFT", -8, 0)
    frame.refreshButton:SetScript("OnClick", function()
        if FC.Camps then FC.Camps:Refresh("camp-window") end
        UI:RefreshCampsView()
    end)

    frame.finderButton = Theme:CreateButton(frame, "Open Camp Finder Map", 165, 30)
    frame.finderButton:SetPoint("RIGHT", frame.refreshButton, "LEFT", -8, 0)
    frame.finderButton:SetScript("OnClick", function()
        if not FC.CampFinder then return end
        local ok, result = FC.CampFinder:OpenMap()
        if not ok then FC:Print(result) end
    end)

    frame.summary = Theme:CreateText(frame, "GameFontHighlight", "")
    frame.summary:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -62)
    frame.summary:SetWidth(856)
    frame.summary:SetJustifyH("LEFT")

    frame.benefitTitle = Theme:CreateSectionTitle(frame, "Current Camp State")
    frame.benefitTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -104)

    frame.benefitLines = {}
    for i = 1, 5 do
        local line = Theme:CreateText(frame, "GameFontHighlightSmall", "")
        line:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -136 - ((i - 1) * 28))
        line:SetWidth(410)
        line:SetJustifyH("LEFT")
        frame.benefitLines[i] = line
    end

    frame.contributionTitle = Theme:CreateSectionTitle(frame, "Your Potential Contributions")
    frame.contributionTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 460, -104)

    frame.contributionLines = {}
    for i = 1, 8 do
        local line = Theme:CreateText(frame, "GameFontHighlightSmall", "")
        line:SetPoint("TOPLEFT", frame, "TOPLEFT", 462, -136 - ((i - 1) * 48))
        line:SetWidth(410)
        line:SetJustifyH("LEFT")
        line:SetJustifyV("TOP")
        frame.contributionLines[i] = line
    end

    frame.catalogTitle = Theme:CreateSectionTitle(frame, "Forever Camp Progression")
    frame.catalogTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -300)

    frame.catalogLines = {}
    for i = 1, 12 do
        local line = Theme:CreateText(frame, "GameFontHighlightSmall", "")
        line:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -332 - ((i - 1) * 23))
        line:SetWidth(410)
        line:SetJustifyH("LEFT")
        frame.catalogLines[i] = line
    end

    frame.finderStatus = Theme:CreateText(frame, "GameFontDisableSmall", "")
    frame.finderStatus:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 18)
    frame.finderStatus:SetWidth(410)
    frame.finderStatus:SetJustifyH("RIGHT")

    frame.note = Theme:CreateText(frame, "GameFontDisableSmall",
        "Skill eligibility is not treated as proof of a learned blueprint; the recipe cache verifies learned camping recipes when possible.")
    frame.note:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 18)
    frame.note:SetWidth(410)
    frame.note:SetJustifyH("LEFT")

    self.campsFrame = frame
    return frame
end

function UI:RefreshCampsView()
    local frame = self.campsFrame
    if not frame then return end

    local snapshot = FC.Camps and FC.Camps:GetSnapshot() or nil
    if not snapshot then
        setText(frame.summary, "Camp data has not been scanned yet.", Theme.colors.muted)
        for _, line in ipairs(frame.contributionLines) do setText(line, "") end
    else
        local active = snapshot.benefit and snapshot.benefit.active
        setText(frame.summary,
            active and "Camp Benefits detected on this character." or "No Camp Benefits aura is currently detected.",
            active and Theme.colors.green or Theme.colors.muted)

        if active then
            local label = snapshot.benefit.name or "Camp Benefits"
            local remaining = snapshot.benefit.remaining and formatDuration(snapshot.benefit.remaining) or "duration unavailable"
            setText(frame.benefitLines[1], "✓  " .. tostring(label), Theme.colors.green)
            setText(frame.benefitLines[2], "Remaining: " .. remaining, Theme.colors.text)
        else
            setText(frame.benefitLines[1], "•  Camp Benefits aura not active", Theme.colors.muted)
            setText(frame.benefitLines[2], "Rest at a camp to acquire its available benefits.", Theme.colors.muted)
        end

        local rested = snapshot.restedXP
        if rested then
            setText(frame.benefitLines[3], string.format("Rested XP pool: %.1f%% of a level", tonumber(rested.percentOfLevel) or 0),
                (tonumber(rested.percentOfLevel) or 0) < 5 and Theme.colors.yellow or Theme.colors.text)
        else
            setText(frame.benefitLines[3], "Rested XP: unavailable", Theme.colors.muted)
        end
        setText(frame.benefitLines[4], "Shared camp-feature cooldown: 60 minutes", Theme.colors.muted)

        local kits = {}
        for _, kit in ipairs(FC.CampData and FC.CampData.hostKits or {}) do
            kits[#kits + 1] = string.format("%s %d slots", kit.name, tonumber(kit.capacity) or 0)
        end
        setText(frame.benefitLines[5], "Host kits: " .. table.concat(kits, " • "), Theme.colors.muted)

        for i = 1, #frame.contributionLines do
            local contribution = snapshot.contributions and snapshot.contributions[i]
            if contribution then
                local qualifier
                if contribution.blueprintConfirmed then
                    qualifier = "recipe cached as learned"
                elseif contribution.recipeConfirmed then
                    qualifier = "entry-tier contribution"
                else
                    qualifier = "skill-ready; blueprint may still be required"
                end
                setText(frame.contributionLines[i], string.format("%s — %d/%d\n   Tier %d: %s (%s)",
                    tostring(contribution.professionName), tonumber(contribution.skill) or 0, tonumber(contribution.maxSkill) or 0,
                    tonumber(contribution.tier) or 1, tostring(contribution.feature), qualifier),
                    contribution.blueprintConfirmed and Theme.colors.green or (contribution.tier >= 3 and Theme.colors.gold or Theme.colors.text))
            elseif i == 1 then
                setText(frame.contributionLines[i], "No camp contribution is skill-ready from the professions currently cached.", Theme.colors.muted)
            else
                setText(frame.contributionLines[i], "")
            end
        end
    end

    local catalog = {}
    for _, definition in pairs(FC.CampData and FC.CampData.professions or {}) do
        if definition.hostingProfession then
            catalog[#catalog + 1] = definition.name .. ": hosts the campfire; upgraded kits increase campsite capacity"
        else
            local tierNames = {}
            for _, tier in ipairs(definition.tiers or {}) do tierNames[#tierNames + 1] = string.format("%s@%d", tier.name, tier.skill) end
            catalog[#catalog + 1] = string.format("%s: %s", definition.name, table.concat(tierNames, " → "))
        end
    end
    table.sort(catalog)
    for i = 1, #frame.catalogLines do setText(frame.catalogLines[i], catalog[i] or "", Theme.colors.muted) end

    setText(frame.finderStatus, FC.CampFinder and FC.CampFinder:GetStatusText() or "Camp finder compatibility unavailable.", Theme.colors.muted)
end

function UI:ShowCamps()
    local frame = self:CreateCampsFrame()
    if FC.Camps then FC.Camps:Refresh("camp-window-open") end
    self:RefreshCampsView()
    frame:Show()
end

local previousCreateMainFrame = UI.CreateMainFrame
function UI:CreateMainFrame(...)
    local frame = previousCreateMainFrame(self, ...)
    if frame and not frame.fcCampsButton and frame.pages and frame.pages.Journey and frame.pages.Journey.statusCard then
        local button = Theme:CreateButton(frame.pages.Journey.statusCard, "Open Camp Companion", 180, 30)
        button:SetPoint("BOTTOMLEFT", frame.pages.Journey.statusCard, "BOTTOMLEFT", 14, 12)
        button:SetScript("OnClick", function() UI:ShowCamps() end)
        frame.fcCampsButton = button
    end
    return frame
end
