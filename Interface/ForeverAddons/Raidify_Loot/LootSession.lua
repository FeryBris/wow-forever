--[[
    LootSession.lua - detecting drops and queueing them for the council

    A session is the window during which this client watches loot and collects
    decisions. It is deliberately local for now: whoever runs it owns the queue.
    Vote synchronisation between council members comes next, and that is where the
    single-authority protocol lives.

    Two things this module is careful about, because both cause real confusion:

    * Only ONE person should be queueing. Every raider opening the same corpse would
      otherwise build their own queue and the council would see divergent lists. The
      session refuses to start without raid authority (leader, assist, or master
      looter) unless explicitly forced for solo testing.
    * A corpse can be opened repeatedly. Items are keyed so reopening does not requeue
      what has already been handled.
]]

local Raidify = _G.Raidify

-- See LootPage.lua: no global GetItemInfo on Forever, identical tuple from C_Item.
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo

--[[
    Loot method moved to C_PartyInfo, it did not go away.

    The global GetLootMethod is absent on World of Warcraft: Forever. That looked at first
    like master loot not existing there — C_Loot has exactly two members and neither is about
    loot method — and it was wrong: C_PartyInfo carries GetLootMethod, SetLootMethod,
    GetAvailableLootMethods, IsLootMethodAvailable and GetLootMethodStyle, and
    Enum.LootMethod.Masterlooter is 2.

    Worth remembering past this line: on a namespaced client a missing global is a relocation
    until proven otherwise, and the namespace it moved to is frequently not the one named
    after it. Loot method moved to party info, not to loot.
]]
local GetLootMethod = (C_PartyInfo and C_PartyInfo.GetLootMethod) or _G.GetLootMethod

-- LootCore.lua sets this after the core/API handshake succeeds. If it did not, the
-- boundary already explained why to the player and this file must add nothing —
-- returning here leaves core untouched rather than defining half a feature against
-- a core it cannot use.
if not Raidify or not Raidify.Loot then return end

-- Councils do not deliberate over greens. Epic and above by default; a guild running
-- a fresh tier where blues still matter can lower it.
local DEFAULT_QUALITY_THRESHOLD = 4

--[[ Does this player have the standing to run a session for the raid? ]]
function Raidify:HasLootAuthority()
    if not IsInRaid() then
        -- Solo or party: allow it, otherwise there is no way to test outside a raid.
        return true
    end

    if UnitIsGroupLeader("player") then return true end
    if UnitIsGroupAssistant("player") then return true end

    -- Master looter, when that mode is in use. Guarded because the global is absent on
    -- Forever and the C_PartyInfo replacement may not exist on the oldest Era builds; with
    -- neither, `method` stays nil and this simply never matches.
    local method, partyIndex, raidIndex
    if GetLootMethod then method, partyIndex, raidIndex = GetLootMethod() end
    if method == "master" then
        if raidIndex and UnitIsUnit("raid" .. raidIndex, "player") then return true end
        if partyIndex == 0 then return true end
    end

    return false
end


local QUALITY_NAME = {
    [0] = "Poor", [1] = "Common", [2] = "Uncommon", [3] = "Rare",
    [4] = "Epic", [5] = "Legendary",
}

--[[
    Set the minimum quality a session queues.

    Applies to a running session immediately rather than only the next one - an
    officer who realises mid-raid that the threshold is wrong should not have to
    restart the session and lose the queue.
]]
function Raidify:SetLootQualityThreshold(value)
    if value == nil then
        local current = self.Loot:GetSetting("lootQualityThreshold") or 4
        self:Print(string.format("Loot threshold is %d (%s and above). /rf loot threshold <0-5> to change.",
            current, QUALITY_NAME[current] or "?"))
        return
    end

    if value < 0 or value > 5 then
        self:PrintError("Threshold must be 0-5: 0 Poor, 1 Common, 2 Uncommon, 3 Rare, 4 Epic, 5 Legendary.")
        return
    end

    self.Loot:SetSetting("lootQualityThreshold", value)

    local applied = ""
    if self.lootSession and self.lootSession.active then
        self.lootSession.threshold = value
        applied = " Applied to the running session."
    end

    self:Print(string.format("Loot threshold set to %d (%s and above).%s",
        value, QUALITY_NAME[value] or "?", applied))
end

--[[
    Arm drop detection and attendance sampling.

    Extracted so start and resume cannot drift: a recovered session that re-armed only half
    of these would look fine and quietly stop recording one of the two things the session
    exists to capture.

    Wrapped rather than registered by method name, for the reason the original inline
    registration gave: an unprotected error inside a handler on the shared Raidify Ace3
    object surfaces as an error in CORE Raidify, which is the blast radius the sub-addon
    split exists to prevent.

    THE BUG THIS FIXES. These registrations used to go through `self:RegisterEvent` on the
    shared Raidify AceAddon object. AceEvent stores exactly one callback per (event, object)
    pair - CallbackHandler does `events[eventname][self] = regfunc` - so registering
    GROUP_ROSTER_UPDATE here REPLACED core's OnRaidRosterUpdate the moment a session started.

    From `/rf loot start` onward, core stopped sampling attendance, reconciling invite
    status, detecting extra players and auto-disabling test mode, for the rest of the night,
    with nothing on screen saying so. Ending the session then called UnregisterEvent, which
    removed the only remaining registration - so the damage outlasted the session.

    Its own frame cannot collide with anything. LootCore and LootTrade already do this; this
    file was the outlier, under a comment that correctly warned about shared-object coupling.
]]
local lootEvents = CreateFrame("Frame")
local lootHandlers = {}

