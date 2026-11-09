local _, FC = ...

local ExternalProviders = {
    providers = {},
    refreshScheduled = false,
    pendingReason = nil,
}
FC.ExternalProviders = ExternalProviders

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

local function copyValue(value, depth)
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
        local copiedKey = copyValue(key, depth + 1)
        local copiedChild = copyValue(child, depth + 1)
        if copiedKey ~= nil and copiedChild ~= nil then result[copiedKey] = copiedChild end
    end
    return result
end

local PublicAPI = {
    apiVersion = 1,
    addon = "ForeverCompanion",
}

function PublicAPI.GetAddonVersion() return FC.version end
function PublicAPI.GetClientInfo() return copyValue(FC.Client) end
function PublicAPI.GetCapabilities() return copyValue(FC.API and FC.API.capabilities or {}) end

function PublicAPI.GetCurrentCharacter()
    local character = FC:GetCurrentCharacter()
    if not character then return nil end
    return copyValue({
        key = character.key,
        name = character.name,
        realm = character.realm,
        className = character.className,
        classFile = character.classFile,
        level = character.level,
        faction = character.faction,
        professions = character.professions,
        preparation = character.preparation,
    })
end

function PublicAPI.GetDiscoveryMode()
    return FC.DB and FC.DB.settings and FC.DB.settings.discoveryMode or "BALANCED"
end

function PublicAPI.RegisterSuggestionProvider(id, callback)
    if type(id) ~= "string" or id == "" then return false, "Provider ID must be a non-empty string." end
    if type(callback) ~= "function" then return false, "Suggestion provider must be a function." end
    if ExternalProviders.providers[id] then return false, "Provider already registered: " .. id end
    ExternalProviders.providers[id] = callback
    if FC.ready then ExternalProviders:ScheduleRefresh("provider-registered") end
    return true
end

function PublicAPI.UnregisterSuggestionProvider(id)
    id = tostring(id or "")
    if not ExternalProviders.providers[id] then return false end
    ExternalProviders.providers[id] = nil
    FC.Suggestions:ClearSource("Plugin:" .. id)
    return true
end

function PublicAPI.GetTravelRoutes(includeDisabled)
    if not FC.TravelRoutes or type(FC.TravelRoutes.GetAllRoutes) ~= "function" then return {} end
    return copyValue(FC.TravelRoutes:GetAllRoutes(includeDisabled == true)) or {}
end

function PublicAPI.RegisterTravelRouteProvider(id, callback)
    if not FC.TravelRoutes or type(FC.TravelRoutes.RegisterProvider) ~= "function" then
        return false, "Travel route registry is unavailable."
    end
    local ok, result = FC.TravelRoutes:RegisterProvider(id, callback)
    if ok and FC.TravelRoutes.Refresh then FC.TravelRoutes:Refresh("provider-registered") end
    return ok, result
end

function PublicAPI.UnregisterTravelRouteProvider(id)
    if not FC.TravelRoutes or type(FC.TravelRoutes.UnregisterProvider) ~= "function" then return false end
    local ok = FC.TravelRoutes:UnregisterProvider(id)
    if ok and FC.TravelRoutes.Refresh then FC.TravelRoutes:Refresh("provider-unregistered") end
    return ok
end

function PublicAPI.GetRecipeSources(recipeID)
    if not FC.RecipeSources or type(FC.RecipeSources.GetSources) ~= "function" then return {} end
    return copyValue(FC.RecipeSources:GetSources(recipeID)) or {}
end

function PublicAPI.RegisterRecipeSourceProvider(id, callback)
    if not FC.RecipeSources or type(FC.RecipeSources.RegisterProvider) ~= "function" then
        return false, "Recipe source registry is unavailable."
    end
    local ok, result = FC.RecipeSources:RegisterProvider(id, callback)
    if ok and FC.RecipeSources.Refresh then FC.RecipeSources:Refresh("provider-registered") end
    return ok, result
