--[[
    LootTrade.lua - handing out what the master looter is carrying.

    THE WORKFLOW THIS SERVES. Most guilds no longer assign loot off the corpse. The master
    looter takes everything, the raid keeps moving, and the items go out later — between
    pulls, or at the end of the night. That is the whole reason this addon queues drops
    instead of demanding a decision while twenty-four people wait.

    It leaves one problem the addon did not solve: awarding an item records a decision and
    nothing else. The item is still in the master looter's bags, and remembering to hand
    out eleven things to nine people at 23:15 is exactly the kind of bookkeeping people get
    wrong. What gets missed is not noticed until someone asks a week later.

    So: track what is owed, say so, and when a trade opens with that person put the items
    in the window.

    WHAT IS AND IS NOT POSSIBLE. An addon cannot open a trade, and it cannot accept one.
    Both are protected, and no addon does either — including Gargul. It CAN move an item
    from a bag into an open trade window, which is what this does. The human still opens
    the trade and still presses accept, which is the right place for the last check anyway.
]]

local Raidify = _G.Raidify

-- See LootPage.lua: no global GetItemInfo on Forever, identical tuple from C_Item.
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
if not Raidify or not Raidify.Loot then return end

local Loot = Raidify.Loot

--[[
    Container API shim.

    C_Container arrived in 10.0 and was backported to Classic (1.14.4 / 2.5.4), so on the
    Interface versions this addon targets it is present — but "should be present" is how
    addons break on a patch day, and the fallback costs three lines.
]]
local GetContainerNumSlots = (C_Container and C_Container.GetContainerNumSlots)
    or _G.GetContainerNumSlots
local GetContainerItemID = (C_Container and C_Container.GetContainerItemID)
    or _G.GetContainerItemID
--[[
    UseContainerItem is how an item actually gets into a trade window.

    Not PickupContainerItem + ClickTradeButton, which is what this file did first: that
    works by moving the cursor, and Gargul — which has been doing this in production for
    years — uses UseContainerItem instead. With the trade window open it places the item
    directly, with no cursor state to leak if anything goes wrong halfway.

    It is also the reason every call below is guarded on TradeFrame:IsShown(). "Use" on a
    container item with NO trade window open does exactly what it says: it equips the
    armour or drinks the potion.
]]
local UseContainerItem = (C_Container and C_Container.UseContainerItem)
    or _G.UseContainerItem
local GetContainerItemLink = (C_Container and C_Container.GetContainerItemLink)
    or _G.GetContainerItemLink

--[[
    WHICH COPY. Item ids are not identity.

    Two copies of one item in the same bags are two different physical items with two
    different clocks, and everything here used to key on the item id alone. So a master
    looter carrying a spare of something they had awarded - a duplicate BoE from the same
    run, a personal trinket - could hand over the wrong one, and the ledger would record the
    award as delivered while the real time-boxed copy stayed in the bag and soulbound two
    hours later. Nobody finds out until the raider asks where their item went.

    So an award reserves a specific copy at the moment it is made, by GUID. Gargul does the
    same thing for the same reason.

    Gated, because C_Item.GetItemGUID does not exist on every Classic flavour - Gargul's own
    source carries the note that this only works on newer game versions. Where it is
    missing, selection falls back to the clock, which is weaker but not wrong: see
    FindItemInBags.
]]
local GetItemGuid = C_Item and C_Item.GetItemGUID
local MakeItemLocation = ItemLocation and ItemLocation.CreateFromBagAndSlot
local GUID_TRACKING = (GetItemGuid and MakeItemLocation) and true or false

local function BagSlotGuid(bag, slot)
    if not GUID_TRACKING then return nil end
    -- pcall because an empty or unreadable slot raises rather than returning nil, and a
    -- bag scan that errors halfway reads as "the item is gone".
    local ok, location = pcall(MakeItemLocation, ItemLocation, bag, slot)
    if not ok or not location then return nil end
    local readable, guid = pcall(GetItemGuid, location)
    if not readable then return nil end
    return guid
end

function Raidify:UsesGuidTracking()
    return GUID_TRACKING
end

