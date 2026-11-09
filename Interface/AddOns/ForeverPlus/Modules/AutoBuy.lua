-- Auto Buy: whatever is ticked for it, bought when a merchant window opens.
--
-- The owner's wish of 2026-10-09, built last and on its own so it can be
-- taken out again: this file and its line in the TOC, the box beside a
-- button in Core/Merchant.lua, FP:CreateBox, and the `auto` parts Reagents
-- and Ammunition hand in. Gated with him on 2026-10-10:
--
--   * **A module of its own, first in the Merchants group and off by
--     default**, with its question's switch under it, his word when the
--     merchant's modules got a group of their own the same day.
--   * **A tick per item, kept per character**: in front of every amount in
--     the reagent list, and beside every button at the merchant, which is
--     where it is set for arrows and bullets and where it shows for
--     everything. Nothing ticked to begin with; the ticks show only while
--     the module is on.
--   * **Ammunition is what the player ticked**, one kind at a time, since
--     two kinds would fill the same quiver.
--   * **A poison counts the ingredients the bags hold** here, unlike its
--     button: the purchase repeats at every merchant until the poison is
--     made, and would otherwise buy the same ingredients each time.
--   * **A question listing everything, every time**, unless "Skip the auto
--     buy dialog" is on, and then a line in chat per purchase. While Reagent
--     Economy spares the reagents the question comes anyway, as for a click.
--
-- One purchase for everything: Merchant.Purchase holds the buttons until it
-- has arrived, so a second purchase in the same moment would be refused.

local ADDON, FP = ...
local L = FP.L
local Merchant = FP.Merchant

local AutoBuy = {}
FP.AutoBuy = AutoBuy

local M = FP:RegisterModule("AutoBuy", {
    title   = L["Auto Buy"],
    default = false,
    desc    = L["Buys what you tick for it whenever you open a merchant who "
           .. "sells it: reagents and poisons up to their amounts, arrows or "
           .. "bullets as many as fit in your quiver or ammo pouch."],
    group   = "merchant",
    order   = 10,
    options = {
        { key = "skipDialog", type = "toggle", default = false,
          label = L["Skip the auto buy dialog"],
          desc  = L["Buys without asking first and reports the purchase in "
               .. "chat. Reagents always show the dialog when your class "
               .. "abilities do not require reagents from a merchant."] },
    },
})

--- Whether Auto Buy is running, so the ticks show and anything is bought.
function AutoBuy.On()
    return M.enabled == true
end

-- ---------------------------------------------------------------------------
-- The ticks, per character
--
-- FP.global.autoBuy[character][key] = true, or the name of a group of which
-- only one may be ticked. Account data like the gold records, so a profile
-- export leaves it out, and FP:ForgetCharacter takes it with the rest.
-- ---------------------------------------------------------------------------

local function Ticks(create)
    local who = FP:CharacterKey()
    if not (who and FP.global) then return nil end
    if type(FP.global.autoBuy) ~= "table" then
        if not create then return nil end
        FP.global.autoBuy = {}
    end
    local mine = FP.global.autoBuy[who]
    if type(mine) ~= "table" then
        if not create then return nil end
        mine = {}
        FP.global.autoBuy[who] = mine
    end
    return mine
end

--- Whether this character has the thing named `key` ticked for Auto Buy.
function AutoBuy.Is(key)
    local ticks = Ticks(false)
    return ticks ~= nil and ticks[key] ~= nil
end

--- Ticks or unticks it. With a `group`, ticking it unticks every other thing
--- of that group: one kind of arrow at a time.
function AutoBuy.Set(key, on, group)
    local ticks = Ticks(on)
    if not ticks then return end
    if on and group then
        for other, value in pairs(ticks) do
            if value == group then ticks[other] = nil end
        end
    end
    ticks[key] = on and (group or true) or nil
end

-- ---------------------------------------------------------------------------
-- What is due
-- ---------------------------------------------------------------------------

local providers = {}

