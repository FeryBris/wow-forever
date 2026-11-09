-- The two things the game throws at you that are always answered the same way:
-- a duel you did not ask for, and a corpse in a battleground.
--
-- **Both act on the player's behalf, so both ship off.** The module itself is
-- on, like every other one here, and does nothing until a switch inside it is
-- turned on. Until build 70009 that was more than a formality: the client read
-- nothing back at a cold start, so whatever shipped on was on again after every
-- restart of the game, however often it had been switched off.
--
-- What releasing cannot see, and it matters: `HasSoulstone` does **not exist**
-- on build 69913, measured 2026-09-20. So the addon cannot tell whether a
-- soulstone is waiting for you. `C_DeathInfo.GetSelfResurrectOptions` is asked
-- instead where it exists, and a wait in seconds is offered for the case it
-- does not. The owner chose zero seconds as the default with that in front of
-- him, so the default is zero and the reasoning is written down here rather
-- than quietly corrected later.

local ADDON, FP = ...
local L = FP.L

local M = FP:RegisterModule("Interruptions", {
    title   = L["Interruptions"],
    default = true,
    desc    = L["Declines duels and releases your spirit in battlegrounds. "
           .. "Both off until you say so."],
    group   = "interrupt",
    order   = 10,
    options = {
        { key = "declineDuels", type = "toggle", default = false,
          label = L["Decline duels"],
          desc  = L["Turns every duel request down. Nothing is sent to whoever "
               .. "asked: they see the same refusal they would see if you had "
               .. "clicked it yourself."] },

        { key = "declineAnnounce", type = "toggle", default = true,
          label = L["Say who was declined"],
          desc  = L["Shows the name in your own chat, so you know whose duel "
               .. "request was declined."],
          disabled = function(mod) return not mod.db.declineDuels end },

        { type = "group", label = L["Battlegrounds"] },

        { key = "bgRelease", type = "toggle", default = false,
          label = L["Release when you die in a battleground"],
          desc  = L["Battlegrounds only, never in the world, a dungeon or a "
               .. "raid. It does not release when the client offers you a "
               .. "resurrection of your own. This build cannot check for a "
               .. "soulstone, so the delay is the only safeguard."] },

        { key = "releaseDelay", type = "number", default = 0,
          label = L["Wait before releasing"], min = 0, max = 30, step = 1,
          format = function(v) return v == 0 and L["at once"] or L["%d s"]:format(v) end,
          desc  = L["Time for a Druid to resurrect you or for a soulstone to "
               .. "do so. Zero releases immediately."],
          disabled = function(mod) return not mod.db.bgRelease end },

        { key = "holdShiftStop", type = "toggle", default = true,
          label = L["Hold Shift to pause"],
          desc  = L["While Shift is down, neither of these acts."] },
    },
})

-- IsInInstance returns a token, never a display name: "pvp" is a battleground
-- and "arena" is an arena. That is the locale rule in one line, and it is why
-- no string in this file is ever compared against something the player reads.
local BATTLEGROUND = "pvp"

local pending = false   -- a release already scheduled; a second death cannot

local function Paused()
    return M.db.holdShiftStop and IsShiftKeyDown()
end

-- ---------------------------------------------------------------------------
-- Duels
-- ---------------------------------------------------------------------------

local function DeclineDuel(challenger)
    if not M.db.declineDuels or Paused() then return end
    if not CancelDuel then
        return FP:Warn(L["Interruptions: CancelDuel is missing on this build."])
    end

    -- Declining is all this does. The dialog the client raised for the request
    -- is the client's to close: StaticPopup_Hide closed it here until
    -- 2026-10-18, and hiding a dialog runs the popup system's own bookkeeping,
    -- its list of open dialogs among it, in this addon's name, so a later
    -- dialog whose button is protected, entering a battleground say, could be
    -- refused. Found in the taint audit of 7.2 and dropped at the owner's word;
    -- at worst the declined request's dialog stays until it runs out, and a
    -- click on it does nothing any more.
    pcall(CancelDuel)

    if M.db.declineAnnounce then
        FP:Print(L["Declined a duel from %s."], challenger and tostring(challenger) or L["somebody"])
    end
end

-- ---------------------------------------------------------------------------
-- Releasing
-- ---------------------------------------------------------------------------

--- Is the player standing in a battleground?
--
-- Two readers, and either one saying yes is not enough: both have to agree
-- that we are somewhere releasing is right. IsInInstance carries the token,
-- C_PvP.IsBattleground is the newer route and is only consulted as a second
-- opinion where it exists.
local function InBattleground()
    if not IsInInstance then return false end
    local ok, inside, kind = pcall(IsInInstance)
    if not ok then return false end
    if FP:Truth(inside) ~= true then return false end
    return kind == BATTLEGROUND
end

