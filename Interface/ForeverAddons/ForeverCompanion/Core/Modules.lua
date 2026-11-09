local _, FC = ...

local Modules = {
    registry = {},
    order = {},
}
FC.Modules = Modules

function FC:RegisterModule(name, module)
    if type(name) ~= "string" or type(module) ~= "table" then
        error("RegisterModule requires a module name and table")
    end
    if Modules.registry[name] then
        error("Module already registered: " .. name)
    end

    module.name = name
    module.enabled = false
    module.initialized = false
    module.lastError = nil
    Modules.registry[name] = module
    Modules.order[#Modules.order + 1] = name
end

function FC:IsModuleEnabled(name)
    local module = Modules.registry[name]
    return module and module.enabled or false
end

function FC:GetRegisteredModules()
    local result = {}
    for _, name in ipairs(Modules.order) do result[#result + 1] = name end
    return result
end

local function unregisterPrivateEvents(module)
    local frame = module and module.eventFrame
    if frame and type(frame.UnregisterAllEvents) == "function" then
        local ok, err = pcall(frame.UnregisterAllEvents, frame)
        if not ok and FC.Logger then
            FC.Logger:Debug("CORE", "Unable to unregister private module events for %s: %s", tostring(module.name), tostring(err))
        end
    end
end

local function clearModuleSuggestions(name, module)
    FC.Suggestions:ClearSource(name)
    for _, source in ipairs(module and module.suggestionSources or {}) do
        FC.Suggestions:ClearSource(source)
    end
end

local function initializeModule(name, module)
    if module.initialized then return true end
    if type(module.OnInitialize) ~= "function" then
        module.initialized = true
        module.lastError = nil
        return true
    end

    local ok, err = FC:SafeCall(name .. ".OnInitialize", module.OnInitialize, module)
    if ok then
        module.initialized = true
        module.lastError = nil
        return true
    end

    module.initialized = false
    module.enabled = false
    module.lastError = tostring(err)
    return false, err
end

local function enableModule(name, module)
    local ok, err = initializeModule(name, module)
    if not ok then return false, err end

    module.enabled = true
    if type(module.OnEnable) == "function" then
        local enableOk, enableErr = FC:SafeCall(name .. ".OnEnable", module.OnEnable, module)
        if not enableOk then
            module.enabled = false
            module.lastError = tostring(enableErr)
            unregisterPrivateEvents(module)
            return false, enableErr
        end
    end

    module.lastError = nil
    return true
end

function FC:SetModuleEnabled(name, enabled)
    local module = Modules.registry[name]
    if not module then return false, "Unknown module: " .. tostring(name) end

    enabled = enabled ~= false
    self.DB.settings.modules[name] = enabled
    if module.enabled == enabled and (not enabled or module.initialized) then return true end

    if enabled then
        local ok, err = enableModule(name, module)
        if not ok then return false, err end
        if type(module.Refresh) == "function" then
            local refreshOk, refreshErr = self:SafeCall(name .. ".Refresh", module.Refresh, module, "module-enabled")
            if not refreshOk then
                module.lastError = tostring(refreshErr)
                return false, refreshErr
            end
        end
    else
        module.enabled = false
        clearModuleSuggestions(name, module)
        if type(module.OnDisable) == "function" then
            local ok, err = self:SafeCall(name .. ".OnDisable", module.OnDisable, module)
            if not ok then module.lastError = tostring(err) end
        end
        unregisterPrivateEvents(module)
    end

    if self.UI and self.UI.RefreshDashboard then self.UI:RefreshDashboard() end
    return true
end

function FC:InitializeModules()
    for _, name in ipairs(Modules.order) do
        local module = Modules.registry[name]
        local wantsEnabled = true
        if self.DB and self.DB.settings and self.DB.settings.modules then
            wantsEnabled = self.DB.settings.modules[name] ~= false
        end

        local initialized = initializeModule(name, module)
        if initialized and wantsEnabled then
            local ok = enableModule(name, module)
            if not ok then
                FC.Logger:Warn("CORE", "Module %s could not be enabled after initialization", tostring(name))
            end
        elseif not wantsEnabled then
            module.enabled = false
            unregisterPrivateEvents(module)
        end
    end
end

function FC:DispatchModuleEvent(event, ...)
    for _, name in ipairs(Modules.order) do
        local module = Modules.registry[name]
        if module.enabled and type(module.OnEvent) == "function" then
            local ok, err = self:SafeCall(name .. ".OnEvent", module.OnEvent, module, event, ...)
            if not ok then module.lastError = tostring(err) end
        end
    end
end

function FC:RefreshModules(reason)
    for _, name in ipairs(Modules.order) do
        local module = Modules.registry[name]
        if module.enabled and type(module.Refresh) == "function" then
            local ok, err = self:SafeCall(name .. ".Refresh", module.Refresh, module, reason or "manual")
            if not ok then module.lastError = tostring(err) end
        end
    end

    if self.UI and self.UI.RefreshDashboard then
        self.UI:RefreshDashboard()
    end
end
