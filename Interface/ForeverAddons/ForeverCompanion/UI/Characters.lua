local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local function setText(fontString, text, color)
    if not fontString then return end
    color = color or Theme.colors.text
    fontString:SetText(text or "")
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function tableCount(value)
    local count = 0
    for _ in pairs(value or {}) do count = count + 1 end
    return count
end

local function formatAge(timestamp)
    timestamp = tonumber(timestamp)
    local now = time and time() or 0
    if not timestamp or timestamp <= 0 or now <= 0 then return "unknown" end
    local age = math.max(0, now - timestamp)
    if age < 60 then return "now" end
    if age < 3600 then return string.format("%dm", math.floor(age / 60)) end
    if age < 86400 then return string.format("%dh", math.floor(age / 3600)) end
    return string.format("%dd", math.floor(age / 86400))
end

local function characterFreshnessColor(character)
    local stamp = character and (character.lastSeen or (character.inventory and character.inventory.lastSeen))
    local now = time and time() or 0
    local age = stamp and now > 0 and (now - stamp) or 0
    if age > 7 * 86400 then return Theme.colors.yellow end
    return Theme.colors.text
end

local function professionText(character)
    local values = {}
    for _, profession in ipairs(character and character.professions or {}) do
        values[#values + 1] = string.format("%s %d/%d", tostring(profession.name or "?"), tonumber(profession.skill) or 0, tonumber(profession.maxSkill) or 0)
    end
    return #values > 0 and table.concat(values, " • ") or "No profession cache"
end

local function inventoryTypes(character)
    local inventory = character and character.inventory or nil
    return tableCount(inventory and inventory.bags), tableCount(inventory and inventory.bank and inventory.bank.items)
end

local function getSortedCharacters()
    local result = {}
    for key, character in pairs(FC.DB and FC.DB.account and FC.DB.account.characters or {}) do
        result[#result + 1] = { key = key, character = character }
    end
    table.sort(result, function(a, b)
        local aSeen = tonumber(a.character.lastSeen) or 0
        local bSeen = tonumber(b.character.lastSeen) or 0
        if aSeen == bSeen then
            local aLevel = tonumber(a.character.level) or 0
            local bLevel = tonumber(b.character.level) or 0
            if aLevel == bLevel then return tostring(a.key) < tostring(b.key) end
            return aLevel > bLevel
        end
        return aSeen > bSeen
    end)
    return result
end

function UI:CreateCharactersFrame()
    if self.charactersFrame then return self.charactersFrame end

    local frame = Theme:CreatePanel(UIParent, Theme.colors.navy, Theme.colors.gold)
    frame:SetSize(860, 620)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    frame.title = Theme:CreateText(frame, "GameFontNormalHuge", "CHARACTERS & ACCOUNT")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -18)
    frame.title:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])

    frame.closeButton = Theme:CreateButton(frame, "X", 32, 30)
    frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -14)
    frame.closeButton:SetScript("OnClick", function() frame:Hide() end)

    frame.refreshButton = Theme:CreateButton(frame, "Refresh Current", 130, 30)
    frame.refreshButton:SetPoint("RIGHT", frame.closeButton, "LEFT", -8, 0)
    frame.refreshButton:SetScript("OnClick", function()
        FC:RefreshModules("characters-window")
        UI:RefreshCharactersView()
    end)

    frame.summary = Theme:CreateText(frame, "GameFontHighlight", "")
    frame.summary:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -64)
    frame.summary:SetWidth(816)
    frame.summary:SetJustifyH("LEFT")

    frame.cache = Theme:CreateText(frame, "GameFontHighlightSmall", "")
    frame.cache:SetPoint("TOPLEFT", frame.summary, "BOTTOMLEFT", 0, -7)
    frame.cache:SetWidth(816)
    frame.cache:SetJustifyH("LEFT")

    frame.header = Theme:CreateText(frame, "GameFontNormal", "Character                         Level / Class             Cache age       Inventory")
    frame.header:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -116)
    frame.header:SetWidth(812)
    frame.header:SetJustifyH("LEFT")
    frame.header:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])

    frame.rows = {}
    for index = 1, 11 do
        local row = Theme:CreatePanel(frame, index % 2 == 0 and Theme.colors.panelSoft or Theme.colors.panel, Theme.colors.blueSoft)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -142 - ((index - 1) * 39))
        row:SetSize(816, 36)

        row.main = Theme:CreateText(row, "GameFontHighlightSmall", "")
        row.main:SetPoint("LEFT", row, "LEFT", 10, 5)
        row.main:SetWidth(790)
        row.main:SetJustifyH("LEFT")

        row.professions = Theme:CreateText(row, "GameFontDisableSmall", "")
        row.professions:SetPoint("LEFT", row, "LEFT", 10, -9)
        row.professions:SetWidth(790)
        row.professions:SetJustifyH("LEFT")

        frame.rows[index] = row
    end

    frame.note = Theme:CreateText(frame, "GameFontDisableSmall",
        "Offline characters are represented by the last cache collected while that character was logged in. Bank data is cached only after the bank was opened successfully.")
    frame.note:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 18)
    frame.note:SetWidth(816)
    frame.note:SetJustifyH("LEFT")

    self.charactersFrame = frame
    return frame
