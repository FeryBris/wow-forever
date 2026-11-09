-- How much ammunition a Hunter carries, and a short warning when it runs low;
-- and the buttons beside a merchant that fill the quiver.
--
-- **Two modules since 2026-10-10**, the owner's word when the merchant's
-- modules got a group of their own: "Ammunition Warning" under Display, the
-- count and the warning, which kept the name Ammunition and its settings;
-- and "Ammunition" under Merchants, the buying, as FillQuiver. One file,
-- since both read the same bags. See migration 7 to 8 in Core/Config.lua.
--
-- Asked for on CurseForge on 2026-09-28 by a player who had built it into their
-- own copy, and shaped by the owner in a dialog the same day:
--
--   * **Hunters only.** They spend ammunition on every shot. A Warrior or a
--     Rogue pulls with a bow now and then, and would sit under any useful
--     threshold for good.
--   * **The count sits on the bag the ammunition belongs in**: the top of the
--     quiver or ammo pouch, above the free slots BagSlots writes at the bottom
--     of the same button, and the top of the backpack when there is no such
--     bag. A number about the bags belongs on the bags, the owner's rule since
--     2026-09-23.
--   * **Every arrow counts, or every bullet**, whichever the ranged weapon
--     fires, regardless of which kind it is.
--   * **The warning is a short red line with a sound**, once when the count
--     drops below the threshold, and armed again once the count is back at or
--     above it: told once per restock rather than once per shot. The sound is
--     picked and tried from the chat's list, the alarm clock by default, the
--     owner's choice once he had heard them.
--   * **The threshold starts at 500** and moves in steps of 50.
--
-- Read in the client's interface code rather than measured, and unseen in game
-- when this was written: the bag families, 1 for a quiver and 2 for an ammo
-- pouch, and the item classes, 6 for ammunition with 2 for arrows and 3 for
-- bullets, which are Classic's numbers and the client's enums where it has them.

local ADDON, FP = ...
local L = FP.L

local M = FP:RegisterModule("Ammunition", {
    title   = L["Ammunition Warning"],
    default = true,
    desc    = L["For Hunters: shows how much ammunition you carry, on your "
           .. "quiver or backpack, with a short warning when it runs low."],
    note    = L["Hunters only"],
    group   = "display",
    order   = 32,
    options = {
        { key = "warn", type = "toggle", default = true,
          label = L["Warn when it runs low"],
          desc  = L["A short red line in the upper middle of the screen, "
               .. "once when your ammunition drops below the amount set "
               .. "here. It appears again only after you restock above that "
               .. "amount. While this is on, the count itself turns red "
               .. "below the threshold."] },

        { key = "threshold", type = "number", default = 500, sub = true,
          label = L["Warn below"], min = 50, max = 3000, step = 50,
          disabled = function(mod) return not mod.db.warn end,
          desc  = L["The ammunition count below which the warning appears."] },

        { key = "sound", type = "toggle", default = true, sub = true,
          label = L["Play a sound with it"],
          disabled = function(mod) return not mod.db.warn end,
          desc  = L["Plays the sound selected below along with the red "
               .. "warning."] },

        -- Chosen and tried like the chat's sounds, from the same list, asked
        -- for by the owner on 2026-09-28. The name is stored, see FP.SOUNDS.
        { key = "soundKit", type = "select", default = "ALARM_CLOCK_WARNING_2", sub = true,
          label = L["Sound"], values = FP:SoundChoices(),
          disabled = function(mod) return not (mod.db.warn and mod.db.sound) end,
          desc  = L["Picks one of the game's own sounds."] },

        { type = "action", label = L["Play the sound"], width = 150,
          desc  = L["Plays the selected sound now."],
          run   = function(mod) mod:PlayPicked() end },

        { type = "action", label = L["Show the warning"], width = 150, sameRow = true,
          desc  = L["Shows the warning once, with its sound when that is on."],
          run   = function(mod) mod:Preview() end },
    },
})

