local _, FC = ...

local UI = FC.UI

local CHARACTER_PAGE_SIZE = 11
local GOAL_PAGE_SIZE = 9
local ROUTE_PAGE_SIZE = 10
local CHECKLIST_PAGE_SIZE = 10
local LEGACY_PAGE_SIZE = 10

local function findIndex(list, targetID, idGetter)
    if targetID == nil then return nil end
    local wanted = tostring(targetID)
    for index, entry in ipairs(list or {}) do
        local value = idGetter(entry)
        if value ~= nil and tostring(value) == wanted then return index end
    end
    return nil
end

local function pageForIndex(index, pageSize)
    if not index then return nil end
    return math.max(1, math.ceil(index / pageSize))
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

local function incompleteLegacyChallenges()
    local snapshot = FC.Legacy and FC.Legacy:GetSnapshot() or nil
    local result = {}
    for _, challenge in ipairs(snapshot and snapshot.challenges or {}) do
        if not challenge.completed then result[#result + 1] = challenge end
    end
    table.sort(result, function(a, b)
        local ap = tonumber(a.progress) or 0
        local bp = tonumber(b.progress) or 0
        if ap == bp then return tostring(a.name or "") < tostring(b.name or "") end
        return ap > bp
    end)
    return result
end

local previousShowCharacters = UI.ShowCharacters
if type(previousShowCharacters) == "function" then
    function UI:ShowCharacters(targetKey, ...)
        local result = previousShowCharacters(self, ...)
        local frame = self.charactersFrame
        if targetKey and frame then
            local index = findIndex(sortedCharacters(), targetKey, function(entry) return entry.key end)
            local page = pageForIndex(index, CHARACTER_PAGE_SIZE)
            if page then
                frame.characterPage = page
                self:RefreshCharactersView()
            end
        end
        return result
    end
end

local previousShowGoals = UI.ShowGoals
if type(previousShowGoals) == "function" then
    function UI:ShowGoals(targetID, ...)
        local result = previousShowGoals(self, ...)
        local frame = self.goalsFrame
        if targetID and frame and FC.Goals then
            local index = findIndex(FC.Goals:GetGoals(true), targetID, function(goal) return goal.id end)
            local page = pageForIndex(index, GOAL_PAGE_SIZE)
            if page then
                frame.goalPage = page
                self:RefreshGoalsView()
            end
        end
        return result
    end
end

local previousShowTravelRoutes = UI.ShowTravelRoutes
if type(previousShowTravelRoutes) == "function" then
    function UI:ShowTravelRoutes(targetID, ...)
        local result = previousShowTravelRoutes(self, ...)
        local frame = self.travelRoutesFrame
        if targetID and frame and FC.TravelRoutes then
            local index = findIndex(FC.TravelRoutes:GetAllRoutes(true), targetID, function(route) return route.id end)
            local page = pageForIndex(index, ROUTE_PAGE_SIZE)
            if page then
                frame.routePage = page
                self:RefreshTravelRoutesView()
            end
        end
        return result
    end
end

local previousShowPreparationChecklist = UI.ShowPreparationChecklist
if type(previousShowPreparationChecklist) == "function" then
    function UI:ShowPreparationChecklist(targetID, ...)
        local result = previousShowPreparationChecklist(self, ...)
        local frame = self.preparationChecklistFrame
        if targetID and frame and FC.PreparationChecklist then
            local index = findIndex(FC.PreparationChecklist:GetItems(), targetID, function(item) return item.id end)
            local page = pageForIndex(index, CHECKLIST_PAGE_SIZE)
            if page then
                frame.checklistPage = page
                self:RefreshPreparationChecklistView()
            end
        end
        return result
    end
end

local previousShowLegacyTracker = UI.ShowLegacyTracker
if type(previousShowLegacyTracker) == "function" then
    function UI:ShowLegacyTracker(targetID, ...)
        local result = previousShowLegacyTracker(self, ...)
        local frame = self.legacyFrame
        if targetID and frame then
            local index = findIndex(incompleteLegacyChallenges(), targetID, function(challenge) return challenge.id end)
            local page = pageForIndex(index, LEGACY_PAGE_SIZE)
            if page then
                frame.legacyPage = page
                self:RefreshLegacyView()
            end
        end
        return result
    end
end

function UI:OpenSearchResult(result)
    if not result then return false end

    if result.kind == "Item" and type(self.ShowItems) == "function" then
        self:ShowItems(result.id)
    elseif result.kind == "Character" and type(self.ShowCharacters) == "function" then
        self:ShowCharacters(result.id)
    elseif result.kind == "Goal" and type(self.ShowGoals) == "function" then
        self:ShowGoals(result.id)
    elseif result.kind == "Legacy" and type(self.ShowLegacyTracker) == "function" then
        self:ShowLegacyTracker(result.id)
    elseif result.kind == "Route" and type(self.ShowTravelRoutes) == "function" then
        self:ShowTravelRoutes(result.id)
    elseif result.kind == "Checklist" and type(self.ShowPreparationChecklist) == "function" then
        self:ShowPreparationChecklist(result.id)
    elseif result.kind == "Recipe" and type(self.ShowRecipeSources) == "function" and FC:IsModuleEnabled("RecipeSources") then
        self:ShowRecipeSources(result.id)
    elseif result.kind == "Recipe" and type(self.ShowAccountRecipes) == "function" then
        self:ShowAccountRecipes()
    else
        return false
    end
    return true
end

local function bindMainSearch(frame)
    if not frame or frame.fcSearchNavigationBound then return end
    local panel = frame.fcSearchResults
    if not panel or not frame.fcSearchBox then return end
    frame.fcSearchNavigationBound = true

    for _, row in ipairs(panel.rows or {}) do
        row:SetScript("OnClick", function(self)
            local result = self.searchResult
            panel:Hide()
            frame.fcSearchBox:ClearFocus()
            UI:OpenSearchResult(result)
        end)
    end

    frame.fcSearchBox:SetScript("OnEnterPressed", function(self)
        local first = panel.currentResults and panel.currentResults[1]
        self:ClearFocus()
        panel:Hide()
        if first then UI:OpenSearchResult(first) end
    end)
end

local previousCreateMainFrame = UI.CreateMainFrame
if type(previousCreateMainFrame) == "function" then
    function UI:CreateMainFrame(...)
        local frame = previousCreateMainFrame(self, ...)
        bindMainSearch(frame)
        return frame
    end
end

local function bindGlobalSearch(frame)
    if not frame or frame.fcSearchNavigationBound then return end
    frame.fcSearchNavigationBound = true
    for _, row in ipairs(frame.rows or {}) do
        row:SetScript("OnClick", function(self)
            UI:OpenSearchResult(self.searchResult)
        end)
    end
end

local previousCreateGlobalSearchFrame = UI.CreateGlobalSearchFrame
if type(previousCreateGlobalSearchFrame) == "function" then
    function UI:CreateGlobalSearchFrame(...)
        local frame = previousCreateGlobalSearchFrame(self, ...)
        bindGlobalSearch(frame)
        return frame
    end
end
