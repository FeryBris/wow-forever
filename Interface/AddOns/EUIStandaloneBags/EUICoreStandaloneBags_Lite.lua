if _G.__EUISTANDALONE_BAGS_INERT then return end
-- ===== AUTO-INJECTED standalone conflict guard (do not edit; build-generated) =====
do
    local CA = C_AddOns
    if CA and CA.GetAddOnEnableState then
        local reason
        -- Suite present? (split literal so no rename can ever rewrite it)
        if CA.GetAddOnEnableState("Ellesmere".."UI") > 0 then
            reason = "suite"
        else
            -- Another enabled EUIStandalone* that isn't me?
            local n = CA.GetNumAddOns and CA.GetNumAddOns() or 0
            for i = 1, n do
                local name = CA.GetAddOnInfo(i)
                if name and name:find("^EUIStandalone") and name ~= "EUIStandaloneBags"
                   and CA.GetAddOnEnableState(i) > 0 then
                    reason = "multi"; break
                end
            end
        end
        if reason then
            _G.__EUISTANDALONE_BAGS_INERT = true
            StaticPopupDialogs["EUISTANDALONE_CONFLICT_Bags"] = {
                text = (reason == "suite")
                    and "Bags is already installed via EllesmereUI. Please use the version from the full suite, or uninstall the EllesmereUI Suite to only use the standalone version."
                    or  "Bags has been auto-disabled, as multiple EUI Standalones cannot coexist. If you wish to have more than one standalone EllesmereUI addon, please install the full EllesmereUI suite -- all of its addons are modular, so you can choose to only enable the ones you want!",
                button1 = OKAY, timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
            }
            local pf = CreateFrame("Frame")
            pf:RegisterEvent("PLAYER_LOGIN")
            pf:SetScript("OnEvent", function() StaticPopup_Show("EUISTANDALONE_CONFLICT_Bags") end)
            return
        end
    end
end
-- ===== end guard =====
if EUI_CLIENT_BLOCKED then return end -- pre-12.1 client failsafe (EUICoreStandaloneBags_ClientGate.lua)
--------------------------------------------------------------------------------
--  EUICoreStandaloneBags_Lite.lua
--  Lightweight replacement for AceAddon-3.0, AceEvent-3.0, and AceDB-3.0
--  Zero-overhead event dispatch (direct frame handlers, no CallbackHandler)
--  Reads existing AceDB SavedVariables format -- no migration needed
--------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

local EUILite = {}
EUICoreStandaloneBags = EUICoreStandaloneBags or {}
EUICoreStandaloneBags.Lite = EUILite

-- WoW Forever (game type "camelot"): the 12.1 engine reporting a 1.60+ toc.
-- Stamped by EUICoreStandaloneBags_ClientGate.lua before any other file runs. Content
-- that vanilla lacks gates on this, never on WOW_PROJECT_ID (the gate reads
-- the toc number, the one signal every Forever build reports the same way).
EUICoreStandaloneBags.IS_FOREVER = (EUI_CLIENT_FOREVER == true)
-- Global cooldown reference spell: Forever reports nothing on 61304 and uses
-- Classic's 29515.
EUICoreStandaloneBags.GCD_SPELL = EUICoreStandaloneBags.IS_FOREVER and 29515 or 61304

-- The options-panel scale moves in 5% steps from 75% to 200% (the Window Scale
-- slider in the panel header). Every seeder rounds onto those steps, so the
-- slider always reads exactly what the panel renders at.
--
-- Lives here (first file in the TOC) so the Startup seed, the migration and the panel
-- itself share ONE range -- copies of these literals is how they drift apart.
EUICoreStandaloneBags.PANEL_SCALE_MIN, EUICoreStandaloneBags.PANEL_SCALE_MAX = 0.75, 2.00

