--[[
    Loot.lua - the RAIDIFY:v1:loot payload

    Holds what the web app knows about loot: who wants what, officer priority, the
    guild's ruleset, and the candidate variables a council weighs. The wire shape is
    frozen (raidify/docs/LOOT_PAYLOAD_CONTRACT.md) because renaming a field here
    breaks every installed copy until players update.

    Design notes worth keeping in mind when extending this:

    * The payload carries ITEM IDS ONLY. Names, icons, quality and slot come from
      GetItemInfo at display time, which keeps the string small and keeps us correct
      if Blizzard retunes an item.
    * Characters are listed once in `chars`; everything else references them by index.
    * Absent means absent. A guild without the loot suite legitimately sends no
      wl/prio/vars at all, and the addon must run a standalone session on that rather
      than error.
]]

local Raidify = _G.Raidify

-- LootCore.lua sets this after the core/API handshake succeeds. If it did not, the
-- boundary already explained why to the player and this file must add nothing —
-- returning here leaves core untouched rather than defining half a feature against
-- a core it cannot use.
if not Raidify or not Raidify.Loot then return end

-- Response tiers, in council-preference order. Kept as an ordered list so sorting
-- does not depend on string comparison.
-- Unranked raid members carry 99, so every value here must stay BELOW it except Pass.
-- Pass means "I do not want this", and it used to sort at 5 — above the 99 given to someone
-- who never listed the item at all. Declining an item therefore placed you higher on the
-- card than a raider who genuinely wanted it, which is exactly backwards and rewards
-- marking Pass on everything you can equip.
local UNRANKED_ORDER = 99

local TIER_ORDER = {
    BiS = 1,
    Upgrade = 2,
    Minor = 3,
    Offspec = 4,
    Pass = UNRANKED_ORDER + 1,
}

-- Keyed by the payload's `rs` token. "council" is a wire value kept for compatibility;
-- the ruleset it names is "officers decide", because nothing in the product ever ran a
-- council vote and the label said otherwise.
local RULESET_LABEL = {
    council = "Officers decide",
    weighted = "Weighted ranking",
    rankThenRoll = "Rank, then roll",
}

--[[
    Mark which characters on this card are guests.

    `pug` is a list of indexes into chars, additive and optional: a payload built for the
    guild rather than for one raid has no such field, and neither does one from a server
    that predates guests. Both must import exactly as they do today, which is why every
    branch here is a silent no-op rather than an error.

    Marked on the char itself so every candidate referencing it inherits the flag.
    Candidates are assembled from four different places - wishlists, officer prios, the
    live raid roster, and the session - and a separate lookup in each is four chances to
    miss one.

    A separate field rather than a ResponseTier. Tier says how much they want the item;
    being a guest says who they are, and an officer needs both at once. "Guest, and this
    is their top pick" is the read - not a choice between the two.

    Indexes are 0-based, matching chars, which ProcessLootImport keys that way because the
    payload's own references are 0-based. Anything that does not resolve is skipped: a
    stale index must not create a phantom character, and tonumber() is applied because JSON
    decoders differ on whether array members arrive as numbers or strings.
]]
local function MarkGuests(chars, pug)
    if type(pug) ~= "table" then return end
    for _, index in ipairs(pug) do
        local char = chars[tonumber(index)]
        if char then char.isPug = true end
    end
end

--[[
    A character name with any realm suffix removed.

    Two naming conventions meet on the candidate card and they do not agree. The payload
    splits "Name-Realm" into name and realm at import; GetRaidRosterInfo hands back the
    whole "Name-Realm" for anyone on a connected realm and a bare name for everyone else.
    Comparing those raw means a connected-realm player never matches their own payload
    row - so they appear twice, once with their wishlist and once bare and unranked.

    That lands hardest on exactly the people this has to get right. Guests are usually
    the cross-realm ones, so the duplicate row is the guest's, and the bare copy carries
    no Guest tag. GetGroupPresence already strips the same way for the same reason.

    Wrapped in parentheses because gsub returns a replacement count as its second value,
    and callers use this as a table key and as an argument.
]]
local function ShortName(name)
    if type(name) ~= "string" then return nil end
    return (name:gsub("%-.*$", ""))
