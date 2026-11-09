local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local function setText(fontString, text, color)
    if not fontString then return end
    color = color or Theme.colors.text
    fontString:SetText(text or "")
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function countEntries(tbl)
    local count = 0
    for _ in pairs(tbl or {}) do count = count + 1 end
    return count
end

local function formatAgeFromStamp(stamp)
    local now = time and time() or 0
    stamp = tonumber(stamp)
    if not stamp or stamp <= 0 or now <= 0 then return FC:GetText("AGE_NEVER") end
    local age = math.max(0, now - stamp)
    if age < 60 then return FC:GetText("AGE_NOW") end
    if age < 3600 then return FC:GetText("AGE_MINUTES_AGO", math.floor(age / 60)) end
    if age < 86400 then return FC:GetText("AGE_HOURS_AGO", math.floor(age / 3600)) end
    return FC:GetText("AGE_DAYS_AGO", math.floor(age / 86400))
end

local function sortedCharacterCaches()
    local result = {}
    for key, character in pairs(FC.DB and FC.DB.account and FC.DB.account.characters or {}) do
        result[#result + 1] = { key = key, data = character }
    end
    table.sort(result, function(a, b)
        return (tonumber(a.data.lastSeen) or 0) > (tonumber(b.data.lastSeen) or 0)
    end)
    return result
end

function UI:CreateCacheManagerFrame()
    if self.cacheManagerFrame then return self.cacheManagerFrame end

    local frame = Theme:CreatePanel(UIParent, Theme.colors.navy, Theme.colors.gold)
    frame:SetSize(820, 610)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    frame.title = Theme:CreateText(frame, "GameFontNormalHuge", "ACCOUNT CACHE MANAGER")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -18)
    frame.title:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])

    frame.closeButton = Theme:CreateButton(frame, "X", 32, 30)
    frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -14)
    frame.closeButton:SetScript("OnClick", function() frame:Hide() end)

    frame.refreshButton = Theme:CreateButton(frame, "Refresh Current", 130, 30)
    frame.refreshButton:SetPoint("RIGHT", frame.closeButton, "LEFT", -8, 0)
    frame.refreshButton:SetScript("OnClick", function()
        FC:RefreshModules("cache-manager")
        setText(frame.actionStatus, FC:GetText("CACHE_REFRESHED"), Theme.colors.green)
        UI:RefreshCacheManagerView()
    end)

    frame.rebuildButton = Theme:CreateButton(frame, "Rebuild Derived Indexes", 180, 30)
    frame.rebuildButton:SetPoint("RIGHT", frame.refreshButton, "LEFT", -8, 0)
    frame.rebuildButton:SetScript("OnClick", function()
        if FC.Inventory and FC.Inventory.RebuildAccountIndex then FC.Inventory:RebuildAccountIndex() end
        if FC.CraftingGoals and FC.CraftingGoals.Refresh then FC.CraftingGoals:Refresh() end
        if FC.AccountRecipes and FC.AccountRecipes.Refresh then FC.AccountRecipes:Refresh() end
        if FC.Goals and FC.Goals.Refresh then FC.Goals:Refresh() end
        if FC.RecipeSources and FC.RecipeSources.Refresh then FC.RecipeSources:Refresh() end
        setText(frame.actionStatus, FC:GetText("CACHE_REBUILD_DONE_DETAIL"), Theme.colors.green)
        UI:RefreshCacheManagerView()
        if UI.frame and UI.frame:IsShown() then UI:RefreshDashboard() end
    end)

    frame.actionStatus = Theme:CreateText(frame, "GameFontHighlightSmall", "")
    frame.actionStatus:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -68)
    frame.actionStatus:SetWidth(776)
    frame.actionStatus:SetJustifyH("LEFT")

    frame.summary = Theme:CreateText(frame, "GameFontHighlight", "")
    frame.summary:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -90)
    frame.summary:SetWidth(776)
    frame.summary:SetJustifyH("LEFT")

    frame.sourceTitle = Theme:CreateSectionTitle(frame, "Account Data Sources")
    frame.sourceTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -128)
    frame.sourceLines = {}
    for i = 1, 9 do
        local line = Theme:CreateText(frame, "GameFontHighlightSmall", "")
        line:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -158 - ((i - 1) * 27))
        line:SetWidth(370)
        line:SetJustifyH("LEFT")
        frame.sourceLines[i] = line
    end

    frame.characterTitle = Theme:CreateSectionTitle(frame, "Character Cache Freshness")
    frame.characterTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 420, -128)
    frame.characterLines = {}
    for i = 1, 10 do
        local line = Theme:CreateText(frame, "GameFontHighlightSmall", "")
        line:SetPoint("TOPLEFT", frame, "TOPLEFT", 422, -158 - ((i - 1) * 34))
        line:SetWidth(372)
        line:SetJustifyH("LEFT")
        frame.characterLines[i] = line
    end

    frame.explanation = Theme:CreateText(frame, "GameFontDisableSmall", FC:GetText("CACHE_EXPLANATION"))
    frame.explanation:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 18)
    frame.explanation:SetWidth(776)
    frame.explanation:SetJustifyH("LEFT")

    self.cacheManagerFrame = frame
    return frame
