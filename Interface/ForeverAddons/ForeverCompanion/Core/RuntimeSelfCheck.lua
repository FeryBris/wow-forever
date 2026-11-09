local _, FC = ...

local previousGetDiagnosticsText = FC.GetDiagnosticsText

local function countEntries(tbl)
    local count = 0
    for _ in pairs(tbl or {}) do count = count + 1 end
    return count
end

local function addCheck(checks, label, state, detail)
    checks[#checks + 1] = {
        label = tostring(label),
        state = state,
        detail = detail and tostring(detail) or nil,
    }
end

local function checkFunctionTable(tbl, names)
    if type(tbl) ~= "table" then return false, "table unavailable" end
    for _, name in ipairs(names) do
        if type(tbl[name]) ~= "function" then
            return false, "missing " .. tostring(name)
        end
    end
    return true
end

function FC:RunRuntimeSelfCheck()
    local checks = {}

    addCheck(checks, "Core ready", self.ready == true and "PASS" or "FAIL",
        self.ready == true and "PLAYER_LOGIN initialization completed" or "addon is not marked ready")

    local interfaceVersion = tonumber(self.Client and self.Client.interface) or 0
    addCheck(checks, "Client build info", interfaceVersion > 0 and "PASS" or "FAIL",
        string.format("interface=%s build=%s", tostring(interfaceVersion > 0 and interfaceVersion or "unknown"), tostring(self.Client and self.Client.build or "unknown")))

    if self.RETAIL_BUILD then
        addCheck(checks, "Client runtime profile", "PASS",
            "Retail UI test profile active; Forever-only systems are intentionally unavailable")
    else
        addCheck(checks, "Forever client detection", self.Client and self.Client.isForever and "PASS" or "WARN",
            self.Client and self.Client.isForever and "Forever interface range detected" or "client is outside the currently recognized Forever interface range")
    end

    local dbLoaded = type(self.DB) == "table" and type(self.DB.account) == "table" and type(self.DB.settings) == "table"
    addCheck(checks, "SavedVariables structure", dbLoaded and "PASS" or "FAIL",
        dbLoaded and "account/settings tables available" or "database/account/settings table missing")

    local dbVersion = self.DB and tonumber(self.DB.dbVersion)
    local dbSchemaOk = dbVersion == tonumber(self.DB_VERSION) and self.DBMigrationFailed ~= true
    local dbDetail
    if self.DBMigrationFailed then
        dbDetail = tostring(self.DBMigrationError or "database migration failed")
    else
        dbDetail = string.format("loaded=%s expected=%s", tostring(dbVersion or "nil"), tostring(self.DB_VERSION))
    end
    addCheck(checks, "Database schema", dbSchemaOk and "PASS" or "FAIL", dbDetail)

    local localeFunctionsOk = type(self.GetLocale) == "function" and type(self.GetText) == "function"
    local enLoaded = type(self.Locales) == "table" and type(self.Locales.enUS) == "table"
    local deLoaded = type(self.Locales) == "table" and type(self.Locales.deDE) == "table"
    local localeOk = localeFunctionsOk and enLoaded and deLoaded
    addCheck(checks, "Localization service", localeOk and "PASS" or "FAIL",
        localeOk and string.format("active=%s enUS=%d keys deDE=%d keys", tostring(self:GetLocale()), countEntries(self.Locales.enUS), countEntries(self.Locales.deDE))
            or "locale functions or English/German tables missing")

    local registered = type(self.GetRegisteredModules) == "function" and self:GetRegisteredModules() or {}
    addCheck(checks, "Module registry", #registered > 0 and "PASS" or "FAIL",
        string.format("%d module(s) registered", #registered))

    local initialized = 0
    local enabled = 0
    local moduleErrors = {}
    if self.Modules and type(self.Modules.registry) == "table" then
        for _, name in ipairs(registered) do
            local module = self.Modules.registry[name]
            if module and module.initialized then initialized = initialized + 1 end
            if module and module.enabled then enabled = enabled + 1 end
            if module and module.lastError then
                moduleErrors[#moduleErrors + 1] = tostring(name) .. ": " .. tostring(module.lastError)
            end
        end
    end
    addCheck(checks, "Module initialization", #registered > 0 and initialized == #registered and "PASS" or "FAIL",
        string.format("%d/%d initialized • %d enabled", initialized, #registered, enabled))
    addCheck(checks, "Module runtime health", #moduleErrors == 0 and "PASS" or "FAIL",
        #moduleErrors == 0 and "no module errors recorded" or table.concat(moduleErrors, " | "))

    local suggestionOk = type(self.Suggestions) == "table"
        and type(self.Suggestions.GetAll) == "function"
        and type(self.Suggestions.Add) == "function"
    addCheck(checks, "Suggestion engine", suggestionOk and "PASS" or "FAIL",
        suggestionOk and string.format("%d active suggestion(s)", self.Suggestions:Count()) or "engine unavailable")

    local api = rawget(_G, "ForeverCompanionAPI")
    local publicApiOk = type(api) == "table" and tonumber(api.apiVersion) == 1 and api == self.APIv1
    addCheck(checks, "Public API v1", publicApiOk and "PASS" or "FAIL",
        publicApiOk and "global provider API registered" or "ForeverCompanionAPI v1 mismatch/unavailable")

    local uiOk, uiDetail = checkFunctionTable(self.UI, {
        "Toggle",
        "ShowHub",
        "ShowSettings",
        "ShowGlobalSearch",
        "ShowDiagnostics",
    })
    addCheck(checks, "Core UI entry points", uiOk and "PASS" or "FAIL", uiOk and "dashboard/features/settings/search/diagnostics available" or uiDetail)

    local minimapOk = type(self.UI) == "table" and type(self.UI.Minimap) == "table"
    addCheck(checks, "Minimap launcher", minimapOk and "PASS" or "WARN",
        minimapOk and "launcher object loaded" or "launcher object unavailable")

    local capabilities = self.API and self.API.capabilities
    local capabilityCount = 0
    local capabilityEnabled = 0
    for _, value in pairs(capabilities or {}) do
        capabilityCount = capabilityCount + 1
        if value then capabilityEnabled = capabilityEnabled + 1 end
    end
    addCheck(checks, "Capability layer", type(capabilities) == "table" and capabilityCount > 0 and "PASS" or "FAIL",
        string.format("%d/%d capabilities currently available", capabilityEnabled, capabilityCount))

    local character = type(self.GetCurrentCharacter) == "function" and self:GetCurrentCharacter() or nil
    addCheck(checks, "Current character cache", character and "PASS" or "WARN",
        character and tostring(character.key or character.name or "character cached") or "current character has not been scanned yet")

    local loggerOk = type(self.Logger) == "table" and type(self.Logger.session) == "table"
    addCheck(checks, "Session logger", loggerOk and "PASS" or "FAIL",
        loggerOk and string.format("%d session log entr%s", #self.Logger.session, #self.Logger.session == 1 and "y" or "ies") or "logger/session buffer unavailable")

    local summary = { PASS = 0, WARN = 0, FAIL = 0 }
    for _, check in ipairs(checks) do
        summary[check.state] = (summary[check.state] or 0) + 1
    end

    local status = summary.FAIL > 0 and "FAIL" or (summary.WARN > 0 and "WARN" or "PASS")
    return {
        status = status,
        pass = summary.PASS,
        warn = summary.WARN,
        fail = summary.FAIL,
        checks = checks,
    }
end

function FC:GetRuntimeSelfCheckText()
    local report = self:RunRuntimeSelfCheck()
    local lines = {
        string.format("Runtime self-check: %s (%d pass / %d warn / %d fail)", report.status, report.pass, report.warn, report.fail),
    }

    for _, check in ipairs(report.checks) do
        local line = string.format("  [%s] %s", check.state, check.label)
        if check.detail and check.detail ~= "" then line = line .. " — " .. check.detail end
        lines[#lines + 1] = line
    end

    return table.concat(lines, "\n")
end

function FC:GetDiagnosticsText()
    local base = type(previousGetDiagnosticsText) == "function" and previousGetDiagnosticsText(self) or "Forever Companion Diagnostics"
    return base .. "\n\n" .. self:GetRuntimeSelfCheckText()
end
