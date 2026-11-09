-- Takes the waiting out of looting, and rolls greed on greens if asked to.
--
-- Two features that look related and are not. One of them decides nothing and
-- one of them acts in front of other people, which is why their defaults and
-- their guards differ.
--
-- 1. **Fast loot only accelerates.** The client already loots for you when
--    autoLootDefault is set, and it spaces the slots out by autoLootRate,
--    measured at 150 on this build. That spacing is the only thing removed
--    here. Whether a corpse is looted automatically at all stays entirely with
--    the client's own setting and its own modifier key, because a second place
--    answering the same question leaves the player with two switches and no
--    way to know which one wins.
--
--    **And that is why fast loot has no Shift guard**, against the convention
--    every other automation here follows. Shift is usually the client's *own*
--    auto loot modifier: treating it as "hands off" would break the invert key
--    for anybody whose default is off. There is nothing to pause in any case,
--    since this decides nothing the client had not already decided.
--
-- 2. **Greed on greens is a real decision**: off by default, and it says what
--    it did. Quality 2 and nothing else, ever. A roll is visible to four other
--    people and cannot be taken back, which is the whole reason the default
--    is off. It weighed even more until build 70009, while this client read
--    nothing back at a cold start and whatever shipped on was on again after
--    every restart.
--
--    **No Shift pause either, since 2026-10-05**, the owner's call. It had
--    one, by the convention, and it could never be used: a roll appears when
--    somebody in the group loots a corpse, and nobody knows that moment in
--    advance to be holding Shift through it.

local ADDON, FP = ...
local L = FP.L

local M = FP:RegisterModule("Looting", {
    title   = L["Fast Auto Loot"],
    default = true,
    desc    = L["Loots without the delay, and can roll greed on greens."],
    group   = "loot",
    order   = 10,
    options = {
        { key = "fastLoot", type = "toggle", default = true,
          label = L["Loot without the delay"],
          desc  = L["Takes every slot at once instead of waiting for the "
               .. "client to process them one by one. It never decides "
               .. "whether to loot: that stays with your own auto loot "
               .. "setting and its modifier key, and this does nothing at "
               .. "all when the client was not going to loot."] },

        -- Blizzard's own auto loot, the setting fast loot follows. A button
        -- rather than something that happens by itself: pressing it once is
        -- enough, because the client stores that setting in its own
        -- configuration and remembers it. It says so in chat either way,
        -- including when it was already on. Usable while the module is off,
        -- `whileOff`, the owner's call of 2026-10-06: it works without it.
        { type = "action", label = L["Turn on Auto Loot"], whileOff = true,
          desc  = L["Turns on the game's own auto loot."],
          run   = function(mod) mod:EnableClientAutoLoot() end },

        { type = "group", label = L["Rolling"] },

        -- Green only: blue and better are never touched, and neither is need.
        -- Off by default because the roll is visible to the whole group and
        -- cannot be taken back. The hover says what it does and nothing of
        -- what it does not, the owner's word of 2026-10-05.
        { key = "greedGreens", type = "toggle", default = false,
          label = L["Roll greed on green items"],
          desc  = L["Rolls greed on every green item automatically."] },

        { key = "greedAnnounce", type = "toggle", default = true,
          label = L["Say what was rolled on"],
          desc  = L["Shows the item in your own chat. Nothing is sent to the "
               .. "group."],
          disabled = function(mod) return not mod.db.greedGreens end },
    },
})

local UNCOMMON = 2    -- Enum.ItemQuality.Uncommon. A number, never a name.
local GREED    = 2    -- RollOnLoot: 0 pass, 1 need, 2 greed, 3 disenchant.
local ROLL_TTL = 65   -- A roll runs 60 seconds at most. See `ours` below.

-- Rolls this module started, so a confirmation dialog is only answered for one
-- we are responsible for: somebody else's need roll is not ours to confirm.
--
-- Entries expire on a timer rather than on an event. LOOT_ROLLS_COMPLETE is a
-- later addition than this client and registering an event a build does not
-- know raises, so the tidy-up must not depend on one being there.
local ours = {}

