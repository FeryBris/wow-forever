--[[
    LootCore.lua - the Raidify_Loot sub-addon boundary

    This file is the FIRST thing Raidify_Loot loads, and everything else in the
    sub-addon depends on it succeeding. It exists because of plan §10.2: loot code
    must never be able to break the free core addon for the players who only ever
    wanted roster import and auto-invite.

    Three guarantees it provides:

    * SEPARATE PRODUCT. Raidify_Loot ships as its own addon with its own .toc and
      `## Dependencies: Raidify`. A player who does not install it loads not one line
      of loot code. This is the whole point — an inert module inside core is still
      code that can throw during core's event dispatch.

    * SEPARATE SAVED VARIABLES. Loot state lives in `RaidifyLootDB`, never in core's
      `RaidifyDB`. A corrupt loot table cannot take the player's roster and settings
      with it, and the companion app can watch one file without parsing the other.

    * VERSION HANDSHAKE. Core publishes `Raidify.APIVersion`. If the installed core
      is older or newer than this sub-addon understands, we self-disable with one
      readable line and touch nothing. Never a Lua error — a player who updated one
      addon and not the other gets an explanation, not a red wall.

    Everything the loot modules call on core goes through the global `Raidify` object
    (roster, import pipeline, theme, export helpers). That coupling is deliberate for
    now and documented in the pending `Raidify.API` surface spec (roadmap 2.A.1); this
    file is where it gets narrowed when that spec lands.
]]

local ADDON_NAME = "Raidify_Loot"

-- The core API contract this build was written against. Bump only when the surface
-- this sub-addon consumes actually changes shape.
local REQUIRED_API = 1

local core = _G.Raidify

-- Core absent entirely. `## Dependencies: Raidify` should make this unreachable, but
-- a player can disable the core addon in the character list without uninstalling it,
-- and that must not produce an error.
if not core then
    _G.RaidifyLootDisabled = "core-missing"
    if _G.RaidifyForever then
        -- World of Warcraft: Forever. This addon has no TOC for it any more, so it only gets here
        -- with "Load out of date AddOns" on; Raidify there has loot council built in.
        print("|cFFEAB444Raidify Loot|r: Raidify on World of Warcraft: Forever has loot council built in. You can remove Raidify Loot from this client.")
    else
        print("|cFFEAB444Raidify Loot|r: the Raidify addon is not enabled, so loot features stay off.")
    end
    return
end

local coreApi = tonumber(core.APIVersion or 0) or 0
if coreApi ~= REQUIRED_API then
    _G.RaidifyLootDisabled = "api-mismatch"
    core.lootDisabledReason = "api-mismatch"
    print(("|cFFEAB444Raidify Loot|r: needs Raidify API v%d but found v%s. Update both addons to the same release; loot features stay off until then.")
        :format(REQUIRED_API, tostring(core.APIVersion or "none")))
    return
end

-- ── saved variables ──────────────────────────────────────────────────────────
--
-- Deliberately a plain table rather than an AceDB profile: the companion app
-- file-watches this SavedVariables file and a flat shape is far cheaper to parse
-- than AceDB's profile/char/realm indirection. Defaults are merged on load so a
-- new key never reads nil on an existing install.

