local _, FC = ...

local Milestones = {}
FC.Milestones = Milestones

local SOURCE = "Milestones"

local function moduleEnabled(name)
    return type(FC.IsModuleEnabled) ~= "function" or FC:IsModuleEnabled(name)
end

local function capabilityAvailable(name)
    return FC.API and FC.API.capabilities and FC.API.capabilities[name] == true
end

local function getStore()
    if not FC.DB or not FC.DB.account then return nil end
    FC.DB.account.milestones = FC.DB.account.milestones or {}
    return FC.DB.account.milestones
end

local function record(id, title, category, description, characterKey, metadata)
    local store = getStore()
    if not store then return false end
    if store[id] then
        store[id].category = category or store[id].category
        store[id].characterKey = characterKey or store[id].characterKey
        if type(metadata) == "table" then
            store[id].metadata = store[id].metadata or {}
            for key, value in pairs(metadata) do store[id].metadata[key] = value end
        end
        return false
    end
    store[id] = {
        id = id,
        title = title,
        category = category,
        description = description,
        characterKey = characterKey,
        completedAt = time and time() or 0,
        metadata = type(metadata) == "table" and metadata or {},
    }
    Milestones.sessionNew = Milestones.sessionNew or {}
    Milestones.sessionNew[id] = true
    return true
end

function Milestones:GetDisplayTitle(milestone)
    if type(milestone) ~= "table" then return "" end
    local metadata = milestone.metadata or {}
    if metadata.kind == "ProfessionCap" and metadata.professionID then
        return FC:GetText("MILESTONE_PROF_CAP_TITLE",
            FC:GetProfessionDisplayName(metadata.professionID, metadata.professionName),
            tonumber(metadata.skill) or 0,
            tonumber(metadata.maxSkill) or 0)
    elseif metadata.kind == "CampTier" and metadata.professionID then
        return FC:GetText("MILESTONE_CAMP_TIER_TITLE",
            FC:GetProfessionDisplayName(metadata.professionID, metadata.professionName),
            tonumber(metadata.tier) or 0)
    elseif metadata.kind == "LegacyCategory" then
        return FC:GetText("MILESTONE_LEGACY_CATEGORY_TITLE", tostring(metadata.categoryName or FC:GetText("MILESTONE_LEGACY_CATEGORY_FALLBACK")))
    elseif metadata.kind == "LegacyAll" then
        return FC:GetText("MILESTONE_LEGACY_ALL_TITLE")
    elseif metadata.kind == "CraftReady" then
        return FC:GetText("MILESTONE_CRAFT_READY_TITLE", tostring(metadata.recipeName or milestone.title or ""))
    end
    return tostring(milestone.title or "")
end

function Milestones:GetDisplayDescription(milestone)
    if type(milestone) ~= "table" then return "" end
    local metadata = milestone.metadata or {}
    if metadata.kind == "ProfessionCap" then
        return FC:GetText("MILESTONE_PROF_CAP_DESC", tostring(metadata.characterName or milestone.characterKey or "?"))
    elseif metadata.kind == "CampTier" then
        return FC:GetText("MILESTONE_CAMP_TIER_DESC",
            tostring(metadata.characterName or milestone.characterKey or "?"), tostring(metadata.feature or ""))
    elseif metadata.kind == "LegacyCategory" then
        return FC:GetText("MILESTONE_LEGACY_CATEGORY_DESC", tonumber(metadata.total) or 0)
    elseif metadata.kind == "LegacyAll" then
        return FC:GetText("MILESTONE_LEGACY_ALL_DESC", tonumber(metadata.completed) or 0, tonumber(metadata.total) or 0)
    elseif metadata.kind == "CraftReady" then
        return FC:GetText("MILESTONE_CRAFT_READY_DESC", tonumber(metadata.quantity) or 1)
    end
    return tostring(milestone.description or FC:GetText("MILESTONE_DEFAULT_DESC"))
end

local function scanProfessions()
    if not moduleEnabled("Professions") then return end
    for characterKey, character in pairs(FC.DB and FC.DB.account and FC.DB.account.characters or {}) do
        for _, profession in ipairs(character.professions or {}) do
            local skill = tonumber(profession.skill) or 0
            local maxSkill = tonumber(profession.maxSkill) or 0
            if maxSkill > 0 and skill >= maxSkill then
                local professionID = profession.skillLineID or profession.name
                local id = string.format("profession_cap_%s_%s_%d", characterKey, tostring(professionID), maxSkill)
                record(id,
                    FC:GetText("MILESTONE_PROF_CAP_TITLE", FC:GetProfessionDisplayName(profession), skill, maxSkill),
                    "Profession",
                    FC:GetText("MILESTONE_PROF_CAP_DESC", tostring(character.name or characterKey)),
                    characterKey,
                    {
                        kind = "ProfessionCap",
                        professionID = profession.skillLineID,
                        professionName = profession.name,
                        skill = skill,
                        maxSkill = maxSkill,
                        characterName = character.name or characterKey,
                    })
            end
        end
    end
