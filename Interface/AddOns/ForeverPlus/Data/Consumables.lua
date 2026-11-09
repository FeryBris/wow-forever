-- What runs out, as a table rather than as code.
--
-- Tables, not logic: this file is read by Modules/Consumables.lua and knows
-- nothing about frames or events, exactly like Data/Buffs.lua.
--
-- **Where the numbers come from, and how far they can be trusted.**
--
-- Four entries are measured on this client, the ones carrying a `spell`: the
-- owner drank them on 2026-09-20 with the probe running, and the probe then
-- read their items straight out of his bags. Item id, aura id, duration, level
-- and picture are facts for those four. Everything else is research, read off
-- the Classic item database on the same day, and it is a proposal until
-- somebody looks at the page in game.
--
-- Those four are also what says how far the research can be trusted. Three of
-- them carry the Classic item id the research proposed, under this build's own
-- names: item 2454 is "Elixir of Minor Strength" here where Classic calls it
-- "Elixir of Lion's Strength", and the Troll's Blood potions are elixirs. So
-- the ids map and the names do not. The fourth, Minor Arcane Elixir, does not
-- exist in Classic at all and carries a seven digit spell id.
--
-- So: **ids travel, names do not.** Everything here is keyed by id, every
-- label shown in game comes from the client, and the `name` below is only a
-- fallback for a row the client cannot resolve. That fallback is our own
-- English and is never compared against anything, which is the locale rule
-- followed rather than bent.
--
-- An entry needs an item or a spell, and may carry both:
--
--   item   what you buy. Gives the name, the picture and the level it needs,
--          and the client resolves the aura from it at runtime
--   spell  the aura, where it has been measured. Independent of the item id,
--          so a wrong item cannot stop the warning from working
--   name   our English fallback, for a row the client has never looked up
--
-- Nothing here stores a duration. The aura carries its own, it is read out of
-- combat like everything else, and a number written here would be one more
-- thing to keep in step with a client that is still moving.
--
-- **The categories are mostly agreed rather than measured, and one of them is
-- not.** Two consumables in one category are assumed to displace each other,
-- which is what the filter on the page means by showing the best one you can
-- use. Where that assumption is wrong the page hides a row it should show, and
-- the fix is one line here.
--
-- The one that is measured: **a Scroll of Protection does not stack with an
-- Elixir of Minor Defense**, watched in game on 2026-09-20. So the protection
-- scrolls sit in Armor rather than in a category of their own.
--
-- The other four stat scroll lines followed that finding rather than a
-- measurement of their own. Strength, Agility, Stamina, Intellect and Spirit
-- each hold their scrolls beside their elixirs on the argument that one slot
-- per stat is one rule and not five, and it is the rule Vanilla is remembered
-- for. If a scroll turns out to stack with its elixir after all, that line
-- moves back out and nothing else changes.
--
-- Inside a category the order is by the level the item asks for, because that
-- is the order the filter walks to find the strongest one you can use. Level
-- is a proxy for strength rather than strength itself: a level 45 elixir can
-- beat a level 55 scroll, and the filter will still pick the scroll.
local ADDON, FP = ...
local L, N = FP.L, FP.N

