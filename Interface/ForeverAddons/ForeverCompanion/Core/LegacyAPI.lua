local _, FC = ...

local API = FC.API
local originalRefreshCapabilities = API.RefreshCapabilities

local EXPECTED_LEGACY_CATEGORY_COUNTS = { 2, 3, 3, 3, 4, 5, 18, 27 }
local EXPECTED_LEGACY_TOTAL = 65

local function safeValue(value)
    if value == nil then return nil end
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if ok and secret then return nil end
    end
    return value
end

local function safeNumber(value)
    return tonumber(safeValue(value)) or 0
end

local function sortedCopy(values)
    local copy = {}
    for index, value in ipairs(values or {}) do
        copy[index] = value
    end
    table.sort(copy)
    return copy
end

local function sameNumbers(left, right)
    if #left ~= #right then
        return false
    end
    for index = 1, #left do
        if left[index] ~= right[index] then
            return false
        end
    end
    return true
end

local function hasAchievementAPI()
    return type(GetCategoryList) == "function"
        and type(GetCategoryInfo) == "function"
        and type(GetCategoryNumAchievements) == "function"
        and type(GetAchievementInfo) == "function"
        and type(GetAchievementNumCriteria) == "function"
        and type(GetAchievementCriteriaInfo) == "function"
end

function API:RefreshCapabilities()
    originalRefreshCapabilities(self)
    self.capabilities.achievements = hasAchievementAPI()
    self.capabilities.legacy = FC.Client.isForever == true and self.capabilities.achievements
end

