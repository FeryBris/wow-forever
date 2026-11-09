-- SavedVariables: profiles, defaults, migrations, enabling and disabling.
--
-- Two tables, and the difference between them matters everywhere below:
--
--   FP.global   the whole saved file -- the profiles, the per-character
--               pointers into them, and the diagnostics reports, which are
--               measurements rather than settings and therefore sit outside
--               any profile.
--   FP.db       the *active profile*. Everything a module reads and writes.
--
-- FP.db keeping its old meaning is deliberate. Every module already says
-- mod.db, and FP.db.modules still holds the on and off states, so profiles
-- arrived without a single module having to change.
--
-- No AceDB. It would fit, and BSD stopped being an obstacle, but it is the one
-- Ace component with no evidence of running on this client, it drags in
-- LibStub and CallbackHandler, and its defaults-by-metatable model means a
-- value equal to its default is never written to disk at all. That opacity is
-- wrong in the one place where a bug destroys work that cannot be recovered.

local ADDON, FP = ...
local L = FP.L

local DB_VERSION      = 10
local DEFAULT_PROFILE = "Default"
local MAX_NAME        = 32

-- Only the structure. Anything a module owns lives inside a profile.
local GLOBAL_DEFAULTS = {
    dbVersion   = DB_VERSION,
    profiles    = {},   -- [profile name] = settings
    profileKeys = {},   -- [character guid] = profile name, see CharacterKey
}

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

-- Fills in missing keys without overwriting existing values, so an existing
-- profile picks up new options but keeps the user's choices.
local function ApplyDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then target[k] = {} end
            ApplyDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
    return target
end

function FP:ApplyDefaults(target, defaults)
    return ApplyDefaults(target, defaults)
end

local function DeepCopy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = DeepCopy(v) end
    return out
end

-- ---------------------------------------------------------------------------
-- Migrations
--
-- Each entry turns version N into version N+1, and they run in sequence, so a
-- file several versions behind is carried the whole way rather than needing a
-- special case per jump.
-- ---------------------------------------------------------------------------

local MIGRATIONS = {}

--- 1 -> 2: the flat settings become the "Default" profile.
--
-- Before this, ForeverPlusDB.modules held the on and off states and every
-- module had a top-level branch of its own. Both now live inside a profile,
-- and a character points at one by name.
--
-- The old keys are removed rather than left beside the new ones. That is
-- normally the wrong move -- a release that stops reading a key should not also
-- delete it -- but nothing has been handed to anyone yet, so there is no copy
-- of 0.1.0 anywhere that could still want them.
MIGRATIONS[1] = function(global)
    local profile = { modules = {} }

    if type(global.modules) == "table" then
        for name, state in pairs(global.modules) do
            profile.modules[name] = state
        end
    end
    global.modules = nil

    -- Only branches belonging to a module we actually have. Anything else at
    -- the top level is left alone: it is either ours (diagnostics, discovery)
    -- or it belongs to a module that has since been removed, and guessing is
    -- worse than leaving it.
    for _, name in ipairs(FP.order) do
        if type(global[name]) == "table" then
            profile[name] = global[name]
            global[name] = nil
        end
    end

    global.profiles = global.profiles or {}
    global.profiles[DEFAULT_PROFILE] = profile
end

--- 2 -> 3: BuffExpiry's two timing settings are replaced by two others.
--
-- `warnSeconds` and `minDuration` described a design that no longer exists.
-- The module watched anything with a long enough timer and warned at a
-- fraction of its length; it now watches a curated list per class and warns at
-- one of two thresholds either side of a ten minute boundary.
--
-- The old keys are removed rather than left lying beside the new ones. Neither
-- is read any more, and a value in a saved file that nothing reads is a
-- question for whoever finds it later.
MIGRATIONS[2] = function(global)
    for _, profile in pairs(global.profiles or {}) do
        local buffs = profile.BuffExpiry
        if type(buffs) == "table" then
            buffs.warnSeconds = nil
            buffs.minDuration = nil
        end
    end
end

--- 3 -> 4: AutoSellGrey is AutoSellGray.
--
-- A spelling change with a real cost behind it. **A module's name is the key
-- its settings are stored under**, so renaming it without moving them would
-- look to the player exactly like the module resetting itself, and they would
-- be right to call that a bug rather than a spelling pass.
--
-- Both halves move: the settings branch and the on or off state beside it.
--
-- Written so that running it twice changes nothing the second time. The
-- framework does not promise that on its own, and a migration that is only
-- correct once is a migration nobody can rerun to check.
MIGRATIONS[3] = function(global)
    for _, profile in pairs(global.profiles or {}) do
        if profile.AutoSellGrey ~= nil and profile.AutoSellGray == nil then
            profile.AutoSellGray = profile.AutoSellGrey
        end
        profile.AutoSellGrey = nil

        local modules = profile.modules
        if type(modules) == "table" then
            if modules.AutoSellGrey ~= nil and modules.AutoSellGray == nil then
                modules.AutoSellGray = modules.AutoSellGrey
            end
            modules.AutoSellGrey = nil
        end
    end
