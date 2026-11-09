-- The column of buttons beside a merchant, the question before buying, and
-- the purchase on its way.
--
-- Built inside Ammunition.lua for 0.8.8, when the quiver got its buttons, and
-- moved here on 2026-10-09 when reagents and poisons joined it for 0.9.1: one
-- column, one question and one purchase at a time, whichever module asks. A
-- module hands its buttons in through Merchant.AddProvider and knows nothing
-- of the others; the column lays out whatever comes back, in the order the
-- providers were given.
--
-- Read in the client's interface code for this build rather than measured:
-- BuyMerchantItem is a plain global the merchant window calls itself, with
-- the amount in single items and at most GetMerchantItemMaxStack per call,
-- and GetMerchantNumItems, GetMerchantItemID and C_MerchantFrame.GetItemInfo
-- describe every item on every page of the merchant.
--
-- **Not measured: where the server puts what was bought.** Should a bag hold
-- a started stack of the same item elsewhere, part of a purchase may go there.

local ADDON, FP = ...
local L = FP.L

local Merchant = {}
FP.Merchant = Merchant

-- Whether a merchant is open, kept from MERCHANT_SHOW and MERCHANT_CLOSED.
-- MerchantFrame:IsShown() is no gate: the order of the handlers of one event
-- is not defined, and the frame can still be hidden while ours runs.
local open = false

-- [itemID] = how many the bags will hold once what is on its way has
-- arrived. While a purchase is on its way the buttons wait, so a second click
-- cannot buy on figures that are out of date.
local onTheWay = {}
local waiting = false
local holdToken
local LOCK_SECONDS = 3

-- { name, order, fn }, in the order the column shows them.
local providers = {}

-- [button id] = when it last bought. **A button that has bought with an id
-- rests for five seconds** with a check mark on it and takes no click, the
-- owner's request of 2026-10-09 after his first poison, **for poisons only**,
-- his word: a poison only counts once it is made, so its button would
-- otherwise buy the same ingredients again the moment the first purchase had
-- landed. Reagents and arrows count what arrived and need no rest.
local justBought = {}
local REST = 5   -- three at first, five at the owner's word once he had tried it

-- ---------------------------------------------------------------------------
-- What the merchant has
-- ---------------------------------------------------------------------------

function Merchant.IsOpen() return open end

--- Whether a purchase is still on its way.
function Merchant.Waiting() return waiting end

--- Whether the button with this id bought something in the last seconds.
function Merchant.JustBought(id)
    local at = id and justBought[id]
    return at ~= nil and GetTime() - at < REST
end

local function ItemIDOf(link)
    local id = type(link) == "string" and link:match("item:(%d+)")
    return id and tonumber(id)
end

--- The item of a merchant slot, by id where the client offers it.
function Merchant.ItemAt(index)
    if GetMerchantItemID then
        local ok, id = pcall(GetMerchantItemID, index)
        if ok and type(id) == "number" then return id end
    end
    if GetMerchantItemLink then
        local ok, link = pcall(GetMerchantItemLink, index)
        if ok then return ItemIDOf(link) end
    end
    return nil
end

--- The link of a merchant slot's item, or nil.
function Merchant.Link(index)
    if not GetMerchantItemLink then return nil end
    local ok, link = pcall(GetMerchantItemLink, index)
    return ok and FP:Plain(link) or nil
end

--- How many slots the merchant has, on every page of the window.
function Merchant.NumItems()
    if not GetMerchantNumItems then return 0 end
    local ok, count = pcall(GetMerchantNumItems)
    return ok and tonumber(count) or 0
end

--- [itemID] = the slot selling it, for everything the merchant has.
function Merchant.Stock()
    local stock = {}
    for index = 1, Merchant.NumItems() do
        local itemID = Merchant.ItemAt(index)
        if itemID and not stock[itemID] then stock[itemID] = index end
    end
    return stock
end

