local _, FC = ...

local Camps = {}
FC.Camps = Camps

local SOURCE = "Camps"

local function normalizeName(value)
    return string.lower(tostring(value or "")):gsub("[^%w]", "")
end

local function findCampDefinition(profession)
    if not profession or not FC.CampData then return nil end
    local direct = FC.CampData.professions[profession.skillLineID]
    if direct then return direct end

    local professionName = normalizeName(profession.name)
    for _, definition in pairs(FC.CampData.professions or {}) do
        if normalizeName(definition.name) == professionName then return definition end
    end
    return nil
end

local function findKnownCampRecipe(characterKey, profession, featureName)
    local target = normalizeName(featureName)
    if target == "" then return nil end
    for recipeID, recipe in pairs(FC.DB and FC.DB.account and FC.DB.account.recipes or {}) do
        local professionMatches = tonumber(recipe.professionID) == tonumber(profession.skillLineID)
            or recipe.professionName == profession.name
        if professionMatches and recipe.learnedBy and recipe.learnedBy[characterKey] then
            local recipeName = normalizeName(recipe.name)
            if recipeName == target or string.find(recipeName, target, 1, true) or string.find(target, recipeName, 1, true) then
                return tonumber(recipeID) or recipeID
            end
        end
    end
    return nil
end

local function getEligibleTier(profession)
    local definition = findCampDefinition(profession)
    if not definition then return nil, nil end

    local skill = tonumber(profession.skill) or 0
    local eligible
    local eligibleIndex
    for index, tier in ipairs(definition.tiers or {}) do
        if skill >= (tonumber(tier.skill) or math.huge) then
            eligible = tier
            eligibleIndex = index
        end
    end
    return definition, eligible, eligibleIndex
end

local function buildContributions(character)
    local contributions = {}
    local characterKey = character and (character.key or FC:GetCharacterKey())
    for _, profession in ipairs(character and character.professions or {}) do
        local definition, tier, tierIndex = getEligibleTier(profession)
        if definition and tier then
            local recipeID = findKnownCampRecipe(characterKey, profession, tier.name)
            contributions[#contributions + 1] = {
                skillLineID = profession.skillLineID,
                campKey = definition.key,
                professionName = profession.name or definition.name,
                skill = tonumber(profession.skill) or 0,
                maxSkill = tonumber(profession.maxSkill) or 0,
                tier = tierIndex,
                feature = tier.name,
                benefit = tier.benefit,
                requiredSkill = tier.skill,
                recipeID = recipeID,
                recipeConfirmed = recipeID ~= nil or tierIndex == 1,
                blueprintConfirmed = recipeID ~= nil,
            }
        end
    end

    table.sort(contributions, function(a, b)
        if a.tier == b.tier then return tostring(a.professionName) < tostring(b.professionName) end
        return a.tier > b.tier
    end)
    return contributions
end

local function addSuggestions(snapshot)
    FC.Suggestions:ClearSource(SOURCE)
    if not snapshot then return end

    if snapshot.benefit and snapshot.benefit.active then
        local remaining = tonumber(snapshot.benefit.remaining)
        if remaining and remaining > 0 and remaining <= 300 then
            FC.Suggestions:Add({
                id = "camp_benefit_expiring",
                source = SOURCE,
                category = "Camp",
                priority = 54,
                title = FC:GetText("SUGG_CAMP_EXPIRE_TITLE"),
                description = FC:GetText("SUGG_CAMP_EXPIRE_DESC", math.max(1, math.ceil(remaining / 60))),
            })
        end
    elseif #snapshot.contributions > 0 then
        local best = snapshot.contributions[1]
        local recipeSuffix = best.blueprintConfirmed and FC:GetText("SUGG_CAMP_RECIPE_CACHED") or ""
        FC.Suggestions:Add({
            id = "camp_contribution_available",
            source = SOURCE,
            category = "Camp",
            priority = 30,
            title = FC:GetText("SUGG_CAMP_CONTRIBUTION_TITLE"),
            description = FC:GetText("SUGG_CAMP_CONTRIBUTION_DESC", tostring(best.professionName), tostring(best.feature), tonumber(best.tier) or 1, recipeSuffix),
        })
    end

    local rested = snapshot.restedXP
    if rested and tonumber(rested.percentOfLevel) and rested.percentOfLevel < 5 then
        for _, contribution in ipairs(snapshot.contributions or {}) do
            if contribution.campKey == "LEATHERWORKING" then
                FC.Suggestions:Add({
                    id = "camp_tent_rested_xp",
                    source = SOURCE,
                    category = "Camp",
                    priority = 44,
                    title = FC:GetText("SUGG_CAMP_RESTED_TITLE"),
                    description = FC:GetText("SUGG_CAMP_RESTED_DESC", rested.percentOfLevel),
                })
                break
            end
        end
    end
end

function Camps:GetSnapshot()
    local character = FC:GetCurrentCharacter()
    return character and character.campSnapshot or nil
end

function Camps:Scan(reason)
    local character = FC:GetCurrentCharacter()
    if not character then return end

    if not FC.API or not FC.API.capabilities or not FC.API.capabilities.camps then
        character.campSnapshot = nil
        FC.Suggestions:ClearSource(SOURCE)
        FC.Logger:Debug("CAMP", "Camp capability unavailable; snapshot cleared")
        return
    end

    local snapshot = {
        benefit = FC.API:GetCampBenefitSnapshot(),
        restedXP = FC.API:GetRestedXPSnapshot(),
        contributions = buildContributions(character),
        scannedAt = time and time() or 0,
        reason = reason or "manual",
    }

    character.campSnapshot = snapshot
    addSuggestions(snapshot)
    FC.Logger:Debug("CAMP", "Camp snapshot: benefit=%s contributions=%d", snapshot.benefit and "yes" or "no", #snapshot.contributions)
end

function Camps:Refresh(reason) self:Scan(reason) end

function Camps:OnEvent(event, unit)
    if event == "UNIT_AURA" and unit ~= "player" then return end

    if event == "PLAYER_LOGIN"
        or event == "PLAYER_ENTERING_WORLD"
        or event == "SKILL_LINES_CHANGED"
        or event == "TRADE_SKILL_LIST_UPDATE"
        or event == "NEW_RECIPE_LEARNED"
        or event == "UNIT_AURA"
        or event == "PLAYER_XP_UPDATE"
        or event == "UPDATE_EXHAUSTION"
    then
        self:Scan(event)
        if FC.UI and FC.UI.RefreshCampsView then FC.UI:RefreshCampsView() end
    end
end

FC:RegisterModule("Camps", Camps)
