-- Reagents and poisons beside a merchant.
--
-- Gated with the owner on 2026-10-09 for 0.9.1: the two backlog entries of
-- 2026-10-07 in one, a button in the column beside a merchant for every
-- reagent the class's spells take, and for a Rogue one for every poison, each
-- buying what is missing for the amount set on the Gameplay page. His answers,
-- in full under *Reagents and poisons at the merchant* in ROADMAP.md:
--
--   * **Every reagent of the class**, whether its spell is learned or not.
--   * **A Rogue sees the poisons themselves**, the highest rank learned of
--     each, and a click buys the ingredients for the number asked for.
--     Crafting stays the player's.
--   * **A target per reagent and per rank of a poison**, a full stack to
--     start with. The page lists what the column can offer now, and every
--     other reagent and rank of the class under "Not Relevant Right Now", a
--     block that opens, the owner's wish of the same evening.
--   * **A poison's click buys the ingredients for the poisons still
--     missing**, whatever the bags hold of them: only finished poisons count,
--     the owner's rule once he had tried a first version that counted the
--     ingredients too. See FP:PoisonIngredients.
--   * **A poison's button that has just bought rests five seconds**, with a
--     check mark, so a second click cannot buy the same again; see
--     Core/Merchant.lua. Reagents count what arrived and need no rest.
--   * **A poison shows only where the merchant sells every ingredient.**
--   * **While the Legacy Tree's Reagent Economy is active, a reagent always
--     asks first**, with a red line saying the class's abilities need none
--     from a merchant, the owner's answer of 2026-10-09. Poisons are not
--     touched by it.
--   * A module of its own, on by default, asking before it buys, with "Do not
--     ask again" and "Skip the purchase dialog", as the quiver does. The
--     switch was "Buy without asking" until the owner found it sounding like
--     a purchase without any click, the same evening.
--
-- The column, the question and the purchase on its way are Core/Merchant.lua;
-- the reagents and the recipes are Data/Reagents.lua.
--
-- **FP:KnowsSpell sees a learned recipe**, measured on 2026-10-10 on another
-- skill's recipes, since nobody on this account has a Rogue at 20: true for a
-- First Aid recipe the owner's character knows, Heavy Linen Bandage 3276, and
-- false for one it does not, Wool Bandage 3277. A poison's recipe itself is
-- unseen; `/fplus reagents` says what it answers.

local ADDON, FP = ...
local L = FP.L
local Merchant = FP.Merchant
local AutoBuy  = FP.AutoBuy

-- A class and a level to act as, for testing on a character of another
-- class, the owner's request of 2026-10-09. Set by `/fplus reagents as` and
-- never saved: a reload ends it. Buying stays real.
local simulate

-- [itemID] = a count to act as if the bags held it, for testing a target
-- without the items, the owner's request of the same day. Set by
-- `/fplus reagents have` and never saved either.
local pretend = {}

-- true or false to act as if Reagent Economy were active or not, nil to ask
-- the client. Set by `/fplus reagents economy`, for testing the warning on a
-- character without the talent, and never saved.
local economyTest

--- How many of an item the bags hold, or what a test asked to pretend.
local function Count(item)
    if pretend[item] then return pretend[item] end
    return Merchant.Count(item)
end

local function ClassToken()
    if simulate then return simulate.class end
    if not UnitClass then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and FP:Plain(token) or nil
end

local function ReagentKey(item) return "reagent" .. item end

-- One target per rank of a poison, since the owner asked for every rank to
-- have its own on 2026-10-09; the one per kind before it, "poison_<kind>",
-- is a key nothing reads any more.
local function PoisonKey(rank) return "poison" .. rank.item end

local Targets, RefreshTargets   -- the list on the page, further down

-- The list of targets. Named so its steppers can ask whether the menu has
-- grayed it out, which it does with the module, like every setting there.
local LIST = { type = "custom", label = L["Reagents"],
    build   = function(holder, width, mod) return Targets(holder, width, mod) end,
    refresh = function(holder, mod) RefreshTargets(holder, mod) end }