--- What the merchant says about one slot.
function Merchant.Offer(index)
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        local ok, info = pcall(C_MerchantFrame.GetItemInfo, index)
        if ok and type(info) == "table" then
            return {
                price     = tonumber(info.price) or 0,
                stack     = tonumber(info.stackCount) or 1,
                available = tonumber(info.numAvailable) or -1,
                extended  = info.hasExtendedCost == true,
                buyable   = info.isPurchasable ~= false,
                usable    = info.isUsable ~= false,
                icon      = info.texture,
            }
        end
    end
    if _G.GetMerchantItemInfo then
        local ok, _, icon, price, stack, available, buyable, usable, extended =
            pcall(_G.GetMerchantItemInfo, index)
        if ok then
            return {
                price = tonumber(price) or 0, stack = tonumber(stack) or 1,
                available = tonumber(available) or -1,
                extended = extended == true, buyable = buyable ~= false,
                usable = usable ~= false, icon = icon,
            }
        end
    end
    return nil
end

--- The most of an item one bag slot holds.
function Merchant.MaxStack(itemID)
    if C_Item and C_Item.GetItemMaxStackCount then
        local ok, n = pcall(C_Item.GetItemMaxStackCount, itemID)
        if ok and type(n) == "number" and n > 0 then return n end
    end
    local get = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
    if get then
        local ok, _, _, _, _, _, _, _, n = pcall(get, itemID)
        if ok and type(n) == "number" and n > 0 then return n end
    end
    return nil
end

--- How many of an item the bags hold.
--
-- The client's own count where it gives one, which takes every bag, the
-- reagent bag's slot among them; else the bags walked one by one.
function Merchant.Count(itemID)
    local get = (C_Item and C_Item.GetItemCount) or rawget(_G, "GetItemCount")
    if type(get) == "function" then
        local ok, n = pcall(get, itemID)
        n = ok and FP:PlainNumber(n)
        if n then return n end
    end

    local container = C_Container
    if not (container and container.GetContainerNumSlots
            and container.GetContainerItemInfo) then
        return 0
    end
    local total = 0
    for _, bag in ipairs(FP:ReadBags() or {}) do
        for slot = 1, bag.total do
            local ok, info = pcall(container.GetContainerItemInfo, bag.bag, slot)
            if ok and type(info) == "table" and info.itemID == itemID then
                total = total + (tonumber(info.stackCount) or 1)
            end
        end
    end
    return total
end

-- ---------------------------------------------------------------------------
-- Buying
-- ---------------------------------------------------------------------------

local function Release()
    waiting, onTheWay, holdToken = false, {}, nil
end

local function Arrived()
    for itemID, target in pairs(onTheWay) do
        if Merchant.Count(itemID) < target then return false end
    end
    return true
end

--- Holds the buttons until what was bought has arrived, or for a few seconds
--- whatever happened.
local function Hold(targets)
    onTheWay, waiting = targets, true
    local token = {}
    holdToken = token
    if C_Timer and C_Timer.After then
        C_Timer.After(LOCK_SECONDS, function()
            if holdToken == token then
                Release()
                FP:Safe("Merchant:Refresh", Merchant.Refresh)
            end
        end)
    end
end

--- One slot, at most the merchant's limit per call. Answers with how many.
local function BuySlot(index, amount)
    local most = amount
    if GetMerchantItemMaxStack then
        local ok, n = pcall(GetMerchantItemMaxStack, index)
        if ok and type(n) == "number" and n > 0 then most = n end
    end
    local left = amount
    while left > 0 do
        local n = math.min(left, most)
        local ok, err = pcall(BuyMerchantItem, index, n)
        if not ok then
            FP:Warn(L["Buying from the merchant failed: %s"], tostring(err))
            break
        end
        left = left - n
    end
    return amount - left
end

