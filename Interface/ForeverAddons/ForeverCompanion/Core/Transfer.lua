local _, FC = ...

local Transfer = {}
FC.Transfer = Transfer

local FORMAT = "FCPLAN2"
local LEGACY_FORMAT = "FCPLAN1"

local function encode(value)
    value = tostring(value or "")
    value = value:gsub("%%", "%%25")
    value = value:gsub("|", "%%7C")
    value = value:gsub("\r", "%%0D")
    value = value:gsub("\n", "%%0A")
    return value
end

local function decode(value)
    value = tostring(value or "")
    value = value:gsub("%%0A", "\n")
    value = value:gsub("%%0D", "\r")
    value = value:gsub("%%7[Cc]", "|")
    value = value:gsub("%%25", "%%")
    return value
end

local function bool(value)
    return value == true and "1" or "0"
end

local function split(line)
    local fields = {}
    local start = 1
    while true do
        local pos = string.find(line, "|", start, true)
        if not pos then
            fields[#fields + 1] = string.sub(line, start)
            break
        end
        fields[#fields + 1] = string.sub(line, start, pos - 1)
        start = pos + 1
    end
    return fields
end

local function decodeOptional(value)
    local result = decode(value)
    if result == "" then return nil end
    return result
end

local function normalizeTargetID(value)
    value = decodeOptional(value)
    if value == nil then return nil end
    return tonumber(value) or value
end

local function sameText(left, right)
    return tostring(left or "") == tostring(right or "")
end

local function findChecklistItem(defaultKey, label)
    if not FC.PreparationChecklist or type(FC.PreparationChecklist.GetItems) ~= "function" then return nil end
    for _, item in ipairs(FC.PreparationChecklist:GetItems()) do
        if defaultKey and defaultKey ~= "" and tostring(item.defaultKey or "") == tostring(defaultKey) then
            return item
        end
        if label and label ~= "" then
            local display = type(FC.PreparationChecklist.GetDisplayLabel) == "function"
                and FC.PreparationChecklist:GetDisplayLabel(item) or tostring(item.label or "")
            if tostring(item.label or "") == label or tostring(display or "") == label then
                return item
            end
        end
    end
    return nil
end

local function findPersonalGoal(title, description, category)
    if not FC.Goals or type(FC.Goals.GetGoals) ~= "function" then return nil end
    for _, goal in ipairs(FC.Goals:GetGoals(true)) do
        local metadata = type(goal.metadata) == "table" and goal.metadata or {}
        if metadata.kind == nil and metadata.targetID == nil
            and sameText(goal.title, title)
            and sameText(goal.description, description)
            and sameText(goal.category or "Personal", category or "Personal")
        then
            return goal
        end
    end
    return nil
end

local function findUserRoute(name, origin, destination, notes, routeType)
    if not FC.TravelRoutes or type(FC.TravelRoutes.GetUserRoutes) ~= "function" then return nil end
    local effectiveName = name
    if (effectiveName == nil or effectiveName == "") and origin ~= "" and destination ~= "" then
        effectiveName = origin .. " → " .. destination
    end
    for _, route in ipairs(FC.TravelRoutes:GetUserRoutes(true)) do
        if sameText(route.name, effectiveName)
            and sameText(route.origin, origin)
            and sameText(route.destination, destination)
            and sameText(route.notes, notes)
            and sameText(route.routeType or "Custom", routeType ~= "" and routeType or "Custom")
        then
            return route
        end
    end
    return nil
end

function Transfer:ExportPlanningData()
    local lines = { FORMAT }
    local settings = FC.DB and FC.DB.settings or {}
    lines[#lines + 1] = table.concat({
        "S",
        encode(settings.discoveryMode or "BALANCED"),
        encode(settings.locale or "AUTO"),
        bool(settings.showLoginSummary ~= false),
    }, "|")

    if FC.Goals and type(FC.Goals.GetGoals) == "function" then
        for _, goal in ipairs(FC.Goals:GetGoals(true)) do
            local metadata = type(goal.metadata) == "table" and goal.metadata or {}
            lines[#lines + 1] = table.concat({
                "G",
                tostring(tonumber(goal.priority) or 65),
                bool(goal.enabled ~= false),
                bool(goal.completed == true),
                encode(goal.category or "Personal"),
                encode(goal.title),
                encode(goal.description),
                encode(metadata.kind),
                encode(metadata.targetID),
                encode(metadata.targetSkill),
            }, "|")
        end
    end

    if FC.PreparationChecklist and type(FC.PreparationChecklist.GetItems) == "function" then
        for _, item in ipairs(FC.PreparationChecklist:GetItems()) do
            lines[#lines + 1] = table.concat({
                "C",
                bool(item.completed == true),
                encode(item.label),
                encode(item.defaultKey),
                bool(item.seeded == true),
            }, "|")
        end
    end

    if FC.CraftingGoals and type(FC.CraftingGoals.GetGoals) == "function" then
        for _, goal in ipairs(FC.CraftingGoals:GetGoals()) do
            lines[#lines + 1] = table.concat({
                "K",
                tostring(goal.recipeID or ""),
                tostring(tonumber(goal.quantity) or 1),
                encode(goal.name),
                encode(goal.professionID),
                encode(goal.professionName),
            }, "|")
        end
    end

    if FC.TravelRoutes and type(FC.TravelRoutes.GetUserRoutes) == "function" then
        for _, route in ipairs(FC.TravelRoutes:GetUserRoutes(true)) do
            lines[#lines + 1] = table.concat({
                "R",
                bool(route.enabled ~= false),
                encode(route.routeType or "Custom"),
                encode(route.origin),
                encode(route.destination),
                encode(route.notes),
                encode(route.name),
            }, "|")
        end
    end

    for recipeID, source in pairs(FC.DB and FC.DB.account and FC.DB.account.recipeSources or {}) do
        if type(source) == "table" and tostring(source.source or "User") == "User" then
            lines[#lines + 1] = table.concat({
                "P",
                tostring(tonumber(recipeID) or tonumber(source.recipeID) or ""),
                encode(source.sourceType or "Other"),
                encode(source.sourceName),
                encode(source.location),
                encode(source.notes),
            }, "|")
        end
    end

    return table.concat(lines, "\n")
