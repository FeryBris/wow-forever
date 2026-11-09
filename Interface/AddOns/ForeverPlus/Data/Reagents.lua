-- The reagents a class's spells take, and the poisons a Rogue makes.
--
-- For the buttons beside a merchant, gated with the owner on 2026-10-09 for
-- 0.9.1, and read out of the Wowhead Forever database the same day: every
-- spell below still takes its reagent there, every recipe its ingredients,
-- and every id resolved to the name written beside it. Classic's numbers,
-- which this game kept. `/fplus reagents` holds them against the client.
--
-- **Every reagent of the class**, the owner's answer, whether the spell that
-- takes it is learned or not. Hunters and Warriors take none. **A reagent no
-- merchant sells is left out**, his word the same evening, since a stepper
-- for it only took room on the page: Light Feathers, Fish Oil and Shiny Fish
-- Scales drop on WoW Forever by his report of 2026-10-07, and Blinding Powder
-- is made by the Rogue.
--
-- **But a spell whose ranks take different reagents shows only the reagent of
-- the highest rank learned**, the owner's word the same evening for the
-- Druid's seeds: Rebirth takes another seed at every rank, and Gift of the
-- Wild other berries. Such an entry lists its `ranks`, each with the spell,
-- the level it is trained at, and the reagent it takes; while no rank is
-- learned it shows nothing.
--
-- **And a Priest sees a reagent only for a spell learned**, his word right
-- after, with the care he asked for: the Holy Candle serves only the first
-- rank of Prayer of Fortitude, while Prayer of Shadow Protection takes a
-- Sacred Candle from level 56, and from 60 every group buff takes one. Such
-- an entry lists the `spells` that take it and shows once one of them is
-- learned, and `unless` names a spell whose learning makes it unneeded.
-- **Mages, Paladins, Shamans and Warlocks see everything**, his word as well,
-- and so does every class not named here. The spell ids come from the same database.
--
-- `stack` is the most one bag slot holds, out of the same database, and what
-- each target starts at: a full stack, his answer. **A lower rank starts
-- lower**, his word of 2026-10-10, since levelling often leaves it unused
-- before the next rank comes: five seeds for a Rebirth below the highest,
-- `lowerStart`, and half a stack for a poison below the highest,
-- `FP.POISON_LOWER_START`. The highest rank keeps the full stack, and Gift of
-- the Wild keeps it on every rank.

local ADDON, FP = ...

FP.CLASS_REAGENTS = {
    DRUID = {
        { stack = 20, lowerStart = 5, ranks = {         -- Rebirth
            { spell = 20484, level = 20, item = 17034 },   -- Maple Seed
            { spell = 20739, level = 30, item = 17035 },   -- Stranglethorn Seed
            { spell = 20742, level = 40, item = 17036 },   -- Ashwood Seed
            { spell = 20747, level = 50, item = 17037 },   -- Hornbeam Seed
            { spell = 20748, level = 60, item = 17038 },   -- Ironwood Seed
        } },
        { stack = 20, ranks = {                         -- Gift of the Wild
            { spell = 21849, level = 50, item = 17021 },   -- Wild Berries
            { spell = 21850, level = 60, item = 17026 },   -- Wild Thornroot
        } },
    },
    MAGE = {
        { item = 17031, stack = 10 },   -- Rune of Teleportation: the teleports, 20
        { item = 17032, stack = 10 },   -- Rune of Portals: the portals, 40
        { item = 17020, stack = 20 },   -- Arcane Powder: Arcane Brilliance, 56
    },
    PALADIN = {
        { item = 17033, stack = 5 },    -- Symbol of Divinity: Divine Intervention, 30
        { item = 21177, stack = 100 },  -- Symbol of Kings: the Greater Blessings
    },
    PRIEST = {
        { item = 17028, stack = 20,                          -- Holy Candle
          spells = { { spell = 21562, level = 48 } },        -- Prayer of Fortitude 1
          unless = { { spell = 21564, level = 60 } } },      -- not with rank 2
        { item = 17029, stack = 20,                          -- Sacred Candle
          spells = { { spell = 27683, level = 56 },          -- Prayer of Shadow Protection
                     { spell = 21564, level = 60 },          -- Prayer of Fortitude 2
                     { spell = 27681, level = 60 } } },      -- Prayer of Spirit
    },
    ROGUE = {
        { item = 5140, stack = 20 },    -- Flash Powder: Vanish, 22
    },
    SHAMAN = {
        { item = 17030, stack = 5 },    -- Ankh: Reincarnation, 30
    },
    WARLOCK = {
        { item = 5565, stack = 5 },     -- Infernal Stone: Inferno, 50
        { item = 16583, stack = 5 },    -- Demonic Figurine: Ritual of Doom, 60
    },
}