local ITEM_CLASS  = Enum and Enum.ItemClass
local PROJECTILE  = (ITEM_CLASS and ITEM_CLASS.Projectile) or 6
local WEAPON      = (ITEM_CLASS and ITEM_CLASS.Weapon) or 2
local ARROW, BULLET = 2, 3

-- What each ranged weapon fires, by weapon subclass: bows and crossbows take
-- arrows, guns take bullets. Thrown weapons and wands take nothing.
local FIRES = { [2] = ARROW, [18] = ARROW, [3] = BULLET }

local RANGED_SLOT = INVSLOT_RANGED or 18

-- How long after entering the world nothing is warned about. The bags arrive
-- one by one at login, and a count taken halfway would warn about ammunition
-- that is sitting in the next bag.
local QUIET = 5

local function IsHunter()
    if not UnitClass then return false end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and FP:Plain(token) == "HUNTER"
end

-- [itemID] = { class, subclass }. An item's class never changes, and a Hunter's
-- bags are walked after every shot.
local classOf = {}

local function ItemClass(itemID)
    local known = classOf[itemID]
    if known then return known[1], known[2] end
    local get = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
    if not get then return nil end
    local ok, _, _, _, _, _, class, subclass = pcall(get, itemID)
    if not ok or type(class) ~= "number" then return nil end
    classOf[itemID] = { class, subclass }
    return class, subclass
end

--- What the ranged weapon fires, ARROW or BULLET, or nil when it fires nothing.
local function Fires()
    if not GetInventoryItemID then return nil end
    local ok, itemID = pcall(GetInventoryItemID, "player", RANGED_SLOT)
    if not ok or type(itemID) ~= "number" then return nil end
    local class, subclass = ItemClass(itemID)
    if class ~= WEAPON then return nil end
    return FIRES[subclass]
end

