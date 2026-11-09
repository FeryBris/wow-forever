-- Extra lines in the game tooltip, and where the tooltip sits.
--
-- Phase 5.1. Asked for on CurseForge on 2026-09-20 by a player naming Leatrix
-- Plus as the model: a guild rank, and who somebody currently has targeted.
--
-- **Only the lines that depend on no measurement are here.** Target of target
-- is unit identity, which C_Secrets covers, and it waits for the probe rather
-- than being promised. So does everything about what this tooltip does during a
-- fight: what can be cached and what falls away is decided by what the client
-- turns out to answer, and building a cache for a refusal nobody has observed
-- is the mistake AGENTS.md names under *Do not add a guard for a failure that
-- has not been observed*.
--
-- Position is ours to set, and the reason is narrower than it first looked.
-- HudTooltip is Edit Mode system 11, the probe found it on 2026-09-23 as
-- GameTooltipDefaultContainer with the entire system mixin on it, and the client
-- anchors the tooltip there at offset 0, 0. By the code alone Edit Mode owns
-- this outright.
--
-- **It is the window that does not offer it.** In HUD Edit Mode every managed
-- element wears a selection plate and the tooltip wears none, confirmed by
-- looking. So the corner setting below is the only way to move a tooltip here
-- rather than a second way fighting Edit Mode, and being registered and being
-- adjustable are different facts. See AGENTS.md under *Edit Mode owns the
-- layout*.
--
-- One consequence: the offsets that keep the bags and action bars clear sit on
-- the container, not on the anchor. A corner pinned to UIParent has none of that
-- help, and BOTTOMLEFT is where the chat window lives by default.

local ADDON, FP = ...
local L, N = FP.L, FP.N

-- The lines this addon writes itself are grayed out while "Add extra
-- information" is off, since none of them is written then.
local function NoExtras(mod) return not mod.db.extras end
local NO_EXTRAS = L["Not in use until you switch extra information on."]

local M = FP:RegisterModule("Tooltip", {
    default = true,

    -- Its own page, and off the module list, for the reason BuffExpiry has
    -- both: this is a thing on the screen rather than a behaviour, and a row
    -- that only leads somewhere else earns its space badly. A module that
    -- leaves the list must carry its own switch on its page, or the only way
    -- to turn it off is the command line.
    page      = N["Tooltip"],
    pageOrder = 40,
    hidden    = true,

    desc = L["Extra lines in the game tooltip, and where the tooltip appears."],

    options = {
        { type = "group", label = L["General"] },

        -- The box on the Tooltip tab since 2026-09-30; this entry only words
        -- it there.
        { type = "module", labelOn  = L["Tooltip changes are on"],
          labelOff = L["Tooltip changes are off"],
          desc = L["Off leaves the client's own tooltip exactly as it was, "
              .. "arrangement and position included. The settings are kept."] },

        -- Separate from the module switch on the owner's instruction: somebody
        -- who wants the tooltip in a corner, or the lines paired up, should not
        -- have to accept the lines this addon writes to get either.
        -- The six lines below that it gates in the code are grayed out while
        -- it is off, the owner's request of 2026-10-06: guild rank, target,
        -- sell price, ids and gathering skill, and since 1.0.1 the item
        -- level. Level, class, race, faction,
        -- guild and the class color are the client's own lines arranged, and
        -- go on working without it.
        { key = "extras", type = "toggle", default = true,
          label = L["Add extra information"],
          desc = L["The lines this addon adds. The arrangement and the "
              .. "position still work while this is off."] },

        { type = "group", label = L["Layout"] },

        { key = "layout", type = "select", default = "compact",
          label = L["How the lines are arranged"],
          values = {
              { "blizzlike", L["Blizzlike"] },
              { "list",      L["One per line"] },
              { "compact",   L["Compact"] },
          },
          desc = L["Blizzlike keeps the client's lines in their original "
              .. "order and adds the rest underneath. One per line gives "
              .. "every entry its own line. Compact pairs entries up."] },

        { key = "anchor", type = "select", default = "DEFAULT",
          label = L["Where it appears"],
          values = {
              { "DEFAULT",     L["Default"] },
              { "TOPLEFT",     L["Top left"] },
              { "TOPRIGHT",    L["Top right"] },
              { "BOTTOMLEFT",  L["Bottom left"] },
          },
          desc = L["Default leaves the tooltip where the client puts it. The "
              .. "other options pin it to the chosen corner, and it grows "
              .. "inward."] },

        -- F10 of the after launch plan, CF6.10 on CurseForge, settled with the
        -- owner on 2026-11-04: a small fixed choice with a preview, and the
        -- game's own texture until somebody picks another, in new and existing
        -- profiles alike. See *The health bar's texture* below.
        { key = "barTexture", type = "select", default = "DEFAULT",
          label = L["Health bar texture"],
          values = {
              { "DEFAULT", L["Default"] },
              { "FLAT",    L["Flat"] },
              { "SOFT",    L["Soft gradient"] },
          },
          desc = L["Choose the texture of the health bar below unit tooltips."] },

        { type = "custom", sub = true,
          build = function(holder, width, mod) return mod:BuildBarPreview(holder, width) end },

        -- Every row below is primary and sits under a heading of its own,
        -- asked for on 2026-09-23. They are not `sub`, because none of them
        -- qualifies the one above it: each names a line that either appears or
        -- does not, and they read as a list rather than as a hierarchy.
        { type = "group", label = L["Lines on a Unit"] },

        -- The order here is the order the two built arrangements follow, which
        -- is why it reads level, class, race, faction rather than alphabetically
        -- or by importance. Compact simply pairs them up two at a time.
        { key = "showLevel", type = "toggle", default = true,
          label = L["Level"],
          desc = L["Shows a player's or creature's level. Under Blizzlike, "
              .. "it covers the whole line the client writes, including "
              .. "race."] },

        { key = "showClass", type = "toggle", default = true,
          label = L["Class"],
          desc = L["Shows a player's class."] },

        { key = "showRace", type = "toggle", default = true,
          label = L["Race"],
          desc = L["Shows a player's race or a creature's type."],
          -- Blizzlike keeps the client's own line, and the client writes level
          -- and race on one. Fading this row is the framework's answer to a
          -- setting another setting has made meaningless, and it is the answer
          -- rather than having the two switches write into each other: see the
          -- note above Rewrite.
          disabled = function(mod) return (mod.db.layout or "compact") == "blizzlike" end,
          disabledText = L["Blizzlike includes race on the level line, so "
                      .. "the Level switch controls both."] },

        { key = "showFaction", type = "toggle", default = true,
          label = L["Faction"],
          desc = L["Which side they are on."] },

        { key = "showGuild", type = "toggle", default = true,
          label = L["Guild"],
          desc = L["The guild a player belongs to."] },

        { key = "guildRank", type = "toggle", default = true,
          label = L["Guild rank"],
          disabled = NoExtras, disabledText = NO_EXTRAS,
          desc = L["The rank they hold there."] },

        { key = "targetOfTarget", type = "toggle", default = true,
          label = L["Target"],
          disabled = NoExtras, disabledText = NO_EXTRAS,
          desc = L["Shows who they have targeted, or \"you\" if it is you."] },

        -- The owner's request of 2026-10-20, on by default at his word. See
        -- *The average item level* below.
        { key = "itemLevel", type = "toggle", default = true,
          label = L["Item level"],
          disabled = NoExtras, disabledText = NO_EXTRAS,
          desc = L["Shows the average item level of a player's equipped "
              .. "items. For other players, the value updates when you hover "
              .. "over them outside combat. The last known value stays "
              .. "visible until the new one arrives."] },

        { key = "classColor", type = "toggle", default = true,
          label = L["Class color on the name"],
          desc = L["Colors a player's name by their class."] },

        { type = "group", label = L["Lines on an Item or Spell"] },

        { key = "vendorPrice", type = "toggle", default = true,
          label = L["What it sells for"],
          disabled = NoExtras, disabledText = NO_EXTRAS,
          desc = L["Shows what a vendor pays for the item and the value of "
              .. "the whole stack."] },

        { key = "ids", type = "toggle", default = false,
          label = L["Item and spell ids"],
          disabled = NoExtras, disabledText = NO_EXTRAS,
          desc = L["Shows the IDs of an item, spell or creature."] },

        -- The owner's request of 2026-09-30, gated on 2026-10-03: a line of
        -- its own, shown whether the skill is enough or not.
        { type = "group", label = L["Lines on Herbs, Veins and Corpses"] },

        { key = "gatherSkill", type = "toggle", default = true,
          label = L["Skill needed to gather"],
          disabled = NoExtras, disabledText = NO_EXTRAS,
          desc = L["Shows the Herbalism, Mining or Skinning skill required "
              .. "for herbs, veins and corpses, in the color the game uses "
              .. "for your skill level."] },

    },
})

