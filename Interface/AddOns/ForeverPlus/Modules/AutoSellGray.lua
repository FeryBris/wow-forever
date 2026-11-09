-- Sells gray items automatically whenever a merchant window opens.
--
-- Five things that go wrong in naive implementations:
--
-- 1. Do not gate on MerchantFrame:IsShown(). Whether that frame is called this
--    on 1.60.1 is unverified -- and even if it is, the order in which
--    MERCHANT_SHOW handlers run is not defined. Ours can run before Blizzard's,
--    so the frame may still be hidden while the merchant is long open. The
--    events themselves are the reliable source, so we track the state here.
--
-- 2. The server throttles rapid follow-up actions, and what it drops it drops
--    silently. The first version answered that by going slowly -- one item
--    every fifth of a second, which is four seconds for a bag of twenty and
--    feels like the addon has hung. It sells in batches instead and then
--    *looks again*: anything still there goes round once more. Checking is
--    both faster and stricter than being careful, because being careful never
--    actually verified anything.
--
--    Looking again is only worth anything once the bags have settled. A slot
--    whose sale has not resolved yet is *locked*, and a locked gray is neither
--    sellable nor gone -- it is unreadable. Checking too early therefore reads
--    as "nothing left" and leaves items behind in silence, which is precisely
--    what the check exists to prevent. So the scan waits, and if it still
--    finds locked grays it waits again rather than drawing a conclusion.
--
-- 3. Read the bags completely first, then sell. Scanning while selling reads
--    half-emptied bags.
--
-- 4. Every pass gets a number. Closing and immediately reopening a merchant
--    would otherwise start a second chain while the first is still running.
--
-- 5. Do not measure the earnings as GetMoney() before against after. The
--    credits arrive from the server with a delay, so anything measured right
--    after the last sale is short. The figure is the difference between what
--    was in the bags at the start and what is left at the end -- which also
--    means a retry cannot count the same item twice, as counting attempts
--    would have.
--
-- The amount is rendered by FP:Money, which shows coin icons.
--
-- Only quality 0 (gray) is ever sold.

local ADDON, FP = ...
local L, N = FP.L, FP.N

local M = FP:RegisterModule("AutoSellGray", {
    title    = L["Sell Gray Items"],
    default  = true,
    desc     = L["Sells gray items at any merchant."],
    group    = "merchant",
    order    = 40,
    options = {
        { key = "announce", type = "toggle", default = true,
          label = L["Report earnings in chat"],
          desc  = L["Shows the total value of sold items in chat."] },
        { key = "holdShiftStop", type = "toggle", default = true,
          label = L["Hold Shift to pause"],
          desc  = L["While Shift is down, nothing is sold."] },
    },
})

local POOR = 0      -- Enum.ItemQuality.Poor

-- Four sales every tenth of a second, against one every fifth of a second
-- before: roughly seven times the pace. The retry pass below is what makes
-- that safe to try -- without it, going faster would just mean losing more
-- quietly.
local BATCH      = 4
local DELAY      = 0.1
local SETTLE     = 0.5  -- before looking again: the bags need longer than a sale
local MAX_PASSES = 3    -- a merchant that refuses is not going to be worn down
local MAX_SETTLE = 6    -- how many times to wait for locks to clear

local queue    = {}
local run      = 0      -- pass number; invalidates stale chains
local passes   = 0
local settles  = 0
local unknown  = false  -- at least one item had no cached price
local merchantOpen = false  -- see point 1 above

-- What the bags held when the pass started, so that what actually left them
-- can be worked out at the end.
local startCount, startValue = 0, 0

-- GetContainerItemInfo returns a table on newer builds and a list of separate
-- values on older ones. Both are handled.
local function ItemInfo(bag, slot)
    local get = C_Container and C_Container.GetContainerItemInfo
    if not get then return nil end

    local info = get(bag, slot)
    if type(info) == "table" then
        return info.quality, info.hyperlink, info.isLocked, info.stackCount
    end
    -- Old format: icon, count, locked, quality, readable, lootable, link
    local _, count, locked, quality, _, _, link = get(bag, slot)
    return quality, link, locked, count
end

-- Sell price is per single item, so a stack is worth price * count.
local function SellPrice(link)
    local getInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
    if not (getInfo and link) then return nil end
    local ok, price = pcall(function() return select(11, getInfo(link)) end)
    return ok and price or nil
