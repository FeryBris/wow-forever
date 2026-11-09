-- What skill a herb, a vein or a corpse asks for before it can be gathered.
--
-- The owner's own request of 2026-09-30, gated on 2026-10-03: a line of its
-- own in the tooltip, shown always, with a switch on the Tooltip page. See
-- *The skill a gathering node needs* in ROADMAP.md.
--
-- **A herb is known by the item it gives, because its tooltip carries
-- nothing else.** Measured by the owner on 2026-10-03 with
-- `/fplus tooltip node` over a Peacebloom: the world cursor's tooltip data
-- holds no guid, no entry and no typed line, only two lines of text of type 0,
-- the name and "Requires Herbalism". So the first plan, keying by the object
-- entry in a guid, could never have matched.
--
-- What is left is the name, and the locale rule forbids comparing it with
-- English. **It is compared with the name of the herb's item instead**, which
-- the client hands over in its own language from the item id: every herb in
-- this table is called exactly what it gives. Text the client wrote against
-- text the client wrote, the same allowance ErrorFilter lives on.
--
-- **Veins are matched differently**, since a vein is not called what it
-- gives, Copper Vein against Copper Ore: see the section on veins below.
--
-- The item ids and levels are Classic's and not checked against this build;
-- AGENTS.md records that Classic item ids have mapped to it so far. A herb
-- this game added is simply not in the table and gets no line.

local ADDON, FP = ...
local L = FP.L

-- The words on the line, marked for translation and translated where the line
-- is written, since this file loads before the language is known. Labels, and
-- never compared with anything the client writes.
FP.GATHER_SKILLS = {
    herb = L["Herbalism"],
    mine = L["Mining"],
    skin = L["Skinning"],
}

-- The item a herb gives, and the Herbalism it asks for.
FP.GATHER_HERBS = {
    [2447]  = 1,     -- Peacebloom
    [765]   = 1,     -- Silverleaf
    [2449]  = 15,    -- Earthroot
    [785]   = 50,    -- Mageroyal
    [2450]  = 70,    -- Briarthorn
    [3820]  = 85,    -- Stranglekelp
    [2453]  = 100,   -- Bruiseweed
    [3355]  = 115,   -- Wild Steelbloom
    [3369]  = 120,   -- Grave Moss
    [3356]  = 125,   -- Kingsblood
    [3357]  = 150,   -- Liferoot
    [3818]  = 160,   -- Fadeleaf
    [3821]  = 170,   -- Goldthorn
    [3358]  = 185,   -- Khadgar's Whisker
    [3819]  = 195,   -- Wintersbite
    [4625]  = 205,   -- Firebloom
    [8831]  = 210,   -- Purple Lotus
    [8836]  = 220,   -- Arthas' Tears
    [8838]  = 230,   -- Sungrass
    [8839]  = 235,   -- Blindweed
    [8845]  = 245,   -- Ghost Mushroom
    [8846]  = 250,   -- Gromsblood
    [13464] = 260,   -- Golden Sansam
    [13463] = 270,   -- Dreamfoil
    [13465] = 280,   -- Mountain Silversage
    [13466] = 285,   -- Plaguebloom
    [13467] = 290,   -- Icecap
    [13468] = 300,   -- Black Lotus
}

-- ---------------------------------------------------------------------------
-- Veins
--
-- Back on 2026-10-03, the owner's decision the same evening they were left
-- out, and in the combined form he picked. A vein is not called what it
-- gives, but it **holds** the metal of its ore: Copper Vein and Copper Ore,
-- Kupferader and Kupfererz, and WoW Forever's own Poor Copper Vein in its
-- starting zones, the owner's report of 2026-10-04. So a vein is matched
-- against the client's own ore names by FP:ClosestName: the ore whose name
-- the vein holds the largest share of, more than half of it, which compares
-- client text with client text and keeps the locale rule. It began as the
-- longest shared beginning, which Poor Copper Vein defeated.
--
-- **Nine veins have no ore of their own in the table**, Small and Rich
-- Thorium, Hakkari Thorium and the Ooze Covered ones, or would match the
-- wrong one. Those are listed by their English
-- name below, **a deliberate exception to the locale rule** that the owner
-- chose over leaving them out: on any other client they get no line, and
-- German comes with phase 7.7.
--
-- The level of a vein is the level of its ore here, except Rich Thorium,
-- which is in the English list. Classic's numbers, unchecked on this build.
-- ---------------------------------------------------------------------------

-- How the client is asked for a profession's name in its own language, used
-- to tell a vein from an Iron Gate: only an object whose second line names
-- Mining is a vein, and a herb that is not called what it gives needs its
-- second line to name Herbalism. The skill lines are Classic's and go to
-- C_TradeSkillUI.GetTradeSkillDisplayName; the spell is Apprentice Mining,
-- whose name is the profession's, measured on 2026-10-04.
FP.GATHER_SKILL_LINES = { herb = 182, mine = 186, skin = 393 }
FP.GATHER_SKILL_SPELLS = { mine = 2575 }

-- The ore a vein gives, and the Mining it asks for.
FP.GATHER_ORES = {
    [2770]  = 1,     -- Copper Ore
    [2771]  = 65,    -- Tin Ore
    [3340]  = 65,    -- Incendicite Ore
    [2775]  = 75,    -- Silver Ore
    [4278]  = 75,    -- Lesser Bloodstone Ore
    [2772]  = 125,   -- Iron Ore
    [5833]  = 150,   -- Indurium Ore
    [2776]  = 155,   -- Gold Ore
    [3858]  = 175,   -- Mithril Ore
    [7911]  = 230,   -- Truesilver Ore
    [11370] = 230,   -- Dark Iron Ore
}

-- The veins no ore name begins, by their English name. See above.
FP.GATHER_VEINS_ENGLISH = {
    ["Small Thorium Vein"]              = 245,
    ["Rich Thorium Vein"]               = 275,
    ["Hakkari Thorium Vein"]            = 275,
    ["Ooze Covered Silver Vein"]        = 75,
    ["Ooze Covered Gold Vein"]          = 155,
    ["Ooze Covered Mithril Deposit"]    = 175,
    ["Ooze Covered Truesilver Deposit"] = 230,
    ["Ooze Covered Thorium Vein"]       = 245,
    ["Ooze Covered Rich Thorium Vein"]  = 275,
}

--- The skill a corpse of this level asks for: the Classic rule, the same
--- for skinning, and for the creatures gathered with Herbalism or Mining.
--
-- 1 up to level 10, ten a level from 11 to 20, five a level above. Whether
-- WoW Forever keeps the rule is not known. nil for a level that cannot be
-- used, which includes the -1 of a boss.
function FP:CorpseSkill(level)
    if type(level) ~= "number" or level < 1 then return nil end
    if level <= 10 then return 1 end
    if level < 20 then return (level - 10) * 10 end
    return level * 5
end
