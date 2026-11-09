local _, FC = ...

local UI = FC.UI

local function setButton(button, key)
    if button and button.SetFCText then button:SetFCText(FC:GetText(key)) end
end

local function setLabel(label, key)
    if label then label:SetText(FC:GetText(key)) end
end

local function localizeCharacters(frame)
    if not frame then return end
    setLabel(frame.title, "WINDOW_CHARACTERS")
    setButton(frame.refreshButton, "REFRESH_CURRENT")
    setButton(frame.prevButton, "PREVIOUS")
    setButton(frame.nextButton, "NEXT")
end

local function localizeAccountRecipes(frame)
    if not frame then return end
    setLabel(frame.title, "WINDOW_ACCOUNT_RECIPES")
    setButton(frame.refreshButton, "REFRESH")
    setLabel(frame.professionTitle, "CACHED_PROFESSIONS")
    setLabel(frame.opportunityTitle, "KNOWN_OTHER_CHARACTER")
end

local function localizeRecipeSources(frame)
    if not frame then return end
    setLabel(frame.title, "WINDOW_RECIPE_SOURCES")
    setButton(frame.searchButton, "SEARCH_RECIPES")
    setLabel(frame.recipeTitle, "CACHED_RECIPES")
    if not frame.selectedRecipeID then setLabel(frame.detailTitle, "SELECT_CACHED_RECIPE") end
    setLabel(frame.typeTitle, "SOURCE_TYPE")
    setLabel(frame.sourceNameLabel, "SOURCE_NAME_ITEM")
    setLabel(frame.locationLabel, "LOCATION")
    setLabel(frame.notesLabel, "NOTES")
    setButton(frame.save, "SAVE_SOURCE_NOTE")
    setButton(frame.remove, "REMOVE_NOTE")
    setLabel(frame.providerTitle, "VERIFIED_PROVIDER_SOURCES")
    setButton(frame.recipePrev, "PREVIOUS")
    setButton(frame.recipeNext, "NEXT")
end

local function localizeGoals(frame)
    if not frame then return end
    setLabel(frame.title, "WINDOW_GOALS")
    setButton(frame.addButton, "PIN_GOAL")
    for _, row in ipairs(frame.rows or {}) do
        if row.remove then setButton(row.remove, "REMOVE") end
        if row.complete and row.complete.label then
            local text = row.complete.label:GetText()
            if text == "Reopen" or text == "Wieder öffnen" then setButton(row.complete, "REOPEN")
            else setButton(row.complete, "DONE") end
        end
    end
end

local function localizeTravelRoutes(frame)
    if not frame then return end
    setLabel(frame.title, "WINDOW_TRAVEL_ROUTES")
    setButton(frame.addButton, "ADD_ROUTE")
    for _, row in ipairs(frame.rows or {}) do
        if row.remove then setButton(row.remove, "REMOVE") end
        if row.toggle and row.toggle.label then
            local text = row.toggle.label:GetText()
            if text == "Enable" or text == "Aktivieren" then setButton(row.toggle, "ENABLE")
            else setButton(row.toggle, "PAUSE") end
        end
    end
end

local function localizeCacheManager(frame)
    if not frame then return end
    setLabel(frame.title, "WINDOW_CACHE_MANAGER")
    setButton(frame.refreshButton, "REFRESH_CURRENT")
    setButton(frame.rebuildButton, "REBUILD_INDEXES")
    setLabel(frame.sourceTitle, "ACCOUNT_DATA_SOURCES")
    setLabel(frame.characterTitle, "CHARACTER_CACHE_FRESHNESS")
end

local function localizeDataTransfer(frame)
    if not frame then return end
    setLabel(frame.title, "WINDOW_DATA_TRANSFER")
    setButton(frame.exportButton, "EXPORT_CURRENT")
    setButton(frame.importButton, "IMPORT_MERGE")
    setButton(frame.selectButton, "SELECT_ALL")
end