-- Nearest 5% step to v, inside the range. Ties round up (harmless: the panel reads
-- large rather than small, which is the direction this whole seed exists to fix).
function EUICoreStandaloneBags.SnapPanelScale(v)
    if type(v) ~= "number" or v ~= v then return 1.00 end
    v = math.floor(v * 20 + 0.5) / 20
    return math.max(EUICoreStandaloneBags.PANEL_SCALE_MIN, math.min(EUICoreStandaloneBags.PANEL_SCALE_MAX, v))
end

-- Lua APIs
local pairs, type, next, rawset, rawget, setmetatable, wipe =
      pairs, type, next, rawset, rawget, setmetatable, wipe
local tinsert, tremove = table.insert, table.remove
local xpcall, geterrorhandler = xpcall, geterrorhandler

local function errorhandler(err) return geterrorhandler()(err) end
local function safecall(func, ...)
    if type(func) == "function" then return xpcall(func, errorhandler, ...) end
end

--------------------------------------------------------------------------------
--  Addon Registry + Lifecycle
--------------------------------------------------------------------------------
local addons = {}          -- name -> addon table
local initQueue = {}       -- addons waiting for OnInitialize
local enableQueue = {}     -- addons waiting for OnEnable
local statuses = {}        -- name -> true if enabled

-- Per-addon event frame. Defined ABOVE NewAddon because NewAddon creates it EAGERLY,
-- and that timing is load-bearing for CPU attribution: the engine bills an event
-- handler's entire call tree to the addon whose execution context called CreateFrame
-- for the frame (probe-verified 2026-07-26; see EUICoreStandaloneBags_Ticker.lua). NewAddon runs
-- in the child's MAIN CHUNK, so the frame is stamped to the child and its event work
-- bills that addon. The old lazy creation happened at first RegisterEvent -- usually
-- inside OnInitialize/OnEnable, which run under the parent's lifecycle dispatch -- so
-- every mixin event frame in the suite was parent-stamped and the whole suite's event
-- handling was billed to the parent addon.
local function GetOrCreateEventFrame(addon)
    if addon._eventFrame then return addon._eventFrame end
    local f = CreateFrame("Frame")
    f._handlers = {}
    f:SetScript("OnEvent", function(self, event, ...)
        local handler = self._handlers[event]
        if handler then
            handler(addon, event, ...)
        end
    end)
    addon._eventFrame = f
    return f
end

--- Create a new addon object. Replaces AceAddon:NewAddon().
-- Returns a table with :RegisterEvent / :UnregisterEvent mixed in.
function EUILite.NewAddon(name)
    if addons[name] then
        return addons[name]
    end
    local addon = { name = name, enabledState = true }
    addons[name] = addon
    tinsert(initQueue, addon)

    -- Eager, on purpose -- see the attribution note on GetOrCreateEventFrame.
    GetOrCreateEventFrame(addon)

    -- Mix in event methods
    addon.RegisterEvent   = EUILite._RegisterEvent
    addon.UnregisterEvent = EUILite._UnregisterEvent

    return addon
end

--- Retrieve an addon by name (for cross-addon access).
-- Replaces LibStub("AceAddon-3.0"):GetAddon(name).
function EUILite.GetAddon(name, silent)
    if not addons[name] and not silent then
        error("EUILite.GetAddon: addon '" .. name .. "' not found.", 2)
    end
    return addons[name]
end

--------------------------------------------------------------------------------
--  Event System (direct frame handlers, no CallbackHandler overhead)
--------------------------------------------------------------------------------
-- Each addon gets its own hidden frame for events. When RegisterEvent is
-- called with a function callback, we store it and route through a single
-- OnEvent script. No securecallfunction dispatch loop, no registry tables.
--------------------------------------------------------------------------------

-- (GetOrCreateEventFrame lives above NewAddon -- creation is eager at
-- NewAddon time for CPU-attribution reasons documented there.)

