-- Consumables that run out: elixirs, potions, food, and what you put on a
-- weapon.
--
-- Asked for by a player on CurseForge on 2026-09-20, the first request this
-- project has had from outside.
--
-- It was granted as **expiry only**, on the argument that absence is a fault
-- for a class buff and the normal state for an elixir, so a missing warning
-- would fire constantly and teach somebody to ignore the display. **That was
-- reversed the same day**, and the thing that reverses it is the switch: a
-- ticked row says "I want this on me", which makes absence a fault the player
-- picked out for themselves. Nothing is ticked by default, so the noise the
-- original argument feared cannot reach anybody who did not ask for it.
--
-- So a warning looks exactly like one on the Buffs page: a countdown when it
-- is running out, a grayed icon when it is not there at all.
--
-- Settled in the phase 3 grilling on 2026-09-20, and the decisions that shape
-- this file are in ROADMAP.md with their reasoning:
--
--   a curated table, so the rule from phase 1.5 stands unchanged: nothing is
--   warned about that the addon was not told about
--   one entry per consumable rather than one per family, grouped into
--   categories, because two elixirs of different strength can still be unable
--   to sit on you at once
--   one threshold, shown at three minutes left. A floor under it, ten
--   minutes of total duration below which nothing counted down, went on
--   2026-10-05 at the owner's word: the list is where a player chooses what is
--   watched, so a second filter beside it only hid what they had ticked
--   every entry off by default, so that a stranger who installs the addon is
--   told nothing by this page. Until build 70009 there was a second reason:
--   a cold start returned every setting to its default, and nobody should
--   have had to switch a stranger's warnings off after each login
--
-- **The table does not exist yet, and that is the point of this file today.**
-- The owner chose to measure before building, so what ships first is the probe
-- below and the weapon half, which needs no table at all.
--
-- The weapon half is deliberately narrow: oils and sharpening stones, for
-- every class. Imbues and poisons stay where they are, in BuffExpiry. Both
-- modules read the weapon through Core/Weapon.lua, and since 2026-09-26 each
-- reads its own place on it: WoW Forever keeps a poison or an imbue beside a
-- stone or an oil rather than instead of one. Which stone or oil exactly is
-- still not something the client says, so the warning shows the picture of
-- what was asked for rather than of what is on the blade.
local ADDON, FP = ...
local L, N = FP.L, FP.N

-- ---------------------------------------------------------------------------
-- The probe
--
-- **Development scaffolding, switched off for 0.5.0.** That is step 7 of
-- Releasing in AGENTS.md and a rule rather than a note: a measurement exists
-- to answer a question about the owner's client, and a stranger who downloads
-- the addon would get chat lines about it and entries in their saved file in
-- return for nothing.
--
-- It stays in the file because it has more to do. Every id in
-- Data/Consumables.lua that came from a database has to be confirmed against
-- this client sooner or later, and four have already turned out to be absent.
-- Set it back to true, reload, carry the thing in your bags, and it writes
-- down what it sees.
--
-- Three questions, and the first is the one that decides how the finished
-- feature behaves in combat:
--
--   does using an item produce an event an addon can read
--   what do an elixir, a potion and a food buff look like out of combat
--   does the item behind such an aura reach us, with its level requirement
--
-- Everything is printed once as it is first seen, so a stack of elixirs can be
-- walked through in one sitting, and written to ForeverPlusDB as well, because
-- a chat line scrolls away and the file does not. Collect, reload, read the
-- file. Since build 70009 what was collected also comes back at the next start
-- and keeps growing across sessions, and no command forgets it: the
-- `consumables` table has to come out of the saved file by hand.
-- ---------------------------------------------------------------------------
local COLLECTING = false

-- What goes on a weapon is a table now, in Data/Consumables.lua: one block per
-- kind, every item in the game inside it, and one choice per hand across all of
-- them. Asked for on 2026-09-20, after the first version offered "an oil" and
-- "a stone" as two switches.
--
-- The client still cannot say which enchant is on the blade, so the choice does
-- not identify anything: it says what you would put there, which is where the
-- name and the picture on the warning come from.

-- The labels are marked here and translated where they are drawn: this file
-- loads before the language is known.
local HANDS = {
    { id = "main", key = "weaponMain", label = L["Main Hand"] },
    { id = "off",  key = "weaponOff",  label = L["Off Hand"] },
}

