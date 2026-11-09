local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme
local PROFESSION_PAGE_SIZE = 8
local OPPORTUNITY_PAGE_SIZE = 10

local function setText(fontString, text, color)
    if not fontString then return end
    color = color or Theme.colors.text
    fontString:SetText(text or "")
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local previousCreateAccountRecipesFrame = UI.CreateAccountRecipesFrame
function UI:CreateAccountRecipesFrame(...)
    local frame = previousCreateAccountRecipesFrame(self, ...)
    if not frame or frame.fcPaging then return frame end
    frame.fcPaging = true
    frame.professionPage = 1
    frame.opportunityPage = 1

    frame.profPrev = Theme:CreateButton(frame, "<", 32, 24)
    frame.profPrev:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -418)
    frame.profNext = Theme:CreateButton(frame, ">", 32, 24)
    frame.profNext:SetPoint("LEFT", frame.profPrev, "RIGHT", 6, 0)
    frame.profPageText = Theme:CreateText(frame, "GameFontHighlightSmall", "")
    frame.profPageText:SetPoint("LEFT", frame.profNext, "RIGHT", 8, 0)
    frame.profPageText:SetWidth(260)

    frame.oppPrev = Theme:CreateButton(frame, "<", 32, 24)
    frame.oppPrev:SetPoint("TOPLEFT", frame, "TOPLEFT", 416, -532)
    frame.oppNext = Theme:CreateButton(frame, ">", 32, 24)
    frame.oppNext:SetPoint("LEFT", frame.oppPrev, "RIGHT", 6, 0)
    frame.oppPageText = Theme:CreateText(frame, "GameFontHighlightSmall", "")
    frame.oppPageText:SetPoint("LEFT", frame.oppNext, "RIGHT", 8, 0)
    frame.oppPageText:SetWidth(300)

    frame.profPrev:SetScript("OnClick", function()
        frame.professionPage = math.max(1, (frame.professionPage or 1) - 1)
        UI:RefreshAccountRecipesView()
    end)
    frame.profNext:SetScript("OnClick", function()
        frame.professionPage = (frame.professionPage or 1) + 1
        UI:RefreshAccountRecipesView()
    end)
    frame.oppPrev:SetScript("OnClick", function()
        frame.opportunityPage = math.max(1, (frame.opportunityPage or 1) - 1)
        UI:RefreshAccountRecipesView()
    end)
    frame.oppNext:SetScript("OnClick", function()
        frame.opportunityPage = (frame.opportunityPage or 1) + 1
        UI:RefreshAccountRecipesView()
    end)

    return frame
end

local previousRefreshAccountRecipesView = UI.RefreshAccountRecipesView
function UI:RefreshAccountRecipesView(...)
    previousRefreshAccountRecipesView(self, ...)
    local frame = self.accountRecipesFrame
    local module = FC.AccountRecipes
    if not frame or not frame.fcPaging or not module then return end

    local professions = module:GetProfessionSummaries()
    local professionMax = math.max(1, math.ceil(#professions / PROFESSION_PAGE_SIZE))
    frame.professionPage = math.max(1, math.min(frame.professionPage or 1, professionMax))
    local professionStart = ((frame.professionPage - 1) * PROFESSION_PAGE_SIZE) + 1

    for i, line in ipairs(frame.professionLines or {}) do
        local profession = professions[professionStart + i - 1]
        if profession then
            local currentText = profession.currentSeen > 0
                and FC:GetText("ACCOUNT_RECIPE_CURRENT", tonumber(profession.currentLearned) or 0, tonumber(profession.currentSeen) or 0)
                or FC:GetText("ACCOUNT_RECIPE_CURRENT_UNSCANNED")
            setText(line, FC:GetText("ACCOUNT_RECIPE_PROFESSION_ROW",
                tostring(profession.professionName),
                tonumber(profession.learnedSomewhere) or 0,
                tonumber(profession.totalSeen) or 0,
                currentText,
                tonumber(profession.crossCharacterOpportunities) or 0),
                profession.crossCharacterOpportunities > 0 and Theme.colors.yellow or Theme.colors.text)
        else
            setText(line, i == 1 and #professions == 0 and FC:GetText("ACCOUNT_RECIPE_EMPTY") or "", Theme.colors.muted)
        end
    end

    local opportunities = module:GetCrossCharacterOpportunities(500)
    local opportunityMax = math.max(1, math.ceil(#opportunities / OPPORTUNITY_PAGE_SIZE))
    frame.opportunityPage = math.max(1, math.min(frame.opportunityPage or 1, opportunityMax))
    local opportunityStart = ((frame.opportunityPage - 1) * OPPORTUNITY_PAGE_SIZE) + 1

    for i, line in ipairs(frame.opportunityLines or {}) do
        local recipe = opportunities[opportunityStart + i - 1]
        if recipe then
            local owners = table.concat(recipe.learnedBy or {}, ", ")
            setText(line, FC:GetText("ACCOUNT_RECIPE_OPPORTUNITY_ROW", tostring(recipe.name), tostring(recipe.professionName), owners), Theme.colors.yellow)
        else
            setText(line, i == 1 and #opportunities == 0 and FC:GetText("ACCOUNT_RECIPE_NO_DIFFERENCES") or "", Theme.colors.muted)
        end

        local hit = frame.opportunityHitboxes and frame.opportunityHitboxes[i]
        if hit then
            hit.recipeID = recipe and recipe.recipeID or nil
            hit.recipeName = recipe and recipe.name or nil
            hit:SetShown(recipe ~= nil)
        end
    end

    frame.profPrev:SetEnabled(frame.professionPage > 1)
    frame.profNext:SetEnabled(frame.professionPage < professionMax)
    frame.profPrev:SetAlpha(frame.professionPage > 1 and 1 or 0.4)
    frame.profNext:SetAlpha(frame.professionPage < professionMax and 1 or 0.4)
    frame.profPageText:SetText(FC:GetText("ACCOUNT_RECIPE_PROF_PAGE", frame.professionPage, professionMax))

    frame.oppPrev:SetEnabled(frame.opportunityPage > 1)
    frame.oppNext:SetEnabled(frame.opportunityPage < opportunityMax)
    frame.oppPrev:SetAlpha(frame.opportunityPage > 1 and 1 or 0.4)
    frame.oppNext:SetAlpha(frame.opportunityPage < opportunityMax and 1 or 0.4)
    frame.oppPageText:SetText(FC:GetText("ACCOUNT_RECIPE_DIFF_PAGE", frame.opportunityPage, opportunityMax, #opportunities))
end
