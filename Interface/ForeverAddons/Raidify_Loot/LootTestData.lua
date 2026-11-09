--[[
    LootTestData.lua - a believable guild's loot data, without a guild.

    WHY THIS EXISTS. Core's test mode fills the addon with a mock 25-man so the roster,
    assignment and dashboard screens can be looked at outside a raid. It stops there: it
    fabricates PEOPLE, not their wishlists. So with test mode on, the loot card showed
    twenty-five names with no rank, no tier, no priority and no attendance — every row
    identical, which is the one arrangement that proves nothing about a card whose entire
    job is ordering rows.

    This fills the rest in: wishlists, officer priorities, the ruleset, and the decision
    variables an officer weighs. The result is a card that sorts, chips that appear, and a
    Loot page with something on it.

    TWO RULES IT FOLLOWS:

    1. Real data always wins. If a guild has imported a payload, this never runs — it fills
       a gap, it does not override anyone's actual wishlists. A test mode that could
       silently replace real loot data would be worse than no test mode.

    2. Nothing here is ever exported. A seeded session is marked and ExportLootSession
       refuses it outright — not row by row, because the payload carries attendance as well
       as awards, and a half-scrubbed export is worse than none: it looks legitimate and
       writes fiction into a guild's permanent record.
]]

local Raidify = _G.Raidify
if not Raidify or not Raidify.Loot then return end

--[[
    Items the mock wishlists are built from.

    Deliberately Karazhan and T4-era, matching the TBC presets core ships, so the names
    resolve to something an officer recognises rather than a row of "item 12345".
]]
local TEST_ITEMS = {
    29760, 29761, 29762, 29763, 29764,  -- Karazhan drops
    28572, 28573, 28574, 28575,
    30219, 29267, 28802, 28797,
}

local TIERS = { "BiS", "Upgrade", "Minor", "Offspec" }

--[[
    Deterministic pseudo-random.

    Seeded from the character name and item, so the same raider always wants the same
    things with the same ranks across a /reload. A card that reshuffles every time it opens
    is useless for checking whether the sort is right.
]]
local function Hash(text, salt)
    local h = salt or 0
    for i = 1, #text do
        h = (h * 31 + text:byte(i)) % 2147483647
    end
    return h
end