--- Register for a Blizzard event. Compatible with AceEvent calling conventions:
--   addon:RegisterEvent("EVENT_NAME", function(self, event, ...) end)
--   addon:RegisterEvent("EVENT_NAME", "MethodName")
--   addon:RegisterEvent("EVENT_NAME")  -- calls self:EVENT_NAME(event, ...)
function EUILite._RegisterEvent(self, eventname, callback)
    local f = GetOrCreateEventFrame(self)
    local handler
    if type(callback) == "function" then
        -- Stored directly. The dispatcher calls handler(addon, event, ...),
        -- which is already the callback's own signature, so wrapping it only
        -- added a second function call to every event the suite receives --
        -- and put an anonymous frame between the callback and any traceback.
        -- The string and no-callback forms below still need a closure, because
        -- they resolve the method on the addon at dispatch time.
        handler = callback
    elseif type(callback) == "string" then
        handler = function(addon, event, ...)
            if addon[callback] then addon[callback](addon, event, ...) end
        end
    else
        -- No callback: look for self:EVENT_NAME
        handler = function(addon, event, ...)
            if addon[eventname] then addon[eventname](addon, event, ...) end
        end
    end
    f._handlers[eventname] = handler
    f:RegisterEvent(eventname)
end

--- Unregister a Blizzard event.
function EUILite._UnregisterEvent(self, eventname)
    local f = self._eventFrame
    if not f then return end
    f._handlers[eventname] = nil
    f:UnregisterEvent(eventname)
end

--------------------------------------------------------------------------------
--  Database (reads existing AceDB format, zero-dependency)
--------------------------------------------------------------------------------
-- AceDB stores data as:
--   GlobalSVName = {
--       profileKeys = { ["CharName - RealmName"] = "Default" },
--       profiles = { Default = { ... } }
--   }
-- We read from that same structure so existing settings carry over.
--------------------------------------------------------------------------------

local function DeepMergeDefaults(dest, src)
    -- Merge src into dest, only filling in keys that don't exist yet
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dest[k]) ~= "table" then
                dest[k] = {}
            end
            DeepMergeDefaults(dest[k], v)
        else
            if dest[k] == nil then
                dest[k] = v
            end
        end
    end
end

-- Expose for use by the profile system when applying old snapshots
EUILite.DeepMergeDefaults = DeepMergeDefaults

local function StripDefaults(db, defaults)
    -- Remove values that match defaults (for clean SavedVariables on logout)
    for k, v in pairs(defaults) do
        if type(v) == "table" and type(db[k]) == "table" then
            StripDefaults(db[k], v)
            -- Keep empty array entries; DeepMergeDefaults fills them on login.
            if not next(db[k]) and type(k) ~= "number" then
                db[k] = nil
            end
        elseif db[k] == v then
            db[k] = nil
        end
    end
end

local function DeepCopy(src)
    if type(src) ~= "table" then return src end
    return CopyTable(src)
end

EUILite.DeepCopy = DeepCopy

local dbRegistry = {}  -- all db objects, for logout cleanup

-- Expose so the profile system can update db.profile in-place after injection
EUILite._dbRegistry = dbRegistry