end

function UI:RefreshCharactersView()
    local frame = self:CreateCharactersFrame()
    local characters = getSortedCharacters()
    local currentKey = FC:GetCharacterKey()
    local accountItems = tableCount(FC.DB and FC.DB.account and FC.DB.account.items)
    local recipes = tableCount(FC.DB and FC.DB.account and FC.DB.account.recipes)
    local goals = FC.Goals and FC.Goals.GetGoals and #(FC.Goals:GetGoals() or {}) or 0
    local craftingGoals = tableCount(FC.DB and FC.DB.account and FC.DB.account.craftingGoals)

    setText(frame.summary, string.format("%d cached character(s) • %d account item type(s) • %d cached recipe(s) • %d goal(s)",
        #characters, accountItems, recipes, goals + craftingGoals), Theme.colors.text)

    local freshness = FC.Inventory and FC.Inventory.GetFreshnessSummary and FC.Inventory:GetFreshnessSummary() or nil
    if freshness then
        local bankAge = freshness.accountBankAge and formatAge((time and time() or 0) - freshness.accountBankAge) or "never"
        setText(frame.cache, string.format("Freshness: %d stale character inventory cache(s) (>24h) • account bank last scanned: %s",
            tonumber(freshness.staleCharacters) or 0, bankAge), freshness.staleCharacters > 0 and Theme.colors.yellow or Theme.colors.muted)
    else
        setText(frame.cache, "Cache freshness data unavailable.", Theme.colors.muted)
    end

    for index, row in ipairs(frame.rows) do
        local entry = characters[index]
        if entry then
            row:Show()
            local character = entry.character
            local bagTypes, bankTypes = inventoryTypes(character)
            local marker = entry.key == currentKey and "◆" or "•"
            local age = formatAge(character.lastSeen)
            setText(row.main, string.format("%s %-30s L%-3d %-18s %-10s Bags %d • Bank %d",
                marker,
                tostring(character.name or entry.key),
                tonumber(character.level) or 0,
                tostring(character.className or "Unknown"),
                age,
                bagTypes,
                bankTypes),
                entry.key == currentKey and Theme.colors.green or characterFreshnessColor(character))
            setText(row.professions, professionText(character), Theme.colors.muted)
        else
            row:Hide()
        end
    end
end

function UI:ShowCharacters()
    local frame = self:CreateCharactersFrame()
    self:RefreshCharactersView()
    frame:Show()
end

local previousCreateMainFrame = UI.CreateMainFrame
function UI:CreateMainFrame(...)
    local frame = previousCreateMainFrame(self, ...)
    if frame and not frame.fcCharactersButton and frame.pages and frame.pages.Overview and frame.pages.Overview.accountCard then
        local button = Theme:CreateButton(frame.pages.Overview.accountCard, "Open Character Dashboard", 205, 30)
        button:SetPoint("BOTTOMRIGHT", frame.pages.Overview.accountCard, "BOTTOMRIGHT", -14, 12)
        button:SetScript("OnClick", function() UI:ShowCharacters() end)
        frame.fcCharactersButton = button
    end
    return frame
end
