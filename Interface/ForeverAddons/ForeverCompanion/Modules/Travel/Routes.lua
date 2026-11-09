local _, FC = ...

local Routes = {
    providers = {},
}
FC.TravelRoutes = Routes

local function getStore()
    if not FC.DB or not FC.DB.account then return nil end
    FC.DB.account.travelRoutes = FC.DB.account.travelRoutes or {}
    FC.DB.account.nextTravelRouteID = tonumber(FC.DB.account.nextTravelRouteID) or 0
    return FC.DB.account.travelRoutes
end

local function safeValue(value)
    if value == nil then return nil end
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if ok and secret then return nil end
    end
    return value
end

local function safeText(value)
    value = safeValue(value)
    if value == nil then return nil end
    local kind = type(value)
    if kind ~= "string" and kind ~= "number" and kind ~= "boolean" then return nil end
    return tostring(value)
end

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function copyTable(value, depth)
    depth = depth or 0
    value = safeValue(value)
    if value == nil then return nil end
    if type(value) ~= "table" then
        local kind = type(value)
        if kind == "string" or kind == "number" or kind == "boolean" then return value end
        return nil
    end
    if depth >= 5 then return nil end

    local result = {}
    for key, child in pairs(value) do
        local copiedKey = copyTable(key, depth + 1)
        local copiedChild = copyTable(child, depth + 1)
        if copiedKey ~= nil and copiedChild ~= nil then result[copiedKey] = copiedChild end
    end
    return result
end

function Routes:NotifyChanged(reason)
    self.lastRefresh = time and time() or 0
    if FC.ready and FC.Travel and FC:IsModuleEnabled("Travel") and type(FC.Travel.Refresh) == "function" then
        FC.Travel:Refresh(reason or "route-change")
    end
    if FC.ready and FC.Journey and FC:IsModuleEnabled("Journey") and type(FC.Journey.Refresh) == "function" then
        FC.Journey:Refresh(reason or "route-change")
    end
    if FC.UI and FC.UI.RefreshTravelRoutesView then FC.UI:RefreshTravelRoutesView() end
    if FC.UI and FC.UI.frame and FC.UI.frame:IsShown() and FC.UI.RefreshDashboard then FC.UI:RefreshDashboard() end
end

function Routes:Create(name, origin, destination, notes, routeType)
    name = trim(name)
    origin = trim(origin)
    destination = trim(destination)
    notes = trim(notes)
    routeType = trim(routeType)

    if name == "" then
        if origin ~= "" and destination ~= "" then name = origin .. " → " .. destination end
    end
    if name == "" then return false, FC:GetText("ROUTE_ERROR_ENDPOINT_REQUIRED") end

    local store = getStore()
    if not store then return false, FC:GetText("FORM_ERROR_DATABASE_NOT_READY") end
    FC.DB.account.nextTravelRouteID = FC.DB.account.nextTravelRouteID + 1
    local id = tostring(FC.DB.account.nextTravelRouteID)
    local stamp = time and time() or 0
    store[id] = {
        id = id,
        name = name,
        origin = origin ~= "" and origin or nil,
        destination = destination ~= "" and destination or nil,
        notes = notes ~= "" and notes or nil,
        routeType = routeType ~= "" and routeType or "Custom",
        enabled = true,
        createdAt = stamp,
        updatedAt = stamp,
        source = "User",
    }
    self:NotifyChanged("route-created")
    return true, store[id]
end

function Routes:Remove(id)
    local store = getStore()
    id = tostring(id or "")
    if not store or not store[id] then return false end
    store[id] = nil
    self:NotifyChanged("route-removed")
    return true
end

function Routes:SetEnabled(id, enabled)
    local store = getStore()
    local route = store and store[tostring(id or "")]
    if not route then return false end
    route.enabled = enabled ~= false
    route.updatedAt = time and time() or 0
    self:NotifyChanged("route-enabled-state")
    return true
end

function Routes:GetUserRoutes(includeDisabled)
    local result = {}
    for _, route in pairs(getStore() or {}) do
        if includeDisabled or route.enabled ~= false then result[#result + 1] = copyTable(route) end
    end
    table.sort(result, function(a, b)
        if (a.enabled ~= false) ~= (b.enabled ~= false) then return a.enabled ~= false end
        return tostring(a.name) < tostring(b.name)
    end)
    return result
end

function Routes:RegisterProvider(id, callback)
    id = trim(id)
    if id == "" then return false, "Provider ID is required." end
    if type(callback) ~= "function" then return false, "Route provider must be a function." end
    if self.providers[id] then return false, "Route provider already registered: " .. id end
    self.providers[id] = callback
    self:NotifyChanged("route-provider-registered")
    return true
end

function Routes:UnregisterProvider(id)
    id = tostring(id or "")
    if not self.providers[id] then return false end
    self.providers[id] = nil
    self:NotifyChanged("route-provider-unregistered")
    return true
end

function Routes:BuildContext()
    local travel = FC.Travel and FC.Travel:GetSnapshot() or nil
    return {
        addonVersion = FC.version,
        discoveryMode = FC.DB and FC.DB.settings and FC.DB.settings.discoveryMode or "BALANCED",
        character = copyTable(FC:GetCurrentCharacter()),
        travel = copyTable(travel),
    }
end

function Routes:GetProviderRoutes()
    local result = {}
    local context = self:BuildContext()
    for providerID, callback in pairs(self.providers) do
        local ok, routes = pcall(callback, copyTable(context))
        if ok and type(routes) == "table" then
            for index, route in ipairs(routes) do
                if type(route) == "table" then
                    local name = safeText(route.name)
                    if name and trim(name) ~= "" then
                        local providerRouteID = safeText(route.id) or tostring(index)
                        result[#result + 1] = {
                            id = "provider:" .. providerID .. ":" .. providerRouteID,
                            name = name,
                            origin = safeText(route.origin),
                            destination = safeText(route.destination),
                            notes = safeText(route.notes),
                            routeType = safeText(route.routeType) or "Provider",
                            enabled = true,
                            source = "Provider:" .. providerID,
                            metadata = copyTable(route.metadata),
                        }
                    end
                end
            end
        elseif not ok then
            FC.Logger:Warn("TRAVEL", "Route provider %s failed: %s", tostring(providerID), tostring(routes))
        end
    end
    return result
end

function Routes:GetAllRoutes(includeDisabled)
    local result = self:GetUserRoutes(includeDisabled)
    for _, route in ipairs(self:GetProviderRoutes()) do result[#result + 1] = route end
    table.sort(result, function(a, b)
        if tostring(a.routeType) == tostring(b.routeType) then return tostring(a.name) < tostring(b.name) end
        return tostring(a.routeType) < tostring(b.routeType)
    end)
    return result
end

function Routes:GetProviderCount()
    local count = 0
    for _ in pairs(self.providers) do count = count + 1 end
    return count
end

function Routes:Refresh()
    self.lastRefresh = time and time() or 0
    if FC.UI and FC.UI.RefreshTravelRoutesView then FC.UI:RefreshTravelRoutesView() end
end

function Routes:OnInitialize()
    getStore()
end

function Routes:OnEvent(event)
    if event == "PLAYER_LOGIN" or event == "ZONE_CHANGED_NEW_AREA" then self:Refresh() end
end

FC:RegisterModule("TravelRoutes", Routes)
