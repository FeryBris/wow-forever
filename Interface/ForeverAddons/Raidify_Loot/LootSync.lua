--[[
    LootSync.lua - so the night is not only on one person's client.

    THE PROBLEM. Everything about a loot session lives on whoever ran /rf loot start. The
    queue, the awards, who is still owed what. If that person disconnects and cannot get
    back — router dies, power cut, client will not launch — the record of the night is gone
    and nobody else in the raid has any of it. The raid keeps killing bosses and nothing is
    being written down.

    That is the last structural gap in this feature, and it is the one most likely to
    actually cost a guild something.

    WHAT THIS IS, AND DELIBERATELY IS NOT. It is a broadcast, not a shared document. The
    master looter sends what they have; other officers keep a read-only copy. Nobody edits
    anything they did not run.

    Two writers on one loot record needs conflict resolution, and getting that wrong
    corrupts the thing the whole addon exists to protect. A copy that is occasionally a few
    seconds stale cannot corrupt anything, and it answers the question that matters: if the
    person running loot vanishes, is the night recoverable? Adopting a mirror is possible
    and deliberately manual — a command, with a confirmation, by someone who has decided to
    take over.
]]

local Raidify = _G.Raidify

-- See LootPage.lua: no global GetItemInfo on Forever, identical tuple from C_Item.
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
if not Raidify or not Raidify.Loot then return end

local Loot = Raidify.Loot

local COMM_KIND = "LOOTSESS"

--[[
    Coalesce bursts.

    Three items awarded in twenty seconds while clearing a queue is normal, and sending
    three times is three times the traffic for a state the third message already describes.
    Nothing here is time-critical: a mirror that lands five seconds later is exactly as
    useful.
]]
local BROADCAST_DELAY = 5
local pendingBroadcast = nil

--[[
    What goes on the wire.

    Deliberately not the session table. That carries the raid's presence samples and every
    decision variable behind each award, none of which a mirror needs — and sending a
    guild's attendance data to every officer's client is a bigger promise than this feature
    should be making. Item ids and winner names are enough to rebuild the record.
]]
local function BuildPayload(session)
    local awards = {}
    for _, award in ipairs(session.awards or {}) do
        table.insert(awards, {
            i = award.itemId,
            w = award.winnerName,
            d = award.disposition,
            o = award.offspec and 1 or nil,
            t = award.tradedAt,
            at = award.awardedAt,
        })
    end

    local queue = {}
    for _, entry in ipairs(session.queue or {}) do
        table.insert(queue, entry.itemId)
    end

    return {
        startedAt = session.startedAt,
        endedAt = session.endedAt,
        active = session.active and 1 or nil,
        awards = awards,
        queue = queue,
    }
end

--[[
    Send the current session to the other officers.

    Raid channel only, and only while in a raid: outside one there is nobody to tell, and
    a party-wide broadcast of loot decisions is not something anyone asked for.
]]
function Raidify:BroadcastLootSession()
    local session = self.lootSession
    if not session or session.isTest then return end
    if not IsInRaid() then return end
    if not self.SendComm then return end

    -- Only the person actually running it. Two officers with sessions both broadcasting
    -- would leave everyone else flipping between two versions of the night.
    if self.HasLootAuthority and not self:HasLootAuthority() then return end

    self:SendComm(COMM_KIND, BuildPayload(session), "RAID", nil, "BULK")
end

--[[ Schedule a send, collapsing anything already queued. ]]
function Raidify:QueueLootBroadcast()
    if pendingBroadcast then return end
    if not (C_Timer and C_Timer.After) then return end

    pendingBroadcast = true
    C_Timer.After(BROADCAST_DELAY, function()
        pendingBroadcast = nil
        Loot:Safe("loot broadcast", function() Raidify:BroadcastLootSession() end)
    end)
end

--[[
    Receive somebody else's session.

    Stored apart from our own, always. A mirror must never be mistaken for a session this
    client is running: the card reads lootSession to decide what to award against, and a
    mirror landing there would let an officer award items out of a queue that is not theirs.
]]
--[[
    Does the sender have any business running a loot session?

    The comm channel is documented in Sync.lua as untrusted input from any raid member, and
    this handler used to take it at its word: anyone in the raid with the addon could
    broadcast a session with any awards in it, and it would sit there as a mirror waiting to
    be adopted. Mirrors the check BroadcastLootSession already applies to itself - leader,
    assistant, or master looter - just pointed at the other end of the wire.
]]
local function SenderHasAuthority(sender)
    if not IsInRaid() then return false end
    if not (GetNumGroupMembers and GetRaidRosterInfo) then return false end

    local short = Ambiguate and Ambiguate(sender, "short") or sender
    for index = 1, GetNumGroupMembers() do
        local name, rank, _, _, _, _, _, _, _, _, isML = GetRaidRosterInfo(index)
        if name and (name == sender or name == short) then
            return (rank and rank > 0) or isML == true
        end
    end
    return false
end