-- How far from the screen edge a chosen corner sits. The client's own margins
-- are larger and asymmetric because they dodge the bars; ours only has to clear
-- the edge, since the player picked a corner the bars are not in.
local MARGIN = 12

-- ---------------------------------------------------------------------------
-- Reading the thing under the cursor
-- ---------------------------------------------------------------------------

--- The unit a tooltip is describing, or nil.
--
-- Two routes because this build has both shapes in it. TooltipUtil is the
-- modern one and GetUnit is the one every Classic addon uses; neither is
-- assumed to exist.
local function DisplayedUnit(tooltip)
    if TooltipUtil and TooltipUtil.GetDisplayedUnit then
        local ok, _, unit = pcall(TooltipUtil.GetDisplayedUnit, tooltip)
        unit = ok and FP:Plain(unit)
        if unit then return unit end
    end
    if tooltip.GetUnit then
        local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
        unit = ok and FP:Plain(unit)
        if unit then return unit end
    end
    return nil
end

--- A number from this client, or nil when it cannot be handled.
--
-- The same rule as `Plain` below, for numbers: an item id, a price, a stack.
-- A secret number survives a comparison with nil and raises on the first
-- arithmetic comparison, so that is what is tried inside the pcall.
local function Number(value)
    local ok, usable = pcall(function()
        return type(value) == "number" and value > -math.huge
    end)
    return (ok and usable) and value or nil
end

--- How many of the item the tooltip is standing on, when that can be told.
--
-- There is no stack size in the tooltip data itself: the tooltip describes an
-- item, and a stack is a property of the slot it happens to be lying in. So the
-- count is read off the button the tooltip belongs to, which is where the
-- client already draws it. A tooltip with no such owner, an item in a chat
-- link, say, has no stack and says so by returning nil rather than 1.
local function StackCount(tooltip)
    if not tooltip.GetOwner then return nil end
    local ok, owner = pcall(tooltip.GetOwner, tooltip)
    if not ok or not owner then return nil end

    -- Both spellings are in use across the client's own button templates.
    local label = rawget(owner, "count") or rawget(owner, "Count")
    if type(label) ~= "table" or not label.GetText then return nil end

    local okText, text = pcall(label.GetText, label)
    if not okText then return nil end
    local okNumber, n = pcall(tonumber, text)
    n = okNumber and Number(n)
    return (n and n > 1) and n or nil
end

-- ---------------------------------------------------------------------------
-- The lines
-- ---------------------------------------------------------------------------

local GRAY   = { 0.6, 0.6, 0.6 }
local NORMAL = { 1, 0.82, 0 }

--- A string from this client, or nil if it cannot be handled.
--
-- A value this client hands over can be **secret**: it arrives intact, survives
-- tostring, and raises on the first comparison made with it. Every measured
-- sample had UnitName answering plainly, so this is not insurance against
-- something observed; it is the house rule from `FP:Truth`, applied where a
-- raise would happen inside a tooltip the client is drawing.
local function Plain(value)
    if not pcall(function() return value == "" end) then return nil end
    return (type(value) == "string" and value ~= "") and value or nil
end

--- Is this module switched on right now?
--
-- `mod.enabled` and not `mod.db`. Binding a profile points every module's db at
-- it whether or not the module is running, so a db test answers "does this have
-- settings" and never "is it on". The hooks below cannot be undone, so this is
-- the only thing standing between a switched off module and a tooltip it is
-- still writing into.
local function Running()
    return M.enabled and M.db
end

local function AddItemLines(tooltip, data)
    if not Running() or not M.db.extras then return end
    local id = data and Number(rawget(data, "id"))

    if M.db.vendorPrice then
        local getInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
        -- Position 11 is the sell price, per item rather than per stack. nil
        -- and zero are different answers: zero means no merchant wants it, nil
        -- means the item is not cached yet, and only the first is worth a line.
        local price
        if getInfo and id then
            local ok, value = pcall(function() return select(11, getInfo(id)) end)
            price = ok and Number(value) or nil
        end
        if price and price > 0 then
            local count = StackCount(tooltip)
            if count then
                tooltip:AddDoubleLine(
                    L["Sells for (%d)"]:format(count),
                    FP:Money(price * count) .. "  |cff888888" .. FP:Money(price) .. "|r",
                    NORMAL[1], NORMAL[2], NORMAL[3], 1, 1, 1)
            else
                tooltip:AddDoubleLine(L["Sells for"], FP:Money(price),
                    NORMAL[1], NORMAL[2], NORMAL[3], 1, 1, 1)
            end
        end
    end

    if M.db.ids and id then
        tooltip:AddDoubleLine(L["Item"], tostring(id),
            GRAY[1], GRAY[2], GRAY[3], GRAY[1], GRAY[2], GRAY[3])
    end
end

local function AddSpellLines(tooltip, data)
    if not Running() or not M.db.extras or not M.db.ids then return end
    local id = data and Number(rawget(data, "id"))
    if not id then return end
    tooltip:AddDoubleLine(L["Spell"], tostring(id),
        GRAY[1], GRAY[2], GRAY[3], GRAY[1], GRAY[2], GRAY[3])
end