--- Whole minutes where it is whole minutes, seconds below one.
local function Duration(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    if seconds < 60 then return L["%d s"]:format(seconds) end
    if seconds % 60 == 0 then return L["%d min"]:format(math.floor(seconds / 60)) end
    return L["%d:%02d min"]:format(math.floor(seconds / 60), seconds % 60)
end

--- A value this client will actually let us handle, or the fallback.
--
-- Not paranoia: a secret value hands itself over intact and raises on the
-- first thing done with it, and tostring does not launder it. One of these
-- written into the saved file would be a value nothing can serialize, in a
-- file the player needs for everything else. See AGENTS.md on secret values.
local function Plain(value, fallback)
    local ok = pcall(function() return value == value end)
    if ok then return value end
    return fallback
end

-- Every spell id any class table mentions, so the probe is quiet about the
-- buffs that already have a home. Built once, on first use: the tables do not
-- change while the client runs.
-- Rebuilt rather than kept, because an item that resolves late adds to it and
-- a set that was right at login would be wrong an hour later. It is walked once
-- per scan over a few hundred numbers, which is nothing next to the aura reads
-- it guards.
local classIds
local function KnownToTables()
    classIds = {}

    local function add(list)
        for _, id in ipairs(list or {}) do classIds[id] = true end
    end

    -- Our own entries as well as the class tables. A watched elixir must not
    -- turn up a second time under the generic row.
    for _, group in ipairs(FP.consumables or {}) do
        for _, entry in ipairs(group.items) do
            if entry.spell then classIds[entry.spell] = true end
            if entry.resolved then classIds[entry.resolved] = true end
        end
    end

    for _, entries in pairs(FP.classBuffs or {}) do
        for _, entry in ipairs(entries) do
            for _, line in ipairs(entry.lines or {}) do add(line) end
            for _, variant in ipairs(entry.variants or {}) do add(variant.ids) end
            add(entry.requires)
            for _, line in ipairs(entry.rankLines or {}) do add(line) end
        end
    end
    return classIds
end

--- An item's name, the level it needs, and its picture.
--
-- **The global GetItemInfo does not exist on this build.** Measured the hard
-- way on 2026-09-20: the bag scan raised on it at every login. It lives under
-- C_Item here, and the global is kept as a fallback rather than dropped,
-- because a client that has one and not the other is exactly what this addon
-- keeps running into. AutoSellGray and QuestRewardValue already ask for it in
-- exactly this shape, which is where this should have been copied from rather
-- than written out again.
--
-- The returns are counted rather than unpacked through a row of underscores:
-- name, link, quality, item level, minimum level, type, subtype, stack size,
-- equip slot, texture, sell price. Miscounting that list has already told a
-- Shaman he was holding no weapon.
--
-- It takes an item id as readily as a link, and answers nil for an item this
-- client has never had to look at. That is a cache miss rather than a wrong
-- id, so nothing may be concluded from it: see CoatingName.
local function ItemFacts(link)
    local get = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
    if not get then return nil end

    local out = { pcall(get, link) }
    if not out[1] then return nil end
    return out[2], out[6], out[11]
end

--- Ask the client to fetch an item it has not needed yet.
local function RequestItem(id)
    local request = C_Item and C_Item.RequestLoadItemDataByID
    if request then pcall(request, id) end
end

--- What to call one coating on the page and on the warning.
--
-- The client's own name first, so it is the words the player reads in their
-- own language and on their own auction house. Our English name only when the
-- client has never heard of the item, which happens both for an id that is
-- wrong and for one that is simply not cached yet. Those two look identical
-- from here, so neither is announced: the row stays readable either way.
local function CoatingName(entry)
    if not entry then return nil end
    local name = ItemFacts(entry.item)
    return name or entry.name or L["Item %s"]:format(tostring(entry.item))
end

local function CoatingIcon(entry)
    if not entry then return FP.FALLBACK_ICON end
    local _, _, icon = ItemFacts(entry.item)
    return icon or FP.FALLBACK_ICON
end

-- Defined at the bottom, next to the controls they belong to, and declared
-- here because the option list names them. A local declared further down is
-- not that local to anything above it: it is a global, and a nil one.
local BuildCoatings, RefreshCoatings, ReportProbe
local BuildConsumables, RefreshConsumables
local BuildFood, RefreshFood
local BuildOverlap, RefreshOverlap

-- And the module itself, for the same reason and at the cost of one more
-- line. The option list below closes over it, RegisterModule is called after
-- the list exists, and reading `M` from a closure written above that call
-- reaches a global rather than this local. That is the exact fault the
-- paragraph above describes, and it still cost a reload to find.
local M

local options = {
    -- No General heading any more: since the redesign of 2026-10-15 nothing
    -- stood under it, the owner's report, since the switch below is drawn on
    -- the tab and everything else went to bar management.

    -- The box on the Consumables tab since 2026-09-30; this entry only words
    -- it there. A sentence rather than a label, and no "all": the entries on
    -- the page can silence one consumable while this is still on.
    { type = "module", labelOn  = L["Consumable warnings are on"],
      labelOff = L["Consumable warnings are off"],
      desc  = L["The master switch for this page. Everything on it only decides "
           .. "what it warns about and when.|n|nOff means no icons at all. The "
           .. "settings are kept, so turning it back on restores what you had."] },

    -- The icon size, the countdown, the look of a missing icon and the
    -- display's place stood here until the redesign of 2026-10-15. They
    -- belong to a bar since, set in bar management, which this button and the
    -- one on the Buffs page both open. See Core/Bars.lua.
    { type = "group", label = L["Bars"] },

    { type = "action", label = L["Manage bars"], width = 150,
      desc  = L["Opens bar settings for buffs and consumables: size, "
           .. "appearance and screen position."],
      run   = function() FP:OpenBarManager() end },

    { type = "group", label = L["Conditions"] },

    { key = "warnSeconds", type = "number", default = 180,
      label = L["Warn at"], min = 30, max = 900, step = 30,
      format = Duration,
      desc  = L["The remaining time at which a consumable warning appears."] },

    -- "Only watch what lasts at least" stood here until 2026-10-05, a floor
    -- of total duration below which nothing counted down. The owner took it
    -- out: ticking a row is the choice, and nothing else should overrule it.
    -- A profile that stored it keeps a key nothing reads, as with the
    -- battleground switch in BuffExpiry.

    -- The matrix: a row per coating, a column per hand, and one choice per
    -- column. It carries its own heading, so there is none declared here.
    -- Four parts, in this order: food, what goes on a weapon, everything you
    -- drink, and last the scrolls a class buff replaces. Asked for that way on
    -- 2026-09-20, and it runs from what somebody touches most often to what
    -- they touch when nobody cast the real thing on them.
    { type = "custom",
      build   = function(holder, width) return BuildFood(holder, width) end,
      refresh = function() RefreshFood() end },

    { type = "custom",
      build   = function(holder, width) return BuildCoatings(holder, width) end,
      refresh = function()
          RefreshCoatings()
          if M.LayoutCoatings then M.LayoutCoatings() end
      end },

    -- Everything you drink, under its own heading.
    { type = "custom",
      build   = function(holder, width) return BuildConsumables(holder, width) end,
      -- Both, and the order matters: the rows take their names from the
      -- client, and only a layout decides which of them are showing. A search
      -- is an option change like any other, so this is what hears about it.
      refresh = function()
          RefreshConsumables()
          if M.LayoutLists then M:LayoutLists() end
      end },

    -- And the ones a Priest or a Mage makes pointless, kept apart rather than
    -- ranked last inside a category. They are a different kind of thing: what
    -- you carry for the day nobody casts the real buff on you.
    { type = "custom",
      build   = function(holder, width) return BuildOverlap(holder, width) end,
      refresh = function()
          RefreshOverlap()
          if M.LayoutLists then M:LayoutLists() end
      end },


    -- Which consumables are watched, keyed the way Data/Consumables.lua keys
    -- them, and holding only what differs from the table. Nothing in the table
    -- is on, so nothing warns anybody who did not ask for it. An entry *may*
    -- start on, and none does: on this client a default of on cannot be
    -- refused for longer than one session.
    { key = "watch", type = "store" },

    -- What is on each hand, or nil for nothing. One value per hand rather than
    -- a checkbox per cell, which is what makes "only one at a time" a property
    -- of the storage instead of a rule somebody has to remember to enforce.
    { key = "weaponMain", type = "store" },
    { key = "weaponOff",  type = "store" },
}

-- Only while measuring.
if COLLECTING then
    options[#options + 1] = { type = "group", label = L["Measurement"] }
    options[#options + 1] = {
        type = "action", label = L["Print what was recorded"], width = 200,
        desc = L["Prints everything the probe recorded during this session "
            .. "in chat. The data is also saved and restored after a reload."],
        run  = function() ReportProbe() end,
    }
end

M = FP:RegisterModule("Consumables", {
    default = true,
    desc    = L["Warns when a selected consumable effect is missing or about "
           .. "to expire."],

    -- A page rather than rows, and off the module list entirely: a row that
    -- cannot be opened and only leads somewhere else earns its space badly.
    -- The switch is the box on the page's tab instead, like every page's
    -- since 2026-09-30.
    page      = N["Consumables"],
    pageOrder = 30,
    hidden    = true,

    options = options,
})

local TICK = 1      -- seconds between checks

-- The icons are drawn on the profile's bars since the redesign of 2026-10-15,
-- see Core/Bars.lua and Core/Warnings.lua. Every entry here starts on the bar
-- called Consumables, above the buff warnings where this display always was.

--- The key an entry's bar and own warning time are kept under, see
--- Core/Bars.lua: the page's own key with the page in front of it. The two
--- coatings are one entry per hand.
local function EntryKey(entry)
    return "cons:" .. tostring(entry.key)
end
local function HandKey(hand)
    return "cons:coat/" .. hand.id
end
M.EntryKey, M.HandKey = EntryKey, HandKey

--- How much has to be left before a warning: the entry's own time where the
--- player gave it one, the page's otherwise. Zero means none before it runs
--- out; the missing warning is not a time and stays.
function M:WarnAt(key)
    local own = FP.Bars.Warn(FP.Bars.Store(), key)
    if own then return own end
    return self.db.warnSeconds
end

-- ---------------------------------------------------------------------------
-- What you drink
--
-- An entry is watched by its **aura**, so the only number that really matters
-- is the spell id. Four of them are measured and written down; every other
-- entry hands its item to the client and asks what that item casts, which is
-- the same route the probe proved works here and costs nothing but a lookup.
--
-- Everything else about a row, its name, its picture and the level it needs,
-- comes from the client as well. The table carries an English fallback for a
-- row the client has never had to look at, and nothing is ever compared
-- against it.
-- ---------------------------------------------------------------------------

--- The aura this entry is watched by, or nil while the client is still looking.
local function EntrySpell(entry)
    if entry.generic then return nil end
    if entry.spell then return entry.spell end
    if entry.resolved then return entry.resolved end
    if not entry.item then return nil end

    local get = C_Item and C_Item.GetItemSpell
    if not get then return nil end

    -- By id first, and by a bare link if that says nothing. Only the link is
    -- measured on this build, from the probe reading the bags, and the two
    -- cost the same. A client that answers one and not the other is exactly
    -- what this addon keeps running into.
    for _, form in ipairs({ entry.item, "item:" .. entry.item }) do
        local ok, _, spellId = pcall(get, form)
        spellId = Plain(spellId, nil)
        if ok and type(spellId) == "number" then
            entry.resolved = spellId
            return spellId
        end
    end
    return nil
end

--- What to call it: the client's word for the item, then for the spell, then
--- ours. An item that has never been looked at answers nil rather than wrongly,
--- which is why this falls through rather than stopping at the first nil.
local function EntryName(entry)
    if entry.generic then return FP:T(entry.name) or "?" end
    if entry.item then
        local name = ItemFacts(entry.item)
        if name then return name end
    end
    local spell = EntrySpell(entry)
    if spell then
        local name = FP:SpellName(spell)
        if name then return name end
    end
    return entry.name or "?"
end

local function EntryIcon(entry)
    if entry.generic then return entry.icon or FP.FALLBACK_ICON end
    if entry.item then
        local _, _, icon = ItemFacts(entry.item)
        if icon then return icon end
    end
    local spell = EntrySpell(entry)
    local icon  = spell and FP:SpellIcon(spell)
    return icon or FP.FALLBACK_ICON
end

--- The level the item asks for, or nil while the client has not said.
local function EntryLevel(entry)
    if not entry.item then return nil end
    local _, reqLevel = ItemFacts(entry.item)
    return reqLevel
end

--- Has the client answered about this entry at all?
--
-- Used to dim a row rather than to hide it. An item the client cannot resolve
-- is either an id this build does not have, which is a mistake in the table,
-- or one it has simply never had to look up, and **those two are identical
-- from in here**. Dimming says "unconfirmed" without claiming which.
local function EntryKnown(entry)
    if entry.generic then return true end
    if entry.spell and FP:SpellName(entry.spell) then return true end
    if entry.item and ItemFacts(entry.item) then return true end
    return false
end

local function PlayerLevel()
    if not UnitLevel then return 1 end
    local ok, level = pcall(UnitLevel, "player")
    return (ok and type(level) == "number") and level or 1
end

--- Could the player have this on them at all?
--
-- The same question BuffExpiry asks before saying a buff is missing, and it
-- exists for the same reason: an icon nobody can clear is worse than none. A
-- level 20 character who ticks a level 43 elixir would otherwise be told for
-- ever that it is absent, and no shop in the world could fix it.
local function Usable(entry)
    if entry.generic then return true end
    local need = EntryLevel(entry)
    return not need or need <= PlayerLevel()
end

--- Is this entry being watched?
--
-- An entry may start switched on, which exactly one does. So a stored value
-- has to be able to say "off" against a default of on, and absent has to mean
-- "whatever the table says" rather than "off": nil and false are different
-- answers here, and conflating them would make the food row impossible to
-- turn off.
--- The real item card on hover, and the same one everywhere.
--
-- **Hung on every frame that can be pointed at, not only on the row.** A child
-- frame with the mouse enabled takes OnEnter away from its parent, so the two
-- boxes on a weapon row used to blank the tooltip at exactly the spot somebody
-- is aiming for. Asked for on 2026-09-20.
--
-- It is also what gives a wrong id away: the card is the item, not our idea of
-- it.
--
-- **An item keeps Blizzard's own card**, by the owner's rule of 2026-09-26: a
-- tooltip that shows one of the game's own objects stays in the game's design,
-- and only what the addon says itself wears the addon's. So an item row shows
-- the GameTooltip, and the addon's tooltip takes over only where there is no
-- item behind the row, the food row, or an item the client has not loaded.
local function AttachTooltip(frame, entry)
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        if entry.item and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if pcall(GameTooltip.SetItemByID, GameTooltip, entry.item)
               and GameTooltip:NumLines() > 0 then
                return GameTooltip:Show()
            end
            GameTooltip:Hide()
        end

        -- No item, or one this client has never looked up. Say what is known
        -- rather than nothing: an empty tooltip reads as broken.
        local spell = EntrySpell(entry)
        FP:ShowTip(self, {
            EntryName(entry),
            { entry.desc
                or (spell and L["Spell %s"]:format(tostring(spell)))
                or (entry.item and L["Item %s, not loaded yet"]:format(tostring(entry.item)))
                or L["Nothing to look up"],
              wrap = true },
        })
    end)
    frame:SetScript("OnLeave", function(self)
        if GameTooltip and GameTooltip:GetOwner() == self then GameTooltip:Hide() end
        FP:HideTip(self)
    end)
end

local function Watched(entry)
    local list   = M.db and M.db.watch
    local stored = list and list[entry.key]
    if stored ~= nil then return stored and true or false end
    return entry.default and true or false
end

local function SetWatched(entry, value)
    if not M.db then return end
    value = value and true or false

    -- Created on first use rather than as a default: a table handed out as a
    -- default is shared between profiles by reference, and that is a bug
    -- waiting for somebody to find it.
    M.db.watch = M.db.watch or {}

    -- Only what differs from the table is written down, so the stored list
    -- stays a list of exceptions rather than a copy of the page.
    if value == (entry.default and true or false) then
        M.db.watch[entry.key] = nil
    else
        M.db.watch[entry.key] = value
    end

    if value and entry.item then RequestItem(entry.item) end
    FP:Safe("Consumables:Update", M.Update, M)
end

--- Every entry that is being watched, whatever category it sits in.
local function EachWatched(fn)
    for _, group in ipairs(FP.consumables or {}) do
        for _, entry in ipairs(group.items) do
            if Watched(entry) then fn(entry) end
        end
    end
end

-- ---------------------------------------------------------------------------
-- What goes on a weapon
--
-- The client says whether a slot carries a temporary enchant and how long it
-- has left. It does not say which enchant, and it cannot be made to without
-- comparing English words, which the locale rule forbids outright. So the
-- picture and the name come from what was asked for rather than from what is
-- there, which the owner settled directly: you could replace whatever is on
-- the weapon with the one you picked, so the one you picked is the useful
-- thing to show.
--
-- Nothing is read in combat and nothing needs to be. An oil or a stone cannot
-- be applied in a fight, so the only way a warning here could go stale is one
-- the player cannot perform.
-- ---------------------------------------------------------------------------

local function ChosenOn(hand)
    return M.db and M.db[hand.key] or nil
end

--- Picks one coating for one hand, or clears it.
--
-- One stored value per hand, which is what makes "only one at a time" a
-- property of the storage rather than a rule somebody has to enforce over
-- twenty rows. Choosing another item simply overwrites it, and choosing the
-- one already there clears the hand.
--
-- That is the one place in this addon where a setting moves another, and it is
-- not the trap AGENTS.md warns about: it is a single choice with one slot,
-- asked for that way, and every row that can hold it is on the same page.
local function ChooseOn(hand, item)
    if not M.db then return end

    -- Spelled out rather than written as a conditional expression, and that is
    -- not a matter of taste. `cond and nil or item` cannot ever produce nil:
    -- `true and nil` is nil, and `nil or item` is item again, so clicking a
    -- box a second time set it right back. Lua's and/or has no way to yield
    -- nil, and nothing about the line says so.
    if ChosenOn(hand) == item then
        M.db[hand.key] = nil
    else
        M.db[hand.key] = item
        RequestItem(item)
    end

    FP:Safe("Consumables:Update", M.Update, M)
end

--- Will this client answer a question about auras at all, right now?
--
-- Asked rather than inferred, which is the whole of the bug BuffExpiry shipped
-- on 2026-09-20: a refused read and an absent buff both come back as nil from
-- the by id route, so treating nil as "it is gone" is only correct while the
-- client is answering. The index route is the detector because it is the one
-- that refuses out loud.
local function ReadsAllowed()
    local byIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if not byIndex then return false end
    return (pcall(byIndex, "player", 1, "HELPFUL"))
end

local function ReadPlayerAura(spellId)
    local get = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
    if not get then return nil end

    local ok, aura = pcall(get, spellId)
    if not ok or type(aura) ~= "table" then return nil end
    return aura
end

-- The client's name for an ordinary food buff, Well Fed in English, read once
-- the client will give it. See FP.FOOD_NAME_SPELLS in Data/Consumables.lua.
local foodName

local function FoodName()
    if foodName then return foodName end
    for _, id in ipairs(FP.FOOD_NAME_SPELLS or {}) do
        local name = FP:SpellName(id)
        if type(name) == "string" and name ~= "" then
            foodName = name
            return name
        end
    end
    return nil
end

--- Is this aura food? By the client's own name for a food buff, or by the
--- short list of food buffs with names of their own.
--
-- **Only what is known to be food counts**, since 2026-09-28. Until then the
-- row took any timed buff nothing else accounted for and kept a list of what
-- it must never pick up, and two racials in six days showed that list would
-- never be finished. See Data/Consumables.lua for the whole story.
local function IsFood(id, name)
    if FP.foodIds and FP.foodIds[id] then return true end
    local wanted = FoodName()
    return wanted ~= nil and name == wanted
end

--- The food buff running on you, if there is one.
--
-- **The generic entry, and the only place this module reads an aura it was not
-- told about by id.** It is off until somebody asks for it.
--
-- Picked by whichever expires first, because that is the one worth an icon.
-- The picture comes from the aura rather than from us, so what you see is the
-- food you are actually carrying.
local function GenericAura()
    local byIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if not byIndex then return nil end

    local best
    for index = 1, 40 do
        local ok, aura = pcall(byIndex, "player", index, "HELPFUL")
        if ok and type(aura) == "table" then
            local id       = Plain(aura.spellId, nil)
            local name     = Plain(aura.name, nil)
            local duration = Plain(aura.duration, 0) or 0
            local expires  = Plain(aura.expirationTime, 0) or 0

            if type(id) == "number" and IsFood(id, name) and expires > 0
               and (not best or expires < best.expires) then
                best = {
                    duration = duration, expires = expires,
                    icon = Plain(aura.icon, nil),
                }
            end
        end
    end
    return best
end

--- What is on the player, of the things being watched.
function M:ScanAuras()
    if not ReadsAllowed() then return end

    self.aura = self.aura or {}
    EachWatched(function(entry)
        if entry.generic then
            self.aura[entry.key] = GenericAura()
            return
        end

        local spell = EntrySpell(entry)
        local aura  = spell and ReadPlayerAura(spell)
        if aura then
            self.aura[entry.key] = {
                duration = Plain(aura.duration, 0) or 0,
                expires  = Plain(aura.expirationTime, 0) or 0,
            }
        else
            self.aura[entry.key] = nil
        end
    end)
end

function M:Scan()
    -- Nothing to read while dead, and nothing to act on either.
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return end
    if InCombatLockdown and InCombatLockdown() then return end

    FP:Safe("Consumables:ScanAuras", M.ScanAuras, self)

    -- Nothing picked, nothing read. Every entry starts switched off on this
    -- client, so this is the ordinary case rather than the empty one, and a
    -- tooltip built twice a second for a question nobody asked is exactly the
    -- kind of cost a stranger should not be paying.
    local wanted = false
    for _, hand in ipairs(HANDS) do
        if ChosenOn(hand) then wanted = true end
    end
    if not wanted then
        self.weapon = nil
    else
        FP:Safe("Consumables:ScanWeapons", M.ScanWeapons, self)
    end

    self.scanned = true
end

--- What is on the weapons, of the things being watched.
function M:ScanWeapons()
    local enchants = FP:WeaponEnchants()
    local now = GetTime()

    self.weapon = self.weapon or {}
    for _, hand in ipairs(HANDS) do
        -- The coating place only. On WoW Forever a poison or an imbue sits in
        -- a place of its own beside the stone or oil, and says nothing about
        -- it: see Core/Weapon.lua.
        local reading = enchants and enchants[hand.id]
        local side = reading and reading.coating
        if side and side.has then
            self.weapon[hand.id] = { expires = now + side.remaining }
        else
            self.weapon[hand.id] = nil
        end
    end
end

function M:Evaluate()
    -- Nothing has been read yet, so nothing is known to be missing. Logging in
    -- during a fight would otherwise report every slot as bare.
    if not self.scanned then return {} end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return {} end

    local now     = GetTime()
    local combat  = InCombatLockdown and InCombatLockdown()
    local out     = {}

    for _, hand in ipairs(HANDS) do
        local coat = FP.weaponCoatingByItem and FP.weaponCoatingByItem[ChosenOn(hand)]
        -- A slot with no weapon in it cannot be coated, so saying it is bare
        -- would be a warning nobody can clear. That is the same test the
        -- imbue warning makes about a shield in the off hand.
        if coat and FP:HasWeapon(hand.id) then
            local state     = self.weapon and self.weapon[hand.id]
            local remaining = state and (state.expires - now) or nil

            if remaining and remaining > 0 then
                if remaining <= self:WarnAt(HandKey(hand)) then
                    out[#out + 1] = {
                        kind = "expiring", icon = CoatingIcon(coat),
                        remaining = remaining, sort = 1 + remaining,
                        label = CoatingName(coat) .. ", " .. FP:T(hand.label),
                        key = HandKey(hand),
                    }
                end
            elseif not combat then
                -- Bare, and the reading is current. In combat the same
                -- picture would be a fact nobody can act on, so it waits.
                out[#out + 1] = {
                    kind = "missing", icon = CoatingIcon(coat), sort = 0,
                    label = CoatingName(coat) .. ", " .. FP:T(hand.label),
                    key = HandKey(hand),
                }
            end
        end
    end

    -- And what you asked to be told about.
    --
    -- **Absence is a warning here, and that reverses how this phase started.**
    -- It was to be expiry only, on the argument that an elixir you are not
    -- carrying is the ordinary state of affairs and a warning about it would
    -- fire for ever. The argument holds right up until somebody ticks a box:
    -- a ticked row says "I want this on me", which makes absence a fault the
    -- player chose to be told about, exactly as on the Buffs page. Nothing is
    -- ticked by default, so nobody is told anything they did not ask for.
    -- Settled on 2026-09-20; see ROADMAP.md for what it replaced.
    EachWatched(function(entry)
        local state     = self.aura and self.aura[entry.key]
        local remaining = state and ((state.expires or 0) - now) or nil

        if remaining and remaining > 0 then
            -- Whatever it lasts: a short buff counts down from the moment it
            -- lands, and that is what the player asked for by ticking it.
            if remaining <= self:WarnAt(EntryKey(entry)) then
                out[#out + 1] = {
                    kind = "expiring", icon = state.icon or EntryIcon(entry),
                    remaining = remaining, sort = 1 + remaining,
                    label = EntryName(entry), key = EntryKey(entry),
                }
            end
            return
        end

        -- Nothing on you, or it ran out while the client was not answering.
        -- In combat that is still worth showing: using an item fires an event
        -- an addon can read, measured on this build, so the player can clear
        -- it and be seen doing it.
        if Usable(entry) then
            out[#out + 1] = {
                kind = "missing", icon = EntryIcon(entry), sort = 0,
                label = EntryName(entry), key = EntryKey(entry),
            }
        end
    end)

    table.sort(out, function(a, b) return a.sort < b.sort end)
    return out
end

--- A cast landed. If it was something we watch, it has just been renewed.
--
-- The only update this client gives us in a fight, and the measurement that
-- made the whole phase possible: using an item fires this with a plain
-- readable spell id. The duration comes from the last proper read, so the
-- countdown stays exact rather than invented.
function M:NoteCast(spellId)
    if not spellId then return end

    EachWatched(function(entry)
        if EntrySpell(entry) ~= spellId then return end

        local previous = self.aura and self.aura[entry.key]
        local duration = previous and previous.duration or 0
        self.aura = self.aura or {}
        self.aura[entry.key] = {
            duration = duration,
            expires  = duration > 0 and (GetTime() + duration) or 0,
        }
    end)
end

--- Every entry that is switched on, with its factory bar, for the counts in
--- bar management: what is watched, and each hand that has a coating chosen.
function M:BarEntries()
    local out = {}
    EachWatched(function(entry)
        out[#out + 1] = { key = EntryKey(entry), factory = "consumables" }
    end)
    for _, hand in ipairs(HANDS) do
        if ChosenOn(hand) then
            out[#out + 1] = { key = HandKey(hand), factory = "consumables" }
        end
    end
    return out
end

--- The page's warning time back to its default, for restoring the default
--- setup with its box for warning times ticked.
function M:ResetWarningTimes()
    self.db.warnSeconds = FP:OptionDefaults(self).warnSeconds
end

--- Moves the bar the consumables start on. What /fplus cons did before the
--- bars were the profile's, kept so the command still does something useful.
function M:TogglePreview()
    if FP.MoveBars then FP:MoveBars("consumables") end
end

function M:Update()
    self:Scan()

    local items = self:Evaluate()
    for _, item in ipairs(items) do
        item.factory = "consumables"
        item.rid = tostring(item.key) .. "|" .. tostring(item.kind)
    end
    FP:HandIn("cons", items)
end

--- Why the page is doing what it is doing, in one screenful.
--
-- The module reads what the client allows, at a moment the player is not
-- watching, and then says nothing for twenty minutes because that is correct.
-- From outside, correct and broken look identical, and "nothing happens" is
-- not something anybody can act on.
--
-- So it says what it knows: what is ticked, what that resolved to, whether the
-- aura is there, and how long is left. Every line of it answers one form of
-- "why is there no icon".
function M:Status()
    local lines = {}
    local function Say(fmt, ...)
        local text = string.format(fmt, ...)
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffffff" .. text .. "|r")
        lines[#lines + 1] = text
    end

    FP:Print("Consumables, what it sees right now:")

    local now = GetTime()
    Say("%-26s %s", "module", FP:IsEnabled("Consumables") and "on" or "off")
    Say("%-26s %s", "the client answers auras", ReadsAllowed() and "yes" or "no")
    Say("%-26s %s", "read anything yet", self.scanned and "yes" or "no")
    Say("%-26s %s left", "warn when under", Duration(self.db.warnSeconds))

    -- What goes on a weapon, and what is on it.
    for _, hand in ipairs(HANDS) do
        local coat  = FP.weaponCoatingByItem and FP.weaponCoatingByItem[ChosenOn(hand)]
        local state = self.weapon and self.weapon[hand.id]
        Say("%-26s %s", hand.label, coat and CoatingName(coat) or "nothing picked")
        if coat then
            Say("%-26s %s", "  on the weapon",
                state and (Duration(math.max(0, state.expires - now)) .. " left")
                      or (FP:HasWeapon(hand.id) and "nothing" or "no weapon in that hand"))
        end
    end

    -- And everything ticked on the page.
    local any = false
    for _, group in ipairs(FP.consumables or {}) do
        for _, entry in ipairs(group.items) do
            if Watched(entry) then
                any = true
                local spell = EntrySpell(entry)
                local state = self.aura and self.aura[entry.key]
                local where

                if entry.generic then
                    where = "any timed buff no table knows"
                elseif spell then
                    where = "spell " .. spell
                elseif entry.item then
                    where = "item " .. entry.item .. ", not resolved yet"
                else
                    where = "nothing to ask for"
                end

                Say("%-26s %s", EntryName(entry), where)
                if state then
                    Say("%-26s %s of %s left", "  on you",
                        Duration(math.max(0, (state.expires or 0) - now)),
                        Duration(state.duration or 0))
                else
                    Say("%-26s %s", "  on you", "no")
                end
            end
        end
    end
    if not any then
        Say("%s", "nothing is ticked on the page, so nothing is watched")
    end

    return lines
end

-- ---------------------------------------------------------------------------
-- The probe, in detail
-- ---------------------------------------------------------------------------

local function Store()
    if not COLLECTING then return nil end
    ForeverPlusDB = ForeverPlusDB or {}
    ForeverPlusDB.consumables = ForeverPlusDB.consumables or {
        auras = {}, casts = {}, items = {},
    }
    return ForeverPlusDB.consumables
end

-- spell id -> what in the bags casts it. Rebuilt when the bags change, which
-- has to happen *before* the item is used: by the time the aura appears the
-- last one of a stack is gone.
local bagSpells = {}

local function ScanBags()
    if not COLLECTING then return end
    local container = C_Container
    local getSpell  = C_Item and C_Item.GetItemSpell
    if not (container and container.GetContainerNumSlots and getSpell) then return end

    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local ok, slots = pcall(container.GetContainerNumSlots, bag)
        if ok and (slots or 0) > 0 then
            for slot = 1, slots do
                -- Two shapes are possible and nobody has asked this build
                -- which it has: a table with the link on it, or the older
                -- string of returns with the link seventh.
                local read, info, _, _, _, _, _, old7 =
                    pcall(container.GetContainerItemInfo, bag, slot)
                local link
                if read then
                    if type(info) == "table" then
                        link = info.hyperlink or info.itemLink
                    else
                        link = old7
                    end
                end
                if link then
                    local found, _, spellId = pcall(getSpell, link)
                    spellId = Plain(spellId, nil)
                    if found and spellId then
                        local name, reqLevel, icon = ItemFacts(link)
                        bagSpells[spellId] = {
                            link = link, name = name,
                            reqLevel = reqLevel, icon = icon,
                        }

                        -- Written down as well, and this is the half that
                        -- builds the table: an item in the bags gives up its
                        -- id and what it casts without being used, so a
                        -- consumable this build invented can be found by
                        -- carrying one rather than by drinking it.
                        local db = Store()
                        local id = tonumber(link:match("item:(%d+)"))
                        if db and id then
                            db.items[id] = {
                                name = name, spell = spellId,
                                reqLevel = reqLevel, icon = icon,
                            }
                        end
                    end
                end
            end
        end
    end
end

--- One line per thing nobody has seen before, and nothing for a repeat.
local function NoteAura(aura)
    local db = Store()
    if not db then return end

    local id = Plain(aura.spellId, nil)
    if type(id) ~= "number" or KnownToTables()[id] then return end

    local name     = Plain(aura.name, "?")
    local duration = Plain(aura.duration, 0)
    local icon     = Plain(aura.icon, nil)

    local known = db.auras[id]
    if known then
        known.seen = (known.seen or 1) + 1
        return
    end

    local item = bagSpells[id]
    db.auras[id] = {
        name     = name,
        duration = duration,
        icon     = icon,
        item     = item and item.name or nil,
        reqLevel = item and item.reqLevel or nil,
        itemIcon = item and item.icon or nil,
        seen     = 1,
    }

    FP:Print("probe: aura %d, %s, lasts %s%s", id, tostring(name),
             Duration(duration),
             item and (", from " .. tostring(item.name)
                       .. " (level " .. tostring(item.reqLevel) .. ")") or "")
end

--- Walks what is on the player. Out of combat only: in combat this client
--- refuses every index read, and a refusal raises rather than returning nil.
local function ProbeAuras()
    if not COLLECTING then return end
    if InCombatLockdown and InCombatLockdown() then return end

    local byIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if not byIndex then return end

    for index = 1, 40 do
        local ok, aura = pcall(byIndex, "player", index, "HELPFUL")
        if ok and type(aura) == "table" then
            -- Only what runs out. A permanent aura has nothing to warn about,
            -- and this phase is about things that end.
            local timed = false
            local usable, answer = pcall(function()
                return (aura.duration or 0) > 0
            end)
            if usable then timed = answer end
            if timed then FP:Safe("Consumables:NoteAura", NoteAura, aura) end
        end
    end
end

--- Did using an item reach us at all, and as what?
--
-- The whole reason the probe exists. If this stays empty while elixirs are
-- being drunk, then nothing the player does in a fight can be observed, and
-- the finished feature has to hide its warnings in combat rather than show a
-- countdown it cannot correct.
local function NoteCast(spellId, unit)
    local db = Store()
    if not db or not spellId then return end

    local known = db.casts[spellId]
    if known then
        known.count = (known.count or 1) + 1
        -- One entry per id, but a list of the units it has arrived under: the
        -- same spell coming from the player and from something else is the
        -- difference between a cast and a proc.
        if unit and known.units and not known.units:find(unit, 1, true) then
            known.units = known.units .. " " .. unit
        end
        return
    end

    local item = bagSpells[spellId]
    db.casts[spellId] = {
        name  = FP:SpellName(spellId),
        item  = item and item.name or nil,
        reqLevel = item and item.reqLevel or nil,
        icon  = item and item.icon or nil,
        units = unit or "?",
        count = 1,
    }

    if item then
        FP:Print("probe: cast %d came from an item, %s (level %s), icon %s",
                 spellId, tostring(item.name), tostring(item.reqLevel),
                 tostring(item.icon))
    end
end

function ReportProbe()
    local db = Store()
    if not db then
        FP:Print("The probe is switched off in this build.")
        return
    end

    local function Say(fmt, ...)
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffffff" .. string.format(fmt, ...) .. "|r")
    end

    FP:Print("Consumables probe, what has been seen:")

    local any = false
    for id, row in pairs(db.auras) do
        any = true
        Say("aura %-7d %-28s %-9s %s", id, tostring(row.name),
            Duration(row.duration or 0),
            row.item and (row.item .. " (level " .. tostring(row.reqLevel) .. ")")
                      or "no item found for it")
    end
    if not any then Say("%s", "no timed aura outside the class tables yet") end

    any = false
    for id, row in pairs(db.casts) do
        any = true
        Say("cast %-7d %-28s %s", id, tostring(row.name),
            row.item and ("from " .. row.item) or "not an item in your bags")
    end
    if not any then
        Say("%s", "no cast recorded yet, so item use may not reach us at all")
    end
end

-- ---------------------------------------------------------------------------
-- Wiring
-- ---------------------------------------------------------------------------

function M:OnEnable()
    self.watcher = self.watcher or CreateFrame("Frame")
    self.watcher:SetScript("OnEvent", function(_, event, unit, _, spellId)
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            -- The probe takes every unit, the module only its own.
            --
            -- Widened on 2026-09-20 for one question: a Lightning Shield that
            -- discharges produced nothing at all in the first measurement, and
            -- "it is not a cast" and "it is a cast by somebody else" look the
            -- same from behind a filter that throws the second away. If it
            -- arrives under any unit at all, the charges can be counted and a
            -- spent shield can be shown mid fight.
            if COLLECTING then
                FP:Safe("Consumables:NoteCast", NoteCast, spellId, unit)
            end
            if unit ~= "player" then return end
            -- Renewing something mid fight is the one thing that can be seen
            -- in there, so it is the one thing that clears a warning.
            FP:Safe("Consumables:Renewed", M.NoteCast, M, spellId)
            FP:Safe("Consumables:Update", M.Update, M)
            return
        end

        if event == "GET_ITEM_INFO_RECEIVED" then
            -- Only while somebody is looking at the list. This fires in
            -- floods at login, and refreshing a page nobody has open is work
            -- done for nothing.
            local menu = _G.ForeverPlusMenu
            if menu and menu:IsShown() then
                if RefreshCoatings then
                    FP:Safe("Consumables:RefreshCoatings", RefreshCoatings)
                end
                if RefreshConsumables then
                    FP:Safe("Consumables:RefreshFood", RefreshFood)
                    FP:Safe("Consumables:RefreshList", RefreshConsumables)
                    FP:Safe("Consumables:RefreshOverlap", RefreshOverlap)
                end
                -- A level that has just arrived can change which row the
                -- filter leaves standing, so the list is placed again.
                if M.LayoutLists then
                    FP:Safe("Consumables:LayoutLists", M.LayoutLists, M)
                end
            end
            return
        end

        if event == "BAG_UPDATE_DELAYED" then
            if COLLECTING then FP:Safe("Consumables:ScanBags", ScanBags) end
            return
        end

        if event == "UNIT_AURA" then
            if unit ~= "player" then return end
            if COLLECTING then FP:Safe("Consumables:ProbeAuras", ProbeAuras) end
            return
        end

        if COLLECTING and event == "PLAYER_ENTERING_WORLD" then
            FP:Safe("Consumables:ScanBags", ScanBags)
            FP:Safe("Consumables:ProbeAuras", ProbeAuras)
        end

        FP:Safe("Consumables:Update", M.Update, M)
    end)

    self.watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    self.watcher:RegisterEvent("UNIT_AURA")
    self.watcher:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self.watcher:RegisterEvent("BAG_UPDATE_DELAYED")
    self.watcher:RegisterEvent("GET_ITEM_INFO_RECEIVED")

    -- The countdown needs a beat of its own: nothing fires while an enchant
    -- ticks down.
    if C_Timer and C_Timer.NewTicker then
        self.ticker = self.ticker or C_Timer.NewTicker(TICK, function()
            FP:Safe("Consumables:Update", M.Update, M)
        end)
    else
        FP:Warn(L["Consumables: C_Timer.NewTicker is missing, so the countdown "
              .. "only updates when something changes."])
    end

    if COLLECTING then
        FP:Safe("Consumables:ScanBags", ScanBags)
        FP:Safe("Consumables:ProbeAuras", ProbeAuras)
    end
    self:Update()
end

--- Settings changed while the module stays on.
function M:Reapply()
    FP:Safe("Consumables:Update", M.Update, M)
end

function M:OnDisable()
    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end
    if self.watcher then self.watcher:UnregisterAllEvents() end
    -- Only this page's icons leave the bars; the Buffs page keeps its own on a
    -- bar the two share.
    FP:HandIn("cons", {})
end

-- ---------------------------------------------------------------------------
-- Folding, and the search
--
-- Both belong to the page rather than to one of the three lists on it, so they
-- live here and every list asks the same two questions: is my block open, and
-- does this row match what was typed.
--
-- View state rather than settings: nobody configures which blocks are open or
-- what was last searched for, and storing either would put "elixirs are
-- closed" into every exported profile.
--
-- The search replaced a filter that showed the strongest usable entry per
-- category. That filter was removed on 2026-09-20 for being inconsistent, and
-- it was: it hid a row whose level you had not reached, which is a different
-- question from the one somebody scrolling the page is asking, and it left
-- nothing to grab hold of when you wanted a particular elixir by name.
-- ---------------------------------------------------------------------------

local closed = {}

-- [entry key] = true while an entry's details are open, since the redesign of
-- 2026-10-15. View state, like the folding.
local detailsOpen = {}

--- Does this text match what is in the search box?
--
-- Folded with FP:Fold on both sides, as on the Gameplay page: string.lower
-- left Cyrillic and Ñ as they were, so on a Russian client "эликсир" missed
-- every "Эликсир" until 1.0.1.
local function Matches(text)
    local filter = M.filter or ""
    if filter == "" then return true end
    return FP:Fold(text):find(filter, 1, true) ~= nil
end

--- The text a row is searched by, read when the search runs: an item's name
--- comes from the client and can arrive after the row was built.
local function SearchLabel(item)
    if item.name then return item.name() end
    return FP:T(item.label)
end

--- What the search box holds, folded, for the menu: the page's own rows
--- above the lists, the bars and the warning time, answer to it too. See
--- SearchPage in Menu.lua.
function M:PageSearch()
    return self.filter or ""
end

--- Which rows of one list a search leaves standing, as a set.
--
-- The Gameplay page's rules, since 1.0.1: a row stands when it matches, or
-- when the heading of its block does; a block heading while anything under it
-- stands; the captions over the hands' columns while a coating stands, since
-- nothing else says which column is which; and the section heading while
-- anything in its list stands. Until then every section heading, the two
-- hands and their captions stood through any search, over nothing.
local function SearchRows(entries)
    local headingHit, liveGroup = {}, {}
    for _, item in ipairs(entries) do
        if item.heading and Matches(SearchLabel(item)) then
            headingHit[item.id], liveGroup[item.id] = true, true
        end
    end
    for _, item in ipairs(entries) do
        if item.group and Matches(SearchLabel(item)) then
            liveGroup[item.group] = true
        end
    end

    local found, anyRow, anyCoating = {}, false, false
    for _, item in ipairs(entries) do
        local show = false
        if item.heading then
            show = liveGroup[item.id] == true
        elseif not (item.section or item.columns or item.detailOf) then
            show = Matches(SearchLabel(item))
                or (item.group ~= nil and headingHit[item.group] == true)
        end
        if show then
            found[item], anyRow = true, true
            if item.coating then anyCoating = true end
        end
    end
    for _, item in ipairs(entries) do
        if item.columns then
            found[item] = anyCoating
        elseif item.section then
            found[item] = anyRow
        end
    end
    return found
end

--- Places a list and sizes it to what is showing.
--
-- A running offset rather than a chain of anchors. **A chain cannot skip a
-- hidden row**: a hidden frame keeps its anchors and its place, so folding a
-- block away would leave exactly the gap it used to fill.
--
-- While a search is running the fold state is ignored: what you see is decided
-- by what you typed, and a matching row inside a shut block that stayed shut
-- would be a search that answers "nothing" while holding the answer.
-- The order is the table's own, and the table is written strongest first. It
-- used to be sorted here by the level the client reports, which was a proxy
-- for strength and wrong wherever the two part company: a scroll that asks for
-- a higher level than an elixir twice its size sat above it. How strong a
-- thing is cannot be read off this client at all, so it is authored, and
-- Data/Consumables.lua carries the number from each tooltip beside the entry
-- so the order can be checked.
local function PlaceRows(holder, entries)
    local searching = (M.filter or "") ~= ""
    local found = searching and SearchRows(entries) or nil

    local y = -2
    -- An entry's details follow its row: shown only when the row is and the
    -- details are open, whatever a search or a fold decided for the rest.
    local rowShown = false
    for _, item in ipairs(entries) do
        local show
        if item.detailOf then
            show = rowShown and detailsOpen[item.detailOf] == true
        elseif found then
            show = found[item] == true
        else
            show = not (item.group and closed[item.group])
        end
        if not item.detailOf then rowShown = show end

        if show then
            item.frame:ClearAllPoints()
            item.frame:SetPoint("TOPLEFT", holder, "TOPLEFT", item.indent, y)
            item.frame:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -2, y)
            item.frame:Show()
            y = y - item.height
        else
            item.frame:Hide()
        end
    end

    -- A list a search left empty takes no room, or four of them would leave
    -- a gap at the end of the page.
    local height = (y == -2) and 1 or math.max(-y + 8, 1)
    holder:SetHeight(height)
    -- Set by the menu on a custom option: the page lays itself out again when
    -- this block changes height. Asked for rather than assumed, because it is
    -- absent while the page is still being built.
    if holder.OnResized then holder.OnResized() end

    -- Folding a block by hand changes what the button should say. Guarded
    -- because the first layout happens while the strip above does not exist.
    if M.UpdatePageButton then M:UpdatePageButton() end
    return height
end

-- ---------------------------------------------------------------------------
-- The coating list
--
-- A block per kind, folded shut until somebody opens it, and inside it every
-- item in the game of that kind with a box for each hand. One box at a time in
-- a column, across all the blocks, because a weapon carries one coating.
--
-- The headings carry no box of their own. "Weapon oil" is not a thing you can
-- put on a weapon, it is where the oils are, and a box on it would have to
-- mean one of them without saying which.
--
-- Built by hand rather than out of toggles: a toggle knows how to be on and
-- off, and this needs a set of rows that know about each other.
-- ---------------------------------------------------------------------------

local ROW_H     = 22
local COL_W     = 84        -- how far apart the two columns of boxes sit
local COL_RIGHT = 12        -- the right column, from the right edge
local INDENT    = 14        -- a row under its heading

-- Every frame in display order, so folding and laying out are one pass.
--   { frame, height, indent, group = <kind>, }
local coatEntries = {}
local coatRows    = {}      -- the ones with something to refresh

--- Every row of the weapon block, back in step with what is stored.
--
-- Lost for an afternoon: it was cut out with the old layout function when the
-- three lists were given one, and nothing noticed because the two callers are
-- a click on a box and a refresh of the page. It compiled, it loaded, and it
-- raised the moment somebody touched it.
function RefreshCoatings()
    for _, frame in ipairs(coatRows) do
        if frame.Refresh then frame:Refresh() end
    end
end

--- One box, drawn like the ones the option rows use so it reads the same.
local function CreateCell(parent, get, set)
    local cell = CreateFrame("Button", nil, parent)
    cell:SetSize(19, 19)

    local hl = FP:Texture(cell, "HIGHLIGHT", FP.colors.hover)
    hl:SetAllPoints()

    local box = FP:Texture(cell, "ARTWORK", FP.colors.off, 13, 13)
    box:SetPoint("CENTER")

    function cell:Refresh()
        box:SetColorTexture(unpack(get() and FP.colors.on or FP.colors.off))
    end
    cell:SetScript("OnClick", function()
        set()
        RefreshCoatings()
    end)

    return cell
end

--- A caption per column, above the blocks rather than beside every row.
local function CreateColumnHeader(parent)
    local header = CreateFrame("Frame", nil, parent)
    header:SetHeight(ROW_H)

    local captions = {}
    for index, hand in ipairs(HANDS) do
        -- Centered on the column, which means centered on the boxes: the
        -- caption is the only thing that says which column is which, and a
        -- caption sitting beside its column is a caption for the other one.
        local text = FP:FontString(header, "OVERLAY", "body")
        text:SetPoint("CENTER", header, "RIGHT",
                      -(COL_RIGHT + (#HANDS - index) * COL_W) - 9.5, 0)
        text:SetText(FP:T(hand.label))
        captions[#captions + 1] = text
    end

    function header:Refresh()
        for _, text in ipairs(captions) do
            text:SetTextColor(unpack(FP.colors.textOff))
        end
    end
    header:Refresh()
    return header
end

local function CreateCoatingRow(parent, entry)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_H)

    local label = FP:FontString(row, "OVERLAY", "body")
    -- The row is indented, the label is not: this lands in the same column as
    -- every other label on the page.
    label:SetPoint("LEFT", FP.ROW_TEXT_X - INDENT, 0)

    local cells = {}
    for index, hand in ipairs(HANDS) do
        local cell = CreateCell(row,
            function() return ChosenOn(hand) == entry.item end,
            function() ChooseOn(hand, entry.item) end)
        cell:SetPoint("RIGHT", row, "RIGHT",
                      -(COL_RIGHT + (#HANDS - index) * COL_W), 0)
        AttachTooltip(cell, entry)
        cells[#cells + 1] = cell
    end
    -- A long item name stops short of the first column rather than under it.
    FP:FitLabel(label, row, cells[1])

    AttachTooltip(row, entry)

    function row:Refresh()
        label:SetText(CoatingName(entry))
        label:SetTextColor(unpack(FP.colors.textOn))
        for _, cell in ipairs(cells) do cell:Refresh() end
    end
    row:Refresh()

    return row
end

local function LayoutCoatings(holder)
    return PlaceRows(holder, coatEntries)
end

function BuildCoatings(holder, width)
    coatEntries, coatRows = {}, {}

    -- One fixed heading over the lot: it divides the page and never folds.
    local heading, headingHeight = FP:SectionHeading(holder, L["Weapon Coatings"])
    coatEntries[#coatEntries + 1] =
        { frame = heading, height = headingHeight, indent = 2, section = true }
    coatRows[#coatRows + 1] = heading

    -- Made here and placed below the hands: their details point at it while
    -- no coating is chosen, since the choice is made in its columns.
    local header = CreateColumnHeader(holder)

    -- What goes on each hand is one entry, with a bar and a time of its own,
    -- since the redesign of 2026-10-15: the owner kept the hands apart rather
    -- than making every coating an entry. A row per hand, named by the hand,
    -- opens them; which coating it is stays the matrix's choice below.
    --
    -- **While nothing is chosen for a hand, its row says so**, and its details
    -- are grayed out with the reason on hover, the owner's report the same day:
    -- grayed out alone, nobody could tell why.
    for _, hand in ipairs(HANDS) do
        local key = HandKey(hand)
        local handRow = CreateFrame("Button", nil, holder)
        handRow:SetHeight(ROW_H)
        local hl = FP:Texture(handRow, "HIGHLIGHT", FP.colors.hover)
        hl:SetAllPoints()
        local text = FP:FontString(handRow, "OVERLAY", "normal")
        text:SetPoint("LEFT", FP.ROW_TEXT_X - 2, 0)
        handRow.text = text
        function handRow:Refresh()
            local note = ""
            if ChosenOn(hand) == nil then
                note = "  |cff888888" .. L["(no coating chosen)"] .. "|r"
            end
            text:SetText(FP:T(hand.label) .. note)
            FP:ApplyLevel(self, "primary")
        end
        FP:MakeEntryRow(handRow, {
            key = key, factory = "consumables",
            isOpen = function() return detailsOpen[key] == true end,
            toggle = function() detailsOpen[key] = not detailsOpen[key] end,
            onToggled = function() LayoutCoatings(holder) end,
        })
        FP:Tooltip(handRow, function() return FP:T(hand.label) end,
            L["Sets the bar and warning time for this hand's coating. Choose "
            .. "the oil or stone in the list below."])
        -- Searched by the hand's name, like any other row since 1.0.1; until
        -- then both hands stood through every search.
        coatEntries[#coatEntries + 1] =
            { frame = handRow, height = ROW_H, indent = 2, label = hand.label }
        coatRows[#coatRows + 1] = handRow

        for _, detail in ipairs(FP:EntryDetails(holder, {
            key = key, factory = "consumables", timed = true,
            inherited = function() return M.db.warnSeconds end,
            blocked = function() return ChosenOn(hand) == nil end,
            blockedText = L["Not in use until you choose an oil or stone for "
                .. "this hand in the list below."],
            causes = function() return { header } end,
            changed = function()
                RefreshCoatings()
                FP:Safe("Consumables:Update", M.Update, M)
            end,
        })) do
            coatEntries[#coatEntries + 1] = {
                frame = detail, height = detail.rowHeight, indent = 14,
                detailOf = key,
            }
            coatRows[#coatRows + 1] = detail
        end
    end

    coatEntries[#coatEntries + 1] =
        { frame = header, height = ROW_H, indent = 2, columns = true }
    coatRows[#coatRows + 1] = header

    for _, group in ipairs(FP.weaponCoatings or {}) do
        -- A local of its own. The loop variable would be read by every closure
        -- below as whatever it holds at the end.
        local kind = group.id
        if closed[kind] == nil then closed[kind] = true end

        local head, headHeight = FP:CollapsibleHeading(holder, group.label, nil,
            function() return not closed[kind] end,
            function() closed[kind] = not closed[kind] end)
        head.OnToggled = function() LayoutCoatings(holder) end
        coatEntries[#coatEntries + 1] = {
            frame = head, height = headHeight, indent = 2,
            heading = true, id = kind, label = group.label,
        }
        coatRows[#coatRows + 1] = head

        for _, entry in ipairs(group.items) do
            -- So the client goes and looks the item up once, rather than the
            -- page showing our English name for ever.
            RequestItem(entry.item)

            local row = CreateCoatingRow(holder, entry)
            coatEntries[#coatEntries + 1] = {
                frame = row, height = ROW_H, indent = INDENT,
                group = kind, entry = entry, coating = true,
                name = function() return CoatingName(entry) end,
            }
            coatRows[#coatRows + 1] = row
        end
    end

    RefreshCoatings()
    -- Handed out so the filter can reach it. Without this the block would lay
    -- itself out only when a heading was clicked, which is exactly the fault
    -- the list below had an hour ago.
    M.LayoutCoatings = function() LayoutCoatings(holder) end
    return LayoutCoatings(holder)
end

-- ---------------------------------------------------------------------------
-- The list of everything you drink
--
-- Same shape as the coating list above and as the class picker on the Buffs
-- page: a fixed heading, then a block per category that folds, then a row per
-- entry. Three lists in the window that look and behave alike, which is the
-- whole reason the page rules in AGENTS.md exist.
--
-- One switch per row rather than two: an elixir is not tied to a hand, it is
-- simply watched or not. Two of them from different categories sit on you at
-- once, which is what a category is for: it says what displaces what, and the
-- filter uses it to show you the one worth carrying.
-- ---------------------------------------------------------------------------

local LIST_ROW_H = 22

local function CreateEntryRow(parent, entry)
    local row = FP:CreateToggle(parent, EntryName(entry),
        function() return Watched(entry) end,
        function(value)
            SetWatched(entry, value)
            -- Its details gray out with it.
            if M.RefreshPage then M:RefreshPage() end
        end)
    row:SetHeight(LIST_ROW_H)

    AttachTooltip(row, entry)

    -- On these rows the box is a texture inside the row, so the row's own
    -- hover already covers it. It becomes a button of its own the day somebody
    -- calls SplitClick on one, and that day it would be a hole in the middle
    -- of the row where the card goes away. Two lines now, none later.
    if row.boxHit then AttachTooltip(row.boxHit, entry) end

    local inherited = row.Refresh
    function row:Refresh()
        inherited(self)
        self.text:SetText(EntryName(entry))

        if entry.generic then
            -- The one row that stands on its own rather than qualifying a
            -- block above it, so it reads at the primary level. The color
            -- arrives with the role: see the page rules in AGENTS.md.
            FP:ApplyLevel(self, "primary")
            return
        end

        -- Dimmed while the client has said nothing about it, which is either
        -- an id this build does not have or one it has not looked up yet.
        self.text:SetTextColor(unpack(EntryKnown(entry)
            and FP.colors.textOn or FP.colors.textOff))
    end
    row:Refresh()

    return row
end

--- Builds the rows of one section of Data/Consumables.lua.
--
-- One list per section rather than one for the lot, because the page puts the
-- weapon coatings between them and a custom block is a single run of frames.
-- Each keeps its own two tables; the fold state is shared, since a block
-- belongs to exactly one section.
local function LayoutList(holder, entries)
    return PlaceRows(holder, entries)
end

local function BuildList(holder, wanted)
    local entries, rows = {}, {}

    local section
    for _, group in ipairs(FP.consumables or {}) do
        local kind = group.id
        if group.section == wanted then

        -- A fixed heading wherever the table says a new part of the page
        -- begins. Food is not an elixir, so it gets one of its own.
        if group.section ~= section then
            section = group.section
            local heading, headingHeight = FP:SectionHeading(holder, section)
            entries[#entries + 1] = {
                frame = heading, height = headingHeight, indent = 2, section = true,
            }
            rows[#rows + 1] = heading
        end

        -- A flat group has no block to open: its rows sit straight under the
        -- section heading. One row under a block of the same name would be
        -- that word twice with an arrow between them.
        if not group.flat then
            if closed[kind] == nil then closed[kind] = true end

            local head, headHeight = FP:CollapsibleHeading(holder, group.label, nil,
                function() return not closed[kind] end,
                function() closed[kind] = not closed[kind] end)
            head.OnToggled = function() LayoutList(holder, entries) end
            entries[#entries + 1] = {
                frame = head, height = headHeight, indent = 2,
                heading = true, id = kind, label = group.label,
            }
            rows[#rows + 1] = head
        end

        for _, entry in ipairs(group.items) do
            -- So the client goes and looks the item up once. Everything the
            -- row shows comes from that answer.
            if entry.item then RequestItem(entry.item) end

            -- Only a row inside a block is indented, and only a row inside
            -- a block folds away with it. Spelled out rather than written as
            -- a conditional expression: and/or cannot yield nil, and that
            -- exact line shipped a bug this morning.
            local block, indent = kind, 14
            if group.flat then block, indent = nil, 2 end

            local row = CreateEntryRow(holder, entry)
            entries[#entries + 1] = {
                frame = row, height = LIST_ROW_H,
                indent = indent, group = block, entry = entry,
                name = function() return EntryName(entry) end,
            }
            rows[#rows + 1] = row

            -- The rest of the row opens the entry's details since the
            -- redesign of 2026-10-15, and the box alone switches it.
            local key = EntryKey(entry)
            FP:MakeEntryRow(row, {
                key = key, factory = "consumables",
                isOpen = function() return detailsOpen[key] == true end,
                toggle = function() detailsOpen[key] = not detailsOpen[key] end,
                onToggled = function() LayoutList(holder, entries) end,
            })
            if row.boxHit then AttachTooltip(row.boxHit, entry) end
            local item = entry
            for _, detail in ipairs(FP:EntryDetails(holder, {
                key = key, factory = "consumables", timed = true,
                inherited = function() return M.db.warnSeconds end,
                blocked = function() return not Watched(item) end,
                causes = function() return { row } end,
                changed = function()
                    for _, frame in ipairs(rows) do
                        if frame.Refresh then frame:Refresh() end
                    end
                    FP:Safe("Consumables:Update", M.Update, M)
                end,
            })) do
                entries[#entries + 1] = {
                    frame = detail, height = detail.rowHeight,
                    indent = indent + 12, detailOf = key,
                }
                rows[#rows + 1] = detail
            end
        end

        end
    end

    local function refresh()
        for _, frame in ipairs(rows) do
            if frame.Refresh then frame:Refresh() end
        end
    end
    local function layout() return LayoutList(holder, entries) end

    refresh()
    return layout(), refresh, layout
end

-- Each list hands its own refresh and layout back here, so the option entry
-- and the events below can reach them without knowing how many there are.
local lists = {}

local function MakeList(name)
    return function(holder)
        local height, refresh, layout = BuildList(holder, name)
        lists[name] = { refresh = refresh, layout = layout }
        return height
    end
end

local function RefreshList(name)
    local list = lists[name]
    if list then list.refresh() end
end

--- Places every list again. Called when something outside them moved: the
--- filter, the player's level, or an item the client has just looked up.
function M:LayoutLists()
    for _, list in pairs(lists) do list.layout() end
    -- The weapon block is built by its own function rather than by the
    -- factory, and it answers to the same filter.
    if M.LayoutCoatings then M.LayoutCoatings() end
end

BuildFood          = MakeList("Food")
BuildConsumables   = MakeList("Consumables")
BuildOverlap       = MakeList(N["Replaced by a Class Buff"])
RefreshFood        = function() RefreshList("Food") end
RefreshConsumables = function() RefreshList("Consumables") end
RefreshOverlap     = function() RefreshList(N["Replaced by a Class Buff"]) end

-- ---------------------------------------------------------------------------
-- The strip above the page
--
-- The same two controls the Modules page has had since phase 1, and for the
-- same reason: a search and an open-everything button act on the whole page,
-- and a control that acts on the whole page is useless the moment it scrolls
-- out of sight. The menu draws this in the fixed strip, which costs the window
-- no height because the strip comes out of the scrolling area.
--
-- Declared here rather than in Menu.lua so that a page still describes itself
-- in one place, which is the rule that got BuffExpiry its generated tab.
-- ---------------------------------------------------------------------------

local HEADER_H = 32
local BUTTON_W = 98

--- Is any block on the page shut?
local function AnythingClosed()
    for _, group in ipairs(FP.weaponCoatings or {}) do
        if closed[group.id] then return true end
    end
    for _, group in ipairs(FP.consumables or {}) do
        if not group.flat and closed[group.id] then return true end
    end
    return false
end

--- Every list, redrawn and placed again.
function M:RefreshPage()
    FP:RefreshBarValues()
    if RefreshCoatings    then FP:Safe("Consumables:RefreshCoatings", RefreshCoatings) end
    if RefreshFood        then FP:Safe("Consumables:RefreshFood", RefreshFood) end
    if RefreshConsumables then FP:Safe("Consumables:RefreshList", RefreshConsumables) end
    if RefreshOverlap     then FP:Safe("Consumables:RefreshOverlap", RefreshOverlap) end
    self:LayoutLists()
    self:UpdatePageButton()
end

--- One button, three jobs, exactly as on the Modules page.
--
-- While a search is running, what you see is decided by what was typed and not
-- by which blocks are open, so opening them all would do nothing visible. The
-- button becomes the way back out instead.
function M:UpdatePageButton()
    if not self.expandButton then return end
    local label
    if (self.filter or "") ~= "" then
        label = L["Clear"]
    else
        label = AnythingClosed() and L["Expand all"] or L["Collapse all"]
    end
    self.expandButton.label:SetText(label)
end

function M:PageHeader(host)
    local pad = FP.PANEL_PAD
    local search   -- assigned below; the button has to be able to clear it

    local function ClearSearch()
        M.filter = ""
        if search and search.editBox then
            search.editBox:SetText("")
            search.editBox:ClearFocus()
        end
        M:RefreshPage()
    end

    local toggle = FP:CreateButton(host, L["Expand all"], BUTTON_W, function()
        if (M.filter or "") ~= "" then return ClearSearch() end

        local opening = AnythingClosed()
        for _, group in ipairs(FP.weaponCoatings or {}) do
            closed[group.id] = not opening
        end
        for _, group in ipairs(FP.consumables or {}) do
            if not group.flat then closed[group.id] = not opening end
        end
        M:RefreshPage()
    end)
    toggle:SetPoint("TOPRIGHT", -pad, -5)
    M.expandButton = toggle

    -- As wide as the longest of its three captions needs, at least the width
    -- it always had, as on the Gameplay page. The window is shown while this
    -- runs, so the widths are real.
    local buttonWidth = BUTTON_W
    for _, caption in ipairs({ L["Expand all"], L["Collapse all"], L["Clear"] }) do
        toggle.label:SetText(caption)
        buttonWidth = math.max(buttonWidth,
            math.ceil(toggle.label:GetStringWidth()) + 16)
    end
    toggle.label:SetText(L["Expand all"])
    toggle:SetWidth(buttonWidth)

    search = FP:CreateInput(host, nil, {
        -- The window's own width rather than the host's: an anchor that has
        -- not resolved yet reports zero, and zero here becomes a negative.
        -- A 400 stood here until 1.0.1, the window's width before it grew to
        -- 460, and the box started 60 units further right than the Gameplay
        -- page's.
        width = FP.WINDOW_W - 2 * pad - buttonWidth - 6,
        placeholder = L["Search"],
        Get = function() return M.filter or "" end,
        Set = function(value) M.filter = FP:Fold(value) end,
        -- Live, on every keystroke. Nothing here restarts a module, so the
        -- usual reason to wait for Enter does not apply.
        OnChange = function(value)
            M.filter = FP:Fold(value)
            M:RefreshPage()
        end,
    })
    search:SetPoint("TOPLEFT", pad, -4)
    search:SetPoint("TOPRIGHT", toggle, "TOPLEFT", -6, 1)

    M:UpdatePageButton()
    return HEADER_H
end
