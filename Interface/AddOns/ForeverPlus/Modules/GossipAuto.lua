-- Clicks the line some NPCs put in front of their shop.
--
-- The whole difficulty is telling that line apart from one that starts an
-- escort, pulls a boss or triggers an event. The owner asked exactly that when
-- he proposed the feature, and the answer was supposed to be easy: a gossip
-- option carries a *type*, everything dangerous is a plain gossip line, and a
-- shop is a vendor line.
--
-- **On build 69913 the type is gone.** Measured 2026-09-20 at a vendor whose
-- window does carry the extra click, `C_GossipInfo.GetOptions()` returns
-- `flags`, `gossipOptionID`, `icon`, `name`, `orderIndex`, `rewards`,
-- `selectOptionWhenOnlyOption`, `status`, and nothing else. The route that
-- preceded it is gone too: `GetGossipOptions` and `GetNumGossipOptions` are
-- both absent, so `#GetOptions()` is the only count there is.
-- `Enum.GossipNpcOption` does exist with all seventy values, so the client
-- knows the concept perfectly well. It simply does not put it on the option.
--
-- What is left is the **icon**, a file id, and that is weaker than a type: the
-- server could in principle hang a vendor icon on something else. So the list
-- below is an allow list that only ever grows by measurement, an unknown icon
-- is never clicked, and the other two guards carry the real weight:
--
--   1. the icon is one we have measured,
--   2. it is the **only** option in the window,
--   3. **no quest** is attached, offered or ready to hand in, which also keeps
--      the two quest modules' precedence intact.
--
-- Plus Shift, as everywhere.
--
-- **Guard 2 will one day look like a bug, and it is not.** Measured 2026-09-20
-- at two class trainers: in a starting area the window has one option, training,
-- and is skipped. For a character who has talents it has two, training and
-- "I wish to unlearn my class or legacy talents", and nothing is skipped. So
-- the convenience quietly stops working at class trainers as a character levels
-- up, and it stops for precisely the right reason, because the second line is
-- one of the four that must never be clicked.
--
-- The obvious repair, skipping when exactly one of several options is a known
-- service, is the variant the owner was offered during the grilling and turned
-- down. It is not a fix for this. It is the thing this guard exists to prevent.
--
-- One thing this cannot use, although it looks made for the job:
-- `selectOptionWhenOnlyOption` is the client's own field for this exact
-- question, and at the one NPC where the feature would have helped it reads
-- `false`. That is the server saying do not skip this. Following it means doing
-- nothing, everywhere.

local ADDON, FP = ...
local L = FP.L

-- **Must be false in any released build.** The owner's decision, 2026-09-20:
-- collecting exists to find out what the icons mean on *his* client, and a
-- stranger who downloads this should neither be told about it nor have it
-- written into their saved file. He asked for it to be switched off at every
-- release, even if only for that release.
--
-- One constant rather than a note, because a note gets read after the upload.
-- It gates the writing *and* the chat line, so flipping it here is enough and
-- no half of it can be left on by accident. Step 7 of *Releasing* in AGENTS.md
-- says the same thing, on the theory that a rule living in exactly one place
-- is a rule that eventually ships.
local COLLECTING = false   -- off for release, see AGENTS.md step 7

-- The switch for saying that an unfamiliar service turned up, which means
-- something only while COLLECTING is on. Left off the page otherwise rather
-- than shown grayed out, the owner's call of 2026-10-05: a row nobody can ever
-- switch on only raises the question why, and its hover blamed another
-- setting that does not exist.
local LEARNING = {
    key = "announceLearned", type = "toggle", default = true,
    label = L["Say when an unfamiliar service turns up"],
    desc  = L["Nothing is clicked in that case. The line tells you the addon "
         .. "encountered an unfamiliar service, and the details are saved so "
         .. "the list can be expanded deliberately. Once per kind of "
         .. "service, not once per NPC."],
}