-- Every target is a key of its own, declared here so a fresh profile gets
-- the owner's starting amount, and export carries them: a full stack, and
-- less for a rank below the highest of Rebirth and of every poison, see the
-- head of Data/Reagents.lua. One list for all classes: a profile can serve
-- characters of several.
local START = {}   -- [key] = the amount a target starts at
local options = {
    { key = "buyWithoutAsking", type = "toggle", default = false,
      label = L["Skip the purchase dialog"],
      desc  = L["A click on a button beside the merchant buys at once and "
           .. "reports the purchase in chat. Reagents always show the dialog "
           .. "when your class abilities do not require reagents from a "
           .. "merchant."] },
    LIST,
}
do
    local function Declare(key, start)
        if START[key] then return end
        START[key] = start
        options[#options + 1] = { key = key, type = "store", default = start }
    end
    -- A rank below the highest starts at `lower` where there is one.
    local function Start(stack, i, count, lower)
        if lower and i < count then return lower end
        return stack
    end
    for _, list in pairs(FP.CLASS_REAGENTS) do
        for _, entry in ipairs(list) do
            if entry.ranks then
                for i, rank in ipairs(entry.ranks) do
                    Declare(ReagentKey(rank.item),
                        Start(entry.stack, i, #entry.ranks, entry.lowerStart))
                end
            else
                Declare(ReagentKey(entry.item), entry.stack)
            end
        end
    end
    for _, poison in ipairs(FP.POISONS) do
        for i, rank in ipairs(poison.ranks) do
            Declare(PoisonKey(rank), Start(FP.POISON_STACK, i, #poison.ranks,
                FP.POISON_LOWER_START))
        end
    end
end

local M = FP:RegisterModule("Reagents", {
    title   = L["Reagents"],
    default = true,
    desc    = L["Beside a merchant, a button for each reagent your class "
           .. "uses and, for Rogues, each poison. A click buys what is "
           .. "missing for the amounts set here."],
    group   = "merchant",
    order   = 30,
    options = options,
})

-- ---------------------------------------------------------------------------
-- Items and recipes
-- ---------------------------------------------------------------------------

local function Target(key, default)
    local value = M.db and tonumber(M.db[key])
    if value == nil then return START[key] or default end
    return value
end

--- The client's icon for an item, from its own data without a server query.
local function ItemIcon(item)
    local get = (C_Item and C_Item.GetItemIconByID) or rawget(_G, "GetItemIconByID")
    if type(get) ~= "function" then return nil end
    local ok, icon = pcall(get, item)
    return ok and icon or nil
end

--- An item's name and link, or nil while the client has not loaded it yet,
--- in which case it is asked to.
local function ItemName(item)
    local get = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
    if get then
        local ok, name, link = pcall(get, item)
        if ok and FP:Plain(name) then return name, FP:Plain(link) end
    end
    local load = C_Item and C_Item.RequestLoadItemDataByID
    if load then pcall(load, item) end
    return nil
end

--- The item's icon and name, or its number until the client has the name.
local function Label(item)
    local text = ItemName(item) or ("#" .. item)
    local icon = ItemIcon(item)
    if icon then text = "|T" .. icon .. ":0|t " .. text end
    return text
end

local HOW_MANY = L["How many you want to carry. A Shift click changes it by a "
    .. "full stack."]

--- The highest rank of a poison the Rogue can make, or nil.
--
-- By its recipe being known; while acting as another class, by the recipe's
-- level against the level given.
local function BestRank(poison)
    for i = #poison.ranks, 1, -1 do
        local rank = poison.ranks[i]
        if simulate then
            if rank.level <= simulate.level then return rank end
        elseif FP:KnowsSpell(rank.recipe) then
            return rank
        end
    end
    return nil
end

--- Whether a spell of the table is learned: by the spell being known, or
--- while acting as another class by its level.
local function Learned(spell)
    if simulate then return spell.level <= simulate.level end
    return FP:KnowsSpell(spell.spell)
end

--- The reagent a class entry stands for now, or nil while it stands for none.
--
-- An entry with `ranks` stands for the reagent of the highest rank learned,
-- one with `spells` for its own reagent once one of them is learned and none
-- of `unless` is, and any other entry for its reagent always. See the head
-- of Data/Reagents.lua.
local function Current(entry)
    if entry.ranks then
        for i = #entry.ranks, 1, -1 do
            local rank = entry.ranks[i]
            if Learned(rank) then return { item = rank.item, stack = entry.stack } end
        end
        return nil
    end
    if entry.spells then
        for _, spell in ipairs(entry.unless or {}) do
            if Learned(spell) then return nil end
        end
        for _, spell in ipairs(entry.spells) do
            if Learned(spell) then return entry end
        end
        return nil
    end
    return entry
end

-- **Not measured how this build shows a Legacy Tree talent**: as a spell the
-- character knows, or as an aura on it. Both are asked, and `/fplus reagents`
-- prints each answer.
local function KnowsEconomy()
    return FP:KnowsSpell(FP.REAGENT_ECONOMY) and true or false
end

local function WearsEconomy()
    local get = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
    if type(get) ~= "function" then return false end
    local ok, aura = pcall(get, FP.REAGENT_ECONOMY)
    if not ok then return false end
    local usable, yes = pcall(function() return aura ~= nil end)
    return usable and yes or false
end

--- Whether Reagent Economy spares the class's abilities their reagents.
local function Economy()
    if economyTest ~= nil then return economyTest end
    return KnowsEconomy() or WearsEconomy()
end

--- The red line in the question while it does, under the talent's own name
--- from the client.
local function EconomyWarning()
    return L["%s is active: your class abilities need no reagents bought from "
        .. "a merchant."]:format(FP:SpellName(FP.REAGENT_ECONOMY) or "Reagent Economy")
end

-- ---------------------------------------------------------------------------
-- What a button would buy
-- ---------------------------------------------------------------------------

--- Everything a button knows about one reagent the merchant sells, or nil
--- when it does not sell it.
--
-- `amount` is what a click buys and `cost` what that costs. `reason` says why
-- a click would buy nothing, and is nil whenever it would buy something.
local function ReagentPlan(reagent, stock)
    local index = stock[reagent.item]
    if not index then return nil end
    local offer = Merchant.Offer(index)
    if not offer then return nil end

    local plan = {
        index = index, item = reagent.item, link = Merchant.Link(index),
        icon = offer.icon or ItemIcon(reagent.item),
        target = Target(ReagentKey(reagent.item), reagent.stack),
        have = Count(reagent.item), amount = 0, cost = 0,
    }
    if offer.extended or not offer.buyable or offer.stack < 1 then
        plan.reason = "merchant"
        return plan
    end

    local amount = FP:TopUp(plan.target, plan.have, offer.stack)
    if amount <= 0 then
        plan.reason = "enough"
        return plan
    end
    if offer.available >= 0 then
        amount = math.min(amount, offer.available * offer.stack)
        if amount <= 0 then
            plan.reason = "sold"
            return plan
        end
    end
    if offer.price > 0 and GetMoney then
        amount = math.min(amount, math.floor(GetMoney() / offer.price) * offer.stack)
        if amount <= 0 then
            plan.reason = "money"
            return plan
        end
    end

    plan.amount = amount
    plan.cost   = offer.price * amount / offer.stack
    return plan
end

--- Every poison the Rogue can make, with its target and what the bags hold of
--- the rank that would be made.
local function Poisons()
    local list = {}
    for _, poison in ipairs(FP.POISONS) do
        local rank = BestRank(poison)
        if rank then
            list[#list + 1] = {
                key = poison.key, rank = rank, takes = rank.takes,
                target = Target(PoisonKey(rank), FP.POISON_STACK),
                have = Count(rank.item),
            }
        end
    end
    return list
end

local function FindPoison(key)
    for _, poison in ipairs(Poisons()) do
        if poison.key == key then return poison end
    end
    return nil
end

--- Everything a button knows about one poison, or nil when the merchant does
--- not sell every ingredient it takes.
--
-- `buys` lists what a click buys, each { index, itemID, amount, link }, and
-- `makes` how many of the poison that is for.
local function PoisonPlan(poison, stock)
    for item in pairs(poison.takes) do
        if not stock[item] then return nil end
    end

    local needs, makes = FP:PoisonIngredients(poison.target, poison.have, poison.takes)

    local plan = {
        key = poison.key, item = poison.rank.item, icon = ItemIcon(poison.rank.item),
        target = poison.target, have = poison.have, makes = makes,
        buys = {}, cost = 0,
    }
    if makes == 0 then
        plan.reason = "enough"
        return plan
    end

    -- In a fixed order, so the question lists them the same way every time.
    local items = {}
    for item in pairs(needs) do items[#items + 1] = item end
    table.sort(items)
    for _, item in ipairs(items) do
        local index = stock[item]
        local offer = Merchant.Offer(index)
        if not offer or offer.extended or not offer.buyable or offer.stack < 1 then
            plan.reason = "merchant"
            return plan
        end
        local amount = FP:TopUp(needs[item], 0, offer.stack)
        if offer.available >= 0 and amount > offer.available * offer.stack then
            plan.reason = "sold"
            return plan
        end
        plan.buys[#plan.buys + 1] = { index = index, itemID = item, amount = amount,
            link = Merchant.Link(index) }
        plan.cost = plan.cost + offer.price * amount / offer.stack
    end

    if plan.cost > 0 and GetMoney and GetMoney() < plan.cost then
        plan.reason = "money"
    end
    return plan
end

-- ---------------------------------------------------------------------------
-- Buying
-- ---------------------------------------------------------------------------

local SKIP_TIP = L["Switches on \"Skip the purchase dialog\" under Reagents on "
    .. "the Gameplay page, where it can be switched off again."]

local REASONS = {
    enough   = L["You have enough."],
    sold     = L["The merchant has none left."],
    money    = L["You cannot afford a stack."],
    merchant = L["Buy this one in the merchant window."],
}

local POISON_REASONS = {
    enough   = L["You have enough."],
    sold     = L["The merchant has none left."],
    money    = L["You cannot afford the ingredients."],
    merchant = L["Buy the ingredients in the merchant window."],
}

--- The row on the Gameplay page, should the window be open.
local function RefreshMenu()
    local menu = FP.modules and FP.modules.Menu
    if menu and menu.Refresh then FP:Safe("Menu:Refresh", menu.Refresh, menu) end
end

--- Buys a reagent up to its target. Worked out again first: the bags and the
--- money may have moved while the question stood.
-- @return how many were bought, what that cost, and the item's link
local function BuyReagent(reagent, planned)
    if not M.enabled then return 0 end
    local now = ReagentPlan(reagent, Merchant.Stock())
    if not now or now.reason then return 0 end
    local amount = math.min(planned.amount, now.amount)
    local bought = Merchant.Purchase({
        { index = now.index, itemID = now.item, amount = amount } })
    local n = bought and bought[now.item] or 0
    return n, (n > 0) and now.cost * n / now.amount or 0, now.link
end

-- While Reagent Economy spares the class's abilities their reagents, the
-- question always comes, with the red line, and without "Do not ask again":
-- a skipped question could never say it.
local function ClickReagent(reagent)
    local plan = ReagentPlan(reagent, Merchant.Stock())
    if not plan or plan.reason then return end
    local spared = Economy()
    if M.db.buyWithoutAsking and not spared then
        local n, cost, link = BuyReagent(reagent, plan)
        if n > 0 then FP:Print(L["Bought %d %s for %s."], n, link or "?", FP:Money(cost)) end
        return
    end
    Merchant.Ask({
        heading  = L["Buy Reagents"],
        question = L["Do you really want to buy %d %s? You will then have %d."]
            :format(plan.amount, plan.link or "?", plan.have + plan.amount),
        warning  = spared and EconomyWarning() or nil,
        cost     = plan.cost,
        skipTip  = not spared and SKIP_TIP or nil,
        onBuy    = function(skip)
            if skip then
                M.db.buyWithoutAsking = true
                RefreshMenu()
            end
            BuyReagent(reagent, plan)
        end,
    })
end

--- The ingredients a poison button buys, one line each.
local function IngredientLines(plan)
    local lines = {}
    for _, buy in ipairs(plan.buys) do
        lines[#lines + 1] = buy.amount .. " " .. (buy.link or "?")
    end
    return lines
end

--- Buys the ingredients for a poison, worked out again first.
-- @return the plan bought on, or nil
local function BuyPoison(key)
    if not M.enabled then return nil end
    local poison = FindPoison(key)
    if not poison then return nil end
    local now = PoisonPlan(poison, Merchant.Stock())
    if not now or now.reason then return nil end
    local bought = Merchant.Purchase(now.buys, "poison:" .. key)
    if not (bought and next(bought)) then return nil end
    return now
end

local function ClickPoison(key)
    local poison = FindPoison(key)
    if not poison then return end
    local plan = PoisonPlan(poison, Merchant.Stock())
    if not plan or plan.reason then return end
    local _, link = ItemName(plan.item)

    if M.db.buyWithoutAsking then
        local now = BuyPoison(key)
        if now then
            FP:Print(L["Bought the ingredients for %d %s for %s."], now.makes,
                link or "?", FP:Money(now.cost))
        end
        return
    end
    Merchant.Ask({
        heading  = L["Buy Poison Ingredients"],
        question = L["Do you really want to buy the ingredients for %d %s?"]
            :format(plan.makes, link or "?"),
        lines    = IngredientLines(plan),
        cost     = plan.cost,
        skipTip  = SKIP_TIP,
        onBuy    = function(skip)
            if skip then
                M.db.buyWithoutAsking = true
                RefreshMenu()
            end
            BuyPoison(key)
        end,
    })
end

-- ---------------------------------------------------------------------------
-- The buttons
-- ---------------------------------------------------------------------------

--- The merchant's own card for the reagent, and below it what a click does.
local function ReagentTooltip(tip, reagent)
    local plan = ReagentPlan(reagent, Merchant.Stock())
    if not plan then return end
    if not pcall(tip.SetMerchantItem, tip, plan.index) and plan.link then
        pcall(tip.SetHyperlink, tip, plan.link)
    end
    tip:AddLine(" ")
    tip:AddLine(L["You have %d of %d."]:format(plan.have, plan.target), 1, 1, 1)
    if plan.reason then
        tip:AddLine(REASONS[plan.reason], 0.6, 0.6, 0.6, true)
    elseif Merchant.Waiting() then
        tip:AddLine(L["Waiting for the previous purchase to complete."], 0.6, 0.6, 0.6, true)
    else
        tip:AddLine(L["Click to buy %d."]:format(plan.amount), 1, 1, 1, true)
        tip:AddLine(L["Cost: %s"]:format(FP:Money(plan.cost)), 1, 1, 1)
    end
end

--- The game's own card for the poison, and below it what a click buys.
local function PoisonTooltip(tip, key)
    local poison = FindPoison(key)
    if not poison then return end
    local plan = PoisonPlan(poison, Merchant.Stock())
    if not plan then return end
    local _, link = ItemName(plan.item)
    local shown = tip.SetItemByID and pcall(tip.SetItemByID, tip, plan.item)
    if not shown and link then pcall(tip.SetHyperlink, tip, link) end

    tip:AddLine(" ")
    tip:AddLine(L["You have %d of %d."]:format(plan.have, plan.target), 1, 1, 1)
    if Merchant.JustBought("poison:" .. key) then
        tip:AddLine(L["Just bought."], 0.1, 1, 0.1, true)
    elseif plan.reason then
        tip:AddLine(POISON_REASONS[plan.reason], 0.6, 0.6, 0.6, true)
    elseif Merchant.Waiting() then
        tip:AddLine(L["Waiting for the previous purchase to complete."], 0.6, 0.6, 0.6, true)
    else
        tip:AddLine(L["Click to buy the ingredients for %d."]:format(plan.makes),
            1, 1, 1, true)
        for _, line in ipairs(IngredientLines(plan)) do tip:AddLine(line, 1, 1, 1) end
        tip:AddLine(L["Cost: %s"]:format(FP:Money(plan.cost)), 1, 1, 1)
    end
end

local AMOUNT_TIP = L["Changes how many you want to carry, the same amount as "
    .. "under Reagents on the Gameplay page."]

--- What a button's arrow changes: the item's target, the same one its
--- stepper on the Gameplay page shows, which follows a change made here.
local function AmountFor(key, item, stack)
    return {
        key = key, stack = stack, max = stack * 10,
        get = function() return Target(key, stack) end,
        set = function(value)
            M.db[key] = value
            RefreshMenu()
        end,
        title = function() return Label(item) end,
        tip = AMOUNT_TIP, stepTip = HOW_MANY,
    }
end

local AUTO_TIP = L["Buys it automatically up to this amount whenever you open "
    .. "a merchant who sells it."]

--- Auto Buy's tick for an item, the same one the reagent list shows, while
--- Auto Buy is on. See Modules/AutoBuy.lua.
local function AutoFor(key, item)
    if not (AutoBuy and AutoBuy.On()) then return nil end
    return {
        get   = function() return AutoBuy.Is(key) end,
        set   = function(on)
            AutoBuy.Set(key, on)
            RefreshMenu()
        end,
        title = function() return Label(item) end,
        tip   = AUTO_TIP,
    }
end

--- The buttons for the column: the class's reagents the merchant sells, and
--- a Rogue's poisons whose ingredients it sells.
local function Provide()
    if not M.enabled then return nil end
    local token = ClassToken()
    local stock = Merchant.Stock()
    local specs = {}

    for _, entry in ipairs(FP.CLASS_REAGENTS[token] or {}) do
        local reagent = Current(entry)
        local plan = reagent and ReagentPlan(reagent, stock)
        if plan then
            specs[#specs + 1] = {
                icon    = plan.icon,
                count   = (plan.amount > 0) and tostring(plan.amount) or nil,
                state   = plan.reason and "gray" or nil,
                tooltip = function(tip) ReagentTooltip(tip, reagent) end,
                click   = function() ClickReagent(reagent) end,
                amount  = AmountFor(ReagentKey(reagent.item), reagent.item,
                    reagent.stack),
                auto    = AutoFor(ReagentKey(reagent.item), reagent.item),
            }
        end
    end

    if token == "ROGUE" then
        for _, poison in ipairs(Poisons()) do
            local plan = PoisonPlan(poison, stock)
            if plan then
                local key = poison.key
                specs[#specs + 1] = {
                    id      = "poison:" .. key,
                    icon    = plan.icon,
                    count   = (not plan.reason and plan.makes > 0)
                        and tostring(plan.makes) or nil,
                    state   = plan.reason and "gray" or nil,
                    tooltip = function(tip) PoisonTooltip(tip, key) end,
                    click   = function() ClickPoison(key) end,
                    amount  = AmountFor(PoisonKey(poison.rank), poison.rank.item,
                        FP.POISON_STACK),
                    auto    = AutoFor(PoisonKey(poison.rank), poison.rank.item),
                }
            end
        end
    end
    return specs
end
Merchant.AddProvider("Reagents", 20, Provide)

--- One thing Auto Buy buys, with its line in the question and in chat.
local function AutoEntry(index, item, amount, cost, link)
    return {
        index = index, itemID = item, amount = amount, cost = cost,
        line = amount .. " " .. (link or "?"),
        said = function(n)
            return L["Bought %d %s for %s."]:format(n, link or "?",
                FP:Money(cost * n / amount))
        end,
    }
end

--- What Auto Buy buys here: every reagent ticked up to its target, and for
--- every poison ticked the ingredients still missing for its target, counting
--- the finished poisons and the ingredients the bags already hold, all
--- poisons together, since several share a vial. Unlike a poison's button,
--- which buys for the poisons missing whatever the bags hold: Auto Buy comes
--- back at every merchant, and would buy the same ingredients each time.
local function AutoPlan()
    if not M.enabled then return nil end
    local token = ClassToken()
    local stock = Merchant.Stock()
    local entries, reagents = {}, 0

    for _, entry in ipairs(FP.CLASS_REAGENTS[token] or {}) do
        local reagent = Current(entry)
        if reagent and AutoBuy.Is(ReagentKey(reagent.item)) then
            local plan = ReagentPlan(reagent, stock)
            if plan and not plan.reason then
                reagents = reagents + 1
                entries[#entries + 1] = AutoEntry(plan.index, plan.item,
                    plan.amount, plan.cost, plan.link)
            end
        end
    end

    if token == "ROGUE" then
        local need = {}
        for _, poison in ipairs(Poisons()) do
            local sold = true
            for item in pairs(poison.takes) do
                if not stock[item] then sold = false end
            end
            if sold and AutoBuy.Is(PoisonKey(poison.rank)) then
                local buy = FP:PoisonIngredients(poison.target, poison.have, poison.takes)
                for item, n in pairs(buy) do need[item] = (need[item] or 0) + n end
            end
        end
        -- In a fixed order, so the question lists them the same way every time.
        local items = {}
        for item in pairs(need) do items[#items + 1] = item end
        table.sort(items)
        for _, item in ipairs(items) do
            local index = stock[item]
            local offer = Merchant.Offer(index)
            if offer and not offer.extended and offer.buyable and offer.stack >= 1 then
                local amount = FP:TopUp(need[item], Count(item), offer.stack)
                if offer.available >= 0 then
                    amount = math.min(amount, offer.available * offer.stack)
                end
                if amount > 0 then
                    entries[#entries + 1] = AutoEntry(index, item, amount,
                        offer.price * amount / offer.stack, Merchant.Link(index))
                end
            end
        end
    end

    return {
        entries = entries,
        warning = (reagents > 0 and Economy()) and EconomyWarning() or nil,
    }
end
if AutoBuy then AutoBuy.AddProvider("Reagents", AutoPlan) end

-- ---------------------------------------------------------------------------
-- The amounts on the Gameplay page
--
-- One stepper per reagent of the class and, for a Rogue, per poison rank,
-- under the item's own name and icon from the client: what the column can
-- offer now first, the rest under "Not Relevant Right Now". Built for what
-- the page meets, and again when that changes, with a rank learned or while
-- acting as another class.
-- ---------------------------------------------------------------------------


--- The steppers the page shows, and those under "Not Relevant Right Now":
--- every reagent and every poison rank of the class has its place in one of
--- the two. Shown is what the column can offer now, the reagent each entry
--- stands for and the highest rank learned of each poison, in the column's
--- order; the rest keeps the order of the tables, lowest rank first.
local function Lists()
    local token = ClassToken()
    local shown, others = {}, {}
    local function Add(list, key, item, stack)
        list[#list + 1] = { key = key, item = item, stack = stack }
    end
    for _, entry in ipairs(FP.CLASS_REAGENTS[token] or {}) do
        local current = Current(entry)
        for _, reagent in ipairs(entry.ranks or { entry }) do
            local list = (current and current.item == reagent.item) and shown or others
            Add(list, ReagentKey(reagent.item), reagent.item, entry.stack)
        end
    end
    if token == "ROGUE" then
        local best = {}
        for i, poison in ipairs(FP.POISONS) do
            best[i] = BestRank(poison)
            if best[i] then
                Add(shown, PoisonKey(best[i]), best[i].item, FP.POISON_STACK)
            end
        end
        for i, poison in ipairs(FP.POISONS) do
            for _, rank in ipairs(poison.ranks) do
                if rank ~= best[i] then
                    Add(others, PoisonKey(rank), rank.item, FP.POISON_STACK)
                end
            end
        end
    end
    return shown, others
end


--- What the list was built for: the class and where each item sits, which
--- changes with a rank learned as well as with acting as another class.
local function Who()
    local shown, others = Lists()
    -- Auto Buy's ticks come and go with it, which is a new list as well.
    local parts = { tostring(ClassToken()), tostring(AutoBuy and AutoBuy.On()) }
    for _, row in ipairs(shown) do parts[#parts + 1] = row.item end
    parts[#parts + 1] = "rest"
    for _, row in ipairs(others) do parts[#parts + 1] = row.item end
    return table.concat(parts, ":")
end

-- Whether "Not Relevant Right Now" is open. Shut at every login: it is view
-- state, like the folded blocks on the other pages, not a setting.
local othersOpen = false

local ROW_H = 26

--- Puts every part of the list under the one before it, the steppers under
--- "Not Relevant Right Now" only while it is open, and answers the height.
local function Layout(holder)
    local y = 0
    for _, part in ipairs(holder.parts or {}) do
        if part.folded and not othersOpen then
            part.frame:Hide()
        else
            part.frame:ClearAllPoints()
            part.frame:SetPoint("TOPLEFT", part.x or 0, -(y + (part.dy or 0)))
            if not part.x then part.frame:SetPoint("TOPRIGHT", 0, -y) end
            part.frame:Show()
            y = y + part.height
        end
    end
    return math.max(y, 1)
end

local function BuildRows(holder, mod)
    for _, part in ipairs(holder.parts or {}) do part.frame:Hide() end
    holder.parts, holder.rows = {}, {}
    holder.who = Who()

    local function Put(frame, height, part)
        part = part or {}
        part.frame, part.height = frame, height
        holder.parts[#holder.parts + 1] = part
    end

    local shown, others = Lists()
    if #shown == 0 then
        holder.empty = holder.empty or FP:FontString(holder, "OVERLAY", "faint")
        -- A class with reagents whose spells are not learned yet, a Druid
        -- below Rebirth, says so rather than that it takes none.
        holder.empty:SetText((#others > 0)
            and L["None of your spells that require reagents have been "
             .. "learned yet."]
            or L["Your class uses no reagents."])
        Put(holder.empty, 24, { x = FP.ROW_TEXT_X, dy = 4 })
    end

    -- Grayed out with the module, a stepper says why, lights up the module's
    -- row and changes nothing, as every setting the menu draws does: its own
    -- hover covers the list's.
    local function HowMany()
        local why = FP:WhyDisabled(mod, LIST)
        if not why then return HOW_MANY end
        return FP:T(HOW_MANY) .. "|n|n" .. FP:T(why)
    end

    local function Stepper(row)
        local stepper = FP:CreateStepper(holder, Label(row.item), {
            min = 0, max = row.stack * 10, step = 1, bigStep = row.stack,
            Get = function() return Target(row.key, row.stack) end,
            Set = function(value)
                if FP:OptionDisabled(mod, LIST) then return end
                mod.db[row.key] = value
                FP:Safe("Merchant:Refresh", Merchant.Refresh)
            end,
        })
        FP:ApplyLevel(stepper, "sub")
        local function Name() return Label(row.item) end
        FP:Tooltip(stepper, Name, HowMany)
        FP:Tooltip(stepper.tooltipTargets, Name, HowMany)
        FP:PointOptionAtCause(stepper, mod, LIST)

        -- Auto Buy's tick, in the gap before the name where a row's box
        -- goes, while Auto Buy is on. Per character, like the column's.
        if AutoBuy and AutoBuy.On() then
            local box = FP:CreateBox(stepper,
                function() return AutoBuy.Is(row.key) end,
                function(on)
                    if FP:OptionDisabled(mod, LIST) then return end
                    AutoBuy.Set(row.key, on)
                    FP:Safe("Merchant:Refresh", Merchant.Refresh)
                end)
            box:SetPoint("LEFT", FP.ROW_BOX_X - 3, 0)
            FP:Tooltip(box, Name, function()
                local why = FP:WhyDisabled(mod, LIST)
                if not why then return AUTO_TIP end
                return FP:T(AUTO_TIP) .. "|n|n" .. FP:T(why)
            end)
            FP:PointOptionAtCause(box, mod, LIST)
            stepper.autoBox = box
        end
        stepper.item = row.item
        holder.rows[#holder.rows + 1] = stepper
        return stepper
    end

    for _, row in ipairs(shown) do Put(Stepper(row), ROW_H) end

    -- Everything else of the class, so a target can be set before a rank or
    -- a spell is learned: a block that opens, as on the other pages, the
    -- owner's wish of 2026-10-09.
    if #others > 0 then
        local head, headHeight = FP:CollapsibleHeading(holder,
            L["Not Relevant Right Now"], nil,
            function() return othersOpen end,
            function() othersOpen = not othersOpen end)
        -- At the one level the module list has inside a module. The
        -- heading's own Refresh gives it the primary color on every click,
        -- so the level goes back on after it.
        local refresh = head.Refresh
        head.Refresh = function()
            refresh()
            FP:ApplyLevel(head, "sub")
        end
        head:Refresh()
        head.OnToggled = function() holder:Resize(Layout(holder)) end
        Put(head, headHeight)
        for _, row in ipairs(others) do
            Put(Stepper(row), ROW_H, { folded = true })
        end
    end
    return Layout(holder)
end

function Targets(holder, width, mod)
    return BuildRows(holder, mod)
end

--- When the page opens: the names the client has loaded since, and the list
--- built again if the class it was built for has changed.
function RefreshTargets(holder, mod)
    if holder.who ~= Who() then
        holder:Resize(BuildRows(holder, mod))
        return
    end
    for _, stepper in ipairs(holder.rows or {}) do
        stepper.text:SetText(Label(stepper.item))
        stepper:Refresh()
        if stepper.autoBox then stepper.autoBox:Refresh() end
    end
end

-- ---------------------------------------------------------------------------
-- Switching, testing, and what it sees
-- ---------------------------------------------------------------------------

function M:OnEnable()  FP:Safe("Merchant:Refresh", Merchant.Refresh) end
function M:OnDisable() FP:Safe("Merchant:Refresh", Merchant.Refresh) end
function M:Reapply()   FP:Safe("Merchant:Refresh", Merchant.Refresh) end

local CLASSES = { DRUID = true, HUNTER = true, MAGE = true, PALADIN = true,
    PRIEST = true, ROGUE = true, SHAMAN = true, WARLOCK = true, WARRIOR = true }

--- `/fplus reagents as CLASS [level]`: act as another class until the next
--- reload, `as off` to stop. The level only decides which poison recipes
--- count as learned; the reagents are every one of the class anyway.
function M:Simulate(args)
    local class, level = (args or ""):match("^(%S*)%s*(%d*)")
    class = (class or ""):upper()
    if class == "" or class == "OFF" then
        simulate = nil
        -- l10n: english, like every answer to a typed command
        FP:Print("Reagents: back to this character's own class.")
    elseif CLASSES[class] then
        simulate = { class = class, level = tonumber(level) or 60 }
        -- l10n: english
        FP:Print("Reagents: acting as a level %d %s until the next reload. "
            .. "Buying stays real.", simulate.level, class)
    else
        -- l10n: english
        return FP:Warn("Reagents: no class called %s.", class)
    end
    FP:Safe("Merchant:Refresh", Merchant.Refresh)
end

--- `/fplus reagents have <poison or item id> <count>`: act as if the bags
--- held that many until the next reload, `have off` to stop. A poison's name,
--- instant or mind-numbing, means the rank its button buys for.
function M:Pretend(args)
    local what, count = (args or ""):match("^(%S*)%s*(%d*)")
    what = (what or ""):lower()
    if what == "" or what == "off" then
        pretend = {}
        -- l10n: english, like every answer to a typed command
        FP:Print("Reagents: counting what the bags really hold again.")
        FP:Safe("Merchant:Refresh", Merchant.Refresh)
        return
    end

    local item = tonumber(what)
    if not item then
        local plain = what:gsub("%-", "")
        for _, poison in ipairs(FP.POISONS) do
            if poison.key:lower() == plain then
                item = (BestRank(poison) or poison.ranks[1]).item
            end
        end
    end
    if not item then
        -- l10n: english
        return FP:Warn("Reagents: no poison or item called %s.", what)
    end

    pretend[item] = tonumber(count) or 0
    -- l10n: english
    FP:Print("Reagents: acting as if the bags held %d of %s until the next "
        .. "reload.", pretend[item], ItemName(item) or ("item " .. item))
    FP:Safe("Merchant:Refresh", Merchant.Refresh)
end

--- `/fplus reagents economy on|off|auto`: act as if Reagent Economy were
--- active or not until the next reload, or ask the client again.
function M:EconomyTest(args)
    local word = (args or ""):match("^(%S*)"):lower()
    if word == "on" then
        economyTest = true
    elseif word == "off" then
        economyTest = false
    elseif word == "" or word == "auto" then
        economyTest = nil
    else
        -- l10n: english, like every answer to a typed command
        return FP:Warn("Reagents: economy takes on, off or auto.")
    end
    local state = "whatever the client says"                    -- l10n: english
    if economyTest ~= nil then
        state = economyTest and "active" or "not active"        -- l10n: english
    end
    -- l10n: english
    FP:Print("Reagents: Reagent Economy counts as %s until the next reload.", state)
end

--- `/fplus reagents`: what the module sees, in English like every
--- diagnosing command.
function M:Status()
    local token = ClassToken()
    FP:Print("Reagents for %s%s:", tostring(token),
        simulate and (", acting at level " .. simulate.level) or "")
    FP:Print("  Reagent Economy %d %s: known %s, aura %s%s, so %s",
        FP.REAGENT_ECONOMY, FP:SpellName(FP.REAGENT_ECONOMY) or "(no such spell)",
        tostring(KnowsEconomy()), tostring(WearsEconomy()),
        (economyTest ~= nil) and (", acting as " .. tostring(economyTest)) or "",
        Economy() and "the question always comes" or "nothing changes")
    local list = FP.CLASS_REAGENTS[token] or {}
    if #list == 0 then FP:Print("  this class takes no reagents") end
    for _, entry in ipairs(list) do
        local shown = Current(entry)
        for _, reagent in ipairs(entry.ranks or { entry }) do
            FP:Print("  %d %s: stack %d, target %d, carried %d%s%s", reagent.item,
                ItemName(reagent.item) or "(not loaded yet)", entry.stack,
                Target(ReagentKey(reagent.item), entry.stack), Count(reagent.item),
                reagent.spell and (", spell %d known %s"):format(reagent.spell,
                    tostring(FP:KnowsSpell(reagent.spell))) or "",
                (shown and shown.item == reagent.item) and ", shown" or ", not shown")
        end
    end
    if token ~= "ROGUE" then return end
    for _, poison in ipairs(FP.POISONS) do
        local best = BestRank(poison)
        for _, rank in ipairs(poison.ranks) do
            FP:Print("  %s %d %s: recipe %d %s, known %s, target %d%s", poison.key,
                rank.item, ItemName(rank.item) or "(not loaded yet)", rank.recipe,
                FP:SpellName(rank.recipe) or "(no such spell)",
                tostring(FP:KnowsSpell(rank.recipe)),
                Target(PoisonKey(rank), FP.POISON_STACK),
                (rank == best) and ", the one made" or "")
        end
    end
end