end

local function scanLegacy()
    if not moduleEnabled("Legacy") or not capabilityAvailable("legacy") then return end
    local snapshot = FC.Legacy and FC.Legacy:GetSnapshot() or nil
    if not snapshot then return end
    for _, category in ipairs(snapshot.categories or {}) do
        local total = tonumber(category.total) or 0
        local completed = tonumber(category.completed) or 0
        if total > 0 and completed >= total then
            local categoryName = tostring(category.title or FC:GetText("MILESTONE_LEGACY_CATEGORY_FALLBACK"))
            record("legacy_category_" .. tostring(category.id),
                FC:GetText("MILESTONE_LEGACY_CATEGORY_TITLE", categoryName),
                "Legacy",
                FC:GetText("MILESTONE_LEGACY_CATEGORY_DESC", total),
                nil,
                {
                    kind = "LegacyCategory",
                    categoryID = category.id,
                    categoryName = categoryName,
                    total = total,
                })
        end
    end
    if tonumber(snapshot.total) and snapshot.total > 0 and tonumber(snapshot.remaining) == 0 then
        record("legacy_all_discovered",
            FC:GetText("MILESTONE_LEGACY_ALL_TITLE"),
            "Legacy",
            FC:GetText("MILESTONE_LEGACY_ALL_DESC", tonumber(snapshot.completed) or 0, tonumber(snapshot.total) or 0),
            nil,
            {
                kind = "LegacyAll",
                completed = tonumber(snapshot.completed) or 0,
                total = tonumber(snapshot.total) or 0,
            })
    end
end

local function scanCraftingGoals()
    if not moduleEnabled("CraftingGoals") or not FC.CraftingGoals then return end
    for _, goal in ipairs(FC.CraftingGoals:GetGoals()) do
        local progress = FC.CraftingGoals:GetProgress(goal)
        if progress.ready then
            record("crafting_ready_" .. tostring(goal.recipeID),
                FC:GetText("MILESTONE_CRAFT_READY_TITLE", tostring(goal.name)),
                "Crafting",
                FC:GetText("MILESTONE_CRAFT_READY_DESC", tonumber(goal.quantity) or 1),
                nil,
                {
                    kind = "CraftReady",
                    recipeID = goal.recipeID,
                    recipeName = goal.name,
                    quantity = tonumber(goal.quantity) or 1,
                })
        end
    end
end

local function scanCampProgress()
    if not moduleEnabled("Camps") or not capabilityAvailable("camps") then return end
    for characterKey, character in pairs(FC.DB and FC.DB.account and FC.DB.account.characters or {}) do
        local snapshot = character.campSnapshot
        for _, contribution in ipairs(snapshot and snapshot.contributions or {}) do
            local tier = tonumber(contribution.tier) or 0
            if tier > 0 then
                record(string.format("camp_tier_%s_%s_%d", characterKey, tostring(contribution.skillLineID), tier),
                    FC:GetText("MILESTONE_CAMP_TIER_TITLE", FC:GetProfessionDisplayName(contribution.skillLineID, contribution.professionName), tier),
                    "Camp",
                    FC:GetText("MILESTONE_CAMP_TIER_DESC", tostring(character.name or characterKey), tostring(contribution.feature)),
                    characterKey,
                    {
                        kind = "CampTier",
                        professionID = contribution.skillLineID,
                        professionName = contribution.professionName,
                        tier = tier,
                        feature = contribution.feature,
                        characterName = character.name or characterKey,
                    })
            end
        end
    end
end

function Milestones:GetMilestones()
    local result = {}
    for _, milestone in pairs(getStore() or {}) do result[#result + 1] = milestone end
    table.sort(result, function(a, b)
        if (a.completedAt or 0) == (b.completedAt or 0) then return self:GetDisplayTitle(a) < self:GetDisplayTitle(b) end
        return (a.completedAt or 0) > (b.completedAt or 0)
    end)
    return result
end

function Milestones:Refresh()
    scanProfessions()
    scanLegacy()
    scanCraftingGoals()
    scanCampProgress()

    FC.Suggestions:ClearSource(SOURCE)
    local added = 0
    for _, milestone in ipairs(self:GetMilestones()) do
        if self.sessionNew and self.sessionNew[milestone.id] and added < 2 then
            added = added + 1
            FC.Suggestions:Add({
                id = "milestone_" .. tostring(milestone.id),
                source = SOURCE,
                category = "Milestone",
                priority = 36,
                title = self:GetDisplayTitle(milestone),
                description = self:GetDisplayDescription(milestone),
            })
        end
    end
end

function Milestones:OnInitialize()
    getStore()
    self.sessionNew = {}
end

function Milestones:OnEvent(event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_LEVEL_UP" or event == "SKILL_LINES_CHANGED" or event == "NEW_RECIPE_LEARNED" then
        self:Refresh()
    end
end

FC:RegisterModule("Milestones", Milestones)
