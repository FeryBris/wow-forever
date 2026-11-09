local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local function setText(fontString, text, color)
    if not fontString then return end
    fontString:SetText(text or "")
    color = color or Theme.colors.text
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function refreshPreparationExtras()
    local frame = UI.frame
    local page = frame and frame.pages and frame.pages.Preparation
    local character = FC:GetCurrentCharacter()
    if not page or not character then return end

    local preparation = character.preparation or {}
    local hearthstoneCount = preparation.hearthstoneCount
    local projectileCount = preparation.projectileCount

    setText(page.checkLines[3], hearthstoneCount and hearthstoneCount > 0
        and string.format("✓  Hearthstone: %d in bags", hearthstoneCount)
        or "•  Hearthstone not found in current bags",
        hearthstoneCount and hearthstoneCount > 0 and Theme.colors.green or Theme.colors.muted)

    if character.classFile == "HUNTER" then
        local ammoColor = projectileCount and (projectileCount <= 100 and Theme.colors.red or (projectileCount <= 300 and Theme.colors.yellow or Theme.colors.green)) or Theme.colors.muted
        setText(page.checkLines[4], projectileCount ~= nil
            and string.format("%s  Hunter ammo: %d", projectileCount <= 100 and "!" or "✓", projectileCount)
            or "?  Hunter ammo unavailable", ammoColor)
    else
        setText(page.checkLines[4], "•  No verified class-specific supply rule is active for this class", Theme.colors.muted)
    end

    local freshness = FC.Inventory and FC.Inventory:GetFreshnessSummary() or nil
    if freshness then
        setText(page.checkLines[7], string.format("%s  Account cache: %d character(s), %d stale bag cache(s)",
            freshness.staleCharacters > 0 and "!" or "✓", freshness.characters, freshness.staleCharacters),
            freshness.staleCharacters > 0 and Theme.colors.yellow or Theme.colors.green)
    else
        setText(page.checkLines[7], "•  Account cache freshness unavailable", Theme.colors.muted)
    end

    local camp = FC.Camps and FC.Camps:GetSnapshot() or nil
    if camp then
        setText(page.checkLines[8], string.format("%s  Camp: benefits %s • %d contribution option(s)",
            camp.benefit and "✓" or "•", camp.benefit and "active" or "not detected", #(camp.contributions or {})),
            camp.benefit and Theme.colors.green or Theme.colors.muted)
    else
        setText(page.checkLines[8], "•  Camp snapshot unavailable in the current context", Theme.colors.muted)
    end
end

if hooksecurefunc then
    hooksecurefunc(UI, "RefreshDashboard", refreshPreparationExtras)
else
    local originalRefresh = UI.RefreshDashboard
    UI.RefreshDashboard = function(self, ...)
        originalRefresh(self, ...)
        refreshPreparationExtras()
    end
end