--[[
    Awards from this session that the winner has not been handed yet.

    Derived rather than stored: the awards list is already the record, and a second list of
    "outstanding" rows would be one more thing that can disagree with it.

    Dispositions are skipped - bank, disenchant and free-roll rows have no winner to trade
    with. So are test awards, which never correspond to an item anyone is carrying.
]]
function Raidify:GetOwedItems(playerName)
    local session = self.lootSession
    if not session or type(session.awards) ~= "table" then return {} end

    --[[
        Test rows count when the whole session is a test, and never otherwise.

        This excluded every isTest award unconditionally, which inverted the thing test mode
        exists for: the seeded awards - the ones with a fabricated clock, put there
        specifically so the owed list and its expiry warnings can be looked at outside a
        raid - were the rows being hidden, while awards made from the sample cards filled the
        list with items nobody is holding. The officer saw a "still to hand out" list of
        things they had just decided and none of the demonstration it was meant to show.

        Sessions are wholly test or wholly real (SampleSeedVerdict enforces it, and recovery
        refuses a seeded session from disk), so keying on the session cannot leak fabricated
        rows into a real night's owed list.
    ]]
    local allowTestRows = session.isTest == true

    local owed = {}
    for index, award in ipairs(session.awards) do
        if award.winner and not award.tradedAt and not award.resolved
            and (allowTestRows or not award.isTest) then
            local name = award.winnerName or award.winner
            -- Compare on the bare name: the trade partner is a unit, and UnitName gives a
            -- name without a realm for anyone you can actually stand next to.
            local bare = name and name:match("^([^%-]+)") or name
            if not playerName or bare == playerName then
                table.insert(owed, { index = index, award = award, name = bare })
            end
        end
    end
    return owed
end

--[[ Everyone still waiting on something, in the order they were awarded. ]]
function Raidify:GetOwedSummary()
    local byPlayer, order = {}, {}
    for _, entry in ipairs(self:GetOwedItems(nil)) do
        if not byPlayer[entry.name] then
            byPlayer[entry.name] = {}
            table.insert(order, entry.name)
        end
        table.insert(byPlayer[entry.name], entry.award)
    end
    return byPlayer, order
end

--[[
    THE TWO-HOUR CLOCK.

    A bind-on-pickup item looted by the master looter can only be traded to another
    eligible looter for two hours. After that it is soulbound to them permanently and the
    raider it was awarded to can never receive it.

    That deadline is the hidden cost of the workflow this whole addon encourages: take
    everything, keep the raid moving, hand it out later. "Later" has a limit, and an owed
    list that does not know about it quietly invites an officer to miss it. Gargul tracks
    this per item and surfaces it; without it, this addon's convenience feature would be
    encouraging exactly the behaviour that loses items.

    There is no API for the remaining time - it exists only as a line of tooltip text - so
    it has to be read the way Gargul reads it. The patterns are built from Blizzard's own
    localised duration strings rather than hardcoded English, so this works outside enUS.
]]

