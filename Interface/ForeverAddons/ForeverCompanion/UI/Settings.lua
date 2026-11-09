local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local moduleKeys = {
    { name = "Professions", key = "PROFESSIONS" },
    { name = "CraftingGoals", key = "CRAFTING_GOALS" },
    { name = "ProfessionPlanner", key = "PROFESSION_PLANNER" },
    { name = "AccountRecipes", key = "ACCOUNT_RECIPES" },
    { name = "Inventory", key = "INVENTORY" },
    { name = "Items", key = "ITEM_INTELLIGENCE" },
    { name = "Preparation", key = "PREPARATION" },
    { name = "PreparationChecklist", key = "PREPARATION_CHECKLIST" },
    { name = "Legacy", key = "LEGACY" },
    { name = "Camps", key = "CAMPS" },
    { name = "Travel", key = "TRAVEL" },
    { name = "Journey", key = "JOURNEY" },
    { name = "Goals", key = "GOALS" },
    { name = "Groups", key = "GROUPS" },
    { name = "Milestones", key = "MILESTONES" },
}

local function refreshLocaleDependentViews()
    if type(FC.RefreshModules) == "function" then FC:RefreshModules("locale-change") end
    if UI.frame and UI.frame:IsShown() and UI.RefreshDashboard then UI:RefreshDashboard() end
    if UI.suggestionsFrame and UI.suggestionsFrame:IsShown() and UI.RefreshSuggestionsView then UI:RefreshSuggestionsView() end
    if UI.charactersFrame and UI.charactersFrame:IsShown() and UI.RefreshCharactersView then UI:RefreshCharactersView() end
    if UI.accountRecipesFrame and UI.accountRecipesFrame:IsShown() and UI.RefreshAccountRecipesView then UI:RefreshAccountRecipesView() end
    if UI.professionPlannerFrame and UI.professionPlannerFrame:IsShown() and UI.RefreshProfessionPlannerView then UI:RefreshProfessionPlannerView() end
    if UI.preparationChecklistFrame and UI.preparationChecklistFrame:IsShown() and UI.RefreshPreparationChecklistView then UI:RefreshPreparationChecklistView() end
end

function UI:CreateSettingsFrame()
    if self.settingsFrame then return self.settingsFrame end

    local frame = Theme:CreatePanel(UIParent, Theme.colors.navy, Theme.colors.gold)
    frame:SetSize(820, 640)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    frame.title = Theme:CreateText(frame, "GameFontNormalHuge", "")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -18)
    frame.title:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])

    frame.closeButton = Theme:CreateButton(frame, "X", 32, 30)
    frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -14)
    frame.closeButton:SetScript("OnClick", function() frame:Hide() end)

    frame.discoveryTitle = Theme:CreateSectionTitle(frame, "")
    frame.discoveryTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -76)
    frame.discoveryButtons = {}
    local modes = { "EXPLORER", "BALANCED", "GUIDE" }
    for i, mode in ipairs(modes) do
        local button = Theme:CreateButton(frame, mode, 145, 34)
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", 24 + ((i - 1) * 155), -108)
        button.mode = mode
        button:SetScript("OnClick", function(self)
            FC.DB.settings.discoveryMode = self.mode
            if FC.Travel and FC:IsModuleEnabled("Travel") then FC.Travel:Refresh("settings") end
            if FC.Journey and FC:IsModuleEnabled("Journey") then FC.Journey:Refresh("settings") end
            UI:RefreshSettingsView()
            if UI.frame and UI.frame:IsShown() then UI:RefreshDashboard() end
        end)
        frame.discoveryButtons[i] = button
    end

    frame.languageTitle = Theme:CreateSectionTitle(frame, "")
    frame.languageTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -164)
    frame.languageButtons = {}
    local locales = {
        { value = "AUTO", key = "LANGUAGE_AUTO" },
        { value = "enUS", key = "LANGUAGE_ENGLISH" },
        { value = "deDE", key = "LANGUAGE_GERMAN" },
    }
    for i, locale in ipairs(locales) do
        local button = Theme:CreateButton(frame, locale.value, 145, 34)
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", 24 + ((i - 1) * 155), -196)
        button.localeValue = locale.value
        button.localeKey = locale.key
        button:SetScript("OnClick", function(self)
            FC.DB.settings.locale = self.localeValue
            refreshLocaleDependentViews()
            UI:RefreshSettingsView()
        end)
        frame.languageButtons[i] = button
    end

    frame.generalTitle = Theme:CreateSectionTitle(frame, "General")
    frame.generalTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -252)

    frame.minimapButton = Theme:CreateButton(frame, "", 220, 34)
    frame.minimapButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -284)
    frame.minimapButton:SetScript("OnClick", function()
        local enabled = FC.DB.settings.minimapButton ~= false
        local minimap = UI.Minimap
        if minimap then
            minimap:Create()
            minimap:SetShown(not enabled)
        else
            FC.DB.settings.minimapButton = not enabled
        end
        UI:RefreshSettingsView()
    end)

    frame.debugButton = Theme:CreateButton(frame, "", 220, 34)
    frame.debugButton:SetPoint("LEFT", frame.minimapButton, "RIGHT", 12, 0)
    frame.debugButton:SetScript("OnClick", function()
        FC.DB.settings.debug = not FC.DB.settings.debug
        UI:RefreshSettingsView()
    end)

    frame.modulesTitle = Theme:CreateSectionTitle(frame, "")
    frame.modulesTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -340)
    frame.moduleButtons = {}
    for i, moduleInfo in ipairs(moduleKeys) do
        local column = (i - 1) % 4
        local row = math.floor((i - 1) / 4)
        local button = Theme:CreateButton(frame, moduleInfo.name, 184, 38)
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", 24 + (column * 194), -372 - (row * 48))
        button.moduleName = moduleInfo.name
        button.localeKey = moduleInfo.key
        button:SetScript("OnClick", function(self)
            local enabled = FC:IsModuleEnabled(self.moduleName)
            FC:SetModuleEnabled(self.moduleName, not enabled)
            UI:RefreshSettingsView()
        end)
        frame.moduleButtons[i] = button
    end

    frame.note = Theme:CreateText(frame, "GameFontDisableSmall",
        "Module changes apply immediately. Character scanning and the external provider bridge remain core dependencies and are intentionally not exposed as toggles here.")
    frame.note:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 18)
    frame.note:SetWidth(772)
    frame.note:SetJustifyH("LEFT")

    self.settingsFrame = frame
    return frame