local function localizeGlobalSearch(frame)
    if not frame then return end
    setLabel(frame.title, "WINDOW_GLOBAL_SEARCH")
    setButton(frame.searchButton, "SEARCH")
    setButton(frame.prevButton, "PREVIOUS")
    setButton(frame.nextButton, "NEXT")

    local query = frame.search and frame.search:GetText() or ""
    local results = frame.results or {}
    local maxPage = math.max(1, math.ceil(#results / 10))
    if frame.summary then
        if query == "" then
            frame.summary:SetText(FC:GetText("GLOBAL_SEARCH_HELP"))
        else
            frame.summary:SetText(FC:GetText("GLOBAL_SEARCH_SUMMARY", #results, tostring(query)))
        end
    end
    if frame.pageText then
        frame.pageText:SetText(FC:GetText("SEARCH_PAGE", tonumber(frame.page) or 1, maxPage))
    end
    if frame.note then
        frame.note:SetText(FC:GetText("GLOBAL_SEARCH_NOTE"))
    end
    if query ~= "" and #results == 0 and frame.rows and frame.rows[1] then
        frame.rows[1]:SetFCText(FC:GetText("GLOBAL_SEARCH_NO_MATCH"))
    end
end

local previousCreateCharactersFrame = UI.CreateCharactersFrame
function UI:CreateCharactersFrame(...)
    local frame = previousCreateCharactersFrame(self, ...)
    localizeCharacters(frame)
    return frame
end

local previousRefreshCharactersView = UI.RefreshCharactersView
function UI:RefreshCharactersView(...)
    previousRefreshCharactersView(self, ...)
    localizeCharacters(self.charactersFrame)
end

local previousCreateAccountRecipesFrame = UI.CreateAccountRecipesFrame
function UI:CreateAccountRecipesFrame(...)
    local frame = previousCreateAccountRecipesFrame(self, ...)
    localizeAccountRecipes(frame)
    return frame
end

local previousRefreshAccountRecipesView = UI.RefreshAccountRecipesView
function UI:RefreshAccountRecipesView(...)
    previousRefreshAccountRecipesView(self, ...)
    localizeAccountRecipes(self.accountRecipesFrame)
end

local previousCreateRecipeSourcesFrame = UI.CreateRecipeSourcesFrame
function UI:CreateRecipeSourcesFrame(...)
    local frame = previousCreateRecipeSourcesFrame(self, ...)
    localizeRecipeSources(frame)
    return frame
end

local previousRefreshRecipeSourcesView = UI.RefreshRecipeSourcesView
function UI:RefreshRecipeSourcesView(...)
    previousRefreshRecipeSourcesView(self, ...)
    localizeRecipeSources(self.recipeSourcesFrame)
end

local previousCreateGoalsFrame = UI.CreateGoalsFrame
function UI:CreateGoalsFrame(...)
    local frame = previousCreateGoalsFrame(self, ...)
    localizeGoals(frame)
    return frame
end

local previousRefreshGoalsView = UI.RefreshGoalsView
function UI:RefreshGoalsView(...)
    previousRefreshGoalsView(self, ...)
    localizeGoals(self.goalsFrame)
end

local previousCreateTravelRoutesFrame = UI.CreateTravelRoutesFrame
function UI:CreateTravelRoutesFrame(...)
    local frame = previousCreateTravelRoutesFrame(self, ...)
    localizeTravelRoutes(frame)
    return frame
end

local previousRefreshTravelRoutesView = UI.RefreshTravelRoutesView
function UI:RefreshTravelRoutesView(...)
    previousRefreshTravelRoutesView(self, ...)
    localizeTravelRoutes(self.travelRoutesFrame)
end

local previousCreateCacheManagerFrame = UI.CreateCacheManagerFrame
function UI:CreateCacheManagerFrame(...)
    local frame = previousCreateCacheManagerFrame(self, ...)
    localizeCacheManager(frame)
    return frame
end

local previousRefreshCacheManagerView = UI.RefreshCacheManagerView
function UI:RefreshCacheManagerView(...)
    previousRefreshCacheManagerView(self, ...)
    localizeCacheManager(self.cacheManagerFrame)
end

local previousCreateDataTransferFrame = UI.CreateDataTransferFrame
function UI:CreateDataTransferFrame(...)
    local frame = previousCreateDataTransferFrame(self, ...)
    localizeDataTransfer(frame)
    return frame
end

local previousCreateGlobalSearchFrame = UI.CreateGlobalSearchFrame
function UI:CreateGlobalSearchFrame(...)
    local frame = previousCreateGlobalSearchFrame(self, ...)
    localizeGlobalSearch(frame)
    return frame
end

local previousRefreshGlobalSearchView = UI.RefreshGlobalSearchView
function UI:RefreshGlobalSearchView(...)
    previousRefreshGlobalSearchView(self, ...)
    localizeGlobalSearch(self.globalSearchFrame)
end

local previousRefreshSettingsView = UI.RefreshSettingsView
function UI:RefreshSettingsView(...)
    previousRefreshSettingsView(self, ...)
    localizeCharacters(self.charactersFrame)
    localizeAccountRecipes(self.accountRecipesFrame)
    localizeRecipeSources(self.recipeSourcesFrame)
    localizeGoals(self.goalsFrame)
    localizeTravelRoutes(self.travelRoutesFrame)
    localizeCacheManager(self.cacheManagerFrame)
    localizeDataTransfer(self.dataTransferFrame)
    localizeGlobalSearch(self.globalSearchFrame)
end