local M = FP:RegisterModule("GossipAuto", {
    title   = L["Skip Gossip"],
    default = true,
    desc    = L["Clicks past the extra line of talk at vendors, trainers, "
            .. "flight masters, bankers and guild masters."],
    group   = "npc",
    order   = 30,
    options = {
        { key = "announceClick", type = "toggle", default = false,
          label = L["Say every time a line is clicked"],
          desc  = L["Writes a line in your chat each time the addon clicks a "
               .. "gossip line for you."] },

        { key = "holdShiftStop", type = "toggle", default = true,
          label = L["Hold Shift to pause"],
          desc  = L["While Shift is down, nothing is clicked, so you can "
               .. "read what the NPC actually says. Hold Shift and talk "
               .. "again to check whether the addon was skipping a window "
               .. "for you."] },
    },
})

-- First on the page while measuring, where it always stood. Added before any
-- profile is bound or any page is built, both of which happen after login.
if COLLECTING then table.insert(M.options, 1, LEARNING) end

-- Icon file ids that are safe to click, each one **measured on this client**,
-- never taken from memory or from another build. Growing this list is a matter
-- of reading ForeverPlusDB.gossipIcons and classifying what turned up there.
--
-- The list began as a single point, one vendor option carrying 132060, and
-- "132060 means vendor" was an inference from it rather than a fact. It held.
-- Four sightings on 2026-09-20 across four NPCs settled it: every vendor line
-- carries 132060 and every trainer line 132058, although the wording they use
-- has nothing in common, down to one Warlock trainer saying "I submit myself
-- for further training my master". **The icon follows the service, not the
-- text**, which is also what makes the whole approach survive a client in
-- another language.
--
-- Every click is still written to ForeverPlusDB.gossipClicked, because the
-- model being right so far is not the same as it being right everywhere.
--
-- Deliberately absent, and they must stay absent even once their icons are
-- known: the spirit healer, because behind it is a resurrection with sickness;
-- the innkeeper, because behind it is the player's hearthstone; the
-- battlemaster; and talent unlearning.
local ALLOWED = {
    -- The first two were each seen at more than one NPC with wording that has
    -- nothing in common, which is what makes an entry about the service rather
    -- than about the text.
    [132060] = "vendor",    -- "I would like to buy from you."  Jeremiah Payson
                            -- "Show me your selection of grimoires."  Gina Lang
    [132058] = "trainer",   -- "Train me."  Shelene Rhobart, William Pickman,
                            --   Nurse Neela
                            -- "I submit myself for further training my master."
                            --   Rupert Boch
    [132057] = "taxi",      -- "I need a ride."  Michael Garrett
    [132055] = "petition",  -- "How do I form a guild?"  Christopher Drakul
    [132050] = "bank",      -- "I would like to check my deposit box."  the
                            --   banker in Orgrimmar, the only line, 2026-09-27
}

-- What a click opened, one whole sentence per service rather than a word put
-- into one: German wants the article with the noun, "den Händler", "die Bank".
local OPENED = {
    vendor   = L["Opened the vendor for you."],
    trainer  = L["Opened the trainer for you."],
    taxi     = L["Opened the taxi for you."],
    petition = L["Opened the petition for you."],
    bank     = L["Opened the bank for you."],
}