--- Buys what a list names, each { index, itemID, amount }, and holds the
--- buttons until it has arrived.
--
-- @param id  the button that bought it, which then rests, see justBought
-- @return [itemID] = how many were bought, or nil when nothing could be
function Merchant.Purchase(list, id)
    if waiting or not open or Merchant.JustBought(id) then return nil end
    local before, bought = {}, {}
    for _, entry in ipairs(list) do
        before[entry.itemID] = before[entry.itemID] or Merchant.Count(entry.itemID)
    end
    for _, entry in ipairs(list) do
        if entry.amount and entry.amount > 0 then
            local n = BuySlot(entry.index, entry.amount)
            if n > 0 then bought[entry.itemID] = (bought[entry.itemID] or 0) + n end
        end
    end
    if next(bought) then
        local targets = {}
        for itemID, n in pairs(bought) do targets[itemID] = before[itemID] + n end
        Hold(targets)
        if id then
            justBought[id] = GetTime()
            if C_Timer and C_Timer.After then
                C_Timer.After(REST + 0.05, function()
                    FP:Safe("Merchant:Refresh", Merchant.Refresh)
                end)
            end
        end
    end
    FP:Safe("Merchant:Refresh", Merchant.Refresh)
    return bought
end

-- ---------------------------------------------------------------------------
-- The question before buying
-- ---------------------------------------------------------------------------

local askPanel

local function AskPanel()
    if askPanel then return askPanel end
    local PAD, HEADER = FP.PANEL_PAD, FP.PANEL_HEADER

    local WIDTH = 340
    local f = FP:CreatePanel("ForeverPlusMerchantAsk", WIDTH, "", "")
    FP:KeepAboveSettings(f)

    -- One anchor and an explicit width, as in the question that deletes a
    -- character in Core/Widgets.lua, so the wrapped height can be measured.
    local function Paragraph(role)
        local fs = FP:FontString(f, "OVERLAY", role)
        fs:SetWidth(WIDTH - 2 * PAD)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        return fs
    end

    f.question = Paragraph("normal")
    f.question:SetPoint("TOPLEFT", PAD, -(HEADER + 4))
    f.lines   = Paragraph("body")
    f.warning = Paragraph("normal")
    f.cost    = Paragraph("body")

    -- "Do not ask again", the owner's request of 2026-10-07 for the quiver.
    -- Unticked whenever the question opens and taken over only by Buy, so
    -- Cancel changes nothing. Its hover says which switch it turns on, which
    -- the asking module words.
    f.skip = FP:CreateToggle(f, L["Do not ask again"],
        function() return f.dontAsk == true end,
        function(value) f.dontAsk = value end)
    f.skip:SetWidth(WIDTH - PAD)
    FP:Tooltip(f.skip, L["Do not ask again"], function() return f.skipTip end)

    -- An item link in the question shows the game's own card on hover, the
    -- owner's rule for anything that is one of the game's objects.
    pcall(f.SetHyperlinksEnabled, f, true)
    f:SetScript("OnHyperlinkEnter", function(self, link)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        pcall(GameTooltip.SetHyperlink, GameTooltip, link)
        GameTooltip:Show()
    end)
    f:SetScript("OnHyperlinkLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    f.yes = FP:CreateButton(f, L["Buy"], 100, function()
        local spec = f.spec
        local skip = f.dontAsk and f.skip:IsShown()
        f:Hide()
        if spec and spec.onBuy then FP:Safe("Merchant:Buy", spec.onBuy, skip) end
    end)
    f.yes:SetPoint("BOTTOMLEFT", PAD, PAD)

    f.no = FP:CreateButton(f, L["Cancel"], 100, function() f:Hide() end)
    f.no:SetPoint("BOTTOMRIGHT", -PAD, PAD)

    f:HookScript("OnHide", function(self) self.spec = nil end)

    askPanel = f
    return f
end

