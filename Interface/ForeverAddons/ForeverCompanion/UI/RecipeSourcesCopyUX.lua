local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme
local PAGE_SIZE = 10

local SOURCE_TYPE_KEYS = {
    Trainer = "SOURCE_TYPE_TRAINER",
    Vendor = "SOURCE_TYPE_VENDOR",
    Drop = "SOURCE_TYPE_DROP",
    Quest = "SOURCE_TYPE_QUEST",
    Blueprint = "SOURCE_TYPE_BLUEPRINT",
    Discovery = "SOURCE_TYPE_DISCOVERY",
    Other = "SOURCE_TYPE_OTHER",
}

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

local function sourceTypeLabel(sourceType)
    local key = SOURCE_TYPE_KEYS[tostring(sourceType or "Other")]
    return key and FC:GetText(key) or tostring(sourceType or FC:GetText("SOURCE_TYPE_OTHER"))
end

local previousRefreshRecipeSourcesView = UI.RefreshRecipeSourcesView
function UI:RefreshRecipeSourcesView(...)
    previousRefreshRecipeSourcesView(self, ...)

    local frame = self.recipeSourcesFrame
    local module = FC.RecipeSources
    if not frame or not module then return end

    if frame.note then
        frame.note:SetText(FC:GetText("RECIPE_SOURCES_NOTE"))
    end

    for _, button in ipairs(frame.typeButtons or {}) do
        local key = SOURCE_TYPE_KEYS[tostring(button.sourceType or "")]
        if key then button:SetFCText(FC:GetText(key)) end
    end

    local rows = module:GetKnownRecipeRows(frame.query or "", 500) or {}
    local maxPage = math.max(1, math.ceil(#rows / PAGE_SIZE))
    frame.recipePage = math.max(1, math.min(tonumber(frame.recipePage) or 1, maxPage))
    local startIndex = ((frame.recipePage - 1) * PAGE_SIZE) + 1

    for index, button in ipairs(frame.recipeRows or {}) do
        local row = rows[startIndex + index - 1]
        if row then
            local sourceCount = #(row.sources or {})
            local marker = tostring(frame.selectedRecipeID) == tostring(row.recipeID) and "◆  " or ""
            button:SetFCText(FC:GetText("RECIPE_SOURCE_ROW",
                marker,
                tostring(row.name or (FC:GetText("RECIPE_SOURCE_RECIPE_FALLBACK") .. " " .. tostring(row.recipeID))),
                tostring(row.professionName or FC:GetText("RECIPE_SOURCE_PROFESSION_FALLBACK")),
                sourceCount))
        end
    end

    if frame.recipePageText then
        frame.recipePageText:SetText(FC:GetText("RECIPE_SOURCE_PAGE", frame.recipePage, maxPage, #rows))
    end

    local recipeID = frame.selectedRecipeID
    local recipes = FC.DB and FC.DB.account and FC.DB.account.recipes or {}
    local recipe = recipeID and tableValueByID(recipes, recipeID) or nil
    if not recipe then
        if frame.detailSummary then
            setText(frame.detailSummary, FC:GetText("RECIPE_SOURCE_SELECT_HELP"), Theme.colors.muted)
        end
        return
    end

    if frame.detailTitle then
        frame.detailTitle:SetText(tostring(recipe.name or (FC:GetText("RECIPE_SOURCE_RECIPE_FALLBACK") .. " " .. tostring(recipeID))))
    end
    if frame.detailSummary then
        setText(frame.detailSummary, FC:GetText("RECIPE_SOURCE_DETAIL",
            tostring(recipeID), tostring(recipe.professionName or FC:GetText("RECIPE_SOURCE_PROFESSION_FALLBACK"))), Theme.colors.text)
    end

    local providerSources = module:GetProviderSources(recipeID) or {}
    for index, line in ipairs(frame.providerLines or {}) do
        local source = providerSources[index]
        if source then
            local location = source.location and (" • " .. tostring(source.location)) or ""
            setText(line, FC:GetText("RECIPE_SOURCE_PROVIDER_ROW",
                sourceTypeLabel(source.sourceType),
                tostring(source.sourceName or source.source or FC:GetText("RECIPE_SOURCE_PROVIDER_FALLBACK")),
                location), Theme.colors.green)
        elseif index == 1 then
            setText(line, FC:GetText("RECIPE_SOURCE_PROVIDER_NONE"), Theme.colors.muted)
        else
            setText(line, "")
        end
    end
end