-- **Reagent Economy**, a talent of the Legacy Tree WoW Forever added: "Your
-- class abilities no longer require reagents purchaseable from vendors.", out
-- of the Wowhead Forever database on 2026-10-09. While it is active a reagent
-- button always asks first, with a red line saying so, the owner's answer the
-- same day; a poison's ingredients are a recipe's rather than an ability's
-- reagents and are left alone until somebody measures otherwise.
FP.REAGENT_ECONOMY = 1225503

-- The poisons, one entry per kind with its ranks from the lowest, each with
-- the recipe that makes it, the poison it makes, the level the recipe needs,
-- and what it takes, item id = count. A recipe makes one poison, and every
-- poison stacks to 20.
--
-- The ingredients: 2928 Dust of Decay, 2930 Essence of Pain, 5173 Deathweed,
-- 8923 Essence of Agony, 8924 Dust of Deterioration, and the vials 3371 Empty,
-- 3372 Leaded and 8925 Crystal.
FP.POISON_STACK = 20
FP.POISON_LOWER_START = 10   -- a rank below the highest, see the head of the file

FP.POISONS = {
    { key = "instant", ranks = {
        { recipe = 8681,  item = 6947,  level = 20, takes = { [2928] = 1, [3371] = 1 } },
        { recipe = 8687,  item = 6949,  level = 28, takes = { [2928] = 3, [3372] = 1 } },
        { recipe = 8691,  item = 6950,  level = 36, takes = { [8924] = 1, [3372] = 1 } },
        { recipe = 11341, item = 8926,  level = 44, takes = { [8924] = 2, [8925] = 1 } },
        { recipe = 11342, item = 8927,  level = 52, takes = { [8924] = 3, [8925] = 1 } },
        { recipe = 11343, item = 8928,  level = 60, takes = { [8924] = 4, [8925] = 1 } },
    } },
    { key = "deadly", ranks = {
        { recipe = 2835,  item = 2892,  level = 30, takes = { [5173] = 1, [3372] = 1 } },
        { recipe = 2837,  item = 2893,  level = 38, takes = { [5173] = 2, [3372] = 1 } },
        { recipe = 11357, item = 8984,  level = 46, takes = { [5173] = 3, [8925] = 1 } },
        { recipe = 11358, item = 8985,  level = 54, takes = { [5173] = 5, [8925] = 1 } },
        { recipe = 25347, item = 20844, level = 60, takes = { [5173] = 7, [8925] = 1 } },
    } },
    { key = "crippling", ranks = {
        { recipe = 3420,  item = 3775,  level = 20, takes = { [2930] = 1, [3371] = 1 } },
        { recipe = 3421,  item = 3776,  level = 50, takes = { [8923] = 3, [8925] = 1 } },
    } },
    { key = "mindNumbing", ranks = {
        { recipe = 5763,  item = 5237,  level = 24, takes = { [2928] = 1, [2930] = 1, [3371] = 1 } },
        { recipe = 8694,  item = 6951,  level = 38, takes = { [2928] = 4, [2930] = 4, [3372] = 1 } },
        { recipe = 11400, item = 9186,  level = 52, takes = { [8924] = 2, [8923] = 2, [8925] = 1 } },
    } },
    { key = "wound", ranks = {
        { recipe = 13220, item = 10918, level = 32, takes = { [2930] = 1, [5173] = 1, [3372] = 1 } },
        { recipe = 13228, item = 10920, level = 40, takes = { [2930] = 1, [5173] = 2, [3372] = 1 } },
        { recipe = 13229, item = 10921, level = 48, takes = { [8923] = 1, [5173] = 2, [8925] = 1 } },
        { recipe = 13230, item = 10922, level = 56, takes = { [8923] = 2, [5173] = 2, [8925] = 1 } },
    } },
}