--[[
    "%d hours" / "%d min" / "%d sec" in whatever language the client is running.

    Grouped BY UNIT rather than flattened into one list, and each group is tried longest
    pattern first, stopping at the first hit. Both matter: the singular form is usually a
    prefix of the plural, so "(%d+) hour" happily matches inside "2 hours" and a flat list
    counts that item twice — two hours became four in testing.
]]
local DURATION_UNITS = {}
do
    local formats = {
        [INT_SPELL_DURATION_HOURS] = 3600,
        [INT_SPELL_DURATION_MIN] = 60,
        [INT_SPELL_DURATION_SEC] = 1,
    }
    for format, seconds in pairs(formats) do
        if type(format) == "string" then
            local group = { seconds = seconds, patterns = {} }
            -- Turn "%d hours" into "(%d+) hours", keeping each word as its own pattern so
            -- singular and plural forms both match.
            local prefix = ""
            local stripped = format:gsub("%%d(%s?)", function(space)
                prefix = "(%d+)" .. space
                return ""
            end)

            -- Blizzard writes plurals as "|4min:mins;" and resolves them before the text
            -- is ever displayed, so the markup must come out or nothing will ever match.
            -- Splitting on the separators leaves both forms as separate candidates, which
            -- is what makes "1 hour" and "2 hours" both parse.
            stripped = stripped:gsub("|4", ""):gsub("[:;]", " ")

            for word in stripped:gmatch("(%S+)") do
                table.insert(group.patterns, prefix .. word)
            end

            -- Longest first, so the plural is tested before the singular it contains.
            table.sort(group.patterns, function(a, b) return #a > #b end)
            table.insert(DURATION_UNITS, group)
        end
    end
end

-- One scanning tooltip for the whole file, reused. Never GameTooltip: that would fight
-- whatever the player is hovering over.
local scanner = CreateFrame("GameTooltip", "RaidifyLootTradeScanner", nil, "GameTooltipTemplate")
scanner:SetOwner(UIParent, "ANCHOR_NONE")

--[[ Never expires. Used for ordinary items that were never bind-on-pickup. ]]
local FOREVER = math.huge

--[[
    What can we do with the item in this bag slot?

    Returns tradeable (boolean) and secondsLeft (number, FOREVER when unbound).
]]
local function InspectBagSlot(bag, slot)
    scanner:ClearLines()
    local ok = pcall(scanner.SetBagItem, scanner, bag, slot)
    if not ok then return false, 0 end  -- cannot read it, so do not touch it

    local needle = BIND_TRADE_TIME_REMAINING
        and BIND_TRADE_TIME_REMAINING:gsub("([%(%)%-%+%[%]])", "%%%1"):gsub("%%s", ".*")
        or nil

    for line = 1, scanner:NumLines() do
        local text = _G["RaidifyLootTradeScannerTextLeft" .. line]
        text = text and text:GetText()

        if text then
            -- Plain "Soulbound" with no countdown: bound for good, cannot be traded.
            if text == ITEM_SOULBOUND then return false, 0 end

            if needle and text:find(needle) then
                local total = 0
                for _, group in ipairs(DURATION_UNITS) do
                    for _, pattern in ipairs(group.patterns) do
                        local amount = text:match(pattern)
                        if amount then
                            total = total + (tonumber(amount) or 0) * group.seconds
                            break  -- one match per unit, or plurals count twice
                        end
                    end
                end
                return total > 0, total
            end
        end
    end

    -- No soulbound line and no countdown: an ordinary tradeable item.
    return true, FOREVER
end

--[[
    Find the best copy of an item to hand over.

    Best, not first. Two copies of one item are two different items with two different
    clocks — Gargul keys them by item GUID for exactly this reason — so returning whichever
    turned up first could pick the one with four minutes left while a fresh one sits in the
    next slot, or one that has already bound while a tradeable copy exists.

    Bank bags are not searched: you cannot trade out of the bank, and scanning a container
    that is not open returns nils rather than erroring, which would read as "the item is
    gone" rather than "I cannot see it".
]]
local function FindItemInBags(itemId, wantGuid)
    local bestBag, bestSlot, bestLeft = nil, nil, nil

    for bag = 0, 4 do
        local slots = GetContainerNumSlots and GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            if GetContainerItemID and GetContainerItemID(bag, slot) == itemId then
                local tradeable, secondsLeft = InspectBagSlot(bag, slot)
                if tradeable then
                    if wantGuid then
                        -- Exactly the copy this award reserved, or nothing. Nothing is a
                        -- fact worth having: it means that copy has left the bags.
                        if BagSlotGuid(bag, slot) == wantGuid then
                            return bag, slot, secondsLeft
                        end
                    elseif not bestLeft or secondsLeft < bestLeft then
                        --[[
                            Lowest clock, not highest.

                            This asked for the copy with the MOST time left, which is
                            backwards twice over. An item that was never bind-on-pickup
                            reports FOREVER, so a personal spare always outranked the
                            actual awarded copy; and between two ticking copies, handing
                            over the one that expires last leaves the urgent one to rot.
                            Give away what is about to expire and keep what is not.
                        ]]
                        bestBag, bestSlot, bestLeft = bag, slot, secondsLeft
                    end
                end
            end
        end
    end

    if wantGuid then return nil end
    return bestBag, bestSlot, bestLeft
end

--[[
    Reserve a copy for an award being made right now.

    Skips copies already spoken for by another undelivered award, so two people awarded the
    same item get two different physical items rather than both pointing at one. Lowest
    clock first, matching FindItemInBags and Gargul: the copy closest to expiring is the one
    that has to move.

    Returns nil where GUID tracking is unavailable, and every caller treats nil as "fall
    back to the clock" rather than an error.
]]
function Raidify:ReserveAwardedItem(itemId)
    if not GUID_TRACKING then return nil end

    local claimed = {}
    for _, entry in ipairs(self:GetOwedItems(nil)) do
        if entry.award.itemGuid then claimed[entry.award.itemGuid] = true end
    end

    local bestGuid, bestLeft = nil, nil
    for bag = 0, 4 do
        local slots = GetContainerNumSlots and GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            if GetContainerItemID and GetContainerItemID(bag, slot) == itemId then
                local guid = BagSlotGuid(bag, slot)
                if guid and not claimed[guid] then
                    local tradeable, secondsLeft = InspectBagSlot(bag, slot)
                    if tradeable and (not bestLeft or secondsLeft < bestLeft) then
                        bestGuid, bestLeft = guid, secondsLeft
                    end
                end
            end
        end
    end

    return bestGuid
end

--[[
    How long is left to hand this item over?

    nil when the item is not in the bags at all — already traded by hand, or never looted.
    FOREVER for anything that was never bind-on-pickup.
]]
function Raidify:GetTradeTimeRemaining(itemId, itemGuid)
    -- Test mode has no real loot, so fake a clock. Without this the expiry warnings are
    -- unreachable outside a raid, which means they ship untested every time.
    if self.IsTestMode and self:IsTestMode() then
        -- Spread the fake clock across the whole two hours. `itemId % 5400` gives adjacent
        -- ids adjacent seconds, and tier tokens are consecutive - so two owed items rendered
        -- the identical "(51m)" and the colour ladder this function exists to demonstrate
        -- (caution under 15 minutes, error at zero) was never reachable from the sample.
        local buckets = { 45, 780, 2400, 5100, 7100 }
        return buckets[(itemId % #buckets) + 1]
    end

    -- With a reserved copy this is that copy's own clock. Without one, two rows for the
    -- same item showed the same number even though the two physical items were bound at
    -- different moments.
    local bag, _, secondsLeft = FindItemInBags(itemId, itemGuid)
    if not bag then return nil end
    return secondsLeft
end

--[[ "1h 12m", "43m", "4m" — the shape a person would say out loud. ]]
function Raidify:FormatTradeTime(seconds)
    if not seconds or seconds == FOREVER then return nil end
    if seconds <= 0 then return "expired" end

    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    if hours > 0 then return string.format("%dh %dm", hours, minutes) end
    if minutes > 0 then return string.format("%dm", minutes) end
    return "under a minute"
end

--[[
    Put what this person is owed into the open trade window.

    ONE ITEM PER TICK, not a loop. Adding them all at once inside the TRADE_SHOW handler
    is what this did first, and Gargul's source carries a comment saying plainly that doing
    it instantly "can bug out the UI" — which is the sort of thing you only learn from
    having shipped it to thousands of raiders.

    Only ever ADDS. It does not accept, cannot accept, and must never try: the human
    pressing accept is the last check on something that moves real property, and removing
    it to save a click would be the wrong trade in every sense.
]]
local pendingAdds = {}
local addTicker = nil

local function StopAdding()
    if addTicker then
        addTicker:Cancel()
        addTicker = nil
    end
    wipe(pendingAdds)
end

local function ProcessNextAdd()
    -- Checked every single tick, not once at the start. If the window closed while items
    -- were still queued, "using" the next one would equip or consume it.
    if not (TradeFrame and TradeFrame:IsShown()) then
        StopAdding()
        return
    end

    local queued = table.remove(pendingAdds, 1)
    if not queued then
        StopAdding()
        return
    end

    local bag, slot = FindItemInBags(queued.itemId, queued.itemGuid)
    if bag and TradeFrame:IsShown() then
        UseContainerItem(bag, slot)
    end
end

function Raidify:FillTradeWindow(playerName)
    if not playerName then return 0 end

    local owed = self:GetOwedItems(playerName)
    if #owed == 0 then return 0 end

    StopAdding()

    local queued = 0
    for _, entry in ipairs(owed) do
        if queued >= 6 then break end  -- six tradeable slots
        local award = entry.award
        if FindItemInBags(award.itemId, award.itemGuid) then
            table.insert(pendingAdds, { itemId = award.itemId, itemGuid = award.itemGuid })
            queued = queued + 1
        end
    end

    if queued > 0 and C_Timer and C_Timer.NewTicker then
        addTicker = C_Timer.NewTicker(0.1, ProcessNextAdd, queued + 1)
    end

    return queued
end

--[[
    Mark what was traded, once the trade actually completed.

    Both sides accepting is not the same as the trade going through - either party can
    still back out, and a trade that fails must not leave the addon believing the item was
    handed over. So the items in the window are noted on accept and only committed when the
    game confirms completion.
]]
local pendingTrade = nil

local function NoteTradeContents(playerName)
    local ids = {}
    for tradeSlot = 1, 6 do
        local link = GetTradePlayerItemLink(tradeSlot)
        if link then
            local id = tonumber(link:match("item:(%d+)"))
            if id then ids[#ids + 1] = id end
        end
    end
    pendingTrade = { name = playerName, itemIds = ids }
end

local function CommitTrade()
    if not pendingTrade then return end

    local owed = Raidify:GetOwedItems(pendingTrade.name)
    local marked = 0

    --[[
        What crossed the window, and which award it settles.

        The item ids are the authority for WHAT was traded - captured on accept, before the
        bags change, so this never depends on how quickly the client updates them. The
        reserved GUID decides WHICH award of that item is now settled, which matters only
        when one person is owed two copies of the same thing.

        Counted rather than matched one-for-one, so two copies in the window settle two
        awards and one copy settles exactly one.
    ]]
    local remaining = {}
    for _, itemId in ipairs(pendingTrade.itemIds) do
        remaining[itemId] = (remaining[itemId] or 0) + 1
    end

    local function settle(award)
        local left = remaining[award.itemId] or 0
        if award.tradedAt or left <= 0 then return false end
        remaining[award.itemId] = left - 1
        award.tradedAt = time()
        marked = marked + 1
        return true
    end

    -- First the awards whose reserved copy has demonstrably left the bags.
    for _, entry in ipairs(owed) do
        local award = entry.award
        if award.itemGuid and not FindItemInBags(award.itemId, award.itemGuid) then
            settle(award)
        end
    end

    -- Then anything still outstanding, oldest award first.
    for _, entry in ipairs(owed) do
        settle(entry.award)
    end

    if marked > 0 then
        Raidify.Loot:SaveSession(Raidify.lootSession)
        Raidify:Print(string.format("Handed %s to |cFFEFF4F6%s|r.",
            Raidify:Plural(marked, "item"), pendingTrade.name))
        if Raidify.RefreshCurrentPage then Raidify:RefreshCurrentPage() end
        if Raidify.RefreshDashboard then Raidify:RefreshDashboard() end
    end

    pendingTrade = nil
end

--[[
    Warn while something can still be done about it.

    A countdown nobody looks at is decoration. The moment worth interrupting an officer is
    when an item is close enough to expiring that they can still walk over and trade it,
    and far enough out that walking over will work — fifteen minutes.

    Once per item, ever. A warning that repeats every minute for the rest of the raid is an
    addon people disable, and the second one carries no information the first did not.
]]
local WARN_BELOW_SECONDS = 15 * 60
local warned = {}

local function CheckExpiringItems()
    local owed = Raidify:GetOwedItems(nil)
    if #owed == 0 then return end

    for _, entry in ipairs(owed) do
        local award = entry.award
        local key = tostring(award.itemId) .. ":" .. tostring(award.awardedAt)

        if not warned[key] then
            local left = Raidify:GetTradeTimeRemaining(award.itemId, award.itemGuid)

            -- nil means it is not in the bags: already handed over by hand, or never
            -- looted. Nothing to warn about either way.
            if left and left ~= math.huge and left <= WARN_BELOW_SECONDS then
                warned[key] = true
                local name = GetItemInfo(award.itemId) or ("item " .. award.itemId)
                Raidify:PrintWarning(string.format(
                    "%s for %s can only be traded for another %s.",
                    name, entry.name, Raidify:FormatTradeTime(left) or "moment"))
            end
        end
    end
end

-- Once a minute. The window is two hours, so anything finer is spending CPU on tooltip
-- scans to tell an officer something they already heard.
if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(60, function()
        Loot:Safe("trade time check", CheckExpiringItems)
    end)
end

--[[
    Say at login if this client cannot do what the feature promises.

    Every API here was verified against one client. If a build or a locale is missing any
    of them, the failure mode is the addon appearing to do nothing — no error, no clue, and
    an officer who assumes the items went in and accepts an empty trade.

    Checked once, reported once, and only when something is actually absent. A working
    install stays silent, which is the only acceptable behaviour for a login message.
]]
local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")

    Loot:Safe("trade support check", function()
        local missing = {}
        if not UseContainerItem then table.insert(missing, "UseContainerItem") end
        if not GetContainerItemID then table.insert(missing, "GetContainerItemID") end
        if not GetContainerNumSlots then table.insert(missing, "GetContainerNumSlots") end
        if not BIND_TRADE_TIME_REMAINING then table.insert(missing, "trade timer text") end

        if #missing == 0 then return end

        print("|cFFEAB444Raidify Loot|r: |cFFD3A96Fthis client is missing "
            .. table.concat(missing, ", ")
            .. " - automatic trades and trade timers are off.|r /rf loot report has details.")

        -- Refuse rather than half-work. A feature that silently does nothing is worse
        -- than one that says it cannot run.
        Loot:SetSetting("autoFillTrades", false)
    end)
end)

--[[
    Events.

    Own frame rather than core's event bus, for the same reason every other file here uses
    one: an error in a handler registered on the shared Ace3 object surfaces as an error in
    core Raidify, which is the blast radius the sub-addon split exists to prevent.
]]
--[[
    Bags changed, so the owed list changed.

    Everything the "still to hand out" list says about an item — how long is left on it,
    whether it is even in the bags — is read from the bags at draw time. Hand something over
    by hand rather than through the addon, or loot a second copy, and the list kept saying
    the old thing until the ten-second ticker came round, or forever if the page was not
    open when it happened.

    BAG_UPDATE_DELAYED rather than BAG_UPDATE: the delayed one fires once after a burst
    settles, which is what looting a corpse or completing a trade actually is. Gargul reads
    the same event for the same reason. NotifyLootChanged coalesces anyway, so a noisy bag
    still costs one redraw.
]]
local bags = CreateFrame("Frame")
bags:RegisterEvent("BAG_UPDATE_DELAYED")
bags:SetScript("OnEvent", function()
    -- Only when there is something to say. A guild not running loot, or an officer between
    -- sessions, should not be redrawing anything every time they pick up a herb.
    local session = Raidify.lootSession
    if not session or type(session.awards) ~= "table" or #session.awards == 0 then return end
    if Raidify.NotifyLootChanged then Raidify:NotifyLootChanged() end
end)

local trade = CreateFrame("Frame")
trade:RegisterEvent("TRADE_SHOW")
trade:RegisterEvent("TRADE_ACCEPT_UPDATE")
trade:RegisterEvent("TRADE_CLOSED")
trade:RegisterEvent("UI_INFO_MESSAGE")

trade:SetScript("OnEvent", function(_, event, arg1, arg2)
    Loot:Safe("trade handling", function()
        if event == "TRADE_SHOW" then
            -- "NPC" is the trade partner, oddly named but correct for a player trade.
            local partner = UnitName("NPC")
            if not partner then return end

            local owed = Raidify:GetOwedItems(partner)
            if #owed == 0 then return end

            if Loot:GetSetting("autoFillTrades") ~= true then
                -- Still say something. The whole failure this file addresses is an officer
                -- not remembering, and a silent addon is no better than no addon.
                Raidify:Print(string.format("|cFFD3A96F%s is owed %d item(s)|r from tonight.",
                    partner, #owed))
                return
            end

            local queued = Raidify:FillTradeWindow(partner)
            if queued > 0 then
                Raidify:Print(string.format("Adding %d item(s) for |cFFEFF4F6%s|r. "
                    .. "|cFF7F888BCheck the window before you accept.|r", queued, partner))
            else
                -- Owed something, but nothing tradeable is in the bags: either already
                -- handed over by hand, or bound and past its trade window.
                Raidify:PrintWarning(string.format(
                    "%s is owed %d item(s), but none of them are in your bags and tradeable.",
                    partner, #owed))
            end

        elseif event == "TRADE_ACCEPT_UPDATE" then
            -- arg1 = player accepted, arg2 = target accepted.
            if arg1 == 1 and arg2 == 1 then
                NoteTradeContents(UnitName("NPC"))
            end

        elseif event == "UI_INFO_MESSAGE" then
            -- The only reliable "it actually went through" signal. TRADE_CLOSED fires
            -- whether the trade completed or somebody hit escape.
            -- arg1 = message type, arg2 = the message itself.
            if arg2 == ERR_TRADE_COMPLETE then CommitTrade() end

        elseif event == "TRADE_CLOSED" then
            --[[
                Deliberately does NOT clear pendingTrade.

                TRADE_CLOSED fires BEFORE the completion message, not after — Gargul's
                source says so in as many words, and it is the kind of ordering nobody
                guesses right. Clearing here is what the first version of this file did,
                and it meant CommitTrade always found nothing staged: every delivery would
                have gone unrecorded, silently, forever.

                Stop adding items, since the window is gone. Leave the staged contents for
                the completion message that is about to arrive.
            ]]
            StopAdding()
        end
    end)
end)
