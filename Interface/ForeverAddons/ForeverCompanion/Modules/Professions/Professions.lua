local _, FC = ...

local Professions = {}
FC.Professions = Professions

local function findProfessionByIDOrName(professions, professionID, professionName)
    for _, profession in ipairs(professions or {}) do
        if profession.skillLineID == professionID or profession.name == professionName then
            return profession
        end
    end
    return nil
end

function Professions:Scan()
    FC.Suggestions:ClearSource("Professions")

    local character = FC:GetCurrentCharacter()
    if not character then
        return false
    end

    local snapshot = FC.API:GetProfessionSnapshot()
    if snapshot == nil then
        FC.Logger:Debug("PROFESSION", "Profession scan unavailable; preserving last valid cache")
        return false
    end

    character.professions = snapshot
    character.professionsLastSeen = time and time() or 0

    for _, profession in ipairs(snapshot) do
        if profession.maxSkill and profession.maxSkill > 0 and profession.skill < profession.maxSkill then
            local ratio = profession.skill / profession.maxSkill
            if ratio >= 0.85 then
                local remaining = profession.maxSkill - profession.skill
                local displayName = FC:GetProfessionDisplayName(profession)
                FC.Suggestions:Add({
                    id = "profession_" .. tostring(profession.skillLineID or profession.name),
                    source = "Professions",
                    category = "Profession",
                    priority = 55 + math.floor(ratio * 20),
                    title = FC:GetText("SUGG_PROF_NEAR_CAP_TITLE", displayName),
                    description = FC:GetText("SUGG_PROF_NEAR_CAP_DESC", profession.skill, profession.maxSkill, remaining),
                    metadata = {
                        professionID = profession.skillLineID,
                        dedupeKey = "profession-cap:" .. tostring(profession.skillLineID or profession.name),
                    },
                })
            end
        end
    end
    return true
end

function Professions:ScanCurrentRecipes()
    if not FC.API.capabilities.tradeSkillRecipes then
        return false
    end

    local now = GetTime and GetTime() or 0
    if self.lastSuccessfulRecipeScanAt and now > 0 and (now - self.lastSuccessfulRecipeScanAt) < 0.25 then
        return false
    end

    local snapshot = FC.API:GetCurrentProfessionRecipeSnapshot()
    if not snapshot or not snapshot.loaded or snapshot.total == 0 then
        return false
    end
    if snapshot.complete == false then
        FC.Logger:Debug("PROFESSION", "Recipe scan incomplete (%d/%d); preserving last valid cache",
            tonumber(snapshot.total) or 0, tonumber(snapshot.expectedTotal) or tonumber(snapshot.total) or 0)
        return false
    end

    if now > 0 then
        self.lastSuccessfulRecipeScanAt = now
    end

    local character = FC:GetCurrentCharacter()
    if not character then
        return false
    end

    local characterKey = character.key or FC:GetCharacterKey()
    character.recipeStats = character.recipeStats or {}
    character.recipeStats[snapshot.professionID] = {
        professionID = snapshot.professionID,
        professionName = snapshot.professionName,
        total = snapshot.total,
        learned = snapshot.learned,
        unlearned = snapshot.unlearned,
        lastSeen = time and time() or 0,
    }

    local profession = findProfessionByIDOrName(character.professions, snapshot.professionID, snapshot.professionName)
    if profession then
        profession.recipeTotal = snapshot.total
        profession.recipeLearned = snapshot.learned
        profession.recipeUnlearned = snapshot.unlearned
    end

    for _, recipe in ipairs(snapshot.recipes) do
        local recipeID = recipe.recipeID
        if recipeID then
            local cached = FC.DB.account.recipes[recipeID] or {
                recipeID = recipeID,
                learnedBy = {},
                seenBy = {},
            }

            cached.name = recipe.name
            cached.professionID = snapshot.professionID
            cached.professionName = snapshot.professionName
            cached.sourceType = recipe.sourceType
            cached.categoryID = recipe.categoryID
            cached.skillLineAbilityID = recipe.skillLineAbilityID
            cached.lastSeen = time and time() or 0
            cached.seenBy = cached.seenBy or {}
            cached.learnedBy = cached.learnedBy or {}
            cached.seenBy[characterKey] = time and time() or 0

            if recipe.learned then
                cached.learnedBy[characterKey] = true
            else
                cached.learnedBy[characterKey] = nil
            end

            FC.DB.account.recipes[recipeID] = cached
        end
    end

    FC.Logger:Debug("PROFESSION", "Cached %d recipes for %s (%d learned)", snapshot.total, snapshot.professionName, snapshot.learned)
    return true
end

function Professions:Refresh()
    self:Scan()
    self:ScanCurrentRecipes()
end

function Professions:OnEvent(event)
    if event == "PLAYER_LOGIN" or event == "SPELLS_CHANGED" or event == "SKILL_LINES_CHANGED" then
        self:Scan()
    elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" or event == "NEW_RECIPE_LEARNED" then
        self:Scan()
        self:ScanCurrentRecipes()
    end
end

FC:RegisterModule("Professions", Professions)