-- ---------------------------------------------------------------------------
-- Grouping the lines by subject
--
-- Asked for on 2026-09-23, with the layout drawn out: name, class and the whole
-- level line, then guild with rank and faction, then who they are targeting.
--
-- The sketch had a blank line between the blocks and they were built, then
-- taken out again the same day: on screen they cost more room than the grouping
-- saved, and a tooltip is read at a glance rather than studied.
--
-- **The hard part is not moving lines, it is knowing which is which.** "Mage"
-- and "Horde" are translated game text and comparing against those literals
-- would break the locale rule outright. What is allowed, and what `ErrorFilter`
-- has always done with the `ERR_` globals, is comparing against a string the
-- client itself has just produced: `UnitClass` and `UnitFactionGroup` each hand
-- back the localized name as their first return, and that is what the tooltip
-- printed.
--
-- Three guards keep a failure cheap rather than ugly:
--
--  * **Players only.** A creature's tooltip carries zone names, PvP marks and
--    quest progress that we cannot identify and must not shuffle.
--  * **Nothing on the right.** A double line's two halves are separate strings
--    and only the left ones are being moved, so any right hand text means we
--    stand aside rather than pull a pair apart.
--  * **All or nothing.** If class, faction or the level line cannot be found,
--    the order is left exactly as the client wrote it. A tooltip in the wrong
--    order is worse than one in Blizzard's order.
-- ---------------------------------------------------------------------------

--- The first return of a client call, as a plain string.
local function First(fn, a)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, a)
    if not ok then return nil end
    return Plain(value)
end

--- A tooltip line as plain text, "" when it is empty, or nil when it cannot be
--- read.
--
-- **A line can be secret.** Found in a dungeon on 2026-09-27, where the client
-- answered questions about the players around with secret values, and what a
-- line says about one of them is the same kind of value. A line that cannot
-- be read makes Rewrite stand aside, which leaves the client's tooltip exactly
-- as it drew it.
local function LineText(index)
    local fs = _G["GameTooltipTextLeft" .. index]
    if not (fs and fs.GetText) then return nil end
    local ok, text = pcall(fs.GetText, fs)
    if not ok then return nil end
    local usable, plain = pcall(function()
        if type(text) ~= "string" then return "" end
        if text == "" then return "" end
        return text
    end)
    return usable and plain or nil
end

--- Is there text on the right of any line? A line that cannot be read counts
--- as yes, which is the side that leaves the tooltip alone.
local function RightHasText(count)
    for i = 1, count do
        local fs = _G["GameTooltipTextRight" .. i]
        if fs and fs.GetText and fs.IsShown then
            local ok, text = pcall(fs.GetText, fs)
            if ok then
                local usable, has = pcall(function()
                    return type(text) == "string" and text ~= ""
                end)
                if not usable or has then return true end
            end
        end
    end
    return false
end

--- A guild name in the game's own angle brackets, or nil.
local function Bracket(name)
    if not name then return nil end
    return "<" .. name .. ">"
end

--- The unit's facts as finished strings, one per switched-on field.
--
-- **Built from data rather than cut out of the text**, which is the whole
-- reason level and race can be separate lines at all: the client writes them
-- on one line together, and no way of splitting that line would survive a
-- change of language. UnitLevel, UnitRace, UnitClass and UnitFactionGroup each
-- answer on their own, and LEVEL is the client's own word for the number.
local function Fields(unit, rank)
    local db = M.db

    local level = select(2, pcall(UnitLevel, unit))
    if not pcall(function() return level == 0 end) then level = nil end
    if type(level) ~= "number" then level = nil end

    local levelText
    if level then
        -- A boss reports -1, which the client writes as question marks rather
        -- than as a number. Punctuation is not game text, so this stays safe.
        levelText = (LEVEL or L["Level"]) .. " " .. (level < 0 and "??" or level)
    end

    return {
        -- A creature has no race and a player has no creature type, so one of
        -- the two answers and the other does not.
        level   = db.showLevel   and levelText or nil,
        class   = db.showClass   and First(UnitClass, unit) or nil,
        race    = db.showRace    and (First(UnitRace, unit)
                                      or First(UnitCreatureType, unit)) or nil,
        faction = db.showFaction and First(UnitFactionGroup, unit) or nil,
        -- In angle brackets, which is the game's own convention for a guild
        -- name and, more to the point here, the thing that separates it from
        -- the rank when the two share a line. Without them Compact read as one
        -- run of words with no telling where the guild ended.
        guild   = db.showGuild and Bracket(First(GetGuildInfo, unit)) or nil,
        rank    = rank or nil,
    }
end

-- **Why the Level and Race switches do not write into each other.** Under
-- Blizzlike the two share the client's one line, and the obvious convenience is
-- to have either switch move the other so the line disappears on one press.
-- That was asked for on 2026-09-23 and declined, because AGENTS.md carries the
-- pitfall it would walk into: *one setting must never silently move another*.
-- BuffExpiry did exactly that once and the result read as settings that would
-- not persist, since a value nobody had touched had moved on its own.
--
-- The rule names the alternative as well, which is to derive the constraint
-- where it is used. So the shared line follows Level alone, and the Race row
-- fades under Blizzlike with a line of hover text saying why. The switch is
-- still exactly where it was when the player picks another arrangement.

