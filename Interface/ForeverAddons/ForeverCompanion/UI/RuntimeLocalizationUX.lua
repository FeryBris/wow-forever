local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local function setText(fontString, text, color)
    if not fontString then return end
    fontString:SetText(text or "")
    color = color or Theme.colors.text
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function countEntries(tbl)
    local count = 0
    for _ in pairs(tbl or {}) do count = count + 1 end
    return count
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

local function getRecipeStats(character, profession)
    if not character or not profession or not character.recipeStats then return nil end
    if profession.skillLineID and character.recipeStats[profession.skillLineID] then
        return character.recipeStats[profession.skillLineID]
    end
    for _, stats in pairs(character.recipeStats) do
        if tonumber(stats.professionID) == tonumber(profession.skillLineID) or stats.professionName == profession.name then
            return stats
        end
    end
    return nil
end

local function professionListText(character)
    local values = {}
    for _, profession in ipairs(character and character.professions or {}) do
        values[#values + 1] = string.format("%s %d/%d",
            FC:GetProfessionDisplayName(profession),
            tonumber(profession.skill) or 0,
            tonumber(profession.maxSkill) or 0)
    end
    return #values > 0 and table.concat(values, "  •  ") or FC:GetText("NO_PROFESSIONS_DETECTED")
end

local function sortedCharacters()
    local result = {}
    for key, character in pairs(FC.DB and FC.DB.account and FC.DB.account.characters or {}) do
        result[#result + 1] = { key = key, character = character }
    end
    table.sort(result, function(a, b)
        local aLevel = tonumber(a.character.level) or 0
        local bLevel = tonumber(b.character.level) or 0
        if aLevel == bLevel then return tostring(a.character.name or a.key) < tostring(b.character.name or b.key) end
        return aLevel > bLevel
    end)
    return result
end

local function localizeOverview(frame)
    local page = frame and frame.pages and frame.pages.Overview
    if not page then return end

    local character = FC:GetCurrentCharacter()
    local knownCharacters = countEntries(FC.DB and FC.DB.account and FC.DB.account.characters)
    local cachedRecipes = countEntries(FC.DB and FC.DB.account and FC.DB.account.recipes)
    local cachedItems = countEntries(FC.DB and FC.DB.account and FC.DB.account.items)

    if character and page.characterInfo then
        local lines = {
            FC:GetText("OVERVIEW_CHARACTER_MAIN", tostring(character.name or "?"), tonumber(character.level) or 0, FC:GetClassDisplayName(character)),
            tostring(character.realm or ""),
            professionListText(character),
            FC:GetText("OVERVIEW_ACCOUNT_CACHE", knownCharacters, cachedRecipes, cachedItems),
        }
        setText(page.characterInfo, table.concat(lines, "\n"), Theme.colors.text)
    end

    local characters = sortedCharacters()
    local currentKey = FC:GetCharacterKey()
    for index, line in ipairs(page.accountLines or {}) do
        local entry = characters[index]
        if entry then
            local marker = entry.key == currentKey and "> " or "  "
            setText(line, FC:GetText("OVERVIEW_ACCOUNT_CHARACTER_ROW",
                marker,
                tostring(entry.character.name or "?"),
                tonumber(entry.character.level) or 0,
                FC:GetClassDisplayName(entry.character)),
                entry.key == currentKey and Theme.colors.green or Theme.colors.text)
        elseif index == 1 then
            setText(line, FC:GetText("NO_CACHED_CHARACTERS"), Theme.colors.muted)
        else
            setText(line, "")
        end
    end
end

local function localizeProfessions(frame)
    local page = frame and frame.pages and frame.pages.Professions
    if not page then return end
    local character = FC:GetCurrentCharacter()
    local professions = character and character.professions or {}

    for index, line in ipairs(page.skillLines or {}) do
        local profession = professions[index]
        if profession then
            local stats = getRecipeStats(character, profession)
            local recipeSuffix = stats and FC:GetText("PROF_RECIPE_SUFFIX", tonumber(stats.learned) or 0, tonumber(stats.total) or 0) or ""
            local remaining = math.max(0, (tonumber(profession.maxSkill) or 0) - (tonumber(profession.skill) or 0))
            local capSuffix = remaining > 0 and FC:GetText("PROF_TO_CAP_SUFFIX", remaining) or ""
            setText(line, FC:GetText("PROF_PROGRESS_ROW",
                FC:GetProfessionDisplayName(profession),
                tonumber(profession.skill) or 0,
                tonumber(profession.maxSkill) or 0,
                recipeSuffix,
                capSuffix))
        elseif index == 1 then
            setText(line, FC:GetText("NO_PROFESSIONS_YET"), Theme.colors.muted)
        else
            setText(line, "")
        end
    end

    for _, button in ipairs(page.recipeButtons or {}) do
        if button:IsShown() and button.recipeID then
            local recipe = FC.DB and FC.DB.account and FC.DB.account.recipes and FC.DB.account.recipes[button.recipeID]
            if recipe then
                button:SetFCText(tostring(recipe.name or (FC:GetText("SEARCH_RECIPE_FALLBACK") .. " " .. tostring(button.recipeID))))
                local goals = FC.DB and FC.DB.account and FC.DB.account.craftingGoals or {}
                button:SetFCActive(goals[button.recipeID] ~= nil or goals[tostring(button.recipeID)] ~= nil)
            end
        end
    end
end

local previousRefreshDashboard = UI.RefreshDashboard
if type(previousRefreshDashboard) == "function" then
    function UI:RefreshDashboard(...)
        previousRefreshDashboard(self, ...)
        localizeOverview(self.frame)
        localizeProfessions(self.frame)
    end
end

local previousRefreshProfessionPlannerView = UI.RefreshProfessionPlannerView
if type(previousRefreshProfessionPlannerView) == "function" then
    function UI:RefreshProfessionPlannerView(...)
        previousRefreshProfessionPlannerView(self, ...)
        local frame = self.professionPlannerFrame
        local professions = FC.ProfessionPlanner and FC.ProfessionPlanner:GetAvailableProfessions() or {}
        if not frame then return end
        for index, button in ipairs(frame.professionButtons or {}) do
            local profession = professions[index]
            if profession and button:IsShown() then button:SetFCText(FC:GetProfessionDisplayName(profession)) end
        end
    end
end

local previousRefreshCharactersView = UI.RefreshCharactersView
if type(previousRefreshCharactersView) == "function" then
    function UI:RefreshCharactersView(...)
        previousRefreshCharactersView(self, ...)
        local frame = self.charactersFrame
        if not frame then return end
        local characters = sortedCharacters()
        local page = math.max(1, tonumber(frame.characterPage) or 1)
        local startIndex = ((page - 1) * 11) + 1
        local currentKey = FC:GetCharacterKey()

        for index, row in ipairs(frame.rows or {}) do
            local entry = characters[startIndex + index - 1]
            if entry and row:IsShown() then
                local inventory = entry.character.inventory or {}
                local bagTypes = countEntries(inventory.bags)
                local bankTypes = countEntries(inventory.bank and inventory.bank.items)
                local marker = entry.key == currentKey and ">" or "-"
                local stamp = tonumber(entry.character.lastSeen or inventory.lastSeen) or 0
                setText(row.main, FC:GetText("CHAR_ROW",
                    marker,
                    tostring(entry.character.name or entry.key),
                    tonumber(entry.character.level) or 0,
                    FC:GetClassDisplayName(entry.character),
                    formatAge(stamp),
                    bagTypes,
                    bankTypes),
                    entry.key == currentKey and Theme.colors.green or Theme.colors.text)
                setText(row.professions, professionListText(entry.character), Theme.colors.muted)
            end
        end
    end
end