-- Services that were agreed for this list and will never reach it, because on
-- this client they have **no gossip step at all**: their window opens the
-- moment you talk to them, so there is no line to click past and nothing for
-- this module to do.
--
--     auctioneer   Auctioneer Epitwee, 2026-09-20, and again on 2026-09-27
--                  on build 70009: the owner reports every auctioneer opening
--                  its window directly
--     tabard       2026-09-20
--
-- **The banker was on that list and is not any more.** Measured with no
-- gossip step on 2026-09-20, on build 69913; on 2026-09-27, on build 70009,
-- the owner found the banker in Orgrimmar showing one, a single line on icon
-- 132050, and the bank did not open by itself. Whether the build changed or
-- the two bankers simply differ is not known, and it does not matter: the
-- icon is measured now and on the list. A service measured without a step
-- can grow one, so the other two were worth checking again: the auctioneer
-- was, the same evening, and still has none. The tabard vendor has not been.
--
-- So every service that was agreed for this list and can be reached is in it:
-- vendor, trainer, taxi, petition and bank are measured, and the auctioneer
-- and the tabard vendor had nothing to click past when last seen. The list is
-- not waiting on more services. It is waiting on the opposite question, which
-- is whether any id that must stay out collides with one that is in.
--
-- The **battlemaster** is a third case and not the same one. It offers no
-- interaction here at all, measured 2026-09-20, so its icon cannot be read and
-- it stays off the allow list exactly as it would have anyway.
--
-- **Why** it offers nothing is unknown, and this comment said otherwise for
-- about an hour: it claimed the beta has no battlegrounds. It has three, which
-- the client itself reported when asked. A guess dressed as a reason, written
-- down in the same session that added the measurement meant to test it, and
-- disproven by that measurement within the hour. Leave the reason open.
--
-- Written down because a negative measurement is a measurement. Without it the
-- next person reads a list of seven agreed services, finds four, and walks to
-- the bank to collect the rest.

-- **What has actually been measured, 2026-09-20:**
--
--     132050  bank        the banker in Orgrimmar, 2026-09-27
--     132053  the catch-all: a plain gossip line, and anything the server gave
--             no icon of its own. Twelve guard directions, and talent
--             unlearning
--     132055  petition    Christopher Drakul
--     132057  taxi        Michael Garrett
--     132058  trainer     five NPCs, four different wordings
--     132060  vendor      two NPCs, two different wordings
--
-- **132053 is the one that mattered.** It is the icon on an ordinary gossip
-- line, the kind that can start an escort or trigger an event, and the question
-- this module hung on was whether it might be the same number as one of the
-- services it clicks. It is not. An Undercity Guardian settled it: twelve
-- directions in one window, all twelve on 132053.
--
-- **And one id does *not* mean one service.** This comment claimed it did, for
-- about half an hour, on the strength of five measured points that happened to
-- be five distinct services. Richard Kerwin, a Warlock trainer, offers training
-- on 132058 and "I wish to unlearn my class or legacy talents" on 132053, side
-- by side in one window. Unlearning is a service, it has its own value in
-- Enum.GossipNpcOption, and it still gets the plain icon here.
--
-- So the real shape is weaker and better: **some services carry an icon of
-- their own, and everything else falls back to the plain one.** Better, because
-- the most dangerous entry on the exclusion list turns out to land on the one
-- id that is already excluded, without anybody having to measure it first, and
-- so does anything else the server did not bother to name.
--
-- What remains, stated rather than argued away: something dangerous could carry
-- a *service* icon. Nothing ever has. Every sighting of 132058 was a trainer
-- and every sighting of 132060 a vendor. Guards 2 and 3 cover the rest, and at
-- Richard Kerwin guard 2 alone would have, since his window has two options and
-- nothing was clicked either way.
--
-- The ids also sit in one consecutive block in alphabetical order by service,
-- which held for five points and then broke on the sixth: unlearning is not at
-- 132059. **That is the whole argument for never filling in a gap.** A pattern
-- with five fits looks more like evidence than one with four, right up to the
-- measurement that ends it.

-- How many distinct options to remember. Higher than would be worth keeping
-- permanently, because sweeping a capital city is the cheapest way to fill the
-- allow list and a cap of forty would stop halfway through Undercity. It costs
-- nothing after a release, where COLLECTING is false and nothing is written at
-- all.
local MAX_SEEN = 150

-- The same option twice in a row is a loop, not a service: clicking something
-- that does not dismiss the window would otherwise run until the client gives
-- up. Two seconds is longer than any window takes to close.
local LOOP_GUARD = 2
local lastOption, lastAt = nil, 0