lootEvents:SetScript("OnEvent", function(_, event, ...)
    local handler = lootHandlers[event]
    if handler then handler(...) end
end)

function Raidify:ArmLootDetection()
    lootHandlers.LOOT_OPENED = function()
        Raidify.Loot:Safe("loot detection", function() Raidify:OnLootOpened() end)
    end
    lootHandlers.GROUP_ROSTER_UPDATE = function()
        Raidify.Loot:Safe("attendance sampling", function() Raidify:SampleRaidPresence() end)
    end

    lootEvents:RegisterEvent("LOOT_OPENED")
    lootEvents:RegisterEvent("GROUP_ROSTER_UPDATE")
end

function Raidify:DisarmLootDetection()
    lootEvents:UnregisterEvent("LOOT_OPENED")
    lootEvents:UnregisterEvent("GROUP_ROSTER_UPDATE")
    lootHandlers.LOOT_OPENED = nil
    lootHandlers.GROUP_ROSTER_UPDATE = nil
end


--[[
    Take the queued item the officer is actually looking at.

    Every disposition used to pull queue[1] regardless of which card was open. That is fine
    when you work the queue front to back, and wrong the moment you use
    /rf loot show <itemId> - a command the documentation lists - because the click then
    records a DIFFERENT item against that raider's name. The confirmation line prints the
    wrong link too, so nothing on screen reveals the mistake.

    Falls back to the front of the queue only when NO card is open, which is the right
    behaviour for /rf loot next.

    A card that is open on an item which is not queued returns nil, and every caller refuses.
    That case is `/rf loot show <id>` used as a lookup - an entirely normal way to answer
    "who has this on their list?" - and the old code silently awarded queue[1] instead: a
    different item, to that person, with the confirmation line naming the wrong thing. The
    fix above this comment was written for the variant where the looked-up item IS queued,
    and left the one where it is not.
]]
function Raidify:TakeQueuedItem(session)
    local frame = self.lootWindow
    local wanted = frame and frame:IsShown() and frame.itemId

    if wanted then
        for i, queued in ipairs(session.queue) do
            if queued.itemId == wanted then
                return table.remove(session.queue, i)
            end
        end
        return nil
    end

    return table.remove(session.queue, 1)
end

--[[ The one refusal message, so all three callers say the same thing. ]]
function Raidify:RefuseUnqueuedCard()
    local frame = self.lootWindow
    local link = frame and (frame.itemLink or ("item " .. tostring(frame.itemId)))
    self:PrintError(string.format(
        "%s has not dropped, so there is nothing to record against it. This card is a "
            .. "lookup - /rf loot next to work the queue.", link or "That item"))
end


