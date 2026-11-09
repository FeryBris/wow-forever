-- What is on the weapon, and whether there is a weapon at all.
--
-- Two modules ask this now. BuffExpiry warns a Shaman about a missing imbue
-- and a Rogue about a missing poison; Consumables warns anybody about an oil
-- or a sharpening stone that is running out. On WoW Forever those are two
-- places on one weapon, and since 2026-09-26 each module reads its own: the
-- buff place for BuffExpiry, the coating place for Consumables. See
-- FP:SortByKinds for how a line is told to belong to one or the other, and
-- SortEnchantLines for where that cannot settle it.
--
-- Lifted out of BuffExpiry on 2026-09-20, unchanged. The measurements behind
-- it are in AGENTS.md under the weapon enchant pitfall. The short version: a
-- line's name and words come from the tooltip, the only place that has them.
local ADDON, FP = ...

FP.WeaponSlot = { main = 16, off = 17 }

local SLOT = FP.WeaponSlot
local WEAPON_CLASS_ID = 2   -- numeric: item type names are localized

-- A fishing pole is a weapon to the client, item class 2, and takes a lure in
-- the place an oil or a stone would go. It counts as no weapon since
-- 2026-10-15, the owner's word: nobody fishing wants to be told the pole
-- lacks an oil or an imbue, and a lure would be counted as a coating. The
-- client's own number where it has the enum, the same number otherwise.
local FISHING_POLE = (Enum and Enum.ItemWeaponSubclass
    and Enum.ItemWeaponSubclass.Fishingpole) or 20

--- Is there something in that slot that could take an enchant?
--
-- A shield in the off hand cannot, and warning a Shaman that their shield is
-- unimbued would be a warning they can do nothing about. Neither can an empty
-- off hand behind a two handed weapon, nor, by choice, a fishing pole.
function FP:HasWeapon(which)
    local slot = SLOT[which]
    if not (slot and GetInventoryItemLink) then return false end

    local ok, link = pcall(GetInventoryItemLink, "player", slot)
    if not ok or not link then return false end

    local instant = C_Item and C_Item.GetItemInfoInstant
    if not instant then return true end   -- cannot tell, so do not claim

    -- GetItemInfoInstant returns itemID, itemType, itemSubType, itemEquipLoc,
    -- icon, classID, subclassID. Counted one short the first time, which read
    -- the icon as the class and told a Shaman holding an axe that they had no
    -- weapon.
    local read, _, _, _, _, _, classID, subclassID = pcall(instant, link)
    if not read then return true end
    if classID ~= WEAPON_CLASS_ID then return false end
    return subclassID ~= FISHING_POLE
end

-- ---------------------------------------------------------------------------
-- Reading a weapon enchant on build 69913
--
-- **The call that exists for this does not work here.** Measured 2026-09-20 on
-- a Shaman with Rockbiter applied: GetWeaponEnchantInfo returns twelve values,
-- three slots of four, and every one of them is false or nil. Two other routes
-- were measured and are dead as well. The imbue is not an aura on the player,
-- so it cannot be read like any other buff. And the item link carries an
-- *empty* enchant field, `item:251932::::`, where a temporary enchant would
-- normally sit as a number.
--
-- The tooltip is the only place left, and the client draws it there plainly:
-- `Rockbiter 1 (51 min)`. That global went on to answer for a stone or an oil
-- on the beta and for an imbue since the launch, and neither of those made it
-- any use for this: see *Placing a line by what the client reports per kind*.
--
-- **Matching that without hardcoding English** is what the locale rule demands
-- and what makes this legitimate rather than a hack. The line has no type of
-- its own, it comes through as type 0, and color will not separate it from an
-- Equip or Use line. But the client publishes the very format it printed with,
-- ITEM_ENCHANT_TIME_LEFT_MIN and its three siblings, so the pattern is built
-- from the client's own string. This is ErrorFilter's technique, applied to a
-- tooltip instead of an error frame.
--
-- **On a German client the global reads "%1$s (%2$d Min.)"**, with numbered
-- placeholders, and until 2026-10-05 not one enchant line was read there. A
-- German Shaman reported it on CurseForge, with the output of
-- `/fplus buffs weapon` showing "Felsbeißer 2 (60 Min.)" on the weapon and
-- nothing in either place. FP:PatternFromFormat takes numbered placeholders
-- since, and says which capture is which value.
-- ---------------------------------------------------------------------------