local DEFAULTS = {
    -- Minimum item quality a loot session queues for the council.
    -- 0 Poor, 1 Common, 2 Uncommon, 3 Rare, 4 Epic, 5 Legendary. Epic by default —
    -- councils do not deliberate over greens — but a guild in a fresh tier where
    -- blues still matter can lower it.
    lootQualityThreshold = 4,

    -- Announce each award to raid chat.
    --
    -- ON. It shipped off as "broadcasting into a guild's raid chat is intrusive", which
    -- is true of a chatty addon and not true of this: one line per award, naming the item
    -- and the winner, at the moment the decision is made. That is the cheapest answer the
    -- product has to "why did he get it", and it reaches the twenty-four people who will
    -- never open the website.
    --
    -- A guild that finds it noisy unticks it after one raid. A guild that never discovers
    -- the setting never gets the benefit, and off-by-default made that the common case.
    announceLootAwards = true,

    -- Announce to raid chat when a loot payload is imported, and therefore that lists
    -- are now fixed for the night.
    --
    -- ON by default, unlike the award announcer above, because it is the opposite kind
    -- of message. That one repeats all night and duplicates what people can already see
    -- in the loot frame; this one fires once and is the only notice a raider ever gets
    -- that the lists being weighed tonight are the ones taken at this moment. A raider
    -- who edits their wishlist after the pull would otherwise believe it counted --
    -- the server refuses the edit, but silence at the moment of import is what makes
    -- them try in the first place.
    announceLootImport = true,

    --[[
        Put awarded items into the trade window when a trade opens with the winner.

        OFF by default, and that is a pilot decision rather than a permanent one. This is
        the only setting in the addon whose code can do something destructive: it calls
        UseContainerItem, and "using" a container item with no trade window open equips the
        armour or drinks the potion. Every guard is in place and none of them has run in a
        real client yet.

        So the first raid a volunteer guild runs is safe by default, and turning it on is a
        deliberate act by someone who knows they are testing it. Flip the default once it
        has survived contact with real trades.

        Turned off, the addon still says who is owed what when a trade opens — which is
        most of the value and none of the risk.
    ]]
    autoFillTrades = false,

    --[[
        Hide everyone else's standing from the candidate card.

        The card shows each candidate's attendance percentage and days since their last
        mainspec item — a sorted personnel ranking of the whole raid, on screen, every time
        a boss dies. That is exactly what an officer needs and exactly what nobody else in
        the guild should be reading over their shoulder.

        It matters because officers screenshare. A drop gets shown in Discord to settle a
        question, and twenty-four people see who the addon thinks has the worst attendance.
        Names and items stay; only the numbers that rank people go.

        OFF by default: the numbers are shown.

        This has now been argued both ways and the second argument won. Hiding was chosen
        because an officer cannot predict, before their first raid, that they will later
        screenshare a drop, and that exposure is one-way and public. True. But it hid the
        two figures that survive everything else: attendance and days-since-last-win are
        still meaningful in week ten, when half the wishlists have gone stale, and they are
        the numbers a council actually argues over. Shipping the durable half hidden made
        the card weakest exactly where it lasts longest.

        The privacy concern is answered by naming the control rather than by the default.
        "Streamer mode" is a thing an officer looks for when they start streaming; "hide
        attendance and loot history on the drop card" is a thing they find afterwards.
    ]]
    hideStandingOnCard = false,
}

--[[
    One-time migration out of core's profile.

    Up to core v1.8.8 the loot files lived inside the core addon and stored these two
    keys in `RaidifyDB`'s AceDB profile. Anyone who ran `/rf loot threshold 3` back
    then would silently get 4 back after the split, which is the kind of small
    betrayal that makes people distrust an update. So: copy the old values across
    once, mark it done, and never look again.

    The old keys are left in place rather than deleted — AceDB tolerates unknown keys,
    and removing data during a migration buys nothing but risk if someone downgrades.
]]
local function migrateFromCoreProfile(db)
    if db.migratedFromCore then return end
    db.migratedFromCore = true

    local profile = core.db and core.db.profile
    if type(profile) ~= "table" then
        -- Core's AceDB isn't up yet. Leave the marker unset so a later call retries.
        db.migratedFromCore = nil
        return
    end

    for key in pairs(DEFAULTS) do
        if profile[key] ~= nil and db.settings[key] == nil then
            db.settings[key] = profile[key]
        end
    end
end