end

function Transfer:ImportPlanningData(text)
    text = tostring(text or "")
    local lines = {}
    for line in text:gmatch("[^\r\n]+") do lines[#lines + 1] = line end

    local format = lines[1]
    if format ~= FORMAT and format ~= LEGACY_FORMAT then
        return false, FC:GetText("TRANSFER_UNSUPPORTED_HEADER")
    end
    local isV2 = format == FORMAT

    local stats = { settings = 0, goals = 0, checklist = 0, crafting = 0, routes = 0, recipeSources = 0, skipped = 0 }

    for index = 2, #lines do
        local fields = split(lines[index])
        local kind = fields[1]

        if kind == "S" then
            local mode = decode(fields[2])
            if mode == "EXPLORER" or mode == "BALANCED" or mode == "GUIDE" then FC.DB.settings.discoveryMode = mode end
            local locale = decode(fields[3])
            if locale == "AUTO" or (FC.Locales and FC.Locales[locale]) then FC.DB.settings.locale = locale end
            FC.DB.settings.showLoginSummary = fields[4] ~= "0"
            stats.settings = stats.settings + 1
        elseif kind == "G" and FC.Goals then
            local title = decode(fields[6])
            local description = decodeOptional(fields[7])
            local category = decode(fields[5])
            local priority = tonumber(fields[2]) or 65
            local metadata = {}
            local goalKind, targetID
            if isV2 then
                goalKind = decodeOptional(fields[8])
                targetID = normalizeTargetID(fields[9])
                local targetSkill = tonumber(decodeOptional(fields[10]))
                if goalKind then metadata.kind = goalKind end
                if targetID ~= nil then metadata.targetID = targetID end
                if targetSkill then metadata.targetSkill = targetSkill end
            end

            local ok, goal
            if goalKind and targetID ~= nil and type(FC.Goals.PinReference) == "function" then
                ok, goal = FC.Goals:PinReference(goalKind, targetID, title, description, priority, metadata)
            else
                goal = findPersonalGoal(title, description, category)
                if goal then
                    ok = true
                    goal.priority = math.max(1, math.min(100, math.floor(priority)))
                    goal.updatedAt = time and time() or 0
                else
                    ok, goal = FC.Goals:Create(title, description, category, priority, metadata)
                end
            end
            if ok and goal then
                FC.Goals:SetEnabled(goal.id, fields[3] ~= "0")
                FC.Goals:SetCompleted(goal.id, fields[4] == "1")
                stats.goals = stats.goals + 1
            else
                stats.skipped = stats.skipped + 1
            end
        elseif kind == "C" and FC.PreparationChecklist then
            local label = decode(fields[3])
            local defaultKey = isV2 and decodeOptional(fields[4]) or nil
            local seeded = isV2 and fields[5] == "1" or defaultKey ~= nil
            local item = findChecklistItem(defaultKey, label)
            local ok = item ~= nil
            if not item then
                ok, item = FC.PreparationChecklist:Add(label, seeded, defaultKey)
            end
            if ok and item then
                FC.PreparationChecklist:SetCompleted(item.id, fields[2] == "1")
                stats.checklist = stats.checklist + 1
            else
                stats.skipped = stats.skipped + 1
            end
        elseif kind == "K" and FC.CraftingGoals then
            local fallback = isV2 and {
                name = decodeOptional(fields[4]),
                professionID = normalizeTargetID(fields[5]),
                professionName = decodeOptional(fields[6]),
            } or nil
            local importMethod = type(FC.CraftingGoals.ImportGoal) == "function" and FC.CraftingGoals.ImportGoal or FC.CraftingGoals.AddGoal
            local ok = importMethod(FC.CraftingGoals, tonumber(fields[2]), tonumber(fields[3]) or 1, fallback)
            if ok then stats.crafting = stats.crafting + 1 else stats.skipped = stats.skipped + 1 end
        elseif kind == "R" and FC.TravelRoutes then
            local routeName = isV2 and decodeOptional(fields[7]) or nil
            local origin = decode(fields[4])
            local destination = decode(fields[5])
            local notes = decode(fields[6])
            local routeType = decode(fields[3])
            local route = findUserRoute(routeName, origin, destination, notes, routeType)
            local ok = route ~= nil
            if not route then
                ok, route = FC.TravelRoutes:Create(routeName, origin, destination, notes, routeType)
            end
            if ok and route then
                FC.TravelRoutes:SetEnabled(route.id, fields[2] ~= "0")
                stats.routes = stats.routes + 1
            else
                stats.skipped = stats.skipped + 1
            end
        elseif kind == "P" and FC.RecipeSources then
            local recipeID = tonumber(fields[2])
            local ok = recipeID and FC.RecipeSources:SetUserNote(recipeID, decode(fields[3]), decode(fields[4]), decode(fields[5]), decode(fields[6]))
            if ok then stats.recipeSources = stats.recipeSources + 1 else stats.skipped = stats.skipped + 1 end
        else
            stats.skipped = stats.skipped + 1
        end
    end

    if FC.Locale and FC.Locale.Refresh then FC.Locale:Refresh() end
    FC:RefreshModules("planning-import")
    return true, stats
end
