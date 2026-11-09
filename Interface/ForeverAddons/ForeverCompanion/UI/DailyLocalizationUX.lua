local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local function setText(fontString, text, color)
    if not fontString then return end
    color = color or Theme.colors.text
    fontString:SetText(text or "")
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function formatDuration(seconds)
    seconds = tonumber(seconds) or 0
    if seconds <= 0 then return FC:GetText("CAMP_EXPIRED") end
    if seconds >= 3600 then
        return FC:GetText("CAMP_DURATION_HMS", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60))
    end
    return FC:GetText("CAMP_DURATION_MS", math.floor(seconds / 60), math.floor(seconds % 60))
end

local previousRefreshCampsView = UI.RefreshCampsView
function UI:RefreshCampsView(...)
    previousRefreshCampsView(self, ...)
    local frame = self.campsFrame
    if not frame then return end

    if frame.note then frame.note:SetText(FC:GetText("CAMP_NOTE")) end
    local snapshot = FC.Camps and FC.Camps:GetSnapshot() or nil
    if not snapshot then
        setText(frame.summary, FC:GetText("CAMP_DATA_NOT_SCANNED"), Theme.colors.muted)
        return
    end

    local active = snapshot.benefit and snapshot.benefit.active
    setText(frame.summary, FC:GetText(active and "CAMP_BENEFITS_DETECTED" or "CAMP_NO_BENEFITS"), active and Theme.colors.green or Theme.colors.muted)

    if active then
        local label = snapshot.benefit.name or FC:GetText("CAMP_BENEFITS_FALLBACK")
        local remaining = snapshot.benefit.remaining and formatDuration(snapshot.benefit.remaining) or FC:GetText("CAMP_DURATION_UNAVAILABLE")
        setText(frame.benefitLines[1], "✓  " .. tostring(label), Theme.colors.green)
        setText(frame.benefitLines[2], FC:GetText("CAMP_REMAINING", remaining), Theme.colors.text)
    else
        setText(frame.benefitLines[1], "•  " .. FC:GetText("CAMP_AURA_INACTIVE"), Theme.colors.muted)
        setText(frame.benefitLines[2], FC:GetText("CAMP_REST_HINT"), Theme.colors.muted)
    end

    local rested = snapshot.restedXP
    if rested then
        setText(frame.benefitLines[3], FC:GetText("CAMP_RESTED_POOL", tonumber(rested.percentOfLevel) or 0),
            (tonumber(rested.percentOfLevel) or 0) < 5 and Theme.colors.yellow or Theme.colors.text)
    else
        setText(frame.benefitLines[3], FC:GetText("CAMP_RESTED_UNAVAILABLE"), Theme.colors.muted)
    end
    setText(frame.benefitLines[4], FC:GetText("CAMP_SHARED_COOLDOWN"), Theme.colors.muted)

    local kits = {}
    for _, kit in ipairs(FC.CampData and FC.CampData.hostKits or {}) do
        kits[#kits + 1] = FC:GetText("CAMP_KIT_SLOTS", tostring(kit.name), tonumber(kit.capacity) or 0)
    end
    setText(frame.benefitLines[5], FC:GetText("CAMP_HOST_KITS", table.concat(kits, " • ")), Theme.colors.muted)

    for index = 1, #frame.contributionLines do
        local contribution = snapshot.contributions and snapshot.contributions[index]
        if contribution then
            local qualifier = contribution.blueprintConfirmed and FC:GetText("CAMP_QUAL_RECIPE")
                or (contribution.recipeConfirmed and FC:GetText("CAMP_QUAL_ENTRY") or FC:GetText("CAMP_QUAL_SKILL"))
            setText(frame.contributionLines[index], FC:GetText("CAMP_CONTRIBUTION_ROW",
                tostring(contribution.professionName), tonumber(contribution.skill) or 0, tonumber(contribution.maxSkill) or 0,
                tonumber(contribution.tier) or 1, tostring(contribution.feature), qualifier),
                contribution.blueprintConfirmed and Theme.colors.green or ((tonumber(contribution.tier) or 0) >= 3 and Theme.colors.gold or Theme.colors.text))
        elseif index == 1 then
            setText(frame.contributionLines[index], FC:GetText("CAMP_NO_CONTRIBUTION"), Theme.colors.muted)
        else
            setText(frame.contributionLines[index], "")
        end
    end

    local catalog = {}
    for _, definition in pairs(FC.CampData and FC.CampData.professions or {}) do
        if definition.hostingProfession then
            catalog[#catalog + 1] = FC:GetText("CAMP_HOST_CATALOG", tostring(definition.name))
        else
            local tierNames = {}
            for _, tier in ipairs(definition.tiers or {}) do
                tierNames[#tierNames + 1] = string.format("%s@%d", tostring(tier.name), tonumber(tier.skill) or 0)
            end
            catalog[#catalog + 1] = FC:GetText("CAMP_CATALOG_ROW", tostring(definition.name), table.concat(tierNames, " → "))
        end
    end
    table.sort(catalog)
    for index = 1, #frame.catalogLines do setText(frame.catalogLines[index], catalog[index] or "", Theme.colors.muted) end

    if FC.CampFinder then
        local provider = FC.CampFinder:GetDetectedProvider()
        if provider then
            setText(frame.finderStatus, FC:GetText("CAMP_FINDER_PROVIDER",
                tostring(provider.name or provider.id or "Provider"), provider.version and (" " .. tostring(provider.version)) or ""), Theme.colors.muted)
        else
            setText(frame.finderStatus, FC:GetText("CAMP_FINDER_NONE"), Theme.colors.muted)
        end
    else
        setText(frame.finderStatus, FC:GetText("CAMP_FINDER_UNAVAILABLE"), Theme.colors.muted)
    end
end

local function ownerSummary(owners)
    local result = {}
    for key, owner in pairs(owners or {}) do
        local locations = {}
        for location, data in pairs(owner.locations or {}) do
            locations[#locations + 1] = string.format("%s %d", tostring(location), tonumber(data.count) or 0)
        end
        table.sort(locations)
        result[#result + 1] = string.format("%s: %d%s", tostring(key), tonumber(owner.count) or 0,
            #locations > 0 and (" (" .. table.concat(locations, ", ") .. ")") or "")
    end
    table.sort(result)
    return result
end

local previousRefreshItemsView = UI.RefreshItemsView
function UI:RefreshItemsView(...)
    previousRefreshItemsView(self, ...)
    local frame = self.itemsFrame
    if not frame then return end
    if frame.note then frame.note:SetText(FC:GetText("ITEM_NOTE")) end

    local analysis = frame.analysis
    if not analysis then
        setText(frame.summary, frame.errorText or FC:GetText("ITEM_SEARCH_HELP"), frame.errorText and Theme.colors.yellow or Theme.colors.muted)
        for _, line in ipairs(frame.detailLines or {}) do setText(line, "") end
        return
    end

    local base = analysis.base
    setText(frame.summary, FC:GetText("ITEM_SUMMARY", tostring(base.name), tonumber(base.itemID) or 0, tonumber(analysis.totalOwned) or 0), Theme.colors.gold)

    local lines = {}
    lines[#lines + 1] = FC:GetText("ITEM_TYPE_LINE", tostring(base.itemType or "?"), tostring(base.itemSubType or "?"), tostring(base.itemLevel or "?"), tostring(base.minLevel or "?"))
    lines[#lines + 1] = FC:GetText("ITEM_EQUIP_LINE", tostring(base.equipLoc or FC:GetText("ITEM_NONE")), FC:GetText(base.isCraftingReagent and "ITEM_YES" or "ITEM_NO"))

    if base.setID then
        lines[#lines + 1] = FC:GetText("ITEM_SET_LINE", tostring(base.setName or FC:GetText("ITEM_UNKNOWN_SET")), tonumber(base.setID) or 0, tonumber(analysis.cachedSetPieceTypesOwned) or 0)
        if #analysis.setPeers > 0 then
            local peers = {}
            for _, peer in ipairs(analysis.setPeers) do peers[#peers + 1] = string.format("%s x%d", tostring(peer.name), tonumber(peer.total) or 0) end
            lines[#lines + 1] = FC:GetText("ITEM_OTHER_PIECES", table.concat(peers, ", "))
        end
    else
        lines[#lines + 1] = FC:GetText("ITEM_NO_SET")
    end

    local owners = ownerSummary(analysis.owners)
    lines[#lines + 1] = #owners > 0 and FC:GetText("ITEM_OWNERSHIP", table.concat(owners, " • ")) or FC:GetText("ITEM_NO_OWNERSHIP")

    local used = analysis.crafting and analysis.crafting.usedByGoals or {}
    local output = analysis.crafting and analysis.crafting.outputOfGoals or {}
    if #used > 0 then
        local names = {}
        for _, goal in ipairs(used) do names[#names + 1] = tostring(goal.name) end
        lines[#lines + 1] = FC:GetText("ITEM_NEEDED_GOALS", table.concat(names, ", "))
    end
    if #output > 0 then
        local names = {}
        for _, goal in ipairs(output) do names[#names + 1] = tostring(goal.name) end
        lines[#lines + 1] = FC:GetText("ITEM_OUTPUT_GOALS", table.concat(names, ", "))
    end
    if #used == 0 and #output == 0 then lines[#lines + 1] = FC:GetText("ITEM_NO_CRAFT_RELEVANCE") end
    if base.description and base.description ~= "" then lines[#lines + 1] = FC:GetText("ITEM_DESCRIPTION", tostring(base.description)) end

    for index = 1, #frame.detailLines do
        setText(frame.detailLines[index], lines[index] or "", index <= 2 and Theme.colors.text or Theme.colors.muted)
    end
end

local previousRefreshProfessionPlannerView = UI.RefreshProfessionPlannerView
function UI:RefreshProfessionPlannerView(...)
    previousRefreshProfessionPlannerView(self, ...)
    local frame = self.professionPlannerFrame
    if not frame then return end
    if frame.note then frame.note:SetText(FC:GetText("PROF_PLAN_NOTE")) end

    local plan = frame.currentPlan
    if not plan then return end
    setText(frame.summary, FC:GetText("PROF_PLAN_SUMMARY", tostring(plan.name), tonumber(plan.current) or 0, tonumber(plan.target) or 0, tonumber(plan.remaining) or 0), Theme.colors.text)
end
