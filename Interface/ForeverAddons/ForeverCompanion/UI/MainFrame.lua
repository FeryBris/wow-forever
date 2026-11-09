local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local function countTableEntries(tbl)
    local count = 0
    for _ in pairs(tbl or {}) do
        count = count + 1
    end
    return count
end

local function getRecipeStats(character, profession)
    if not character or not character.recipeStats or not profession then
        return nil
    end

    if profession.skillLineID and character.recipeStats[profession.skillLineID] then
        return character.recipeStats[profession.skillLineID]
    end

    for _, stats in pairs(character.recipeStats) do
        if stats.professionName == profession.name then
            return stats
        end
    end
    return nil
end

local function getSortedCharacters()
    local characters = {}
    for key, character in pairs(FC.DB and FC.DB.account and FC.DB.account.characters or {}) do
        characters[#characters + 1] = { key = key, data = character }
    end

    table.sort(characters, function(a, b)
        local aLevel = tonumber(a.data.level) or 0
        local bLevel = tonumber(b.data.level) or 0
        if aLevel == bLevel then
            return tostring(a.data.name) < tostring(b.data.name)
        end
        return aLevel > bLevel
    end)
    return characters
end

local function getTrackedRecipes()
    local recipes = {}
    local goals = FC.DB and FC.DB.account and FC.DB.account.craftingGoals or {}

    for recipeID, recipe in pairs(FC.DB and FC.DB.account and FC.DB.account.recipes or {}) do
        local learned = false
        for _, known in pairs(recipe.learnedBy or {}) do
            if known then
                learned = true
                break
            end
        end

        if learned then
            recipes[#recipes + 1] = {
                recipeID = tonumber(recipeID) or recipeID,
                name = recipe.name or ("Recipe " .. tostring(recipeID)),
                tracked = goals[recipeID] ~= nil or goals[tonumber(recipeID)] ~= nil,
                professionName = recipe.professionName,
            }
        end
    end

    table.sort(recipes, function(a, b)
        if a.tracked ~= b.tracked then
            return a.tracked
        end
        return tostring(a.name) < tostring(b.name)
    end)
    return recipes
end

local function setText(fontString, text, color)
    fontString:SetText(text or "")
    color = color or Theme.colors.text
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function createCard(parent, title)
    local card = Theme:CreatePanel(parent, Theme.colors.panel, Theme.colors.goldSoft)
    card.title = Theme:CreateSectionTitle(card, title)
    card.title:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -12)

    local accent = card:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
    accent:SetPoint("TOPRIGHT", card, "TOPRIGHT", 0, 0)
    accent:SetHeight(3)
    accent:SetColorTexture(Theme.colors.blue[1], Theme.colors.blue[2], Theme.colors.blue[3], 0.85)
    return card
end

local function createLines(parent, count, startY, spacing, width, template)
    local lines = {}
    for i = 1, count do
        local line = Theme:CreateText(parent, template or "GameFontHighlightSmall", "")
        line:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, startY - ((i - 1) * spacing))
        line:SetWidth(width)
        line:SetJustifyH("LEFT")
        line:SetJustifyV("TOP")
        lines[i] = line
    end
    return lines
end

local function createOverviewPage(frame)
    local page = CreateFrame("Frame", nil, frame.content)
    page:SetAllPoints(frame.content)

    page.characterCard = createCard(page, "Current Character")
    page.characterCard:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    page.characterCard:SetSize(370, 150)
    page.characterInfo = Theme:CreateText(page.characterCard, "GameFontHighlight", "")
    page.characterInfo:SetPoint("TOPLEFT", page.characterCard, "TOPLEFT", 14, -42)
    page.characterInfo:SetWidth(340)
    page.characterInfo:SetJustifyH("LEFT")
    page.characterInfo:SetJustifyV("TOP")

    page.accountCard = createCard(page, "Account Characters")
    page.accountCard:SetPoint("TOPLEFT", page.characterCard, "BOTTOMLEFT", 0, -12)
    page.accountCard:SetSize(370, 316)
    page.accountLines = createLines(page.accountCard, 9, -44, 27, 340, "GameFontHighlightSmall")

    page.suggestionCard = createCard(page, "Smart Suggestions")
    page.suggestionCard:SetPoint("TOPLEFT", page, "TOPLEFT", 382, 0)
    page.suggestionCard:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
    page.suggestionLines = createLines(page.suggestionCard, 8, -46, 52, 426, "GameFontHighlightSmall")

    return page
