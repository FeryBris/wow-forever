local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local function setText(fontString, text, color)
    if not fontString then return end
    color = color or Theme.colors.text
    fontString:SetText(text or "")
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function ownerSummary(owners)
    local result = {}
    for key, owner in pairs(owners or {}) do
        local locations = {}
        for location, data in pairs(owner.locations or {}) do
            locations[#locations + 1] = string.format("%s %d", location, tonumber(data.count) or 0)
        end
        table.sort(locations)
        result[#result + 1] = string.format("%s: %d%s", key, tonumber(owner.count) or 0,
            #locations > 0 and (" (" .. table.concat(locations, ", ") .. ")") or "")
    end
    table.sort(result)
    return result
end

function UI:CreateItemsFrame()
    if self.itemsFrame then return self.itemsFrame end

    local frame = Theme:CreatePanel(UIParent, Theme.colors.navy, Theme.colors.gold)
    frame:SetSize(800, 590)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    frame.title = Theme:CreateText(frame, "GameFontNormalHuge", "ITEM INTELLIGENCE")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -18)
    frame.title:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])

    frame.closeButton = Theme:CreateButton(frame, "X", 32, 30)
    frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -14)
    frame.closeButton:SetScript("OnClick", function() frame:Hide() end)

    frame.search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.search:SetSize(500, 30)
    frame.search:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -68)
    frame.search:SetAutoFocus(false)
    frame.search:SetTextInsets(8, 8, 0, 0)

    frame.searchButton = Theme:CreateButton(frame, "Analyze", 120, 30)
    frame.searchButton:SetPoint("LEFT", frame.search, "RIGHT", 12, 0)

    frame.summary = Theme:CreateText(frame, "GameFontHighlight", "Search a cached item name or enter an item ID.")
    frame.summary:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -112)
    frame.summary:SetWidth(748)
    frame.summary:SetJustifyH("LEFT")

    frame.detailLines = {}
    for i = 1, 12 do
        local line = Theme:CreateText(frame, "GameFontHighlightSmall", "")
        line:SetPoint("TOPLEFT", frame, "TOPLEFT", 26, -154 - ((i - 1) * 32))
        line:SetWidth(748)
        line:SetJustifyH("LEFT")
        line:SetJustifyV("TOP")
        frame.detailLines[i] = line
    end

    local function analyze()
        local query = frame.search:GetText() or ""
        frame.search:ClearFocus()
        local analysis, err = FC.Items:FindAndAnalyze(query)
        frame.analysis = analysis
        frame.errorText = err
        UI:RefreshItemsView()
    end
    frame.searchButton:SetScript("OnClick", analyze)
    frame.search:SetScript("OnEnterPressed", analyze)

    frame.note = Theme:CreateText(frame, "GameFontDisableSmall",
        "Item Intelligence summarizes verified item metadata, cached ownership, set membership and crafting-goal relevance. It does not calculate best-in-slot or percentage upgrades.")
    frame.note:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 18)
    frame.note:SetWidth(748)
    frame.note:SetJustifyH("LEFT")

    self.itemsFrame = frame
    return frame
end

function UI:RefreshItemsView()
    local frame = self.itemsFrame
    if not frame then return end
    local analysis = frame.analysis
    if not analysis then
        setText(frame.summary, frame.errorText or "Search a cached item name or enter an item ID.", frame.errorText and Theme.colors.yellow or Theme.colors.muted)
        for _, line in ipairs(frame.detailLines) do setText(line, "") end
        return
    end

    local base = analysis.base
    setText(frame.summary, string.format("%s  •  Item %d  •  cached total x%d", tostring(base.name), tonumber(base.itemID) or 0, tonumber(analysis.totalOwned) or 0), Theme.colors.gold)

    local lines = {}
    lines[#lines + 1] = string.format("Type: %s / %s  •  Item level: %s  •  Required level: %s", tostring(base.itemType or "?"), tostring(base.itemSubType or "?"), tostring(base.itemLevel or "?"), tostring(base.minLevel or "?"))
    lines[#lines + 1] = string.format("Equip location: %s  •  Crafting reagent: %s", tostring(base.equipLoc or "none"), base.isCraftingReagent and "yes" or "no")

    if base.setID then
        lines[#lines + 1] = string.format("Set: %s (ID %d)  •  %d cached set-piece type(s) currently owned", tostring(base.setName or "Unknown set"), tonumber(base.setID) or 0, tonumber(analysis.cachedSetPieceTypesOwned) or 0)
        if #analysis.setPeers > 0 then
            local peers = {}
            for _, peer in ipairs(analysis.setPeers) do peers[#peers + 1] = string.format("%s x%d", tostring(peer.name), tonumber(peer.total) or 0) end
            lines[#lines + 1] = "Other cached pieces: " .. table.concat(peers, ", ")
        end
    else
        lines[#lines + 1] = "Set membership: none exposed by the item API."
    end

    local owners = ownerSummary(analysis.owners)
    if #owners > 0 then
        lines[#lines + 1] = "Ownership: " .. table.concat(owners, " • ")
    else
        lines[#lines + 1] = "Ownership: not present in the current account cache."
    end

    local used = analysis.crafting and analysis.crafting.usedByGoals or {}
    local output = analysis.crafting and analysis.crafting.outputOfGoals or {}
    if #used > 0 then
        local names = {}
        for _, goal in ipairs(used) do names[#names + 1] = tostring(goal.name) end
        lines[#lines + 1] = "Needed by crafting goal(s): " .. table.concat(names, ", ")
    end
    if #output > 0 then
        local names = {}
        for _, goal in ipairs(output) do names[#names + 1] = tostring(goal.name) end
        lines[#lines + 1] = "Output of crafting goal(s): " .. table.concat(names, ", ")
    end
    if #used == 0 and #output == 0 then lines[#lines + 1] = "Crafting goals: no current relevance detected." end

    if base.description and base.description ~= "" then lines[#lines + 1] = "Description: " .. tostring(base.description) end

    for i = 1, #frame.detailLines do
        setText(frame.detailLines[i], lines[i] or "", i <= 2 and Theme.colors.text or Theme.colors.muted)
    end
end

function UI:ShowItems(query)
    local frame = self:CreateItemsFrame()
    if query then
        frame.search:SetText(tostring(query))
        if FC.Items and type(FC.Items.FindAndAnalyze) == "function" then
            local analysis, err = FC.Items:FindAndAnalyze(tostring(query))
            frame.analysis = analysis
            frame.errorText = err
        end
    end
    self:RefreshItemsView()
    frame:Show()
end

local previousCreateMainFrame = UI.CreateMainFrame
function UI:CreateMainFrame(...)
    local frame = previousCreateMainFrame(self, ...)
    if frame and not frame.fcItemsButton and frame.pages and frame.pages.Inventory and frame.pages.Inventory.resultsCard then
        local button = Theme:CreateButton(frame.pages.Inventory.resultsCard, "Item Intelligence", 150, 30)
        button:SetPoint("BOTTOMRIGHT", frame.pages.Inventory.resultsCard, "BOTTOMRIGHT", -14, 12)
        button:SetScript("OnClick", function()
            local query = frame.pages.Inventory.searchBox and frame.pages.Inventory.searchBox:GetText() or nil
            UI:ShowItems(query ~= "" and query or nil)
        end)
        frame.fcItemsButton = button
    end
    return frame
end