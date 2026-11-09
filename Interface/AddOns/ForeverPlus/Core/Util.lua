-- Small helpers every module needs: output, error containment, combat deferral.

local ADDON, FP = ...
local L = FP.L

local PREFIX = "|cff00b4ffForeverPlus|r: "

local function format(fmt, ...)
    if select("#", ...) > 0 then
        local ok, out = pcall(string.format, fmt, ...)
        return ok and out or fmt
    end
    return fmt
end

-- Both translate their format, see Core/Locale.lua: a message marked with L
-- while a file loaded is still English until it is printed.
function FP:Print(fmt, ...)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. format(FP:T(fmt), ...))
end

function FP:Warn(fmt, ...)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. "|cffff5555" .. format(FP:T(fmt), ...) .. "|r")
end

--- Calls fn inside a pcall. One broken module must never take the rest down --
--  especially on a client whose API we have not fully measured.
-- @return true on success, false otherwise
function FP:Safe(what, fn, ...)
    if fn == nil then
        -- This used to return true silently. A missing function is a failure,
        -- not a success -- that is exactly how Discover() went missing once.
        self:Warn(L["%s: function is missing"], tostring(what))
        return false
    end
    if type(fn) ~= "function" then
        self:Warn(L["%s: expected a function, got %s"], tostring(what), type(fn))
        return false
    end

    local ok, err = pcall(fn, ...)
    if not ok then
        self:Warn(L["Error in %s: %s"], what, tostring(err))
    end
    return ok
end

-- Protected frames (action bars, unit frames) cannot be touched in combat.
-- Trying anyway earns a lockdown error.
local pending = {}
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
watcher:SetScript("OnEvent", function()
    if #pending == 0 then return end
    -- Swap first, then work through it: an entry may safely queue more work
    -- while it runs.
    local queue = pending
    pending = {}
    for i = 1, #queue do
        FP:Safe(queue[i].what, queue[i].fn)
    end
end)