end

--- 4 -> 5: the quest reward values became a module of their own.
--
-- They were an option on QuestAutoTurnIn, `showRewardValue`, and are now the
-- module `QuestRewardValue`. Somebody who had switched them off said so on a
-- switch that no longer exists, and losing that would turn them back on
-- without being asked.
--
-- Only the "off" case needs carrying. A module defaults to on, so an absent
-- entry already means on, and writing one would be saying the same thing twice.
MIGRATIONS[4] = function(global)
    for _, profile in pairs(global.profiles or {}) do
        local turnIn = profile.QuestAutoTurnIn
        if type(turnIn) == "table" then
            if turnIn.showRewardValue == false then
                profile.modules = profile.modules or {}
                if profile.modules.QuestRewardValue == nil then
                    profile.modules.QuestRewardValue = false
                end
            end
            turnIn.showRewardValue = nil
        end
    end
end

--- 5 -> 6: a character is known by its guid rather than by its name.
--
-- Found on 2026-09-26, the first day build 70009 handed saved variables back.
-- The same character had been "Sleepi Joe" to UnitName on 69977 and was
-- "Sleepi" on 70009, so the file held two characters where there was one and
-- the info bar added the same gold up twice. See CharacterKey below.
--
-- **What the player chose travels, what the addon only observed starts again.**
--
--   profileKeys  Which profile a character uses is a choice. An entry pointing
--                at Default is dropped, because no entry means Default anyway;
--                the rest wait under the old name and are carried over to the
--                guid the next time that character logs in, the only moment
--                its name and its guid are both known (ActivateProfile).
--   gold         Cleared, and its entries change shape, from a bare amount to
--                { copper, name, realm, class }: the overview on the info bar
--                has to say whose gold it is. Every character is counted
--                again at its next login.
--   noticed      Cleared. A notice said once may be said once more.
--
-- Nothing but the three tables is touched, so running it twice is harmless.
MIGRATIONS[5] = function(global)
    if type(global.profileKeys) == "table" then
        -- Clearing a key during pairs() is allowed; adding one is not.
        for key, pointed in pairs(global.profileKeys) do
            if pointed == DEFAULT_PROFILE then global.profileKeys[key] = nil end
        end
    end
    global.gold    = nil
    global.noticed = nil
end

--- 6 -> 7: ChatTweaks is replaced by Chat, which carries its settings on.
--
-- Phase 6, decided on 2026-09-23 against the recommendation, which was to grow
-- ChatTweaks and leave its key alone. The owner chose a module named for what
-- it is, and **a module's name is the key its settings live under**, so the
-- rename has to move them, exactly as 3 to 4 did for AutoSellGray.
--
-- The three settings keep their keys: never fade, Shift plus wheel, lines per
-- notch. Since build 70009 they come back at every start, so this reaches
-- everybody who ever changed one. Written so a second run changes nothing.
MIGRATIONS[6] = function(global)
    for _, profile in pairs(global.profiles or {}) do
        if profile.ChatTweaks ~= nil and profile.Chat == nil then
            profile.Chat = profile.ChatTweaks
        end
        profile.ChatTweaks = nil

        local modules = profile.modules
        if type(modules) == "table" then
            if modules.ChatTweaks ~= nil and modules.Chat == nil then
                modules.Chat = modules.ChatTweaks
            end
            modules.ChatTweaks = nil
        end
    end
end

--- 7 -> 8: Ammunition's buttons at the merchant become a module of their own.
--
-- The owner's word of 2026-10-10, when the merchant's modules got a group of
-- their own: the buying went there as "Ammunition", and the count with its
-- warning stayed under Display as "Ammunition Warning". **The warning keeps
-- the module's name and so its settings**; the buying moves to FillQuiver.
-- Its two switches go with it: the buttons switched off make that module
-- off, and the question's switch keeps its key. A profile that had the whole
-- module off has both off. Written so a second run changes nothing.
MIGRATIONS[7] = function(global)
    for _, profile in pairs(global.profiles or {}) do
        local ammo = profile.Ammunition
        local off = type(profile.modules) == "table"
            and profile.modules.Ammunition == false
        if type(ammo) == "table" then
            if ammo.fillButtons == false then off = true end
            if ammo.fillWithoutAsking ~= nil and type(profile.FillQuiver) ~= "table" then
                profile.FillQuiver = { fillWithoutAsking = ammo.fillWithoutAsking }
            end
            ammo.fillButtons, ammo.fillWithoutAsking = nil, nil
        end
        if off then
            profile.modules = profile.modules or {}
            if profile.modules.FillQuiver == nil then
                profile.modules.FillQuiver = false
            end
        end
    end