local function readCategories()
    local ok, categoryIDs = pcall(GetCategoryList)
    if not ok or type(categoryIDs) ~= "table" then
        return nil, "GetCategoryList failed"
    end

    local categories = {}
    local children = {}

    for _, rawCategoryID in ipairs(categoryIDs) do
        local categoryID = safeValue(rawCategoryID)
        if type(categoryID) == "number" then
            local infoOk, rawTitle, rawParentID = pcall(GetCategoryInfo, categoryID)
            local title = infoOk and safeValue(rawTitle) or nil
            local parentID = infoOk and safeValue(rawParentID) or nil
            if title then
                local totalOk, rawTotal, rawCompleted = pcall(GetCategoryNumAchievements, categoryID, true)
                local total = totalOk and safeNumber(rawTotal) or 0
                local completed = totalOk and safeNumber(rawCompleted) or 0

                categories[categoryID] = {
                    id = categoryID,
                    title = title,
                    parentID = parentID,
                    total = total,
                    completed = completed,
                }

                if type(parentID) == "number" and parentID ~= -1 then
                    children[parentID] = children[parentID] or {}
                    children[parentID][#children[parentID] + 1] = categoryID
                end
            end
        end
    end

    return categories, children
end

local function hasLegacyMarker(title)
    return string.find(string.lower(tostring(title or "")), "legacy", 1, true) ~= nil
end

local function findLegacyTree(categories, children)
    local expected = sortedCopy(EXPECTED_LEGACY_CATEGORY_COUNTS)

    for rootID, childIDs in pairs(children or {}) do
        local counts = {}
        local matchingChildren = {}
        local total = 0

        for _, childID in ipairs(childIDs) do
            local category = categories[childID]
            if category and category.total > 0 then
                counts[#counts + 1] = category.total
                matchingChildren[#matchingChildren + 1] = childID
                total = total + category.total
            end
        end

        if total == EXPECTED_LEGACY_TOTAL and sameNumbers(sortedCopy(counts), expected) then
            table.sort(matchingChildren, function(a, b)
                return tostring(categories[a].title) < tostring(categories[b].title)
            end)
            return rootID, matchingChildren
        end
    end

    -- Conservative fallback for beta builds that flatten Legacy into one
    -- category. A generic 65-achievement category is not enough evidence.
    for categoryID, category in pairs(categories or {}) do
        if category.total == EXPECTED_LEGACY_TOTAL and hasLegacyMarker(category.title) then
            return categoryID, { categoryID }
        end
    end

    return nil, nil
end

local function criterionProgress(completed, quantity, requiredQuantity)
    if completed == true then return 1 end
    local current = tonumber(safeValue(quantity))
    local required = tonumber(safeValue(requiredQuantity))
    if current and required and required > 0 then
        return math.max(0, math.min(1, current / required))
    end
    return 0
end

local function readAchievement(categoryID, index)
    local ok, rawAchievementID, rawName, points, rawCompleted, month, day, year, description, flags, icon = pcall(GetAchievementInfo, categoryID, index)
    local achievementID = ok and safeValue(rawAchievementID) or nil
    local name = ok and safeValue(rawName) or nil
    if type(achievementID) ~= "number" or not name then
        return nil
    end

    local completed = safeValue(rawCompleted) == true
    local criteriaTotal = 0
    local criteriaCompleted = 0
    local criteriaProgress = 0
    local criteria = {}

    local countOk, count = pcall(GetAchievementNumCriteria, achievementID)
    if countOk then
        criteriaTotal = safeNumber(count)
    end

    for criteriaIndex = 1, criteriaTotal do
        local criteriaOk, criteriaString, _, rawCriteriaDone, quantity, requiredQuantity = pcall(GetAchievementCriteriaInfo, achievementID, criteriaIndex, true)
        if criteriaOk then
            local criteriaDone = safeValue(rawCriteriaDone) == true
            if criteriaDone then criteriaCompleted = criteriaCompleted + 1 end
            local partial = criterionProgress(criteriaDone, quantity, requiredQuantity)
            criteriaProgress = criteriaProgress + partial
            criteria[#criteria + 1] = {
                text = safeValue(criteriaString),
                completed = criteriaDone,
                quantity = safeValue(quantity),
                requiredQuantity = safeValue(requiredQuantity),
                progress = partial,
            }
        end
    end

    local progress
    if completed then
        progress = 1
    elseif criteriaTotal > 0 then
        progress = math.max(0, math.min(1, criteriaProgress / criteriaTotal))
    else
        progress = 0
    end

    return {
        id = achievementID,
        name = name,
        points = safeNumber(points),
        completed = completed,
        month = safeValue(month),
        day = safeValue(day),
        year = safeValue(year),
        description = safeValue(description),
        flags = safeValue(flags),
        icon = safeValue(icon),
        criteriaTotal = criteriaTotal,
        criteriaCompleted = criteriaCompleted,
        progress = progress,
        criteria = criteria,
    }
end

function API:GetLegacySnapshot()
    if not self.capabilities or not self.capabilities.legacy then
        return nil, "Achievement APIs are unavailable on this client"
    end

    local categories, childrenOrError = readCategories()
    if not categories then
        return nil, childrenOrError
    end
    local children = childrenOrError

    local rootID, legacyCategoryIDs = findLegacyTree(categories, children)
    if not rootID then
        return nil, "Legacy challenge category tree was not discovered"
    end

    local root = categories[rootID] or { id = rootID, title = "Legacy" }
    local snapshot = {
        rootID = rootID,
        title = root.title or "Legacy",
        total = 0,
        completed = 0,
        remaining = 0,
        categories = {},
        challenges = {},
        scannedAt = time and time() or 0,
    }

    local seenAchievements = {}
    for _, categoryID in ipairs(legacyCategoryIDs) do
        local category = categories[categoryID]
        if category then
            local categorySnapshot = {
                id = categoryID,
                title = category.title,
                total = category.total,
                completed = category.completed,
                challenges = {},
            }

            for index = 1, category.total do
                local challenge = readAchievement(categoryID, index)
                if challenge and not seenAchievements[challenge.id] then
                    seenAchievements[challenge.id] = true
                    categorySnapshot.challenges[#categorySnapshot.challenges + 1] = challenge
                    snapshot.challenges[#snapshot.challenges + 1] = challenge
                end
            end

            snapshot.categories[#snapshot.categories + 1] = categorySnapshot
        end
    end

    snapshot.total = #snapshot.challenges
    if snapshot.total ~= EXPECTED_LEGACY_TOTAL then
        return nil, string.format("Legacy challenge data incomplete: %d/%d readable", snapshot.total, EXPECTED_LEGACY_TOTAL)
    end

    for _, challenge in ipairs(snapshot.challenges) do
        if challenge.completed then
            snapshot.completed = snapshot.completed + 1
        end
    end
    snapshot.remaining = math.max(0, snapshot.total - snapshot.completed)

    table.sort(snapshot.categories, function(a, b)
        return tostring(a.title) < tostring(b.title)
    end)

    table.sort(snapshot.challenges, function(a, b)
        if a.completed ~= b.completed then
            return not a.completed
        end
        if a.progress == b.progress then
            return tostring(a.name) < tostring(b.name)
        end
        return a.progress > b.progress
    end)

    return snapshot
end