--- Asks before buying.
--
-- @param spec  { heading, question, lines = { text, ... } or nil, warning or
--              nil, cost in copper, skipTip = the hover of "Do not ask
--              again", which is left off without one, onBuy = fn(skipTicked) }
function Merchant.Ask(spec)
    local f = AskPanel()
    f.spec = spec
    f.heading:SetText(spec.heading or "")
    f.question:SetText(spec.question or "")

    local above = f.question
    if spec.lines and #spec.lines > 0 then
        f.lines:ClearAllPoints()
        f.lines:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -6)
        f.lines:SetText(table.concat(spec.lines, "\n"))
        f.lines:Show()
        above = f.lines
    else
        f.lines:Hide()
    end

    -- In the red of the low ammunition line, set on every question so a
    -- change of scheme cannot have colored it back.
    if spec.warning then
        f.warning:ClearAllPoints()
        f.warning:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -8)
        f.warning:SetText(spec.warning)
        f.warning:SetTextColor(1, 0.25, 0.25)
        f.warning:Show()
        above = f.warning
    else
        f.warning:Hide()
    end

    f.cost:ClearAllPoints()
    f.cost:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -8)
    f.cost:SetText(L["Cost: %s"]:format(FP:Money(spec.cost or 0)))

    -- Its box sits under the text above it, the row starting one box inset
    -- to the left of the panel's margin.
    f.dontAsk, f.skipTip = false, spec.skipTip
    f.skip:Refresh()
    f.skip:ClearAllPoints()
    f.skip:SetPoint("TOPLEFT", f.cost, "BOTTOMLEFT", -FP.ROW_BOX_X, -6)
    if spec.skipTip then f.skip:Show() else f.skip:Hide() end

    -- Shown before it is measured: wrapped text cannot report its height
    -- from inside a hidden frame.
    f:Show()
    local height = FP.PANEL_HEADER + 4 + f.question:GetStringHeight() + 8
        + f.cost:GetStringHeight() + 16 + 22 + FP.PANEL_PAD
    if f.lines:IsShown() then height = height + f.lines:GetStringHeight() + 6 end
    if f.warning:IsShown() then height = height + f.warning:GetStringHeight() + 8 end
    if f.skip:IsShown() then height = height + f.skip:GetHeight() + 6 end
    f:SetHeight(height)
end

-- ---------------------------------------------------------------------------
-- The column
--
-- Its own frames, hung off the merchant window so it comes and goes with it;
-- nothing of the merchant window itself is touched.
-- ---------------------------------------------------------------------------

local BUTTON, GAP, EDGE = 36, 4, 6
local column
local buttons = {}

-- **The amount beside a button**, the owner's request of 2026-10-09: an
-- arrow to the right of a button opens a stepper beside the column, so the
-- amount a click buys up to can be changed without opening the settings,
-- with a stack less and a stack more around the - and +, his layout: -5
-- and +5 at first, a whole stack of the item since his next look. One open
-- at a time, shut
-- with the merchant window. Only for buttons that hand in an `amount`, which
-- the reagents and poisons do and the ammunition, by his word, does not.
local ARROW_W = 14
local editor
local editing   -- the `amount.key` the stepper shows, or nil while it is shut

-- **Auto Buy's box**, the owner's wish of 2026-10-10: in front of a button
-- that hands in `auto`, the same square as a switch, showing and setting
-- whether this character buys it automatically. See Core/AutoBuy.lua.
local BOX_W = 19