end

local function createProfessionsPage(frame)
    local page = CreateFrame("Frame", nil, frame.content)
    page:SetAllPoints(frame.content)

    page.skillsCard = createCard(page, "Profession Progress")
    page.skillsCard:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    page.skillsCard:SetSize(340, 190)
    page.skillLines = createLines(page.skillsCard, 5, -46, 27, 310, "GameFontHighlightSmall")

    page.recipesCard = createCard(page, "Known Recipes")
    page.recipesCard:SetPoint("TOPLEFT", page.skillsCard, "BOTTOMLEFT", 0, -12)
    page.recipesCard:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 0)
    page.recipesCard:SetWidth(340)
    page.recipeHint = Theme:CreateText(page.recipesCard, "GameFontDisableSmall", "Open a profession window to populate the cache.")
    page.recipeHint:SetPoint("TOPLEFT", page.recipesCard, "TOPLEFT", 14, -42)
    page.recipeHint:SetWidth(310)
    page.recipeHint:SetJustifyH("LEFT")

    page.recipeButtons = {}
    for i = 1, 8 do
        local button = Theme:CreateButton(page.recipesCard, "", 310, 27)
        button:SetPoint("TOPLEFT", page.recipesCard, "TOPLEFT", 14, -66 - ((i - 1) * 29))
        button.label:SetJustifyH("LEFT")
        button.label:ClearAllPoints()
        button.label:SetPoint("LEFT", button, "LEFT", 8, 0)
        button.label:SetPoint("RIGHT", button, "RIGHT", -8, 0)
        button:SetScript("OnClick", function(self)
            if not self.recipeID or not FC.CraftingGoals then
                return
            end

            local goals = FC.DB.account.craftingGoals or {}
            if goals[self.recipeID] then
                FC.CraftingGoals:RemoveGoal(self.recipeID)
            else
                local ok, result = FC.CraftingGoals:AddGoal(self.recipeID, 1)
                if not ok then
                    FC:Print(result)
                end
            end
            UI:RefreshDashboard()
        end)
        page.recipeButtons[i] = button
    end

    page.goalsCard = createCard(page, "Crafting Goals & Shopping List")
    page.goalsCard:SetPoint("TOPLEFT", page, "TOPLEFT", 352, 0)
    page.goalsCard:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
    page.goalLines = createLines(page.goalsCard, 12, -46, 34, 448, "GameFontHighlightSmall")

    page.goalHint = Theme:CreateText(page.goalsCard, "GameFontDisableSmall", "Click a cached recipe on the left to track/untrack it.")
    page.goalHint:SetPoint("BOTTOMLEFT", page.goalsCard, "BOTTOMLEFT", 14, 12)
    page.goalHint:SetWidth(448)
    page.goalHint:SetJustifyH("LEFT")

    return page
end

local function createInventoryPage(frame)
    local page = CreateFrame("Frame", nil, frame.content)
    page:SetAllPoints(frame.content)

    page.searchCard = createCard(page, "Account Item Search")
    page.searchCard:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    page.searchCard:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 0)
    page.searchCard:SetHeight(88)

    page.searchBox = CreateFrame("EditBox", nil, page.searchCard, "InputBoxTemplate")
    page.searchBox:SetSize(520, 30)
    page.searchBox:SetPoint("TOPLEFT", page.searchCard, "TOPLEFT", 18, -42)
    page.searchBox:SetAutoFocus(false)
    page.searchBox:SetTextInsets(8, 8, 0, 0)

    page.searchButton = Theme:CreateButton(page.searchCard, "Search", 120, 30)
    page.searchButton:SetPoint("LEFT", page.searchBox, "RIGHT", 12, 0)

    page.clearButton = Theme:CreateButton(page.searchCard, "Clear", 100, 30)
    page.clearButton:SetPoint("LEFT", page.searchButton, "RIGHT", 8, 0)

    local function runSearch()
        UI.inventoryQuery = page.searchBox:GetText() or ""
        UI:RefreshDashboard()
    end
    page.searchButton:SetScript("OnClick", runSearch)
    page.searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        runSearch()
    end)
    page.clearButton:SetScript("OnClick", function()
        page.searchBox:SetText("")
        UI.inventoryQuery = ""
        UI:RefreshDashboard()
    end)

    page.resultsCard = createCard(page, "Cached Results")
    page.resultsCard:SetPoint("TOPLEFT", page.searchCard, "BOTTOMLEFT", 0, -12)
    page.resultsCard:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
    page.resultLines = createLines(page.resultsCard, 12, -46, 33, 810, "GameFontHighlightSmall")
    return page