-- ---------------------------------------------------------------------------
-- Fast loot
-- ---------------------------------------------------------------------------

--- Was the client going to loot this by itself?
--
-- The event carries the answer, which beats working it out: the modifier key
-- inverts the CVar and the client has already applied that. The CVar is only
-- the fallback for a build that does not pass the argument.
--
-- Never a bare `if value then` on either: a value from this client can be
-- secret, which survives tostring and raises on the first comparison.
local function ClientWouldLoot(fromEvent)
    -- "The event did not say" and "the event said no" are different answers,
    -- and FP:Truth reports both as false. So they are told apart here, before
    -- it is asked: without this the CVar fallback could never be reached on a
    -- build that passes no argument, and fast loot would simply never act.
    --
    -- Even the comparison against nil goes through pcall. A value from this
    -- client can be secret, and a secret raises the first time it is compared
    -- with anything at all.
    local readable, absent = pcall(function() return fromEvent == nil end)
    if readable and not absent then
        local said = FP:Truth(fromEvent)
        if said ~= nil then return said end
    end

    local get = (C_CVar and C_CVar.GetCVarBool) or _G.GetCVarBool
    if not get then return false end
    local ok, value = pcall(get, "autoLootDefault")
    return ok and FP:Truth(value) == true
end

--- Turns the client's own auto loot on, once, on request.
--
-- **Not done at login, and the reason changed on 2026-09-26.** The owner asked
-- for it to happen once at install. Until build 70009 that could not be built:
-- to do it *once* the addon has to remember that it did, the client read
-- nothing back at a cold start, and "at install" would have become "at every
-- login", with no switch able to stop it for longer than a session.
--
-- 70009 made it buildable, and the owner decided to keep the button anyway:
-- an addon somebody installs should not change their client's settings
-- without being asked. The owner's own client had auto loot on long before,
-- so building it would only ever have reached strangers.
--
-- Nothing is lost by it being manual either. The CVar belongs to the client,
-- which keeps it in its own configuration rather than in ours, so one press
-- holds and no enforcing is needed. That also keeps the module's own rule
-- intact: it accelerates what the client decided and never decides it again.
function M:EnableClientAutoLoot()
    local get = (C_CVar and C_CVar.GetCVarBool) or _G.GetCVarBool
    local set = (C_CVar and C_CVar.SetCVar) or _G.SetCVar
    if not set then
        return FP:Warn(L["Looting: this client offers no way to set a CVar."])
    end

    if get then
        local ok, value = pcall(get, "autoLootDefault")
        if ok and FP:Truth(value) == true then
            return FP:Print(L["The client's auto loot is already on, nothing changed."])
        end
    end

    if not pcall(set, "autoLootDefault", "1") then
        return FP:Warn(L["Looting: the client refused to set autoLootDefault."])
    end

    -- Read it back rather than trust the write. A CVar can be refused without
    -- raising, and then a message saying it worked would be the only evidence
    -- that it had not.
    local confirmed = false
    if get then
        local okRead, value = pcall(get, "autoLootDefault")
        confirmed = okRead and FP:Truth(value) == true
    end

    if not confirmed then
        return FP:Warn(L["Looting: autoLootDefault was set but does not "
            .. "report that it is on. Check the client's own options."])
    end
    FP:Print(L["The client's auto loot is now on. That is a client setting, so it "
        .. "stays on whether or not this addon is running."])
end

local function FastLoot(autoLoot)
    if not M.db.fastLoot then return end
    if not (GetNumLootItems and LootSlot) then
        return FP:Warn(L["Looting: the loot API is missing on this build."])
    end

    if not ClientWouldLoot(autoLoot) then
        -- Not a failure. Auto loot is off, or the key that inverts it is down,
        -- and either way the corpse is the player's to work through.
        return
    end

    local ok, slots = pcall(GetNumLootItems)
    if not ok or not slots or slots == 0 then return end

    -- Downwards, because looting a slot can renumber the ones behind it and a
    -- forward loop would then skip every second item.
    for slot = slots, 1, -1 do
        local has = true
        if LootSlotHasItem then
            local okSlot, value = pcall(LootSlotHasItem, slot)
            has = okSlot and FP:Truth(value) ~= false
        end
        if has then pcall(LootSlot, slot) end
    end