--- Rewrites the tooltip's left lines into the arrangement the player chose.
--
-- Returns whether it ran, and whether it found somewhere to put the rank.
-- Those are two answers because the guild line can be switched off while the
-- rank is still switched on, and the rank then has to be said somewhere else
-- rather than disappearing along with a switch nobody touched.
--
-- **Three arrangements and two different risks.** Blizzlike keeps the client's
-- own lines in the client's own order and only drops what is switched off, so
-- it runs on anything. The other two throw those lines away and write their
-- own, so they run on players only: a creature's tooltip carries zone names,
-- PvP marks and quest progress we cannot name, and those are kept and appended
-- rather than lost.
local function Rewrite(tooltip, unit, rank)
    local db   = M.db
    local mode = db.layout or "compact"

    local count = tooltip.NumLines and tooltip:NumLines() or 0
    if count < 2 or RightHasText(count) then return false end

    local isPlayer = FP:Truth(select(2, pcall(UnitIsPlayer, unit)))
    if mode ~= "blizzlike" and not isPlayer then mode = "blizzlike" end

    local className = First(UnitClass, unit)
    local faction   = First(UnitFactionGroup, unit)
    local guild     = First(GetGuildInfo, unit)
    local level     = select(2, pcall(UnitLevel, unit))
    if not pcall(function() return level == 0 end) then return false end
    if type(level) ~= "number" then level = nil end

    -- Read everything once, with its color, before anything is written back.
    local lines, classAt, factionAt, guildAt, levelAt = {}, nil, nil, nil, nil
    for i = 1, count do
        local text = LineText(i)
        if text == nil then return false end
        local fs = _G["GameTooltipTextLeft" .. i]
        local okColor, r, g, b = pcall(fs.GetTextColor, fs)
        lines[i] = { text = text, r = okColor and r or 1,
                     g = okColor and g or 1, b = okColor and b or 1 }

        if i > 1 then
            if not classAt and className and text == className then classAt = i
            elseif not factionAt and faction and text == faction then factionAt = i
            elseif not guildAt and guild and text == guild then guildAt = i
            elseif not levelAt and level
                   and text:find("%f[%d]" .. (level < 0 and 1 or level) .. "%f[%D]") then
                levelAt = i
            end
        end
    end

    local out, rankPlaced = {}, false

    if mode == "blizzlike" then
        -- Level and race share one line here, so it goes only when neither of
        -- them is wanted. Hiding one of a pair by cutting the line up is the
        -- text surgery the other two arrangements exist to avoid.
        local hidden, any = {}, false
        local function hide(index) if index then hidden[index] = true any = true end end
        if not db.showClass   then hide(classAt)   end
        if not db.showGuild   then hide(guildAt)   end
        if not db.showFaction then hide(factionAt) end
        -- Level alone, because race has no line of its own here and its
        -- switch is faded to say so. Requiring both to be off made the Level
        -- switch look broken: you pressed it and nothing moved.
        if not db.showLevel then hide(levelAt) end

        -- Nothing to drop, so the client's own tooltip is left exactly alone
        -- and the caller adds the extra lines underneath it.
        if not any then return false end

        for i = 1, count do
            if not hidden[i] then out[#out + 1] = lines[i] end
        end
    else
        local f = Fields(unit, rank)
        local levelColor = levelAt and lines[levelAt] or nil

        local function add(text, color)
            if not text or text == "" then return end
            out[#out + 1] = { text = text,
                              r = color and color.r or 1,
                              g = color and color.g or 1,
                              b = color and color.b or 1 }
        end
        local function join(one, two)
            if one and two then return one .. " " .. two end
            return one or two
        end

        -- The name, always first and never searched for.
        out[1] = lines[1]
        lines[1].used = true

        if mode == "compact" then
            add(join(f.level, f.class), levelColor)
            add(join(f.race, f.faction))
            add(join(f.guild, f.rank))
        else
            add(f.level, levelColor)
            add(f.class)
            add(f.race)
            add(f.faction)
            add(f.guild)
            add(f.rank)
        end
        if f.rank then rankPlaced = true end

        -- The client's own versions of what we just rebuilt are dropped, and
        -- everything we could not name is appended in its original order. A
        -- line we do not understand still belongs to the client and says
        -- something we did not think of.
        for _, index in ipairs({ classAt or 0, factionAt or 0, guildAt or 0, levelAt or 0 }) do
            if lines[index] then lines[index].used = true end
        end
        for i = 2, count do
            if not lines[i].used and lines[i].text ~= "" then out[#out + 1] = lines[i] end
        end
    end

    -- Grow first, then rewrite: AddLine appends, so every index is stable once
    -- the count is right. Anything left over at the end is emptied, which is
    -- what dropping a line comes down to.
    while (tooltip:NumLines() or 0) < #out do tooltip:AddLine(" ") end
    local total = tooltip:NumLines() or #out
    for i = 1, total do
        local fs = _G["GameTooltipTextLeft" .. i]
        if not fs then break end
        local line = out[i]
        pcall(fs.SetText, fs, line and line.text or "")
        if line then pcall(fs.SetTextColor, fs, line.r, line.g, line.b) end
    end
    return true, rankPlaced
end

-- ---------------------------------------------------------------------------
-- Guilds seen, for a player who is not under the cursor
--
-- Phase 6 shortens names in the chat, and the owner's condition for that was
-- the full name one hover away, with class and guild. A name in the chat has
-- no unit behind it, so nothing can be asked about its guild; what can be done
-- is to remember the guild of every player whose tooltip was shown. That is
-- caching of the kind 5.1 allowed, by volatility: a guild is the same a minute
-- later. Bounded, and started again rather than trimmed when full.
-- ---------------------------------------------------------------------------

local guilds, guildCount = {}, 0
local MAX_GUILDS = 500

local function NoteGuild(unit)
    if not (UnitGUID and GetGuildInfo) then return end
    local okGuid, guid = pcall(UnitGUID, unit)
    guid = okGuid and Plain(guid)
    if not guid then return end
    local ok, name, rank = pcall(GetGuildInfo, unit)
    if not ok then return end

    if guilds[guid] == nil then
        guildCount = guildCount + 1
        if guildCount > MAX_GUILDS then
            wipe(guilds)
            guildCount = 1
        end
    end
    name = Plain(name)
    guilds[guid] = name and { name = name, rank = Plain(rank) } or false
end

-- ---------------------------------------------------------------------------
-- The skill a herb or a corpse asks for
--
-- Gated with the owner on 2026-10-03: a line of its own, always, under a
-- switch of its own. The level comes from Data/Gathering.lua, a herb known by
-- the name of the item it gives, or from the corpse's level by the Classic
-- rule, and a vein by the beginning of its ore's name. Why, and what that
-- misses, is in the head of that file.
--
-- **The line wears the color of the client's own skill line**, the owner's
-- wish of 2026-10-03, so it reads with the same difficulty: red when the
-- skill is too low or missing, then orange, yellow, green and gray. Measured
-- over a Peacebloom the same day: the client writes the skill on the second
-- line, "Requires Herbalism" in red without the profession and "Herbalism" in
-- green with it. Taking its color says what the addon cannot ask by itself,
-- since the skill line API names professions in the client's language and the
-- locale rule keeps those names out of anything compared.
-- ---------------------------------------------------------------------------

--- The color of a line of the game tooltip, or nil when it cannot be read.
local function LineColor(index)
    local fs = _G["GameTooltipTextLeft" .. index]
    if not (fs and fs.GetTextColor) then return nil end
    local ok, r, g, b = pcall(fs.GetTextColor, fs)
    r, g, b = ok and Number(r), ok and Number(g), ok and Number(b)
    if r and g and b then return { r, g, b } end
    return nil
end

--- Our line, in the color of the client's skill line, white without one.
local function AddGatherLine(tooltip, skill, level, color)
    local name = FP.GATHER_SKILLS and FP.GATHER_SKILLS[skill]
    if not (name and level) then return end
    local r, g, b = 1, 1, 1
    if color then r, g, b = color[1], color[2], color[3] end
    tooltip:AddDoubleLine(L["Requires %s"]:format(FP:T(name)), tostring(level), r, g, b, r, g, b)
end

-- The herbs and ores by the name of their item, in the client's language.
-- Built as the names arrive: an item the client has not cached yet answers
-- nil, is asked for, and is looked up again on the next hover.
--
-- **Asked for as soon as the module runs**, since 2026-10-03: the owner's
-- first Kingsblood showed no line, and the second hover did, because the
-- client had not cached that item's name yet. LearnNames from OnEnable asks
-- for every one up front, so the names are there before the first node.
local herbNames, oreNames, missing = {}, {}, nil

local function LearnNames()
    if missing == 0 then return end
    local getName = C_Item and C_Item.GetItemNameByID
    local request = C_Item and C_Item.RequestLoadItemDataByID
    missing = 0
    local function Learn(items, names)
        for item, level in pairs(items or {}) do
            local known = false
            for _, entry in pairs(names) do
                if entry.item == item then known = true break end
            end
            if not known then
                local itemName = getName and Plain(select(2, pcall(getName, item)))
                if itemName then
                    names[itemName] = { item = item, level = level }
                else
                    missing = missing + 1
                    if request then pcall(request, item) end
                end
            end
        end
    end
    Learn(FP.GATHER_HERBS, herbNames)
    Learn(FP.GATHER_ORES, oreNames)
end

--- A gathering profession's name in the client's language, or nil.
--
-- Asked of the client twice over: C_TradeSkillUI.GetTradeSkillDisplayName
-- by skill line, which this build's API documentation lists and nothing here
-- has measured yet, and the name of a spell that carries the profession's
-- name, measured for Mining on 2026-10-04: "Mining is called Mining here".
-- The name is only ever looked for inside text the client wrote itself.
local function SkillName(skill)
    local line = FP.GATHER_SKILL_LINES and FP.GATHER_SKILL_LINES[skill]
    local get = C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName
    if line and get then
        local name = Plain(select(2, pcall(get, line)))
        if name then return name end
    end
    local spell = FP.GATHER_SKILL_SPELLS and FP.GATHER_SKILL_SPELLS[skill]
    return spell and FP:SpellName(spell) or nil
end

--- Does the client's second line name this profession?
local function NamesSkill(skill, skillLine)
    local name = SkillName(skill)
    return name and skillLine and skillLine:find(name, 1, true) and true or false
end

--- The entry among `names` that `name` is made from, see FP:ClosestName.
local function Closest(name, names)
    return (FP:ClosestName(name, names))
end

--- The Herbalism a herb asks for, or nil when this is no herb we know.
--
-- By the name of the item it gives, whole, which needs no further proof.
-- Failing that, by the item name it holds most of, FP:ClosestName, for the
-- herbs WoW Forever added to its starting zones, and only when the second
-- line names Herbalism, so that nothing else sharing a word with a herb passes.
local function HerbLevel(name, skillLine)
    if not name then return nil end
    LearnNames()
    local entry = herbNames[name]
    if not entry and NamesSkill("herb", skillLine) then
        entry = Closest(name, herbNames)
    end
    return entry and entry.level, entry and entry.item
end

--- The Mining a vein asks for, or nil when this is no vein we know.
--
-- Only an object whose second line names Mining counts, so an Iron Gate
-- never matches Iron Ore. Then the English exceptions by their whole name,
-- then the ore whose name the vein holds most of, FP:ClosestName: "Copper "
-- in "Poor Copper Vein", a vein WoW Forever added and the owner's report of
-- 2026-10-04, which the longest shared beginning used before could not find.
-- See the head of Data/Gathering.lua for why both.
local function VeinLevel(name, skillLine)
    if not (name and NamesSkill("mine", skillLine)) then return nil end

    local listed = FP.GATHER_VEINS_ENGLISH and FP.GATHER_VEINS_ENGLISH[name]
    if listed then return listed end

    LearnNames()
    local best = Closest(name, oreNames)
    return best and best.level, best and best.item
end

--- The first line of a world object's tooltip data: its name.
local function ObjectName(data)
    local ok, name = pcall(function()
        local lines = rawget(data, "lines")
        local first = type(lines) == "table" and lines[1]
        return type(first) == "table" and rawget(first, "leftText") or nil
    end)
    return ok and Plain(name) or nil
end

local function AddObjectLines(tooltip, data)
    if not Running() or not M.db.extras or not M.db.gatherSkill then return end
    if tooltip ~= GameTooltip or type(data) ~= "table" then return end
    local name, skillLine = ObjectName(data), LineText(2)
    local level = HerbLevel(name, skillLine)
    if level then return AddGatherLine(tooltip, "herb", level, LineColor(2)) end
    level = VeinLevel(name, skillLine)
    if level then AddGatherLine(tooltip, "mine", level, LineColor(2)) end
end

-- Which profession each of the client's own corpse lines names. The client's
-- strings, compared with what the client itself wrote, which is what the
-- locale rule allows; see ErrorFilter. Engineering's bolts are left out.
local CORPSE_LINES = {
    UNIT_SKINNABLE_LEATHER = "skin",
    UNIT_SKINNABLE_HERB    = "herb",
    UNIT_SKINNABLE_ROCK    = "mine",
}

--- On a dead creature that can be gathered: the skill it asks for.
local function AddCorpseLine(tooltip, unit)
    if tooltip ~= GameTooltip then return end
    if FP:Truth(select(2, pcall(UnitIsDead, unit))) ~= true then return end
    if FP:Truth(select(2, pcall(UnitIsPlayer, unit))) ~= false then return end

    local count = (GameTooltip.NumLines and GameTooltip:NumLines()) or 0
    for i = 2, count do
        local text = LineText(i)
        if text and text ~= "" then
            for global, skill in pairs(CORPSE_LINES) do
                if Plain(_G[global]) == text then
                    local level = Number(select(2, pcall(UnitLevel, unit)))
                    AddGatherLine(tooltip, skill, FP:CorpseSkill(level), LineColor(i))
                    return
                end
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- The average item level, the owner's request of 2026-10-20 for 1.0.1
--
-- Read in the client's code for build 70425 first: its API documentation names
-- NotifyInspect, the event INSPECT_READY with the inspected guid, and
-- C_PaperDollInfo.GetInspectItemLevel, and nothing in the client's own
-- interface shows an item level. Measured by the owner the same day:
-- CanInspect answered true for a player beside him, and after NotifyInspect
-- GetInspectItemLevel answered a plain 4, not secret.
--
-- **So another player is read only after asking the server**, which this does
-- when the tooltip shows them: never in a fight, never while the player's own
-- inspect window is open, where the answer to a second request could replace
-- the player in it, at most one request on its way, and none for a player
-- answered within the last half minute. The answer is kept by guid for the
-- session and shown at once the next time, until a fresh one replaces it, the
-- owner's choice of 2026-10-20. An answer to the client's own inspect window
-- is kept as well, since reading it costs nothing.
--
-- The line's label is the client's own word, STAT_AVERAGE_ITEM_LEVEL, which
-- every language has.
-- ---------------------------------------------------------------------------

local itemLevels = {}       -- [guid] = { level, at }, this session's answers
local asked = nil           -- { guid, at } while a request is on its way
local lastAsk = 0
local ASK_TIMEOUT = 3       -- a request without an answer by then is lost
local ASK_GAP     = 1.5     -- the least time between two requests
local FRESH       = 30      -- an answer this young is not asked for again

-- Which line of the open tooltip holds the value, so a fresh answer writes
-- over it rather than adding a second one: { guid, line }.
local shownLevel = nil

local function ItemLevelLabel()
    return Plain(_G.STAT_AVERAGE_ITEM_LEVEL) or L["Item level"]
end

--- The average the client holds for a unit, unrounded, or nil.
local function ClientItemLevel(unit)
    local info = _G.C_PaperDollInfo
    if not (info and info.GetInspectItemLevel) then return nil end
    local ok, value = pcall(info.GetInspectItemLevel, unit)
    return ok and Number(value) or nil
end

--- The same, rounded down, and nil for nothing at all.
local function ReadItemLevel(unit)
    local value = ClientItemLevel(unit)
    if value and value > 0 then return math.floor(value) end
    return nil
end

-- **Your own average is the client's GetAverageItemLevel**, which this build
-- has although its API documentation does not name it: measured by the owner
-- on 2026-10-20, 28.69 for all three of its values, where GetInspectItemLevel
-- answers 0 for "player". The second value is what you wear.
--
-- Worked out from the equipment for one evening first, by retail's rule, and
-- taken back the same day: it came to 28.50 for him, and an inspected
-- player's items arrived only seven of them while the client counted all, so
-- the client's own number is the only one that is right for both.
local function OwnItemLevel()
    local average = _G.GetAverageItemLevel
    if not average then return nil end
    local ok, overall, equipped = pcall(average)
    local value = ok and (Number(equipped) or Number(overall))
    if value and value > 0 then return math.floor(value) end
    return nil
end

local function AskForItemLevel(unit, guid)
    if not (NotifyInspect and CanInspect) or InCombatLockdown() then return end
    local inspect = _G.InspectFrame
    if inspect and FP:Truth(select(2, pcall(inspect.IsShown, inspect))) then
        return
    end
    local now = GetTime()
    if asked and now - asked.at < ASK_TIMEOUT then return end
    if now - lastAsk < ASK_GAP then return end
    if FP:Truth(select(2, pcall(CanInspect, unit))) ~= true then return end
    if not pcall(NotifyInspect, unit) then return end
    asked, lastAsk = { guid = guid, at = now }, now
end

--- The value on the open tooltip: written over the line that holds it, or
--- added under the rest.
local function ShowItemLevel(tooltip, guid, level)
    local text = tostring(level)
    local line = shownLevel and shownLevel.guid == guid and shownLevel.line
    if line then
        local left  = _G["GameTooltipTextLeft" .. line]
        local right = _G["GameTooltipTextRight" .. line]
        if left and right
           and Plain(select(2, pcall(left.GetText, left))) == ItemLevelLabel() then
            pcall(right.SetText, right, text)
            pcall(tooltip.Show, tooltip)
            return
        end
    end
    tooltip:AddDoubleLine(ItemLevelLabel(), text,
        NORMAL[1], NORMAL[2], NORMAL[3], 1, 1, 1)
    shownLevel = { guid = guid, line = tooltip:NumLines() }
    pcall(tooltip.Show, tooltip)
end

local function AddItemLevel(tooltip, unit)
    shownLevel = nil
    if tooltip ~= GameTooltip then return end
    if FP:Truth(select(2, pcall(UnitIsPlayer, unit))) ~= true then return end
    local guid = Plain(select(2, pcall(UnitGUID, unit)))
    if not guid then return end

    local level
    if FP:Truth(select(2, pcall(UnitIsUnit, unit, "player"))) == true then
        level = OwnItemLevel()
    else
        local known = itemLevels[guid]
        level = known and known.level
        if not (known and GetTime() - known.at < FRESH) then
            AskForItemLevel(unit, guid)
        end
    end
    if level then
        tooltip:AddDoubleLine(ItemLevelLabel(), tostring(level),
            NORMAL[1], NORMAL[2], NORMAL[3], 1, 1, 1)
        shownLevel = { guid = guid, line = tooltip:NumLines() }
    end
end

--- The server's answer, to our request or to the client's inspect window.
local function OnInspectReady(guid)
    guid = Plain(guid)
    if not guid then return end
    if asked and asked.guid == guid then asked = nil end

    local unit
    local tipUnit = GameTooltip and DisplayedUnit(GameTooltip)
    local onTip = tipUnit and Plain(select(2, pcall(UnitGUID, tipUnit))) == guid
    if onTip then
        unit = tipUnit
    elseif UnitTokenFromGUID then
        unit = Plain(select(2, pcall(UnitTokenFromGUID, guid)))
    end
    if not unit then return end

    local level = ReadItemLevel(unit)
    if not level then return end
    itemLevels[guid] = { level = level, at = GetTime() }

    if onTip and FP:Truth(select(2, pcall(GameTooltip.IsShown, GameTooltip))) then
        ShowItemLevel(GameTooltip, guid, level)
    end
end

local function AddUnitLines(tooltip)
    if not Running() then return end
    local unit = DisplayedUnit(tooltip)
    if not unit then return end

    if FP:Truth(select(2, pcall(UnitIsPlayer, unit))) then NoteGuild(unit) end

    -- Two returns matter and the rank is the second, behind the guild name.
    -- Leatrix Plus, which the requester named as the model, shows the name and
    -- not the rank, so this is the part of the request its own model misses.
    local rank
    if M.db.extras and M.db.guildRank and GetGuildInfo then
        local ok, _, name = pcall(GetGuildInfo, unit)
        if ok then rank = Plain(name) end
    end

    -- Rewrite folds the rank onto the guild line when it runs. When it stands
    -- aside the rank still gets said on a line of its own, which is what this
    -- did before any of the grouping existed.
    --
    -- Called through pcall rather than FP:Safe on purpose: Safe reports whether
    -- the call survived, and what decides the fallback here is what Rewrite
    -- answered.
    local ok, rewritten, rankPlaced = pcall(Rewrite, tooltip, unit, rank)
    rewritten = ok and rewritten
    if rank and not (rewritten and rankPlaced) then
        tooltip:AddLine(rank, GRAY[1], GRAY[2], GRAY[3])
    end

    if M.db.extras and M.db.targetOfTarget then
        -- Measured on 2026-09-23 and the reason this line exists at all: unit
        -- identity is something C_Secrets covers, so the worry was a line that
        -- vanishes in combat, which is when it is worth having. It does not. In
        -- the lockdown, on a creature, this returned a player name and
        -- UnitIsUnit confirmed which player.
        --
        -- **In a dungeon it does.** Reported on 2026-09-27 from Ragefire Chasm,
        -- where UnitIsUnit answered with a secret boolean and the test on it
        -- raised on every hover. Every answer here is now asked through
        -- FP:Truth and Plain, and a question the client will not answer drops
        -- the line rather than guessing: "you" is only said when the client
        -- says so, a name only when the name is readable.
        local other = unit .. "target"
        local okExists, exists = pcall(UnitExists, other)
        if okExists and FP:Truth(exists) == true then
            local okMe, isMe = pcall(UnitIsUnit, other, "player")
            local me = okMe and FP:Truth(isMe)
            local name, color
            if me == true then
                -- The case worth reading at a glance during a fight, so it says
                -- so in a word rather than repeating the player's own name.
                name, color = L["you"], { r = 1, g = 0.4, b = 0.4 }
            else
                name = Plain(select(2, pcall(UnitName, other)))
                if name and M.db.classColor and RAID_CLASS_COLORS then
                    local okClass, _, token = pcall(UnitClass, other)
                    token = okClass and Plain(token)
                    if token then color = RAID_CLASS_COLORS[token] end
                end
            end
            if name then
                local r, g, b = 1, 1, 1
                if color then r, g, b = color.r, color.g, color.b end
                tooltip:AddDoubleLine(L["Target"], name,
                    NORMAL[1], NORMAL[2], NORMAL[3], r, g, b)
            end
        end
    end

    if M.db.extras and M.db.itemLevel then
        FP:Safe("Tooltip:AddItemLevel", AddItemLevel, tooltip, unit)
    end

    if M.db.classColor and RAID_CLASS_COLORS then
        -- The second return is the non-localized token, which is what the
        -- color table is keyed by. The display name would break on any client
        -- that is not this one.
        local okPlayer, isPlayer = pcall(UnitIsPlayer, unit)
        local okClass, _, token  = pcall(UnitClass, unit)
        token = okClass and Plain(token)
        if okPlayer and FP:Truth(isPlayer) == true and token then
            local color = RAID_CLASS_COLORS[token]
            local name  = _G["GameTooltipTextLeft1"]
            if color and name and name.SetTextColor then
                pcall(name.SetTextColor, name, color.r, color.g, color.b)
            end
        end
    end

    if M.db.extras and M.db.gatherSkill then
        FP:Safe("Tooltip:AddCorpseLine", AddCorpseLine, tooltip, unit)
    end

    if M.db.extras and M.db.ids then
        local ok, guid = pcall(UnitGUID, unit)
        guid = ok and Plain(guid)
        if guid then
            -- "Creature-0-1234-0-0-2448-000012AB": the sixth field is the id
            -- worth having. A player's guid has no such field and the match
            -- simply fails, which is the right answer for a player.
            local npc = guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
            if npc then
                tooltip:AddDoubleLine("NPC", npc,
                    GRAY[1], GRAY[2], GRAY[3], GRAY[1], GRAY[2], GRAY[3])
            end
        end
    end

    -- Adding a line makes the tooltip measure itself again; writing over one
    -- does not. After a regroup the longest line may have moved or grown, so it
    -- is asked to size itself once more before it is drawn.
    if rewritten then pcall(tooltip.Show, tooltip) end
end

--- The card for a player named somewhere other than under the cursor.
--
-- The chat calls this when a shortened name is hovered. A player the client
-- has a unit for, somebody in the group, targeted or on a nameplate, gets the
-- whole tooltip, arrangement and extra lines included, because that is the
-- best description there is. Anybody else gets what the guid says and what
-- this module remembers: the name in full and in its class color, race and
-- class, and a guild if one was ever seen.
--
-- The GameTooltip rather than the addon's own, by the owner's rule of
-- 2026-09-26: a tooltip that shows one of the game's objects stays the game's.
--
-- @param owner  the frame the pointer is over
-- @param name   the name in full, as the chat line had it
-- @param guid   the speaker's guid, or nil when the line did not carry one
function FP:ShowPlayerCard(owner, name, guid)
    if not (GameTooltip and owner and name) then return end
    GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")

    if guid and UnitTokenFromGUID then
        local ok, unit = pcall(UnitTokenFromGUID, guid)
        unit = ok and Plain(unit)
        if unit and pcall(GameTooltip.SetUnit, GameTooltip, unit) then return end
    end

    local className, classToken, raceName
    if guid and GetPlayerInfoByGUID then
        local ok, class, token, race = pcall(GetPlayerInfoByGUID, guid)
        if ok then className, classToken, raceName = Plain(class), Plain(token), Plain(race) end
    end

    local color = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
    GameTooltip:AddLine(name, color and color.r or 1, color and color.g or 1,
        color and color.b or 1)

    local what = (raceName and className) and (raceName .. " " .. className)
                 or raceName or className
    if what then GameTooltip:AddLine(what, 1, 1, 1) end

    local guild = guid and guilds[guid]
    if guild then
        GameTooltip:AddLine(Bracket(guild.name) .. (guild.rank and (" " .. guild.rank) or ""),
            GRAY[1], GRAY[2], GRAY[3])
    end
    GameTooltip:Show()
end

-- ---------------------------------------------------------------------------
-- Placement
-- ---------------------------------------------------------------------------

--- Puts the tooltip in the chosen corner, growing inward.
--
-- A frame grows away from the point it is anchored by, so pinning the tooltip's
-- own top left to the screen's top left leaves that corner still and lets it
-- spread down and right. That is the whole of the answer to a tooltip that
-- grows the wrong way when an item has a long name: pick the right corner and
-- the direction follows.
local function Reanchor(tooltip)
    if not Running() or not tooltip then return end
    local corner = M.db.anchor
    if not corner or corner == "DEFAULT" then return end

    local x = corner:find("LEFT") and MARGIN or -MARGIN
    local y = corner:find("TOP")  and -MARGIN or MARGIN

    tooltip:ClearAllPoints()
    tooltip:SetPoint(corner, UIParent, corner, x, y)
end

-- ---------------------------------------------------------------------------
-- The health bar's texture
--
-- F10 of the after launch plan. **Only the picture**: the bar under a unit's
-- tooltip stays the client's, GameTooltipStatusBar in its interface code for
-- build 70790, with the value, the color, the unit it watches and whether it
-- shows all its own. Health is secret on this client, and the client keeps the
-- bar working through secure methods for exactly that reason, so nothing here
-- reads a value or touches one of those.
--
-- **The client's own texture is not touched until somebody picks another**, so
-- a player who never looks here has a bar nobody has handled, and another
-- addon's choice is not overwritten. Back to Default, or with the module off,
-- it gets back what it had before the first change.
-- ---------------------------------------------------------------------------

-- The client's plain white, tinted by the bar's color, and the status bar
-- texture most of its own older bars are drawn with, light above and dark below.
-- Both in its interface code for this build. Candidates for the owner's eye.
local BAR_TEXTURES = {
    FLAT = "Interface\\Buttons\\WHITE8X8",
    SOFT = "Interface\\TargetingFrame\\UI-StatusBar",
}

-- What the client's XML gives the bar, for a bar that will not say.
local BAR_DEFAULT = "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill"

local barOriginal, barChanged

local function HealthBar()
    local bar = rawget(_G, "GameTooltipStatusBar")
    if bar and type(bar.SetStatusBarTexture) == "function" then return bar end
    return nil
end

--- The texture the bar has of its own, a file id or a path.
local function OriginalBarTexture()
    if barChanged then return barOriginal or BAR_DEFAULT end
    local bar = HealthBar()
    local ok, texture = pcall(function() return bar:GetStatusBarTexture():GetTexture() end)
    return (ok and texture) or BAR_DEFAULT
end

local function ApplyBarTexture()
    local bar = HealthBar()
    if not bar then return end
    local wanted = Running() and BAR_TEXTURES[M.db.barTexture] or nil
    if wanted then
        if not barChanged then
            barOriginal = OriginalBarTexture()
            barChanged = true
        end
        bar:SetStatusBarTexture(wanted)
    elseif barChanged then
        bar:SetStatusBarTexture(barOriginal or BAR_DEFAULT)
        barChanged = false
    end
end

-- The preview's size and color: the height the client gives the real bar, about
-- the width of a tooltip, and the green it draws while nothing asks for another.
local PREVIEW_WIDTH, PREVIEW_HEIGHT, PREVIEW_ROW = 200, 8, 22

local function PaintBarPreview()
    local bar = M.barPreview
    if not bar or not M.db then return end
    bar:SetStatusBarTexture(BAR_TEXTURES[M.db.barTexture] or OriginalBarTexture())
    bar:SetStatusBarColor(0, 1, 0)
end

--- The sample under the setting: an invented value, never a unit's health.
function M:BuildBarPreview(holder, width)
    local caption = FP:FontString(holder, "OVERLAY", "body")
    caption:SetPoint("LEFT", holder, "LEFT", FP.ROW_TEXT_X, 0)
    caption:SetText(L["Preview"])

    local bar = CreateFrame("StatusBar", nil, holder)
    bar:SetSize(math.min(PREVIEW_WIDTH, math.max(width - FP.ROW_TEXT_X - 80, 60)),
        PREVIEW_HEIGHT)
    bar:SetPoint("LEFT", caption, "RIGHT", 10, 0)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0.65)

    -- The empty part, which a real tooltip shows as whatever lies behind it.
    local ground = bar:CreateTexture(nil, "BACKGROUND")
    ground:SetAllPoints()
    ground:SetColorTexture(0, 0, 0, 0.5)

    self.barPreview = bar
    PaintBarPreview()
    return PREVIEW_ROW
end

-- ---------------------------------------------------------------------------

local hooked = false

--- Registers with the client once, and never again.
--
-- Both hooks are permanent: hooksecurefunc and AddTooltipPostCall cannot be
-- undone, so switching the module off has to be answered inside the handlers
-- rather than by unhooking. Running() above is what every handler tests first.
local function Hook()
    if hooked then return end

    local proc = _G.TooltipDataProcessor
    if proc and proc.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        local types = Enum.TooltipDataType
        if types.Item then proc.AddTooltipPostCall(types.Item, AddItemLines) end
        if types.Spell then proc.AddTooltipPostCall(types.Spell, AddSpellLines) end
        if types.Unit then proc.AddTooltipPostCall(types.Unit, AddUnitLines) end
        if types.Object then proc.AddTooltipPostCall(types.Object, AddObjectLines) end
    else
        -- Said out loud rather than failing quietly. A module that draws
        -- nothing and reports nothing is indistinguishable from one that is
        -- switched off, which has cost this project two features already.
        FP:Warn(L["Tooltip: TooltipDataProcessor is unavailable in this "
            .. "client build, so no lines can be added. Placement still "
            .. "works."])
    end

    if _G.GameTooltip_SetDefaultAnchor and hooksecurefunc then
        -- Hooked rather than replaced, and after the fact: the client re-places
        -- the tooltip on every single show, so a point set anywhere else does
        -- not survive one.
        hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip)
            if tooltip == GameTooltip then FP:Safe("Tooltip:Reanchor", Reanchor, tooltip) end
        end)
    else
        FP:Warn(L["Tooltip: GameTooltip_SetDefaultAnchor is unavailable in "
            .. "this client build, so the corner setting has no effect."])
    end

    -- The server's answers for the item level. Registered once like the
    -- hooks above, and asked first whether the line is wanted at all.
    local inspect = CreateFrame("Frame")
    inspect:RegisterEvent("INSPECT_READY")
    inspect:SetScript("OnEvent", function(_, _, guid)
        if Running() and M.db.extras and M.db.itemLevel then
            FP:Safe("Tooltip:InspectReady", OnInspectReady, guid)
        end
    end)

    hooked = true