end

local function createPreparationPage(frame)
    local page = CreateFrame("Frame", nil, frame.content)
    page:SetAllPoints(frame.content)

    page.checkCard = createCard(page, "Preparation Checklist")
    page.checkCard:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    page.checkCard:SetSize(440, 466)
    page.checkLines = createLines(page.checkCard, 8, -54, 48, 408, "GameFontHighlight")

    page.infoCard = createCard(page, "Dungeon-ready at a glance")
    page.infoCard:SetPoint("TOPLEFT", page, "TOPLEFT", 452, 0)
    page.infoCard:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
    page.infoLines = createLines(page.infoCard, 9, -48, 42, 350, "GameFontHighlightSmall")
    return page
end

local function createJourneyPage(frame)
    local page = CreateFrame("Frame", nil, frame.content)
    page:SetAllPoints(frame.content)

    page.discoveryCard = createCard(page, "Discovery Mode")
    page.discoveryCard:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    page.discoveryCard:SetSize(380, 250)

    page.discoveryText = Theme:CreateText(page.discoveryCard, "GameFontHighlightSmall",
        "Choose how much guidance Forever Companion should reveal as Journey features arrive.")
    page.discoveryText:SetPoint("TOPLEFT", page.discoveryCard, "TOPLEFT", 14, -48)
    page.discoveryText:SetWidth(350)
    page.discoveryText:SetJustifyH("LEFT")

    page.modeButtons = {}
    local modes = {
        { key = "EXPLORER", label = "Explorer — uncover everything" },
        { key = "BALANCED", label = "Balanced — focused hints" },
        { key = "GUIDE", label = "Guide — precise guidance" },
    }
    for i, mode in ipairs(modes) do
        local button = Theme:CreateButton(page.discoveryCard, mode.label, 350, 38)
        button:SetPoint("TOPLEFT", page.discoveryCard, "TOPLEFT", 14, -88 - ((i - 1) * 46))
        button.mode = mode.key
        button:SetScript("OnClick", function(self)
            FC.DB.settings.discoveryMode = self.mode
            UI:RefreshDashboard()
        end)
        page.modeButtons[i] = button
    end

    page.statusCard = createCard(page, "Legacy, Travel & Exploration")
    page.statusCard:SetPoint("TOPLEFT", page, "TOPLEFT", 392, 0)
    page.statusCard:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
    page.statusLines = createLines(page.statusCard, 10, -50, 38, 406, "GameFontHighlightSmall")

    page.roadmapCard = createCard(page, "Next Modules")
    page.roadmapCard:SetPoint("TOPLEFT", page.discoveryCard, "BOTTOMLEFT", 0, -12)
    page.roadmapCard:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 0)
    page.roadmapCard:SetWidth(380)
    page.roadmapLines = createLines(page.roadmapCard, 5, -48, 38, 350, "GameFontHighlightSmall")
    return page
end

function UI:SwitchTab(name)
    if not self.frame or not self.frame.pages then
        return
    end

    self.activeTab = name
    for tabName, page in pairs(self.frame.pages) do
        if tabName == name then
            page:Show()
        else
            page:Hide()
        end
    end

    for tabName, button in pairs(self.frame.tabs or {}) do
        button:SetFCActive(tabName == name)
    end
end