--- Adds a source of buttons.
--
-- @param fn  answers with a list of buttons, each { id, icon, count = text or
--            nil, state = "gray" or "red" or nil, tooltip = fn(GameTooltip),
--            click = fn(), amount = nil or { key, get = fn(), set = fn(n),
--            stack, max, title = fn(), tip, stepTip }, auto = nil or { get =
--            fn(), set = fn(on), title = fn(), tip } }, or nil for none.
--            `id` names what the button buys, the same on every refresh, and
--            is what rests after a purchase made with it, see
--            Merchant.Purchase. `amount` is what its arrow changes: `key`
--            names it, `title` and `tip` word the arrow's hover and
--            `stepTip` the hover of the - and +. `auto` is its Auto Buy box
function Merchant.AddProvider(name, order, fn)
    providers[#providers + 1] = { name = name, order = order or 50, fn = fn }
    table.sort(providers, function(a, b) return a.order < b.order end)
end

local function Column()
    if column then return column end
    local merchant = _G.MerchantFrame
    if not merchant then return nil end

    column = CreateFrame("Frame", "ForeverPlusMerchantColumn", merchant)
    column:SetPoint("TOPLEFT", merchant, "TOPRIGHT", 2, 0)
    local bg = FP:Texture(column, "BACKGROUND", FP.colors.bg)
    bg:SetAllPoints()
    FP:AddBorder(column)
    column:Hide()
    return column
end

--- The game's own card for what the button buys, and below it what a click
--- does, both written by the module the button came from.
local function OnEnter(self)
    local spec = self.spec
    if not (spec and spec.tooltip and GameTooltip) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    FP:Safe("Merchant:tooltip", spec.tooltip, GameTooltip)
    GameTooltip:Show()
end

local function OnClick(self)
    local spec = self.spec
    if waiting or not (spec and spec.click) or Merchant.JustBought(spec.id) then
        return
    end
    FP:Safe("Merchant:click", spec.click)
end

--- The stepper beside the column: a stack less, -, the amount, +, a stack
--- more. The - and + change it by one, or by a full stack with Shift, as on
--- the settings page.
local function Editor()
    if editor then return editor end
    local f = CreateFrame("Frame", nil, column)
    f:SetFrameLevel(column:GetFrameLevel() + 5)
    local bg = FP:Texture(f, "BACKGROUND", FP.colors.bg)
    bg:SetAllPoints()
    FP:AddBorder(f)
    -- So a click between its buttons does not fall through to the world.
    f:EnableMouse(true)

    local function Nudge(by, stackWithShift)
        local amount = f.amount
        if not amount then return end
        if stackWithShift and IsShiftKeyDown and IsShiftKeyDown() then
            by = (by > 0 and 1 or -1) * amount.stack
        end
        local value = (tonumber(amount.get()) or 0) + by
        value = math.max(0, math.min(amount.max or value, value))
        FP:Safe("Merchant:amount", amount.set, value)
        FP:Safe("Merchant:Refresh", Merchant.Refresh)
    end

    -- The outer two step by a stack of the item, and say how many: their
    -- captions are set whenever the stepper moves to another button.
    local function Stack() return f.amount and f.amount.stack or 1 end
    local PAD, G, SMALL, WIDE, VALUE = 6, 3, FP.STEP_BTN, 36, 40
    f.less = FP:CreateButton(f, "", WIDE, function() Nudge(-Stack()) end)
    f.less:SetPoint("LEFT", PAD, 0)
    f.minus = FP:CreateButton(f, "-", SMALL, function() Nudge(-1, true) end)
    f.minus:SetPoint("LEFT", f.less, "RIGHT", G, 0)
    f.minus.tipSide = "LEFT"
    f.value = FP:FontString(f, "OVERLAY", "normal")
    f.value:SetWidth(VALUE)
    f.value:SetJustifyH("CENTER")
    f.value:SetPoint("LEFT", f.minus, "RIGHT", G, 0)
    f.plus = FP:CreateButton(f, "+", SMALL, function() Nudge(1, true) end)
    f.plus:SetPoint("LEFT", f.value, "RIGHT", G, 0)
    f.more = FP:CreateButton(f, "", WIDE, function() Nudge(Stack()) end)
    f.more:SetPoint("LEFT", f.plus, "RIGHT", G, 0)
    f:SetSize(2 * PAD + 2 * WIDE + 2 * SMALL + VALUE + 4 * G, BUTTON)

    FP:Tooltip({ f.minus, f.plus },
        function() return f.amount and f.amount.title() end,
        function() return f.amount and f.amount.stepTip end)
    f:Hide()
    editor = f
    return f
end

--- Opens the stepper for a button's amount, or shuts it when it shows that
--- one already.
local function OnArrow(self)
    local spec = self:GetParent().spec
    local amount = spec and spec.amount
    if not amount then return end
    editing = (editing ~= amount.key) and amount.key or nil
    FP:Safe("Merchant:Refresh", Merchant.Refresh)
end

--- The client's own submenu arrow, as on the Chat page's play buttons,
--- drained and tinted like a button's caption, pointing back once open.
local function PaintArrow(b, open)
    local tex = b.arrow.tex
    tex:SetDesaturated(true)
    local font = FP:Font("button")
    if font and font.GetTextColor then tex:SetVertexColor(font:GetTextColor()) end
    if open then tex:SetTexCoord(1, 0, 0, 1) else tex:SetTexCoord(0, 1, 0, 1) end
end

local function Button(i)
    if buttons[i] then return buttons[i] end
    local b = CreateFrame("Button", nil, column)
    b:SetSize(BUTTON, BUTTON)

    b.arrow = CreateFrame("Button", nil, b)
    b.arrow:SetSize(ARROW_W, BUTTON)
    b.arrow:SetPoint("LEFT", b, "RIGHT", 2, 0)
    local arrowLight = FP:Texture(b.arrow, "HIGHLIGHT", FP.colors.hover)
    arrowLight:SetAllPoints()
    b.arrow.tex = b.arrow:CreateTexture(nil, "ARTWORK")
    b.arrow.tex:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    b.arrow.tex:SetSize(12, 12)
    b.arrow.tex:SetPoint("CENTER")
    b.arrow:SetScript("OnClick", OnArrow)
    FP:Tooltip(b.arrow,
        function() return b.spec and b.spec.amount and b.spec.amount.title() end,
        function() return b.spec and b.spec.amount and b.spec.amount.tip end)
    -- Above it, the owner's word after his first look: to the right it
    -- covered the stepper the arrow had just opened.
    b.arrow.tipSide = "TOP"
    b.arrow:Hide()

    b.auto = FP:CreateBox(b,
        function() return b.spec and b.spec.auto and b.spec.auto.get() or false end,
        function(on)
            if not (b.spec and b.spec.auto) then return end
            FP:Safe("Merchant:auto", b.spec.auto.set, on)
            FP:Safe("Merchant:Refresh", Merchant.Refresh)
        end)
    b.auto:SetPoint("RIGHT", b, "LEFT", -2, 0)
    FP:Tooltip(b.auto,
        function() return b.spec and b.spec.auto and b.spec.auto.title() end,
        function() return b.spec and b.spec.auto and b.spec.auto.tip end)
    b.auto.tipSide = "TOP"
    b.auto:Hide()

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    FP:AddBorder(b)
    local hl = FP:Texture(b, "HIGHLIGHT", FP.colors.hover)
    hl:SetAllPoints()
    b.count = FP:IconText(b, "BOTTOM", 0, 2)
    -- The check mark of a button resting after a purchase: the client's own
    -- ready check mark, which needs no words in any language.
    b.done = b:CreateTexture(nil, "OVERLAY")
    b.done:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    b.done:SetSize(BUTTON * 0.7, BUTTON * 0.7)
    b.done:SetPoint("CENTER")
    b.done:Hide()
    b:SetScript("OnEnter", OnEnter)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    b:SetScript("OnClick", OnClick)
    buttons[i] = b
    return b
end

--- Gray when a click would buy nothing, red when it would buy something the
--- character cannot use yet, the merchant's own red for that.
local function Paint(b, spec)
    b.spec = spec
    b.icon:SetTexture(spec.icon or 134400)
    b.icon:SetDesaturated(spec.state == "gray")
    if spec.state == "gray" then
        b.icon:SetVertexColor(0.6, 0.6, 0.6)
    elseif spec.state == "red" then
        b.icon:SetVertexColor(0.9, 0, 0)
    else
        b.icon:SetVertexColor(1, 1, 1)
    end
    local resting = Merchant.JustBought(spec.id)
    b.count:SetText(resting and "" or (spec.count or ""))
    if resting then b.done:Show() else b.done:Hide() end
    b:SetAlpha((waiting and not resting) and 0.5 or 1)

    if spec.amount then
        PaintArrow(b, editing == spec.amount.key)
        b.arrow:Show()
    else
        b.arrow:Hide()
    end

    if spec.auto then
        b.auto:Refresh()
        b.auto:Show()
    else
        b.auto:Hide()
    end
end

--- Puts the stepper beside the button whose amount it shows, or shuts it
--- when no button hands that amount in any more.
local function PlaceEditor(shown)
    local host
    for i = 1, shown do
        local spec = buttons[i].spec
        if editing and spec and spec.amount and spec.amount.key == editing then
            host = buttons[i]
        end
    end
    if not host then
        editing = nil
        if editor then editor:Hide() end
        return
    end
    local f = Editor()
    f.amount = host.spec.amount
    f.value:SetText(tostring(f.amount.get() or 0))
    f.less.label:SetText("-" .. (f.amount.stack or 1))
    f.more.label:SetText("+" .. (f.amount.stack or 1))
    f:ClearAllPoints()
    -- Just past the column's right edge, level with the button.
    f:SetPoint("LEFT", host, "RIGHT", 2 + ARROW_W + EDGE + 2, 0)
    f:Show()
end

--- Asks every provider again and lays the column out.
function Merchant.Refresh()
    if not column then return end
    local specs = {}
    if open then
        for _, provider in ipairs(providers) do
            local ok, list = pcall(provider.fn)
            if not ok then
                FP:Warn(L["Error in %s: %s"], provider.name, tostring(list))
            elseif type(list) == "table" then
                for _, spec in ipairs(list) do specs[#specs + 1] = spec end
            end
        end
    end

    -- The column grows by the arrows' width as soon as one button has one,
    -- and by the boxes' in front as soon as one has a box.
    local arrows, boxes = false, false
    for _, spec in ipairs(specs) do
        if spec.amount then arrows = true end
        if spec.auto then boxes = true end
    end
    local left = EDGE + (boxes and (BOX_W + 2) or 0)

    for i, spec in ipairs(specs) do
        local b = Button(i)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", column, "TOPLEFT", left, -(EDGE + (i - 1) * (BUTTON + GAP)))
        Paint(b, spec)
        b:Show()
    end
    for i = #specs + 1, #buttons do
        buttons[i]:Hide()
        buttons[i].spec = nil
    end
    PlaceEditor(#specs)

    if #specs == 0 then
        column:Hide()
        return
    end
    column:SetSize(left + BUTTON + EDGE + (arrows and (2 + ARROW_W) or 0),
        2 * EDGE + #specs * BUTTON + (#specs - 1) * GAP)
    column:Show()
end

-- The merchant's state, the purchase on its way, and the column. Registered
-- once at load: the modules that hand in buttons say themselves whether they
-- are on, so nothing here has to be switched with them. Asked rather than
-- assumed, because an event this build does not know raises when registered.
local events = CreateFrame("Frame")
for _, event in ipairs({ "MERCHANT_SHOW", "MERCHANT_UPDATE", "MERCHANT_CLOSED",
                         "PLAYER_MONEY", "BAG_UPDATE_DELAYED",
                         "BAG_CONTAINER_UPDATE" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "MERCHANT_SHOW" then
        open = true
        Column()
    elseif event == "MERCHANT_CLOSED" then
        open = false
        Release()
        editing = nil
        if askPanel then askPanel:Hide() end
    elseif event == "BAG_UPDATE_DELAYED" and waiting and Arrived() then
        Release()
    end
    FP:Safe("Merchant:Refresh", Merchant.Refresh)
end)