end

function M:OnEnable()
    Hook()
    FP:Safe("Tooltip:LearnNames", LearnNames)
    FP:Safe("Tooltip:ApplyBarTexture", ApplyBarTexture)
end

function M:OnDisable()
    -- The hooks stay and every handler asks Running() first. The position needs
    -- nothing, since the client puts that back by itself at the next show, once
    -- our hook declines to move it. The bar's texture does not come back by
    -- itself.
    FP:Safe("Tooltip:ApplyBarTexture", ApplyBarTexture)
end

--- Changing the corner should not need the tooltip to be shown again, and the
--- texture and its preview follow at once.
function M:Reapply()
    if GameTooltip and GameTooltip:IsShown() then
        FP:Safe("Tooltip:Reanchor", Reanchor, GameTooltip)
    end
    FP:Safe("Tooltip:ApplyBarTexture", ApplyBarTexture)
    FP:Safe("Tooltip:PaintBarPreview", PaintBarPreview)
end

--- /fplus tooltip ilvl: what the client says about item levels, for you and
--- for a targeted player, whose value comes with an inspect, asked for here.
--
-- Kept for a player who reports a wrong item level: the tooltip shows what
-- the client answers and nothing else. Says nothing unless asked and writes
-- nothing.
function M:ItemLevelStatus()
    local function F(value)
        value = Number(value)
        return value and string.format("%.2f", value) or "nil"
    end
    local function Report(unit)
        FP:Print("%s: GetInspectItemLevel %s.", unit, F(ClientItemLevel(unit)))
    end

    local average = _G.GetAverageItemLevel
    if average then
        local ok, a, b, c = pcall(average)
        FP:Print("GetAverageItemLevel: %s", ok and (F(a) .. " " .. F(b) .. " " .. F(c))
            or "raised")
    else
        FP:Print("GetAverageItemLevel is absent on this build.")
    end
    FP:Print("CanInspect player %s, target %s.",
        tostring(FP:Truth(select(2, pcall(CanInspect, "player")))),
        tostring(FP:Truth(select(2, pcall(CanInspect, "target")))))
    Report("player")

    if FP:Truth(select(2, pcall(UnitIsPlayer, "target"))) ~= true then
        return FP:Print("Target another player to read theirs as well.")
    end
    if NotifyInspect and not InCombatLockdown() then pcall(NotifyInspect, "target") end
    FP:Print("Inspecting the target; its numbers follow in two seconds.")
    C_Timer.After(2, function() FP:Safe("Tooltip:ItemLevelStatus", Report, "target") end)
