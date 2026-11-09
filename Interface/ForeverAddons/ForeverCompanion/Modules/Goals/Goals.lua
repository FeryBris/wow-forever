local _, FC = ...

local Goals = {}
FC.Goals = Goals

local SOURCE = "Goals"

local function getStore()
    if not FC.DB or not FC.DB.account then return nil end
    FC.DB.account.goals = FC.DB.account.goals or {}
    return FC.DB.account.goals
end

local function normalizePriority(value)
    value = tonumber(value) or 65
    return math.max(1, math.min(100, math.floor(value)))
end

local function bestProfession(skillLineID)
    local best
    local bestCharacter
    local function consider(character)
        for _, profession in ipairs(character and character.professions or {}) do
            if tonumber(profession.skillLineID) == tonumber(skillLineID) then
                if not best or (tonumber(profession.skill) or 0) > (tonumber(best.skill) or 0) then
                    best = profession
                    bestCharacter = character
                end
            end
        end
    end

    consider(FC:GetCurrentCharacter())
    for _, character in pairs(FC.DB and FC.DB.account and FC.DB.account.characters or {}) do
        consider(character)
    end
    return best, bestCharacter
end

function Goals:GetDisplayTitle(goal)
    if type(goal) ~= "table" then return "" end
    local metadata = goal.metadata or {}
    if metadata.kind == "Profession" and metadata.targetID then
        local profession = bestProfession(metadata.targetID)
        local professionName = FC:GetProfessionDisplayName(profession or metadata.targetID, goal.title)
        local targetSkill = tonumber(metadata.targetSkill) or tonumber(profession and profession.maxSkill) or 0
        return FC:GetText("PROF_GOAL_TITLE", targetSkill, professionName)
    end
    return tostring(goal.title or "")
end

function Goals:GetDisplayDescription(goal)
    if type(goal) ~= "table" then return "" end
    local metadata = goal.metadata or {}
    if metadata.kind == "Profession" and metadata.targetID then
        local profession, owner = bestProfession(metadata.targetID)
        local current = tonumber(profession and profession.skill) or 0
        local targetSkill = tonumber(metadata.targetSkill) or tonumber(profession and profession.maxSkill) or current
        local currentKey = type(FC.GetCharacterKey) == "function" and FC:GetCharacterKey() or nil
        local ownerKey = owner and owner.key or nil
        if owner and ownerKey and currentKey and tostring(ownerKey) ~= tostring(currentKey) then
            return FC:GetText("PROF_GOAL_DESC_CHARACTER", tostring(owner.name or ownerKey), current, targetSkill)
        end
        return FC:GetText("PROF_GOAL_DESC", current, targetSkill)
    end
    return tostring(goal.description or FC:GetText("GOAL_PINNED_PERSONAL_DESC"))
end

function Goals:Create(title, description, category, priority, metadata)
    title = tostring(title or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if title == "" then return false, FC:GetText("GOAL_ERROR_TITLE_REQUIRED") end

    local store = getStore()
    if not store then return false, FC:GetText("FORM_ERROR_DATABASE_NOT_READY") end

    FC.DB.account.nextGoalID = (tonumber(FC.DB.account.nextGoalID) or 0) + 1
    local id = tostring(FC.DB.account.nextGoalID)
    local now = time and time() or 0
    store[id] = {
        id = id,
        title = title,
        description = description and tostring(description) or nil,
        category = category and tostring(category) or "Personal",
        priority = normalizePriority(priority),
        enabled = true,
        completed = false,
        createdAt = now,
        updatedAt = now,
        metadata = type(metadata) == "table" and metadata or {},
    }
    self:Refresh()
    return true, store[id]
end

function Goals:PinReference(kind, targetID, title, description, priority, metadata)
    kind = tostring(kind or "Reference")
    metadata = type(metadata) == "table" and metadata or {}
    metadata.kind = kind
    metadata.targetID = targetID

    for _, goal in pairs(getStore() or {}) do
        if goal.metadata and goal.metadata.kind == kind and tostring(goal.metadata.targetID) == tostring(targetID) then
            goal.enabled = true
            goal.completed = false
            goal.updatedAt = time and time() or 0
            for key, value in pairs(metadata) do goal.metadata[key] = value end
            self:Refresh()
            return true, goal
        end
    end

    return self:Create(title, description, kind, priority, metadata)
end

function Goals:Remove(id)
    local store = getStore()
    id = tostring(id or "")
    if not store or not store[id] then return false end
    store[id] = nil
    self:Refresh()
    return true
end

function Goals:SetCompleted(id, completed)
    local store = getStore()
    id = tostring(id or "")
    local goal = store and store[id]
    if not goal then return false end
    goal.completed = completed == true
    goal.updatedAt = time and time() or 0
    self:Refresh()
    return true
end

function Goals:SetEnabled(id, enabled)
    local store = getStore()
    id = tostring(id or "")
    local goal = store and store[id]
    if not goal then return false end
    goal.enabled = enabled ~= false
    goal.updatedAt = time and time() or 0
    self:Refresh()
    return true
end

function Goals:GetGoals(includeCompleted)
    local result = {}
    for _, goal in pairs(getStore() or {}) do
        if includeCompleted or not goal.completed then result[#result + 1] = goal end
    end
    table.sort(result, function(a, b)
        if a.completed ~= b.completed then return a.completed == false end
        if (a.priority or 0) == (b.priority or 0) then
            return (tonumber(a.createdAt) or 0) < (tonumber(b.createdAt) or 0)
        end
        return (a.priority or 0) > (b.priority or 0)
    end)
    return result
end

function Goals:GetGoal(id)
    local store = getStore()
    return store and store[tostring(id or "")] or nil
end

function Goals:Refresh()
    FC.Suggestions:ClearSource(SOURCE)
    local shown = 0
    for _, goal in ipairs(self:GetGoals(false)) do
        if goal.enabled ~= false and shown < 4 then
            shown = shown + 1
            local metadata = goal.metadata or {}
            local suggestionMetadata = {
                goalID = goal.id,
                goalKind = metadata.kind,
                targetID = metadata.targetID,
            }
            if metadata.kind == "Profession" and metadata.targetID then
                suggestionMetadata.professionID = metadata.targetID
                suggestionMetadata.dedupeKey = "profession-cap:" .. tostring(metadata.targetID)
            end
            FC.Suggestions:Add({
                id = "goal_" .. tostring(goal.id),
                source = SOURCE,
                category = goal.category or "Goal",
                priority = tonumber(goal.priority) or 65,
                title = self:GetDisplayTitle(goal),
                description = self:GetDisplayDescription(goal),
                metadata = suggestionMetadata,
            })
        end
    end
end

function Goals:PrintGoals()
    local goals = self:GetGoals(true)
    if #goals == 0 then
        FC:Print("No personal goals pinned.")
        return
    end
    FC:Print("Personal goals:")
    for _, goal in ipairs(goals) do
        FC:Print(string.format("[%s] #%s P%d %s — %s",
            goal.completed and "done" or (goal.enabled == false and "paused" or "active"),
            tostring(goal.id), tonumber(goal.priority) or 0, self:GetDisplayTitle(goal), self:GetDisplayDescription(goal)))
    end
end

function Goals:OnInitialize()
    getStore()
end

function Goals:OnEnable()
    self:Refresh()
end

function Goals:OnEvent(event)
    if event == "PLAYER_LOGIN" then self:Refresh() end
end

FC:RegisterModule("Goals", Goals)
