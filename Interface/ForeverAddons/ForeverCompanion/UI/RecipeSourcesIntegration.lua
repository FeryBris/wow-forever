local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local previousCreateAccountRecipesFrame = UI.CreateAccountRecipesFrame
function UI:CreateAccountRecipesFrame(...)
    local frame = previousCreateAccountRecipesFrame(self, ...)
    if not frame or frame.fcRecipeSourcesIntegration then return frame end
    frame.fcRecipeSourcesIntegration = true

    local sourcesButton = Theme:CreateButton(frame, "Recipe Sources", 118, 30)
    sourcesButton:SetPoint("RIGHT", frame.refreshButton, "LEFT", -8, 0)
    sourcesButton:SetScript("OnClick", function()
        if UI.ShowRecipeSources then UI:ShowRecipeSources() end
    end)
    frame.recipeSourcesButton = sourcesButton

    frame.opportunityHitboxes = {}
    for i, line in ipairs(frame.opportunityLines or {}) do
        local hit = CreateFrame("Button", nil, frame)
        hit:SetPoint("TOPLEFT", line, "TOPLEFT", -4, 4)
        hit:SetSize(396, 36)
        hit:RegisterForClicks("LeftButtonUp")
        hit:SetScript("OnClick", function(self)
            if self.recipeID and UI.ShowRecipeSources then UI:ShowRecipeSources(self.recipeID) end
        end)
        hit:SetScript("OnEnter", function(self)
            if not self.recipeID then return end
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine(self.recipeName or "Recipe", 1.00, 0.82, 0.28)
            GameTooltip:AddLine("Click to view or add source information.", 0.45, 0.82, 1.00)
            GameTooltip:Show()
        end)
        hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
        frame.opportunityHitboxes[i] = hit
    end

    return frame
end

local previousRefreshAccountRecipesView = UI.RefreshAccountRecipesView
function UI:RefreshAccountRecipesView(...)
    previousRefreshAccountRecipesView(self, ...)
    local frame = self.accountRecipesFrame
    if not frame or not frame.opportunityHitboxes or not FC.AccountRecipes then return end

    local opportunities = FC.AccountRecipes:GetCrossCharacterOpportunities(#frame.opportunityHitboxes)
    for i, hit in ipairs(frame.opportunityHitboxes) do
        local recipe = opportunities[i]
        hit.recipeID = recipe and recipe.recipeID or nil
        hit.recipeName = recipe and recipe.name or nil
        hit:SetShown(recipe ~= nil)
    end
end

local previousCreateMainFrame = UI.CreateMainFrame
function UI:CreateMainFrame(...)
    local frame = previousCreateMainFrame(self, ...)
    if not frame or frame.fcRecipeSourcesButton then return frame end
    local page = frame.pages and frame.pages.Professions
    if not page or not page.skillsCard then return frame end

    local button = Theme:CreateButton(page.skillsCard, "Recipe Sources", 118, 26)
    button:SetPoint("TOPRIGHT", page.skillsCard, "TOPRIGHT", -8, -9)
    button:SetScript("OnClick", function()
        if UI.ShowRecipeSources then UI:ShowRecipeSources() end
    end)
    frame.fcRecipeSourcesButton = button
    return frame
end
