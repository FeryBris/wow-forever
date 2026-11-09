local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local SOURCE_TYPES = { "Trainer", "Vendor", "Drop", "Quest", "Blueprint", "Discovery", "Other" }

local function setText(fontString, text, color)
    if not fontString then return end
    color = color or Theme.colors.text
    fontString:SetText(text or "")
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function tableValueByID(tbl, id)
    if type(tbl) ~= "table" then return nil end
    local numeric = tonumber(id)
    return (numeric and tbl[numeric]) or tbl[tostring(id)] or tbl[id]
end

local function getUserSource(recipeID)
    local store = FC.DB and FC.DB.account and FC.DB.account.recipeSources or {}
    return tableValueByID(store, recipeID)
end

local function getRecipe(recipeID)
    local recipes = FC.DB and FC.DB.account and FC.DB.account.recipes or {}
    return tableValueByID(recipes, recipeID)
end

function UI:CreateRecipeSourcesFrame()
    if self.recipeSourcesFrame then return self.recipeSourcesFrame end

    local frame = Theme:CreatePanel(UIParent, Theme.colors.navy, Theme.colors.gold)
    frame:SetSize(900, 650)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    frame.title = Theme:CreateText(frame, "GameFontNormalHuge", "RECIPE & BLUEPRINT SOURCES")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -18)
    frame.title:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])

    frame.close = Theme:CreateButton(frame, "X", 32, 30)
    frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -14)
    frame.close:SetScript("OnClick", function() frame:Hide() end)

    frame.search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.search:SetSize(330, 30)
    frame.search:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -66)
    frame.search:SetAutoFocus(false)
    frame.search:SetTextInsets(8, 8, 0, 0)

    frame.searchButton = Theme:CreateButton(frame, "Search recipes", 120, 30)
    frame.searchButton:SetPoint("LEFT", frame.search, "RIGHT", 10, 0)

    frame.recipeTitle = Theme:CreateSectionTitle(frame, "Cached Recipes")
    frame.recipeTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -112)

    frame.recipeRows = {}
    for i = 1, 10 do
        local row = Theme:CreateButton(frame, "", 420, 38)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -144 - ((i - 1) * 41))
        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", row, "LEFT", 9, 0)
        row.label:SetPoint("RIGHT", row, "RIGHT", -9, 0)
        row.label:SetJustifyH("LEFT")
        row:SetScript("OnClick", function(self)
            if not self.recipeRow then return end
            frame.selectedRecipeID = self.recipeRow.recipeID
            frame.fcLoadedRecipeID = nil
            UI:RefreshRecipeSourcesView()
        end)
        frame.recipeRows[i] = row
    end

    frame.detail = Theme:CreatePanel(frame, Theme.colors.panel, Theme.colors.blueSoft)
    frame.detail:SetPoint("TOPLEFT", frame, "TOPLEFT", 464, -66)
    frame.detail:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 20)

    frame.detailTitle = Theme:CreateSectionTitle(frame.detail, "Select a cached recipe")
    frame.detailTitle:SetPoint("TOPLEFT", frame.detail, "TOPLEFT", 14, -14)
    frame.detailSummary = Theme:CreateText(frame.detail, "GameFontHighlightSmall", "")
    frame.detailSummary:SetPoint("TOPLEFT", frame.detail, "TOPLEFT", 14, -44)
    frame.detailSummary:SetWidth(390)
    frame.detailSummary:SetJustifyH("LEFT")

    frame.typeTitle = Theme:CreateText(frame.detail, "GameFontNormalSmall", "SOURCE TYPE")
    frame.typeTitle:SetPoint("TOPLEFT", frame.detail, "TOPLEFT", 14, -92)
    frame.typeButtons = {}
    for i, sourceType in ipairs(SOURCE_TYPES) do
        local col = (i - 1) % 3
        local row = math.floor((i - 1) / 3)
        local button = Theme:CreateButton(frame.detail, sourceType, 122, 28)
        button:SetPoint("TOPLEFT", frame.detail, "TOPLEFT", 14 + (col * 130), -114 - (row * 34))
        button.sourceType = sourceType
        button:SetScript("OnClick", function(self)
            frame.selectedSourceType = self.sourceType
            UI:RefreshRecipeSourcesView()
        end)
        frame.typeButtons[i] = button
    end

    frame.sourceNameLabel = Theme:CreateText(frame.detail, "GameFontNormalSmall", "SOURCE / NPC / ITEM")
    frame.sourceNameLabel:SetPoint("TOPLEFT", frame.detail, "TOPLEFT", 14, -224)
    frame.sourceName = CreateFrame("EditBox", nil, frame.detail, "InputBoxTemplate")
    frame.sourceName:SetSize(390, 30)
    frame.sourceName:SetPoint("TOPLEFT", frame.detail, "TOPLEFT", 14, -246)
    frame.sourceName:SetAutoFocus(false)
    frame.sourceName:SetTextInsets(8, 8, 0, 0)

    frame.locationLabel = Theme:CreateText(frame.detail, "GameFontNormalSmall", "LOCATION")
    frame.locationLabel:SetPoint("TOPLEFT", frame.detail, "TOPLEFT", 14, -288)
    frame.location = CreateFrame("EditBox", nil, frame.detail, "InputBoxTemplate")
    frame.location:SetSize(390, 30)
    frame.location:SetPoint("TOPLEFT", frame.detail, "TOPLEFT", 14, -310)
    frame.location:SetAutoFocus(false)
    frame.location:SetTextInsets(8, 8, 0, 0)

    frame.notesLabel = Theme:CreateText(frame.detail, "GameFontNormalSmall", "NOTES")
    frame.notesLabel:SetPoint("TOPLEFT", frame.detail, "TOPLEFT", 14, -352)
    frame.notes = CreateFrame("EditBox", nil, frame.detail, "InputBoxTemplate")
    frame.notes:SetSize(390, 30)
    frame.notes:SetPoint("TOPLEFT", frame.detail, "TOPLEFT", 14, -374)
    frame.notes:SetAutoFocus(false)
    frame.notes:SetTextInsets(8, 8, 0, 0)

    frame.save = Theme:CreateButton(frame.detail, "Save source note", 150, 32)
    frame.save:SetPoint("TOPLEFT", frame.detail, "TOPLEFT", 14, -420)
    frame.remove = Theme:CreateButton(frame.detail, "Remove note", 120, 32)
    frame.remove:SetPoint("LEFT", frame.save, "RIGHT", 10, 0)

    frame.providerTitle = Theme:CreateText(frame.detail, "GameFontNormalSmall", "VERIFIED / PROVIDER SOURCES")
    frame.providerTitle:SetPoint("TOPLEFT", frame.detail, "TOPLEFT", 14, -472)
    frame.providerLines = {}
    for i = 1, 3 do
        local line = Theme:CreateText(frame.detail, "GameFontHighlightSmall", "")
        line:SetPoint("TOPLEFT", frame.detail, "TOPLEFT", 14, -494 - ((i - 1) * 34))
        line:SetWidth(390)
        line:SetJustifyH("LEFT")
        frame.providerLines[i] = line
    end

    frame.note = Theme:CreateText(frame, "GameFontDisableSmall",
        "Forever Companion does not guess recipe sources. User notes are personal planning data; provider entries must come from a registered, verifiable data source.")
    frame.note:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 18)
    frame.note:SetWidth(420)
    frame.note:SetJustifyH("LEFT")

    local function runSearch()
        frame.query = frame.search:GetText() or ""
        frame.search:ClearFocus()
        UI:RefreshRecipeSourcesView()
    end
    frame.searchButton:SetScript("OnClick", runSearch)
    frame.search:SetScript("OnEnterPressed", runSearch)

    frame.save:SetScript("OnClick", function()
        if not frame.selectedRecipeID or not FC.RecipeSources then return end
        local ok, err = FC.RecipeSources:SetUserNote(
            frame.selectedRecipeID,
            frame.selectedSourceType or "Other",
            frame.sourceName:GetText(),
            frame.location:GetText(),
            frame.notes:GetText()
        )
        if not ok then FC:Print(err); return end
        FC.RecipeSources:Refresh()
        UI:RefreshRecipeSourcesView()
    end)

    frame.remove:SetScript("OnClick", function()
        if not frame.selectedRecipeID or not FC.RecipeSources then return end
        FC.RecipeSources:RemoveUserNote(frame.selectedRecipeID)
        frame.selectedSourceType = nil
        frame.sourceName:SetText("")
        frame.location:SetText("")
        frame.notes:SetText("")
        FC.RecipeSources:Refresh()
        UI:RefreshRecipeSourcesView()
    end)

    self.recipeSourcesFrame = frame
    return frame