-- ---------------------------------------------------------------------------
-- What goes on a weapon
--
-- One choice per hand across every block, so a category here is only a way of
-- keeping the list short enough to read.
--
-- Checked against the item database on 2026-09-20 after being written from
-- memory: twenty two of the twenty three guesses were right, and the one that
-- was wrong is instructive. Superior Mana Oil does not exist in Classic, it is
-- a Burning Crusade item, and it would have sat in the list for ever as a row
-- nobody could ever satisfy.
--
-- Weighted Consecrated Sharpening Stone came out the same evening, and this
-- time the client said so rather than a database: the row stayed dimmed and
-- its tooltip read "Retrieving item information", which is the client looking
-- and finding nothing. Existing in Classic and existing here are two
-- questions, and only the second one matters.
--
-- Blackfathom Sharpening Stone followed it out, and between them they make a
-- rule worth having: **what this build took from the later Classic seasons is
-- the runes, not the consumables.** Four items from those seasons have been
-- tried now and none of them is here. The next one is not worth adding until
-- somebody has seen it in game.
-- ---------------------------------------------------------------------------
FP.weaponCoatings = {
    {
        id    = "oil",
        label = L["Weapon Oil"],
        items = {
            { item = 23123,   name = "Blessed Wizard Oil" },
            { item = 20749,   name = "Brilliant Wizard Oil" },
            { item = 20748,   name = "Brilliant Mana Oil" },
            { item = 20750,   name = "Wizard Oil" },
            { item = 20747,   name = "Lesser Mana Oil" },
            { item = 20746,   name = "Lesser Wizard Oil" },
            { item = 20745,   name = "Minor Mana Oil" },
            { item = 20744,   name = "Minor Wizard Oil" },
            { item = 3829,    name = "Frost Oil" },
            { item = 3824,    name = "Shadow Oil" },
        },
    },

    {
        id    = "stone",
        label = L["Sharpening Stone"],
        items = {
            { item = 23122,   name = "Consecrated Sharpening Stone" },
            { item = 18262,   name = "Elemental Sharpening Stone" },
            { item = 12404,   name = "Dense Sharpening Stone" },
            { item = 7964,    name = "Solid Sharpening Stone" },
            { item = 2871,    name = "Heavy Sharpening Stone" },
            { item = 2863,    name = "Coarse Sharpening Stone" },
            { item = 2862,    name = "Rough Sharpening Stone" },
        },
    },

    {
        id    = "weightstone",
        label = L["Weightstone"],
        items = {
            { item = 12643,   name = "Dense Weightstone" },
            { item = 7965,    name = "Solid Weightstone" },
            { item = 3241,    name = "Heavy Weightstone" },
            { item = 3240,    name = "Coarse Weightstone" },
            { item = 3239,    name = "Rough Weightstone" },
        },
    },
}

