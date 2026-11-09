local _, FC = ...

local Groups = {}
FC.Groups = Groups

local SOURCE = "Groups"

local function safeValue(value)
    if value == nil then return nil end
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if ok and secret then return nil end
    end
    return value
end

local function safeBooleanCall(callback, ...)
    if type(callback) ~= "function" then return nil end
    local ok, value = pcall(callback, ...)
    if not ok then return nil end
    value = safeValue(value)
    if value == nil then return nil end
    return value == true
end

local function buildUnits()
    local units = {}
    local inRaid = safeBooleanCall(IsInRaid)
    local inGroup = safeBooleanCall(IsInGroup)

    if inRaid == true and type(GetNumGroupMembers) == "function" then
        local ok, count = pcall(GetNumGroupMembers)
        count = ok and tonumber(safeValue(count)) or 0
        for i = 1, count do units[#units + 1] = "raid" .. i end
    elseif inGroup == true and type(GetNumSubgroupMembers) == "function" then
        units[#units + 1] = "player"
        local ok, count = pcall(GetNumSubgroupMembers)
        count = ok and tonumber(safeValue(count)) or 0
        for i = 1, count do units[#units + 1] = "party" .. i end
    else
        units[1] = "player"
    end
    return units
end

local function readUnit(unit)
    if type(UnitExists) == "function" then
        local exists = safeBooleanCall(UnitExists, unit)
        if exists == false then return nil end
    end

    local name, realm
    if type(UnitName) == "function" then
        local ok, valueName, valueRealm = pcall(UnitName, unit)
        if ok then
            name = safeValue(valueName)
            realm = safeValue(valueRealm)
        end
    end

    local className, classFile
    if type(UnitClass) == "function" then
        local ok, valueName, valueFile = pcall(UnitClass, unit)
        if ok then
            className = safeValue(valueName)
            classFile = safeValue(valueFile)
        end
    end

    local level
    if type(UnitLevel) == "function" then
        local ok, value = pcall(UnitLevel, unit)
        if ok then level = tonumber(safeValue(value)) end
    end

    local context = FC.API.GetMapContextForUnit and FC.API:GetMapContextForUnit(unit) or nil
    local connected = safeBooleanCall(UnitIsConnected, unit)
    local deadOrGhost = safeBooleanCall(UnitIsDeadOrGhost, unit)
    local isPlayer = safeBooleanCall(UnitIsUnit, unit, "player")
    if isPlayer == nil then isPlayer = unit == "player" end

    return {
        unit = unit,
        name = name or unit,
        realm = realm,
        className = className,
        classFile = classFile,
        level = level,
        connected = connected,
        deadOrGhost = deadOrGhost == true,
        mapID = context and context.mapID,
        mapName = context and context.mapName,
        x = context and context.x,
        y = context and context.y,
        isPlayer = isPlayer,
    }
end

local function memberIdentity(member)
    local name = tostring(member and member.name or member and member.unit or "member")
    local realm = tostring(member and member.realm or "")
    if realm ~= "" then return name .. "-" .. realm end
    return name
end

function Groups:GetSnapshot()
    return self.snapshot
end

function Groups:Scan(reason)
    local members = {}
    local maps = {}
    for _, unit in ipairs(buildUnits()) do
        local member = readUnit(unit)
        if member then
            members[#members + 1] = member
            if member.mapID then maps[member.mapID] = (maps[member.mapID] or 0) + 1 end
        end
    end

    local mapCount = 0
    for _ in pairs(maps) do mapCount = mapCount + 1 end
    self.snapshot = {
        members = members,
        mapCount = mapCount,
        grouped = #members > 1,
        playerPreparation = FC:GetCurrentCharacter() and FC:GetCurrentCharacter().preparation or nil,
        scannedAt = time and time() or 0,
        reason = reason or "manual",
    }

    FC.Suggestions:ClearSource(SOURCE)
    if #members > 1 and mapCount > 1 then
        FC.Suggestions:Add({
            id = "group_travel_spread",
            source = SOURCE,
            category = "Group",
            priority = 43,
            title = FC:GetText("SUGG_GROUP_SPREAD_TITLE"),
            description = FC:GetText("SUGG_GROUP_SPREAD_DESC", #members, mapCount),
        })
    end

    for _, member in ipairs(members) do
        if member.connected == false then
            local identity = memberIdentity(member)
            FC.Suggestions:Add({
                id = "group_offline_" .. identity,
                source = SOURCE,
                category = "Group",
                priority = 25,
                title = FC:GetText("SUGG_GROUP_OFFLINE_TITLE", tostring(member.name or identity)),
                description = FC:GetText("SUGG_GROUP_OFFLINE_DESC"),
            })
        end
    end

    FC.Logger:Debug("GROUP", "Group snapshot: members=%d maps=%d", #members, mapCount)
end

function Groups:Refresh(reason)
    self:Scan(reason)
end

function Groups:OnEvent(event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" or event == "ZONE_CHANGED_NEW_AREA" then
        self:Scan(event)
        if FC.UI and FC.UI.RefreshGroupsView then FC.UI:RefreshGroupsView() end
    end
end

FC:RegisterModule("Groups", Groups)
