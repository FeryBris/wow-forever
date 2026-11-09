local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme
local PAGE_SIZE = 11

local function setText(fontString, text, color)
    if not fontString then return end
    color = color or Theme.colors.text
    fontString:SetText(text or "")
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function formatAge(timestamp)
    timestamp = tonumber(timestamp)
    local now = time and time() or 0
    if not timestamp or timestamp <= 0 or now <= 0 then return FC:GetText("CHAR_AGE_UNKNOWN") end
    local age = math.max(0, now - timestamp)
    if age < 60 then return FC:GetText("CHAR_AGE_NOW") end
    if age < 3600 then return string.format("%dm", math.floor(age / 60)) end
    if age < 86400 then return string.format("%dh", math.floor(age / 3600)) end
    return string.format("%dd", math.floor(age / 86400))
end

local function countEntries(tbl)
    local count = 0
    for _ in pairs(tbl or {}) do count = count + 1 end
    return count
end

local function professionText(character)
    local values = {}
    for _, profession in ipairs(character and character.professions or {}) do
        values[#values + 1] = string.format("%s %d/%d",
            FC:GetProfessionDisplayName(profession),
            tonumber(profession.skill) or 0,
            tonumber(profession.maxSkill) or 0)
    end
    return #values > 0 and table.concat(values, " • ") or FC:GetText("CHAR_NO_PROFESSION_CACHE")
end

local function sortedCharacters()
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

local previousCreateCharactersFrame = UI.CreateCharactersFrame
function UI:CreateCharactersFrame(...)
    local frame = previousCreateCharactersFrame(self, ...)
    if not frame or frame.fcPaging then return frame end
    frame.fcPaging = true
    frame.characterPage = 1

    frame.prevButton = Theme:CreateButton(frame, "Previous", 90, 26)
    frame.prevButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -250, 44)
    frame.nextButton = Theme:CreateButton(frame, "Next", 90, 26)
    frame.nextButton:SetPoint("LEFT", frame.prevButton, "RIGHT", 8, 0)
    frame.pageText = Theme:CreateText(frame, "GameFontHighlightSmall", "")
    frame.pageText:SetPoint("LEFT", frame.nextButton, "RIGHT", 8, 0)
    frame.pageText:SetWidth(140)

    frame.prevButton:SetScript("OnClick", function()
        frame.characterPage = math.max(1, (frame.characterPage or 1) - 1)
        UI:RefreshCharactersView()
    end)
    frame.nextButton:SetScript("OnClick", function()
        frame.characterPage = (frame.characterPage or 1) + 1
        UI:RefreshCharactersView()
    end)
    return frame
end

local previousRefreshCharactersView = UI.RefreshCharactersView
function UI:RefreshCharactersView(...)
    previousRefreshCharactersView(self, ...)
    local frame = self.charactersFrame
    if not frame or not frame.fcPaging then return end

    local characters = sortedCharacters()
    local maxPage = math.max(1, math.ceil(#characters / PAGE_SIZE))
    frame.characterPage = math.max(1, math.min(frame.characterPage or 1, maxPage))
    local startIndex = ((frame.characterPage - 1) * PAGE_SIZE) + 1
    local currentKey = FC:GetCharacterKey()
    local now = time and time() or 0

    local accountItems = countEntries(FC.DB and FC.DB.account and FC.DB.account.items)
    local recipes = countEntries(FC.DB and FC.DB.account and FC.DB.account.recipes)
    local goals = FC.Goals and FC.Goals.GetGoals and #(FC.Goals:GetGoals() or {}) or 0
    local craftingGoals = countEntries(FC.DB and FC.DB.account and FC.DB.account.craftingGoals)
    setText(frame.summary, FC:GetText("CHAR_SUMMARY", #characters, accountItems, recipes, goals + craftingGoals), Theme.colors.text)

    local freshness = FC.Inventory and FC.Inventory.GetFreshnessSummary and FC.Inventory:GetFreshnessSummary() or nil
    if freshness then
        local bankAge = freshness.accountBankAge and formatAge((time and time() or 0) - freshness.accountBankAge) or FC:GetText("CHAR_AGE_NEVER")
        setText(frame.cache, FC:GetText("CHAR_CACHE_FRESHNESS", tonumber(freshness.staleCharacters) or 0, bankAge),
            freshness.staleCharacters > 0 and Theme.colors.yellow or Theme.colors.muted)
    else
        setText(frame.cache, FC:GetText("CHAR_CACHE_UNAVAILABLE"), Theme.colors.muted)
    end

    if frame.header then frame.header:SetText(FC:GetText("CHAR_HEADER")) end
    if frame.note then frame.note:SetText(FC:GetText("CHAR_NOTE")) end

    for index, row in ipairs(frame.rows or {}) do
        local entry = characters[startIndex + index - 1]
        if entry then
            row:Show()
            local character = entry.character
            local inventory = character.inventory or {}
            local bagTypes = countEntries(inventory.bags)
            local bankTypes = countEntries(inventory.bank and inventory.bank.items)
            local marker = entry.key == currentKey and "◆" or "•"
            local age = formatAge(character.lastSeen)
            local stamp = tonumber(character.lastSeen or inventory.lastSeen) or 0
            local stale = stamp > 0 and now > 0 and (now - stamp) > (7 * 86400)
            setText(row.main, FC:GetText("CHAR_ROW",
                marker,
                tostring(character.name or entry.key),
                tonumber(character.level) or 0,
                FC:GetClassDisplayName(character),
                age,
                bagTypes,
                bankTypes),
                entry.key == currentKey and Theme.colors.green or (stale and Theme.colors.yellow or Theme.colors.text))
            setText(row.professions, professionText(character), Theme.colors.muted)
        else
            row:Hide()
        end
    end

    frame.prevButton:SetEnabled(frame.characterPage > 1)
    frame.nextButton:SetEnabled(frame.characterPage < maxPage)
    frame.prevButton:SetAlpha(frame.characterPage > 1 and 1 or 0.4)
    frame.nextButton:SetAlpha(frame.characterPage < maxPage and 1 or 0.4)
    frame.prevButton:SetFCText(FC:GetText("PREVIOUS"))
    frame.nextButton:SetFCText(FC:GetText("NEXT"))
    frame.pageText:SetText(FC:GetText("PAGE_X_OF_Y", frame.characterPage, maxPage))
end