end

function PublicAPI.UnregisterRecipeSourceProvider(id)
    if not FC.RecipeSources or type(FC.RecipeSources.UnregisterProvider) ~= "function" then return false end
    local ok = FC.RecipeSources:UnregisterProvider(id)
    if ok and FC.RecipeSources.Refresh then FC.RecipeSources:Refresh("provider-unregistered") end
    return ok
end

function PublicAPI.Refresh()
    FC:RefreshModules("public-api")
end

function ExternalProviders:BuildContext()
    return {
        apiVersion = PublicAPI.apiVersion,
        addonVersion = FC.version,
        client = copyValue(FC.Client),
        capabilities = copyValue(FC.API and FC.API.capabilities or {}),
        character = PublicAPI.GetCurrentCharacter(),
        discoveryMode = PublicAPI.GetDiscoveryMode(),
    }
end

function ExternalProviders:Refresh(reason)
    local context = self:BuildContext()
    context.reason = reason or "refresh"

    for id, callback in pairs(self.providers) do
        local source = "Plugin:" .. id
        FC.Suggestions:ClearSource(source)
        -- Each provider receives its own defensive copy so one integration can
        -- never mutate the context observed by another provider or by the addon.
        local ok, suggestions = pcall(callback, copyValue(context))
        if ok and type(suggestions) == "table" then
            for index, suggestion in ipairs(suggestions) do
                if type(suggestion) == "table" then
                    local title = safeText(suggestion.title)
                    if title and title ~= "" then
                        local providerSuggestionID = safeText(suggestion.id) or tostring(index)
                        FC.Suggestions:Add({
                            id = source .. ":" .. providerSuggestionID,
                            source = source,
                            category = safeText(suggestion.category) or "Plugin",
                            priority = tonumber(safeValue(suggestion.priority)) or 0,
                            title = title,
                            description = safeText(suggestion.description),
                            metadata = copyValue(suggestion.metadata),
                        })
                    end
                end
            end
        elseif not ok then
            FC.Logger:Warn("CORE", "Suggestion provider %s failed: %s", id, tostring(suggestions))
        end
    end
end

function ExternalProviders:ScheduleRefresh(reason)
    self.pendingReason = reason or self.pendingReason or "refresh"
    if self.refreshScheduled then return end
    self.refreshScheduled = true

    local function execute()
        self.refreshScheduled = false
        local pending = self.pendingReason or "refresh"
        self.pendingReason = nil
        if not FC.IsModuleEnabled or FC:IsModuleEnabled("ExternalProviders") then
            self:Refresh(pending)
        end
    end

    if C_Timer and type(C_Timer.After) == "function" then
        -- Run after the current event dispatch so Characters/Inventory/Travel/etc.
        -- have already updated the shared context this provider will observe.
        C_Timer.After(0, execute)
    else
        execute()
    end
end

function ExternalProviders:ClearProviderSuggestions()
    for id in pairs(self.providers) do
        FC.Suggestions:ClearSource("Plugin:" .. tostring(id))
    end
end

function ExternalProviders:OnEnable()
    self:ScheduleRefresh("enable")
end

function ExternalProviders:OnDisable()
    self.refreshScheduled = false
    self.pendingReason = nil
    self:ClearProviderSuggestions()
end

function ExternalProviders:OnEvent(event)
    if event == "PLAYER_LOGIN"
        or event == "PLAYER_ENTERING_WORLD"
        or event == "PLAYER_LEVEL_UP"
        or event == "SKILL_LINES_CHANGED"
        or event == "BAG_UPDATE_DELAYED"
        or event == "ZONE_CHANGED_NEW_AREA"
        or event == "QUEST_LOG_UPDATE"
    then
        self:ScheduleRefresh(event)
    end
end

FC:RegisterModule("ExternalProviders", ExternalProviders)

FC.APIv1 = PublicAPI
_G.ForeverCompanionAPI = PublicAPI
