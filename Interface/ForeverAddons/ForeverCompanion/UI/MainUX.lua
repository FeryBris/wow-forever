local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local FEATURE_GROUPS = {
    {
        title = "ACCOUNT & COLLECTION",
        tools = {
            { label = "Characters", method = "ShowCharacters", module = "Characters" },
            { label = "Account Recipes", method = "ShowAccountRecipes", module = "AccountRecipes" },
            { label = "Item Intelligence", method = "ShowItems", module = "Items" },
            { label = "Milestones", method = "ShowMilestones", module = "Milestones" },
        },
    },
    {
        title = "PROGRESS & JOURNEY",
        tools = {
            { label = "Smart Suggestions", method = "ShowSuggestions" },
            { label = "Legacy", method = "ShowLegacyTracker", module = "Legacy" },
            { label = "Journey", method = "ShowJourney", module = "Journey" },
            { label = "Goals", method = "ShowGoals", module = "Goals" },
        },
    },
    {
        title = "PREPARE & TRAVEL",
        tools = {
            { label = "Preparation", method = "ShowPreparationChecklist", module = "PreparationChecklist" },
            { label = "Camps", method = "ShowCamps", module = "Camps" },
            { label = "Travel", method = "ShowTravel", module = "Travel" },
            { label = "Routes", method = "ShowTravelRoutes", modules = { "Travel", "TravelRoutes" } },
            { label = "Groups", method = "ShowGroups", module = "Groups" },
        },
    },
    {
        title = "TOOLS",
        tools = {
            { label = "Profession Planner", method = "ShowProfessionPlanner", module = "ProfessionPlanner" },
            { label = "Recipe Sources", method = "ShowRecipeSources", module = "RecipeSources" },
            { label = "Cache Manager", method = "ShowCacheManager" },
            { label = "Planning Transfer", method = "ShowDataTransfer" },
            { label = "Settings", method = "ShowSettings" },
            { label = "Diagnostics", method = "ShowDiagnostics" },
        },
    },
}

local function toolRequirements(tool)
    if type(tool.modules) == "table" then return tool.modules end
    if tool.module then return { tool.module } end
    return {}
end

local function isToolAvailable(tool)
    if type(UI[tool.method]) ~= "function" then return false end
    for _, moduleName in ipairs(toolRequirements(tool)) do
        if not FC:IsModuleEnabled(moduleName) then return false end
    end
    return true
end

local function openTool(tool)
    if not isToolAvailable(tool) then
        if #toolRequirements(tool) > 0 and type(UI.ShowSettings) == "function" then
            UI:ShowSettings()
        end
        return false
    end
    UI[tool.method](UI)
    return true
end

local function openSearchResult(result)
    if not result then return end
    if result.kind == "Item" and UI.ShowItems then
        UI:ShowItems(result.id)
    elseif result.kind == "Character" and UI.ShowCharacters then
        UI:ShowCharacters()
    elseif result.kind == "Goal" and UI.ShowGoals then
        UI:ShowGoals()
    elseif result.kind == "Legacy" and UI.ShowLegacyTracker then
        UI:ShowLegacyTracker()
    elseif result.kind == "Route" and UI.ShowTravelRoutes then
        UI:ShowTravelRoutes()
    elseif result.kind == "Checklist" and UI.ShowPreparationChecklist then
        UI:ShowPreparationChecklist()
    elseif result.kind == "Recipe" and UI.ShowRecipeSources and FC:IsModuleEnabled("RecipeSources") then
        UI:ShowRecipeSources(result.id)
    elseif result.kind == "Recipe" and UI.ShowAccountRecipes then
        UI:ShowAccountRecipes()
    end
end

local function createSearchResults(frame)
    local panel = Theme:CreatePanel(frame, Theme.colors.panel, Theme.colors.blueSoft)
    panel:SetSize(520, 304)
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel((frame:GetFrameLevel() or 0) + 20)
    panel:EnableMouse(true)
    panel:Hide()

    panel.title = Theme:CreateText(panel, "GameFontNormalSmall", "SEARCH RESULTS")
    panel.title:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -10)
    panel.title:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])

    panel.rows = {}
    for i = 1, 7 do
        local row = Theme:CreateButton(panel, "", 496, 34)
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -34 - ((i - 1) * 36))
        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", row, "LEFT", 9, 0)
        row.label:SetPoint("RIGHT", row, "RIGHT", -9, 0)
        row.label:SetJustifyH("LEFT")
        row:SetScript("OnClick", function(self)
            local result = self.searchResult
            panel:Hide()
            if frame.fcSearchBox then frame.fcSearchBox:ClearFocus() end
            openSearchResult(result)
        end)
        panel.rows[i] = row
    end

    panel.footer = Theme:CreateText(panel, "GameFontDisableSmall", "")
    panel.footer:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 12, 9)
    panel.footer:SetWidth(496)
    panel.footer:SetJustifyH("LEFT")

    return panel
end