end

--[[
    Tell the raid that lists are loaded, and therefore fixed for tonight.

    The raid is the audience because the raid is who it concerns. Every other signal this
    addon produces is for the officer holding it: the summary line goes to their chat frame,
    the card opens on their screen. A raider has no way to know the moment their list stopped
    counting - and that moment is exactly when they would want to know, because after it,
    editing is pointless. The server refuses the write once the raid is InProgress; silence
    here is what makes somebody try anyway and then argue about it.

    Sent to RAID and only from a raid. Outside one there is nobody to tell, and pasting a
    string while organising in a guild channel should not broadcast anywhere.

    Deliberately not gated on the officer being loot master or on a session being active. The
    fact being announced is about the lists, not about the session: an officer who pastes an
    hour early has still fixed what tonight is decided from.

    Roster-only payloads say a different thing, because for those guilds nothing is locked -
    there are no wishlists to freeze, and claiming otherwise would be a lie told to the whole
    raid at once.
]]
local function AnnounceImport(self, charCount, wisherCount, hasLootData)
    if not self.Loot:GetSetting("announceLootImport") then return end
    if not IsInRaid() then return end

    local message
    if hasLootData then
        message = string.format(
            "Raidify: loot lists loaded for %d raiders (%d with wishlists). Lists are locked for tonight - edits from here on will not count.",
            charCount, wisherCount)
    else
        message = string.format("Raidify: roster loaded for %d raiders.", charCount)
    end

    SendChatMessage(message, "RAID")
end