function UI:CreateMainFrame()
    if self.frame then
        return self.frame
    end

    local frame = Theme:CreatePanel(UIParent, Theme.colors.navy, Theme.colors.gold)
    frame:SetSize(900, 620)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")
    frame:Hide()

    frame.header = Theme:CreatePanel(frame, Theme.colors.navySoft, Theme.colors.goldSoft)
    frame.header:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
    frame.header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
    frame.header:SetHeight(58)

    frame.title = Theme:CreateText(frame.header, "GameFontNormalHuge", "FOREVER COMPANION")
    frame.title:SetPoint("TOPLEFT", frame.header, "TOPLEFT", 18, -10)
    frame.title:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])

    frame.subtitle = Theme:CreateText(frame.header, "GameFontHighlightSmall", "")
    frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 2, -3)
    frame.subtitle:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3])

    frame.closeButton = Theme:CreateButton(frame.header, "X", 32, 30)
    frame.closeButton:SetPoint("TOPRIGHT", frame.header, "TOPRIGHT", -12, -13)
    frame.closeButton:SetScript("OnClick", function() frame:Hide() end)

    frame.refreshButton = Theme:CreateButton(frame.header, "Refresh", 90, 30)
    frame.refreshButton:SetPoint("RIGHT", frame.closeButton, "LEFT", -8, 0)
    frame.refreshButton:SetScript("OnClick", function()
        FC:RefreshModules("button")
    end)

    frame.tabs = {}
    local tabs = {
        { key = "Overview", label = "Overview" },
        { key = "Professions", label = "Professions" },
        { key = "Inventory", label = "Inventory" },
        { key = "Preparation", label = "Preparation" },
        { key = "Journey", label = "Journey" },
    }

    local previous
    for _, tabInfo in ipairs(tabs) do
        local button = Theme:CreateButton(frame, tabInfo.label, 160, 34)
        button:SetPoint("TOP", frame, "TOP", 0, -76)
        if previous then
            button:SetPoint("LEFT", previous, "RIGHT", 6, 0)
        else
            button:SetPoint("LEFT", frame, "LEFT", 24, 0)
        end
        button:SetScript("OnClick", function()
            UI:SwitchTab(tabInfo.key)
        end)
        frame.tabs[tabInfo.key] = button
        previous = button
    end

    frame.content = CreateFrame("Frame", nil, frame)
    frame.content:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -122)
    frame.content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 22)

    frame.pages = {
        Overview = createOverviewPage(frame),
        Professions = createProfessionsPage(frame),
        Inventory = createInventoryPage(frame),
        Preparation = createPreparationPage(frame),
        Journey = createJourneyPage(frame),
    }

    self.frame = frame
    self.activeTab = self.activeTab or "Overview"
    self:SwitchTab(self.activeTab)
    return frame
end