--- Runs fn now -- or, if we are in combat, right after it ends.
function FP:OutOfCombat(what, fn)
    if InCombatLockdown() then
        pending[#pending + 1] = { what = what, fn = fn }
    else
        self:Safe(what, fn)
    end
end

--- Does this global exist? Without touching it.
function FP:Has(name)
    return _G[name] ~= nil
end

-- Coin icons, assembled from the texture escape sequence:
--   |T<path>:<height>:<width>:<xOffset>:<yOffset>|t
local COIN = {
    gold   = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t",
    silver = "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t",
    copper = "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t",
}

--- Formats an amount of copper as text with coin icons.
--
-- GetCoinTextureString does not exist on build 1.60.1 -- measured, not assumed
-- -- so this is a chain: the modern namespace first, the old global second,
-- and the icons assembled by hand last. The hand-built form only needs the
-- coin textures, which have shipped since Vanilla.
function FP:Money(copper)
    copper = math.floor(tonumber(copper) or 0)

    local builtin = (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString)
                 or _G.GetCoinTextureString
    if builtin then
        local ok, text = pcall(builtin, copper)
        if ok and type(text) == "string" and text ~= "" then return text end
    end

    local gold   = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local rest   = copper % 100

    -- Skip the denominations that are zero: 77 copper reads better on its own
    -- than behind two zeroes.
    local parts = {}
    if gold   > 0 then parts[#parts + 1] = gold   .. COIN.gold end
    if silver > 0 then parts[#parts + 1] = silver .. COIN.silver end
    if rest   > 0 or #parts == 0 then parts[#parts + 1] = rest .. COIN.copper end
    return table.concat(parts, " ")
end

--- The client's own display name for a spell id, or nil if it knows no such
--- spell.
--
-- The id is ours, the name is the client's. That split is the locale rule in
-- one function: our tables carry numbers, which are the same everywhere, and
-- anything a player reads comes back from the game in the game's language.
--
-- Both shapes are handled. The modern call returns a table, the old global
-- returned a list of values, and this build has already moved several
-- functions between the two.
function FP:SpellName(id)
    if not id then return nil end

    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, id)
        if ok then
            if type(info) == "table"  then return info.name end
            if type(info) == "string" then return info end
        end
    end

    if _G.GetSpellInfo then
        local ok, name = pcall(_G.GetSpellInfo, id)
        if ok and type(name) == "string" and name ~= "" then return name end
    end

    return nil
end

--- The client's own icon for a spell id, or nil.
--
-- Needed for a buff that is *missing*: there is no aura to take an icon from,
-- so it comes from the spell instead.
function FP:SpellIcon(id)
    if not id then return nil end

    if C_Spell and C_Spell.GetSpellTexture then
        local ok, texture = pcall(C_Spell.GetSpellTexture, id)
        if ok and texture then return texture end
    end

    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, id)
        if ok and type(info) == "table" and info.iconID then return info.iconID end
    end

    if _G.GetSpellTexture then
        local ok, texture = pcall(_G.GetSpellTexture, id)
        if ok and texture then return texture end
    end

    return nil
end

--- Has this character learned that spell?
--
-- All three readers below exist on build 69913, measured 2026-09-19, and all
-- three are asked rather than only the first: see the note in the body.
--
-- "Known" rather than "high enough level" on purpose: reaching the level is
-- not the same as having been to the trainer, and telling somebody about a
-- rank they cannot cast is noise.
function FP:KnowsSpell(id)
    if not id then return false end

    -- Built with table.insert rather than as a literal: a nil in the middle of
    -- a list ends ipairs there, so a missing first reader would silently hide
    -- the two behind it.
    local readers = {}
    for _, reader in ipairs({
        _G.IsPlayerSpell,
        _G.IsSpellKnown,
        C_SpellBook and C_SpellBook.IsSpellKnown,
    }) do
        if type(reader) == "function" then readers[#readers + 1] = reader end
    end

    -- **Any yes wins.** The first version returned whatever the first reader
    -- said, which meant one of them answering false for everything would hide
    -- the other two completely. They disagree about ranks and about talents,
    -- and being told a spell is not trained when it is turns the whole warning
    -- off for that buff without a word.
    for _, reader in ipairs(readers) do
        local ok, answer = pcall(reader, id)
        if ok then
            -- Never a bare `if answer then`: see FP:Truth below for why a
            -- value that came back from this client cannot be touched
            -- directly.
            if self:Truth(answer) == true then return true end
        end
    end

    return false
end

--- Registers every event a handler table names, one at a time.
--
-- `RegisterEvent` **raises** on an event this build does not know, and a raise
-- inside OnEnable takes the rest of the module's setup down with it. This build
-- is newer than the model's knowledge in places and older in others, so an
-- event name is a guess until it has been tried on this client.
--
-- Each one is therefore tried on its own, and the refused ones are named rather
-- than swallowed. A module quietly missing an event is exactly the kind of
-- failure that gets blamed on the feature instead of on the registration.
--
-- @return how many registered, and the sorted list of those that did not
function FP:RegisterEvents(frame, handlers, what)
    local missing, count = {}, 0
    for event in pairs(handlers) do
        if pcall(frame.RegisterEvent, frame, event) then
            count = count + 1
        else
            missing[#missing + 1] = event
        end
    end
    if #missing > 0 then
        table.sort(missing)
        -- What stands first is a module's internal name, English like every
        -- one of them; "module" only stands in for a caller that gave none.
        self:Warn(L["%s: this client does not recognize %s. Those features "
               .. "remain unavailable."],
            what or "module", table.concat(missing, ", "))  -- l10n: english
    end
    return count, missing
end

--- Turns one of the client's own format strings into a Lua pattern.
--
-- **The locale rule in one function.** The rule forbids comparing against game
-- text the addon hardcoded, and the way through has always been to take the
-- client's own string and work from that: ErrorFilter builds its filters from
-- ERR_OUT_OF_MANA rather than from the English words. This does the same for
-- anything shaped like a format, so the technique stops being something each
-- module reinvents.
--
-- Written for the weapon enchant line, where the client prints
-- "Rockbiter 1 (51 min)" from ITEM_ENCHANT_TIME_LEFT_MIN, "%s (%d min)".
--
--   "%s (%d min)"  ->  "^(.+) %%((%%d+) min%%)$"
--
-- **Numbered placeholders as well, since 2026-10-05.** A player on a German
-- client reported on CurseForge that no enchant line was ever read there: the
-- German client writes that global as "%1$s (%2$d Min.)", each placeholder
-- carrying the number of the value it stands for. They come out the same way
-- as the plain ones, and since a language may print the values in another
-- order than they are passed, the second thing returned says which value each
-- capture is.
--
-- The order of the steps is not arbitrary. The placeholders come out first,
-- because %s and %d contain the very character the escaping is about, and
-- putting them back last means an escaped format cannot eat them.
--
-- @param openEnd  lets the line carry more after the part that matched. The
--                 weapon enchant needs it, see Core/Weapon.lua; everything
--                 else wants the whole line to be the format.
-- @return a pattern with one capture per placeholder, or nil; and for each
--         capture the number of the value it stands for, { 1, 2 } for
--         "%s (%d min)" and { 2, 1 } for "%2$d: %1$s"
function FP:PatternFromFormat(format, openEnd)
    if type(format) ~= "string" or format == "" then return nil end

    local order = {}
    local work = format:gsub("%%(%d*)%$?([sd])", function(number, kind)
        order[#order + 1] = tonumber(number) or (#order + 1)
        return kind == "s" and "\1" or "\2"
    end)
    -- |4singular:plural; is resolved by the client as it draws, so the pattern
    -- has to accept whichever of the two words came out: "1 hour", "2 hours".
    -- Any run of characters up to a space or a bracket rather than letters,
    -- since %a knows only the English alphabet here and "часов" is a word too.
    work = work:gsub("|4[^;]*;", "\3")
    work = work:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    work = work:gsub("\1", "(.+)"):gsub("\2", "(%%d+)"):gsub("\3", "[^%%s%%)]+")
    return "^" .. work .. (openEnd and "" or "$"), order
end

--- A boolean that came from the client, made safe to look at.
--
-- The client can hand back a value that is *secret*: it survives the read, it
-- survives `tostring`, and it raises on the first comparison. So the only way
-- to find out whether one can be used is to try one operation inside a pcall.
--
-- `1` counts as true, because half of this client's older calls answer that
-- way and none of them means it as a number. `IsResting` and `IsMounted` are
-- the ones that prompted it: comparing them strictly against `true` returned
-- false for ever and switched off a setting without a word.
--
-- @return true, false, or nil when the value cannot be looked at at all
function FP:Truth(value)
    local ok, yes = pcall(function() return value == true or value == 1 end)
    if ok then return yes end
    return nil
end

--- How many leading characters two strings share.
--
-- By byte, and without folding case. string.upper and string.lower are byte
-- based in WoW's Lua and mangle anything outside ASCII, which is most of the
-- names this will ever see on a non English client. Moved here from BuffExpiry
-- on 2026-09-26, when the weapon reading needed it as well.
function FP:SharedPrefix(a, b)
    if type(a) ~= "string" or type(b) ~= "string" then return 0 end
    local limit = math.min(#a, #b)
    for i = 1, limit do
        if a:byte(i) ~= b:byte(i) then return i - 1 end
    end
    return limit
end

--- How long the longest run of characters two strings have in common is.
--
-- By byte and without folding case, for the reason given above. Where
-- SharedPrefix asks whether one name begins like another, this finds one name
-- inside another wherever it stands: "Poor Copper Vein", a vein WoW Forever
-- added, holds "Copper " from "Copper Ore", and a language that puts the metal
-- last shares the end instead, "Filon de cuivre" and "Minerai de cuivre".
-- Added on 2026-10-04 for the gathering line in the tooltip.
function FP:SharedRun(a, b)
    if type(a) ~= "string" or type(b) ~= "string" then return 0 end
    local best, previous = 0, {}
    for i = 1, #a do
        local current, byte = {}, a:byte(i)
        for j = 1, #b do
            if byte == b:byte(j) then
                local run = (previous[j - 1] or 0) + 1
                current[j] = run
                if run > best then best = run end
            end
        end
        previous = current
    end
    return best
end

--- Which of several names is the one another name is made from, or nil.
--
-- The candidate whose name shares the most with `name` **as a share of its
-- own length**, at least four bytes and more than half of it. The share is
-- what decides, and both limits were found by trying every vein against
-- every ore on 2026-10-04: "Iron Deposit" holds "Iron " from "Iron Ore" and
-- from "Dark Iron Ore" alike, five bytes each, and only the share tells the
-- two apart; and "Rich Thorium Vein" holds "rium " from "Indurium Ore", five
-- of its twelve bytes, which the limit of 0.55 refuses.
-- @param candidates  a table of name -> value
-- @return the value of the closest, and its name
function FP:ClosestName(name, candidates)
    if type(name) ~= "string" or type(candidates) ~= "table" then return nil end
    local best, bestName, bestShare, bestLength = nil, nil, 0, 0
    for candidate, value in pairs(candidates) do
        if type(candidate) == "string" and #candidate > 0 then
            local length = self:SharedRun(name, candidate)
            local share = length / #candidate
            if length >= 4 and share >= 0.55
               and (share > bestShare or (share == bestShare and length > bestLength)) then
                best, bestName, bestShare, bestLength = value, candidate, share, length
            end
        end
    end
    return best, bestName
end

--- Can every item in the list be given by a different giver?
--
-- A small bipartite matching: each giver can give one item, and `givers[g]`
-- answers whether giver g can give a particular one. Augmenting paths rather
-- than a greedy pass, because the answer has to be right when two givers can
-- each give different things, and the lists here are never longer than a
-- handful on either side.
local function Assignable(items, givers)
    local owner = {}   -- [giver index] = item index

    local function Try(index, visited)
        for g = 1, #givers do
            if not visited[g] and givers[g](items[index]) then
                visited[g] = true
                if not owner[g] or Try(owner[g], visited) then
                    owner[g] = index
                    return true
                end
            end
        end
        return false
    end

    for index = 1, #items do
        if not Try(index, {}) then return false end
    end
    return true
end

--- Which wanted things are worth asking for, when each giver gives one.
--
-- Written for Paladin blessings and reported from a group on 2026-09-27: a
-- Warlock at 15 beside Paladins at 15 and 16 was asked for Kings and
-- Salvation, which neither of them could cast yet, and asked for both twice.
-- The two faults are separate and both are answered here: a giver is asked
-- only for what that giver can give, and no giver is asked twice.
--
-- **What is already there took somebody's turn.** Held items are charged to
-- the givers first, and only then is anything new asked for. A held item no
-- giver present could have given came from somebody who is not here, so it
-- takes nobody's turn, which is why the charge is a matching rather than a
-- subtraction.
--
-- @param wanted  ids, most wanted first
-- @param held    [id] = true for what is already there
-- @param givers  a list with one function per giver, function(id) -> bool
-- @return the ids to ask for, in the order they are wanted
function FP:PlanGifts(wanted, held, givers)
    local claimed, ask = {}, {}

    local function Claim(id)
        claimed[#claimed + 1] = id
        if Assignable(claimed, givers) then return true end
        claimed[#claimed] = nil
        return false
    end

    for _, id in ipairs(wanted) do
        if held[id] then Claim(id) end
    end
    for _, id in ipairs(wanted) do
        if not held[id] and Claim(id) then ask[#ask + 1] = id end
    end
    return ask
end

-- ---------------------------------------------------------------------------
-- Camp bonuses
--
-- Here rather than in BuffExpiry so the harness can run them: string work and
-- a decision, nothing that asks the client. See FP.campBonuses in
-- Data/Buffs.lua for what a camp gives and why it is read this way.
-- ---------------------------------------------------------------------------

--- Which bonuses the description of Camp Benefits lists.
--
-- It reads "Gained the following camp benefits:", then a line per object,
-- "Fish Bowl: All stats increased by 8%.", with \r\n between, measured by the
-- owner's probe on 2026-10-15. A line is matched by the longest object name it
-- contains, so whatever a language puts around the name does not matter. The
-- first line is the heading unless it names an object.
--
-- **A later line that names no object makes the whole answer unknown**, nil:
-- a bonus is never called missing on a description that could not be read
-- through, which is the quiet direction. A name the client has not fetched
-- yet ends the same way, and the next look tries again.
--
-- @param text   the description, as the client wrote it
-- @param names  a list of { name = <an object's name>, bonus = <its bonus id> }
-- @return [bonus id] = true, or nil; and the lines nothing matched
function FP:CampListed(text, names)
    if type(text) ~= "string" then return nil, {} end
    local listed, unmatched, first = {}, {}, true
    for raw in (text:gsub("\r", "") .. "\n"):gmatch("(.-)\n") do
        local line = raw:match("^%s*(.-)%s*$")
        if line ~= "" then
            local best, length = nil, 0
            for _, known in ipairs(names or {}) do
                local name = known.name
                if type(name) == "string" and #name > length
                   and line:find(name, 1, true) then
                    best, length = known.bonus, #name
                end
            end
            if best then
                listed[best] = true
            elseif not first then
                unmatched[#unmatched + 1] = line
            end
            first = false
        end
    end
    if #unmatched > 0 then return nil, unmatched end
    return listed, unmatched
end

--- Whether a mana gain is the share of the maximum a shield gives back for a
--- spent charge.
--
-- Water Shield's 408511 gives 3 percent of the maximum mana, out of the
-- Wowhead Forever database, and the server works it out in whole points, so
-- the gain lies within one point of the exact share whichever way it rounds.
-- A gain of nothing never counts: full mana may report one, and so may every
-- other source of mana.
--
-- @param amount   the gain UNIT_COMBAT reported
-- @param maxMana  the player's maximum mana
-- @param percent  the share the shield gives back, 3 for Water Shield
function FP:IsShieldMana(amount, maxMana, percent)
    if type(amount) ~= "number" or type(maxMana) ~= "number"
       or type(percent) ~= "number" then
        return false
    end
    if amount <= 0 or maxMana <= 0 then return false end
    return math.abs(amount - maxMana * percent / 100) < 1
end

--- Whether a UNIT_COMBAT event could be a critical spell of the player's own,
--- which spends a Water Shield charge on WoW Forever.
--
-- A critical heal on anybody, the player included: heals carry school 1 here
-- whatever cast them, measured on a priest's own holy heals, so the school
-- says nothing and is not asked. And a critical hit on anybody but the
-- player in a school other than physical, which leaves out a melee crit:
-- hits carry their real school, measured in the shield probe's fights, 238
-- physical against 8 nature and 7 fire. A crit on the player is somebody's
-- hit on the shield, which spends its charge as a hit.
--
-- Whose crit it was is never in the event, which is why a crit alone spends
-- nothing: see NoteMana in BuffExpiry.
function FP:IsSpellCritSign(unit, action, flag, school)
    if flag ~= "CRITICAL" then return false end
    if action == "HEAL" then return true end
    return action == "WOUND" and unit ~= "player"
        and type(school) == "number" and school ~= 1
end

--- The pairing of a crit with the mana a shield gives back, as a small machine
--- the harness can run. BuffExpiry feeds it the player's casts, the crits that
--- may have been the player's spells and the gains of the shield's share, and
--- each answer is the time a charge went, or nil.
--
-- A crit counts only within `castBefore` seconds after a cast of the player's
-- own. A crit and a gain pair when they come within `near` seconds of each
-- other, either way round, and each pairs once: a gain that finds no crit
-- waits for one, and is the time the charge went when it comes.
function FP:NewCritGate(near, castBefore)
    local gate = { near = near or 0.5, castBefore = castBefore or 3 }

    function gate:Cast(t)
        self.castAt = t
    end

    function gate:Crit(t)
        if not (self.castAt and t - self.castAt <= self.castBefore) then return nil end
        local waiting = self.manaAt
        if waiting and t - waiting <= self.near then
            self.manaAt = nil
            return waiting
        end
        self.critAt = t
        return nil
    end

    function gate:Mana(t)
        if self.critAt and t - self.critAt <= self.near then
            self.critAt = nil
            return t
        end
        self.manaAt = t
        return nil
    end

    return gate
end

--- What the bonuses a player ticked come to.
--
-- A bonus is fine while a class buff that replaces it is on, or while Camp
-- Benefits is on and lists it; a list that could not be read counts as
-- listing everything, see CampListed. A bonus with an aura of its own,
-- `ownAura`, is fine while that aura is on, whatever Camp Benefits says.
-- Everything else is missing.
--
-- @param picks    the ticked bonuses, tables with an `id`, in their order
-- @param active   whether Camp Benefits is on
-- @param listed   [bonus id] = true, or nil while the list is unknown
-- @param covered  [bonus id] = true where a class buff stands in for it
-- @param own      [bonus id] = true where a bonus's own aura is on
-- @return the missing bonuses, in the order given; and whether any of the
--         others rests on the camp, so that its running out matters
function FP:PlanCamp(picks, active, listed, covered, own)
    local missing, fromCamp = {}, false
    covered, own = covered or {}, own or {}
    for _, bonus in ipairs(picks or {}) do
        if covered[bonus.id] then
            -- A class buff that replaces it is on: nothing to say.
        elseif bonus.ownAura then
            -- Never on Camp Benefits, so its running out does not touch it.
            if not own[bonus.id] then missing[#missing + 1] = bonus end
        elseif active and (listed == nil or listed[bonus.id]) then
            fromCamp = true
        else
            missing[#missing + 1] = bonus
        end
    end
    return missing, fromCamp
end

--- A string that came from the client, or nil when it cannot be handled.
--
-- The same rule as `Truth`, for text: one comparison inside a pcall before
-- anything else touches the value. An empty string counts as no answer, which
-- is what every caller wants from a name or an id.
function FP:Plain(value)
    local ok, usable = pcall(function()
        return type(value) == "string" and value ~= ""
    end)
    return (ok and usable) and value or nil
end

--- A number that came from the client, or nil when it cannot be handled.
--
-- The same rule once more: arithmetic inside a pcall, because a secret number
-- is handed over intact and raises only when something is done with it.
function FP:PlainNumber(value)
    local ok, number = pcall(function()
        return type(value) == "number" and value + 0 or nil
    end)
    return ok and number or nil
end

-- ---------------------------------------------------------------------------
-- Bag slots
--
-- Read here rather than in BagSlots since 2026-10-09, when the info bar began
-- counting the same bags: it has to go on counting while BagSlots is off, the
-- owner's word being that the backpack and the bar are switched apart.
-- ---------------------------------------------------------------------------

--- Every bag the character carries, with its free and total slots.
--
-- **The family is the second answer of GetContainerNumFreeSlots**, 0 for an
-- ordinary bag, which is the test Blizzard's own free slot count made while it
-- was still written in Lua: a quiver, an ammo pouch, a soul bag or a herb bag
-- holds one kind of thing, so a free slot in it is no room for loot. Bag 0 is
-- the backpack and always ordinary. `NUM_BAG_SLOTS` is read rather than
-- assumed: this build is not the one any of these numbers were written for.
-- The reagent bag sits where the client's own index puts it, or in the slot
-- after the last ordinary bag, which is where its code counts it.
--
-- @return a list of { bag, free, total, family, reagent } in the client's own
--         order, the reagent bag last; nil when the client offers no counts
function FP:ReadBags()
    local container = rawget(_G, "C_Container")
    local numSlots  = type(container) == "table" and container.GetContainerNumSlots
    local numFree   = type(container) == "table" and container.GetContainerNumFreeSlots
    if not (numSlots and numFree) then return nil end

    local function Read(bag, reagent)
        local okSlots, slots = pcall(numSlots, bag)
        local okFree, spare, family = pcall(numFree, bag)
        slots = okSlots and self:PlainNumber(slots)
        spare = okFree and self:PlainNumber(spare)
        if not (slots and spare and slots > 0) then return nil end
        family = (bag ~= 0) and self:PlainNumber(family) or 0
        return { bag = bag, free = spare, total = slots, family = family,
                 reagent = reagent or nil }
    end

    local bags, last = {}, rawget(_G, "NUM_BAG_SLOTS") or 4
    for bag = 0, last do bags[#bags + 1] = Read(bag) end

    local enum = rawget(_G, "Enum")
    local reagent = type(enum) == "table" and type(enum.BagIndex) == "table"
        and enum.BagIndex.ReagentBag or (last + 1)
    bags[#bags + 1] = Read(reagent, true)
    return bags
end

--- The bags grouped by what they hold: the ordinary ones together, each
--- family of special bag together, wherever it is worn.
--
-- **A bag counts by its family, also in the reagent bag's slot.** The
-- owner's soul bag came out as a reagent bag on 2026-10-09, which only that
-- slot can give, so on WoW Forever a special bag sits there too. Only a bag of
-- family 0 in that slot is a kind of its own, "reagent".
--
-- In the order the first bag of each kind comes in, so the ordinary bags,
-- whose first is the backpack, lead.
--
-- @param bags  what FP:ReadBags returned
-- @return a list of { kind, free, total, bags = { bag, ... } }, where kind is
--         "ordinary", "reagent" or the family's number
function FP:BagKinds(bags)
    local kinds, byKind = {}, {}
    for _, bag in ipairs(bags or {}) do
        local kind = (bag.family ~= 0 and bag.family)
            or (bag.reagent and "reagent") or "ordinary"
        local entry = byKind[kind]
        if not entry then
            entry = { kind = kind, free = 0, total = 0, bags = {} }
            byKind[kind] = entry
            kinds[#kinds + 1] = entry
        end
        entry.free  = entry.free + bag.free
        entry.total = entry.total + bag.total
        entry.bags[#entry.bags + 1] = bag.bag
    end
    return kinds
end

--- The gray stack whose loss costs the least at a merchant, or nil.
--
-- D1 of the 1.0.2 brief, the owner's answers of 2026-10-21: **the whole
-- stack of the lowest total vendor value**, the price of one times the stack,
-- so a bag slot is freed for the least gold rather than the cheapest single
-- item. A known value of nothing counts; an unknown price, a quest item and a
-- locked slot are left out. Of two stacks worth the same, the smaller, and
-- then the one met first.
--
-- @param stacks  a list of { bag, slot, itemID, count, quality, price,
--                quest, locked }, price per item or nil when unknown
-- @return that stack, with `total` added, or nil
function FP:CheapestGray(stacks)
    local best
    for _, s in ipairs(stacks or {}) do
        local count = tonumber(s.count) or 1
        if s.quality == 0 and type(s.price) == "number" and s.price >= 0
           and not s.quest and not s.locked and count > 0 then
            local total = s.price * count
            if not best or total < best.total
               or (total == best.total and count < best.count) then
                best = { bag = s.bag, slot = s.slot, itemID = s.itemID,
                         count = count, price = s.price, total = total,
                         link = s.link }
            end
        end
    end
    return best
end

-- ---------------------------------------------------------------------------
-- Worn durability
--
-- Read here rather than in InfoBar since 2026-11-05, when the durability
-- warning began reading the same pieces: it has to warn with the bar switched
-- off.
-- ---------------------------------------------------------------------------

--- Every worn piece that can wear down, and whether every slot answered.
--
-- An empty slot and a piece that does not wear down both answer nil. **A slot
-- that refused, or whose answer cannot be handled, is a gap instead**: it says
-- nothing about that piece, and FP:DurabilityVerdict must not read it as fine.
--
-- @return a list of { slot, current, maximum, share }, and true when complete
function FP:ReadWornPieces()
    local pieces, complete = {}, true
    if type(GetInventoryItemDurability) ~= "function" then return pieces, false end
    for slot = 1, 18 do
        local ok, current, maximum = pcall(GetInventoryItemDurability, slot)
        local readable, absent = pcall(function() return current == nil end)
        if not (ok and readable) then
            complete = false
        elseif not absent then
            current, maximum = self:PlainNumber(current), self:PlainNumber(maximum)
            if not (current and maximum) then
                complete = false
            elseif maximum > 0 then
                pieces[#pieces + 1] = { slot = slot, current = current,
                    maximum = maximum, share = current / maximum }
            end
        end
    end
    return pieces, complete
end

--- What a reading says against a threshold in percent.
--
-- The lowest piece decides, not an average. **Compared in whole numbers rather
-- than as a share or a rounded figure**: 14 of 70 is exactly 20 percent, and a
-- piece at 20.4 percent, which the info bar prints as 20, is above 20.
--
-- @return "low" and the lowest piece; "fine" when every piece was read and is
--         above the threshold; nil when nothing can be said, which is neither
function FP:DurabilityVerdict(pieces, complete, threshold)
    local lowest
    for _, piece in ipairs(pieces) do
        if not lowest or piece.share < lowest.share then lowest = piece end
    end
    if not lowest then return nil end
    if lowest.current * 100 <= (tonumber(threshold) or 0) * lowest.maximum then
        return "low", lowest
    end
    return complete and "fine" or nil
end

--- A piece's condition as whole percent, rounded like the info bar's figure.
--
-- Never 0 while any durability is left: 0 reads as broken, and it is not yet.
function FP:DurabilityPercent(piece)
    local percent = math.floor(piece.share * 100 + 0.5)
    if percent == 0 and piece.current > 0 then return 1 end
    return percent
end

-- The equipment slot as the character window names it, from the client's own
-- strings: "Head" here, "Kopf" on a German client. Asked for by the owner as
-- the orientation for the damaged list, with the official names.
local SLOT_NAMES = {
    [1] = "HEADSLOT", [2] = "NECKSLOT", [3] = "SHOULDERSLOT", [4] = "SHIRTSLOT",
    [5] = "CHESTSLOT", [6] = "WAISTSLOT", [7] = "LEGSSLOT", [8] = "FEETSLOT",
    [9] = "WRISTSLOT", [10] = "HANDSSLOT", [11] = "FINGER0SLOT",
    [12] = "FINGER1SLOT", [13] = "TRINKET0SLOT", [14] = "TRINKET1SLOT",
    [15] = "BACKSLOT", [16] = "MAINHANDSLOT", [17] = "SECONDARYHANDSLOT",
    [18] = "RANGEDSLOT",
}

function FP:SlotName(slot)
    local global = SLOT_NAMES[slot]
    return global and self:Plain(_G[global]) or nil
end

-- ---------------------------------------------------------------------------
-- Buying up to an amount
--
-- For the reagents and poisons beside a merchant, gated with the owner on
-- 2026-10-09. Here rather than in the module so the harness can hold them.
-- ---------------------------------------------------------------------------

--- How many to buy to reach a target, in whole merchant stacks.
--
-- Rounded up rather than down: the player asked for at least the target, and
-- the client's own window sells nothing between two stacks.
-- @return the amount, 0 when the bags already hold enough
function FP:TopUp(target, have, sold)
    local missing = (tonumber(target) or 0) - (tonumber(have) or 0)
    if missing <= 0 then return 0 end
    sold = math.max(1, tonumber(sold) or 1)
    return math.ceil(missing / sold) * sold
end

--- The ingredients for the poisons still missing up to a target.
--
-- **Ingredients in the bags are left out of it**, the owner's rule of
-- 2026-10-09 once he had tried the first version, which counted them and held
-- the shared ones back for the other poisons: a click buys what the poisons
-- still missing take, and nothing else decides it. Only finished poisons
-- count against the target. A recipe makes one poison.
--
-- @param takes  [itemID] = how many one poison takes
-- @return [itemID] = how many to buy, and how many poisons that makes
function FP:PoisonIngredients(target, have, takes)
    local makes = math.max(0, (tonumber(target) or 0) - (tonumber(have) or 0))
    local buy = {}
    if makes == 0 then return buy, 0 end
    for item, count in pairs(takes) do buy[item] = makes * count end
    return buy, makes
end

-- ---------------------------------------------------------------------------
-- Whose gold the info bar counts
-- ---------------------------------------------------------------------------

--- Whether a character's gold counts under the info bar's choice.
--
-- Here rather than in InfoBar so the harness can hold it. "all" counts every
-- character, "self" the one being played, "faction" those gold can be mailed
-- between: on the same realm, of the same ruleset and of the same faction.
-- "ruleset" counts both factions of the ruleset, the owner's wish of
-- 2026-10-13, for following the other faction's characters too. A faction or
-- a ruleset not known yet counts wherever the realm matches, the way the mail
-- list treats it.
--
-- **The ruleset** is WoW Forever's word for Normal, PvP and later Hardcore,
-- and the client refuses mail between two of them, in its own words
-- ERR_MAIL_CANT_SEND_SUPERDISTRICT. It is the number that
-- C_GameRules.GetCurrentGameModeRecordID
-- answers, measured by the owner on 2026-10-13 on the beta: 15 for Normal on
-- "Classic Beta PvE 2", realm 4620, and 14 for PvP on "Classic Beta PvP 2",
-- realm 4613. The realm parts them there as well; the number is kept for the
-- one realm WoW Forever launches with, where it may be all that does.
--
-- @param record  { key, realm, faction, mode } of a stored character, mode
--                being the ruleset's number
-- @param scope   "all", "ruleset", "faction" or "self"
-- @param me      the same four for the character being played
function FP:GoldCounts(record, scope, me)
    if record.key ~= nil and record.key == me.key then return true end
    if scope == "self" then return false end
    if scope == "faction" or scope == "ruleset" then
        if record.realm == nil or record.realm ~= me.realm then return false end
        if record.mode ~= nil and me.mode ~= nil and record.mode ~= me.mode then
            return false
        end
        if scope == "ruleset" then return true end
        return record.faction == nil or me.faction == nil
            or record.faction == me.faction
    end
    return true
end

--- The number of the ruleset this character plays, or nil while the client
--- will not say. See FP:GoldCounts.
function FP:Ruleset()
    local rules = rawget(_G, "C_GameRules")
    local get = type(rules) == "table" and rules.GetCurrentGameModeRecordID
    if type(get) ~= "function" then return nil end
    local ok, value = pcall(get)
    return ok and self:PlainNumber(value) or nil
end

-- ---------------------------------------------------------------------------
-- The client's own sounds
--
-- One short list for every setting that picks a sound: the chat's since phase
-- 6.5, and the ammunition warning's since the owner asked on 2026-09-28 for its
-- sound to be chosen and tried like those. By their names in the client's
-- SOUNDKIT table. The name is what is stored, not the number, so a sound a
-- later build renames is noticed as missing instead of playing something else.
-- Only the ones this client actually has are offered, and nothing is bundled,
-- so the provenance question never arises.
-- ---------------------------------------------------------------------------

FP.SOUNDS = {
    { "TELL_MESSAGE",          L["Whisper"] },
    { "RAID_WARNING",          L["Raid warning"] },
    { "READY_CHECK",           L["Ready check"] },
    { "IG_PLAYER_INVITE",      L["Group invite"] },
    { "UI_BNET_TOAST",         L["Friend online"] },
    { "ALARM_CLOCK_WARNING_2", L["Alarm clock"] },
    { "ALARM_CLOCK_WARNING_3", L["Alarm clock, short"] },
    { "MAP_PING",              L["Map ping"] },
    { "AUCTION_WINDOW_OPEN",   L["Auction house"] },
    { "LOOT_WINDOW_COIN_SOUND",L["Coins"] },
    { "LEVEL_UP",              L["Level up"] },
}

--- The client's number for a sound, by its SOUNDKIT name, or nil when this
--- client has no such sound.
function FP:SoundKitId(name)
    local kit = rawget(_G, "SOUNDKIT")
    local id = type(kit) == "table" and name ~= nil and kit[name]
    return type(id) == "number" and id or nil
end

--- The sounds this client has, as values for a drop-down.
function FP:SoundChoices()
    local out = {}
    for _, pair in ipairs(self.SOUNDS) do
        if self:SoundKitId(pair[1]) then out[#out + 1] = { pair[1], pair[2] } end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Which quests the two quest modules may take or hand in
--
-- CF8 on CurseForge, settled with the owner on 2026-10-18, see
-- planning/1.0.0/PLANNING-CURSEFORGE-REQUESTS-2026-10-17.md. A player lost the
-- items of a repeatable quest in a loop: accepted, handed in, offered again,
-- accepted again, for as long as the items lasted, and the owner had seen the
-- same at the bloodgem quests in the Barrens. So **each quest is accepted
-- automatically at most once and handed in automatically at most once per
-- conversation with a quest giver**, and one handed in is not accepted again
-- in that conversation; other quests and chains go on as before, and the
-- player may always act by hand.
--
-- **A conversation ends when every window of it has been closed for longer
-- than a moment**, or when another NPC speaks. The client closes and opens
-- the windows itself between the steps of a quest, gossip to detail and back,
-- within a fraction of a second, so that is still the same conversation;
-- talking to the NPC again on purpose takes longer than the gap. Not
-- measured in game when this was written: /fplus quests prints what the
-- guard saw, for a look at a repeatable quest.
-- ---------------------------------------------------------------------------

FP.QUEST_GAP = 2   -- seconds every window must stay closed to end a conversation

--- A fresh guard. Pure, for the harness: `now` and `npc` are handed in.
function FP:NewQuestGuard(gap)
    local guard = { gap = gap or FP.QUEST_GAP, open = false, closedAt = nil,
                    npc = nil, started = nil, accepted = {}, turnedIn = {},
                    held = {} }

    --- A window of a conversation opened. Returns true when it starts a new one.
    function guard:Touch(now, npc)
        local fresh = self.started == nil
            or (npc ~= nil and self.npc ~= nil and npc ~= self.npc)
            or (not self.open and self.closedAt ~= nil and now - self.closedAt > self.gap)
        if fresh then
            self.accepted, self.turnedIn, self.held = {}, {}, {}
            self.started = now
        end
        if npc ~= nil then self.npc = npc end
        self.open = true
        return fresh
    end

    --- Every window of it closed, for now.
    function guard:Closed(now)
        self.open = false
        self.closedAt = now
    end

    --- A quest the client gives no id for is not held back by the guard.
    function guard:MayAccept(id)
        return id == nil or not (self.accepted[id] or self.turnedIn[id])
    end
    function guard:MayTurnIn(id)
        return id == nil or not (self.turnedIn[id] or self.held[id])
    end
    function guard:Accepted(id) if id ~= nil then self.accepted[id] = true end end
    function guard:TurnedIn(id) if id ~= nil then self.turnedIn[id] = true end end
    --- Left to the player for this conversation: a choice of rewards, say.
    function guard:Hold(id) if id ~= nil then self.held[id] = true end end

    return guard
end

--- Whether a quest is one to accept automatically, by its color for the
--- character: "all", "noGray" or "noGreen".
--
-- @param difficulty  the client's own judgement, Enum.RelativeContentDifficulty:
--                    0 trivial and gray, 1 easy and green, 2 and up fair or
--                    harder; nil when it gave none
-- @param trivial     the client's flag for a gray quest, where it gave one
function FP:QuestWanted(level, difficulty, trivial)
    if level ~= "noGray" and level ~= "noGreen" then return true end
    if difficulty == nil and trivial == true then difficulty = 0 end
    if difficulty == nil then
        -- Not told: a quest the client did not call gray is taken, as before
        -- the filter; whether it is green cannot be told, so it is not.
        return level == "noGray"
    end
    return difficulty >= (level == "noGreen" and 2 or 1)
end

--- The one guard both quest modules share, and what it noted, for
--- /fplus quests. Its frame hears every window of a conversation close.
function FP:QuestGuard()
    local guard = self.questGuard
    if guard then return guard end
    guard = self:NewQuestGuard()
    guard.log = {}
    function guard:Note(text)
        local log = self.log
        log[#log + 1] = string.format("%.1f %s", GetTime and GetTime() or 0, text)
        if #log > 40 then table.remove(log, 1) end
    end
    self.questGuard = guard
    if CreateFrame then
        local frame = CreateFrame("Frame")
        for _, event in ipairs({ "GOSSIP_CLOSED", "QUEST_FINISHED" }) do
            pcall(frame.RegisterEvent, frame, event)
        end
        frame:SetScript("OnEvent", function(_, event)
            guard:Closed(GetTime())
            guard:Note(event)
        end)
        guard.frame = frame
    end
    return guard
end

--- The NPC being talked to, as its guid, or nil.
function FP:QuestNpc()
    if not UnitGUID then return nil end
    local ok, guid = pcall(UnitGUID, "npc")
    return ok and self:Plain(guid) or nil
end

--- The quest of the open quest window, or nil.
function FP:OpenQuestID()
    if not GetQuestID then return nil end
    local ok, id = pcall(GetQuestID)
    id = ok and self:PlainNumber(id) or nil
    return (id and id > 0) and id or nil
end

--- How hard a quest is for the character, Enum.RelativeContentDifficulty, or nil.
function FP:QuestDifficulty(id)
    local get = C_PlayerInfo and C_PlayerInfo.GetContentDifficultyQuestForPlayer
    if not (get and id) then return nil end
    local ok, value = pcall(get, id)
    return ok and self:PlainNumber(value) or nil
end

-- ---------------------------------------------------------------------------
-- Experience over a stretch of play
--
-- What the info bar's two experience displays read, D01 of the after launch
-- plan, gated with the owner on 2026-11-06. A measurement is a plain table, so
-- it can lie in the saved file, where a /reload finds it again. See *Experience*
-- in Modules/InfoBar.lua for who starts one and when.
-- ---------------------------------------------------------------------------

-- A rate is never worked out over less than this. The figures stand from the
-- first moment, the owner's answer, and a first kill three seconds after a
-- login would otherwise read as a hundred thousand an hour. Over a span this
-- long the rate simply climbs while the first minute runs.
local XP_SHORTEST_SPAN = 60

--- A new measurement, from what the client answers right now.
function FP:NewXPSession(now, xp, maximum)
    return { started = now, gained = 0, xp = xp, maximum = maximum }
end

--- Counts what has come in since the measurement last looked.
--
-- **Experience going down is a new level**, the only way it does here: what the
-- old level still lacked and what stands now have both been earned. The old
-- level's maximum is the one that says what it lacked, and the client may
-- answer with the new maximum before the amount falls, so the maximum is only
-- taken along when the amount changed. A level up used to throw the whole
-- measurement away, exactly when the figures were worth looking at.
--
-- Called as often as anybody likes: the same answer twice adds nothing.
function FP:NoteXP(session, xp, maximum)
    if type(session) ~= "table" or not xp then return end
    local last = session.xp
    if not last then
        session.xp, session.maximum = xp, maximum
        return
    end
    if xp == last then return end

    local gained = tonumber(session.gained) or 0
    if xp > last then
        gained = gained + (xp - last)
    else
        gained = gained + math.max((session.maximum or last) - last, 0) + xp
    end
    session.gained = gained
    session.xp, session.maximum = xp, maximum or session.maximum
end

--- Experience per hour of a measurement, or nil without one.
function FP:XPPerHour(session, now)
    if type(session) ~= "table" or not session.started or not now then return nil end
    local span = math.max(now - session.started, XP_SHORTEST_SPAN)
    return (tonumber(session.gained) or 0) / span * 3600
end

--- Seconds until the next level at a rate, or nil while the rate says nothing.
function FP:SecondsToLevel(rate, xp, maximum)
    if not (rate and xp and maximum) or rate <= 0 or maximum <= xp then return nil end
    return (maximum - xp) / rate * 3600
end

--- Which side of its owner a frame of this height hangs on: under it, unless the
--- screen runs out there and there is more room above. Where neither side has
--- the room, the larger one, and the frame's clamp does the rest.
function FP:SideThatFits(height, below, above)
    if height <= below or below >= above then return "BOTTOM" end
    return "TOP"
end

-- ---------------------------------------------------------------------------
-- The addons' CPU usage
--
-- For the hover of the info bar's frame rate, F12 of the after launch plan. In
-- percent since 2026-11-06, the owner's word before the release: a time per tick
-- says little to a player. The client's own addon list and performance bar show
-- this figure and call it CPU, so the arithmetic is theirs, GetOverallMetric and
-- GetAddonMetricPercent of AddonListMixin in the interface code for build 70790,
-- and the windows agree. It is a share of the time the whole game takes, which
-- is as near to the processor as an addon can see.
-- ---------------------------------------------------------------------------

--- All addons together as a share of the whole game, in percent. Nil while the
--- client gives nothing to measure against.
function FP:ShareOfAllAddOns(overall, application)
    if not overall or not application or application <= 0 then return nil end
    return overall / application * 100
end

--- One addon's share in percent, against the game and that addon alone, the
--- other addons left out, as the client counts it. So the lines under a total
--- need not add up to it.
function FP:ShareOfAddOn(value, overall, application)
    if not value or not overall or not application then return nil end
    local total = application - overall + value
    if total <= 0 then return nil end
    return value / total * 100
end

--- A share as the client writes one, with as many decimals as a small figure
--- needs to say anything, and below that 0%. The comma comes from FP:Decimal.
function FP:ShareText(percent)
    if percent >= 1 then return string.format("%.0f%%", percent) end
    if percent >= 0.1 then return self:Decimal(percent, 1) .. "%" end
    if percent >= 0.01 then return self:Decimal(percent, 2) .. "%" end
    return "0%"
end

--- The busiest addons out of what C_AddOnProfiler.GetTopKAddOnsForMetric answers,
--- as { name, value } with the highest time first.
--
-- Sorted here rather than trusted, since the client's documentation promises
-- no order, and by name where two tie, so a list that is redrawn every second
-- does not swap two lines back and forth. An addon that took no time at all
-- earns no line: it is not busy, and a line of zeros would only fill the list.
function FP:BusiestAddOns(results, limit)
    local out = {}
    if type(results) ~= "table" then return out end
    for _, result in ipairs(results) do
        local name  = type(result) == "table" and self:Plain(result.addOnName)
        local value = type(result) == "table" and self:PlainNumber(result.metricValue)
        if name and value and value > 0 then
            out[#out + 1] = { name = name, value = value }
        end
    end
    table.sort(out, function(a, b)
        if a.value ~= b.value then return a.value > b.value end
        return a.name < b.name
    end)
    while limit and #out > limit do out[#out] = nil end
    return out
end