local function HandleLootSession(self, payload, sender)
    if type(payload) ~= "table" then return end
    if type(payload.awards) ~= "table" then return end

    -- Silently, not with a warning: a client that is wrong about this is either buggy or
    -- hostile, and either way telling it so on every message helps nobody.
    if not SenderHasAuthority(sender) then return end

    -- Our own session always wins. Somebody else broadcasting while we are running one
    -- means two sessions are open, which is a problem to report rather than resolve.
    if self.lootSession and self.lootSession.active then
        if not self._warnedDoubleSession then
            self._warnedDoubleSession = true
            self:PrintWarning(string.format(
                "%s is also running a loot session. Only one of you should - the other's "
                    .. "queue is separate and will not be in your export.", sender))
        end
        return
    end

    self.lootMirror = {
        from = sender,
        receivedAt = time(),
        startedAt = payload.startedAt,
        endedAt = payload.endedAt,
        active = payload.active == 1,
        awards = payload.awards,
        queue = payload.queue or {},
    }

    if self.RefreshCurrentPage then self:RefreshCurrentPage() end
end

--[[
    Take over a session somebody else was running.

    Manual, and it asks first. This is the recovery path for "the master looter is gone",
    not something to do casually: it makes this client the one holding the record, and the
    items are still in the other person's bags, so it can only ever rebuild the LEDGER, not
    the loot itself. Saying that plainly matters more than making it convenient.
]]
function Raidify:AdoptLootMirror()
    local mirror = self.lootMirror
    if not mirror then
        self:PrintError("No session from another officer to take over.")
        return
    end

    if self.lootSession and self.lootSession.active then
        self:PrintError("End your own session first.")
        return
    end

    --[[
        Show what is being merged, not just how much of it.

        A count is not a decision. An officer recovering from a real crash reads "12 awards
        will be copied to you", under pressure, with the raid waiting, and clicks Take over
        without ever seeing the rows - and once adopted they are indistinguishable from
        awards that officer made themselves. This list is the only place a wrong row gets
        caught before it reaches the website.
    ]]
    local SHOWN = 8
    local lines = {}
    for index, award in ipairs(mirror.awards) do
        if index > SHOWN then break end
        local itemName = GetItemInfo and GetItemInfo(award.i)
        table.insert(lines, string.format("  %s - %s%s",
            itemName or ("item " .. tostring(award.i)),
            award.w or (award.d and tostring(award.d)) or "?",
            award.o == 1 and " (offspec)" or ""))
    end
    if #mirror.awards > SHOWN then
        table.insert(lines, string.format("  ...and %d more", #mirror.awards - SHOWN))
    end
    if #lines == 0 then
        table.insert(lines, "  (nothing awarded yet)")
    end

    self:ShowConfirmDialog({
        title = "Take over " .. mirror.from .. "'s session?",
        message = string.format(
            "%d award(s) and %d queued item(s) will be copied to you, and you become the "
                .. "one who exports the night.\n\n%s\n\nThe items are still in %s's bags - "
                .. "this recovers the record, not the loot.",
            #mirror.awards, #(mirror.queue or {}), table.concat(lines, "\n"), mirror.from),
        confirmText = "Take over",
        cancelText = "Cancel",
        onConfirm = function()
            local awards = {}
            for _, a in ipairs(mirror.awards) do
                table.insert(awards, {
                    itemId = a.i,
                    winner = a.w,
                    winnerName = a.w,
                    disposition = a.d,
                    offspec = a.o == 1 or nil,
                    tradedAt = a.t,
                    awardedAt = a.at,
                    -- Marked so the ledger can say where these came from. A record that
                    -- cannot tell first-hand from second-hand is a record an officer
                    -- cannot defend.
                    adoptedFrom = mirror.from,
                })
            end

            --[[
                Carry the queue as well as the awards.

                This used to set queue = {} and say nothing about it. The mirror's queue is
                the items still waiting on a decision when the other officer dropped, which
                is precisely what a takeover exists to rescue - and discarding it silently
                meant those drops left the record with nobody told they had ever existed.

                Only item ids cross the wire, so link and quality are re-resolved from the
                client's own cache when the card opens. sourceKey is synthesised: the
                adopting officer never opened that corpse, so there is no real key to carry,
                and this still stops the item queueing twice if they open it later.
            ]]
            local queue, seen = {}, {}
            for _, itemId in ipairs(mirror.queue or {}) do
                local key = "adopted:" .. tostring(itemId)
                if not seen[key] then
                    seen[key] = true
                    table.insert(queue, {
                        itemId = itemId,
                        sourceKey = key,
                        queuedAt = mirror.startedAt or time(),
                        adopted = true,
                    })
                end
            end

            self.lootSession = {
                active = true,
                startedAt = mirror.startedAt or time(),
                -- This client owns the night now; recovery keys off it after a relog.
                owner = Loot:CharacterKey(),
                queue = queue,
                seen = seen,
                awards = awards,
                present = {},
                threshold = Loot:GetSetting("lootQualityThreshold"),
                adoptedFrom = mirror.from,
            }

            Loot:MarkUsed()
            self:ArmLootDetection()
            self:SampleRaidPresence()
            Loot:SaveSession(self.lootSession)

            self.lootMirror = nil
            self:PrintBranded(string.format(
                "Took over %s's session - %d award(s) and %d queued item(s) carried over.",
                mirror.from, #awards, #queue))
            if self.RefreshCurrentPage then self:RefreshCurrentPage() end
        end,
    })
end

if Raidify.RegisterCommHandler then
    Raidify:RegisterCommHandler(COMM_KIND, HandleLootSession)
end