-- Once per icon per session. The point is to be told that something new turned
-- up, not to be told again at every NPC in the city.
local announced = {}

--- Is there any quest on this window, offered or ready to hand in?
--
-- Deliberately broader than QuestAutoTurnIn's own check, which asks only about
-- finished ones. Here *any* quest is a reason to keep out: the window belongs
-- to the quest modules then, and no quest may ever start through this one.
local function HasAnyQuest()
    local g = C_GossipInfo
    if not g then return true end   -- cannot tell, so do not act

    for _, fn in ipairs({ g.GetNumAvailableQuests, g.GetNumActiveQuests }) do
        if type(fn) == "function" then
            local ok, count = pcall(fn)
            if ok and (tonumber(count) or 0) > 0 then return true end
        end
    end

    for _, fn in ipairs({ g.GetAvailableQuests, g.GetActiveQuests }) do
        if type(fn) == "function" then
            local ok, list = pcall(fn)
            if ok and type(list) == "table" then
                local okCount, count = pcall(function() return #list end)
                if okCount and (count or 0) > 0 then return true end
            end
        end
    end

    return false
end

--- Writes an option down: the ones left alone, and the ones clicked.
--
-- Both halves are kept, and the second half is the important one. The allow
-- list rests on a single measurement, one vendor line carrying icon 132060,
-- and "this icon means vendor" is an inference from that one point rather than
-- a fact. If this build hangs the same number on every gossip line, the list
-- lets through exactly what it was built to stop, and the only way to find out
-- is to write down what is actually being clicked and at which NPC.
--
-- Name and NPC are recorded for a human to read later. The *logic* never looks
-- at either, only at the numeric icon, which is the locale rule: a number means
-- the same on every client, a name does not.
local function Record(where, icon, name, npc, quest)
    -- Off in a released build. Not a lesser form of collecting: nothing is
    -- written and nothing is said, and the caller carries on leaving an
    -- unknown option alone, which is the part that actually protects anybody.
    if not COLLECTING then return end

    local store = FP.global[where]
    if type(store) ~= "table" then
        store = {}
        FP.global[where] = store
    end

    -- Keyed by icon *and* text. Keying by the icon alone would keep the first
    -- wording it ever saw and hide every later one behind a counter, and the
    -- wording is precisely the evidence: it is what showed that the icon
    -- follows the service rather than the phrasing.
    local key = tostring(icon or 0) .. "  " .. tostring(name)
    local entry = store[key]
    if entry then
        entry.seen = (entry.seen or 1) + 1
        return
    end

    local count = 0
    for _ in pairs(store) do count = count + 1 end
    if count >= MAX_SEEN then return end

    store[key] = {
        icon  = icon, name = name, npc = npc,
        -- Whether a quest hung on the window. Worth a field of its own: the
        -- dangerous kind of option is a plain gossip line at a quest giver, so
        -- this is how the generic gossip icon gets identified and deliberately
        -- kept off the list, rather than assumed never to collide with it.
        quest = quest or nil,
        seen  = 1, stamp = date("%Y-%m-%d %H:%M:%S"),
    }
end

--- Says once that a kind of service turned up which nobody has classified.
--
-- Keyed by the icon alone, although the store is keyed by icon and text. The
-- two want different things: the store wants every wording, the reader wants
-- to hear once. Sharing a key is how a line meant to appear once per session
-- began appearing at every NPC with a phrasing of its own.
local function Announce(icon, name)
    if not (COLLECTING and M.db.announceLearned) then return end
    local key = tostring(icon or 0)
    if announced[key] then return end
    announced[key] = true
    FP:Print(L["Left alone because the service is unfamiliar: icon %s, "
        .. "\"%s\". The details are saved so the list can be expanded "
        .. "deliberately."],
        tostring(icon), tostring(name))
end

--- Writes down every option in the window, silently.
--
-- Clicking needs a window of exactly one option. **Learning does not**, and
-- tying the two together meant a banker or a flight master could only ever be
-- measured at an NPC that happened to have nothing else to say, which is not
-- how a banker behaves. Silent on purpose: this runs at every conversation,
-- and the announcement above stays with the single case it was written for.
local function Sweep(options, count, quest, npc)
    for i = 1, count do
        local option = options[i]
        if type(option) == "table" then
            Record("gossipIcons", tonumber(rawget(option, "icon")),
                   rawget(option, "name"), npc, quest)
        end
    end
end

local function Show()
    if M.db.holdShiftStop and IsShiftKeyDown() then return end

    local g = C_GossipInfo
    if not (g and g.GetOptions and g.SelectOption) then return end

    local ok, options = pcall(g.GetOptions)
    if not ok or type(options) ~= "table" then return end

    local okCount, count = pcall(function() return #options end)
    if not okCount then return end

    local npc   = UnitName and UnitName("npc")
    local quest = HasAnyQuest()

    -- Everything in the window gets written down, whatever happens below.
    Sweep(options, count, quest, npc)

    -- Guard 3 and guard 2, both absolute, both settled before a single field
    -- of an option is looked at.
    if quest or count ~= 1 then return end

    local option = options[1]
    if type(option) ~= "table" then return end

    local icon = tonumber(rawget(option, "icon"))
    local id   = rawget(option, "gossipOptionID")
    local name = rawget(option, "name")
    if id == nil then return end

    if not (icon and ALLOWED[icon]) then
        return Announce(icon, name)
    end

    local now = GetTime and GetTime() or 0
    if lastOption == id and (now - lastAt) < LOOP_GUARD then
        -- Clicked this a moment ago and the window is still here, so clicking
        -- again would only do it faster.
        return
    end
    lastOption, lastAt = id, now

    Record("gossipClicked", icon, name, npc, false)
    pcall(g.SelectOption, id)

    if M.db.announceClick then
        FP:Print(OPENED[ALLOWED[icon]] or ALLOWED[icon])
    end
end

local handlers = {}
function handlers.GOSSIP_SHOW() Show() end

--- Prints what has been met and not clicked, so the list can be widened.
function M:Seen()
    local function Dump(title, where)
        local rows = {}
        for _, entry in pairs(FP.global[where] or {}) do
            rows[#rows + 1] = string.format(
                "  |cffffffff%-8s|r x%-3d %s %s  |cff888888(%s)|r",
                tostring(entry.icon), entry.seen or 1,
                entry.quest and "|cffffcc00Q|r" or " ",
                tostring(entry.name), tostring(entry.npc))
        end
        table.sort(rows)
        FP:Print("%s: %d", title, #rows)
        for i = 1, #rows do DEFAULT_CHAT_FRAME:AddMessage(rows[i]) end
    end

    -- Clicked first, because that is the list that can be wrong. The other one
    -- is every option the module has ever seen in a gossip window, clicked or
    -- not, and it is what the allow list gets widened from.
    Dump("Clicked for you", "gossipClicked")
    Dump("Every option seen", "gossipIcons")
end

--- Throws that list away again.
function M:ForgetSeen()
    local count = 0
    for _, where in ipairs({ "gossipIcons", "gossipClicked" }) do
        for _ in pairs(FP.global[where] or {}) do count = count + 1 end
        FP.global[where] = nil
    end
    wipe(announced)
    return count
end

function M:OnEnable()
    self.frame = self.frame or CreateFrame("Frame")
    self.frame:SetScript("OnEvent", function(_, event, ...)
        local handler = handlers[event]
        if handler then FP:Safe("GossipAuto:" .. event, handler, ...) end
    end)
    FP:RegisterEvents(self.frame, handlers, "GossipAuto")
end

function M:OnDisable()
    if self.frame then self.frame:UnregisterAllEvents() end
    lastOption, lastAt = nil, 0
end