end

function UI:RefreshRecipeSourcesView()
    local frame = self.recipeSourcesFrame
    if not frame or not FC.RecipeSources then return end

    local rows = FC.RecipeSources:GetKnownRecipeRows(frame.query or "", #frame.recipeRows)
    for i, button in ipairs(frame.recipeRows) do
        local row = rows[i]
        if row then
            button.recipeRow = row
            button:Show()
            local sourceCount = #(row.sources or {})
            button:SetFCText(string.format("%s%s\n%s • %d source note(s)",
                frame.selectedRecipeID == row.recipeID and "◆  " or "",
                tostring(row.name), tostring(row.professionName or "Profession"), sourceCount))
            button:SetFCActive(frame.selectedRecipeID == row.recipeID)
        else
            button.recipeRow = nil
            button:Hide()
        end
    end

    if not frame.selectedRecipeID and rows[1] then
        frame.selectedRecipeID = rows[1].recipeID
        frame.fcLoadedRecipeID = nil
    end

    local recipeID = frame.selectedRecipeID
    local recipe = recipeID and getRecipe(recipeID) or nil
    if not recipe then
        frame.detailTitle:SetText("Select a cached recipe")
        setText(frame.detailSummary, "Open a profession window in game to populate recipe data, then choose a recipe on the left.", Theme.colors.muted)
        frame.save:SetEnabled(false)
        frame.remove:SetEnabled(false)
        return
    end

    frame.save:SetEnabled(true)
    frame.remove:SetEnabled(true)
    frame.detailTitle:SetText(tostring(recipe.name or ("Recipe " .. tostring(recipeID))))
    setText(frame.detailSummary, string.format("Recipe ID %s • %s", tostring(recipeID), tostring(recipe.professionName or "Profession")), Theme.colors.text)

    if frame.fcLoadedRecipeID ~= tostring(recipeID) then
        local user = getUserSource(recipeID)
        frame.selectedSourceType = user and user.sourceType or "Other"
        frame.sourceName:SetText(user and user.sourceName or "")
        frame.location:SetText(user and user.location or "")
        frame.notes:SetText(user and user.notes or "")
        frame.fcLoadedRecipeID = tostring(recipeID)
    end

    for _, button in ipairs(frame.typeButtons) do
        button:SetFCActive(button.sourceType == (frame.selectedSourceType or "Other"))
    end

    local providerSources = FC.RecipeSources:GetProviderSources(recipeID)
    for i, line in ipairs(frame.providerLines) do
        local source = providerSources[i]
        if source then
            local location = source.location and (" • " .. tostring(source.location)) or ""
            setText(line, string.format("%s: %s%s", tostring(source.sourceType or "Source"), tostring(source.sourceName or source.source or "Provider"), location), Theme.colors.green)
        elseif i == 1 then
            setText(line, "No registered provider source for this recipe yet.", Theme.colors.muted)
        else
            setText(line, "")
        end
    end
end

function UI:ShowRecipeSources(recipeID)
    local frame = self:CreateRecipeSourcesFrame()
    if recipeID then
        frame.selectedRecipeID = tonumber(recipeID) or recipeID
        frame.fcLoadedRecipeID = nil
    end
    self:RefreshRecipeSourcesView()
    frame:Show()
end