end

--- 8 -> 9: the displays become bars of the profile.
--
-- Planned on 2026-10-14 and 15, see
-- planning/1.0.0/PLANNING-BUFFS-AND-LAYOUT.md: BuffExpiry's two displays and
-- Consumables' one were each their module's, with the look and the position in
-- its branch. They become the three default bars, General Warnings, Combat
-- Buffs and Consumables, exactly as they were, and every entry stays on the
-- display it drew on, since that is its factory bar. The work is
-- Core/Bars.lua's, so a profile from an import string gets the same.
MIGRATIONS[8] = function(global)
    for _, profile in pairs(global.profiles or {}) do
        FP.Bars.Migrate(profile)
    end
end

--- 9 -> 10: the chat's input line has three places rather than a switch.
--
-- S2 of the 1.0.2 brief, silhouetteone's request on CurseForge of 2026-10-20
-- and the owner's answer of 2026-10-21: below the window, between the window
-- and its tabs, or above the tabs. `inputTop` put it between them, so a
-- profile that had it on keeps that place, the owner's condition, and the
-- switch goes. Written so a second run changes nothing.
MIGRATIONS[9] = function(global)
    for _, profile in pairs(global.profiles or {}) do
        local chat = profile.Chat
        if type(chat) == "table" then
            if chat.inputTop == true and chat.inputPlace == nil then
                chat.inputPlace = "between"
            end
            chat.inputTop = nil
        end
    end
end

-- Every migration up to 4 to 5 ran against a real saved file and was confirmed
-- in game. Until build 70009 that was only possible after a /reload, and on
-- 69977 not even then: nothing was handed back, so nothing was ever migrated
-- and a player could not have found out either way. 5 to 6 is the first to run
-- on a client that reads its file at every start.

function FP:RunMigrations(global)
    local from = tonumber(global.dbVersion) or 1

    if from > DB_VERSION then
        -- Settings written by a later version. Say so rather than quietly
        -- working on a structure we do not understand.
        return self:Warn(L["Settings were written by a newer version (format "
            .. "%d, this build reads %d). Leaving them unchanged."], from, DB_VERSION)
    end

    while from < DB_VERSION do
        local step = MIGRATIONS[from]
        if not step then
            return self:Warn(L["No way to convert settings from format %d "
                .. "to %d."], from, from + 1)
        end
        local ok = self:Safe(L["migration %d to %d"]:format(from, from + 1),
            step, global)
        if not ok then
            -- Stop at the failure instead of running the next step on a
            -- half-converted file.
            return self:Warn(L["Settings stayed at format %d."], from)
        end
        from = from + 1
        global.dbVersion = from
        self:Print(L["Settings converted to format %d."], from)
    end
end

-- ---------------------------------------------------------------------------
-- Start-up
-- ---------------------------------------------------------------------------

--- A profile that starts from nothing: a new player's, a new one, or one reset.
--
-- **Where a default changed after profiles had been kept with the old one**, a
-- module names the new value in `fresh`, a function filling its branch, and
-- only a profile that starts here gets it. A profile from before stored
-- nothing for that setting and goes on reading the old default, since a new
-- default must not change anybody's settings, the owner's word of 2026-10-18;
-- a copy and an import keep what they carry. See BuffExpiry's `fresh`.
local function EmptyProfile()
    local profile = { modules = {} }
    for name, mod in pairs(FP.modules or {}) do
        if type(mod.fresh) == "function" then
            local branch = {}
            mod.fresh(branch)
            profile[name] = branch
        end
    end
    return profile
end

--- Creates the saved structure and brings it up to date.
--
-- Runs at ADDON_LOADED. It deliberately does *not* pick a profile: which
-- profile a character uses is looked up by the character's guid, and nothing
-- about the player is reliably available this early.
function FP:InitDB()
    -- What the client handed us, counted before anything here touches it.
    -- Settings vanishing between one session and the next is the worst failure
    -- this addon can have, and a fresh database looks exactly like a first run.
    -- Nothing prints this any more (see Boot.lua); /dump ForeverPlus.loaded
    -- reads it in game, which is the cheapest way to check a new build.
    local handed = _G.ForeverPlusDB
    self.loaded = {
        hadTable   = type(handed) == "table",
        hadVersion = type(handed) == "table" and handed.dbVersion or nil,
        profiles   = 0,
        characters = 0,
    }
    if type(handed) == "table" then
        if type(handed.profiles) == "table" then
            for _ in pairs(handed.profiles) do
                self.loaded.profiles = self.loaded.profiles + 1
            end
        end
        if type(handed.profileKeys) == "table" then
            for _ in pairs(handed.profileKeys) do
                self.loaded.characters = self.loaded.characters + 1
            end
        end
    end

    local global = ApplyDefaults(_G.ForeverPlusDB or {}, GLOBAL_DEFAULTS)
    _G.ForeverPlusDB = global
    self.global = global

    self:RunMigrations(global)

    if not next(global.profiles) then
        global.profiles[DEFAULT_PROFILE] = EmptyProfile()
        self.loaded.startedFresh = true
    end