--[[
    Build a loot payload from core's mock roster.

    Shape matches ProcessLootImport's output exactly, because that is what every consumer
    reads. Building the real structure rather than a lookalike means the card, the page and
    the sort are exercising the same code paths a real import produces.
]]
function Raidify:BuildTestLootData()
    if not self.GetMockRoster then return nil end

    local roster = self:GetMockRoster()
    if not roster or #roster == 0 then return nil end

    local chars, wishlists, prios, vars = {}, {}, {}, {}

    for index, member in ipairs(roster) do
        local charIndex = index - 1  -- payload indexes are 0-based
        chars[charIndex] = {
            key = member.name,
            name = member.name,
            class = member.className,
            groupIndex = member.group,
        }

        -- Each raider wants three or four things, ranked. Ranks start at 1 per raider,
        -- which is what makes one item show "rank 1" for one person and "rank 3" for
        -- another — the case the card's sort exists to resolve.
        local wants = {}
        local seed = Hash(member.name)
        local wantCount = 3 + (seed % 2)

        for slot = 1, wantCount do
            local pick = TEST_ITEMS[((seed + slot * 7) % #TEST_ITEMS) + 1]
            local tier = TIERS[((seed + slot * 3) % #TIERS) + 1]
            -- Entry shape: { itemId, rank, tier } — same as the wire format.
            table.insert(wants, { pick, slot, tier })
        end
        wishlists[tostring(charIndex)] = wants

        -- Decision variables. Spread wide on purpose: an officer checking that attendance
        -- and drought actually render needs to see a low number next to a high one.
        vars[tostring(charIndex)] = {
            att = 55 + (seed % 46),          -- 55-100%
            dsl = seed % 90,                 -- 0-89 days since last mainspec
        }
    end

    -- A couple of officer priorities, so the "P1" marker and the prio-first sort are
    -- exercised. Two items only — a card where everyone is prioed tests nothing.
    if #roster >= 3 then
        prios[tostring(TEST_ITEMS[1])] = { 0, 2 }
        prios[tostring(TEST_ITEMS[2])] = { 1 }
    end

    return {
        guild = "Test Guild",
        generatedAt = time(),
        ruleset = "council",
        rulesetLabel = "Officers decide",
        entitlements = { "loot" },
        chars = chars,
        wishlists = wishlists,
        prios = prios,
        vars = vars,
        hasLootData = true,
        -- The flag every consumer of this data can check. Nothing that leaves the client
        -- may carry data with this set.
        isTestData = true,
    }
end

--[[
    Install it, or take it away again.

    Called when test mode flips. Only ever touches lootData that this file created, which
    is what keeps rule 1 true: a guild with a real import keeps it, and turning test mode
    off does not wipe what they imported this morning.
]]
--[[
    Drop a seeded session, refusing if real awards ever got mixed into it.

    Shared by "Clear samples" and by leaving test mode, because both have to make the same
    judgement and the cost of getting it wrong is a night nobody can rebuild. Seeding now
    refuses to touch a real session at all, so the mixed case should be unreachable — but
    this is the check standing between a tidy-up click and a deleted ledger, and a client
    carrying a session written by an older build can still be in exactly that state.
]]
local function ClearSeededSession(self)
    local session = self.lootSession
    if not session or not session.isTest then return true end

    local real = 0
    for _, award in ipairs(session.awards or {}) do
        if not award.isTest then real = real + 1 end
    end

    if real > 0 then
        self:PrintError(string.format(
            "This session has %d real award(s) mixed in with sample data - leaving it alone. "
                .. "/rf loot export to send the night first.", real))
        return false
    end

    self.lootSession = nil
    self.Loot:ClearSession()
    return true
end

function Raidify:SyncTestLootData()
    local testing = self.IsTestMode and self:IsTestMode()

    if testing then
        -- Never overwrite a real import.
        if self.lootData and not self.lootData.isTestData then return end
        self.lootData = self:BuildTestLootData()
        -- Deliberately NOT saved. SaveLootData refuses test data anyway, but not writing
        -- it at all is the clearer statement: fabricated wishlists must never survive a
        -- logout into what looks like a real import.
        return
    end

    if self.lootData and self.lootData.isTestData then
        self.lootData = nil
        -- Restore whatever real payload was stored before test mode was turned on.
        local stored = self.Loot:LoadLootData()
        if type(stored) == "table" then self.lootData = stored end
    end

    --[[
        The seeded SESSION goes with the seeded data.

        Clearing one and not the other was the whole bug. A seeded session is active with no
        endedAt, which is indistinguishable from a night interrupted by a crash: login
        recovery restored it, StartLootSession resumed it, every real award of the next raid
        landed in it, and the export refused the lot at the end of the night with the raid
        already logged off. Turning test mode off has to mean it, and so does the
        auto-disable that fires on joining a real raid.
    ]]
    ClearSeededSession(self)
end

--[[
    Seed a session with something to look at.

    /rf loot sim queues items but awards nothing, so the awards list, the "won tonight"
    chips and the Loot page's history all render empty — the states most worth checking are
    exactly the ones a fresh session cannot show.

    Marked isTest on every award so the export drops them. This is the rule-2 boundary and
    the reason the function refuses to run outside test mode at all.
]]
--[[
    Remove seeded loot data, leaving anything real alone.

    Called by core's ClearTestData. Both checks are on the marker rather than clearing
    outright: an officer who imported a real payload this morning and then looked at test
    mode must still have that payload afterwards.
]]
function Raidify:ClearTestLootData()
    if self.lootData and self.lootData.isTestData then
        self.lootData = nil
    end
    ClearSeededSession(self)
end

--[[
    May sample data take over whatever session is currently loaded?

    Pure, and separate from the seeding, because this predicate is where the damage happens
    in both directions. Too loose and fabricated awards land in a real night that then
    refuses to export. Too tight - as the first version was, refusing on any non-test
    session at all - and the husk left by starting and stopping tracking with nothing in
    between locks an officer out of the sample button permanently, with nothing on screen
    telling them how to get out of it.

    Returns one of:
      "seed"        nothing in the way, or it is already sample data
      "active"      a session is running; ending it is the officer's call, not ours
      "unexported"  a real night with something in it that has not been sent
      "discard"     an ended session holding nothing, or one already exported
]]
local function SampleSeedVerdict(session)
    if not session or session.isTest then return "seed" end

    local awarded = type(session.awards) == "table" and #session.awards or 0
    local queued = type(session.queue) == "table" and #session.queue or 0

    if session.active then return "active", awarded end
    if (awarded > 0 or queued > 0) and not session.exportedAt then
        return "unexported", awarded
    end
    return "discard", awarded
end

function Raidify:SeedTestLootSession()
    if not (self.IsTestMode and self:IsTestMode()) then
        self:PrintError("Test mode is off. Turn it on in Settings, or /rf test on.")
        return
    end

    self:SyncTestLootData()

    local loot = self.lootData
    if not loot or not loot.chars then
        self:PrintError("No test roster available.")
        return
    end

    --[[
        Never adopt a session this function did not create.

        This used to call StartLootSession and then carry on with whatever self.lootSession
        happened to be. StartLootSession refuses - correctly - when a real night has ended
        without being exported, but it returns without clearing anything, so the seed stamped
        isTest on the officer's real record, killed its export, and left "Clear samples"
        pointing straight at it. Two clicks from curiosity to a lost night, on the same page
        the real session lives on.

        But refuse on the CONTENTS, not merely on a session object existing. The first cut
        of this guard rejected any non-test session at all, which included the husk left
        behind by starting and stopping tracking with nothing in between: 0 awarded, 0
        queued, endedAt set, nothing anywhere to clear it. That is not a night anyone can
        lose, and refusing on it left the officer permanently unable to seed samples with no
        way out. An empty ended session is not a record; it is the absence of one.

        The refusal has to come first and it has to be loud. Sample data never mixes with a
        real night in either direction.
    ]]
    local verdict, awarded = SampleSeedVerdict(self.lootSession)

    if verdict == "active" then
        self:PrintError("You have a loot session running. /rf loot end first - sample "
            .. "data is never mixed into a real night.")
        return
    end

    if verdict == "unexported" then
        self:PrintError(string.format(
            "Last session ended with %d awarded and was never exported. /rf loot export "
                .. "to send it first - sample data is never mixed into a real night.",
            awarded))
        return
    end

    if verdict == "discard" then
        -- Ended with nothing in it, or already sent. There is no record here to protect, and
        -- leaving it in place is what trapped an officer who started and stopped tracking
        -- before reaching for the sample button.
        self.lootSession = nil
        self.Loot:ClearSession()
    end

    local existing = self.lootSession

    if not existing or not existing.active then
        self:StartLootSession(false)
    end

    -- Either the seeded session we already had, or one StartLootSession just created. If it
    -- refused for any other reason there is nothing here to mark, and nothing to damage.
    local session = self.lootSession
    if not session then return end

    -- Marks the whole session, not just its rows. ExportLootSession refuses on this,
    -- because the payload carries attendance too and a half-scrubbed export is worse than
    -- no export.
    session.isTest = true

    -- Three awards across three raiders, one of them twice, so "won 2 tonight" has
    -- something to report and the offspec chip has a case as well.
    local recipients = {}
    for i = 0, 3 do
        if loot.chars[i] then table.insert(recipients, loot.chars[i]) end
    end
    if #recipients < 2 then return end

    --[[
        One of the three is already handed over.

        Awarded and delivered are different states and the Loot page shows them in different
        places, so seeding all three as undelivered demonstrated only half of it. With one
        traded, "Given out tonight" reads three and "Still to hand out" reads two, which is
        the arrangement that makes the distinction obvious before an officer meets it on a
        real night with a two-hour clock running.
    ]]
    local plan = {
        { char = recipients[1], item = TEST_ITEMS[1], offspec = false, traded = true },
        { char = recipients[1], item = TEST_ITEMS[2], offspec = false },
        { char = recipients[2], item = TEST_ITEMS[3], offspec = true },
    }

    for _, entry in ipairs(plan) do
        table.insert(session.awards, {
            itemId = entry.item,
            winner = entry.char.key,
            winnerName = entry.char.name,
            winnerClass = entry.char.class,
            rank = 1,
            tier = "BiS",
            offspec = entry.offspec or nil,
            awardedAt = time(),
            tradedAt = entry.traded and time() or nil,
            -- Dropped by ExportLootSession. Fabricated awards must never reach the site.
            isTest = true,
        })
    end

    self.Loot:SaveSession(session)
    self:SimulateLootDrop(nil)

    self:Print(string.format(
        "Seeded %d test awards and queued some drops. |cFFD3A96FNothing here will be exported.|r",
        #plan))
end