-- Pre-SavedVariables db tracking. A NewDB call at FILE SCOPE in the addon that OWNS the
-- central store runs before WoW loads that addon's SavedVariables: it builds its
-- profile inside a fresh table, and the real saved table then replaces the global right
-- after, orphaning the db -- session writes go to the orphan and are never serialized
-- (settings silently stop saving). In the suite this can't happen (children's files
-- execute long after the parent's SVs loaded), but in a STANDALONE build everything is
-- one addon, so a file-scope NewDB (Bags) hit exactly this. Any db created before the
-- owning addon's ADDON_LOADED is recorded here and re-rooted in place against the real
-- loaded store at that moment. STANDALONE-GATED: the suite has no pre-SV NewDB callers
-- (children init after the parent's SVs load), so the queue is provably empty there;
-- the gate makes that a hard guarantee instead of a convention. The folder-name test is
-- rename-immune (the standalone build never renames "Standalone").
local IS_STANDALONE = type(ADDON_NAME) == "string" and ADDON_NAME:find("Standalone") ~= nil
local _svLoaded = false   -- true once ADDON_NAME's SavedVariables are live
local _preSVDBs = {}      -- dbs created before that, awaiting re-root
--- True once db.profile can be trusted to be the real saved table.
--
-- A pre-SavedVariables db is built inside an orphan table and re-rooted in
-- place at ADDON_LOADED (see _preSVDBs above), which silently invalidates
-- anything a consumer CACHED from it. A cache that is only READ shows stale
-- values; one written BACK to the profile destroys real saved data -- Bags'
-- category list did exactly that. Consumers test this before trusting, or
-- persisting, anything derived from db.profile.
--
-- Always true in the suite, where no db is ever created pre-SavedVariables.
function EUILite.IsDBReady()
    return (not IS_STANDALONE) or _svLoaded
end

--- Create or open a database backed by the central EUICoreStandaloneBagsDB store.
-- Returns a db object with .profile pointing to the active profile table
-- inside EUICoreStandaloneBagsDB.profiles[name].addons[folder].
-- @param svName  Global SavedVariables name (string), e.g. "EUICoreStandaloneBagsActionBarsDB"
-- @param defaults  Table with a .profile sub-table of default values
-- @param defaultToCharKey  (ignored, kept for call-site compat)
function EUILite.NewDB(svName, defaults, defaultToCharKey)
    -- Derive the addon folder name from the SV name (strip trailing "DB")
    local folder = svName:match("^(.+)DB$") or svName

    -- Resolve the active profile name from the central DB
    local profileName = "Default"
    if EUICoreStandaloneBagsDB and EUICoreStandaloneBagsDB.activeProfile then
        profileName = EUICoreStandaloneBagsDB.activeProfile
    end

    -- Ensure the profile and addons tables exist in the central DB
    if not EUICoreStandaloneBagsDB then EUICoreStandaloneBagsDB = {} end
    if not EUICoreStandaloneBagsDB.profiles then EUICoreStandaloneBagsDB.profiles = {} end
    if type(EUICoreStandaloneBagsDB.profiles[profileName]) ~= "table" then
        EUICoreStandaloneBagsDB.profiles[profileName] = {}
    end
    local profileData = EUICoreStandaloneBagsDB.profiles[profileName]
    if not profileData.addons then profileData.addons = {} end
    if type(profileData.addons[folder]) ~= "table" then
        profileData.addons[folder] = {}
    end
    local profile = profileData.addons[folder]

    -- Child SV globals are vestigial (all data lives in EUICoreStandaloneBagsDB).
    -- Wipe in-place (not replace) so WoW's SV serializer, which holds
    -- the original table reference from load time, saves the empty table.
    if _G[svName] and type(_G[svName]) == "table" then
        wipe(_G[svName])
    else
        _G[svName] = {}
    end

    -- Merge defaults into profile (fills missing keys only)
    local profileDefaults = defaults and defaults.profile
    if profileDefaults then
        DeepMergeDefaults(profile, profileDefaults)
        -- Validate: if any top-level default sub-table is missing or wrong
        -- type after merge, the profile is corrupt. Wipe and re-merge.
        local corrupt = false
        for k, v in pairs(profileDefaults) do
            if type(v) == "table" and type(profile[k]) ~= "table" then
                corrupt = true
                break
            end
        end
        if corrupt then
            wipe(profile)
            DeepMergeDefaults(profile, profileDefaults)
            -- One-time warning per session
            if not EUILite._corruptionWarned then
                EUILite._corruptionWarned = true
                C_Timer.After(5, function()
                    EUICoreStandaloneBags.Print("|cffff6600EUICoreStandaloneBags:|r Profile data for " .. folder .. " was corrupted and has been repaired. Your settings may have been reset to defaults.")
                end)
            end
        end
    end

    -- Build the db object
    local db = {
        sv = EUICoreStandaloneBagsDB,
        svName = svName,
        folder = folder,
        profile = profile,
        _profileName = profileName,
        _defaults = defaults,
        _profileDefaults = profileDefaults,
    }

    --- Reset the current profile to defaults.
    function db:ResetProfile()
        wipe(self.profile)
        if self._profileDefaults then
            DeepMergeDefaults(self.profile, self._profileDefaults)
        end
    end

    -- Register for logout cleanup
    tinsert(dbRegistry, db)

    -- Created before the owning addon's SavedVariables loaded: the real
    -- saved table will replace EUICoreStandaloneBagsDB momentarily, so queue this db
    -- for the in-place re-root at ADDON_LOADED (see _preSVDBs above).
    if IS_STANDALONE and not _svLoaded then
        tinsert(_preSVDBs, db)
    end

    return db
end

--------------------------------------------------------------------------------
--  Logout handler: strip defaults so SavedVariables stay clean
--  Fires pre-logout callbacks first so systems like Profiles can snapshot
--  the full profile data before defaults are stripped.
--------------------------------------------------------------------------------
local preLogoutCallbacks = {}

--- Register a function to run before StripDefaults on logout.
--- Used by the profile system to save a complete snapshot.
function EUILite.RegisterPreLogout(fn)
    tinsert(preLogoutCallbacks, fn)
end

local logoutFrame = CreateFrame("Frame")
logoutFrame:RegisterEvent("PLAYER_LOGOUT")
logoutFrame:SetScript("OnEvent", function()
    -- Fire pre-logout callbacks while data is still intact
    for _, fn in ipairs(preLogoutCallbacks) do
        safecall(fn)
    end

    -- Strip defaults from a COPY of each profile table, then write the stripped copy
    -- back into the central store. This keeps the live db.profile references untouched
    -- (important if any pre-logout callback still reads from them after this point).
    local activeProfile = EUICoreStandaloneBagsDB and EUICoreStandaloneBagsDB.activeProfile or "Default"
    local profileData = EUICoreStandaloneBagsDB and EUICoreStandaloneBagsDB.profiles and EUICoreStandaloneBagsDB.profiles[activeProfile]
    if profileData and profileData.addons then
        for _, db in pairs(dbRegistry) do
            if db._profileDefaults and db.profile then
                local stripped = DeepCopy(db.profile)
                StripDefaults(stripped, db._profileDefaults)
                profileData.addons[db.folder] = stripped
            end
        end
    end
end)

--------------------------------------------------------------------------------
--  Lifecycle driver (replaces AceAddon's ADDON_LOADED / PLAYER_LOGIN handler)
--------------------------------------------------------------------------------
-- OnInitialize fires on ADDON_LOADED (SavedVariables are available). OnEnable fires on
-- PLAYER_LOGIN (game data is available). This matches AceAddon's exact timing.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--  Stale central-DB guard
--------------------------------------------------------------------------------
-- WoW executes a child addon's ENTIRE WTF SavedVariables file when the child loads --
-- including variables its TOC no longer declares (the TOC only controls what gets
-- WRITTEN at logout). A child TOC that ever declared "## SavedVariables: EUICoreStandaloneBagsDB"
-- left a full copy of the central DB in that child's WTF file; if the child was then
-- disabled, the copy froze. Re-enabling the child executes the frozen copy AFTER the
-- parent loaded the real DB, replacing it -- and the next logout persists the stale
-- data over the real file (all profiles wiped).
--
-- The guard captures the authoritative table at the parent's own ADDON_LOADED
-- (the only moment it is guaranteed to be the freshly-loaded real data) and
-- re-points the global at it if any later load in the startup batch swapped
-- the table. It runs before the init queue below, so a poisoned child's own
-- OnInitialize never sees the stale table. Armed only until PLAYER_LOGIN:
-- every SV-bearing suite child is a hard dependency (never LoadOnDemand), so
-- all of them -- and any possible stale file -- load before then. The one
-- LoadOnDemand member, EUICoreStandaloneBagsOptions, declares NO SavedVariables by
-- design: WoW never writes a WTF file for it, so its post-login load executes
-- no SV file and can never swap the global. Keep it SV-less. Post-login
-- ADDON_LOADEDs (Blizzard on-demand addons) and intentional table swaps
-- (full reset + ReloadUI) are never touched. If the parent DB failed to
-- load (nil), the guard stays unarmed and behavior is unchanged.
local _parentDBRef           -- the table the parent's own SV file produced
local _dbGuardArmed = true   -- true from load until PLAYER_LOGIN

-- Re-root dbs created before the owning addon's SavedVariables loaded (see _preSVDBs
-- above): resolve the profile inside the REAL loaded central store, merge defaults, and
-- update the db object IN PLACE so every closure holding it reads and writes the table
-- WoW will serialize at logout. The vestigial child SV global is re-wiped in place (its
-- saved copy loaded after NewDB's file-scope wipe and would otherwise persist junk).
local function RerootPreSVDBs()
    if #_preSVDBs == 0 then return end
    local profileName = (EUICoreStandaloneBagsDB and EUICoreStandaloneBagsDB.activeProfile) or "Default"
    if not EUICoreStandaloneBagsDB then EUICoreStandaloneBagsDB = {} end
    if type(EUICoreStandaloneBagsDB.profiles) ~= "table" then EUICoreStandaloneBagsDB.profiles = {} end
    if type(EUICoreStandaloneBagsDB.profiles[profileName]) ~= "table" then
        EUICoreStandaloneBagsDB.profiles[profileName] = {}
    end
    local profileData = EUICoreStandaloneBagsDB.profiles[profileName]
    if not profileData.addons then profileData.addons = {} end
    for _, db in ipairs(_preSVDBs) do
        if type(profileData.addons[db.folder]) ~= "table" then
            profileData.addons[db.folder] = {}
        end
        local profile = profileData.addons[db.folder]
        if db._profileDefaults then
            DeepMergeDefaults(profile, db._profileDefaults)
        end
        db.sv = EUICoreStandaloneBagsDB
        db._profileName = profileName
        db.profile = profile
        if _G[db.svName] and type(_G[db.svName]) == "table" then
            wipe(_G[db.svName])
        else
            _G[db.svName] = {}
        end
    end
    wipe(_preSVDBs)
end

-- Drain the OnEnable queue. The pre-steps (PP.mult refresh, spec-profile
-- pre-seed) run once, before any OnEnable body. The dispatch site decides
-- whether to call this synchronously or one tick deferred -- see the big
-- comment there for why the triggering event makes that choice.
local function FlushEnableQueue()
    -- Ensure PP.mult is current before any addon's OnEnable runs. PP is
    -- defined in EUICoreStandaloneBags.lua (loaded after this file) so it exists by the
    -- time PLAYER_LOGIN fires.
    if EUICoreStandaloneBags and EUICoreStandaloneBags.PP and EUICoreStandaloneBags.PP.UpdateMult then
        EUICoreStandaloneBags.PP.UpdateMult()
    end
    -- Apply spec-assigned profile data into each child SV before any OnEnable
    -- runs. The spec API is available here (after OnInitialize, before
    -- OnEnable) so we can resolve the current spec and inject the correct
    -- profile snapshot. ADDON_LOADED is too early (spec API not ready yet).
    if EUICoreStandaloneBags and EUICoreStandaloneBags.PreSeedSpecProfile then
        EUICoreStandaloneBags.PreSeedSpecProfile()
    end
    while #enableQueue > 0 do
        local addon = tremove(enableQueue, 1)
        if addon.enabledState then
            statuses[addon.name] = true
            safecall(addon.OnEnable, addon)
        end
    end
end

-- Account passes that must read the saved data exactly as it loaded: run once
-- at this addon's own ADDON_LOADED, before a pre-SavedVariables db is
-- re-rooted and before any OnInitialize opens a profile and merges defaults
-- into it -- in the suite and in every standalone alike.
local _svLoadedHooks = {}
function EUILite.OnSavedVariablesLoaded(fn)
    _svLoadedHooks[#_svLoadedHooks + 1] = fn
end

--- For those passes: true while EUICoreStandaloneBagsDB is still the stand-in a
--- pre-SavedVariables db built (a standalone's file-scope NewDB), with no saved
--- data loaded over it -- a fresh account, whatever the stand-in holds.
function EUILite.StoreFromBeforeLoad()
    local db = _preSVDBs[1]
    return db ~= nil and db.sv == EUICoreStandaloneBagsDB
end

local lifecycleFrame = CreateFrame("Frame")
lifecycleFrame:RegisterEvent("ADDON_LOADED")
lifecycleFrame:RegisterEvent("PLAYER_LOGIN")
lifecycleFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            _parentDBRef = EUICoreStandaloneBagsDB
            for i = 1, #_svLoadedHooks do safecall(_svLoadedHooks[i]) end
            wipe(_svLoadedHooks)
            if IS_STANDALONE then
                _svLoaded = true
                RerootPreSVDBs()
                -- Runtime files can cache default fonts before this addon's
                -- SavedVariables load. Resolve the saved choice when frames init.
                if EUICoreStandaloneBags.InvalidateFontCache then
                    EUICoreStandaloneBags.InvalidateFontCache()
                end
            end
        elseif _dbGuardArmed and _parentDBRef and EUICoreStandaloneBagsDB ~= _parentDBRef then
            -- A stale SavedVariables copy from a child's WTF file replaced the central
            -- DB. Restore the real table; the stale copy purges from the offending file
            -- on its next logout (its TOC no longer declares the variable).
            EUICoreStandaloneBagsDB = _parentDBRef
        end
    elseif event == "PLAYER_LOGIN" then
        _dbGuardArmed = false
    end

    -- Process init queue on every ADDON_LOADED (same as AceAddon)
    while #initQueue > 0 do
        local addon = tremove(initQueue, 1)
        safecall(addon.OnInitialize, addon)
        tinsert(enableQueue, addon)
    end

    -- Process the enable (OnEnable) queue once logged in. WHEN we run it
    -- depends on which event delivered us here, and both cases matter:
    --
    --   * PLAYER_LOGIN -> run SYNCHRONOUSLY, right now. PLAYER_LOGIN is a
    --     top-level game event, never dispatched from inside a secure chain,
    --     so the mid-secure-chain taint hazard below does not apply. Running
    --     here also keeps every OnEnable (and the secure setup each performs:
    --     RegisterStateDriver, WrapScript, protected SetCVar, EditMode Hide)
    --     inside the login/reload LOADING-SCREEN window -- the only window in
    --     which those secure operations are permitted while the player is in
    --     combat. C_Timer callbacks do NOT run during the loading screen, so
    --     deferring here would always miss the window on a /reload in combat
    --     and every child addon's secure setup would be blocked
    --     (ADDON_ACTION_BLOCKED storm).
    --
    --   * ADDON_LOADED (post-login demand-loads) -> DEFER one tick. These can
    --     be dispatched from inside Blizzard's own SECURE executions (e.g.
    --     UIParent demand-loading Blizzard_CombatLog), and running OnEnable
    --     bodies synchronously there stamps every value they write with addon
    --     taint born mid-secure-chain -- fields Edit Mode's enter/exit passes
    --     later read, erroring on 12.x secret values. A timer callback is a
    --     fresh, purely addon-owned execution. Such loads happen after the
    --     loading screen anyway, so there is no in-combat secure window to
    --     preserve for them.
    if IsLoggedIn() and #enableQueue > 0 then
        if event == "PLAYER_LOGIN" then
            FlushEnableQueue()
        elseif not lifecycleFrame._enableFlushQueued then
            lifecycleFrame._enableFlushQueued = true
            C_Timer.After(0, function()
                lifecycleFrame._enableFlushQueued = false
                FlushEnableQueue()
            end)
        end
    end
end)