end

function UI:RefreshSettingsView()
    local frame = self.settingsFrame
    if not frame then return end

    frame.title:SetText(FC:GetText("SETTINGS_TITLE"))
    frame.discoveryTitle:SetText(FC:GetText("DISCOVERY_MODE"))
    frame.languageTitle:SetText(FC:GetText("LANGUAGE"))
    frame.modulesTitle:SetText(FC:GetText("MODULES"))

    local currentMode = FC.DB and FC.DB.settings and FC.DB.settings.discoveryMode or "BALANCED"
    for _, button in ipairs(frame.discoveryButtons) do
        button:SetFCText(FC:GetText(button.mode))
        button:SetFCActive(button.mode == currentMode)
    end

    local currentLocale = FC.DB and FC.DB.settings and FC.DB.settings.locale or "AUTO"
    for _, button in ipairs(frame.languageButtons) do
        button:SetFCText(FC:GetText(button.localeKey))
        button:SetFCActive(button.localeValue == currentLocale)
    end

    local minimapEnabled = FC.DB and FC.DB.settings and FC.DB.settings.minimapButton ~= false
    frame.minimapButton:SetFCText(FC:GetText("MINIMAP_BUTTON") .. ": " .. FC:GetText(minimapEnabled and "ENABLED" or "DISABLED"))
    frame.minimapButton:SetFCActive(minimapEnabled)

    local debugEnabled = FC.DB and FC.DB.settings and FC.DB.settings.debug == true
    frame.debugButton:SetFCText(FC:GetText("DEBUG_LOGGING") .. ": " .. FC:GetText(debugEnabled and "ENABLED" or "DISABLED"))
    frame.debugButton:SetFCActive(debugEnabled)

    for _, button in ipairs(frame.moduleButtons) do
        local enabled = FC:IsModuleEnabled(button.moduleName)
        button:SetFCText(FC:GetText(button.localeKey) .. ": " .. FC:GetText(enabled and "ENABLED" or "DISABLED"))
        button:SetFCActive(enabled)
    end
end

function UI:ShowSettings()
    local frame = self:CreateSettingsFrame()
    self:RefreshSettingsView()
    frame:Show()
end

local previousCreateMainFrame = UI.CreateMainFrame
function UI:CreateMainFrame(...)
    local frame = previousCreateMainFrame(self, ...)
    if frame and not frame.fcSettingsButton and frame.header then
        local button = Theme:CreateButton(frame.header, FC:GetText("SETTINGS"), 95, 30)
        local anchor = frame.fcGoalsButton or frame.refreshButton
        button:SetPoint("RIGHT", anchor, "LEFT", -8, 0)
        button:SetScript("OnClick", function() UI:ShowSettings() end)
        frame.fcSettingsButton = button
    end
    return frame
end