-- How long one of those formats is worth, in seconds.
local ENCHANT_UNITS = {
    { global = "ITEM_ENCHANT_TIME_LEFT_SEC",   seconds = 1 },
    { global = "ITEM_ENCHANT_TIME_LEFT_MIN",   seconds = 60 },
    { global = "ITEM_ENCHANT_TIME_LEFT_HOURS", seconds = 3600 },
    { global = "ITEM_ENCHANT_TIME_LEFT_DAYS",  seconds = 86400 },
}

-- **Open at the end, since 2026-09-26.** A Rogue reported on CurseForge that
-- Instant Poison on the weapon was reported missing while Crippling Poison was
-- seen. The line was matched as a whole, from the name to the closing bracket
-- of the time, so anything the client prints after the time broke the match,
-- and a poison that carries charges is the obvious thing to print more about.
--
-- The Wowhead section for this game backs that up, read the same day: both
-- are still weapon coatings lasting thirty minutes, not auras, and **Instant
-- Poison carries 60 charges where Crippling Poison carries none**. That is the
-- one difference between the two, and nothing here compares spell ids, so a
-- reworked poison with a new id could not have caused it.
--
-- **Both were reworked all the same**, which the owner suspected and the
-- database confirms. The spells that coat the weapon, 8679 and 3408, no longer
-- use Classic's temporary weapon enchant but an effect type Wowhead cannot
-- name, #360, carrying the old enchant ids 323 and 22 and a value of 1801.
-- Instant Poison adds a second effect, a dummy of 61 for its 60 charges, run
-- by a server side script. Crippling Poison uses the same new effect and is
-- seen, so the effect still leaves a line with a time on the weapon. No new
-- spell ids exist for Instant Poison on this build.
--
-- **Measured the same afternoon**, from a screenshot the owner brought from
-- the Rogue Discord: the line reads "Instant Poison (19 min) (27 Charges)".
-- The charges follow the time, which is exactly what the open end allows, and
-- the same screenshot showed the second place on the weapon that the next
-- section is about. Deadly, Wound and Mind-numbing Poison carry charges the
-- same way according to the database, so they print the same shape.
local enchantPatterns   -- built once, on first use
local function EnchantPatterns()
    if enchantPatterns then return enchantPatterns end
    enchantPatterns = {}
    for _, unit in ipairs(ENCHANT_UNITS) do
        local pattern, order = FP:PatternFromFormat(_G[unit.global], true)
        if pattern then
            enchantPatterns[#enchantPatterns + 1] =
                { pattern = pattern, order = order, seconds = unit.seconds }
        end
    end
    return enchantPatterns
end

--- The name and the time out of one line, or nothing when it is not one.
--
-- The name is the first value of the format and the time the second,
-- whichever order the client prints them in.
local function ReadLine(text, form)
    local captures, values = { text:match(form.pattern) }, {}
    for index, value in ipairs(form.order) do values[value] = captures[index] end
    return values[1], tonumber(values[2])
end

--- Every temporary enchant on one slot, read off the item's own tooltip.
--
-- **Every one, not the first.** Until 2026-09-26 this returned the first line
-- that carried a time, on the assumption Classic makes: one temporary enchant
-- per weapon. WoW Forever keeps two. A screenshot from a Rogue's weapon showed
-- "Sharpened +2 (26 min)" above "Instant Poison (19 min) (27 Charges)", and
-- the database says why: poisons and Shaman imbues are cast with a new effect
-- type, #360, while stones and oils still use the old temporary enchant, so
-- each hand has a place for one of each. See SortEnchantLines for telling them
-- apart.
--
-- @return a list of { name, remaining }, in the order the tooltip shows them;
--         and whether the slot could be read at all, since an empty list is
--         also what a refusal leaves, and learning from one would be learning
--         from nothing. An empty slot is read: it holds no lines.
local function TooltipEnchantLines(slot)
    local found = {}
    local get = C_TooltipInfo and C_TooltipInfo.GetInventoryItem
    if not get then return found, false end

    local ok, data = pcall(get, "player", SLOT[slot])
    if not ok then return found, false end
    if type(data) ~= "table" then return found, true end

    local patterns = EnchantPatterns()
    if #patterns == 0 then return found, false end

    for _, line in ipairs(data.lines or {}) do
        local text = type(line) == "table" and line.leftText
        if type(text) == "string" and text ~= "" then
            -- Without color escapes. A line that arrives wrapped in one would
            -- fail at its first character, where the pattern expects the name.
            text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            for _, form in ipairs(patterns) do
                local name, amount = ReadLine(text, form)
                if name and amount then
                    -- The unit too: "30 Min." is only true to the minute,
                    -- which is how close a time read elsewhere can come.
                    found[#found + 1] = { name = name,
                                          remaining = amount * form.seconds,
                                          unit = form.seconds }
                    break
                end
            end
        end
    end
    return found, true
end

-- ---------------------------------------------------------------------------
-- Which place a line belongs to
--
-- **Two places per hand on WoW Forever, found on 2026-09-26.** The buff place
-- takes what a class casts on its weapon: a Rogue's poison, a Shaman's imbue.
-- The coating place takes what anybody can put on: a sharpening stone, a
-- weightstone, an oil. Both can be on one weapon at once, so a warning about
-- one must never be answered by a line that belongs to the other.
--
-- **What the client reports per kind comes first**, since 2026-11-06, see
-- *Placing a line by what the client reports per kind* below. What follows is
-- for a hand the report does not settle.
--
-- **A line the player's own cast put there is known exactly**, since
-- 2026-10-05: see *Learning a line from the cast* below. Everything else is
-- told apart by name, the way the imbue rank already is in BuffExpiry.
--
-- **By name**: how strongly a line points at a name the client gives for the
-- class's own weapon buffs, against the same for the stones and oils.
-- "Instant Poison" against the spell "Instant Poison", "Rockbiter 1" against
-- "Rockbiter Weapon". Nothing is compared to a literal, and on a German client
-- both sides of every comparison are German. A line has to point at a buff by
-- at least three characters and more than at any coating to count as the
-- buff; everything else is a coating. Three is what keeps "Frost Oil" from
-- reading as Frostbrand once the oil's own name is known.
--
-- **The start they share, or the line's whole name inside the spell's**, see
-- FP:EnchantEvidence. The start alone failed on a German client, reported on
-- 2026-10-05: the line reads "Felsbeißer 2" and the spell "Waffe des
-- Felsbeißers", and they share nothing at the start. The same player found
-- that matching only the start of the line anywhere in the spell would turn
-- Korean sharpening stones into imbues, since every Korean imbue's name holds
-- the word for weapon and the stone's line, "무기 연마 +2", begins with it.
-- The whole name, without its rank, does not fit inside an imbue's.
--
-- **Where no name matches at all**, which the same player found for some
-- imbues on the Spanish, Russian and Chinese clients, whose spells and
-- enchants use different words, the line is a coating until the first cast
-- teaches otherwise. That makes the missing imbue warning wrong once, and the
-- recast it asks for is exactly what puts it right for good.
--
-- The one weakness, stated so nobody has to find it: an oil whose item name
-- the client has not loaded yet has no name to count against, so a Rogue
-- wearing Minor Wizard Oil could, for that moment, see it taken for
-- Mind-numbing Poison. It corrects itself as soon as the name arrives.
-- ---------------------------------------------------------------------------

local MIN_SHARED = 3

--- How strongly an enchant line points at a spell, in bytes.
--
-- The start the two share, or, when it is longer, the line's whole name
-- without its trailing rank standing anywhere inside the spell's: "Felsbeißer"
-- in "Waffe des Felsbeißers". By byte and without folding case, like
-- SharedPrefix, so nothing here depends on how a language writes its letters.
function FP:EnchantEvidence(line, spell)
    if type(line) ~= "string" or type(spell) ~= "string" then return 0 end
    local shared = self:SharedPrefix(line, spell)
    local stem = line:gsub("%s*%d+%s*$", "")
    if #stem > shared and #stem >= MIN_SHARED and spell:find(stem, 1, true) then
        return #stem
    end
    return shared
end

local function Score(name, candidates, measure)
    local best = 0
    for _, candidate in ipairs(candidates) do
        local run = measure(FP, name, candidate)
        if run > best then best = run end
    end
    return best
end

--- Sorts the lines of one hand into its two places.
--
-- Pure, so the harness can run it: the names come in as arguments.
--
-- @param lines         { { name, remaining }, ... }, as the tooltip listed them
-- @param buffNames     what the client calls this class's weapon buffs
-- @param coatingNames  what the client calls the stones and oils
-- @param learned       line name -> the spell whose cast put it there; may be nil
-- @return the buff line and the coating line; either may be nil
function FP:SortEnchantLines(lines, buffNames, coatingNames, learned)
    local buff, coating
    for _, line in ipairs(lines or {}) do
        local asBuff, asCoating
        if learned and learned[line.name] then
            asBuff, asCoating = math.huge, 0
        else
            asBuff    = Score(line.name, buffNames or {}, FP.EnchantEvidence)
            asCoating = Score(line.name, coatingNames or {}, FP.SharedPrefix)
        end
        if asBuff >= MIN_SHARED and asBuff > asCoating then
            buff = buff or line
        else
            coating = coating or line
        end
    end
    return buff, coating
end

-- ---------------------------------------------------------------------------
-- Learning a line from the cast
--
-- Asked for in the same CurseForge report, as an idea rather than as code:
-- remember which imbue the player has just cast instead of trusting names. The
-- cast is the one thing about a weapon buff this client reports plainly, in a
-- fight or not, as a spell id. So when a Shaman's imbue or a Rogue's poison is
-- cast, BuffExpiry has both hands read before it goes out and again after it
-- landed, and the one line that appeared or was renewed is the one that spell
-- put there. Its name is kept for the account, keyed by the text the client
-- printed, and decides its place from then on, in any language.
--
-- Nothing is learned from a guess: two lines changing at once, or none, teach
-- nothing, since whatever is learned is kept for good.
-- ---------------------------------------------------------------------------

-- How far a line's time has to go up to count as renewed. The tooltip gives
-- minutes, so a recast reads at least a minute longer than before.
local RENEWED = 30

--- The lines of the weapon buffs learned so far, line name -> spell id, or
--- nil while nothing has been. Made only by the first thing learned, so the
--- saved file of a player who never casts one stays as it was.
local function Learned(create)
    if type(FP.global) ~= "table" then return nil end
    if create and type(FP.global.enchantLines) ~= "table" then
        FP.global.enchantLines = {}
    end
    local learned = FP.global.enchantLines
    return type(learned) == "table" and learned or nil
end

--- The spell whose cast put a line with this name on a weapon, or nil.
function FP:LearnedEnchant(name)
    local learned = Learned()
    return learned and type(name) == "string" and learned[name] or nil
end

function FP:LearnEnchantLine(name, spellId)
    if not (type(name) == "string" and name ~= "" and spellId) then return end
    local learned = Learned(true)
    if learned then learned[name] = spellId end
end

--- Both hands' lines as the tooltip shows them now, for comparing, or nil
--- when either hand could not be read.
function FP:WeaponLines()
    local main, mainRead = TooltipEnchantLines("main")
    local off, offRead   = TooltipEnchantLines("off")
    if not (mainRead and offRead) then return nil end
    return { main = main, off = off }
end

--- The one line that differs between two readings of both hands, or nil.
--
-- A line that was not there before, or whose time went up, is what happened
-- in between. Pure, so the harness can run it.
function FP:CastLine(before, after)
    local found
    for _, hand in ipairs({ "main", "off" }) do
        local old = {}
        for _, line in ipairs((before or {})[hand] or {}) do
            old[line.name] = line.remaining
        end
        for _, line in ipairs((after or {})[hand] or {}) do
            local was = old[line.name]
            if not was or line.remaining > was + RENEWED then
                if found then return nil end
                found = line
            end
        end
    end
    return found
end

-- The client's names for this class's weapon buffs. Built once: spell names
-- are always there, whether or not the character knows the spell. A class
-- without weapon buffs gets an empty list, and every line is a coating.
local buffNames

local function BuffNames()
    if buffNames then return buffNames end
    local ok, _, token = pcall(UnitClass, "player")
    token = ok and FP:Plain(token)
    if not token then return {} end

    local names, seen = {}, {}
    for _, entry in ipairs((FP.classBuffs or {})[token] or {}) do
        if entry.kind == "weapon" then
            for _, id in ipairs(entry.names or entry.requires or {}) do
                local name = FP:SpellName(id)
                if name and not seen[name] then
                    seen[name] = true
                    names[#names + 1] = name
                end
            end
        end
    end
    buffNames = names
    return names
end

-- The client's names for the stones and oils. Item names arrive when the
-- client has looked them up, so the list is kept only once it is complete.
local coatingNames

local function ItemName(id)
    local get = (C_Item and C_Item.GetItemNameByID) or _G.GetItemInfo
    if not get then return nil end
    local ok, name = pcall(get, id)
    return ok and FP:Plain(name) or nil
end

local function CoatingNames()
    if coatingNames then return coatingNames end
    local names, complete = {}, true
    for _, group in ipairs(FP.weaponCoatings or {}) do
        for _, entry in ipairs(group.items or {}) do
            local name = entry.item and ItemName(entry.item)
            if name then names[#names + 1] = name else complete = false end
        end
    end
    if complete then coatingNames = names end
    return names
end

-- ---------------------------------------------------------------------------
-- Placing a line by what the client reports per kind
--
-- **C_Item.GetWeaponEnchantInfo says what is on a hand, kind by kind**, read on
-- 2026-11-06 in the client's own buff frame for build 70790, which draws its
-- weapon icons from it: a list per hand, each entry with hasEnchant,
-- enchantType, timeLeft in milliseconds, charges and enchantID. The kinds are
-- Enum.ItemEnchantType, Temporary for a stone or an oil and Imbue for what is
-- cast with the new effect #360: a poison, a Shaman's imbue, a Warlock's stone.
-- So the place of a line needs no name and no cast, in any language: the line
-- with an imbue's time is the buff, the line with a temporary enchant's time
-- the coating. **Measured the same day** on a new Shaman with "Rockbiter 1
-- (60 min)" alone on a mace: two entries per hand, the first hasEnchant=false
-- with enchantType=0, the second hasEnchant=true, enchantType=3, enchantID=29,
-- timeLeft=3595501, and both entries of the empty off hand like that first one.
-- A stone, an oil, a poison and a Warlock's stone have not been seen in it, but
-- the Wowhead section for this game, read the same day, gives all 49 ranks of
-- imbues, poisons and Warlock's stones the effect #360 Rockbiter has, and all 22
-- stones and oils "Enchant Item - Temporary".
--
-- **It replaced the global GetWeaponEnchantInfo, which can no longer tell.**
-- From 0.8.7 on, the line with the time that call reported was taken for the
-- coating and any other for the buff, which held on the beta, measured on
-- 2026-10-05 and 2026-10-06 with an oil and a Firestone on one sword. Build
-- 70755, the day before the launch, added one sentence to the documentation of
-- C_PaperDollInfo.GetTemporaryEnchantmentInfo, which the global is built on:
-- "Imbue enchants take priority over temporary enchants." A weapon carrying an
-- imbue now answers with the imbue's time, measured on that mace as true,
-- 3595501, 0, 29, so that line went to the coating place and the buff place
-- stayed empty: Rockbiter reported as missing while it was on the weapon, on
-- CurseForge right after the launch, and by the same route every poison and
-- Warlock's stone.
--
-- **A line its cast taught beats the report**, see *Learning a line from the
-- cast*: the report has been seen for one imbue, and the cast for many. Should
-- the client call a poison or a Warlock's stone a temporary enchant, the warning
-- asks for a recast, and the recast settles it for good.
--
-- **Names and learned casts stay behind it**, for a hand the report does not
-- settle, and for a client where the call is gone or refused.
-- ---------------------------------------------------------------------------

-- The client's own numbers where it has the enums, the same numbers otherwise.
local KIND_TEMPORARY = (Enum and Enum.ItemEnchantType
    and Enum.ItemEnchantType.Temporary) or 2
local KIND_IMBUE = (Enum and Enum.ItemEnchantType
    and Enum.ItemEnchantType.Imbue) or 3
local REPORT_SLOT = {
    main = (Enum and Enum.WeaponSlot and Enum.WeaponSlot.MainHand) or 0,
    off  = (Enum and Enum.WeaponSlot and Enum.WeaponSlot.OffHand) or 1,
}

-- Seconds the two readings may differ by beyond the unit of the line, for the
-- moment between asking the call and reading the tooltip.
local TIME_SLACK = 5

--- What the client reports on one hand, by kind.
--
-- @return { buff = seconds or false, coating = seconds or false }, or nil when
--         the call is missing or refused or an answer in it cannot be read
local function ReportedKinds(hand)
    local read = C_Item and C_Item.GetWeaponEnchantInfo
    if type(read) ~= "function" then return nil end

    local ok, kinds = pcall(function()
        local found = { buff = false, coating = false }
        for _, enchant in pairs(read(REPORT_SLOT[hand])) do
            local has = FP:Truth(enchant.hasEnchant)
            if has == nil then return nil end
            if has then
                local kind = FP:PlainNumber(enchant.enchantType)
                local left = FP:PlainNumber(enchant.timeLeft)
                if not (kind and left) then return nil end
                if kind == KIND_IMBUE then
                    found.buff = left / 1000
                elseif kind == KIND_TEMPORARY then
                    found.coating = left / 1000
                end
            end
        end
        return found
    end)
    return ok and kinds or nil
end

--- Can this line be the enchant with that much time left? Any line can, where
--- the client reports none of that kind.
local function Fits(line, seconds)
    if not seconds then return true end
    return math.abs(line.remaining - seconds) <= (line.unit or 60) + TIME_SLACK
end

--- Sorts one hand's lines by what the client reports per kind.
--
-- Pure, so the harness can run it.
--
-- @param lines        { { name, remaining, unit }, ... }, as the tooltip listed them
-- @param buffTime     seconds the imbue has left, or false for none
-- @param coatingTime  seconds the stone or oil has left, or false for none
-- @return the buff line and the coating line, either of which may be nil, and
--         whether the report settled it. Not settled: lines while nothing is
--         reported, more lines than a hand has places, or times that fit both
--         ways round or neither.
function FP:SortByKinds(lines, buffTime, coatingTime)
    lines = lines or {}
    local first, second = lines[1], lines[2]
    if not first then return nil, nil, true end
    if #lines > 2 or not (buffTime or coatingTime) then return nil, nil, false end

    if not second then
        -- One line and one kind: that is the line, whatever time it printed.
        if not coatingTime then return first, nil, true end
        if not buffTime then return nil, first, true end
        local asBuff, asCoating = Fits(first, buffTime), Fits(first, coatingTime)
        if asBuff == asCoating then return nil, nil, false end
        if asBuff then return first, nil, true end
        return nil, first, true
    end

    local straight = Fits(first, buffTime) and Fits(second, coatingTime)
    local crossed  = Fits(first, coatingTime) and Fits(second, buffTime)
    if straight == crossed then return nil, nil, false end
    if straight then return first, second, true end
    return second, first, true
end

local NONE = { has = false, remaining = 0 }

local function Side(line, learned)
    if not line then return NONE end
    return { has = true, remaining = line.remaining, name = line.name,
             learned = learned and learned[line.name] or nil }
end

--- Both places on both weapons, as seconds remaining.
--
-- @return { main = hand, off = hand }, where a hand is
--         { buff = side, coating = side, lines = the lines it was read from }
--         and a side is { has, remaining, name, learned }, `learned` being
--         the spell whose cast taught the line's place, when one did
--
-- The tooltip for the names and the times a player sees, the client's report
-- for which is which, see *Placing a line by what the client reports*; names
-- and learned casts only where the report does not settle it. `placedBy` on a
-- hand says which it was. **A place the client reports counts even when no line
-- filled it**, unnamed, so that a tooltip worded in a way nobody has read yet
-- costs the rank check and never reports a buff as missing.
function FP:WeaponEnchants()
    local result = {}
    local buffs, coatings, learned = BuffNames(), CoatingNames(), Learned()
    for _, hand in ipairs({ "main", "off" }) do
        local lines = TooltipEnchantLines(hand)
        local kinds = ReportedKinds(hand)
        local buff, coating, settled
        if kinds then
            buff, coating, settled = self:SortByKinds(lines, kinds.buff, kinds.coating)
        end

        local placedBy = "kind"
        if not settled then
            buff, coating = self:SortEnchantLines(lines, buffs, coatings, learned)
            placedBy = "name"
        elseif coating and learned and learned[coating.name] then
            -- The report took that line for a coating, so on this hand it is
            -- wrong, and what it says about the place just emptied with it.
            buff, coating = coating, buff
            placedBy = "name"
            kinds = nil
        end

        local place = { buff = Side(buff, learned), coating = Side(coating),
                        lines = lines, placedBy = #lines > 0 and placedBy or nil }
        if kinds and kinds.buff and not place.buff.has then
            place.buff = { has = true, remaining = kinds.buff }
        end
        if kinds and kinds.coating and not place.coating.has then
            place.coating = { has = true, remaining = kinds.coating }
        end
        result[hand] = place
    end
    return result
end