local function refreshInlineSearch(frame, forceShow)
    if not frame.fcSearchBox or not frame.fcSearchResults then return end
    local query = tostring(frame.fcSearchBox:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local panel = frame.fcSearchResults

    if query == "" then
        panel:Hide()
        return
    end

    local results = FC.Search and FC.Search:Query(query, #panel.rows) or {}
    panel.currentResults = results

    for i, row in ipairs(panel.rows) do
        local result = results[i]
        if result then
            row.searchResult = result
            row:SetFCText(string.format("[%s]  %s  —  %s", tostring(result.kindLabel or result.kind), tostring(result.title), tostring(result.subtitle or "")))
            row:Show()
        else
            row.searchResult = nil
            row:Hide()
        end
    end

    if #results == 0 then
        panel.footer:SetText(FC:GetText("GLOBAL_SEARCH_NO_MATCH"))
    else
        panel.footer:SetText(FC:GetText("INLINE_SEARCH_RESULT_COUNT", #results))
    end

    if forceShow or #query >= 2 then panel:Show() end
end

local function createFeatureDrawer(frame)
    local drawer = Theme:CreatePanel(frame, Theme.colors.navy, Theme.colors.gold)
    drawer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -70)
    drawer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 16)
    drawer:SetWidth(356)
    drawer:SetFrameStrata("DIALOG")
    drawer:SetFrameLevel((frame:GetFrameLevel() or 0) + 15)
    drawer:EnableMouse(true)
    drawer:Hide()

    drawer.title = Theme:CreateText(drawer, "GameFontNormalLarge", "COMPANION FEATURES")
    drawer.title:SetPoint("TOPLEFT", drawer, "TOPLEFT", 16, -14)
    drawer.title:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])

    drawer.close = Theme:CreateButton(drawer, "X", 30, 28)
    drawer.close:SetPoint("TOPRIGHT", drawer, "TOPRIGHT", -12, -10)
    drawer.close:SetScript("OnClick", function() drawer:Hide() end)

    drawer.entries = {}
    local y = -48
    for _, group in ipairs(FEATURE_GROUPS) do
        local heading = Theme:CreateText(drawer, "GameFontNormalSmall", group.title)
        heading:SetPoint("TOPLEFT", drawer, "TOPLEFT", 16, y)
        heading:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3])
        y = y - 22

        for index, tool in ipairs(group.tools) do
            local column = (index - 1) % 2
            local rowIndex = math.floor((index - 1) / 2)
            local button = Theme:CreateButton(drawer, tool.label, 153, 30)
            button:SetPoint("TOPLEFT", drawer, "TOPLEFT", 16 + (column * 163), y - (rowIndex * 36))
            button.fcTool = tool
            button:SetScript("OnClick", function(self)
                if openTool(self.fcTool) then drawer:Hide() end
            end)
            drawer.entries[#drawer.entries + 1] = button
        end

        y = y - (math.ceil(#group.tools / 2) * 36) - 12
    end

    function drawer:Refresh()
        for _, button in ipairs(self.entries) do
            local available = isToolAvailable(button.fcTool)
            button:SetAlpha(available and 1 or 0.35)
            button:EnableMouse(true)
        end
    end

    return drawer
end

local previousCreateMainFrame = UI.CreateMainFrame
function UI:CreateMainFrame(...)
    local frame = previousCreateMainFrame(self, ...)
    if not frame or frame.fcPrimaryUX then return frame end
    frame.fcPrimaryUX = true

    for _, key in ipairs({ "fcGoalsButton", "fcSettingsButton", "fcGroupsButton" }) do
        local oldButton = frame[key]
        if oldButton then
            oldButton:Hide()
            oldButton:EnableMouse(false)
        end
    end
    if frame.fcHubButton then
        frame.fcHubButton:Hide()
        frame.fcHubButton:EnableMouse(false)
    end

    local search = CreateFrame("EditBox", nil, frame.header, "InputBoxTemplate")
    search:SetSize(270, 30)
    search:SetPoint("TOP", frame.header, "TOP", 34, -13)
    search:SetAutoFocus(false)
    search:SetTextInsets(26, 8, 0, 0)
    frame.fcSearchBox = search

    local searchIcon = Theme:CreateText(search, "GameFontNormal", "⌕")
    searchIcon:SetPoint("LEFT", search, "LEFT", 8, 0)
    searchIcon:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3])

    local hint = Theme:CreateText(search, "GameFontDisableSmall", "Search everything…")
    hint:SetPoint("LEFT", search, "LEFT", 27, 0)
    hint:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3])
    frame.fcSearchHint = hint

    local results = createSearchResults(frame)
    results:SetPoint("TOP", search, "BOTTOM", 0, -5)
    frame.fcSearchResults = results

    search:SetScript("OnTextChanged", function(self)
        hint:SetShown(self:GetText() == "")
        refreshInlineSearch(frame, false)
    end)
    search:SetScript("OnEditFocusGained", function(self)
        hint:SetShown(self:GetText() == "")
        if self:GetText() ~= "" then refreshInlineSearch(frame, true) end
    end)
    search:SetScript("OnEditFocusLost", function() end)
    search:SetScript("OnEnterPressed", function(self)
        local first = frame.fcSearchResults.currentResults and frame.fcSearchResults.currentResults[1]
        self:ClearFocus()
        frame.fcSearchResults:Hide()
        if first then openSearchResult(first) end
    end)
    search:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        frame.fcSearchResults:Hide()
    end)

    local features = Theme:CreateButton(frame.header, "Features", 86, 30)
    features:SetPoint("RIGHT", frame.refreshButton, "LEFT", -8, 0)
    frame.fcFeaturesButton = features

    local drawer = createFeatureDrawer(frame)
    frame.fcFeatureDrawer = drawer
    features:SetScript("OnClick", function()
        if drawer:IsShown() then
            drawer:Hide()
        else
            drawer:Refresh()
            drawer:Show()
        end
    end)

    frame.refreshButton:SetFCText("Refresh")
    return frame
end

local previousRefreshDashboard = UI.RefreshDashboard
function UI:RefreshDashboard(...)
    previousRefreshDashboard(self, ...)
    local frame = self.frame
    if frame and frame.fcFeatureDrawer and frame.fcFeatureDrawer:IsShown() then
        frame.fcFeatureDrawer:Refresh()
    end
end