local function ensureDb()
    if type(_G.RaidifyLootDB) ~= "table" then
        _G.RaidifyLootDB = {}
    end
    local db = _G.RaidifyLootDB
    if type(db.settings) ~= "table" then db.settings = {} end

    -- Before defaults: a migrated value must win over a default, not lose to one.
    migrateFromCoreProfile(db)

    --[[
        Re-take the privacy default, once.

        `hideStandingOnCard` was flipped to ON because officers screenshare drops and cannot
        predict, before their first raid, that they will. But defaults only fill keys that
        are nil, and every install from the previous build has an explicit `false` stored -
        so the flip reached exactly nobody who already had the addon, and the Loot page
        rendered an unchecked box under a hint reading "On by default".

        One-way and versioned: it clears a stored `false` so the default can apply, and never
        runs again. An officer who deliberately unchecks it afterwards keeps that choice.
    ]]
    if not db.standingDefaultV2 then
        db.standingDefaultV2 = true
        if db.settings.hideStandingOnCard == false then
            db.settings.hideStandingOnCard = nil
        end
    end

    --[[
        Re-take two defaults, once, for the same reason V2 existed.

        The loop below WRITES defaults into storage rather than leaving them absent, so
        every install carries an explicit value for every key. Changing a default therefore
        reaches nobody who already has the addon: the key is not nil, so the new value never
        applies. V2 hit this and had to clear the stored value to let the flip land.

        Two flips this time, both from the raider panel:
          hideStandingOnCard  true  -> nil, so the numbers show and the control becomes
                                       streamer mode rather than a privacy default.
          announceLootAwards  false -> nil, so awards are announced in raid chat.

        One-way and versioned. It clears only the value that matches the OLD default, so an
        officer who deliberately set the opposite keeps their choice, and it never runs
        again. Anyone who changes either setting after this update keeps that too.
    ]]
    if not db.panelDefaultsV3 then
        db.panelDefaultsV3 = true
        if db.settings.hideStandingOnCard == true then
            db.settings.hideStandingOnCard = nil
        end
        if db.settings.announceLootAwards == false then
            db.settings.announceLootAwards = nil
        end
    end

    for key, value in pairs(DEFAULTS) do
        if db.settings[key] == nil then
            db.settings[key] = value
        end
    end
    return db
end

-- ── the sub-addon namespace ──────────────────────────────────────────────────

local Loot = {}
core.Loot = Loot

Loot.version = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(ADDON_NAME, "Version") or "unknown"

function Loot:Db()
    return ensureDb()
end

function Loot:GetSetting(key)
    local db = ensureDb()
    local value = db.settings[key]
    if value == nil then return DEFAULTS[key] end
    return value
end

function Loot:SetSetting(key, value)
    local db = ensureDb()
    db.settings[key] = value
    return value
end

--[[
    Wrap anything that runs off a game event.

    An unprotected error inside a handler registered on the shared `Raidify` Ace3
    object surfaces as an error in core Raidify — exactly the blast radius §10.2
    forbids. Every entry point the game can call into (LOOT_OPENED, slash commands,
    UI callbacks) goes through here, so the worst case is a printed line and a
    dead loot action rather than a broken addon.
]]
--[[
    Keep failures, do not just mention them.

    Chat is where an error goes to die. It prints once, scrolls away inside a minute, and
    the person who saw it is tanking. When this runs in someone else's raid the entire
    diagnostic that comes back is "it broke at some point", which is not enough to fix
    anything.

    So every failure is written to SavedVariables with the time, what was running, and the
    stack — recoverable after the raid, by someone who was not there. /rf loot report puts
    it in a copyable window.

    Capped, because an error inside a repeating handler would otherwise write a line every
    tick until the disk complained. The FIRST errors are kept rather than the last: the one
    that started the cascade explains the twenty that followed, and the twentieth explains
    nothing.
]]
local MAX_STORED_ERRORS = 25