end

function UI:RefreshCacheManagerView()
    local frame = self:CreateCacheManagerFrame()
    local account = FC.DB and FC.DB.account or {}
    local characters = account.characters or {}
    local storage = account.storage or {}
    local accountBank = storage.accountBank

    setText(frame.summary, FC:GetText("CACHE_SUMMARY",
        tostring(FC.DB and FC.DB.dbVersion or "?"),
        countEntries(characters), countEntries(account.items), countEntries(account.recipes), countEntries(account.flightPoints)), Theme.colors.text)

    local legacy = account.legacy or {}
    local checklist = account.preparationChecklist and account.preparationChecklist.items or {}
    local routeCount = countEntries(account.travelRoutes)
    local sourceCount = countEntries(account.recipeSources)
    local legacyText = legacy.snapshot
        and FC:GetText("CACHE_LEGACY_COMPLETE", tonumber(legacy.snapshot.completed) or 0, tonumber(legacy.snapshot.total) or 0)
        or FC:GetText("CACHE_NO_SNAPSHOT")
    local sources = {
        FC:GetText("CACHE_BAGS_INDEX", countEntries(account.items)),
        FC:GetText("CACHE_ACCOUNT_BANK", countEntries(accountBank and accountBank.items), formatAgeFromStamp(accountBank and accountBank.lastSeen)),
        FC:GetText("CACHE_RECIPES", countEntries(account.recipes)),
        FC:GetText("CACHE_RECIPE_NOTES", sourceCount),
        FC:GetText("CACHE_TRAVEL", countEntries(account.flightPoints), routeCount),
        FC:GetText("CACHE_LEGACY", legacyText),
        FC:GetText("CACHE_GOALS", countEntries(account.goals), countEntries(account.craftingGoals)),
        FC:GetText("CACHE_CHECKLIST", countEntries(checklist)),
        FC:GetText("CACHE_SNOOZES", countEntries(account.suggestionState and account.suggestionState.snoozed)),
    }
    for i, line in ipairs(frame.sourceLines) do setText(line, sources[i] or "", Theme.colors.muted) end

    local caches = sortedCharacterCaches()
    local now = time and time() or 0
    for i = 1, #frame.characterLines do
        local entry = caches[i]
        if entry then
            local character = entry.data
            local inventory = character.inventory or {}
            local age = character.lastSeen and now > 0 and now - character.lastSeen or 0
            local stale = age > 86400
            setText(frame.characterLines[i], FC:GetText("CACHE_CHARACTER_ROW",
                tostring(character.name or entry.key), tonumber(character.level) or 0, tostring(character.className or ""),
                formatAgeFromStamp(character.lastSeen), formatAgeFromStamp(inventory.lastSeen), formatAgeFromStamp(inventory.bank and inventory.bank.lastSeen)),
                stale and Theme.colors.yellow or Theme.colors.text)
        else
            setText(frame.characterLines[i], i == 1 and FC:GetText("CACHE_NO_CHARACTER") or "", Theme.colors.muted)
        end
    end

    if frame.explanation then frame.explanation:SetText(FC:GetText("CACHE_EXPLANATION")) end
end

function UI:ShowCacheManager()
    local frame = self:CreateCacheManagerFrame()
    self:RefreshCacheManagerView()
    frame:Show()
end