local function refreshOverview(page, character)
    local knownCharacters = countTableEntries(FC.DB and FC.DB.account and FC.DB.account.characters)
    local cachedRecipes = countTableEntries(FC.DB and FC.DB.account and FC.DB.account.recipes)
    local cachedItems = countTableEntries(FC.DB and FC.DB.account and FC.DB.account.items)

    if character then
        local professionNames = {}
        for _, profession in ipairs(character.professions or {}) do
            professionNames[#professionNames + 1] = string.format("%s %d/%d", profession.name, profession.skill or 0, profession.maxSkill or 0)
        end
        local professionText = #professionNames > 0 and table.concat(professionNames, "  •  ") or "No professions detected"
        setText(page.characterInfo, string.format("%s — Level %d %s\n%s\n%s\nAccount cache: %d characters • %d recipes • %d item types",
            character.name or "Unknown",
            tonumber(character.level) or 0,
            character.className or "",
            character.realm or "",
            professionText,
            knownCharacters,
            cachedRecipes,
            cachedItems))
    else
        setText(page.characterInfo, "Character data has not been scanned yet.", Theme.colors.muted)
    end

    local sortedCharacters = getSortedCharacters()
    local currentKey = FC:GetCharacterKey()
    for i = 1, #page.accountLines do
        local entry = sortedCharacters[i]
        if entry then
            local data = entry.data
            local marker = entry.key == currentKey and "◆ " or "  "
            local text = string.format("%s%s  •  L%d %s", marker, tostring(data.name or "Unknown"), tonumber(data.level) or 0, tostring(data.className or ""))
            setText(page.accountLines[i], text, entry.key == currentKey and Theme.colors.green or Theme.colors.text)
        elseif i == 1 then
            setText(page.accountLines[i], "No cached characters yet.", Theme.colors.muted)
        else
            setText(page.accountLines[i], "")
        end
    end

    local suggestions = FC.Suggestions:GetTop(#page.suggestionLines)
    for i = 1, #page.suggestionLines do
        local suggestion = suggestions[i]
        if suggestion then
            local text = string.format("%d.  %s\n     %s",
                i,
                tostring(suggestion.title or suggestion.category),
                tostring(suggestion.description or suggestion.category or ""))
            local color = suggestion.priority and suggestion.priority >= 80 and Theme.colors.red
                or (suggestion.priority and suggestion.priority >= 60 and Theme.colors.yellow or Theme.colors.text)
            setText(page.suggestionLines[i], text, color)
        elseif i == 1 then
            setText(page.suggestionLines[i], "No urgent suggestions right now.\nYour journey looks tidy.", Theme.colors.green)
        else
            setText(page.suggestionLines[i], "")
        end
    end
end

local function refreshProfessions(page, character)
    local professions = character and character.professions or {}
    for i = 1, #page.skillLines do
        local profession = professions[i]
        if profession then
            local recipeStats = getRecipeStats(character, profession)
            local recipeText = recipeStats and string.format(" • %d/%d recipes", recipeStats.learned or 0, recipeStats.total or 0) or ""
            local remaining = math.max(0, (profession.maxSkill or 0) - (profession.skill or 0))
            setText(page.skillLines[i], string.format("%s  %d / %d%s%s",
                profession.name,
                profession.skill or 0,
                profession.maxSkill or 0,
                recipeText,
                remaining > 0 and string.format("  • %d to cap", remaining) or ""))
        elseif i == 1 then
            setText(page.skillLines[i], "No professions detected yet.", Theme.colors.muted)
        else
            setText(page.skillLines[i], "")
        end
    end

    local recipes = getTrackedRecipes()
    for i = 1, #page.recipeButtons do
        local button = page.recipeButtons[i]
        local recipe = recipes[i]
        if recipe then
            button.recipeID = recipe.recipeID
            button:Show()
            button:SetFCText((recipe.tracked and "✓  " or "+  ") .. tostring(recipe.name))
            button:SetFCActive(recipe.tracked)
        else
            button.recipeID = nil
            button:Hide()
        end
    end

    local goals = FC.CraftingGoals and FC.CraftingGoals:GetGoals() or {}
    local lineIndex = 1
    for _, goal in ipairs(goals) do
        if lineIndex > #page.goalLines then
            break
        end

        local progress = FC.CraftingGoals:GetProgress(goal)
        local status = progress.ready and "READY" or string.format("%d material type(s) missing", progress.missingKinds)
        setText(page.goalLines[lineIndex], string.format("%s  x%d  —  %s",
            tostring(goal.name),
            tonumber(goal.quantity) or 1,
            status),
            progress.ready and Theme.colors.green or Theme.colors.gold)
        lineIndex = lineIndex + 1

        for _, reagent in ipairs(progress.reagents) do
            if lineIndex > #page.goalLines then
                break
            end

            if reagent.itemID then
                local text = string.format("   %s  %d / %d", tostring(reagent.name or ("Item " .. reagent.itemID)), reagent.available, reagent.needed)
                local color = reagent.missing > 0 and Theme.colors.yellow or Theme.colors.muted
                setText(page.goalLines[lineIndex], text, color)
                lineIndex = lineIndex + 1
            elseif reagent.ambiguous then
                setText(page.goalLines[lineIndex], "   Choice reagent — select material in profession UI", Theme.colors.muted)
                lineIndex = lineIndex + 1
            end
        end
    end

    if #goals == 0 then
        setText(page.goalLines[1], "No crafting goals pinned yet.", Theme.colors.muted)
        lineIndex = 2
    end

    for i = lineIndex, #page.goalLines do
        setText(page.goalLines[i], "")
    end
end

local function refreshInventory(page)
    local query = tostring(UI.inventoryQuery or "")
    if page.searchBox and not page.searchBox:HasFocus() and page.searchBox:GetText() ~= query then
        page.searchBox:SetText(query)
    end

    local matches = {}
    if query ~= "" and FC.Inventory then
        matches = FC.Inventory:Find(query, #page.resultLines)
    end

    for i = 1, #page.resultLines do
        local item = matches[i]
        if item then
            local owners = {}
            for key, owner in pairs(item.characters or {}) do
                owners[#owners + 1] = string.format("%s: %d", key, tonumber(owner.count) or 0)
            end
            table.sort(owners)
            local ownerText = #owners > 0 and table.concat(owners, "  •  ") or "No owner cache"
            setText(page.resultLines[i], string.format("%s  x%d\n   %s",
                tostring(item.name or ("Item " .. tostring(item.itemID))),
                tonumber(item.total) or 0,
                ownerText))
        elseif i == 1 then
            if query == "" then
                setText(page.resultLines[i], "Type an item name or item ID above.\nResults use the account cache collected while characters are logged in.", Theme.colors.muted)
            else
                setText(page.resultLines[i], "No cached match for \"" .. query .. "\".", Theme.colors.muted)
            end
        else
            setText(page.resultLines[i], "")
        end
    end
end

local function refreshPreparation(page, character)
    local preparation = character and character.preparation or {}
    local freeSlots = preparation and preparation.freeBagSlots
    local durability = preparation and preparation.lowestDurability

    local bagColor = freeSlots and (freeSlots <= 2 and Theme.colors.red or (freeSlots <= 5 and Theme.colors.yellow or Theme.colors.green)) or Theme.colors.muted
    local duraColor = durability and (durability <= 25 and Theme.colors.red or (durability <= 50 and Theme.colors.yellow or Theme.colors.green)) or Theme.colors.green

    setText(page.checkLines[1], freeSlots and string.format("✓  Free bag slots: %d", freeSlots) or "?  Bag space unavailable", bagColor)
    setText(page.checkLines[2], durability and string.format("✓  Lowest durability: %.0f%%", durability) or "✓  No damaged equipment detected", duraColor)
    setText(page.checkLines[3], "✓  Character cache active", Theme.colors.green)
    setText(page.checkLines[4], FC.API.capabilities.containers and "✓  Inventory API available" or "!  Inventory API unavailable",
        FC.API.capabilities.containers and Theme.colors.green or Theme.colors.yellow)
    setText(page.checkLines[5], FC.API.capabilities.recipeSchematic and "✓  Crafting material API available" or "!  Crafting material API unavailable",
        FC.API.capabilities.recipeSchematic and Theme.colors.green or Theme.colors.yellow)
    setText(page.checkLines[6], "•  Class-specific consumables: next milestone", Theme.colors.muted)
    setText(page.checkLines[7], "•  Hearthstone / ammo / reagents: research in progress", Theme.colors.muted)
    setText(page.checkLines[8], "•  Camp preparation: waiting for verified Forever API", Theme.colors.muted)

    local suggestions = FC.Suggestions:GetTop(12)
    local index = 1
    for _, suggestion in ipairs(suggestions) do
        if suggestion.category == "Preparation" and index <= #page.infoLines then
            setText(page.infoLines[index], "• " .. tostring(suggestion.title) .. "\n  " .. tostring(suggestion.description or ""), Theme.colors.yellow)
            index = index + 1
        end
    end

    if index == 1 then
        setText(page.infoLines[1], "No preparation warning is currently active.", Theme.colors.green)
        index = 2
    end
    for i = index, #page.infoLines do
        setText(page.infoLines[i], "")
    end
end

local function refreshJourney(page)
    local mode = FC.DB and FC.DB.settings and FC.DB.settings.discoveryMode or "BALANCED"
    for _, button in ipairs(page.modeButtons) do
        button:SetFCActive(button.mode == mode)
    end

    local status = {
        { "Legacy", FC.API.capabilities.legacy, "API research pending — hidden until verified." },
        { "Travel", false, "Flight-point enumeration research pending." },
        { "Journey", false, "Zone-opportunity engine planned after travel data." },
        { "Camps", FC.API.capabilities.camps, "Camp API research pending." },
        { "Maps", FC.API.capabilities.maps, "Base map capability detected." },
    }

    for i = 1, #page.statusLines do
        local row = status[i]
        if row then
            local prefix = row[2] and "✓" or "•"
            local color = row[2] and Theme.colors.green or Theme.colors.muted
            setText(page.statusLines[i], string.format("%s  %s\n    %s", prefix, row[1], row[3]), color)
        else
            setText(page.statusLines[i], "")
        end
    end

    local roadmap = {
        "1. Crafting goals + cross-character materials",
        "2. Preparation rules by class",
        "3. Legacy API research and tracker",
        "4. Travel / flight point capability research",
        "5. Discovery-mode Journey suggestions",
    }
    for i = 1, #page.roadmapLines do
        setText(page.roadmapLines[i], roadmap[i] or "", i == 1 and Theme.colors.gold or Theme.colors.text)
    end
end

function UI:RefreshDashboard()
    local frame = self:CreateMainFrame()
    local character = FC:GetCurrentCharacter()

    frame.subtitle:SetText(string.format("WoW Forever • Interface %s • %d suggestion(s) • %s mode",
        tostring(FC.Client.interface or "?"),
        FC.Suggestions:Count(),
        tostring(FC.DB and FC.DB.settings and FC.DB.settings.discoveryMode or "BALANCED")))

    refreshOverview(frame.pages.Overview, character)
    refreshProfessions(frame.pages.Professions, character)
    refreshInventory(frame.pages.Inventory)
    refreshPreparation(frame.pages.Preparation, character)
    refreshJourney(frame.pages.Journey)
end

function UI:Toggle()
    local frame = self:CreateMainFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        FC:RefreshModules("window-open")
        self:SwitchTab(self.activeTab or "Overview")
        frame:Show()
    end
end