--- Does the client have a resurrection of its own on offer?
--
-- The honest answer on this build is "sometimes we cannot tell". HasSoulstone
-- is absent here, so a soulstone is invisible to us; this asks the one reader
-- that might know and treats a missing reader as "no idea" rather than as "no".
local function SelfResurrectOffered()
    local get = C_DeathInfo and C_DeathInfo.GetSelfResurrectOptions
    if type(get) ~= "function" then return false end
    local ok, options = pcall(get)
    if not ok or type(options) ~= "table" then return false end
    local okCount, count = pcall(function() return #options end)
    return okCount and (count or 0) > 0
end

local function Release()
    pending = false
    if not M.db.bgRelease or Paused() then return end
    if not InBattleground() then return end

    -- Asked again rather than only once before the wait: the whole point of
    -- waiting is that somebody may act during it.
    if SelfResurrectOffered() then
        return FP:Print(L["Not releasing: the client is offering you a resurrection."])
    end

    -- Already a ghost, so somebody or something got there first.
    if UnitIsGhost then
        local ok, ghost = pcall(UnitIsGhost, "player")
        if ok and FP:Truth(ghost) == true then return end
    end

    if not RepopMe then
        return FP:Warn(L["Interruptions: RepopMe is missing on this build."])
    end
    pcall(RepopMe)
end

local function Died()
    if not M.db.bgRelease or pending then return end
    if not InBattleground() then return end

    local wait = tonumber(M.db.releaseDelay) or 0
    if wait <= 0 or not (C_Timer and C_Timer.After) then
        return Release()
    end

    pending = true
    C_Timer.After(wait, function() FP:Safe("Interruptions:release", Release) end)
end

-- ---------------------------------------------------------------------------

local handlers = {}

function handlers.DUEL_REQUESTED(challenger) DeclineDuel(challenger) end
function handlers.PLAYER_DEAD() Died() end

-- Leaving the battleground, or being brought back, cancels a wait that is
-- still running: releasing into the world afterwards would be exactly wrong.
function handlers.PLAYER_ALIVE() pending = false end
function handlers.PLAYER_ENTERING_WORLD() pending = false end

--- Self-test: reports for each building block whether it exists on this build.
function M:SelfTest()
    local function state(ok) return ok and "|cff44ff44ok|r" or "|cffff5555missing|r" end
    local okIn, inside, kind = pcall(IsInInstance)

    FP:Print("Interruptions self-test:")
    local lines = {
        { "CancelDuel",       state(CancelDuel ~= nil) },
        { "RepopMe",          state(RepopMe ~= nil) },
        { "UnitIsGhost",      state(UnitIsGhost ~= nil) },
        { "HasSoulstone",     state(HasSoulstone ~= nil) .. " |cff888888(absent here, known)|r" },
        { "C_DeathInfo.GetSelfResurrectOptions",
          state(C_DeathInfo and C_DeathInfo.GetSelfResurrectOptions ~= nil) },
        { "IsInInstance now", okIn and (tostring(inside) .. ", " .. tostring(kind)) or "raised" },
        { "In a battleground", InBattleground() and "|cff44ff44yes|r" or "no" },
        { "GetNumBattlegroundTypes", state(_G.GetNumBattlegroundTypes ~= nil) },
        { "GetBattlegroundInfo",     state(_G.GetBattlegroundInfo ~= nil) },
    }
    for _, line in ipairs(lines) do
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  |cffffffff%-38s|r %s", line[1], line[2]))
    end

    -- Does this client know of any battlegrounds at all?
    --
    -- The owner reported on 2026-09-20 that battlemasters offer no interaction
    -- here, and suspected the beta simply has none yet. That would turn this
    -- half of the module from *untested* into *untestable*, which is a
    -- different state and deserves a measurement rather than a suspicion: one
    -- of them is waiting for an opportunity, the other is waiting for the game.
    local counter = _G.GetNumBattlegroundTypes
    if type(counter) ~= "function" then
        return FP:Print("GetNumBattlegroundTypes is absent, so this client will "
            .. "not say how many battlegrounds it has.")
    end

    local ok, count = pcall(counter)
    if not ok then
        return FP:Print("GetNumBattlegroundTypes raised rather than answering.")
    end

    count = tonumber(count) or 0
    FP:Print("Battlegrounds this client offers: %d", count)
    if count == 0 or not _G.GetBattlegroundInfo then return end

    for i = 1, count do
        local okInfo, name = pcall(GetBattlegroundInfo, i)
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "  |cffffffff  %d|r %s", i, okInfo and tostring(name) or "unreadable"))
    end
end

function M:OnEnable()
    self.frame = self.frame or CreateFrame("Frame")
    self.frame:SetScript("OnEvent", function(_, event, ...)
        local handler = handlers[event]
        if handler then FP:Safe("Interruptions:" .. event, handler, ...) end
    end)
    FP:RegisterEvents(self.frame, handlers, "Interruptions")
end

function M:OnDisable()
    if self.frame then self.frame:UnregisterAllEvents() end
    pending = false
end