function Loot:RecordError(label, err)
    local db = ensureDb()
    db.errors = db.errors or {}

    if #db.errors >= MAX_STORED_ERRORS then return end

    local session = core.lootSession
    table.insert(db.errors, {
        at = time(),
        label = label,
        message = tostring(err),
        stack = debugstack and debugstack(3, 6, 0) or nil,
        version = self.version,
        -- What the addon was holding at the time. A failure with an empty queue and one
        -- with forty items in it are rarely the same failure.
        state = session and string.format("session=%s queue=%d awards=%d",
            tostring(session.active), #(session.queue or {}), #(session.awards or {})) or "no session",
    })
end

function Loot:Safe(label, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        self:RecordError(label, err)

        -- One line, once — a repeating handler must not spam a raid's chat frame.
        if not self._reported then self._reported = {} end
        if not self._reported[label] then
            self._reported[label] = true
            print(("|cFFEAB444Raidify Loot|r: %s failed and was skipped. "
                .. "|cFFD3A96FRun /rf loot report after the raid and send it to us.|r"):format(label))
        end
        return nil
    end
    return err
end

--[[
    Does this guild use loot at all?

    Not every guild that installs the addon runs a loot council, and nothing loot-shaped
    should occupy a pixel of screen for the ones that do not. That rules out the obvious
    signal: `core.lootData` is deliberately NOT persisted — it is raid-scoped and
    regenerated from the web in seconds — so it is nil on every fresh login until someone
    imports, and an indicator keyed off it would flicker in and out between sessions.

    So it is a stored flag, set the first time a guild does something that only a loot
    guild does: import loot data, or start a session. Never cleared. A guild that ran loot
    last tier is still a loot guild in the eleven weeks before the next one.
]]
--[[
    Something about loot changed — redraw whatever is on screen.

    THE PROBLEM THIS FIXES. The Loot page refreshed on a ten-second ticker and on nothing
    else. Award an item from the card, watch a drop queue, take over a session: the page
    sat there showing the state from up to ten seconds ago, and an officer comparing what
    they had just done against what the page said concluded the addon had lost it or
    duplicated it. A screen that is usually right is worse than one that is obviously
    stale, because it gets believed.

    The ticker stays, but only for what it is actually for: counting a clock down. Every
    change now says so explicitly, the moment it happens.

    Coalesced to the end of the frame. Queueing four items off one corpse is four calls
    describing one new state, and redrawing per item would rescan bags four times for a
    screen nobody saw in between.
]]
local notifyQueued = false

function Raidify:NotifyLootChanged()
    if notifyQueued then return end
    notifyQueued = true

    local function flush()
        notifyQueued = false
        Loot:Safe("loot ui refresh", function()
            -- Only when someone can see it. The Loot page rescans bags to price the trade
            -- clocks, and activePage outlives closing the window, so an unguarded refresh
            -- did that work for a hidden screen on every bag update. Opening the window
            -- refreshes the active page anyway.
            local visible = Raidify.IsMainWindowShown == nil or Raidify:IsMainWindowShown()
            if visible and Raidify.RefreshCurrentPage then Raidify:RefreshCurrentPage() end

            -- The dashboard is a separate always-on widget and does its own dirty-marking.
            if Raidify.RefreshDashboard then Raidify:RefreshDashboard() end
        end)
    end

    if C_Timer and C_Timer.After then C_Timer.After(0, flush) else flush() end
end

function Loot:MarkUsed()
    local db = ensureDb()
    if db.usesLoot then return end
    db.usesLoot = true
end

function Loot:UsesLoot()
    return ensureDb().usesLoot == true
end

--[[
    Everything core needs to draw an indicator, in one call.

    Core must never reach into the sub-addon's internals — it has to keep working when the
    sub-addon is absent, which is the whole point of the split. So this is the only surface
    core touches, and core guards it with `if Raidify.Loot and Raidify.Loot.GetState`.

    Returns nil when there is nothing worth showing, which is the answer for every guild
    that does not use loot. A nil return means "draw nothing", not "draw a zero".
]]
function Loot:GetState()
    -- Test mode counts as a reason to draw, but must never call MarkUsed: looking at the
    -- feature is not using it, and a flag set by curiosity would follow the guild forever.
    local testing = core.IsTestMode and core:IsTestMode()
    if not testing and not self:UsesLoot() then return nil end

    local session = core.lootSession
    local queued, awarded = 0, 0
    if session then
        queued = type(session.queue) == "table" and #session.queue or 0
        awarded = type(session.awards) == "table" and #session.awards or 0
    end

    return {
        active = session ~= nil and session.active == true,
        -- Ended but not yet sent. The officer still has work to do, and this is the only
        -- thing on screen that will tell them so.
        unexported = session ~= nil and not session.active
            and awarded > 0 and not session.exportedAt,
        queued = queued,
        awarded = awarded,
        -- Whether there is a card to reopen. Closing it is currently a dead end.
        hasCard = core.lootWindow ~= nil and core.lootWindow.itemId ~= nil,
    }
end

-- ── session persistence ──────────────────────────────────────────────────────
--
-- The live session used to exist only in memory, so a /reload or a crash mid-raid
-- lost the entire queue and award ledger. That defeats both the crash-recovery
-- design (§5.2) and the companion's end-raid ingest (§5.4), which reads the session
-- out of SavedVariables precisely because that is the only thing a reload preserves.

function Loot:SaveSession(session)
    local db = ensureDb()

    --[[
        Never write a seeded session to disk.

        SaveLootData has refused fabricated payloads since the day it was written. This did
        not, and that asymmetry was the bug: a seeded session persisted, login recovery
        restored it, StartLootSession resumed it, and the real night that followed was
        stamped isTest and refused to export. Fabricated data must not survive a logout in
        either shape, and clearing on the way past also cleans up anything an older build
        left behind.
    ]]
    if session and session.isTest then
        db.session = nil
        db.sessionSavedAt = nil
        if Raidify.NotifyLootChanged then Raidify:NotifyLootChanged() end
        return
    end

    db.session = session
    db.sessionSavedAt = time()

    -- Every mutation to a session already ends here, which makes this the one place that
    -- cannot be forgotten. Redrawing per call sites was how the Loot page ended up stale
    -- after an award: the save was remembered and the refresh was not.
    if Raidify.NotifyLootChanged then Raidify:NotifyLootChanged() end
end

--[[
    Nights that have been exported and may not have reached the website yet.

    WHY A LIST. `db.session` holds one session. Starting the next one replaces it, so an
    officer who raids Tuesday and Wednesday without opening the companion in between used
    to lose Tuesday outright — the string was shown once, in a window, and never written
    down. Attendance never had this problem because it keeps a night per character.

    WHY THE ADDON PRUNES IT AND NOT THE COMPANION. The companion only ever reads this file;
    WoW owns every write to it, and anything written from outside is overwritten on the
    next logout. So this cannot be a queue the uploader drains. It is a bounded window of
    recent nights, and the companion tracks on its own side which ones it has already sent.

    Bounded at 10: more than a fortnight of raiding for anyone who uploads occasionally,
    and small enough that a saved-variables file stays a saved-variables file.
]]
local MAX_PENDING_EXPORTS = 10

function Loot:RememberPendingExport(export, session, awardCount)
    if type(export) ~= "string" or export == "" then return end

    local db = ensureDb()
    db.pendingExports = db.pendingExports or {}

    local nightId = session and session.nightId or nil

    -- Re-exporting the same night replaces its entry rather than adding a second one.
    -- `/rf loot export` can legitimately be run again on an ended session, and two copies
    -- of one night is exactly the duplicate this whole mechanism exists to prevent.
    if nightId then
        for index, entry in ipairs(db.pendingExports) do
            if entry.nightId == nightId then
                table.remove(db.pendingExports, index)
                break
            end
        end
    end

    table.insert(db.pendingExports, 1, {
        nightId = nightId,
        exportedAt = time(),
        startedAt = session and session.startedAt or nil,
        endedAt = session and session.endedAt or nil,
        awards = awardCount or 0,
        payload = export,
    })

    while #db.pendingExports > MAX_PENDING_EXPORTS do
        table.remove(db.pendingExports)
    end

    if Raidify.NotifyLootChanged then Raidify:NotifyLootChanged() end
end

--[[
    Keep the imported payload across a logout.

    It used to be memory-only, on the reasoning that it is raid-scoped and can be
    regenerated from the website in seconds. That holds at a desk and fails in the case it
    actually matters: a disconnect at 21:40. The session recovered fine — awards, queue,
    attendance — while every wishlist, priority and rule vanished, so the card came back
    showing unranked names and the officer had to alt-tab, regenerate the string and paste
    it again with the raid waiting.

    "Regenerated in seconds" is true of the generating. It is not true of doing it in the
    middle of a boss fight.

    Test data is never written. Fabricated wishlists surviving into a real session would be
    indistinguishable from a real import to everything downstream.
]]
function Loot:SaveLootData(data)
    local db = ensureDb()

    if not data or data.isTestData then
        db.lootData = nil
        db.lootDataSavedAt = nil
        return
    end

    db.lootData = data
    db.lootDataSavedAt = time()
end

function Loot:LoadLootData()
    return ensureDb().lootData
end

--[[
    Who this client is, for the session's owner stamp.

    RaidifyLootDB is account-wide on purpose, so an officer's threshold and auto-trade
    settings follow them to whichever character they happen to raid on. The SESSION cannot
    be, and was: one slot shared by every character on the account meant a crash on a main
    and a relog on an alt handed the alt the main's session. The next corpse the alt looted
    was appended to the main's awards, SampleRaidPresence mixed the alt's raid into the
    main's attendance, and the export sent the pair as one night with one startedAt.

    Realm is included because character names are only unique within one.
]]
function Loot:CharacterKey()
    local name = UnitName and UnitName("player")
    if not name then return nil end
    local realm = GetRealmName and GetRealmName() or ""
    return realm ~= "" and (name .. "-" .. realm) or name
end

function Loot:LoadSession()
    local db = ensureDb()
    return db.session
end

function Loot:ClearSession()
    local db = ensureDb()
    db.session = nil
    db.sessionSavedAt = nil
    if Raidify.NotifyLootChanged then Raidify:NotifyLootChanged() end
end

-- ── slash command delegation ─────────────────────────────────────────────────
--
-- Core owns `/rf` and forwards anything starting with "loot" to us. When the
-- sub-addon is absent core prints an install hint instead, so `/rf loot` never
-- errors on a core-only install.

function core:HandleLootCommand(input)
    return Loot:Safe("loot command", function()
        if input == "loot" then
            self:PrintLootSummary()
        elseif input:match("^loot%s+show%s+%d+$") then
            self:ShowLootCandidates(input:match("(%d+)$"))
        elseif input == "loot start" then
            self:StartLootSession(false)
        elseif input == "loot start force" then
            self:StartLootSession(true)
        elseif input == "loot end" then
            self:EndLootSession()
        elseif input == "loot queue" then
            self:PrintLootQueue()
        elseif input == "loot next" then
            self:ShowNextLootItem()
        elseif input == "loot done" then
            self:ResolveCurrentLootItem()
        elseif input:match("^loot%s+threshold%s+%d$") then
            self:SetLootQualityThreshold(tonumber(input:match("(%d)$")))
        elseif input == "loot threshold" then
            self:SetLootQualityThreshold(nil)
        elseif input == "loot report" then
            self:ShowLootReport()
        elseif input == "loot report clear" then
            self:ClearLootReport()
        elseif input == "loot debug" then
            self:DebugLootSlots()
        elseif input == "loot export" then
            self:ExportLootSession()
        elseif input == "loot test" then
            self:SeedTestLootSession()
        elseif input == "loot sim" then
            self:SimulateLootDrop(nil)
        elseif input:match("^loot%s+sim%s+%d+$") then
            self:SimulateLootDrop(tonumber(input:match("(%d+)$")))
        else
            print("|cFFEAB444Raidify Loot|r: unknown loot command. Try /rf loot, /rf loot start, /rf loot queue, /rf loot export.")
            print("  |cFF7F888BWith test mode on, /rf loot test fills a session with sample data.|r")
        end
    end)
end

-- ── recover an interrupted session ───────────────────────────────────────────
--
-- SavedVariables are not populated when this file executes, so recovery waits for
-- PLAYER_LOGIN. Own frame rather than core's event bus: an error here must not
-- reach core's dispatch, and the sub-addon should not be adding registrations to
-- the shared Ace3 object during load.
--
-- A session found still `active` means the client reloaded or crashed mid-raid.
-- We restore the queue and awards but leave the session inactive: re-arming
-- LOOT_OPENED silently after a crash would surprise whoever reloaded, and the
-- officer can resume deliberately. The awards are the part that must not be lost.

local recovery = CreateFrame("Frame")
recovery:RegisterEvent("PLAYER_LOGIN")
recovery:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")

    -- The payload first: a recovered session whose candidates have no ranks is only half
    -- a recovery, and the card reads lootData the moment it opens.
    Loot:Safe("loot data recovery", function()
        local saved = Loot:LoadLootData()
        if type(saved) == "table" and not core.lootData then
            core.lootData = saved
        end
    end)

    Loot:Safe("session recovery", function()
        local saved = Loot:LoadSession()
        if type(saved) ~= "table" then return end

        --[[
            Refuse a seeded session outright.

            SaveSession no longer writes these, but an earlier build did, so a client that
            has already been used for a look-around is carrying one right now. Restoring it
            would hand the next raid night a session that silently absorbs real awards and
            then refuses to export them.
        ]]
        if saved.isTest then
            Loot:ClearSession()
            return
        end

        local awards = type(saved.awards) == "table" and #saved.awards or 0
        local queued = type(saved.queue) == "table" and #saved.queue or 0
        if awards == 0 and queued == 0 then return end

        --[[
            A session belongs to the character that started it.

            Checked after the empty test so an alt is never nagged about a session with
            nothing in it, and it names the character rather than just refusing: the officer
            needs to know where their night went, not merely that it is not here.

            A session with no owner predates this stamp. Adopting it matches the old
            behaviour rather than stranding a real night on an upgrade, and it gets stamped
            on the way through so it can only ever happen once.
        ]]
        local me = Loot:CharacterKey()
        if saved.owner and me and saved.owner ~= me then
            print(("|cFFEAB444Raidify Loot|r: a loot session from |cFFEAB444%s|r is still waiting to be exported. Log in on that character to send it.")
                :format(saved.owner))
            return
        end
        if not saved.owner then saved.owner = me end

        local wasActive = saved.active
        saved.active = false
        core.lootSession = saved

        if wasActive then
            print(("|cFFEAB444Raidify Loot|r: recovered an interrupted session — %d awarded, %d queued. /rf loot queue to review, /rf loot export to send it to the site.")
                :format(awards, queued))
        end
    end)
end)

--[[
    The one failure that cannot be recovered.

    Forgetting `/rf loot export` is already self-healing — StartLootSession refuses to open
    a new session over an ended, unexported one, so the night waits in SavedVariables until
    somebody sends it, for days if necessary.

    Forgetting `/rf loot start` is not. With no session, LOOT_OPENED is never registered at
    all, nothing inspects the corpse, and there is nothing to recover afterwards. The loot
    is handed out, the night happens, and the record simply does not exist. No UI fixes
    that, because the officer never knows to look.

    So: one line, once per session of the game client, the first time loot is opened with no
    session running. Deliberately not a popup — this fires while a raid leader is standing
    over a boss corpse with twenty-four people waiting, which is the worst possible moment
    for something modal. Deliberately not repeated — a reminder that fires on every corpse
    is an addon people disable.

    Gated four ways so it can never reach a guild — or a moment — this does not apply to:
      * the guild has used loot before (MarkUsed), so a guild that never touches the
        feature never sees this line even once;
      * the player is in a raid, because a loot session records a raid night and nothing
        else. HasLootAuthority deliberately answers true outside a raid so the feature can
        be tested solo, so it cannot stand in for this check: without it, an officer whose
        guild uses loot got this line for skinning a boar while questing alone;
      * the player could actually start a session (leader, assistant or master looter);
      * it has not already fired this session.
]]
local nudge = CreateFrame("Frame")
local nudged = false

local function RemindToStart()
    if nudged then return end

    Loot:Safe("session reminder", function()
        if not Loot:UsesLoot() then return end
        if not IsInRaid() then return end

        local session = core.lootSession
        if session and session.active then return end

        -- Someone who cannot start one does not need telling. In a guild running loot,
        -- everyone but the leader would otherwise get this line on the first corpse.
        if core.HasLootAuthority and not core:HasLootAuthority() then return end

        nudged = true
        print("|cFFEAB444Raidify Loot|r: |cFFD3A96Fno session is running, so nothing is being "
            .. "recorded.|r /rf loot start to begin one.")
    end)
end

--[[
    Entering combat in a raid is the earliest honest signal that the night has started.

    The first corpse is too late to be much use: by then a pack is already dead and whatever
    dropped off it was never queued. There is nothing to recover at that point, which is
    exactly what makes this the one reminder worth having. Same flag and same gates as the
    loot trigger, so an officer still sees it at most once per client session.
]]
nudge:RegisterEvent("PLAYER_REGEN_DISABLED")
nudge:RegisterEvent("LOOT_OPENED")
nudge:SetScript("OnEvent", function()
    RemindToStart()
end)

core.lootModuleLoaded = true