--- Adds a source of things to buy automatically.
--
-- @param fn  answers nil, or { entries, warning }: `entries` a list of
--            { index, itemID, amount, cost, line, said }, `line` the entry in
--            the question and `said(n)` the chat line once n arrived;
--            `warning` a red line that brings the question anyway
function AutoBuy.AddProvider(name, fn)
    providers[#providers + 1] = { name = name, fn = fn }
end

local function Collect()
    local due = { entries = {}, warnings = {} }
    for _, provider in ipairs(providers) do
        local ok, plan = pcall(provider.fn)
        if not ok then
            FP:Warn(L["Error in %s: %s"], provider.name, tostring(plan))
        elseif type(plan) == "table" and type(plan.entries) == "table"
               and #plan.entries > 0 then
            for _, entry in ipairs(plan.entries) do
                due.entries[#due.entries + 1] = entry
            end
            if plan.warning then due.warnings[#due.warnings + 1] = plan.warning end
        end
    end
    return due
end

--- What the money allows, in order: an entry that no longer fits is left out.
local function Afford(entries)
    local budget = GetMoney and tonumber(GetMoney()) or math.huge
    local kept = {}
    for _, entry in ipairs(entries) do
        local cost = tonumber(entry.cost) or 0
        if cost <= budget then
            kept[#kept + 1] = entry
            budget = budget - cost
        end
    end
    return kept
end

local function Buy(entries)
    if not M.enabled or #entries == 0 then return end
    local list = {}
    for _, entry in ipairs(entries) do
        list[#list + 1] = { index = entry.index, itemID = entry.itemID,
            amount = entry.amount }
    end
    local bought = Merchant.Purchase(list)
    if not bought then return end
    for _, entry in ipairs(entries) do
        local n = bought[entry.itemID]
        if n and n > 0 and entry.said then FP:Print("%s", entry.said(n)) end
    end
end

--- The row on the Gameplay page, should the window be open.
local function RefreshMenu()
    local menu = FP.modules and FP.modules.Menu
    if menu and menu.Refresh then FP:Safe("Menu:Refresh", menu.Refresh, menu) end
end

-- ---------------------------------------------------------------------------
-- When a merchant window opens
-- ---------------------------------------------------------------------------

-- Set once this opening of a merchant window has been looked at.
local done

local function Run()
    if done or not M.enabled or not Merchant.IsOpen()
       or Merchant.NumItems() == 0 then
        return
    end
    done = true

    local due = Collect()
    local entries = Afford(due.entries)
    if #entries == 0 then return end
    if M.db.skipDialog and #due.warnings == 0 then
        Buy(entries)
        return
    end

    local lines, cost = {}, 0
    for _, entry in ipairs(entries) do
        lines[#lines + 1] = entry.line
        cost = cost + (tonumber(entry.cost) or 0)
    end
    Merchant.Ask({
        heading  = L["Buy Automatically"],
        question = L["Buy everything ticked for buying automatically?"],
        lines    = lines,
        warning  = (#due.warnings > 0) and table.concat(due.warnings, "\n") or nil,
        cost     = cost,
        -- Left off with a red line, which a skipped question could never show.
        skipTip  = (#due.warnings == 0)
            and L["Switches on \"Skip the auto buy dialog\" under Auto Buy on "
                .. "the Gameplay page, where it can be switched off again."]
            or nil,
        onBuy    = function(skip)
            if skip then
                M.db.skipDialog = true
                RefreshMenu()
            end
            -- Worked out again: the bags and the money may have moved while
            -- the question stood.
            Buy(Afford(Collect().entries))
        end,
    })
end

-- A moment after the merchant's events, since Core/Merchant.lua sets the
-- window open from the same MERCHANT_SHOW, and the order of the handlers of
-- one event is not defined. MERCHANT_UPDATE tries again while the merchant
-- has not listed its goods yet.
local events = CreateFrame("Frame")
for _, event in ipairs({ "MERCHANT_SHOW", "MERCHANT_UPDATE", "MERCHANT_CLOSED" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "MERCHANT_CLOSED" then
        done = nil
        return
    end
    if event == "MERCHANT_SHOW" then done = nil end
    if done or not M.enabled then return end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.2, function() FP:Safe("AutoBuy:Run", Run) end)
    else
        FP:Safe("AutoBuy:Run", Run)
    end
end)

-- Switched on or off: the ticks come and go beside the merchant's buttons
-- and in the reagent list.
function M:OnEnable()
    FP:Safe("Merchant:Refresh", Merchant.Refresh)
    RefreshMenu()
end

function M:OnDisable()
    FP:Safe("Merchant:Refresh", Merchant.Refresh)
    RefreshMenu()
end

function M:Reapply() end
