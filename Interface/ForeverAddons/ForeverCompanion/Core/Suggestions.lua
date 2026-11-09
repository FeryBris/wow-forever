local _, FC = ...

local Suggestions = {
    items = {},
}
FC.Suggestions = Suggestions

local function now()
    return time and time() or 0
end

local function getState()
    if not FC.DB or not FC.DB.account then return nil end
    FC.DB.account.suggestionState = FC.DB.account.suggestionState or {}
    local state = FC.DB.account.suggestionState
    state.snoozed = state.snoozed or {}
    return state
end

local function getSnoozedUntil(id)
    local state = getState()
    if not state then return nil end
    local untilTime = tonumber(state.snoozed[tostring(id)])
    if not untilTime then return nil end
    local current = now()
    if current > 0 and untilTime <= current then
        state.snoozed[tostring(id)] = nil
        return nil
    end
    return untilTime
end

local function copySuggestion(suggestion, snoozedUntil)
    return {
        id = suggestion.id,
        source = suggestion.source,
        category = suggestion.category,
        priority = suggestion.priority,
        title = suggestion.title,
        description = suggestion.description,
        metadata = suggestion.metadata,
        snoozedUntil = snoozedUntil,
    }
end

local function preference(suggestion)
    if suggestion.source == "Goals" then return 30 end
    if suggestion.source == "Milestones" then return 20 end
    return 10
end

local function shouldReplace(existing, candidate)
    if not existing then return true end
    local existingPriority = tonumber(existing.priority) or 0
    local candidatePriority = tonumber(candidate.priority) or 0
    if candidatePriority ~= existingPriority then return candidatePriority > existingPriority end
    return preference(candidate) > preference(existing)
end

function Suggestions:ClearSource(source)
    if not source then return end
    for id, suggestion in pairs(self.items) do
        if suggestion.source == source then self.items[id] = nil end
    end
end

function Suggestions:Add(suggestion)
    if type(suggestion) ~= "table" or not suggestion.id or not suggestion.title then
        return false
    end

    local id = tostring(suggestion.id)
    self.items[id] = {
        id = id,
        source = suggestion.source or "Core",
        category = suggestion.category or "General",
        priority = tonumber(suggestion.priority) or 0,
        title = tostring(suggestion.title),
        description = suggestion.description and tostring(suggestion.description) or nil,
        metadata = type(suggestion.metadata) == "table" and suggestion.metadata or nil,
    }
    return true
end

function Suggestions:IsSnoozed(id)
    return getSnoozedUntil(id) ~= nil
end

function Suggestions:GetSnoozedUntil(id)
    return getSnoozedUntil(id)
end

function Suggestions:Snooze(id, seconds)
    id = tostring(id or "")
    if id == "" or not self.items[id] then return false end
    local state = getState()
    if not state then return false end
    seconds = math.max(60, tonumber(seconds) or 3600)
    local current = now()
    state.snoozed[id] = current > 0 and (current + seconds) or seconds
    return true
end

function Suggestions:Unsnooze(id)
    local state = getState()
    id = tostring(id or "")
    if not state or state.snoozed[id] == nil then return false end
    state.snoozed[id] = nil
    return true
end

function Suggestions:ClearSnoozes()
    local state = getState()
    if not state then return end
    state.snoozed = {}
end

function Suggestions:GetAll(includeSnoozed)
    local grouped = {}
    for _, suggestion in pairs(self.items) do
        local snoozedUntil = getSnoozedUntil(suggestion.id)
        if includeSnoozed or not snoozedUntil then
            local metadata = suggestion.metadata or {}
            local dedupeKey = tostring(metadata.dedupeKey or ("id:" .. tostring(suggestion.id)))
            local candidate = copySuggestion(suggestion, snoozedUntil)
            if shouldReplace(grouped[dedupeKey], candidate) then
                grouped[dedupeKey] = candidate
            end
        end
    end

    local result = {}
    for _, suggestion in pairs(grouped) do result[#result + 1] = suggestion end

    table.sort(result, function(a, b)
        if (a.snoozedUntil ~= nil) ~= (b.snoozedUntil ~= nil) then
            return a.snoozedUntil == nil
        end
        if a.priority == b.priority then return a.title < b.title end
        return a.priority > b.priority
    end)
    return result
end

function Suggestions:GetTop(limit)
    local result = self:GetAll(false)
    limit = tonumber(limit) or #result
    while #result > limit do table.remove(result) end
    return result
end

function Suggestions:Count(includeSnoozed)
    return #self:GetAll(includeSnoozed == true)
end

function Suggestions:CountSnoozed()
    local count = 0
    for _, suggestion in ipairs(self:GetAll(true)) do
        if suggestion.snoozedUntil then count = count + 1 end
    end
    return count
end

function Suggestions:PinAsGoal(id)
    id = tostring(id or "")
    local suggestion = self.items[id]
    if not suggestion then return false, FC:GetText("SUGGESTION_PIN_FAILED") end
    if not FC.Goals or type(FC.Goals.PinReference) ~= "function" then
        return false, FC:GetText("SUGGESTION_PIN_FAILED")
    end

    return FC.Goals:PinReference(
        "Suggestion",
        id,
        suggestion.title,
        suggestion.description or ("Suggested by " .. tostring(suggestion.source)),
        math.max(1, math.min(100, tonumber(suggestion.priority) or 65)),
        {
            suggestionSource = suggestion.source,
            suggestionCategory = suggestion.category,
        }
    )
end
