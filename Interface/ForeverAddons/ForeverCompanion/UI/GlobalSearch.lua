local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme
local PAGE_SIZE = 10

local function setText(fontString, text, color)
    if not fontString then return end
    color = color or Theme.colors.text
    fontString:SetText(text or "")
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function openResult(result)
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

local function refreshResults(frame)
    local query = frame.search:GetText() or ""
    frame.results = query ~= "" and FC.Search and FC.Search:Query(query, 250) or {}
    local maxPage = math.max(1, math.ceil(#frame.results / PAGE_SIZE))
    frame.page = math.max(1, math.min(tonumber(frame.page) or 1, maxPage))
end

function UI:CreateGlobalSearchFrame()
    if self.globalSearchFrame then return self.globalSearchFrame end

    local frame = Theme:CreatePanel(UIParent, Theme.colors.navy, Theme.colors.gold)
    frame:SetSize(850, 650)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()
    frame.page = 1

    frame.title = Theme:CreateText(frame, "GameFontNormalHuge", FC:GetText("WINDOW_GLOBAL_SEARCH"))
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -18)
    frame.title:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])

    frame.closeButton = Theme:CreateButton(frame, "X", 32, 30)
    frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -14)
    frame.closeButton:SetScript("OnClick", function() frame:Hide() end)

    frame.search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.search:SetSize(620, 32)
    frame.search:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -68)
    frame.search:SetAutoFocus(false)
    frame.search:SetTextInsets(8, 8, 0, 0)

    frame.searchButton = Theme:CreateButton(frame, FC:GetText("SEARCH"), 110, 32)
    frame.searchButton:SetPoint("LEFT", frame.search, "RIGHT", 12, 0)

    frame.summary = Theme:CreateText(frame, "GameFontHighlightSmall", FC:GetText("GLOBAL_SEARCH_HELP"))
    frame.summary:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -112)
    frame.summary:SetWidth(800)
    frame.summary:SetJustifyH("LEFT")
    frame.summary:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3])

    frame.rows = {}
    for i = 1, PAGE_SIZE do
        local row = Theme:CreateButton(frame, "", 800, 40)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -144 - ((i - 1) * 43))
        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", row, "LEFT", 10, 0)
        row.label:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        row.label:SetJustifyH("LEFT")
        row:SetScript("OnClick", function(self)
            openResult(self.searchResult)
        end)
        frame.rows[i] = row
    end

    frame.prevButton = Theme:CreateButton(frame, FC:GetText("PREVIOUS"), 100, 28)
    frame.prevButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 52)
    frame.nextButton = Theme:CreateButton(frame, FC:GetText("NEXT"), 100, 28)
    frame.nextButton:SetPoint("LEFT", frame.prevButton, "RIGHT", 8, 0)
    frame.pageText = Theme:CreateText(frame, "GameFontHighlightSmall", "")
    frame.pageText:SetPoint("LEFT", frame.nextButton, "RIGHT", 12, 0)

    frame.prevButton:SetScript("OnClick", function()
        frame.page = math.max(1, (frame.page or 1) - 1)
        UI:RefreshGlobalSearchView()
    end)
    frame.nextButton:SetScript("OnClick", function()
        local maxPage = math.max(1, math.ceil(#(frame.results or {}) / PAGE_SIZE))
        frame.page = math.min(maxPage, (frame.page or 1) + 1)
        UI:RefreshGlobalSearchView()
    end)

    frame.note = Theme:CreateText(frame, "GameFontDisableSmall", FC:GetText("GLOBAL_SEARCH_NOTE"))
    frame.note:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 18)
    frame.note:SetWidth(800)
    frame.note:SetJustifyH("LEFT")

    local function runSearch()
        frame.search:ClearFocus()
        frame.page = 1
        refreshResults(frame)
        UI:RefreshGlobalSearchView()
    end
    frame.searchButton:SetScript("OnClick", runSearch)
    frame.search:SetScript("OnEnterPressed", runSearch)

    self.globalSearchFrame = frame
    return frame
end

function UI:RefreshGlobalSearchView()
    local frame = self:CreateGlobalSearchFrame()
    local query = frame.search:GetText() or ""
    local results = frame.results or {}
    local maxPage = math.max(1, math.ceil(#results / PAGE_SIZE))
    frame.page = math.max(1, math.min(frame.page or 1, maxPage))

    if query == "" then
        setText(frame.summary, FC:GetText("GLOBAL_SEARCH_HELP"), Theme.colors.muted)
    else
        setText(frame.summary, FC:GetText("GLOBAL_SEARCH_SUMMARY", #results, tostring(query)), #results > 0 and Theme.colors.text or Theme.colors.yellow)
    end

    local startIndex = ((frame.page - 1) * PAGE_SIZE) + 1
    for i, row in ipairs(frame.rows) do
        local result = results[startIndex + i - 1]
        if result then
            row.searchResult = result
            row:Show()
            row:SetFCText(string.format("[%s]  %s    —    %s", tostring(result.kindLabel or result.kind), tostring(result.title), tostring(result.subtitle or "")))
        else
            row.searchResult = nil
            row:Hide()
        end
    end

    if query ~= "" and #results == 0 then
        frame.rows[1]:Show()
        frame.rows[1].searchResult = nil
        frame.rows[1]:SetFCText(FC:GetText("GLOBAL_SEARCH_NO_MATCH"))
    end

    frame.prevButton:SetEnabled(frame.page > 1)
    frame.nextButton:SetEnabled(frame.page < maxPage)
    frame.prevButton:SetAlpha(frame.page > 1 and 1 or 0.4)
    frame.nextButton:SetAlpha(frame.page < maxPage and 1 or 0.4)
    frame.pageText:SetText(FC:GetText("SEARCH_PAGE", frame.page, maxPage))
    frame.note:SetText(FC:GetText("GLOBAL_SEARCH_NOTE"))
end

function UI:ShowGlobalSearch(query)
    local frame = self:CreateGlobalSearchFrame()
    if query ~= nil then frame.search:SetText(tostring(query)) end
    frame.page = 1
    refreshResults(frame)
    self:RefreshGlobalSearchView()
    frame:Show()
    if frame.search:GetText() == "" then frame.search:SetFocus() end
end