-- ---------------------------------------------------------------------------
-- What you drink
--
-- Ordered by category, and inside a category **by how strong the effect is,
-- strongest first**. The page draws it exactly as written.
--
-- That replaced sorting by the level an item asks for, which was close enough
-- to be believable and wrong where it mattered: Elixir of Superior Defense
-- gives 450 armour and Scroll of Protection IV gives 240, and the scroll asks
-- for two levels more, so the weaker one sat on top. Level is a proxy for
-- strength and this is the thing itself.
--
-- The number in the comment after an entry is what its tooltip says, so the
-- order can be checked line by line rather than believed. Where an entry sits
-- below a smaller number, the comment says why. Where entries do
-- different things, and several categories here are like that, the order says
-- nothing and the comment on the category says so.
--
-- **Where the categories come from now.** Most of them were reasoned out and
-- then corrected by the owner's own tests. Since 2026-09-20 there is a better
-- source for the shape of the thing: WoWSims models Classic consumables as one
-- pick per slot, and its slots are exactly what a category here means. It
-- confirmed four groupings independently, three of which the owner had already
-- measured in game, and it found one nobody had noticed at all, which is that
-- alcohol is its own slot.
--
-- What it is not is an authority on **this build**. It describes Classic, and
-- the Dire Maul items it lists are gone from here for exactly that reason.
--
-- Two more things it cannot say, both worth knowing before reading a gap in it
-- as an answer:
--
--   **Every class shares one file.** Mage, Rogue, Shadow Priest and Warrior
--   add nothing of their own, so there is no second list to go and find
--   **There are no healer simulations**, so nothing a healer drinks is
--   modelled. A consumable missing from it may simply have had nobody to
--   model it for
--
-- **A category is a claim that its entries displace each other.** Nothing in
-- the code depends on it any more, now that the page sorts by level and
-- searches by name instead of filtering by category, but it is still what a
-- block tells a reader, so it is still worth getting right.
--
-- The nine under Blasted Lands and Zandalar are the owner's own information
-- and the only group here with a source better than reasoning: they are quest
-- rewards that do not stack with each other, and do not stack with the three
-- flasks a bijou buys either.
--
-- Added on 2026-09-20 from the Classic consumables guide, at the owner's
-- request. Potions were skipped on his instruction, and food with them: a food
-- buff is one row already, the generic one at the top.
--
-- **The Dire Maul consumables were added and taken straight back out.** The
-- guide lists R.O.I.D.S., Gizzard Gum and their three siblings among the
-- elixirs, and the item database agrees, but the owner plays this build and
-- they are world buffs here rather than something you carry, and WoW Forever
-- does not have them at all. A category made of items nobody can obtain is a
-- page full of rows that can never come true.
--
-- Worth keeping as a warning about the source: a Classic database describes
-- Classic, and this build is not it. What is in it is the owner's to say.
--
-- **What is still deliberately left out**, so the next person does not think
-- it was forgotten:
--
--   the utility elixirs, water breathing, water walking and the detect line.
--   Each is its own effect and would be a category of one, and none of them
--   is what the request was about
--   the healing, mana and protection potions, which are either instant or run
--   for seconds. The floor on the page is ten minutes, so they would never
--   produce a countdown anyway
--   the engineering trinkets, bandages, explosives and quest items the guide
--   lists beside them, which are not buffs at all
--
-- Each of those is one line to add once somebody wants it.
--
-- **The one generic entry.** Food is a single row rather than a hundred,
-- because only one food buff can sit on you at a time, so listing every meal
-- in the game would be a hundred switches for one slot. Asked for that way on
-- 2026-09-20.
--
-- It watches every food buff rather than one meal's, and how it knows a food
-- buff when it sees one is in the section right below. It says nothing at all
-- until it is ticked, and a ticked row warns about absence like every other.
--
-- It also covers food no table names. This build ships food of its own,
-- Skywall Souffle among it, and the row had it the moment it existed.
-- Measured the same day, and it settles the design: the Well Fed buff here is
-- spell 1249519, fifteen minutes, and **no item in the bags produces it** that
-- can be matched to it. The bags know the spell the food casts, not the buff
-- it leaves behind. A table keyed by item could never have found it.
--
-- The `icon` is that buff's own picture, measured with it. It is only used
-- when nothing is on the player, where there is no aura to take one from, and
-- a question mark there would say "broken" rather than "you have not eaten".
--
-- **It starts switched off like everything else, and since 2026-09-26 that is
-- a decision rather than a workaround.** Its food grants five percent more
-- experience while leveling, which was a good enough reason to warn a stranger
-- before it runs out, and that was the call for about an hour on 2026-09-20.
-- It was taken back because until build 70009 a cold start returned every
-- setting to its default, so an entry that started on could not be switched
-- off for longer than one session.
--
-- **Decided against the recommendation.** This comment used to promise that
-- the day the client remembered, `default = true` here would be the whole
-- change, and carrying that out was the recommendation when 70009 arrived. The
-- owner kept it off: a stranger who installs the addon is told nothing by this
-- page, and a ticked food row shows a grayed icon for as long as they have not
-- eaten. The machinery for a default of on is still in place and unused.
-- ---------------------------------------------------------------------------
--- How the food row knows a food buff.
--
-- **By its name, and by a short list**, the owner's choice on 2026-09-28. Until
-- then the row watched whatever timed buff nothing else accounted for and kept
-- a list of what it must never pick up. That list grew by one report at a time,
-- each a buff of ten minutes or more taken for a meal, which then silenced the
-- missing food icon: the Skyborne racial Elemental Blessing on 2026-09-22, and
-- on 2026-09-28 Energized, which the High Order Skyborne racial Read Ley Line
-- leaves at a ley line. Raid and boss buffs would have been next, in the
-- owner's words, so the question turned round: not what is not food, but what
-- is.
--
-- **Every aura the client calls Well Fed is food.** The name is the client's
-- own, read off one of the spells below, and it is only ever compared with the
-- names the client gives the auras on the player, so a client in another
-- language matches the same way. Thirty one spells carry the name in the
-- Wowhead Forever database, many of them this game's own additions in the
-- 12xxxxx and 13xxxxx ranges, so food it adds later is found without a line
-- here as long as it keeps the name. The first spell is the Classic one; the
-- second is the Skywall Souffle buff measured on this client, in case the first
-- ever goes.
FP.FOOD_NAME_SPELLS = { 19705, 1249519 }

-- **Food buffs with names of their own**, each looked up in the Wowhead Forever
-- database on 2026-09-28. Add one when a player reports a meal the row does not
-- see: that is the one mistake left, and it errs towards a warning rather than
-- towards silence.
local FOOD_OTHER_NAMES = {
    18192,   -- Increased Agility, Grilled Squid, 10 min
    18194,   -- Mana Regeneration, Nightfin Soup, 10 min
    22730,   -- Increased Intellect, Runn Tum Tuber Surprise, 10 min
    25661,   -- Increased Stamina, Dirge's Kickin' Chimaerok Chops, 15 min
    18125,   -- Blessed Sunfruit, 10 min
    18141,   -- Blessed Sunfruit Juice, 10 min
}

FP.foodIds = {}
for _, id in ipairs(FOOD_OTHER_NAMES) do FP.foodIds[id] = true end