end

-- ---------------------------------------------------------------------------
-- Greed on greens
-- ---------------------------------------------------------------------------

local function RollItemLink(rollID)
    if not GetLootRollItemLink then return nil end
    local ok, link = pcall(GetLootRollItemLink, rollID)
    return ok and link or nil
end

local function StartRoll(rollID)
    if not M.db.greedGreens then return end
    if not (GetLootRollItemInfo and RollOnLoot) then
        return FP:Warn(L["Looting: the roll API is missing on this build."])
    end

    -- texture, name, count, quality, bindOnPickUp, canNeed, canGreed, ...
    local ok, _, name, _, quality, _, _, canGreed = pcall(GetLootRollItemInfo, rollID)
    if not ok then return end

    -- Exactly quality 2. Not "2 and below", not "up to 2": a threshold here
    -- would quietly grow into rolling on things nobody agreed to.
    if quality ~= UNCOMMON then return end
    if FP:Truth(canGreed) ~= true then return end

    ours[rollID] = true
    if C_Timer and C_Timer.After then
        C_Timer.After(ROLL_TTL, function() ours[rollID] = nil end)
    end
    pcall(RollOnLoot, rollID, GREED)

    if M.db.greedAnnounce then
        FP:Print(L["Rolled greed on %s."], RollItemLink(rollID) or name or L["a green item"])
    end
end

--- Some rolls ask again before they count. Answer only for our own.
local function ConfirmRoll(rollID, rollType)
    if not ours[rollID] then return end
    if ConfirmLootRoll then pcall(ConfirmLootRoll, rollID, rollType) end
end

-- ---------------------------------------------------------------------------

local handlers = {}

function handlers.LOOT_READY(autoLoot) FastLoot(autoLoot) end

-- LOOT_OPENED as well: which of the two a build fires first is not defined,
-- and the later one finds an emptied corpse rather than doing any harm.
function handlers.LOOT_OPENED(autoLoot) FastLoot(autoLoot) end

function handlers.START_LOOT_ROLL(rollID) StartRoll(rollID) end
function handlers.CONFIRM_LOOT_ROLL(rollID, rollType) ConfirmRoll(rollID, rollType) end

--- Self-test: reports for each building block whether it exists on this build.
function M:SelfTest()
    local function state(ok) return ok and "|cff44ff44ok|r" or "|cffff5555missing|r" end
    local get = (C_CVar and C_CVar.GetCVarBool) or _G.GetCVarBool
    local cvar = "?"
    if get then
        local ok, value = pcall(get, "autoLootDefault")
        cvar = ok and tostring(value) or "unreadable"
    end

    FP:Print("Looting self-test:")
    local lines = {
        { "GetNumLootItems",     state(GetNumLootItems ~= nil) },
        { "LootSlot",            state(LootSlot ~= nil) },
        { "LootSlotHasItem",     state(LootSlotHasItem ~= nil) },
        { "GetLootRollItemInfo", state(GetLootRollItemInfo ~= nil) },
        { "RollOnLoot",          state(RollOnLoot ~= nil) },
        { "ConfirmLootRoll",     state(ConfirmLootRoll ~= nil) },
        { "autoLootDefault",     cvar },
    }
    for _, line in ipairs(lines) do
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  |cffffffff%-22s|r %s", line[1], line[2]))
    end
end

function M:OnEnable()
    self.frame = self.frame or CreateFrame("Frame")
    self.frame:SetScript("OnEvent", function(_, event, ...)
        local handler = handlers[event]
        if handler then FP:Safe("Looting:" .. event, handler, ...) end
    end)
    FP:RegisterEvents(self.frame, handlers, "Looting")
end

function M:OnDisable()
    if self.frame then self.frame:UnregisterAllEvents() end
    wipe(ours)
end