--[[
    Re-arm an interrupted session without discarding it.

    Recovery restores the awards and the queue but leaves the session inactive on purpose,
    so nothing silently resumes after a crash. The problem was what happened next: the
    officer was told to run /rf loot start, which only checked `active` - false after a
    recovery - and then assigned a brand new empty session over the top. Every award and
    every attendance sample from before the wipe, gone, with no confirmation and no undo.

    So start routes here when there is a record worth keeping. Detection is re-armed, the
    record is untouched.
]]
function Raidify:ResumeLootSession()
    local session = self.lootSession
    session.active = true

    self:ArmLootDetection()
    self:SampleRaidPresence()
    self.Loot:SaveSession(session)
    if self.QueueLootBroadcast then self:QueueLootBroadcast() end

    self:Print(string.format(
        "|cff72B68FResumed|r the recovered session - %d awarded, %d still queued. "
            .. "/rf loot end to finish it.",
        #session.awards, #session.queue))
end


function Raidify:StartLootSession(force)
    if self.lootSession and self.lootSession.active then
        self:PrintWarning("A loot session is already running. /rf loot end to stop it.")
        return
    end

    --[[
        Three states, not two.

        The first version of this checked "does the session have anything in it" and
        resumed if so. That is right on the night of a crash and wrong on every night
        after: a cleanly ended Tuesday still has its awards, so Thursday's `/rf loot start`
        resumed TUESDAY - same startedAt, Thursday's items appended to Tuesday's list, and
        an export that re-sent a night the officer had already pasted into the website.
        Worse than the bug it replaced, because the resume message reads identically
        whether the session is twenty minutes old or two days old.

        `endedAt` is what tells them apart. It is written by EndLootSession and by nothing
        else, so a session that has it was finished on purpose and a session without it
        was interrupted.
    ]]
    local previous = self.lootSession
    local hasRecord = previous
        and ((type(previous.awards) == "table" and #previous.awards > 0)
          or (type(previous.queue) == "table" and #previous.queue > 0))

    if hasRecord and not previous.endedAt then
        self:ResumeLootSession()
        return
    end

    -- Finished, but never sent. Starting over the top of it is how a night's record gets
    -- lost quietly, so it takes a deliberate second command rather than a warning the
    -- officer reads after the fact.
    if hasRecord and not previous.exportedAt and not force then
        self:PrintError(string.format(
            "Last session ended with %d awarded and was never exported. "
                .. "/rf loot export to send it, or /rf loot start force to discard it.",
            #previous.awards))
        return
    end

    if not self.lootData then
        self:PrintWarning("No loot data imported. Sessions still work, but candidates will be limited to who is in the raid.")
    end

    if not force and not self:HasLootAuthority() then
        --[[
            `force` overrides two unrelated things: this authority check, and the guard above
            that stops a new session burying an unexported one.

            So telling an officer to type it, without saying what else it does, is the tool
            walking them into destroying a night's record - an assistant who is not master
            looter follows this exact instruction. The message now names the second
            consequence, but only when it actually applies, so the common case stays short.
        ]]
        local atRisk = hasRecord and not previous.exportedAt and #previous.awards or 0
        local warning = atRisk > 0
            and string.format(" WARNING: that would also discard last session's %s, which "
                .. "has not been sent yet - /rf loot export first.",
                self:Plural(atRisk, "award"))
            or ""

        self:PrintError("Only the raid leader, an assistant, or the master looter should run "
            .. "the session - otherwise everyone builds their own queue. Use "
            .. "/rf loot start force to override." .. warning)
        return
    end

    self.lootSession = {
        active = true,
        startedAt = time(),
        -- The character this belongs to. Recovery refuses to hand it to anyone else.
        owner = self.Loot:CharacterKey(),
        queue = {},
        seen = {},
        awards = {},
        -- Who was actually in the raid, by name. The addon is the only thing that
        -- witnesses this firsthand: WCL sees a log, the website sees a sign-up, and
        -- neither knows who really turned up.
        present = {},
        threshold = self.Loot:GetSetting("lootQualityThreshold") or DEFAULT_QUALITY_THRESHOLD,
    }

    -- Shared with tonight's attendance session so the website can tell these two uploads
    -- describe one evening rather than inferring it from two clocks. Assigned after the
    -- table is in place, not inside the constructor: NightId inspects `self.lootSession`,
    -- which during construction is still the PREVIOUS session — a new night would have
    -- silently inherited the last one's id.
    self.lootSession.nightId = self:NightId()

    -- Starting a session is the other thing only a loot guild does. Marked here as well
    -- as on import, because a guild running standalone sessions may never import at all.
    self.Loot:MarkUsed()

    self:ArmLootDetection()
    self:SampleRaidPresence()
    self.Loot:SaveSession(self.lootSession)

    self:Print(string.format("Loot session started. Queueing %s items and above.",
        QUALITY_NAME[self.lootSession.threshold] or ("quality " .. self.lootSession.threshold)))
end

--[[
    Record who is in the raid right now.

    Called at session start, whenever the group changes, and again at session end, so
    someone who arrived twenty minutes late or left before the last boss is still
    recorded as having been there. The first and last sighting are kept because "showed
    up for one boss" and "raided all night" are different facts, and an officer
    adjudicating loot will eventually want to tell them apart.

    Deliberately records PRESENCE ONLY. The addon can see who is in the raid group; it
    cannot see why someone is not. Guessing "absent" here would put the addon in the
    business of deciding whether a raider was benched or a no-show, which is an officer's
    judgement and the exact distinction that makes attendance numbers trusted or not.
    Absence is inferred on the web, and the repair editor is where a bench is recorded.
]]
function Raidify:SampleRaidPresence()
    local session = self.lootSession
    if not session then return end
    if not session.present then session.present = {} end

    local now = time()

    local function mark(name, class)
        if not name or name == "" then return end

        local entry = session.present[name]
        if entry then
            entry.last = now
            -- Class can arrive nil on the first sample of a zoning player; fill it in
            -- once the game knows rather than leaving the row classless forever.
            if not entry.class and class then entry.class = class end
        else
            session.present[name] = { first = now, last = now, class = class }
        end
    end

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, _, _, _, _, class = GetRaidRosterInfo(i)
            mark(name, class)
        end
    elseif IsInGroup() then
        -- Five-mans count too: a guild running Zul'Gurub splits or a heroic for loot is
        -- still a night the council may be asked about.
        for i = 1, GetNumGroupMembers() - 1 do
            local unit = "party" .. i
            local _, class = UnitClass(unit)
            mark(UnitName(unit), class)
        end
        local _, myClass = UnitClass("player")
        mark(UnitName("player"), myClass)
    else
        local _, myClass = UnitClass("player")
        mark(UnitName("player"), myClass)
    end
end

function Raidify:EndLootSession()
    if not self.lootSession or not self.lootSession.active then
        self:PrintWarning("No loot session is running.")
        return
    end

    self:SampleRaidPresence()
    -- Own frame, so this can no longer take core's roster handler down with it.
    self:DisarmLootDetection()
    self.lootSession.active = false
    self.lootSession.endedAt = time()

    -- The finished session is what the companion ingests and what /rf loot export
    -- reads, so it has to survive the /reload that flushes SavedVariables.
    self.Loot:SaveSession(self.lootSession)

    local pending = #self.lootSession.queue
    local awarded = #self.lootSession.awards

    self:Print(string.format("Loot session ended. %d awarded, %d still queued.", awarded, pending))
    if pending > 0 then
        self:Print("Queued items are kept - /rf loot queue to review them.")
    end
end


--[[
    Queue one item for the council. The single place an item enters the queue.

    Both real loot and simulated loot go through here, so a simulated drop exercises
    the same threshold, dedupe and unknown-quality handling as a real one. A test
    harness that takes a shortcut past the logic it is meant to be testing is worse
    than no harness.

    Returns true when the item was newly queued.
]]
function Raidify:QueueLootItem(itemId, link, quality, sourceId, slot)
    local session = self.lootSession
    if not session or not session.active then return false end
    if not itemId then return false end

    -- An item still uncached AND with no slot quality is unknown, not junk. Queue it
    -- rather than discard it: a missed drop is far worse than an extra card the
    -- officer dismisses.
    local unknownQuality = (quality == nil)
    if not unknownQuality and quality < session.threshold then return false end

    -- Key on the source too: the same item id can legitimately drop twice in a night,
    -- and the council decides each one separately.
    --
    -- When the source is unknown the slot stands in for it, because a shared "unknown"
    -- sentinel makes every copy of an item collide: two Onslaught Girdles off one boss
    -- key identically, the second never queues, and nothing on screen says a drop went
    -- unrecorded. GetLootSourceInfo is missing on some Classic builds and returns nil for
    -- a slot on others, so this is not a rare path.
    --
    -- The slot is the right stand-in because it is stable for the corpse: reopening the
    -- same loot window rescans the same slots and still dedupes, which is what `seen`
    -- exists for, while two copies of an item occupy two different slots and now survive.
    -- Two separate corpses dropping the same item into the same slot index would still
    -- collide - accepted, as it needs the source to be unavailable and the slots to line
    -- up, and the alternative re-queues a card every time an officer reopens a corpse.
    local key = sourceId
        and (tostring(sourceId) .. ":" .. itemId)
        or ("slot" .. tostring(slot) .. ":" .. itemId)
    if session.seen[key] then return false end

    session.seen[key] = true
    table.insert(session.queue, {
        itemId = itemId,
        link = link,
        quality = quality,
        qualityUnknown = unknownQuality,
        sourceKey = key,
        queuedAt = time(),
    })

    -- Queued items were held in memory only until the next award saved the session, so a
    -- crash between a drop and a decision lost the queue - and the Loot page showed no sign
    -- the drop had happened. Saving here persists it and, through SaveSession, redraws.
    self.Loot:SaveSession(session)
    return true
end

--[[
    A corpse (or chest) was opened. Queue anything worth a council decision.

    Reads every slot rather than only the master-looter view, because the same code
    has to work under group loot where the addon is just observing.
]]
function Raidify:OnLootOpened()
    local session = self.lootSession
    if not session or not session.active then return end

    local queued = 0

    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotInfo and GetLootSlotLink(slot)
        if link then
            -- GetLootSlotInfo returns quality FIFTH:
            --   icon, name, quantity, currencyID, quality, locked, isQuestItem, questID, isActive
            -- Reading it as the third value yields quantity (nearly always 1), which
            -- silently queues nothing at any sensible threshold.
            local _, _, _, _, slotQuality = GetLootSlotInfo(slot)

            local itemId = tonumber(link:match("item:(%d+)"))

            -- Fall back to the item's own quality when the slot does not report one;
            -- the link is authoritative and already in hand.
            local quality = slotQuality
            if quality == nil and itemId then
                quality = select(3, GetItemInfo(itemId))
            end

            -- Left nil when the API is absent or answers nil, so QueueLootItem can fall
            -- back to the slot rather than every drop sharing one "unknown" key.
            local guid = GetLootSourceInfo and GetLootSourceInfo(slot)
            if self:QueueLootItem(itemId, link, quality, guid and tostring(guid), slot) then
                queued = queued + 1
            end
        end
    end

    if queued > 0 then
        -- Name what queued. "2 items queued" leaves the officer guessing whether the
        -- thing they were watching for is actually in there.
        for index = #session.queue - queued + 1, #session.queue do
            local entry = session.queue[index]
            self:Print(string.format("Queued %s%s",
                entry.link or ("item " .. entry.itemId),
                entry.qualityUnknown and " |cff7F888B(quality unknown)|r" or ""))
        end

        -- Open the first one straight away when nothing else is under discussion: the
        -- officer is already looking at the corpse and making them type breaks that
        -- flow. If a card is already up, leave it - pulling focus mid-decision is
        -- worse than a queued item waiting - but say so, or it reads as a missed drop.
        if #session.queue == queued then
            self:ShowNextLootItem()
        else
            self:Print(string.format(
                "|cffEAB444%d waiting|r behind the item on screen. /rf loot done to resolve it and advance.",
                #session.queue - 1))
        end
    end
end


--[[
    /rf loot debug - dump exactly what the addon sees in the open loot window.

    Written because a green recipe did not queue while a green item did, and guessing
    at the cause from the outside was going in circles. This reports every slot and
    the precise reason it was kept or skipped, so the next occurrence is diagnosable
    instead of a discussion.

    Run it with the corpse open.
]]
function Raidify:DebugLootSlots()
    local count = GetNumLootItems()
    if not count or count == 0 then
        self:Print("No loot window open (or it has no slots). Open a corpse first, then run this.")
        return
    end

    local threshold = (self.lootSession and self.lootSession.threshold)
        or self.Loot:GetSetting("lootQualityThreshold") or 4

    self:Print(string.format("Loot window: %s, threshold %d (%s+)",
        self:Plural(count, "slot"), threshold, QUALITY_NAME[threshold] or "?"))

    for slot = 1, count do
        local link = GetLootSlotLink(slot)
        local icon, name, quantity, currencyID, slotQuality, locked, isQuestItem = GetLootSlotInfo(slot)
        local slotType = GetLootSlotType and GetLootSlotType(slot) or nil
        local itemId = link and tonumber(link:match("item:(%d+)"))

        local itemQuality
        if itemId then itemQuality = select(3, GetItemInfo(itemId)) end

        local verdict
        if not link then
            verdict = "|cffBE706ESKIPPED - no item link (money or currency slot)|r"
        elseif not itemId then
            verdict = "|cffBE706ESKIPPED - link has no item id|r"
        else
            local effective = slotQuality or itemQuality
            if effective == nil then
                verdict = "|cff72B68FKEPT - quality unknown, queued rather than dropped|r"
            elseif effective >= threshold then
                verdict = "|cff72B68FKEPT|r"
            else
                verdict = string.format("|cffD3A96FSKIPPED - quality %d below threshold %d|r",
                    effective, threshold)
            end
        end

        self:Print(string.format("  slot %d: %s", slot, link or (name or "?")))
        self:Print(string.format("     type=%s slotQuality=%s itemQuality=%s quest=%s locked=%s",
            tostring(slotType), tostring(slotQuality), tostring(itemQuality),
            tostring(isQuestItem), tostring(locked)))
        self:Print("     " .. verdict)
    end
end


--[[
    Simulate a drop, so testing does not depend on RNG.

    Runs through QueueLootItem exactly as real loot does - only the WoW loot API is
    bypassed, not the logic. The card, award flow and export are all identical to a
    real drop, which is the point: a harness that skips the code under test proves
    nothing.

    /rf loot sim              - a default spread covering the interesting cases
    /rf loot sim <itemId>     - one specific item
]]

-- Chosen to exercise distinct paths rather than to look realistic:
--   29761 Helm of the Fallen Defender  - class-locked, likely wishlisted, has a prio
--   18563 Bindings of the Windseeker   - class-locked via a curated fill
--   19137 Onslaught Girdle             - carries a standing rule
--   11382 Blood of the Mountain        - ordinary, no lock
--[[
    What a simulated boss drops.

    Kara and T4-era, matching TEST_ITEMS in LootTestData for the reason stated there: the
    names have to resolve, or the card is a row of "item 19137" and proves nothing about a
    screen whose job is to make a decision readable. The previous list mixed in Classic-era
    ids that a TBC client has no reason to have cached, so one row rendered as a bare number
    and an officer had no idea what they had just awarded.

    Deliberately none of the three the sample data awards up front (TEST_ITEMS 1-3).
    Overlapping them put the same item in both "given out tonight" and a fresh card, which
    reads as the addon having duplicated something rather than as a second drop.
]]
local SIMULATED_DROPS = { 29763, 29764, 28573, 30219 }

function Raidify:SimulateLootDrop(itemId)
    local session = self.lootSession
    if not session or not session.active then
        self:PrintError("Start a session first: /rf loot start")
        return
    end

    local ids = itemId and { itemId } or SIMULATED_DROPS
    local queued = 0

    -- A distinct source per simulation run, so repeated runs queue fresh items rather
    -- than being swallowed by the dedupe. Real corpses differ; simulated ones must too.
    local runId = "sim-" .. tostring(time()) .. "-" .. tostring(math.random(1000, 9999))

    for index, id in ipairs(ids) do
        local name, link, quality = GetItemInfo(id)

        -- GetItemInfo is nil for anything uncached. Ask for it and queue with unknown
        -- quality: QueueLootItem keeps unknowns rather than dropping them, and the card
        -- fills the name in when the server answers.
        if not link and C_Item and C_Item.RequestLoadItemDataByID then
            C_Item.RequestLoadItemDataByID(id)
        end

        if self:QueueLootItem(id, link, quality, runId .. "-" .. index) then
            queued = queued + 1
            self:Print(string.format("Simulated drop: %s", link or ("item " .. id)))
        end
    end

    if queued == 0 then
        self:PrintWarning("Nothing queued - the items may be below your threshold. /rf loot threshold to check.")
        return
    end

    self:Print(string.format("%s queued.", Raidify:Plural(queued, "simulated drop")))
    if #session.queue == queued then
        self:ShowNextLootItem()
    end
end

--[[ Show the oldest unresolved item in the queue. ]]
function Raidify:ShowNextLootItem()
    local session = self.lootSession
    if not session or #session.queue == 0 then
        self:Print("Nothing in the loot queue.")
        return
    end

    local entry = session.queue[1]
    self:ShowLootCandidates(entry.itemId)
end

--[[ Drop the front of the queue - taken, banked, or decided elsewhere. ]]
function Raidify:ResolveCurrentLootItem(note)
    local session = self.lootSession
    if not session or #session.queue == 0 then
        self:PrintWarning("Nothing in the loot queue.")
        return
    end

    local entry = self:TakeQueuedItem(session)
    -- nil means the open card is a lookup for an item that never dropped. Recording
    -- anything here would write against a different item entirely.
    if not entry then self:RefuseUnqueuedCard() return end
    table.insert(session.awards, {
        itemId = entry.itemId,
        link = entry.link,
        -- awardedAt, not resolvedAt. The export reads `awardedAt` for every row, so a
        -- resolved item shipped with `at = nil` and the server had nothing to date it by.
        -- It still has no winner and no disposition, which is the point of the command -
        -- the item left the queue without going to anyone the tool knows about - so the
        -- export drops it rather than sending a row the server can only reject.
        awardedAt = time(),
        resolved = true,
        note = note,
    })

    self:Print(string.format("Resolved %s. %d left in the queue.",
        entry.link or ("item " .. entry.itemId), #session.queue))

    -- Written explicitly rather than relying on the session table still being the
    -- same one SaveSession handed to SavedVariables. That reference does hold today,
    -- which is why awards survived a reload at all — but it is an invariant nothing
    -- states and one reassignment away from silently losing a night.
    self.Loot:SaveSession(session)
    if self.QueueLootBroadcast then self:QueueLootBroadcast() end

    if #session.queue > 0 then
        self:ShowNextLootItem()
    elseif self.lootWindow then
        -- Clear the item as well as hiding. itemId was never reset, so the dashboard's
        -- reopen button stayed lit for the rest of the night and brought back a card for
        -- an item that had already been decided - stale counts, stale offspec state, and
        -- a straight path into awarding against the wrong thing.
        self.lootWindow.itemId = nil
        self.lootWindow.isQueued = nil
        self.lootWindow:Hide()
    end
end


--[[
    Award the item currently on the card to a candidate.

    Records who got it and why they were eligible, then advances the queue. The record
    is what eventually reaches the web ledger, so it keeps the decision inputs
    alongside the outcome - "rank 1 BiS, prio 1" explains an award months later in a
    way that a bare name does not.
]]
function Raidify:AwardCurrentItemTo(candidate)
    local session = self.lootSession
    if not session or #session.queue == 0 then
        self:PrintWarning("Nothing in the loot queue to award.")
        return
    end

    if not candidate or not candidate.char then
        self:PrintError("No candidate selected.")
        return
    end

    -- The game itself blocks this, so recording it would put a knowingly impossible
    -- award into the guild's permanent history.
    if candidate.eligible == false then
        self:PrintError(string.format("%s cannot use that item - its class restriction blocks it.",
            candidate.char.name))
        return
    end

    local entry = self:TakeQueuedItem(session)
    -- nil means the open card is a lookup for an item that never dropped. Recording
    -- anything here would write against a different item entirely.
    if not entry then self:RefuseUnqueuedCard() return end

    --[[
        Reserve the physical copy now, not at trade time.

        Two copies of one item are two items with two clocks. Claiming one here means a
        second award of the same item takes a different copy, the owed list shows each its
        own remaining time, and the trade hands over the one that was actually promised.
        nil on Classic flavours without the GUID API, where the clock is used instead.
    ]]
    local itemGuid = self.ReserveAwardedItem and self:ReserveAwardedItem(entry.itemId) or nil

    table.insert(session.awards, {
        itemId = entry.itemId,
        itemGuid = itemGuid,
        link = entry.link,
        winner = candidate.char.key or candidate.char.name,
        winnerName = candidate.char.name,
        winnerClass = candidate.char.class,
        rank = candidate.rank,
        tier = candidate.tier,
        prio = candidate.prio,
        -- Awarded for an offspec. The web ledger keeps offspec awards out of "days since
        -- last loot" and "recent loot", so a raider who takes a weapon for their offspec
        -- does not pay for it the next time they want a mainspec item. Without this flag
        -- every award the addon sent looked like a mainspec win, which made accepting
        -- offspec loot a cost - and the fastest way to teach a raid to refuse it.
        offspec = self.lootWindow and self.lootWindow.offspec or nil,
        -- Recorded, not blocked. Awarding to someone who disconnected mid-boss is
        -- legitimate, but the ledger should say so - "why did rank 4 win this" reads very
        -- differently once you know ranks 1 to 3 were not in the raid.
        absent = candidate.present == false or nil,
        awardedAt = time(),
    })

    local offspec = self.lootWindow and self.lootWindow.offspec
    self:Print(string.format("|cff72B68FAwarded|r %s to |cffEAB444%s|r%s",
        entry.link or ("item " .. entry.itemId), candidate.char.name,
        offspec and " |cffD3A96F(offspec)|r" or ""))

    if self.Loot:GetSetting("announceLootAwards") and IsInRaid() then
        SendChatMessage(
            string.format("Raidify: %s awarded to %s%s",
                entry.link or ("item " .. entry.itemId), candidate.char.name,
                offspec and " (offspec)" or ""),
            "RAID")
    end

    -- Written explicitly rather than relying on the session table still being the
    -- same one SaveSession handed to SavedVariables. That reference does hold today,
    -- which is why awards survived a reload at all — but it is an invariant nothing
    -- states and one reassignment away from silently losing a night.
    self.Loot:SaveSession(session)
    if self.QueueLootBroadcast then self:QueueLootBroadcast() end

    if #session.queue > 0 then
        self:ShowNextLootItem()
    elseif self.lootWindow then
        -- Clear the item as well as hiding. itemId was never reset, so the dashboard's
        -- reopen button stayed lit for the rest of the night and brought back a card for
        -- an item that had already been decided - stale counts, stale offspec state, and
        -- a straight path into awarding against the wrong thing.
        self.lootWindow.itemId = nil
        self.lootWindow.isQueued = nil
        self.lootWindow:Hide()
        self:Print("Queue empty. /rf loot export when you are ready to record it on the web.")
    end
end


--[[
    Record an item as banked, disenchanted, or free-rolled.

    Same ledger as a personal award, with no winner. The point is that every item that
    dropped has an entry - a gap in the record is what makes a guild argue about what
    happened three weeks ago.
]]
function Raidify:DisposeCurrentItem(disposition)
    local session = self.lootSession
    if not session or #session.queue == 0 then
        self:PrintWarning("Nothing in the loot queue.")
        return
    end

    local entry = self:TakeQueuedItem(session)
    -- nil means the open card is a lookup for an item that never dropped. Recording
    -- anything here would write against a different item entirely.
    if not entry then self:RefuseUnqueuedCard() return end

    table.insert(session.awards, {
        itemId = entry.itemId,
        link = entry.link,
        disposition = disposition,
        awardedAt = time(),
    })

    -- Display text, not the enum key: the button says "Free roll" and this line used to
    -- answer "FreeRoll".
    local shown = (self.Loot.DispositionText and self.Loot.DispositionText[disposition])
        or disposition
    self:Print(string.format("%s -> |cffEAB444%s|r",
        entry.link or ("item " .. entry.itemId), shown))

    -- Written explicitly rather than relying on the session table still being the
    -- same one SaveSession handed to SavedVariables. That reference does hold today,
    -- which is why awards survived a reload at all — but it is an invariant nothing
    -- states and one reassignment away from silently losing a night.
    self.Loot:SaveSession(session)

    -- Both siblings broadcast and this did not, so bank, disenchant and free-roll never
    -- reached a co-officer's mirror at all. A takeover then rebuilt a night missing every
    -- item that left the raid without a name on it.
    if self.QueueLootBroadcast then self:QueueLootBroadcast() end

    if #session.queue > 0 then
        self:ShowNextLootItem()
    elseif self.lootWindow then
        -- Clear the item as well as hiding. itemId was never reset, so the dashboard's
        -- reopen button stayed lit for the rest of the night and brought back a card for
        -- an item that had already been decided - stale counts, stale offspec state, and
        -- a straight path into awarding against the wrong thing.
        self.lootWindow.itemId = nil
        self.lootWindow.isQueued = nil
        self.lootWindow:Hide()
    end
end

--[[
    Build the string that carries this session's awards back to the web.

    Sends the decision inputs, not just the outcome: the server records rank, tier and
    prio alongside the winner so the ledger can answer "why did they get it" without
    the council having to remember.
]]
--[[
    Refuse outright rather than filtering.

    Dropping test AWARDS row by row is not enough: the payload also carries attendance,
    sampled from whoever was in the group, and in test mode that is twenty-five invented
    names. A partially-scrubbed export is the worst outcome available — it looks legitimate
    and quietly writes fiction into a guild's permanent record.

    So a session that was seeded with test data cannot be exported at all. The per-award
    isTest filter below stays as a second line of defence for a session that somehow mixes
    both, which nothing should produce.
]]
function Raidify:ExportLootSession()
    if self.lootSession and self.lootSession.isTest then
        self:PrintError("This session was filled with test data and cannot be sent to the "
            .. "website. /rf loot start force to begin a real one.")
        return
    end


    local session = self.lootSession
    if not session then
        self:PrintWarning("No session to export yet.")
        return
    end

    -- Attendance alone is worth exporting. A night where the council handed out nothing
    -- still happened, and refusing to export it would lose the one record the addon is
    -- uniquely able to produce.
    local attendance = {}
    for name, seen in pairs(session.present or {}) do
        table.insert(attendance, {
            name = name,
            class = seen.class,
            first = seen.first,
            last = seen.last,
        })
    end
    table.sort(attendance, function(a, b) return a.name < b.name end)

    if #session.awards == 0 and #attendance == 0 then
        self:PrintWarning("Nothing to export yet - no awards and nobody seen in the raid.")
        return
    end

    local awards = {}
    for _, a in ipairs(session.awards) do
        -- Send name and quality too. The web catalog holds raid loot; a session can
        -- legitimately capture something outside it (trash, a pattern, a world drop),
        -- and dropping those from the ledger is exactly the gap that makes a guild
        -- argue weeks later. With these the server can record it regardless.
        local name, _, quality = GetItemInfo(a.itemId)

        -- Resolved items are a local note that the queue moved on, not an award. They
        -- carry no winner and no disposition, which is exactly the row the server refuses
        -- with "No winner and no disposition recorded" - so sending it buys a confusing
        -- line in the officer's import preview and nothing else.
        -- Plain conditional, not `goto`. WoW runs Lua 5.1, which has no goto at all —
        -- it is a syntax error there, and a syntax error takes the whole file with it.
        -- Test awards never leave the client. LootTestData seeds them so the awards list
        -- and the "won tonight" chips have something to show; sending them would put a
        -- fabricated night into a guild's permanent record.
        if not a.resolved and not a.isTest then
        table.insert(awards, {
            itemId = a.itemId,
            name = name,
            quality = quality,
            disposition = a.disposition,
            winner = a.winner,
            class = a.winnerClass,
            rank = a.rank,
            tier = a.tier,
            prio = a.prio,
            -- The winner was not in the raid when this was awarded. Captured at award time
            -- and, until now, dropped at the door: the ledger could not tell anyone that
            -- ranks 1 to 3 were absent, which is the single fact that explains most
            -- contested awards after the fact.
            absent = a.absent,
            -- Deliberately NOT sent as a disposition. A disposition means nobody got the
            -- item and the server skips winner matching entirely, so routing offspec
            -- through it would throw away the name this row exists to record.
            offspec = a.offspec,
            at = a.awardedAt,
            --[[
                Awarded and delivered are different facts.

                Both of these were computed in the addon, held in memory, and thrown away at
                the door. Without tradedAt the ledger can only ever say an item was awarded,
                so a raider who says they never received it and an officer who says they
                handed it over are arguing with nothing between them. Without adoptedFrom an
                award someone took over after a disconnect reads exactly like one the
                exporting officer made themselves, which is the one thing a record has to be
                able to tell apart.
            ]]
            tradedAt = a.tradedAt,
            adoptedFrom = a.adoptedFrom or session.adoptedFrom,
        })
        end
    end

    local payload = {
        v = 1,
        type = "lootawards",
        guild = self.lootData and self.lootData.guild or nil,
        -- The raid this session belongs to, when a roster was imported for one.
        -- Without it every session award lands unattached, and filtering the web
        -- ledger by raid returns nothing for the 95% of awards that come from here.
        -- Nil for a standalone session with no imported raid, which is legitimate.
        raid = self.raidInfo and self.raidInfo.id or nil,
        -- Ties this to tonight's attendance upload. Without it the server falls back to
        -- matching on a minute-precision timestamp, which double-records a standalone
        -- night. Back-filled for sessions that started before this field existed.
        nightId = session.nightId or self:NightId(),
        startedAt = session.startedAt,
        endedAt = session.endedAt or time(),
        awards = awards,
        -- Presence only, never absence: see SampleRaidPresence. The server records these
        -- as attended and infers nothing about anyone missing.
        attendance = attendance,
    }

    local export = self:CreateExportString("lootawards", payload)

    -- Producing the string is as close to "sent" as the addon can get - it cannot know
    -- whether the officer actually pasted it. That is enough for what this flag guards:
    -- starting a new session over a night that was never even exported is the accident
    -- worth blocking, and one that was exported but not pasted is recoverable, because
    -- /rf loot export can be run again on an ended session.
    session.exportedAt = time()
    self.Loot:SaveSession(session)

    -- Hand the finished string to the companion app, which uploads it without ever having
    -- to understand the payload. Keeping the string rather than re-encoding from the Lua
    -- table on the other side means there is exactly one implementation of the wire format
    -- and one checksum, produced here.
    self.Loot:RememberPendingExport(export, session, #awards)

    self:ShowLootExportWindow(export, #awards, #attendance)
    return export
end


--[[
    Show the export string for copying into the web app.

    Mirrors how attendance export already presents itself (AceGUI MultiLineEditBox,
    pre-selected) so officers do not have to learn a second interaction for the same
    job.
]]
function Raidify:ShowLootExportWindow(exportString, awardCount, attendeeCount)
    local AceGUI = LibStub("AceGUI-3.0")

    if self.lootExportFrame then
        self.lootExportFrame:Release()
        self.lootExportFrame = nil
    end

    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Raidify - Loot Awards")
    frame:SetStatusText(string.format(
        "%d award(s) and %d attendee(s) ready to record on the web",
        awardCount, attendeeCount or 0))
    frame:SetLayout("Flow")
    frame:SetWidth(560)
    frame:SetHeight(280)
    frame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
        Raidify.lootExportFrame = nil
    end)

    local box = AceGUI:Create("MultiLineEditBox")
    box:SetLabel("Copy this into the Loot & Records page:")
    box:SetFullWidth(true)
    box:SetNumLines(6)
    box:SetText(exportString)
    box:DisableButton(true)
    frame:AddChild(box)

    -- Officers copy this mid-raid with a boss pull pending; pre-selecting it removes
    -- a step from an already rushed moment.
    local editBox = box.editBox
    if editBox then
        editBox:HighlightText()
        editBox:SetFocus()
    end

    self.lootExportFrame = frame
end

function Raidify:PrintLootQueue()
    local session = self.lootSession
    if not session then
        self:Print("No loot session. /rf loot start to begin one.")
        return
    end

    self:Print(string.format("Loot session: %s | %d queued | %d resolved",
        session.active and "|cff72B68Frunning|r" or "|cff7F888Bended|r",
        #session.queue, #session.awards))

    for index, entry in ipairs(session.queue) do
        self:Print(string.format("  %d. %s", index, entry.link or ("item " .. entry.itemId)))
    end
end