--- Every arrow or every bullet in the bags, or only those of one item, or
--- nil while the bags are not there yet.
--
-- The reagent bag's slot is read as well since 1.0.2: on WoW Forever a
-- special bag can sit there, the owner's soul bag on 2026-10-09, so a quiver
-- can too, and its arrows were left out before.
local function CountAmmo(fires, itemID)
    local container = C_Container
    if not (container and container.GetContainerNumSlots
            and container.GetContainerItemInfo) then
        return nil
    end

    local bags = {}
    for bag = 0, (NUM_BAG_SLOTS or 4) do bags[#bags + 1] = bag end
    local index = Enum and Enum.BagIndex
    if type(index) == "table" and type(index.ReagentBag) == "number" then
        bags[#bags + 1] = index.ReagentBag
    end

    local total, seen = 0, false
    for _, bag in ipairs(bags) do
        local ok, slots = pcall(container.GetContainerNumSlots, bag)
        if ok and type(slots) == "number" and slots > 0 then
            seen = true
            for slot = 1, slots do
                local okInfo, info = pcall(container.GetContainerItemInfo, bag, slot)
                if okInfo and type(info) == "table" and info.itemID
                   and (not itemID or info.itemID == itemID) then
                    local class, subclass = ItemClass(info.itemID)
                    if class == PROJECTILE and subclass == fires then
                        total = total + (tonumber(info.stackCount) or 1)
                    end
                end
            end
        end
    end
    if not seen then return nil end
    return total
end

--- The bag a quiver or an ammo pouch sits in, and its family, or nil.
--
-- By family: 1 is a quiver and 2 an ammo pouch, the two low bits of the
-- bitfield, so anything in those bits holds ammunition.
local function AmmoBag()
    local container = C_Container
    local numSlots = container and container.GetContainerNumSlots
    local numFree  = container and container.GetContainerNumFreeSlots
    if not (numSlots and numFree) then return nil end

    for bag = 1, (NUM_BAG_SLOTS or 4) do
        local okSlots, slots = pcall(numSlots, bag)
        local okFree, _, family = pcall(numFree, bag)
        if okSlots and okFree and type(slots) == "number" and slots > 0
           and type(family) == "number" and family % 4 ~= 0 then
            return bag, family
        end
    end
    return nil
end

--- The button the count goes on: the quiver's, when it can be seen, else the
--- backpack. The bag bar can be folded away, and a count on a hidden button
--- would be a count nobody sees.
local function CountButton()
    local bag = AmmoBag()
    local button = bag and _G["CharacterBag" .. (bag - 1) .. "Slot"]
    if button and button:IsVisible() then return button end
    return _G.MainMenuBarBackpackButton
end

-- [button] = the count written on it. One button carries it at a time; the rest
-- are emptied, so a quiver taken off does not leave its last number behind.
local countLabels = {}

--- Writes the count on its button, red while it is low.
--
-- Red only while the warning is on, the owner's choice on 2026-09-28: the
-- threshold it is measured against means nothing with the warning off, and its
-- row on the page is grayed out then too. The red is the warning line's own.
local function ShowCount(count, low)
    local button = CountButton()
    for other, fs in pairs(countLabels) do
        if other ~= button then fs:SetText("") end
    end
    if not button then return end
    local fs = countLabels[button]
    if not fs then
        fs = FP:IconText(button, "TOP", 0, -2)
        countLabels[button] = fs
    end
    fs:SetText(tostring(count))
    if low then
        fs:SetTextColor(1, 0.25, 0.25)
    else
        fs:SetTextColor(1, 1, 1)
    end
    fs:Show()
end

local function ClearCount()
    for _, fs in pairs(countLabels) do fs:SetText("") end
end

-- ---------------------------------------------------------------------------
-- The warning
-- ---------------------------------------------------------------------------

-- Its line among the short red ones, see FP:FlashLine.
local ALERT_LINE = 1

local function Warn(count)
    FP:FlashLine(ALERT_LINE, L["Low on ammunition: %d left"]:format(count))
    if M.db.sound then M:PlayPicked(true) end
end

--- The sound picked, now. On the master channel, so it is heard with sound
--- effects turned off, which is how the client plays its own alerts.
--
-- @param quiet  say nothing when the sound is missing; the warning itself
--               should not add a chat line to a moment that already has one
function M:PlayPicked(quiet)
    local id = FP:SoundKitId(self.db.soundKit)
    if id and PlaySound and pcall(PlaySound, id, "Master") then return true end
    if not quiet then
        FP:Warn(L["Ammunition: this client has no sound called %s."],
            tostring(self.db.soundKit))
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Keeping it current
-- ---------------------------------------------------------------------------

M.armed      = true   -- whether the next drop below the threshold is told
M.quietUntil = 0

function M:Update()
    if not self.enabled then return end
    if not IsHunter() then return ClearCount() end

    local fires = Fires()
    if not fires then return ClearCount() end

    local count = CountAmmo(fires)
    if not count then return end
    self.count = count
    local threshold = tonumber(self.db.threshold) or 500
    ShowCount(count, self.db.warn and count < threshold)

    if count >= threshold then
        self.armed = true
    elseif self.armed and self.db.warn and GetTime() >= self.quietUntil then
        self.armed = false
        Warn(count)
    end
end

--- Holds the warning back for a moment and looks again once it is over.
local function Settle()
    M.quietUntil = GetTime() + QUIET
    if C_Timer and C_Timer.After then
        C_Timer.After(QUIET + 0.1, function()
            FP:Safe("Ammunition:Update", M.Update, M)
        end)
    end
end

--- The warning as it would come, whatever the count, for the page's button.
function M:Preview()
    Warn(self.count or tonumber(self.db.threshold) or 500)
end

-- ---------------------------------------------------------------------------
-- The count on the info bar
--
-- A1 of the 1.0.2 brief, the owner's own request of 2026-10-21 and his
-- answers the same day: a display on the info bar, off by default, for any
-- character with a bow, a gun or a crossbow in hand rather than for Hunters
-- alone, and nothing at all without one. It counts with the quiver's count
-- above, every arrow or every bullet the weapon fires, or the ammunition in
-- the ammo slot alone, the player's choice. **It turns red by this module's
-- switch and threshold**, shared rather than copied, also while this module
-- or the Gameplay page is off; the red line and the sound stay this
-- module's. Read here whether the module runs or not.
--
-- The ammo slot is inventory slot 0, which the backpack shares in the
-- client's character window, PaperDollItemSlotButton_Update in its interface
-- code for build 70450, and GetInventoryItemID names its item. Read in the
-- client's code, not measured.
-- ---------------------------------------------------------------------------

local AMMO_SLOT = rawget(_G, "INVSLOT_AMMO") or 0

M.ARROW, M.BULLET = ARROW, BULLET

--- The item in the ammo slot, or nil while it is empty.
local function SlotAmmo()
    if not GetInventoryItemID then return nil end
    local ok, itemID = pcall(GetInventoryItemID, "player", AMMO_SLOT)
    itemID = ok and FP:PlainNumber(itemID)
    return (itemID and itemID > 0) and itemID or nil
end

--- What the info bar shows.
-- @param mode  "all" for every arrow or every bullet, or "slot" for the
--              ammunition in the ammo slot alone
-- @return the count, or nil while the bags cannot be read; ARROW or BULLET,
--         what the weapon fires; and the ammo slot's item. Nothing at all
--         without a weapon that fires either.
function M:BarCount(mode)
    local fires = Fires()
    if not fires then return nil end
    local slot = SlotAmmo()
    if mode == "slot" then
        -- An empty ammo slot holds none, which is known.
        if not slot then return 0, fires, nil end
        return CountAmmo(fires, slot), fires, slot
    end
    return CountAmmo(fires), fires, slot
end

--- Whether a count is low by the warning's switch and threshold.
function M:IsLow(count)
    local db = self.db or {}
    return db.warn ~= false and type(count) == "number"
        and count < (tonumber(db.threshold) or 500)
end

-- ---------------------------------------------------------------------------
-- Filling the quiver
--
-- The owner's request of 2026-10-07, in its second shape the same day: a
-- column of buttons beside the merchant window, one for every kind of arrow
-- or bullet the merchant sells, each buying as many as the quiver or ammo
-- pouch still holds. The first shape filled up after a purchase in the
-- merchant's own list, and the owner found its two faults in game: the
-- merchant's stack was bought before the question came, since a hook only
-- runs after the client's own click, and without the question one stack too
-- many arrived, because the amount was worked out while the first purchase
-- was still arriving. A button works its amount out before anything is
-- bought, and the merchant's own list is left alone.
--
-- Settled by the owner in the dialog: symbols only, with the amount on each
-- and in its hover beside the price; gray while the bag is full or does not
-- take that kind, arrows with an ammo pouch and bullets with a quiver;
-- ammunition above the Hunter's level red and still for sale, with a red
-- warning in the question; buttons and question both on by default. Nothing
-- appears without a quiver or an ammo pouch, since there is nothing to fill.
-- The question always comes for ammunition that cannot be used yet, even
-- with "Skip the purchase dialog", or its warning could never be read.
--
-- **The column, the question and the purchase on its way live in
-- Core/Merchant.lua since 2026-10-09**, when reagents and poisons joined the
-- column for 0.9.1. What stays here is what only arrows and bullets ask:
-- which bag takes them, how much still fits, and the words. The amount is
-- rounded down to whole merchant stacks, the only amounts the client's own
-- window sells, and to what the money and the merchant allow.
-- ---------------------------------------------------------------------------

local Merchant = FP.Merchant
local AutoBuy  = FP.AutoBuy

-- The buttons and the question before buying, both on by default since the
-- buttons replaced the fill after a purchase, the owner's word of
-- 2026-10-07. Its switch was "Show buttons to fill the quiver" under the
-- Ammunition module until 2026-10-10, when it became this module's own.
local Q = FP:RegisterModule("FillQuiver", {
    title   = L["Ammunition"],
    default = true,
    desc    = L["Adds a button for each kind of ammunition beside merchants "
           .. "who sell it. A click buys as many as your quiver or ammo "
           .. "pouch can still hold."],
    note    = L["Hunters only"],
    group   = "merchant",
    order   = 20,
    options = {
        { key = "fillWithoutAsking", type = "toggle", default = false,
          label = L["Skip the purchase dialog"],
          desc  = L["A click on a button beside the merchant buys at once "
               .. "and reports the purchase in chat. Ammunition you cannot "
               .. "use yet always shows the dialog."] },
    },
})

-- Which ammunition each bag family takes. A family is a bitfield.
local FAMILY_FOR = { [ARROW] = 1, [BULLET] = 2 }

local function Takes(family, subclass)
    local bit = FAMILY_FOR[subclass]
    return bit ~= nil and type(family) == "number"
        and math.floor(family / bit) % 2 == 1
end

--- How many more of an item fit into one bag: every empty slot a full stack,
--- and every started stack of the same item what it lacks.
local function Room(bag, itemID)
    local stack = Merchant.MaxStack(itemID)
    local container = C_Container
    local okSlots, slots = pcall(container.GetContainerNumSlots, bag)
    if not (stack and okSlots and type(slots) == "number") then return 0 end

    local room = 0
    for slot = 1, slots do
        local ok, info = pcall(container.GetContainerItemInfo, bag, slot)
        if ok and type(info) ~= "table" then
            room = room + stack
        elseif ok and info.itemID == itemID then
            room = room + math.max(0, stack - (tonumber(info.stackCount) or stack))
        end
    end
    return room
end

--- Everything a button knows about one merchant slot holding arrows or
--- bullets, or nil for any other slot and while there is no ammunition bag.
--
-- `amount` is what a click buys and `cost` what that costs. `reason` says why
-- a click would buy nothing, and is nil whenever it would buy something.
local function Plan(index)
    local itemID = Merchant.ItemAt(index)
    if not itemID then return nil end
    local class, subclass = ItemClass(itemID)
    if class ~= PROJECTILE or not FAMILY_FOR[subclass] then return nil end

    local bag, family = AmmoBag()
    local offer = Merchant.Offer(index)
    if not (bag and offer) then return nil end

    local plan = {
        index = index, itemID = itemID, subclass = subclass,
        link = Merchant.Link(index), icon = offer.icon,
        usable = offer.usable, quiver = Takes(family, ARROW),
        amount = 0, cost = 0,
    }

    if not Takes(family, subclass) then
        plan.reason = "bag"
        return plan
    end
    if offer.extended or not offer.buyable or offer.stack < 1 then
        plan.reason = "merchant"
        return plan
    end

    local amount = math.floor(Room(bag, itemID) / offer.stack) * offer.stack
    if amount <= 0 then
        plan.reason = "full"
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
        amount = math.min(amount,
            math.floor(GetMoney() / offer.price) * offer.stack)
        if amount <= 0 then
            plan.reason = "money"
            return plan
        end
    end

    plan.amount = amount
    plan.cost   = offer.price * amount / offer.stack
    return plan
end

--- One of two whole sentences, for a quiver or for an ammo pouch. Never the
--- bag's name glued into one: other languages change more than the noun.
local function ForBag(plan, quiver, pouch)
    return plan.quiver and quiver or pouch
end

--- Buys what a plan names, and answers with the amount bought and its cost.
--- Worked out again first: the bags and the money may have moved while the
--- question stood, and the module may have been switched off.
local function Buy(plan)
    if not Q.enabled then return nil end
    local now = Plan(plan.index)
    if not now or now.itemID ~= plan.itemID or now.reason then return nil end
    local amount = math.min(plan.amount, now.amount)
    if amount <= 0 then return nil end

    local bought = Merchant.Purchase({
        { index = plan.index, itemID = plan.itemID, amount = amount } })
    local n = bought and bought[plan.itemID] or 0
    if n <= 0 then return nil end
    return n, now.cost * n / now.amount
end

--- The red line in the question, for ammunition above the Hunter's level.
local function UnusableText(plan)
    local get = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
    if get then
        local ok, _, _, _, _, level = pcall(get, plan.itemID)
        if ok and type(level) == "number" and level > 1 then
            return string.format(L["You cannot use these before level %d."], level)
        end
    end
    return L["You cannot use these yet."]
end

--- The question before buying, worded for the bag.
--
-- "Do not ask again" switches "Skip the purchase dialog" on with Buy, the owner's
-- request of 2026-10-07 once the question had been seen in game. Not on the
-- question with the red warning, which comes anyway.
local function Ask(plan)
    Merchant.Ask({
        heading  = ForBag(plan, L["Fill the Quiver"], L["Fill the Ammo Pouch"]),
        question = string.format(ForBag(plan,
            L["Do you really want to buy %d %s to fill your quiver?"],
            L["Do you really want to buy %d %s to fill your ammo pouch?"]),
            plan.amount, plan.link or "?"),
        warning  = not plan.usable and UnusableText(plan) or nil,
        cost     = plan.cost,
        skipTip  = plan.usable and L["Switches on \"Skip the purchase dialog\" "
            .. "under Ammunition on the Gameplay page, where it can be switched "
            .. "off again."] or nil,
        onBuy    = function(skip)
            if skip then
                Q.db.fillWithoutAsking = true
                -- The row on the Gameplay page, should the window be open.
                local menu = FP.modules and FP.modules.Menu
                if menu and menu.Refresh then FP:Safe("Menu:Refresh", menu.Refresh, menu) end
            end
            Buy(plan)
        end,
    })
end

local REASONS = {
    full     = function(plan)
        return ForBag(plan, L["No more will fit in your quiver."],
                            L["No more will fit in your ammo pouch."])
    end,
    sold     = function() return L["The merchant has none left."] end,
    money    = function() return L["You cannot afford a stack."] end,
    merchant = function() return L["Buy this one in the merchant window."] end,
    bag      = function(plan)
        return ForBag(plan, L["Your quiver cannot hold bullets."],
                            L["Your ammo pouch cannot hold arrows."])
    end,
}

--- The merchant's own card for the item, and below it what a click does.
local function Tooltip(tip, index)
    local plan = Plan(index)
    if not plan then return end
    if not pcall(tip.SetMerchantItem, tip, plan.index) and plan.link then
        pcall(tip.SetHyperlink, tip, plan.link)
    end
    tip:AddLine(" ")
    if plan.reason then
        tip:AddLine(REASONS[plan.reason](plan), 0.6, 0.6, 0.6, true)
    elseif Merchant.Waiting() then
        tip:AddLine(L["Waiting for the previous purchase to complete."], 0.6, 0.6, 0.6, true)
    else
        tip:AddLine(string.format(ForBag(plan,
            L["Click to buy %d and fill your quiver."],
            L["Click to buy %d and fill your ammo pouch."]), plan.amount),
            1, 1, 1, true)
        tip:AddLine(L["Cost: %s"]:format(FP:Money(plan.cost)), 1, 1, 1)
    end
end

local function Click(index)
    local plan = Plan(index)
    if not plan or plan.reason then return end
    if Q.db.fillWithoutAsking and plan.usable then
        local amount, cost = Buy(plan)
        if amount and amount > 0 then
            FP:Print(ForBag(plan, L["Bought %d %s for %s to fill your quiver."],
                L["Bought %d %s for %s to fill your ammo pouch."]), amount,
                plan.link or "?", FP:Money(cost))
        end
    else
        Ask(plan)
    end
end

-- Auto Buy's tick for one kind of ammunition: one kind at a time per bag
-- family, so ticking another unticks it. See Modules/AutoBuy.lua.
local function AutoKey(itemID) return "ammo" .. itemID end

local function AutoFor(plan)
    if not (AutoBuy and AutoBuy.On()) then return nil end
    local key = AutoKey(plan.itemID)
    return {
        get   = function() return AutoBuy.Is(key) end,
        set   = function(on) AutoBuy.Set(key, on, "ammo" .. plan.subclass) end,
        title = function() return plan.link or "?" end,
        tip   = ForBag(plan,
            L["Fills your quiver with these automatically whenever you open a "
                .. "merchant who sells them. One kind at a time."],
            L["Fills your ammo pouch with these automatically whenever you "
                .. "open a merchant who sells them. One kind at a time."]),
    }
end

--- The buttons for the column: one for every kind of arrow or bullet the
--- merchant sells, for a Hunter with a quiver or an ammo pouch.
local function Provide()
    if not (Q.enabled and IsHunter()) then return nil end
    local specs = {}
    for index = 1, Merchant.NumItems() do
        local plan = Plan(index)
        if plan then
            specs[#specs + 1] = {
                icon    = plan.icon or 134400,
                count   = plan.amount > 0 and tostring(plan.amount) or nil,
                state   = (plan.reason and "gray") or (not plan.usable and "red") or nil,
                tooltip = function(tip) Tooltip(tip, index) end,
                click   = function() Click(index) end,
                auto    = AutoFor(plan),
            }
        end
    end
    return specs
end
Merchant.AddProvider("Ammunition", 10, Provide)

--- What Auto Buy fills: the kind ticked, as much as the bag still takes and
--- the money allows. Never what the Hunter cannot use yet, whose warning only
--- a question could give.
local function AutoPlan()
    if not (Q.enabled and IsHunter()) then return nil end
    local entries = {}
    for index = 1, Merchant.NumItems() do
        local plan = Plan(index)
        if plan and not plan.reason and plan.usable
           and AutoBuy.Is(AutoKey(plan.itemID)) then
            entries[#entries + 1] = {
                index = index, itemID = plan.itemID, amount = plan.amount,
                cost = plan.cost, line = plan.amount .. " " .. (plan.link or "?"),
                said = function(n)
                    return ForBag(plan, L["Bought %d %s for %s to fill your quiver."],
                        L["Bought %d %s for %s to fill your ammo pouch."])
                        :format(n, plan.link or "?",
                            FP:Money(plan.cost * n / plan.amount))
                end,
            }
        end
    end
    return { entries = entries }
end
if AutoBuy then AutoBuy.AddProvider("Ammunition", AutoPlan) end

function Q:OnEnable()  FP:Safe("Merchant:Refresh", Merchant.Refresh) end
function Q:OnDisable() FP:Safe("Merchant:Refresh", Merchant.Refresh) end
function Q:Reapply()   FP:Safe("Merchant:Refresh", Merchant.Refresh) end

function M:OnEnable()
    self.frame = self.frame or CreateFrame("Frame")
    self.frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then Settle() end
        FP:Safe("Ammunition:Update", M.Update, M)
    end)

    -- Every bag change, the event BagSlots listens to. This began as the
    -- delayed bag event alone, and the owner's first look at an ammo pouch on
    -- 2026-09-28 showed the pouch's free slots, drawn by BagSlots on this
    -- event, with no count above them until a reload. After a shot it is one
    -- call, for the bag the shot came out of.
    self.frame:RegisterEvent("BAG_UPDATE")
    -- Asked rather than assumed, because an event this build does not know
    -- raises when it is registered.
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED",
                             "BAG_CONTAINER_UPDATE", "BAG_UPDATE_DELAYED" }) do
        pcall(self.frame.RegisterEvent, self.frame, event)
    end

    self.armed = true
    Settle()
    self:Update()
end

function M:OnDisable()
    if self.frame then self.frame:UnregisterAllEvents() end
    ClearCount()
    FP:HideFlashLine(ALERT_LINE)
end

--- A new threshold is judged at once, against the count already known.
function M:Reapply()
    self:Update()
end