end

--- Fills the queue with every sellable gray item in the bags.
--
-- The locked count is not an aside. A locked slot is one whose last action has
-- not resolved, and its item is neither sellable nor known to be gone -- so a
-- scan that finds locked grays has not found out anything yet.
--
-- @return count, total value in copper, any price uncached, locked grays
local function Scan()
    wipe(queue)
    local lastBag = NUM_BAG_SLOTS or 4
    local value, anyUnknown, lockedGrays = 0, false, 0

    for bag = 0, lastBag do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local quality, link, locked, count = ItemInfo(bag, slot)
            if quality == POOR then
                if locked then
                    lockedGrays = lockedGrays + 1
                else
                    local price = SellPrice(link)
                    -- A price of 0 means no merchant wants it. nil only means
                    -- "not cached yet", so give those a try -- we just cannot
                    -- count them.
                    if price ~= 0 then
                        value = value + (price or 0) * (count or 1)
                        if price == nil then anyUnknown = true end
                        queue[#queue + 1] = { bag = bag, slot = slot }
                    end
                end
            end
        end
    end
    return #queue, value, anyUnknown, lockedGrays
end

-- They call each other, so both names have to exist before either body is
-- compiled. Lua resolves a name when it compiles the function that uses it,
-- and a local declared further down is not that local -- it is a global, and
-- a nil one.
local SellNext, Verify

local function Finish(id)
    if id ~= run then return end   -- stale pass

    -- What left the bags, rather than what we tried to sell. Counting attempts
    -- would count an item twice across a retry, and would count one the server
    -- refused outright.
    local leftCount, leftValue, _, stillLocked = Scan()
    wipe(queue)

    local soldCount = startCount - leftCount
    local soldValue = startValue - leftValue

    if M.db.announce and soldCount > 0 then
        FP:Print(FP:Plural(soldCount, N["Sold %d gray item for %s%s."],
                N["Sold %d gray items for %s%s."]),
            soldCount,
            unknown and L["at least "] or "",
            FP:Money(math.max(soldValue, 0)))
    end

    -- Only worth saying while the merchant is still there. Walking away mid-pass
    -- leaves items behind by definition, and being told so is just noise.
    if leftCount > 0 and merchantOpen and M.db.announce then
        -- Otherwise say it rather than leave it. Silence here is exactly how
        -- the slow version would have hidden the same thing.
        FP:Print(FP:Plural(leftCount, N["%d gray item could not be sold."],
            N["%d gray items could not be sold."]), leftCount)
    end

    -- Reached only if the locks never cleared, which is three seconds of
    -- waiting. Rare, and not something to leave unsaid when it happens.
    if stillLocked > 0 and merchantOpen and M.db.announce then
        FP:Print(FP:Plural(stillLocked,
            N["%d gray item still had a sale pending and could not be "
                .. "checked. Reopen the merchant if it is still there."],
            N["%d gray items still had a sale pending and could not be "
                .. "checked. Reopen the merchant if they are still there."]),
            stillLocked)
    end

    unknown = false
end

--- Looks again once the bags have settled, and goes round if anything is left.
--
-- Two different waits live here, and conflating them is what let two items
-- slip through the first time round. A locked gray means "ask again later";
-- an unlocked one means "this did not sell, try it". Only when neither is
-- there has anything actually been established.
function Verify(id)
    if id ~= run then return end
    if not merchantOpen then return Finish(id) end

    local left, _, _, locked = Scan()

    if locked > 0 and settles < MAX_SETTLE then
        settles = settles + 1
        C_Timer.After(SETTLE, function()
            FP:Safe("AutoSellGray:settle", Verify, id)
        end)
        return
    end

    if left == 0 then return Finish(id) end

    if passes >= MAX_PASSES then return Finish(id) end
    passes = passes + 1
    SellNext(id)
end

function SellNext(id)
    if id ~= run then return end

    if not merchantOpen then
        wipe(queue)
        return Finish(id)
    end

    for _ = 1, BATCH do
        local item = table.remove(queue, 1)
        if not item then break end
        C_Container.UseContainerItem(item.bag, item.slot)
    end

    -- More to sell: the short step. Nothing left to sell: the longer wait,
    -- because a sale takes far longer to show up in the bags than it does to
    -- send, and a check run too early finds nothing and says so.
    if #queue > 0 then
        C_Timer.After(DELAY, function()
            FP:Safe("AutoSellGray:step", SellNext, id)
        end)
    else
        C_Timer.After(SETTLE, function()
            FP:Safe("AutoSellGray:verify", Verify, id)
        end)
    end
end

--- Starts a selling pass.
-- @param verbose  also report when nothing happens (used by /fplus sell)
function M:Run(verbose)
    if not (C_Container and C_Container.UseContainerItem and C_Timer) then
        return FP:Warn(L["AutoSellGray: C_Container.UseContainerItem or C_Timer is missing."])
    end
    if self.db.holdShiftStop and IsShiftKeyDown() then
        if verbose then FP:Print(L["Shift is held, automation paused."]) end
        return
    end
    if not merchantOpen then
        if verbose then FP:Print(L["No merchant open."]) end
        return
    end

    run     = run + 1
    passes  = 0
    settles = 0

    local found, value, anyUnknown = Scan()
    if found == 0 then
        if verbose then FP:Print(L["No gray items in your bags."]) end
        return
    end

    if verbose then
        FP:Print(FP:Plural(found, N["Found %d gray item, selling ..."],
            N["Found %d gray items, selling ..."]), found)
    end

    startCount, startValue, unknown = found, value, anyUnknown
    SellNext(run)
end

--- Self-test: reports for each building block whether it exists on this build.
function M:SelfTest()
    local function state(ok) return ok and "|cff44ff44ok|r" or "|cffff5555missing|r" end
    local c = C_Container or {}

    FP:Print("AutoSellGray self-test:")
    local lines = {
        { "Merchant open (per event)", merchantOpen and "|cff44ff44yes|r" or "|cffff5555no|r" },
        { "MerchantFrame",             MerchantFrame and (MerchantFrame:IsShown() and "exists, shown" or "exists, hidden") or "|cffff5555missing|r" },
        { "C_Container",               state(C_Container ~= nil) },
        { "  GetContainerNumSlots",    state(c.GetContainerNumSlots ~= nil) },
        { "  GetContainerItemInfo",    state(c.GetContainerItemInfo ~= nil) },
        { "  UseContainerItem",        state(c.UseContainerItem ~= nil) },
        { "C_Timer.After",             state(C_Timer and C_Timer.After ~= nil) },
        { "GetCoinTextureString",      state(GetCoinTextureString ~= nil) },
        { "C_Item.GetItemInfo",        state(C_Item and C_Item.GetItemInfo ~= nil) },
        { "GetItemInfo (global)",      state(_G.GetItemInfo ~= nil) },
        { "NUM_BAG_SLOTS",             tostring(NUM_BAG_SLOTS) },
    }
    for _, l in ipairs(lines) do
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  |cffffffff%-26s|r %s", l[1], l[2]))
    end

    -- What does GetContainerItemInfo actually return? That decides which branch
    -- of ItemInfo applies.
    if c.GetContainerItemInfo then
        local sample = c.GetContainerItemInfo(0, 1)
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "  |cffffffff%-26s|r %s", "  return type (bag 0/1)", type(sample)))
    end

    if c.GetContainerNumSlots then
        local found, total, anyUnknown, locked = Scan()
        FP:Print("Gray items in range: %d, worth %s%s%s",
            found, anyUnknown and "at least " or "", FP:Money(total),
            locked > 0 and string.format(" (%d locked, not readable yet)", locked) or "")
        wipe(queue)
    end
end

function M:OnEnable()
    self.frame = self.frame or CreateFrame("Frame")
    self.frame:SetScript("OnEvent", function(_, event)
        if event == "MERCHANT_SHOW" then
            merchantOpen = true
            FP:Safe("AutoSellGray:Run", M.Run, M, false)
        elseif event == "MERCHANT_CLOSED" then
            merchantOpen = false
            run = run + 1
            wipe(queue)
        end
    end)
    self.frame:RegisterEvent("MERCHANT_SHOW")
    self.frame:RegisterEvent("MERCHANT_CLOSED")
end

function M:OnDisable()
    if self.frame then self.frame:UnregisterAllEvents() end
    run = run + 1
    merchantOpen = false
    wipe(queue)
end
