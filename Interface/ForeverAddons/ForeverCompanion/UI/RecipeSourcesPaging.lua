local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme
local PAGE_SIZE = 10

local function getRows(frame)
    if not FC.RecipeSources then return {} end
    return FC.RecipeSources:GetKnownRecipeRows(frame.query or "", 500)
end

local function updatePaging(frame, rows)
    local maxPage = math.max(1, math.ceil(#rows / PAGE_SIZE))

    if frame.fcFollowSelection and frame.selectedRecipeID then
        for index, row in ipairs(rows) do
            if tostring(row.recipeID) == tostring(frame.selectedRecipeID) then
                frame.recipePage = math.ceil(index / PAGE_SIZE)
                break
            end
        end
        frame.fcFollowSelection = nil
    end

    frame.recipePage = math.max(1, math.min(tonumber(frame.recipePage) or 1, maxPage))
    local startIndex = ((frame.recipePage - 1) * PAGE_SIZE) + 1

    for i, button in ipairs(frame.recipeRows or {}) do
        local row = rows[startIndex + i - 1]
        if row then
            button.recipeRow = row
            button:Show()
            local sourceCount = #(row.sources or {})
            button:SetFCText(string.format("%s%s\n%s • %d source note(s)",
                tostring(frame.selectedRecipeID) == tostring(row.recipeID) and "◆  " or "",
                tostring(row.name), tostring(row.professionName or "Profession"), sourceCount))
            button:SetFCActive(tostring(frame.selectedRecipeID) == tostring(row.recipeID))
        else
            button.recipeRow = nil
            button:Hide()
        end
    end

    if frame.recipePrev then
        frame.recipePrev:SetEnabled(frame.recipePage > 1)
        frame.recipePrev:SetAlpha(frame.recipePage > 1 and 1 or 0.4)
    end
    if frame.recipeNext then
        frame.recipeNext:SetEnabled(frame.recipePage < maxPage)
        frame.recipeNext:SetAlpha(frame.recipePage < maxPage and 1 or 0.4)
    end
    if frame.recipePageText then
        frame.recipePageText:SetText(string.format("Page %d / %d • %d recipe(s)", frame.recipePage, maxPage, #rows))
    end
end

local previousCreateRecipeSourcesFrame = UI.CreateRecipeSourcesFrame
function UI:CreateRecipeSourcesFrame(...)
    local frame = previousCreateRecipeSourcesFrame(self, ...)
    if not frame or frame.fcPaging then return frame end
    frame.fcPaging = true
    frame.recipePage = 1

    frame.recipePrev = Theme:CreateButton(frame, "Previous", 90, 26)
    frame.recipePrev:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -560)
    frame.recipeNext = Theme:CreateButton(frame, "Next", 90, 26)
    frame.recipeNext:SetPoint("LEFT", frame.recipePrev, "RIGHT", 8, 0)
    frame.recipePageText = Theme:CreateText(frame, "GameFontHighlightSmall", "")
    frame.recipePageText:SetPoint("LEFT", frame.recipeNext, "RIGHT", 10, 0)
    frame.recipePageText:SetWidth(220)

    frame.recipePrev:SetScript("OnClick", function()
        frame.recipePage = math.max(1, (frame.recipePage or 1) - 1)
        UI:RefreshRecipeSourcesView()
    end)
    frame.recipeNext:SetScript("OnClick", function()
        frame.recipePage = (frame.recipePage or 1) + 1
        UI:RefreshRecipeSourcesView()
    end)

    local originalSearchClick = frame.searchButton:GetScript("OnClick")
    frame.searchButton:SetScript("OnClick", function(...)
        frame.recipePage = 1
        if originalSearchClick then originalSearchClick(...) end
    end)
    frame.search:SetScript("OnEnterPressed", function(self)
        frame.recipePage = 1
        frame.query = self:GetText() or ""
        self:ClearFocus()
        UI:RefreshRecipeSourcesView()
    end)

    return frame
end

local previousRefreshRecipeSourcesView = UI.RefreshRecipeSourcesView
function UI:RefreshRecipeSourcesView(...)
    previousRefreshRecipeSourcesView(self, ...)
    local frame = self.recipeSourcesFrame
    if not frame or not frame.fcPaging then return end
    updatePaging(frame, getRows(frame))
end

local previousShowRecipeSources = UI.ShowRecipeSources
function UI:ShowRecipeSources(recipeID)
    local frame = self:CreateRecipeSourcesFrame()
    if recipeID then frame.fcFollowSelection = true end
    return previousShowRecipeSources(self, recipeID)
end