--[[
    Process a loot payload import.

    Stores into self.lootData rather than the AceDB profile: it is raid-scoped, can be
    regenerated from the web in seconds, and saving a full roster's wishlists into
    SavedVariables on every /reload is a lot of disk for data with a short shelf life.
]]
function Raidify:ProcessLootImport(data)
    if type(data.chars) ~= "table" or #data.chars == 0 then
        return false, "That loot payload has no characters in it."
    end

    local chars = {}
    for index, entry in ipairs(data.chars) do
        -- chars[i] = { "Name-Realm", "CLASS", raidGroupIndex or nil }
        local key = entry[1]
        if type(key) == "string" then
            local name, realm = key:match("^([^%-]+)%-?(.*)$")
            chars[index - 1] = {          -- payload indexes are 0-based
                key = key,
                name = name or key,
                realm = (realm ~= "" and realm) or nil,
                class = entry[2],
                groupIndex = entry[3],
            }
        end
    end

    MarkGuests(chars, data.pug)

    local loot = {
        guild = data.g,
        generatedAt = data.ts,
        ruleset = data.rs or "council",
        rulesetLabel = RULESET_LABEL[data.rs or "council"] or "Officers decide",
        entitlements = data.ent or {},
        chars = chars,
        groups = data.groups,
        council = data.council,
        wishlists = data.wl,
        prios = data.prio,
        rules = data.rules,
        vars = data.vars,
        classLocks = data.cls,
    }

    -- A free guild's payload carries the roster and nothing else. That is a valid
    -- standalone session, not a broken import, so say so plainly instead of erroring.
    loot.hasLootData = (data.wl ~= nil) or (data.prio ~= nil)

    self.lootData = loot

    -- Survives a logout now, so a disconnect mid-raid does not cost the officer their
    -- wishlists and priorities at the worst possible moment.
    self.Loot:SaveLootData(loot)
    self.Loot:MarkUsed()

    local wishers = 0
    if data.wl then
        for _ in pairs(data.wl) do wishers = wishers + 1 end
    end

    local summary = string.format("Loot data imported: %d characters", #data.chars)
    if loot.hasLootData then
        summary = summary .. string.format(", %d with wishlists", wishers)
    else
        summary = summary .. " (roster only - this guild has no loot suite, sessions will run standalone)"
    end

    AnnounceImport(self, #data.chars, wishers, loot.hasLootData)

    return true, summary
end

--[[
    Who is actually in the group right now, as a name set.

    Returns nil when the answer is unknowable or meaningless - solo, or in no group at
    all. Callers must treat nil as "do not filter", because a card opened outside a raid
    to look something up should still show its candidates.

    Cross-realm names arrive as "Name-Realm" from the roster API while wishlist names are
    bare, so the realm is stripped for the comparison. Two players with the same name on
    different realms in one raid would collide here; that is a raid the game itself makes
    nearly impossible to assemble in Classic, and the failure is a false "present", which
    is the same answer this returned for everyone before.
]]
function Raidify:GetGroupPresence()
    if not IsInRaid() and not IsInGroup() then return nil end

    local present = {}
    local function mark(name)
        if not name or name == "" then return end
        present[(name:gsub("%-.*$", ""))] = true
    end

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            mark((GetRaidRosterInfo(i)))
        end
    else
        for i = 1, GetNumGroupMembers() - 1 do
            mark(UnitName("party" .. i))
        end
    end
    mark(UnitName("player"))

    return present
end


--[[
    What this raider has already been given tonight.

    The fact a council actually argues about at the moment of a drop — "didn't Bob already
    get a weapon an hour ago?" — and until now the card could not answer it. Every other
    input was on the row (prio, tier, rank, attendance, days since loot) while the one
    piece of evidence generated by this very session was sitting in session.awards,
    uncomputed and unread.

    Mainspec and offspec are counted separately and never summed. An offspec award is
    explicitly free — it stays out of the numbers that follow a raider around, on the
    website and in the payload — so folding it into one figure here would reintroduce at
    the point of decision exactly the cost the offspec flag exists to remove.

    Matched on the character key when both sides have one, falling back to the bare name.
    The key is "Name-Realm" for cross-realm raiders and awards store whichever the roster
    gave them, so comparing names alone would merge two raiders with the same name from
    different realms — rare, and precisely the case an officer would never think to check.
]]
local function WonTonight(session, char)
    if not session or type(session.awards) ~= "table" then return 0, 0 end

    local key = char.key
    local name = char.name
    local mainspec, offspec = 0, 0

    local charHasRealm = key ~= nil and key:find("-", 1, true) ~= nil

    for _, award in ipairs(session.awards) do
        -- Dispositions (bank, disenchant, free roll) and resolved items have no winner.
        -- Nobody took those home, so they are nobody's tally.
        local won = award.winner
        local hit = false

        if won then
            if won == key then
                hit = true
            elseif charHasRealm then
                -- This candidate names a realm, so an exact key match is the only honest
                -- one. A differing key is a different raider; a bare-name award carries no
                -- realm at all and cannot be attributed to this one rather than a
                -- same-named raider elsewhere. Guessing here would put someone else's loot
                -- on this row, which is worse than showing nothing.
                hit = false
            else
                -- No realm on our side either — a raid-derived candidate carries only what
                -- the group roster gave us. Name is the best evidence available, and
                -- refusing to match on it would undercount the ordinary case to guard
                -- against a rare one.
                hit = (award.winnerName or won) == name
            end
        end

        if hit then
            if award.offspec then offspec = offspec + 1 else mainspec = mainspec + 1 end
        end
    end

    return mainspec, offspec
end


--[[
    Everyone who wants a given item id, best response first.

    Returns a list of { char, rank, tier, prio, eligible }, where prio is the officer
    priority position (nil when unprioed) and eligible is false when the game itself
    would not let that class use the item.

    Sorted the way a council reads a card: officer priority first because it is an
    explicit decision, then response tier, then wishlist rank.
]]
function Raidify:GetLootCandidates(itemId)
    -- No import at all is a valid state: a guild with no loot suite runs standalone and
    -- gets its whole card from the raid below, so this cannot return early.
    local loot = self.lootData

    local key = tostring(itemId)
    local candidates = {}
    local seen = {}

    if loot and loot.wishlists then
        for charIndex, entries in pairs(loot.wishlists) do
            local char = loot.chars[tonumber(charIndex)]
            if char then
                for _, entry in ipairs(entries) do
                    if tostring(entry[1]) == key then
                        seen[charIndex] = true
                        table.insert(candidates, {
                            char = char,
                            rank = entry[2],
                            tier = entry[3],
                            tierOrder = TIER_ORDER[entry[3]] or UNRANKED_ORDER,
                        })
                    end
                end
            end
        end
    end

    -- Officer prios can name someone who never wishlisted the item - that is the
    -- point of a prio, so they belong on the card even with no wishlist row.
    if loot and loot.prios and loot.prios[key] then
        for position, charIndex in ipairs(loot.prios[key]) do
            local char = loot.chars[charIndex]
            if char then
                local existing
                for _, c in ipairs(candidates) do
                    if c.char == char then existing = c break end
                end
                if existing then
                    existing.prio = position
                else
                    table.insert(candidates, {
                        char = char,
                        prio = position,
                        tierOrder = UNRANKED_ORDER,
                    })
                end
            end
        end
    end

    -- Everyone else in the raid belongs on the card too, unranked. A raider with no list
    -- is not declining the item - ResponseTier.Pass exists to say that - so excluding them
    -- turns "did not do homework" into "loses the item", aimed squarely at the raiders we
    -- are trying to onboard. They sort below anyone who did list it and above anyone
    -- absent, which is what "unranked, not excluded" means in a sorted card.
    --
    -- This used to be an all-or-nothing fallback: the raid appeared only when NOBODY had
    -- wishlisted. So two names on a list beat twenty present raiders who had none, and
    -- once absent candidates are marked that gets worse, not better - the card could show
    -- two offline names and no way to give the item to anyone actually there.
    --
    -- Names are compared short on both sides, and a raid name that matches a payload
    -- character adopts that character rather than the synthetic one built from the roster.
    --
    -- Adopting is what puts the Guest tag on the card. isPug lives on the payload char, and
    -- most drops are on nobody's wishlist - the comment above says so - so without this a
    -- flagged guest arrives down this path as a bare { name, key, class } table and renders
    -- exactly like a guild member. The tag would have been correct on the minority of drops
    -- and silently absent on the rest, which is worse than never having shipped it: an
    -- officer reads "no tag" as "one of ours" and hands a stranger a weapon on that basis.
    local byShortName = {}
    if loot and loot.chars then
        for _, c in pairs(loot.chars) do
            local short = ShortName(c.name)
            if short then byShortName[short] = c end
        end
    end

    for _, extra in ipairs(self:GetRaidRosterCandidates(itemId)) do
        local short = ShortName(extra.char.name)
        local known = short and byShortName[short]
        if known then extra.char = known end

        local dup = false
        for _, c in ipairs(candidates) do
            if ShortName(c.char.name) == short then dup = true break end
        end
        if not dup then table.insert(candidates, extra) end
    end

    -- A wishlist is guild-wide; the raid is not. Without this the top name on the card
    -- was whoever had the best claim in the whole guild, present or not, and the officer
    -- clicking down the list had nothing telling them the winner was offline.
    local present = self:GetGroupPresence()

    local session = self.lootSession

    for _, c in ipairs(candidates) do
        c.wonTonight, c.wonOffspecTonight = WonTonight(session, c.char)
        c.eligible = self:IsClassEligibleForItem(itemId, c.char.class)
        c.present = present == nil or present[c.char.name] == true
        -- IndexOfChar returning nil would look up loot.vars["nil"] rather than nothing, so
        -- the index has to be checked before it is used as a key.
        --
        -- This no longer skips raid-derived candidates. It used to, because a synthetic
        -- roster char could never be in loot.chars - but one that matched a payload
        -- character now adopts it above, and it is the same person either way. Withholding
        -- their attendance because the card happened to reach them through the roster half
        -- would show the officer two different rows for one raider depending on whether
        -- they wishlisted this particular item. Guests resolve here too and find nothing,
        -- which is correct: the server deliberately sends no vars for them.
        local index = loot and self:IndexOfChar(c.char) or nil
        c.vars = index and loot.vars and loot.vars[tostring(index)] or nil
    end

    table.sort(candidates, function(a, b)
        -- Presence outranks everything, including an officer prio. A prio is a promise
        -- about who should get the item when they are here, not a claim on it in absentia.
        if a.present ~= b.present then return a.present end
        if (a.prio ~= nil) ~= (b.prio ~= nil) then return a.prio ~= nil end
        if a.prio and b.prio and a.prio ~= b.prio then return a.prio < b.prio end
        if a.tierOrder ~= b.tierOrder then return a.tierOrder < b.tierOrder end
        return (a.rank or 99) < (b.rank or 99)
    end)

    return candidates
end


--[[
    Everyone currently in the raid (or party, or just you), as candidates.

    Most drops are on nobody's wishlist, and the council still has to award them -
    offspec, a fresh alt, someone who simply needs it. A card with no clickable names
    cannot record those, which is most of a raid night. This is also the standalone
    session path (LOOT_COUNCIL_PLAN 5.2 step 1): a guild with no loot suite gets its
    candidates entirely from here.

    Class-ineligible players are excluded outright rather than listed and marked. For
    wishlist candidates the marker explains why a known name is not winning; here the
    name was never a contender, so listing it is noise.
]]
function Raidify:GetRaidRosterCandidates(itemId)
    local candidates = {}

    local function add(name, class)
        if not name or name == "" then return end
        if not self:IsClassEligibleForItem(itemId, class) then return end
        table.insert(candidates, {
            char = { name = name, key = name, class = class },
            fromRaid = true,
            eligible = true,
            tierOrder = UNRANKED_ORDER,
        })
    end

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, _, _, _, _, class = GetRaidRosterInfo(i)
            add(name, class)
        end
    elseif IsInGroup() then
        for i = 1, GetNumGroupMembers() - 1 do
            local unit = "party" .. i
            if UnitExists(unit) then
                add(UnitName(unit), select(2, UnitClass(unit)))
            end
        end
        add(UnitName("player"), select(2, UnitClass("player")))
    else
        add(UnitName("player"), select(2, UnitClass("player")))
    end

    table.sort(candidates, function(a, b) return a.char.name < b.char.name end)
    return candidates
end

--[[
    Can this class use the item at all?

    Only the game's own restriction - the payload's `cls` map, which comes from the
    item's "Classes:" line. Armour type is deliberately NOT considered: Classic lets
    any class equip any armour, and shamans and druids legitimately take cloth caster
    gear, so filtering on it would hide real contenders from the council.
]]
function Raidify:IsClassEligibleForItem(itemId, class)
    local loot = self.lootData
    if not loot or not loot.classLocks then return true end

    local allowed = loot.classLocks[tostring(itemId)]
    if not allowed then return true end   -- no lock recorded means anyone

    for _, name in ipairs(allowed) do
        if name == class then return true end
    end
    return false
end

--[[ Reverse lookup: which payload index is this character? ]]
function Raidify:IndexOfChar(char)
    local loot = self.lootData
    if not loot then return nil end
    for index, c in pairs(loot.chars) do
        if c == char then return index end
    end
    return nil
end

--[[ Standing rule for an item (AlwaysBank / AlwaysDisenchant / HardReserve / ...). ]]
function Raidify:GetItemStandingRule(itemId)
    local loot = self.lootData
    if not loot or not loot.rules then return nil end
    return loot.rules[tostring(itemId)]
end

--[[ Is this player on the loot council for the imported guild? ]]
function Raidify:IsLootCouncilMember(name)
    local loot = self.lootData
    if not loot or not loot.council then return false end

    for _, index in ipairs(loot.council) do
        local char = loot.chars[index]
        if char and char.name == name then return true end
    end
    return false
end

--[[
    Am I recording right now?

    The one question this addon could not answer, and the one behind its most expensive
    failure: an officer realises at the second boss that they never ran /rf loot start, and
    nothing they can type tells them whether the first boss was captured. Every command
    described the IMPORT; none described the session.

    Printed first, and before the no-import early return below, because a session can run
    with no payload at all - a guild with no wishlists still records who got what - so
    hiding the session state behind "no loot data imported" hides it from exactly the guilds
    that have nothing else on screen.

    Four states, and the two that need action say what the action is:

      never started   nothing is being recorded, and nothing before now can be recovered
      recording       how long, how much
      stopped, unsent the night is finished and still on this machine
      stopped, sent   done
]]
function Raidify:PrintLootSessionState()
    local session = self.lootSession

    if not session or not session.startedAt then
        self:Print("|cffD3A96FNot recording.|r /rf loot start begins the night - "
            .. "anything that drops before that is not captured.")
        return
    end

    local awarded, queued = #session.awards, #session.queue

    if session.active then
        local mins = math.floor((time() - session.startedAt) / 60)
        local since = mins < 1 and "just started"
            or (mins < 60 and string.format("%d min", mins)
            or string.format("%dh %02dm", math.floor(mins / 60), mins % 60))
        self:Print(string.format(
            "|cff72B68FRecording|r - %s, %d awarded, %d waiting.", since, awarded, queued))
        return
    end

    -- Stopped. Whether the night has left this machine is the whole difference between
    -- "finished" and "about to be lost", so it is the part that gets the colour.
    if session.exportedAt then
        self:Print(string.format("Stopped and sent. %d awarded.", awarded))
    else
        self:Print(string.format(
            "|cffD3A96FStopped, not sent.|r %d awarded, still on this machine - "
                .. "run the companion, or /rf loot export.", awarded))
    end
end

--[[
    /rf loot - what did we actually receive?

    Deliberately verbose: this is the first thing anyone runs when an import "did not
    work", and a summary that only says "ok" makes that conversation longer.
]]
function Raidify:PrintLootSummary()
    self:PrintLootSessionState()

    local loot = self.lootData
    if not loot then
        self:Print("No loot data imported. Use /rf import and paste the string from the Loot & Records page.")
        return
    end

    local charCount = 0
    for _ in pairs(loot.chars) do charCount = charCount + 1 end

    self:Print(string.format("Loot data for |cffEAB444%s|r - %d characters, ruleset: %s",
        loot.guild or "unknown guild", charCount, loot.rulesetLabel))

    if loot.generatedAt then
        -- Client clocks are not authoritative and are routinely wrong by hours, so a
        -- payload can legitimately look like it came from the future. Report that
        -- honestly instead of printing a negative age.
        local age = time() - loot.generatedAt
        if age < 0 then
            self:Print("Generated just now (your client clock is behind the server).")
        else
            local mins = math.floor(age / 60)
            if mins > 120 then
                self:Print(string.format("|cffD3A96FGenerated %d hours ago|r - regenerate if wishlists changed since.",
                    math.floor(mins / 60)))
            elseif mins < 1 then
                self:Print("Generated less than a minute ago.")
            else
                self:Print(string.format("Generated %d minutes ago.", mins))
            end
        end
    end

    if not loot.hasLootData then
        self:Print("Roster only - this guild has no Loot & Records suite, so sessions run standalone.")
        return
    end

    local wishers, wants = 0, 0
    if loot.wishlists then
        for _, entries in pairs(loot.wishlists) do
            wishers = wishers + 1
            wants = wants + #entries
        end
    end
    local prioed = 0
    if loot.prios then for _ in pairs(loot.prios) do prioed = prioed + 1 end end
    local locked = 0
    if loot.classLocks then for _ in pairs(loot.classLocks) do locked = locked + 1 end end
    local ruled = 0
    if loot.rules then for _ in pairs(loot.rules) do ruled = ruled + 1 end end

    self:Print(string.format("%d wishlists covering %d wants | %d items with officer priority",
        wishers, wants, prioed))
    if ruled > 0 then self:Print(string.format("%d items have a standing rule", ruled)) end
    if locked > 0 then self:Print(string.format("%d items are class-restricted", locked)) end
    if loot.council then
        self:Print(string.format("%d council members can vote", #loot.council))
    end
end