FP.consumables = {
    {
        id    = "food",
        label = L["Food"],
        section = "Food",
        flat    = true,
        items = {
            -- `desc` is what hovering the row says. Every other row shows the
            -- item's own tooltip; this one has no item to show, and without a
            -- line of its own it said "nothing to look up", which is true and
            -- tells nobody what the row does.
            { generic = true, icon = 133943, name = L["Any Food Buff"],
              desc = L["Watches for a food buff, whichever food it came from: "
                  .. "warns when none is on you, and before the one you have "
                  .. "runs out."] },
        },
    },

    {
        id    = "strength",
        label = L["Strength"],
        section = "Consumables",
        items = {
            { item = 12451,   name = "Juju Power" },
            { item = 9206,    name = "Elixir of Giants" },
            { item = 13453,   name = "Elixir of Brute Force" },
            { item = 10310,   name = "Scroll of Strength IV" },
            { item = 4426,    name = "Scroll of Strength III" },
            { item = 2289,    name = "Scroll of Strength II" },
            { item = 3391,    name = "Elixir of Ogre's Strength" },
            { item = 954,     name = "Scroll of Strength" },
            { item = 2454,    spell = 2367,     name = "Elixir of Lion's Strength" },
        },
    },

    {
        id    = "agility",
        label = L["Agility"],
        section = "Consumables",
        items = {
            { item = 13452,   name = "Elixir of the Mongoose" },
            { item = 9187,    name = "Elixir of Greater Agility" },
            { item = 10309,   name = "Scroll of Agility IV" },
            { item = 8949,    name = "Elixir of Agility" },
            { item = 4425,    name = "Scroll of Agility III" },
            { item = 1477,    name = "Scroll of Agility II" },
            { item = 3390,    name = "Elixir of Lesser Agility" },
            { item = 3012,    name = "Scroll of Agility" },
            { item = 2457,    name = "Elixir of Minor Agility" },
        },
    },

    {
        id    = "armor",
        label = L["Armor"],
        section = "Consumables",
        items = {
            { item = 13445,   name = "Elixir of Superior Defense" },
            { item = 8951,    name = "Elixir of Greater Defense" },
            { item = 10305,   name = "Scroll of Protection IV" },
            { item = 4421,    name = "Scroll of Protection III" },
            { item = 3389,    name = "Elixir of Defense" },
            { item = 1478,    name = "Scroll of Protection II" },
            { item = 3013,    name = "Scroll of Protection" },
            { item = 5997,    spell = 673,      name = "Elixir of Minor Defense" },
        },
    },

    {
        id    = "stamina",
        label = L["Stamina"],
        section = "Consumables",
        items = {
            { item = 3825,    name = "Elixir of Fortitude" },
            { item = 2458,    name = "Elixir of Minor Fortitude" },
        },
    },

    {
        id    = "health",
        label = L["Health Regeneration"],
        section = "Consumables",
        items = {
            { item = 20004,   name = "Major Troll's Blood Potion" },
            { item = 3826,    name = "Mighty Troll's Blood Potion" },
            { item = 3388,    name = "Strong Troll's Blood Potion" },
            { item = 3382,    spell = 3219,     name = "Weak Troll's Blood Potion" },
        },
    },

    {
        id    = "mana",
        label = L["Mana Regeneration"],
        section = "Consumables",
        items = {
            { item = 20007,   name = "Mageblood Potion" },
        },
    },

    {
        id    = "spellpower",
        label = L["Spell Power"],
        section = "Consumables",
        items = {
            { item = 13454,   name = "Greater Arcane Elixir" },
            { item = 9155,    name = "Arcane Elixir" },
            { item = 217398,  name = "Lesser Arcane Elixir" },
            { item = 247754,  spell = 1245244,  name = "Minor Arcane Elixir" },
        },
    },

    {
        id    = "firepower",
        label = L["Fire Power"],
        section = "Consumables",
        items = {
            { item = 21546,   name = "Elixir of Greater Firepower" },
            { item = 6373,    name = "Elixir of Firepower" },
        },
    },

    {
        id    = "frostpower",
        label = L["Frost Power"],
        section = "Consumables",
        items = {
            { item = 17708,   name = "Elixir of Frost Power" },
        },
    },

    {
        id    = "shadowpower",
        label = L["Shadow Power"],
        section = "Consumables",
        items = {
            { item = 9264,    name = "Elixir of Shadow Power" },
        },
    },

    {
        id    = "resistance",
        label = L["Resistance"],
        section = "Consumables",
        items = {
            { item = 9088,    name = "Gift of Arthas" },
            { item = 3386,    name = "Elixir of Poison Resistance" },
        },
    },

    {
        id    = "blasted",
        label = L["Blasted Lands and Zandalar"],
        section = "Consumables",
        items = {
            { item = 20079,   name = "Spirit of Zanza" },
            { item = 20080,   name = "Sheen of Zanza" },
            { item = 20081,   name = "Swiftness of Zanza" },
            { item = 8410,    name = "R.O.I.D.S." },
            { item = 8412,    name = "Ground Scorpok Assay" },
            { item = 8411,    name = "Lung Juice Cocktail" },
            { item = 8423,    name = "Cerebral Cortex Compound" },
            { item = 8424,    name = "Gizzard Gum" },
            { item = 22133,   name = "Darnassus Gift Collection" },
        },
    },

    {
        id    = "attackPower",
        label = L["Attack Power"],
        section = "Consumables",
        items = {
            { item = 12460,   name = "Juju Might" },
            { item = 12820,   name = "Winterfall Firewater" },
        },
    },

    {
        id    = "juju",
        label = L["Juju"],
        section = "Consumables",
        items = {
            { item = 12450,   name = "Juju Flurry" },
            { item = 12455,   name = "Juju Ember" },
            { item = 12457,   name = "Juju Chill" },
        },
    },

    {
        id    = "hit",
        label = L["Hit Chance"],
        section = "Consumables",
        items = {
            { item = 22237,   name = "Dark Desire" },
            { item = 23327,   name = "Fire-toasted Bun" },
        },
    },

    {
        id    = "alcohol",
        label = L["Alcohol"],
        section = "Consumables",
        items = {
            { item = 21151,   name = "Rumsey Rum Black Label" },
            { item = 21114,   name = "Rumsey Rum Dark" },
            { item = 20709,   name = "Rumsey Rum Light" },
        },
    },

    {
        id    = "other",
        label = L["Other"],
        section = "Consumables",
        items = {
            { item = 8529,    name = "Noggenfogger Elixir" },
        },
    },

    {
        id    = "flask",
        label = L["Flask"],
        section = "Consumables",
        items = {
            { item = 13510,   name = "Flask of the Titans" },
            { item = 13511,   name = "Flask of Distilled Wisdom" },
            { item = 13512,   name = "Flask of Supreme Power" },
            { item = 13513,   name = "Flask of Chromatic Resistance" },
        },
    },

    {
        id    = "classStamina",
        label = L["Stamina"],
        section = N["Replaced by a Class Buff"],
        items = {
            { item = 10307,   name = "Scroll of Stamina IV" },
            { item = 4422,    name = "Scroll of Stamina III" },
            { item = 1711,    name = "Scroll of Stamina II" },
            { item = 1180,    name = "Scroll of Stamina" },
        },
    },

    {
        id    = "classIntellect",
        label = L["Intellect"],
        section = N["Replaced by a Class Buff"],
        items = {
            { item = 9179,    name = "Elixir of Greater Intellect" },
            { item = 10308,   name = "Scroll of Intellect IV" },
            { item = 4419,    name = "Scroll of Intellect III" },
            { item = 2290,    name = "Scroll of Intellect II" },
            { item = 3383,    name = "Elixir of Wisdom" },
            { item = 955,     name = "Scroll of Intellect" },
        },
    },

    {
        id    = "classSpirit",
        label = L["Spirit"],
        section = N["Replaced by a Class Buff"],
        items = {
            { item = 13447,   name = "Elixir of the Sages" },
            { item = 10306,   name = "Scroll of Spirit IV" },
            { item = 4424,    name = "Scroll of Spirit III" },
            { item = 1712,    name = "Scroll of Spirit II" },
            { item = 1181,    name = "Scroll of Spirit" },
        },
    },
}

--- Every entry, flattened, so a warning can find its way back to its row.
FP.weaponCoatingByItem = {}
for _, group in ipairs(FP.weaponCoatings) do
    for _, entry in ipairs(group.items) do
        entry.group = group.id
        FP.weaponCoatingByItem[entry.item] = entry
    end
end

FP.consumableByKey = {}
for _, group in ipairs(FP.consumables) do
    for _, entry in ipairs(group.items) do
        entry.group = group.id
        -- The key is the item where there is one and the spell otherwise, so
        -- an entry measured without its item is still addressable. Spells are
        -- prefixed, because an item id and a spell id are both plain numbers
        -- and nothing stops the same number being both.
        entry.key = entry.generic and ("g" .. group.id)
                 or entry.item and ("i" .. entry.item)
                 or ("s" .. entry.spell)
        FP.consumableByKey[entry.key] = entry
    end
end