end

--- A stable key for this character: its guid.
--
-- **Not its name, and that was measured rather than argued.** Up to format 5
-- the key was "Name - Realm". On 2026-09-26, the first day this client handed
-- saved variables back, one character came back as two: UnitName had answered
-- "Sleepi Joe" on build 69977 and answered "Sleepi" on 70009. Names here come
-- out of a pseudonym system and are display text, and display text moves. It
-- may well have moved before; nobody could see it while nothing was read back.
--
-- The guid is the server's own record of the character, "Player-<realm>-<id>".
-- It is the same under every name and in every language, so this is the locale
-- rule being kept as much as a fault being fixed.
--
-- Only meaningful from PLAYER_LOGIN onwards. nil when the client will not say.
function FP:CharacterKey()
    if type(UnitGUID) ~= "function" then return nil end
    local ok, guid = pcall(UnitGUID, "player")
    return ok and self:Plain(guid) or nil
end

--- What format 5 and earlier called this character, newest spelling first.
--
-- Only for carrying a profile choice over to the guid. Both spellings the name
-- has been seen in are tried, built from what the client answers now: the first
-- part alone, as 70009 gives it, and both parts, as 69977 gave it. A character
-- whose name has moved a third time is simply not found, and lands on Default.
local function LegacyKeys()
    if type(UnitName) ~= "function" then return {} end
    local ok, first, second = pcall(UnitName, "player")
    first = ok and FP:Plain(first)
    -- UKNOWNBEING is the client's own global for "Unknown Being" (Blizzard's
    -- spelling, not a typo here) and is what UnitName answers before the
    -- player is fully there. Resolved from the client rather than compared
    -- against the English words, per the locale rule.
    if not first or first == UKNOWNBEING then return {} end

    local realm = (GetNormalizedRealmName and GetNormalizedRealmName())
               or (GetRealmName and GetRealmName())
    realm = FP:Plain(realm) or "?"

    local keys = { first .. " - " .. realm }
    second = FP:Plain(second)
    if second then keys[2] = first .. " " .. second .. " - " .. realm end
    return keys
end

--- Moves this character's profile choice from its old name to its guid.
--
-- Every old spelling is removed once it has been looked at, so a character is
-- carried over once and leaves nothing behind under a name it no longer has.
local function AdoptLegacyKey(keys, key)
    if keys[key] ~= nil then return end
    for _, old in ipairs(LegacyKeys()) do
        if keys[old] ~= nil then
            if keys[key] == nil then keys[key] = keys[old] end
            keys[old] = nil
        end
    end
end

