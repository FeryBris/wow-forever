local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local function setText(fontString, text, color)
    if not fontString then return end
    color = color or Theme.colors.text
    fontString:SetText(text or "")
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

function UI:CreateAccountRecipesFrame()
    if self.accountRecipesFrame then return self.accountRecipesFrame end

    local frame = Theme:CreatePanel(UIParent, Theme.colors.navy, Theme.colors.gold)
    frame:SetSize(840, 610)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    frame.title = Theme:CreateText(frame, "GameFontNormalHuge", "ACCOUNT RECIPE MATRIX")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -18)
    frame.title:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])

    frame.closeButton = Theme:CreateButton(frame, "X", 32, 30)
    frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -14)
    frame.closeButton:SetScript("OnClick", function() frame:Hide() end)

    frame.refreshButton = Theme:CreateButton(frame, "Refresh", 90, 30)
    frame.refreshButton:SetPoint("RIGHT", frame.closeButton, "LEFT", -8, 0)
    frame.refreshButton:SetScript("OnClick", function()
        FC:RefreshModules("account-recipes")
        UI:RefreshAccountRecipesView()
    end)

    frame.summary = Theme:CreateText(frame, "GameFontHighlight", "")
    frame.summary:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -64)
    frame.summary:SetWidth(796)
    frame.summary:SetJustifyH("LEFT")

    frame.professionTitle = Theme:CreateSectionTitle(frame, "Cached Professions")
    frame.professionTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -104)

    frame.professionLines = {}
    for i = 1, 8 do
        local line = Theme:CreateText(frame, "GameFontHighlightSmall", "")
        line:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -136 - ((i - 1) * 34))
        line:SetWidth(365)
        line:SetJustifyH("LEFT")
        frame.professionLines[i] = line
    end

    frame.opportunityTitle = Theme:CreateSectionTitle(frame, "Known On Another Character")
    frame.opportunityTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 414, -104)

    frame.opportunityLines = {}
    for i = 1, 10 do
        local line = Theme:CreateText(frame, "GameFontHighlightSmall", "")
        line:SetPoint("TOPLEFT", frame, "TOPLEFT", 416, -136 - ((i - 1) * 39))
        line:SetWidth(396)
        line:SetJustifyH("LEFT")
        line:SetJustifyV("TOP")
        frame.opportunityLines[i] = line
    end

    frame.note = Theme:CreateText(frame, "GameFontDisableSmall",
        "Recipe knowledge is based only on profession windows that Forever Companion has observed. 'Known on another character' means the current character previously saw the recipe as unlearned while another cached character had learned it; it does not imply the recipe can be transferred.")
    frame.note:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 18)
    frame.note:SetWidth(796)
    frame.note:SetJustifyH("LEFT")

    self.accountRecipesFrame = frame
    return frame
end

function UI:RefreshAccountRecipesView()
    local frame = self:CreateAccountRecipesFrame()
    local module = FC.AccountRecipes
    if not module then
        setText(frame.summary, "Account recipe module unavailable.", Theme.colors.muted)
        return
    end

    local summary = module:GetAccountSummary()
    setText(frame.summary, string.format("%d cached recipe(s) • %d learned somewhere • %d profession cache(s) • %d cross-character opportunity/opportunities",
        tonumber(summary.totalSeen) or 0,
        tonumber(summary.learnedSomewhere) or 0,
        tonumber(summary.professionCount) or 0,
        tonumber(summary.crossCharacterOpportunities) or 0), Theme.colors.text)

    local professions = module:GetProfessionSummaries()
    for i = 1, #frame.professionLines do
        local profession = professions[i]
        if profession then
            local currentText = profession.currentSeen > 0
                and string.format("current %d/%d", tonumber(profession.currentLearned) or 0, tonumber(profession.currentSeen) or 0)
                or "current not scanned"
            setText(frame.professionLines[i], string.format("%s\n   account %d/%d learned • %s • %d elsewhere-known gap(s)",
                tostring(profession.professionName),
                tonumber(profession.learnedSomewhere) or 0,
                tonumber(profession.totalSeen) or 0,
                currentText,
                tonumber(profession.crossCharacterOpportunities) or 0),
                profession.crossCharacterOpportunities > 0 and Theme.colors.yellow or Theme.colors.text)
        else
            setText(frame.professionLines[i], i == 1 and "Open profession windows on your characters to build the recipe matrix." or "", Theme.colors.muted)
        end
    end

    local opportunities = module:GetCrossCharacterOpportunities(#frame.opportunityLines)
    for i = 1, #frame.opportunityLines do
        local recipe = opportunities[i]
        if recipe then
            local owners = table.concat(recipe.learnedBy or {}, ", ")
            setText(frame.opportunityLines[i], string.format("%s — %s\n   Known by: %s",
                tostring(recipe.name), tostring(recipe.professionName), owners), Theme.colors.yellow)
        else
            setText(frame.opportunityLines[i], i == 1 and "No cross-character recipe differences are currently known from the cache." or "", Theme.colors.muted)
        end
    end
end

function UI:ShowAccountRecipes()
    local frame = self:CreateAccountRecipesFrame()
    self:RefreshAccountRecipesView()
    frame:Show()
end

local previousCreateMainFrame = UI.CreateMainFrame
function UI:CreateMainFrame(...)
    local frame = previousCreateMainFrame(self, ...)
    if frame and not frame.fcAccountRecipesButton and frame.pages and frame.pages.Professions and frame.pages.Professions.skillsCard then
        local button = Theme:CreateButton(frame.pages.Professions.skillsCard, "Account Recipes", 125, 26)
        if frame.fcProfessionPlannerButton then
            button:SetPoint("RIGHT", frame.fcProfessionPlannerButton, "LEFT", -8, 0)
        else
            button:SetPoint("TOPRIGHT", frame.pages.Professions.skillsCard, "TOPRIGHT", -118, -9)
        end
        button:SetScript("OnClick", function() UI:ShowAccountRecipes() end)
        frame.fcAccountRecipesButton = button
    end
    return frame
end
