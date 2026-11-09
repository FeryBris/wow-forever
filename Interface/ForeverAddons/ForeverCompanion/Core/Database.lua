local _, FC = ...

local function ensureTable(parent, key)
    if type(parent[key]) ~= "table" then
        parent[key] = {}
    end
    return parent[key]
end

local function applyDefaults(db)
    db.dbVersion = tonumber(db.dbVersion) or 1

    local account = ensureTable(db, "account")
    ensureTable(account, "characters")
    ensureTable(account, "items")
    ensureTable(account, "recipes")
    ensureTable(account, "recipeSources")
    ensureTable(account, "craftingGoals")
    ensureTable(account, "legacy")
    ensureTable(account, "flightPoints")
    ensureTable(account, "storage")
    ensureTable(account, "goals")
    ensureTable(account, "milestones")
    ensureTable(account, "preparationChecklist")
    ensureTable(account, "travelRoutes")
    local suggestionState = ensureTable(account, "suggestionState")
    ensureTable(suggestionState, "snoozed")
    account.nextGoalID = tonumber(account.nextGoalID) or 0
    account.nextTravelRouteID = tonumber(account.nextTravelRouteID) or 0

    local settings = ensureTable(db, "settings")
    if settings.discoveryMode == nil then settings.discoveryMode = "BALANCED" end
    if settings.showLoginSummary == nil then settings.showLoginSummary = true end
    if settings.minimapButton == nil then settings.minimapButton = true end
    if settings.debug == nil then settings.debug = false end
    if settings.locale == nil then settings.locale = "AUTO" end

    local modules = ensureTable(settings, "modules")
    local defaults = {
        Characters = true,
        Professions = true,
        CraftingGoals = true,
        ProfessionPlanner = true,
        AccountRecipes = true,
        RecipeSources = true,
        Inventory = true,
        Items = true,
        Preparation = true,
        PreparationChecklist = true,
        Legacy = true,
        Camps = true,
        Travel = true,
        TravelRoutes = true,
        Journey = true,
        Goals = true,
        Groups = true,
        Milestones = true,
        LoginSummary = true,
        ExternalProviders = true,
    }
    for name, defaultValue in pairs(defaults) do
        if modules[name] == nil then modules[name] = defaultValue end
    end

    -- These modules intentionally have no normal module toggle. They are
    -- infrastructure rather than optional gameplay features, so an obsolete or
    -- hand-edited SavedVariables value must not leave the UI in an unrecoverable
    -- state. Login-summary visibility is controlled by showLoginSummary instead.
    modules.Characters = true
    modules.LoginSummary = true
    modules.ExternalProviders = true
end

local migrations = {}

migrations[2] = function(db)
    local settings = ensureTable(db, "settings")
    ensureTable(settings, "modules")
    if settings.debug == nil then settings.debug = false end
end

migrations[3] = function(db)
    local settings = ensureTable(db, "settings")
    local modules = ensureTable(settings, "modules")
    if modules.Inventory == nil then modules.Inventory = true end
end

migrations[4] = function(db)
    local account = ensureTable(db, "account")
    ensureTable(account, "craftingGoals")

    local settings = ensureTable(db, "settings")
    local modules = ensureTable(settings, "modules")
    if modules.CraftingGoals == nil then modules.CraftingGoals = true end
end

migrations[5] = function(db)
    local account = ensureTable(db, "account")
    ensureTable(account, "storage")
    ensureTable(account, "goals")
    ensureTable(account, "flightPoints")
    ensureTable(account, "milestones")
    account.nextGoalID = tonumber(account.nextGoalID) or 0

    local settings = ensureTable(db, "settings")
    if settings.locale == nil then settings.locale = "AUTO" end
    local modules = ensureTable(settings, "modules")
    local newModules = {
        "Legacy", "Camps", "Travel", "Journey", "Goals", "Items",
        "Groups", "Milestones", "ProfessionPlanner", "ExternalProviders",
    }
    for _, name in ipairs(newModules) do
        if modules[name] == nil then modules[name] = true end
    end
end

migrations[6] = function(db)
    local account = ensureTable(db, "account")
    ensureTable(account, "preparationChecklist")

    local settings = ensureTable(db, "settings")
    local modules = ensureTable(settings, "modules")
    local newModules = {
        "AccountRecipes", "PreparationChecklist", "LoginSummary",
    }
    for _, name in ipairs(newModules) do
        if modules[name] == nil then modules[name] = true end
    end
end

migrations[7] = function(db)
    local account = ensureTable(db, "account")
    local state = ensureTable(account, "suggestionState")
    ensureTable(state, "snoozed")
end

migrations[8] = function(db)
    local account = ensureTable(db, "account")
    ensureTable(account, "travelRoutes")
    account.nextTravelRouteID = tonumber(account.nextTravelRouteID) or 0

    local settings = ensureTable(db, "settings")
    local modules = ensureTable(settings, "modules")
    if modules.TravelRoutes == nil then modules.TravelRoutes = true end
end

migrations[9] = function(db)
    local account = ensureTable(db, "account")
    ensureTable(account, "recipeSources")

    local settings = ensureTable(db, "settings")
    local modules = ensureTable(settings, "modules")
    if modules.RecipeSources == nil then modules.RecipeSources = true end
end

function FC:InitializeDatabase()
    if type(ForeverCompanionDB) ~= "table" then
        ForeverCompanionDB = { dbVersion = self.DB_VERSION }
    end

    local db = ForeverCompanionDB
    applyDefaults(db)

    self.DBMigrationFailed = false
    self.DBMigrationError = nil

    local currentVersion = tonumber(db.dbVersion) or 1
    while currentVersion < self.DB_VERSION do
        local nextVersion = currentVersion + 1
        local migrate = migrations[nextVersion]
        if migrate then
            local ok, err = pcall(migrate, db)
            if not ok then
                self.DBMigrationFailed = true
                self.DBMigrationError = string.format("Migration to v%d failed: %s", nextVersion, tostring(err))
                self.Logger:Error("DB", "%s", self.DBMigrationError)
                break
            end
        end
        currentVersion = nextVersion
        db.dbVersion = currentVersion
    end

    -- Never claim a schema version that was not actually reached. applyDefaults
    -- still repairs missing tables so diagnostics and recovery UI remain usable.
    db.dbVersion = currentVersion
    applyDefaults(db)
    self.DB = db

    if self.DBMigrationFailed then
        self.Logger:Warn("DB", "Database loaded in recovery mode at version %d (expected %d)", db.dbVersion, self.DB_VERSION)
    else
        self.Logger:Debug("DB", "Database ready at version %d", db.dbVersion)
    end
end