--- Removes everything this addon keeps about one character.
--
-- Asked for on 2026-09-26, together with the gold overview it is reached from:
-- once the client started handing the file back, a deleted or abandoned
-- character stayed in every per character record for good.
--
-- Five records are kept per character, all under its key, and this is the
-- one place that has to know all of them: which profile it uses, its gold,
-- the notices already shown to it, since 0.8.0 its chat, kept across
-- sessions by Modules/ChatHistory.lua, and since 2026-09-29 its name, realm,
-- faction, class and level, for the mail window's list in Modules/MailAlts.lua.
-- The profiles themselves are shared by every character and are left alone.
--
-- Refuses the character being played. Every one of those records is written
-- again within a second of being removed, so deleting it would only look as
-- if it had worked.
--
-- @return the number of records removed, or nil and a reason
function FP:ForgetCharacter(key)
    if type(key) ~= "string" or key == "" then
        return nil, L["No character given"]
    end
    if key == self.charKey then
        return nil, L["That is the character you are playing"]
    end

    local global, removed = self.global, 0
    if global.profileKeys[key] ~= nil then
        global.profileKeys[key] = nil
        removed = removed + 1
    end
    if type(global.gold) == "table" and global.gold[key] ~= nil then
        global.gold[key] = nil
        removed = removed + 1
    end
    if type(global.chatHistory) == "table" and global.chatHistory[key] ~= nil then
        global.chatHistory[key] = nil
        removed = removed + 1
    end
    if type(global.autoBuy) == "table" and global.autoBuy[key] ~= nil then
        global.autoBuy[key] = nil
        removed = removed + 1
    end
    if type(global.cooldowns) == "table" and global.cooldowns[key] ~= nil then
        global.cooldowns[key] = nil
        removed = removed + 1
    end
    if type(global.characters) == "table" and global.characters[key] ~= nil then
        global.characters[key] = nil
        removed = removed + 1
    end
    if type(global.noticed) == "table" then
        local prefix = key .. "/"
        -- Clearing a key during pairs() is allowed; adding one is not.
        for slot in pairs(global.noticed) do
            if type(slot) == "string" and slot:sub(1, #prefix) == prefix then
                global.noticed[slot] = nil
                removed = removed + 1
            end
        end
    end
    return removed
end

--- Picks this character's profile and wires everything to it.
function FP:ActivateProfile()
    local key = self:CharacterKey()
    if not key then
        self:Warn(L["Could not identify this character, so %s is in use. A "
            .. "/reload should fix it."], DEFAULT_PROFILE)
    end
    self.charKey = key

    if key then AdoptLegacyKey(self.global.profileKeys, key) end

    local name = key and self.global.profileKeys[key]
    if not name or not self.global.profiles[name] then
        name = DEFAULT_PROFILE
        if not self.global.profiles[name] then
            self.global.profiles[name] = EmptyProfile()
        end
        if key then self.global.profileKeys[key] = name end
    end

    self:BindProfile(name)
end

--- Points FP.db and every mod.db at a profile, filling in what is missing.
--
-- Binding only moves references. Nothing is started or stopped here, because
-- the two callers want different things: start-up enables from scratch, while
-- a profile switch has to compare against what is already running.
function FP:BindProfile(name)
    local profile = self.global.profiles[name]
    profile.modules = profile.modules or {}
    -- A profile made fresh, reset or imported gets its three bars here, before
    -- anything draws on one.
    if self.Bars then self.Bars.Ensure(profile) end

    self.profileName = name
    self.db = profile

    for _, moduleName in ipairs(self.order) do
        local mod = self.modules[moduleName]
        if profile.modules[moduleName] == nil then
            profile.modules[moduleName] = mod.default
        end
        profile[moduleName] = ApplyDefaults(profile[moduleName] or {}, self:OptionDefaults(mod))
        mod.db = profile[moduleName]
    end
end

-- ---------------------------------------------------------------------------
-- Running modules
--
-- The runtime half, split out from the stored half on purpose. A profile switch
-- needs exactly this: the new profile already says what should be running, so
-- writing that state back would be writing a value onto itself -- and writing
-- it through EnableModule would put it in whichever profile FP.db points at,
-- which during a switch is briefly the wrong one.
-- ---------------------------------------------------------------------------

local function StartModule(mod)
    if mod.enabled then return end
    mod.enabled = true
    FP:Safe(mod.name .. ":OnEnable", mod.OnEnable, mod)
end

local function StopModule(mod)
    if not mod.enabled then return end
    if not mod.OnDisable then
        -- The module cannot undo itself. Say so instead of pretending it is off.
        FP:Print(L["%s is off. Takes effect after /reload."], FP:ModuleTitle(mod))
        return
    end
    mod.enabled = false
    FP:Safe(mod.name .. ":OnDisable", mod.OnDisable, mod)
end

function FP:IsEnabled(name)
    return self.db and self.db.modules[name] == true
end

-- ---------------------------------------------------------------------------
-- A page's switch
--
-- The owner's rule of 2026-09-30: every page of the window that changes the
-- game has a switch on its tab. A page that is one module uses that module's
-- own switch, and nothing here is needed for it. The Gameplay page is a list
-- of modules with a switch each, so its switch is a second one above theirs:
-- off stops every module in the list, the minimap button among them, and each
-- keeps its own setting, so switching the page on again brings back exactly
-- the ones that were on. His choice over switching them all on or all off,
-- which would lose that.
--
-- Kept in the profile under `pagesOff`, by a key of the page's own rather than
-- by its caption: the Gameplay page was called Modules until 0.7.0.
-- ---------------------------------------------------------------------------

FP.LIST_PAGE = "list"

--- The key of the page switch this module answers to, or nil for none.
local function GateOf(mod)
    if FP:IsListed(mod) then return FP.LIST_PAGE end
    return nil
end

function FP:PageOff(key)
    local off = self.db and self.db.pagesOff
    return type(off) == "table" and off[key] == true
end

--- Whether a module should be running: switched on itself, and not on a page
--- that is switched off. IsEnabled answers only the first half, which is what
--- the module's own box shows.
function FP:IsWanted(name)
    local mod = self.modules[name]
    if not (mod and self:IsEnabled(name)) then return false end
    local gate = GateOf(mod)
    return not (gate and self:PageOff(gate))
end

function FP:EnableModule(name)
    local mod = self.modules[name]
    if not mod then return self:Warn(L["Unknown module: %s"], tostring(name)) end
    self.db.modules[name] = true
    -- On a page that is switched off it waits for the page.
    if self:IsWanted(name) then StartModule(mod) end
end

function FP:DisableModule(name)
    local mod = self.modules[name]
    if not mod then return self:Warn(L["Unknown module: %s"], tostring(name)) end
    self.db.modules[name] = false
    StopModule(mod)
end

function FP:ToggleModule(name)
    if self:IsEnabled(name) then self:DisableModule(name)
    else self:EnableModule(name) end
    return self:IsEnabled(name)
end

--- Switches a page on or off, and starts or stops every module answering to
--- it. The modules' own settings are not touched.
function FP:SetPageOff(key, off)
    if not self.db then return end
    if type(self.db.pagesOff) ~= "table" then self.db.pagesOff = {} end
    self.db.pagesOff[key] = off and true or nil

    for _, name in ipairs(self.order) do
        local mod = self.modules[name]
        if GateOf(mod) == key then
            if self:IsWanted(name) then StartModule(mod) else StopModule(mod) end
        end
    end
end

function FP:EnableAll()
    for _, name in ipairs(self.order) do
        if self:IsWanted(name) then StartModule(self.modules[name]) end
    end
end

--- Brings a running module in line with values that have changed underneath it.
--
-- Stopping and starting is the generic route: the module cleans up in
-- OnDisable and rebuilds with the new values in OnEnable. It is also a
-- sledgehammer, and for anything holding a window it is the wrong one -- the
-- settings window vanished on every profile switch, because tearing the module
-- down is exactly what OnDisable is supposed to do.
--
-- A module that can adjust itself in place says so with Reapply, and that is
-- used instead.
local function Reapply(mod)
    if mod.Reapply then
        return FP:Safe(mod.name .. ":Reapply", mod.Reapply, mod)
    end
    if mod.OnDisable and mod.OnEnable then
        FP:Safe(mod.name .. ":OnDisable", mod.OnDisable, mod)
        FP:Safe(mod.name .. ":OnEnable",  mod.OnEnable,  mod)
        return true
    end
    return false
end

function FP:RefreshModule(name)
    local mod = self.modules[name]
    if not mod or not mod.enabled then return end
    if not Reapply(mod) then
        self:Print(L["%s: /reload needed for the change to take effect."],
            self:ModuleTitle(mod))
    end
end

-- ---------------------------------------------------------------------------
-- Profiles
-- ---------------------------------------------------------------------------

function FP:ListProfiles()
    local names = {}
    for name in pairs(self.global.profiles) do names[#names + 1] = name end
    table.sort(names)
    return names
end

--- A usable profile name, or nil and the reason it is not.
--
-- The length is counted in bytes, so a name with umlauts gets fewer characters
-- than an English one. Not worth solving: this is our own field, and the limit
-- is there to keep the tab readable rather than to be exact.
function FP:ValidProfileName(name)
    if type(name) ~= "string" then return nil, L["A profile needs a name"] end

    name = name:match("^%s*(.-)%s*$")
    if name == "" then return nil, L["A profile needs a name"] end
    if #name > MAX_NAME then
        return nil, L["Profile names are limited to %d characters"]:format(MAX_NAME)
    end
    -- The name is printed, and it travels inside an export string. A pipe would
    -- open a color escape and a control character would not survive the trip.
    if name:find("[%c|]") then
        return nil, L["A profile name cannot contain a pipe or a "
            .. "control character"]
    end
    return name
end

--- Creates a profile, optionally as a copy of an existing one.
-- @return the name on success, or nil and a reason
function FP:CreateProfile(name, copyFrom)
    local clean, why = self:ValidProfileName(name)
    if not clean then return nil, why end
    if self.global.profiles[clean] then
        return nil, L["A profile called %s already exists"]:format(clean)
    end

    local source = copyFrom and self.global.profiles[copyFrom]
    if copyFrom and not source then
        return nil, L["No profile called %s exists"]:format(copyFrom)
    end

    self.global.profiles[clean] = source and DeepCopy(source) or EmptyProfile()
    return clean
end

function FP:RenameProfile(from, to)
    if not self.global.profiles[from] then
        return nil, L["No profile called %s exists"]:format(tostring(from))
    end

    local clean, why = self:ValidProfileName(to)
    if not clean then return nil, why end
    if self.global.profiles[clean] then
        return nil, L["A profile called %s already exists"]:format(clean)
    end

    self.global.profiles[clean] = self.global.profiles[from]
    self.global.profiles[from]  = nil

    -- Every character standing on the old name has to come along, or it would
    -- silently fall back to Default on its next login.
    for key, pointed in pairs(self.global.profileKeys) do
        if pointed == from then self.global.profileKeys[key] = clean end
    end
    if self.profileName == from then self.profileName = clean end

    return clean
end

--- Empties a profile back to the defaults of every module.
function FP:ResetProfile(name)
    name = name or self.profileName
    if not self.global.profiles[name] then
        return nil, L["No profile called %s exists"]:format(tostring(name))
    end

    self.global.profiles[name] = EmptyProfile()
    if name == self.profileName then self:ApplyProfile(name) end
    return name
end

function FP:DeleteProfile(name)
    if not self.global.profiles[name] then
        return nil, L["No profile called %s exists"]:format(tostring(name))
    end

    local names = self:ListProfiles()
    if #names <= 1 then
        return nil, L["%s is the only profile. Reset it instead of "
            .. "deleting it"]:format(name)
    end

    -- Move everyone standing on it off first, so that nothing is left pointing
    -- at a profile that no longer exists.
    local fallback
    for _, other in ipairs(names) do
        if other ~= name then fallback = fallback or other end
    end
    if name ~= DEFAULT_PROFILE and self.global.profiles[DEFAULT_PROFILE] then
        fallback = DEFAULT_PROFILE
    end

    for key, pointed in pairs(self.global.profileKeys) do
        if pointed == name then self.global.profileKeys[key] = fallback end
    end

    local wasActive = (self.profileName == name)
    self.global.profiles[name] = nil

    if wasActive then self:ApplyProfile(fallback) end
    return name
end

--- Switches this character to a profile.
function FP:SetProfile(name)
    if not self.global.profiles[name] then
        return nil, L["No profile called %s exists"]:format(tostring(name))
    end
    if name == self.profileName then
        return name
    end

    if self.charKey then self.global.profileKeys[self.charKey] = name end

    -- Restarting a module can touch a protected frame, which is refused in
    -- combat. Defer rather than decline: declining loses the switch in exactly
    -- the moment somebody wanted it.
    if InCombatLockdown() then
        self:Print(L["Profile %s takes effect when you leave combat."], name)
        self:OutOfCombat("profile switch", function() FP:ApplyProfile(name) end)
    else
        self:ApplyProfile(name)
    end
    return name
end

--- Rebinds to a profile and brings every module in line with it.
function FP:ApplyProfile(name)
    if not self.global.profiles[name] then
        return self:Warn(L["Profile %s disappeared before it could be "
            .. "applied."], tostring(name))
    end

    -- Read before FP.db moves: afterwards the old profile is out of reach and
    -- there is no way to tell what was running.
    local running = {}
    for _, moduleName in ipairs(self.order) do
        running[moduleName] = self.modules[moduleName].enabled
    end

    self:BindProfile(name)

    for _, moduleName in ipairs(self.order) do
        local mod = self.modules[moduleName]
        -- The new profile's page switches count as well as its module ones.
        local wanted = self:IsWanted(moduleName)

        if wanted and running[moduleName] then
            -- Same module, on in both profiles, but its settings may have
            -- moved. Reapply rather than StopModule: a module without
            -- OnDisable would otherwise announce itself as off while it keeps
            -- running, and one holding a window would close it.
            if not Reapply(mod) then
                self:Print(L["%s: /reload needed before its new settings apply."],
                    self:ModuleTitle(mod))
            end
        elseif wanted then
            StartModule(mod)
        elseif running[moduleName] then
            StopModule(mod)
        end
    end

    self:Print(L["Profile: %s"], name)
end

-- ---------------------------------------------------------------------------
-- Export and import
-- ---------------------------------------------------------------------------

local MAX_DEPTH = 4

--- Reduces an imported table to the shape a profile is allowed to have.
--
-- Structural only: a profile is a table of module branches, each a table of
-- scalars. Anything else is dropped and named, so an import can never bring in
-- something deeper or stranger than the settings are.
--
-- Checking each key against its declared type belongs here too, but the option
-- schema that would say what a key *is* arrives with 1.2. Until then there is
-- nothing to check against -- BuffExpiry, for one, stores its dragged position
-- under keys that are deliberately absent from its defaults.
local function Clean(value, depth, path, skipped)
    local kind = type(value)
    if kind == "string" or kind == "number" or kind == "boolean" then
        return value
    end

    if kind == "table" and depth < MAX_DEPTH then
        local out = {}
        for key, item in pairs(value) do
            if type(key) == "string" or type(key) == "number" then
                local cleaned = Clean(item, depth + 1, path .. "." .. tostring(key), skipped)
                if cleaned ~= nil then out[key] = cleaned end
            else
                skipped[#skipped + 1] = L["%s (a %s key)"]:format(path, type(key))
            end
        end
        return out
    end

    skipped[#skipped + 1] = path .. " (" .. kind .. ")"
    return nil
end

-- What a profile holds beside its module branches. See ImportProfile.
local PROFILE_KEYS = { modules = true, pagesOff = true, bars = true }

--- A profile as a transport string.
-- @return the string, or nil and a reason
function FP:ExportProfile(name)
    name = name or self.profileName
    local profile = self.global.profiles[name]
    if not profile then
        return nil, L["No profile called %s exists"]:format(tostring(name))
    end

    return self:Encode({ v = self.version, name = name, data = profile })
end

--- Reads a transport string into a new profile.
--
-- Never overwrites: the name from the string is used, suffixed on collision,
-- and switching to it afterwards is a deliberate second step. Pasting a string
-- should not be able to cost somebody their configuration.
--
-- @return the new profile's name and a list of what was skipped,
--         or nil and a reason
function FP:ImportProfile(text)
    local payload, why = self:Decode(text)
    if not payload then return nil, why end

    if type(payload) ~= "table" or type(payload.data) ~= "table" then
        return nil, L["that string is not a ForeverPlus profile"]
    end

    local skipped = {}
    local data = Clean(payload.data, 0, "profile", skipped)
    if type(data) ~= "table" then
        return nil, L["that profile has no readable settings in it"]
    end
    data.modules = type(data.modules) == "table" and data.modules or {}

    -- A string exported by an older version carries the older shape: a
    -- ChatTweaks branch where this build has Chat, for one. The migrations that
    -- work on a profile's contents are run over it first, so a renamed module
    -- arrives under its new name instead of being dropped below as unknown.
    -- The first one is not among them, since it builds profiles out of a flat
    -- file and a profile string was never flat. Every one of them changes
    -- nothing the second time, which is what makes running them on a profile
    -- that is already current safe.
    local wrapper = { profiles = { data } }
    for step = 2, DB_VERSION - 1 do
        if MIGRATIONS[step] then
            self:Safe(L["import migration %d to %d"]:format(step, step + 1),
                MIGRATIONS[step], wrapper)
        end
    end

    -- Branches belonging to modules this build does not have. Keeping them
    -- would be harmless but invisible; naming them explains why a setting did
    -- not arrive. Clearing a key during pairs() is allowed; adding one is not.
    --
    -- Three keys of a profile are not modules, and all three stay: `modules`,
    -- every module's own switch, `pagesOff`, the switches of the pages that are
    -- not one module's, Gameplay's above all, and since format 9 `bars`. The
    -- second was dropped here as unknown until 2026-10-06, so an imported
    -- profile came back with its Gameplay page on.
    for key in pairs(data) do
        if not PROFILE_KEYS[key] and not self.modules[key] then
            skipped[#skipped + 1] = L["%s (no such module here)"]:format(key)
            data[key] = nil
        end
    end

    -- Whitelisted is not the same as checked: a bar's size, an entry pointing
    -- at a bar, a time of its own are values somebody could have edited into
    -- the string, so each is held against what the page itself could set.
    if self.Bars then self.Bars.Validate(data, skipped) end

    local base = self:ValidProfileName(payload.name) or "Imported"
    local name, suffix = base, 2
    while self.global.profiles[name] do
        name = base .. " (" .. suffix .. ")"
        suffix = suffix + 1
    end

    self.global.profiles[name] = data

    -- Paranoid, and this one line has earned it. Everything in FP.global only
    -- survives a reload because that table *is* _G.ForeverPlusDB, the one the
    -- client writes out. If they were ever different, a profile would appear in
    -- the list, work perfectly, and be gone at the next login with nothing
    -- having gone wrong anywhere visible. Checked where it would cost the most.
    if _G.ForeverPlusDB ~= self.global then
        self.global.profiles[name] = nil
        return nil, L["the settings being saved are not the ones in this "
            .. "table. The import was undone to prevent silent data loss. "
            .. "Please report this"]
    end

    -- Read back from the saved table by name, rather than trusting the write
    -- we just did. The whole failure being chased here is a profile that is in
    -- the list and not in the file, and this is the only moment where the two
    -- can still be compared.
    local saved = _G.ForeverPlusDB.profiles[name]
    if saved ~= data then
        return nil, L["the profile was not saved successfully. Please "
            .. "report this"]
    end

    return name, skipped, #self:ListProfiles()
end
