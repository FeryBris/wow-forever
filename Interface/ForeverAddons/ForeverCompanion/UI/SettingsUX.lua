local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local CATEGORIES = {
    { key = "ALL", labelKey = "SETTINGS_CATEGORY_ALL" },
    { key = "PROGRESS", labelKey = "SETTINGS_CATEGORY_PROGRESS" },
    { key = "ADVENTURE", labelKey = "SETTINGS_CATEGORY_ADVENTURE" },
    { key = "UTILITY", labelKey = "SETTINGS_CATEGORY_UTILITY" },
}

local MODULE_CATEGORY = {
    Professions = "PROGRESS",
    CraftingGoals = "PROGRESS",
    ProfessionPlanner = "PROGRESS",
    AccountRecipes = "PROGRESS",
    RecipeSources = "PROGRESS",
    Legacy = "PROGRESS",
    Goals = "PROGRESS",
    Milestones = "PROGRESS",

    Camps = "ADVENTURE",
    Travel = "ADVENTURE",
    TravelRoutes = "ADVENTURE",
    Journey = "ADVENTURE",
    Groups = "ADVENTURE",

    Inventory = "UTILITY",
    Items = "UTILITY",
    Preparation = "UTILITY",
    PreparationChecklist = "UTILITY",
}

local CATEGORY_HINT_KEYS = {
    ALL = "SETTINGS_HINT_ALL",
    PROGRESS = "SETTINGS_HINT_PROGRESS",
    ADVENTURE = "SETTINGS_HINT_ADVENTURE",
    UTILITY = "SETTINGS_HINT_UTILITY",
}

local function collectModuleButtons(frame)
    local result = {}
    for _, button in ipairs(frame.moduleButtons or {}) do result[#result + 1] = button end
    for _, button in ipairs(frame.extraModuleButtons or {}) do result[#result + 1] = button end
    return result
end

local function applyCategoryLabels(frame)
    for index, info in ipairs(CATEGORIES) do
        local button = frame.fcCategoryButtons and frame.fcCategoryButtons[index]
        if button and button.SetFCText then button:SetFCText(FC:GetText(info.labelKey)) end
    end
end

local function layoutModuleButtons(frame)
    local selected = frame.fcSettingsCategory or "ALL"
    local visible = {}

    for _, button in ipairs(collectModuleButtons(frame)) do
        local category = MODULE_CATEGORY[button.moduleName] or "UTILITY"
        local show = selected == "ALL" or category == selected
        button:SetShown(show)
        if show then visible[#visible + 1] = button end
    end

    for index, button in ipairs(visible) do
        button:ClearAllPoints()
        local column = (index - 1) % 4
        local row = math.floor((index - 1) / 4)
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", 24 + (column * 202), -420 - (row * 48))
        button:SetSize(192, 38)
    end

    for _, filter in ipairs(frame.fcCategoryButtons or {}) do
        filter:SetFCActive(filter.categoryKey == selected)
    end

    applyCategoryLabels(frame)
    if frame.fcCategoryHint then
        frame.fcCategoryHint:SetText(FC:GetText(CATEGORY_HINT_KEYS[selected] or "SETTINGS_HINT_ALL"))
    end
    if frame.note then frame.note:SetText(FC:GetText("SETTINGS_CHANGE_NOTE")) end
end

local previousCreateSettingsFrame = UI.CreateSettingsFrame
function UI:CreateSettingsFrame(...)
    local frame = previousCreateSettingsFrame(self, ...)
    if not frame or frame.fcGroupedSettings then return frame end
    frame.fcGroupedSettings = true
    frame:SetSize(860, 700)
    frame.fcSettingsCategory = frame.fcSettingsCategory or "ALL"

    if frame.modulesTitle then
        frame.modulesTitle:ClearAllPoints()
        frame.modulesTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -342)
    end

    frame.fcCategoryButtons = {}
    for index, info in ipairs(CATEGORIES) do
        local button = Theme:CreateButton(frame, FC:GetText(info.labelKey), 108, 30)
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", 24 + ((index - 1) * 116), -370)
        button.categoryKey = info.key
        button:SetScript("OnClick", function(self)
            frame.fcSettingsCategory = self.categoryKey
            layoutModuleButtons(frame)
        end)
        frame.fcCategoryButtons[index] = button
    end

    frame.fcCategoryHint = Theme:CreateText(frame, "GameFontDisableSmall", "")
    frame.fcCategoryHint:SetPoint("LEFT", frame.fcCategoryButtons[#frame.fcCategoryButtons], "RIGHT", 14, 0)
    frame.fcCategoryHint:SetWidth(330)
    frame.fcCategoryHint:SetJustifyH("LEFT")

    layoutModuleButtons(frame)
    return frame
end

local previousRefreshSettingsView = UI.RefreshSettingsView
function UI:RefreshSettingsView(...)
    previousRefreshSettingsView(self, ...)
    local frame = self.settingsFrame
    if frame and frame.fcGroupedSettings then layoutModuleButtons(frame) end
end