end

--- /fplus tooltip node: everything the client says about what is under the
--- cursor, key by key.
--
-- The measurement ROADMAP.md asked for before the gathering line was built,
-- kept for when a node shows no line or the wrong number: a table printed with
-- tostring has measured nothing, see AGENTS.md, so every key of every line and
-- every argument is opened. Says nothing unless asked and writes nothing.
function M:NodeStatus()
    local function Show(value)
        local ok, text = pcall(function()
            if value == nil then return "nil" end
            return tostring(value) .. ""
        end)
        if not ok then return "secret" end
        return text
    end
    local function Dump(prefix, t, depth)
        -- Deep enough for a line's color, data > lines > line > leftColor,
        -- which a limit of three cut off on the first run.
        if depth > 5 then return end
        local keys = {}
        for key in pairs(t) do keys[#keys + 1] = key end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, key in ipairs(keys) do
            local value = t[key]
            if type(value) == "table" then
                DEFAULT_CHAT_FRAME:AddMessage(prefix .. tostring(key) .. " =")
                Dump(prefix .. "  ", value, depth + 1)
            else
                DEFAULT_CHAT_FRAME:AddMessage(prefix .. tostring(key) .. " = " .. Show(value))
            end
        end
    end

    local get = C_TooltipInfo and C_TooltipInfo.GetWorldCursor
    local ok, data = false, nil
    if get then ok, data = pcall(get) end
    if not get then
        FP:Print("C_TooltipInfo.GetWorldCursor is absent on this build.")
    elseif not ok then
        FP:Print("GetWorldCursor raised.")
    elseif type(data) ~= "table" then
        FP:Print("Nothing under the cursor: GetWorldCursor answered %s.", Show(data))
    else
        local name, skillLine = ObjectName(data), LineText(2)
        local level, item = HerbLevel(name, skillLine)
        local what = level and string.format("herb of item %d, Herbalism %d", item, level)
        if not what then
            level, item = VeinLevel(name, skillLine)
            what = level and string.format("vein of item %s, Mining %d",
                tostring(item or "listed by name"), level)
        end
        FP:Print("Under the cursor: %s, %s; here Herbalism is called %s, Mining %s, "
            .. "Skinning %s.", Show(name), what or "no herb or vein in the tables",
            Show(SkillName("herb")), Show(SkillName("mine")), Show(SkillName("skin")))
        pcall(Dump, "  ", data, 1)
    end

    if FP:Truth(select(2, pcall(UnitExists, "mouseover"))) == true then
        local level = Number(select(2, pcall(UnitLevel, "mouseover")))
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "  mouseover: dead %s, level %s, skill by the corpse rule %s",
            Show(select(2, pcall(UnitIsDead, "mouseover"))), Show(level),
            Show(FP:CorpseSkill(level))))
        for global in pairs(CORPSE_LINES) do
            DEFAULT_CHAT_FRAME:AddMessage("  " .. global .. " = " .. Show(_G[global]))
        end
    end
end
