local ADDON, ns = ...
local L = ns.L

ns.version   = "0.23.33"
ns.TRANCE_ID = 17941          -- Shadow Trance (Nightfall talent), Classic ID
ns.DURATION  = 10             -- seconds, Classic value
ns.SB_IDS    = { 686, 695, 705, 1088, 1106, 7641, 11659, 11660, 11661, 25307 } -- Shadow Bolt ranks
ns.SB_ICON   = "Interface\\Icons\\Spell_Shadow_ShadowBolt"

local TRANCE_ID = ns.TRANCE_ID
local GetTime, pcall, type = GetTime, pcall, type

local SB = {}
for _, id in ipairs(ns.SB_IDS) do SB[id] = true end

----------------------------------------------------------------------
-- The procs Shadowflare knows, by class. Each one gets its own alert and its own settings.
--   spell : the proc's own spell (its name is shown), cast : the spell it speeds up (its icon)
--   gameAlert : the game has its own proc alert for it (sound choice "the game's")
-- Forever hides buffs from addons in combat (checked in game, 10 October 2026): procs are
-- found through the cast time of the spell they speed up.
----------------------------------------------------------------------
ns.SOULFIRE_IDS = { 6353, 17924 }                                   -- Soul Fire ranks
ns.OVERPOWER_IDS = { 7384, 7887, 11584, 11585 }                     -- Overpower ranks
ns.REVENGE_IDS   = { 6572, 6574, 7379, 11600, 11601, 25288 }        -- Revenge ranks
local IMMOLATE_IDS = { 348, 707, 1094, 2941, 11665, 11667, 11668, 25309 }
local SEARING_IDS  = { 5676, 17919, 17920, 17921, 17922, 17923 }    -- Searing Pain ranks
-- Other classes (usual spell ranks; Forever may add or change some: unchecked in game).
-- Lowest rank first: the highest one the player knows is used.
local R = {
    frostbolt  = { 116, 205, 837, 7322, 8406, 8407, 8408, 10179, 10180, 10181, 25304 },
    fireball   = { 133, 143, 145, 3140, 8400, 8401, 8402, 10148, 10149, 10150, 10151, 25306 },
    missiles   = { 5143, 5144, 5145, 8416, 8417, 10211, 10212, 25345 },
    pyroblast  = { 11366, 12505, 12522, 12523, 12524, 12525, 12526, 18809 },
    wrath      = { 5176, 5177, 5178, 5179, 5180, 6780, 8905, 9912 },
    starfire   = { 2912, 8949, 8950, 8951, 9875, 9876, 25298 },
    touch      = { 5185, 5186, 5187, 5188, 5189, 6778, 8903, 9758, 9888, 9889, 25297 },
    claw       = { 1082, 3029, 5201, 9849, 9850 },
    shred      = { 5221, 6800, 8992, 9829, 9830 },
    maul       = { 6807, 6808, 6809, 8972, 9745, 9880, 9881 },
    bolt       = { 403, 529, 548, 915, 943, 6041, 10391, 10392, 15207, 15208 },
    chain      = { 421, 930, 2860, 10605 },
    holylight  = { 635, 639, 647, 1026, 1042, 3472, 10328, 10329, 25292 },
    flash      = { 19750, 19939, 19940, 19941, 19942, 19943 },
    hammer     = { 24275, 24274, 24239 },
    nova       = { 15237, 15430, 15431, 27799, 27800, 27801 },
    smite      = { 585, 591, 598, 984, 1004, 6060, 10933, 10934 },
    lesserheal = { 2050, 2052, 2053 },
    riposte    = { 14251 },
    ambush     = { 8676, 8724, 8725, 11267, 11268, 11269 },
    mongoose   = { 1495, 14269, 14270, 14271 },
    counter    = { 19306, 20909, 20910 },
    execute    = { 5308, 20658, 20660, 20661, 20662 },
    victory    = { 34428, 402927 },   -- 402927: Forever (given by Ben, 14 October 2026)
    shieldblock = { 2565 },
    -- Conflagrate: Forever's own number last (read in game by Ben, 23 October 2026)
    conflag    = { 17962, 18930, 18931, 18932, 1293817 },   -- Classic number; Forever: 5 s cooldown, 7 s, 2 blocks (unchecked in game)
}
local DECIM_RENEW = {}
for _, id in ipairs(ns.SB_IDS) do DECIM_RENEW[#DECIM_RENEW + 1] = id end
for _, id in ipairs(SEARING_IDS) do DECIM_RENEW[#DECIM_RENEW + 1] = id end

ns.PROCS = {
    { key = "trance", class = "WARLOCK", spec = "affliction", spell = TRANCE_ID, dur = 10, mode = "trance",
      cast = ns.SB_IDS, icon = ns.SB_ICON, gameAlert = true, label = "L_trance",
      defaults = { color = "violet", soundChoice = "game", y = 120 } },
    { key = "decimation", class = "WARLOCK", spec = "demonology", spell = 440870, dur = 10,
      buffIds = { 440873 }, nameFromSpell = true, preset = true,
      mode = "faster", refs = { ns.SB_IDS, IMMOLATE_IDS }, renew = DECIM_RENEW,
      cast = ns.SOULFIRE_IDS, icon = "Interface\\Icons\\Spell_Fire_Fireball02", label = "L_decimation",
      defaults = { color = "fire", soundChoice = "power", y = 230 } },
    -- Conflagrate (0.23.16, Reddit idea): Destruction talent (row 4, level 25). Checked in game by
    -- Ben (23 October 2026, spell 1293817): the game says "usable" only while his Immolate is on
    -- the target, and "no" once Conflagrate has used it up. Shadow and Flame at 5/5 keeps Immolate:
    -- the alert then comes back at the end of each cooldown (10 s, checked in the tooltip by Ben).
    -- Off by default (asked of Ben): not every warlock takes the talent.
    { key = "conflagrate", class = "WARLOCK", spec = "destruction", spell = 1293817, mode = "usable", noPower = false, onTarget = true,
      cd = 10, holdCd = true, noTimer = true, dur = 5, combatOnly = true,
      cast = R.conflag, icon = "Interface\\Icons\\Spell_Fire_Fireball", label = "L_conflagrate",
      defaults = { color = "fire", soundChoice = "power", y = 340, enabled = false } },
    -- Warrior: abilities that can only be used for a few seconds after an event.
    -- "usable": shown while the game says the spell can be used, or could be with more rage.
    -- holdCd: after a cast, hidden for the whole cooldown. The game says "usable" even while
    -- the spell is on cooldown, and hides cooldowns in combat (reported on Reddit for Victory
    -- Rush, 16 October 2026). Cooldowns checked on the Forever tooltips (Ben, 16 October):
    -- Overpower 5 s, Victory Rush 30 s, Riposte 6 s, Mongoose Bite 5 s, Counterattack 5 s.
    -- Revenge has no cooldown in Forever: it keeps its old rule (hidden after a cast until the
    -- window closes, at most 5 s), confirmed in game on 14 October.
    -- combatOnly (0.19.0): opened by a dodge, block or parry, so only in combat. Out of combat
    -- the game could say "usable, short of rage" for a moment when the window closed, and the
    -- alert came back for about half a second (seen by Ben on Revenge, 20 October 2026).
    -- 0.23.27 (Reddit and CurseForge, Ben): also in another stance, off by default. The game says
    -- "not usable" outside the right stance, so Shadowflare follows the trigger itself there: the
    -- game's hit feed (UNIT_COMBAT) tells a dodge, a parry or a block in combat (only its amount
    -- is secret in Forever's API docs). Stance numbers: the usual ones, unchecked in Forever.
    { key = "overpower", class = "WARRIOR", spec = "arms", spell = 7384, dur = 5, cd = 5, holdCd = true, mode = "usable", combatOnly = true,
      stance = 2457, stanceTrack = "targetDodge",   -- Battle Stance; the target dodged
      cast = ns.OVERPOWER_IDS, icon = "Interface\\Icons\\Ability_MeleeDamage", label = "L_overpower",
      defaults = { color = "blood", style = "blz449493", soundChoice = "power", y = 120 } },
    { key = "revenge", class = "WARRIOR", spec = "protection", spell = 6572, dur = 5, cd = 5, mode = "usable", combatOnly = true,
      stance = 71, stanceTrack = "avoided",         -- Defensive Stance; you blocked, dodged or parried
      cast = ns.REVENGE_IDS, icon = "Interface\\Icons\\Ability_Warrior_Revenge", label = "L_revenge",
      defaults = { color = "fire", style = "blz449494", soundChoice = "power", y = 230 } },
    -- Shield Block (0.23.15, asked on CurseForge): shown when it can be pressed again, to keep
    -- it up. Follows its cooldown (5 s, nothing resets it in Forever as far as we know), only
    -- with enough rage, a shield and Defensive Stance (the game's own "usable"), in combat.
    -- Image only by default: it comes back every 5 s while tanking (decided by Ben).
    { key = "shieldblock", class = "WARRIOR", spec = "protection", spell = 2565, mode = "usable", noPower = false,
      cd = 5, holdCd = true, noTimer = true, dur = 5, combatOnly = true,
      cast = R.shieldblock, icon = "Interface\\Icons\\Ability_Defend", label = "L_shieldblock",
      defaults = { color = "frost", soundChoice = "none", y = 120 } },
    -- Execute: a state (target below 20%) rather than a proc. Shown only while it can
    -- really be cast (enough rage, target low enough), never hidden by its own cast.
    { key = "execute", class = "WARRIOR", spec = "any", spell = 5308, mode = "usable", noPower = false, onTarget = true,
      hideOnCast = false, noTimer = true, dur = 5, cast = R.execute,
      icon = "Interface\\Icons\\INV_Sword_48", label = "L_execute",
      defaults = { color = "blood", soundChoice = "power", y = -150 } },
    -- Victory Rush (Forever): usable within 20 s after a kill, 30 s cooldown
    -- 0.23.5: shown by the game from its buff "Victorious" (402975, seen by Ben with /flare
    -- buffs): the game's time left follows every kill that renews it. The buff stays during the
    -- cooldown: the frame is held back then (gameHold).
    { key = "victoryrush", class = "WARRIOR", spec = "any", spell = 402927, mode = "usable", dur = 20, cd = 30, holdCd = true,
      buffIds = { 402975 }, gameHold = true, preset = true,
      cast = R.victory, icon = "Interface\\Icons\\Ability_Warrior_Devastate", label = "L_victoryrush",
      -- A kill often ends the fight: shown out of combat too (0.22.0)
      defaults = { color = "fire", soundChoice = "power", y = 340, onlyCombat = false } },

    -- Mage. Clearcasting makes every spell free; Missile Barrage only Arcane Missiles
    -- (so it counts only when Frostbolt and Fireball still cost their usual mana).
    -- Missile Barrage is a row 1 talent in Forever (15 Oct 2026): any mage can have it.
    { key = "clearcasting", class = "MAGE", spec = "arcane", spell = 12536, mode = "free", free = 0, dur = 15,
      buffIds = { 12536 }, preset = true,
      -- 0.23.28 (Blizzard's notes, November 3): Arcane Missiles no longer uses Clearcasting up
      -- while Missile Barrage is up. Still free after Missiles is not a new Clearcasting.
      notSpentBy = R.missiles,
      watch = { R.frostbolt, R.fireball }, icon = "Interface\\Icons\\Spell_Shadow_ManaBurn", keepIcon = true, label = "L_clearcasting",
      defaults = { color = "frost", soundChoice = "power", y = 120 } },
    { key = "missilebarrage", class = "MAGE", spec = "any", spell = 400588, mode = "free", free = 0, dur = 15,
      buffIds = { 400589 }, nameFromSpell = true, preset = true,
      watch = { R.missiles }, unless = "clearcasting", icon = "Interface\\Icons\\Spell_Nature_StarFall", label = "L_missilebarrage",
      defaults = { color = "violet", soundChoice = "power", y = 230 } },
    -- Heating Up (Forever, renamed from Hot Streak on 1 Oct 2026; tooltip checked in game by
    -- Ben, 16 Oct): each critical strike takes 25% off the next Pyroblast's cast time, up to
    -- 3 stacks, 20 s. Never instant. Like every stacking proc, the alert comes at the most
    -- stacks (decided by Ben, 16 Oct): Pyroblast compared with Fireball (haste set aside),
    -- shown below 0.46 of its usual ratio. 3 stacks give 0.25 (or 0.42 if the stacks
    -- multiply), 2 stacks 0.5 (or 0.56): the line sits between the two either way.
    -- Presence of Mind makes Pyroblast instant (cast time 0): never counted.
    -- The key stays "hotstreak" so the players' settings are kept.
    -- From 0.18.0 the alert can also show from 1 or 2 stacks (setting "Show from"): the
    -- ratio counts them (1 stack 0.75, 2 stacks 0.5 or 0.56, 3 stacks 0.25 or 0.42).
    { key = "hotstreak", class = "MAGE", spec = "fire", spell = 400624, mode = "faster", threshold = 0.46, dur = 20,
      buffIds = { 400625 }, nameFromSpell = true, preset = true, stacks = 3, stackAt = { 0.88, 0.66 },
      cast = R.pyroblast, refs = { R.fireball }, icon = "Interface\\Icons\\Spell_Fire_Fireball02", label = "L_hotstreak",
      defaults = { color = "fire", soundChoice = "power", y = 120, stackLook = "fillup" } },
    -- Fingers of Frost (Forever talent, Frost row 5): Chill effects can make the next 2 spells
    -- treat the target as Frozen, 15 s. Nothing an addon can read changes (cast time, cost,
    -- usable), but the game plays its own proc alert sound (seen by Ben, 16 Oct 2026): the
    -- alert follows the game's proc alert event, as Shadow Trance does ("overlay" mode).
    -- Unchecked in game: which spell number the event carries (the buff 400670 per another
    -- addon's public code, or the talent 400647), so both are accepted, and /flare debug
    -- prints every game alert. Its sound stays the game's (gameSoundOnly): turning the game's
    -- alert off might also stop the event.
    -- 0.18.2: a second way, asked by Ben after a player saw no alert in combat (19 Oct 2026):
    -- once its buff has been on the player out of combat, the game shows the alert itself
    -- (AuraShow.lua), with the charges left (2, then 1), the same brightness at both
    -- (noDim, Ben's choice), and gone when the buff goes. The game's alert signal above
    -- still works as before. The buff may not count its charges (stacksOptional): then one
    -- frame for the whole buff, without a number. Shadowflare's own alert can't know the
    -- charges (noOwnCount): no number there.
    { key = "fingers", class = "MAGE", spec = "frost", spell = 400670, mode = "overlay", dur = 15,
      overlayIds = { 400670, 400647, 44544 }, gameAlert = true, gameSoundOnly = true,
      buffIds = { 400670 }, nameFromSpell = true, preset = true, stacks = 2, stacksOptional = true, noDim = true, noOwnCount = true,
      icon = "Interface\\Icons\\Ability_Mage_WintersGrasp", label = "L_fingers",
      defaults = { color = "frost", style = "blz449489", anim = "impactpulse", soundChoice = "game", y = 340, fromStacks = 1, stackLook = "dots" } },

    -- Druid
    -- Omen of Clarity is a baseline spell of every druid in Forever (level 20)
    { key = "omen", class = "DRUID", spec = "any", spell = 16864, mode = "free", free = 0, dur = 15,
      buffIds = { 16870 }, preset = true,
      watch = { R.wrath, R.touch, R.claw, R.shred, R.maul }, icon = "Interface\\Icons\\Spell_Shadow_ManaBurn", keepIcon = true, label = "L_omen",
      defaults = { color = "frost", soundChoice = "power", y = 120 } },
    { key = "eclipse", class = "DRUID", spec = "balance", spell = 409813,   -- Forever (Wowhead, given by Ben)
      mode = "faster", selfCheck = true, fullCut = 1.75, dur = 15, renew = R.wrath,
      buffIds = { 408255 }, nameFromSpell = true, preset = true, stacks = 4, perCharge = 0.5,
      cast = R.starfire, refs = { R.wrath }, icon = "Interface\\Icons\\Spell_Arcane_StarFire", label = "L_eclipse",
      defaults = { color = "frost", soundChoice = "power", y = 230, stackLook = "fillup" } },

    -- Shaman
    -- Below 5 stacks (0.18.0), the stacks are counted from Lightning Bolt's mana cost (20% off
    -- per stack, readable in combat), or from its cast time when the cost reads 0 (Clearcasting).
    { key = "maelstrom", class = "SHAMAN", spec = "enhancement", spell = 408498, mode = "instant", dur = 30,
      buffIds = { 408505 }, nameFromSpell = true, preset = true, stacks = 5, perStack = 0.2,
      cast = R.bolt, icon = "Interface\\Icons\\Spell_Nature_Lightning", label = "L_maelstrom",
      defaults = { color = "frost", soundChoice = "power", y = 120, stackLook = "dots" } },
    -- Elemental Focus (Forever): the next damage spell costs no mana at all. Maelstrom
    -- Weapon also cuts Lightning Bolt's cost (20% a stack), and makes it free and instant
    -- at 5 stacks: a Lightning Bolt with no cast time is not counted (skipInstant).
    { key = "elemfocus", class = "SHAMAN", spec = "elemental", spell = 16164, mode = "free", free = 0, dur = 15,
      buffIds = { 16246 }, preset = true,
      skipInstant = true, watch = { R.bolt, R.chain }, icon = "Interface\\Icons\\Spell_Shadow_ManaBurn", keepIcon = true, label = "L_elemfocus",
      defaults = { color = "frost", soundChoice = "power", y = 230 } },

    -- Paladin. Hammer of Wrath: a state (target below 20%), shown only while it can really
    -- be cast; after a cast it stays hidden during its cooldown.
    -- Infusion of Light (Forever, rank 2): a critical Holy Shock or Flash of Light takes 1 s
    -- (0.5 s at rank 1) off the next Holy Light within 15 s. Flash of Light is not sped up:
    -- it is the reference, so haste does not count.
    { key = "infusion", class = "PALADIN", spec = "holy", spell = 426065, mode = "faster", selfCheck = true, dur = 15,
      nameFromSpell = true,
      cast = R.holylight, refs = { R.flash }, icon = "Interface\\Icons\\Spell_Holy_HolyBolt", label = "L_infusion",
      defaults = { color = "fire", soundChoice = "power", y = 120 } },
    { key = "hammer", class = "PALADIN", spec = "any", spell = 24275, mode = "usable", noPower = false, cd = 6, holdCd = true, onTarget = true,
      noTimer = true, dur = 5, cast = R.hammer, icon = "Interface\\Icons\\Ability_ThunderClap", label = "L_hammer",
      defaults = { color = "fire", soundChoice = "power", y = 230 } },

    -- Priest. Searing Light (Forever talent): Holy Fire's periodic damage can make the
    -- next Holy Nova cost no mana. Inner Focus makes the next spell free too, whichever it
    -- is: when Smite or Lesser Heal is free as well, it is Inner Focus (others).
    { key = "searinglight", class = "PRIEST", spec = "holy", mode = "free", free = 0, dur = 15,
      nameFromLabel = true,
      watch = { R.nova }, others = { R.smite, R.lesserheal }, icon = "Interface\\Icons\\Spell_Holy_HolyNova", label = "L_searinglight",
      defaults = { color = "fire", soundChoice = "power", y = 120 } },

    -- Rogue. Ambush usable out of stealth (in stealth it always is: not counted).
    { key = "riposte", class = "ROGUE", spec = "combat", spell = 14251, mode = "usable", cd = 6, holdCd = true, dur = 5, combatOnly = true,
      cast = R.riposte, icon = "Interface\\Icons\\Ability_Warrior_Challange", label = "L_riposte",
      defaults = { color = "blood", soundChoice = "power", y = 120 } },
    -- 0.23.26 (Blizzard's notes, November 2): Cutthroat is removed. Ghostly Strike (Subtlety row 4)
    -- now makes the next Ambush or Garrote within 7 s not need Stealth: the same alert, renamed,
    -- 7 s. No buff number (Cutthroat's no longer exists, and waiting for it hid the alert): it
    -- follows "Ambush usable out of stealth" only. The key stays "cutthroat" (players' settings).
    -- Ghostly Strike 14278: the usual number, unchecked in Forever (its name shows if it exists).
    { key = "cutthroat", class = "ROGUE", spec = "subtlety", spell = 14278, mode = "usable", notStealthed = true, dur = 7,
      cast = R.ambush, icon = "Interface\\Icons\\Ability_Rogue_Ambush", label = "L_cutthroat",
      defaults = { color = "shadow", soundChoice = "power", y = 230 } },
    -- Remorseless Attacks (Assassination row 1, client data): after a kill, +40% critical strike
    -- chance on the next Sinister Strike, Backstab, Ambush, Mutilate or Ghostly Strike, 20 s.
    -- Nothing an addon can read changes: only the game can show it ("aura" mode, AuraShow.lua),
    -- once the buff has been seen out of combat. No sound. Buff numbers 14143 / 14149 and its
    -- name "Remorseless" are the usual ones (unchecked in Forever); found by name otherwise.
    { key = "remorseless", class = "ROGUE", spec = "assassination", spell = 14144, mode = "aura", dur = 20,
      buffIds = { 14143, 14149 }, nameFromSpell = true, icon = "Interface\\Icons\\Ability_FiegnDead",
      -- 0.23.15 (Reddit): it comes from a kill, which often ends the fight: shown out of combat
      -- too, as Victory Rush (it went away while looting)
      label = "L_remorseless", defaults = { color = "blood", y = 340, onlyCombat = false } },

    -- Hunter
    { key = "mongoose", class = "HUNTER", spec = "any", spell = 1495, mode = "usable", cd = 5, holdCd = true, dur = 5, combatOnly = true,
      cast = R.mongoose, icon = "Interface\\Icons\\Ability_Hunter_SwiftStrike", label = "L_mongoose",
      defaults = { color = "fel", soundChoice = "power", y = 120 } },
    { key = "counterattack", class = "HUNTER", spec = "survival", spell = 19306, mode = "usable", cd = 5, holdCd = true, dur = 5, combatOnly = true,
      cast = R.counter, icon = "Interface\\Icons\\Ability_Warrior_Challange", label = "L_counterattack",
      defaults = { color = "blood", soundChoice = "power", y = 230 } },
    -- Rapid Killing (Marksmanship row 3, talent 415405 in the client data): after a kill (or a
    -- death under Serpent Sting), the next Shot deals 20% more damage, 20 s. "aura" mode like
    -- Remorseless Attacks: shown by the game only, no sound. Buff found by its name, or by the
    -- Burning Crusade numbers 35098 / 35099 (unchecked in Forever).
    { key = "rapidkilling", class = "HUNTER", spec = "marksmanship", spell = 415405, mode = "aura", dur = 20,
      -- 0.23.21: 35098 / 35099 (the usual numbers) don't exist in Forever; its client has 415405
      -- (the talent), 415407 and 415817 named "Rapid Killing" (Forever spell data)
      buffIds = { 415407, 415817 }, nameFromSpell = true, icon = "Interface\\Icons\\Ability_Hunter_RapidKilling",
      label = "L_rapidkilling", defaults = { color = "fel", y = 340 } },
    -- Deadly Aspects (Beast Mastery row 1, talent 19552 in the Forever data): with Aspect of the
    -- Hawk, Auto Shot can give "Quick Shots"; with Aspect of the Beast, melee attacks can give
    -- "Quick Strikes": +30% attack speed, 12 s. Two buffs: both are learned (multiBuff) and the
    -- game's frame shows for either. 6150 is the usual Quick Shots number (unchecked in Forever);
    -- otherwise found by name (English names only: the French ones are unknown).
    { key = "deadlyaspects", class = "HUNTER", spec = "beastmastery", spell = 19552, mode = "aura", dur = 12,
      buffIds = { 6150 }, buffNames = { "Quick Shots", "Quick Strikes" }, multiBuff = true,
      icon = "Interface\\Icons\\Spell_Nature_RavenForm", label = "L_deadlyaspects",
      defaults = { color = "fel", y = -150 } },

    -- Paladin, more (0.19.0), shown by the game only, no sound.
    -- Redoubt (Protection row 1, talent 20127): higher block chance, 10 s or 5 blocks. Buff 20128
    -- (Redoubt) in the Forever data, other ranks' numbers from Classic.
    { key = "redoubt", class = "PALADIN", spec = "protection", spell = 20127, mode = "aura", dur = 10,
      buffIds = { 20128, 20131, 20132, 20133, 20134 }, nameFromSpell = true,
      icon = "Interface\\Icons\\Ability_Defend", label = "L_redoubt", defaults = { color = "frost", y = 340 } },
    -- Vengeance (Retribution row 5, talent 20049): more damage for 30 s after a crit, up to 3 stacks.
    -- Not the warrior's Revenge (called "Vengeance" in French): its own key, "vengeance", and only
    -- for paladins, so the two never meet (buffs are learned for the player's own class only).
    -- 0.23.26 (Blizzard's notes, November 2): up to 5 stacks (was 3), needs Seal of Command
    { key = "vengeance", class = "PALADIN", spec = "retribution", spell = 20049, mode = "aura", dur = 30,
      buffIds = { 20050, 20052, 20053, 20054, 20055 }, nameFromSpell = true, stacks = 5,
      icon = "Interface\\Icons\\Ability_Racial_Avatar", label = "L_vengeance", defaults = { color = "fire", y = -150, stackLook = "dim" } },

    -- Priest. Martyrdom (Discipline row 2, talent 14531): Focused Casting for 6 s after a critical
    -- hit taken. The buff is "Focused Casting" (27828 in the Forever data, 6 s), not "Martyrdom":
    -- found by that number, or by its name read from it.
    { key = "martyrdom", class = "PRIEST", spec = "discipline", spell = 14531, mode = "aura", dur = 6,
      buffIds = { 27828, 14743 }, icon = "Interface\\Icons\\Spell_Nature_Tranquility", label = "L_martyrdom",
      defaults = { color = "frost", y = 230 } },

    -- Paladin. Reckoning (talent 20177, "Rétribution" in French; asked on Reddit): after a block
    -- or a critical hit taken, an extra attack is stored, up to 4. The talent itself is hidden,
    -- but the stored attacks are a buff with stacks and no end time (seen in game, Oct 20).
    -- Shown by the game per stack, no sound. noEnd: a buff with no end time is accepted for it.
    -- 20178 is the usual buff number (unchecked in Forever); found by the talent's name otherwise.
    { key = "reckoning", class = "PALADIN", spec = "protection", spell = 20177, mode = "aura", dur = 15,
      noTimer = true, noEnd = true, buffIds = { 20178 }, nameFromSpell = true, stacks = 4,
      icon = "Interface\\Icons\\Spell_Holy_BlessingOfStrength", label = "L_reckoning",
      defaults = { color = "blood", y = 230, stackLook = "dots" } },

    -- Druid. Nature's Grace (Balance tier 5, 1 rank, Forever text): a non-periodic spell crit
    -- gives 10% faster casting and a 10% shorter global cooldown for 3 s. Shown by the game only,
    -- no sound. 16880 / 16886 are the usual talent and buff numbers (16886 seen in another addon's
    -- public Forever code); found by name otherwise.
    { key = "naturesgrace", class = "DRUID", spec = "balance", spell = 16880, mode = "aura", dur = 3,
      buffIds = { 16886 }, nameFromSpell = true, nameFromLabel = true,
      icon = "Interface\\Icons\\Spell_Nature_NaturesBlessing", label = "L_naturesgrace",
      defaults = { color = "fel", y = 340 } },

    -- Default look below the maximum (0.21.0, chosen per proc; players can change it): a fill for
-- the procs that build up to one spell (Heating Up, Eclipse), dots for the ones counted one by
-- one (Maelstrom Weapon, Arcane Blast, Reckoning, Thousand Cuts), dimmer for a growing bonus
-- (Vengeance), and the two sides of its art for Fingers of Frost (2 charges, decided by Ben).

    -- Shaman. Improved Stormstrike (Enhancement, talent 1223031 in the Forever data): a dodge or a
    -- parry can reset Stormstrike's cooldown (always at 2/2). "reset" mode (0.20.0): Forever's
    -- API never hides whether a spell is on cooldown (SpellCooldownInfo.isActive is NeverSecret
    -- in Forever's own API documentation). After a Stormstrike, if its cooldown ends well before
    -- its 6 s, it was reset: the alert shows until Stormstrike is used, or for "Show for" seconds
    -- (setting, 4 by default). In combat only. Stormstrike 17364 (usual number, unchecked).
    -- 0.23.26 (Blizzard's notes, November 2): Stormstrike's cooldown is 6 s (was 8). With 8, its
    -- usual end at 6 s looked like a reset: an alert after every Stormstrike.
    { key = "stormstrike", class = "SHAMAN", spec = "enhancement", spell = 1223031, mode = "reset", cd = 6, dur = 4,
      cast = { 17364 }, combatOnly = true, icon = "Interface\\Icons\\Ability_Shaman_Stormstrike", label = "L_stormstrike",
      defaults = { color = "frost", soundChoice = "power", y = 120, showFor = 4 } },

    -- Rogue. Thousand Cuts: removed from the game (Blizzard's notes, November 2), so from Shadowflare
    -- too in 0.23.26.
    -- Mage. Arcane Blast (Arcane tier 3, 400574 in the Forever data): each cast gives Spell Damage
    -- (15% of Intellect) for 15 s, up to 4 stacks, and raises its own cost. Not a proc: an alert
    -- at the stacks the player picks. Its buff has the spell's name. Shown by the game; no sound.
    -- 0.23.14 (reported by drani21): its buff had to be seen out of combat with 2 stacks before
    -- anything showed, and its stacks last only 15 s: many mages never saw it. Shadowflare now
    -- counts the stacks itself from the Arcane Blasts cast (mode "casts"; tooltip in Forever:
    -- each cast adds a stack, up to 4, 15 s from the first one, not renewed), and its mana cost
    -- (raised by each stack) tells when they are gone early. The game's frame still takes over
    -- once the buff is learned. Shown from 1 stack by default (Ben).
    -- 0.23.26 (Blizzard's notes, November 2): its stacks last 18 s (was 15)
    -- 0.23.31 (CurseForge, "a lot of times it doesn't track"): never handed to the game any more.
    -- Once its buff had been seen out of combat, the game's frame took over for good, and it
    -- follows these stacks badly in a fight (drani21's first report, October). Counted from the
    -- casts only, with its sound and its time left.
    { key = "arcaneblast", class = "MAGE", spec = "arcane", spell = 400574, mode = "casts", dur = 18,
      stacks = 4, cast = { 400574 }, fromFirst = true,
      icon = "Interface\\Icons\\Spell_Arcane_Blast", label = "L_arcaneblast",
      defaults = { color = "violet", y = 340, stackLook = "dots", fromStacks = 1 } },

    -- Weapons and enchants (0.20.0): not tied to a class (gear = true: every class has them).
    -- Their own sections in the options, "Weapons" and "Enchants". Shown by the game only, no sound.
    -- Hand of Edward the Odd (one-hand mace, item 2243, level 57): "Next spell cast within 4 sec
    -- will cast instantly". Proc spell 18803 in the Forever data (its buff). Name and icon from the item.
    { key = "edward", class = "WEAPONS", gear = true, spec = "mace", item = 2243, spell = 18803, mode = "aura", dur = 4,
      buffIds = { 18803 }, icon = "Interface\\Icons\\INV_Mace_04", label = "L_edward",
      defaults = { color = "frost", y = -150, enabled = false } },   -- 0.23.15: off until ticked (Ben)
    -- Revelation (melee weapon enchant, enchant spell 1248805): the next non-periodic spell gets
    -- +100% critical strike chance. Buff name read from the enchant's own name (the part after
    -- " - "), so it works in every language; "Revelation" otherwise. Its length is unknown: a
    -- long buff or one with no end time is accepted for it (maxDur, noEnd).
    { key = "revelation", class = "ENCHANTS", gear = true, spec = "weapon", enchantSpell = 1248805, mode = "aura", dur = 15,
      noEnd = true, maxDur = 3600, buffNames = { "Revelation" }, icon = "Interface\\Icons\\Spell_Holy_MindVision",
      label = "L_revelation", defaults = { color = "violet", y = 340, enabled = false } },
    -- Insight (weapon enchant, enchant spell 1248757): +100% Spirit for 10 s. "Clairvoyance" in
    -- French, a name other spells may also use: only a buff of about 10 s is taken (minDur, maxDur).
    { key = "insight", class = "ENCHANTS", gear = true, spec = "weapon", enchantSpell = 1248757, mode = "aura", dur = 10,
      minDur = 8, maxDur = 12, buffNames = { "Insight" }, icon = "Interface\\Icons\\Spell_Holy_DivineSpirit",
      label = "L_insight", defaults = { color = "frost", y = 340, enabled = false } },
}
-- From 0.16.0, the procs that are buffs can also be shown by the game itself once their
-- buff has been seen out of combat (buffIds, nameFromSpell, nameFromLabel, stacks: see
-- AuraShow.lua). Buff numbers from the game's data, unchecked in Forever: Clearcasting
-- 12536, Missile Barrage 400589, Omen of Clarity 16870, Elemental Focus 16246, Cutthroat
-- 462707 (as another addon's public Forever code uses them); Decimation 440873, Hot Streak
-- 400625, Eclipse 408255 / 408250, Maelstrom Weapon 408505 (Season of Discovery numbers).
-- A wrong number does nothing: the buff is then found by its name, or the proc stays as before.
-- 0.23.20 (Ben: having to see a buff out of combat first looked like a broken alert): the
-- "aura" procs (only the game can show them) and the procs marked "preset" (numbers seen
-- working in Forever: Victory Rush, and the five above) are shown by the game from the
-- first login, with every number given. The others still wait for their buff to be seen
-- once out of combat (one sighting is enough, at any number of stacks).
-- 0.23.21: Heating Up 400625, Maelstrom Weapon 408505, Decimation 440873 and Eclipse 408255
-- exist in the Forever client under those exact names (its spell data, build 70374), while
-- each talent has its own number: marked "preset" too. Eclipse 408250 is not there: removed.
ns.PROC_BY = {}
ns.CLASSES = {}          -- classes that have at least one proc, in order
do
    local seen = {}
    for _, p in ipairs(ns.PROCS) do
        ns.PROC_BY[p.key] = p
        if not seen[p.class] then seen[p.class] = true; ns.CLASSES[#ns.CLASSES + 1] = p.class end
    end
end
-- Default animation of each proc (0.23.0, decided with Ben): a short window or a reaction gets
-- Impact, a rare strong proc Flash, a free or faster spell with time to use it Classic pulse,
-- an on/off state Still. The others (long buffs) keep Breathing.
ns.ANIM_DEFAULTS = {
    impactpulse = { "fingers" },   -- 0.23.2
    impact  = { "overpower", "revenge", "hotstreak", "maelstrom", "riposte", "mongoose", "counterattack", "stormstrike" },
    flash   = { "cutthroat", "remorseless", "rapidkilling", "edward", "revelation" },
    classic = { "trance", "victoryrush", "decimation", "missilebarrage", "arcaneblast", "eclipse", "naturesgrace", "infusion", "searinglight" },
    still   = { "execute", "hammer", "shieldblock", "conflagrate" },
}
for anim, keys in pairs(ns.ANIM_DEFAULTS) do
    for _, k in ipairs(keys) do
        local p = ns.PROC_BY[k]
        if p then p.defaults = p.defaults or {}; p.defaults.anim = anim end
    end
end
-- Once per profile (0.23.0, Ben's choice): every proc saved as Breathing, the old default for
-- all, takes its new default. A player who changes it afterwards keeps his choice.
function ns.MigrateAnims(db)
    -- 0.23.26: Cutthroat's buff is gone (Ghostly Strike follows Ambush only): its learned entry too
    if type(db.buffs) == "table" and not db.ghost0326 then
        db.buffs.cutthroat = nil
        db.ghost0326 = true
    end
    for _, prof in pairs(db.profiles or {}) do
        if type(prof) == "table" and not prof.anim023 then
            for key, t in pairs(prof.procs or {}) do
                local p = ns.PROC_BY[key]
                local want = p and p.defaults and p.defaults.anim
                if type(t) == "table" and want and want ~= "breath" and (t.anim == nil or t.anim == "breath") then t.anim = want end
            end
            prof.anim023 = true
        end
        -- Once per profile (0.23.14): Arcane Blast now has its own detection and a sound (it had
        -- none, stored as "none"), and shows from 1 stack (it was 4, stored when first read)
        if type(prof) == "table" and not prof.ab0234 then
            local t = type(prof.procs) == "table" and prof.procs.arcaneblast
            if type(t) == "table" then
                if t.soundChoice == "none" then t.soundChoice = nil end
                if t.fromStacks == 4 then t.fromStacks = 1 end
            end
            prof.ab0234 = true
        end
        -- Once per profile (0.23.26): Vengeance goes up to 5 stacks. "Show at 3" was its old
        -- maximum (the default): it moves to the new one. Any other choice is kept.
        if type(prof) == "table" and not prof.veng0326 then
            local t = type(prof.procs) == "table" and prof.procs.vengeance
            if type(t) == "table" and t.fromStacks == 3 then t.fromStacks = 5 end
            prof.veng0326 = true
        end
        -- Once per profile (0.23.2): Fingers of Frost, Impact until now, takes Impact pulse
        if type(prof) == "table" and not prof.anim0232 then
            local t = type(prof.procs) == "table" and prof.procs.fingers
            if type(t) == "table" and t.anim == "impact" then t.anim = "impactpulse" end
            prof.anim0232 = true
        end
        -- Once per profile (0.23.15, Ben): weapons and enchants off unless the player ticked them
        -- himself; Remorseless Attacks shown out of combat too (it comes from a kill)
        if type(prof) == "table" and not prof.def0315 then
            local procs = type(prof.procs) == "table" and prof.procs or {}
            for _, p in ipairs(ns.PROCS) do
                local t = procs[p.key]
                if p.gear and type(t) == "table" and not t.enabledByUser then t.enabled = false end
            end
            if type(procs.remorseless) == "table" and procs.remorseless.onlyCombat == true then procs.remorseless.onlyCombat = false end
            prof.def0315 = true
        end
        -- Retail pictures kept one per series (0.23.15 test builds): a step picked moves to the full one
        local RETAIL_MOVED = { blz1027131 = "blz1027133", blz1027132 = "blz1027133", blz1028136 = "blz1028139",
            blz1028137 = "blz1028139", blz1028138 = "blz1028139", blz1029138 = "blz1029140", blz1029139 = "blz1029140",
            blz623950 = "blz1028092", blz1028091 = "blz1028092" }
        if type(prof) == "table" and type(prof.procs) == "table" then
            for _, t in pairs(prof.procs) do
                if type(t) == "table" and RETAIL_MOVED[t.style] then t.style = RETAIL_MOVED[t.style] end
            end
        end
        -- Once per profile (0.23.15): the "sides" look (Fingers of Frost: one side at 1 charge)
        -- is gone, every two-sided style has its own Sides choice now: Dots in its place, the
        -- whole alert at full brightness, as Ben wanted for Fingers of Frost
        if type(prof) == "table" and not prof.sides0315 then
            for _, t in pairs(type(prof.procs) == "table" and prof.procs or {}) do
                if type(t) == "table" and t.stackLook == "sides" then t.stackLook = "dots" end
            end
            prof.sides0315 = true
        end
    end
end

local GLOBAL_DEFAULTS = { showNotes = true, selected = "trance" }
local PROC_DEFAULTS = {
    enabled = true, style = "arcs", color = "violet", scale = 1, alpha = 1, shadow = 0.6, onlyCombat = true,
    timer = true, timerFree = false, timerSize = 22, tox = 0, toy = -80, rotation = 0,
    timerAlign = "center",   -- 0.23.23: the time left placed apart: left, center or right
    font = "game",           -- 0.23.24: every text of the alert ("game", a game font, or "lsm:<name>")
    edges = false, edgesOnly = false, anim = "breath", soundChoice = "power", tintClassic = false, x = 0, y = 120,
    noEntrance = false,   -- 0.23.13: no way in or out for this alert (its animation keeps moving)
    spacing = 0, side = "both",   -- 0.23.15: two-sided styles, halves moved apart, one side only
    otherStances = false,         -- 0.23.27: Overpower and Revenge also in another stance (off)
    noneTime = true, noneDots = true,   -- 0.23.32: what the None style shows (Style tab)
}
-- Procs with stacks (0.18.0): the number of stacks shown next to the alert, where and how big.
-- "fromStacks" (show from N stacks) defaults to the proc's maximum: nothing changes unless set.
local STACK_DEFAULTS = { stackNum = true, stackSize = 24, sox = 0, soy = 55, fillHide = false }
ns.STACK_DEFAULTS = STACK_DEFAULTS
-- Settings that used to sit at the top level (0.8 and before): they now belong to Shadow Trance
local OLD_KEYS = { "style", "color", "custom", "scale", "alpha", "timer", "timerFree", "timerSize",
    "tx", "ty", "edges", "soundChoice", "tintClassic", "x", "y" }

-- The settings of one proc (filled with its defaults once per session)
local filled = {}
ns.PROC_DEFAULTS = PROC_DEFAULTS
ns.CFG_KEY = setmetatable({}, { __mode = "k" })
function ns.Cfg(key)
    local procs = ns.procs
    local c = procs[key]
    if not c then
        c = {}
        procs[key] = c
    end
    if not filled[c] then
        local p = ns.PROC_BY[key]
        -- Up to 0.10 the time left had its own place on screen; it now follows the alert
        if c.tox == nil and c.tx ~= nil then
            c.tox, c.toy = c.tx - (c.x or 0), (c.ty or 40) - (c.y or 120)
        end
        c.tx, c.ty = nil, nil
        if p and p.defaults then   -- the proc's own defaults first, then the common ones
            for k, v in pairs(p.defaults) do if c[k] == nil then c[k] = v end end
        end
        for k, v in pairs(PROC_DEFAULTS) do if c[k] == nil then c[k] = v end end
        if p and p.stacks then   -- procs with stacks (0.18.0): from how many, and the number shown
            for k, v in pairs(STACK_DEFAULTS) do if c[k] == nil then c[k] = v end end
            if c.fromStacks == nil then c.fromStacks = p.stacks end
        end
        if p and p.gameSoundOnly then c.soundChoice = "game" end   -- its only possible sound
        if p and p.mode == "aura" then c.soundChoice = "none" end   -- shown by the game only: no sound
        filled[c] = true
        ns.CFG_KEY[c] = key   -- 0.23.30: which alert a settings table is for (the None style)
    end
    return c
end

-- From how many stacks a proc's alert shows (its maximum unless the player chose fewer)
function ns.FromStacks(key)
    local p = ns.PROC_BY[key]
    if not (p and p.stacks) then return nil end
    local v = tonumber(ns.Cfg(key).fromStacks) or p.stacks
    v = math.floor(v)
    if v < 1 then v = 1 elseif v > p.stacks then v = p.stacks end
    return v
end

-- The proc whose settings the options page shows
function ns.Selected() return ns.PROC_BY[ns.db.selected] and ns.db.selected or "trance" end
function ns.Cur() return ns.Cfg(ns.Selected()) end

----------------------------------------------------------------------
-- Safe reads (the Forever client may hide some values in combat)
-- The client can hand back "secret" values that break comparisons, maths and tostring.
-- num() and str() return a plain value, or nil when the value can't be used.
-- No function is created on the way: these run on every aura change.
----------------------------------------------------------------------
local isSecretValue = issecretvalue
local function plusZero(v) return v + 0 end
local function withEmpty(v) return v .. "" end

local function secret(v)
    if not isSecretValue then return false end
    local ok, s = pcall(isSecretValue, v)
    return not ok or s
end
local function num(v)
    if v == nil or secret(v) then return nil end
    if type(v) == "number" then return v end
    local ok, r = pcall(plusZero, v)
    if ok and type(r) == "number" then return r end
end
local function str(v)
    if v == nil or secret(v) then return nil end
    if type(v) == "string" then return v end
    local ok, r = pcall(withEmpty, v)
    if ok and type(r) == "string" then return r end
end
local function clean(v)
    if type(v) == "number" then return num(v) end
    if type(v) == "string" then return str(v) end
    if secret(v) then return nil end
    return v
end
ns.num, ns.str, ns.clean = num, str, clean

function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffa35cffShadowflare|r " .. tostring(msg))
end

function ns.SpellName(id)
    local ok, n
    if C_Spell and C_Spell.GetSpellName then ok, n = pcall(C_Spell.GetSpellName, id)
    elseif GetSpellInfo then ok, n = pcall(GetSpellInfo, id) end
    return ok and str(n) or nil
end

function ns.SpellIcon(id)
    local ok, t
    if C_Spell and C_Spell.GetSpellTexture then ok, t = pcall(C_Spell.GetSpellTexture, id)
    elseif GetSpellTexture then ok, t = pcall(GetSpellTexture, id) end
    return ok and clean(t) or nil
end

-- Weapons and enchants (0.20.0): the item's name, or the enchant's name without its prefix
-- ("Enchant Weapon - Revelation" gives "Revelation"), in the player's language. nil if unknown yet.
function ns.GearName(p)
    if p.item then
        local get = C_Item and C_Item.GetItemNameByID
        if get then
            local ok, n = pcall(get, p.item)
            n = ok and str(n) or nil
            if n then return n end
            if C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, p.item) end
        end
        return nil
    end
    if p.enchantSpell then
        local n = ns.SpellName(p.enchantSpell)
        if n then
            local short = n:match("^.+%s%-%s(.+)$")
            return short or n
        end
    end
end

-- Their icon: the buff's own once seen out of combat, else the item's, else the one given
function ns.GearIcon(p)
    local e = ns.db and type(ns.db.buffs) == "table" and ns.db.buffs[p.key]
    if type(e) == "table" and e.icon then return e.icon end
    if p.item and C_Item and C_Item.GetItemIconByID then
        local ok, t = pcall(C_Item.GetItemIconByID, p.item)
        if ok and t then return clean(t) end
    end
end

-- What the alerts show for each proc: the icon of the spell to cast, the proc's name,
-- and a short line ("Instant Shadow Bolt"). Names come from the game, in the player's language.
ns.INFO = {}
function ns.Info(key)
    local i = ns.INFO[key]
    if not i then
        local p = ns.PROC_BY[key]
        i = { key = key, icon = p.icon, name = L["P_" .. key] or key, label = L[p.label] or "" }
        ns.INFO[key] = i
    end
    return i
end
local function UpdateInfo()
    for _, p in ipairs(ns.PROCS) do
        local i = ns.Info(p.key)
        i.name = ns.GearName(p) or (p.spell and ns.SpellName(p.spell)) or L["P_" .. p.key] or p.key
        -- keepIcon: the proc helps every spell (Clearcasting), so it shows the buff's own
        -- icon rather than one of the spells it watches. "aura" procs: the talent's own icon.
        if p.mode == "aura" and p.spell and not p.gear then i.icon = ns.SpellIcon(p.spell) or p.icon end
        if p.gear then i.icon = ns.GearIcon(p) or p.icon end
        local list = (not p.keepIcon) and (p.cast or (p.watch and p.watch[1])) or {}
        for n = #list, 1, -1 do
            local t = ns.SpellIcon(list[n])
            if t then i.icon = t break end
        end
    end
    ns.tranceName = ns.SpellName(TRANCE_ID)
end
ns.UpdateInfo = UpdateInfo

-- Cast time of a spell. The old form returns plain values, the new one builds a table:
-- the old one is used when the client has it.
local GetSpellInfoOld = GetSpellInfo
-- During one check, each spell is read once (0.20.1): several procs often look at the same
-- spell (Shadow Bolt, Frostbolt, Lightning Bolt), and each read can make a small table.
local readStamp, readCount = nil, 0
local ctAt, ctVal, costAt, costVal = {}, {}, {}, {}
local function CastTimeRead(id)
    if GetSpellInfoOld then
        local ok, _, _, _, ct = pcall(GetSpellInfoOld, id)
        if ok then return num(ct) end
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, id)
        if ok and type(info) == "table" then return num(info.castTime) end
    end
end
local function CastTime(id)
    if not readStamp then return CastTimeRead(id) end
    if ctAt[id] == readStamp then return ctVal[id] end
    local v = CastTimeRead(id)
    ctAt[id], ctVal[id] = readStamp, v
    return v
end

-- Highest known rank of a spell, from a list of ranks
local function Known(list)
    for i = #list, 1, -1 do
        local id = list[i]
        local known = false
        if IsPlayerSpell then local ok, v = pcall(IsPlayerSpell, id); known = ok and v end
        if not known and IsSpellKnown then local ok, v = pcall(IsSpellKnown, id); known = ok and v end
        if known then return id end
    end
end

----------------------------------------------------------------------
-- Shadow Trance: four independent signals, any one is enough
--   aura     : the Shadow Trance buff on the player (readable out of combat only on Forever)
--   overlay  : the game's own proc overlay event
--   glow     : the game's "Shadow Bolt glows on the action bar" event
--   cast-time: Shadow Bolt cast time drops to 0 (what works in combat on Forever)
-- Decimation: Soul Fire casts faster. Compared with Shadow Bolt (or Immolate), so that
-- anything that speeds up every spell (haste) does not count.
-- The game's events drive everything. In combat, and while an alert is up, a light
-- check every 0.2 s also reads the cast times: they change a moment after the events.
----------------------------------------------------------------------
local S = { aura = false, overlay = false, glow = false, instant = false, auraReliable = true, active = false }
ns.state = S
local castBase   -- Shadow Bolt's normal cast time, once seen

local function SetAura(found, inst, exp, dur, via)
    if S.aura and not found then S.auraGoneAt = GetTime() end
    S.aura, S.auraInst, S.auraExp, S.auraDur = found, inst, exp, dur
    S.via = found and (via or "list") or nil
end

-- Ask the game directly whether Shadow Trance is on the player (one call, nothing built
-- when it isn't). true: found, false: not there, nil: the game can't say.
local ByIdAPI = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
local function AskGameRaw()
    local a = ByIdAPI(TRANCE_ID)
    if a then
        SetAura(true, num(a.auraInstanceID), num(a.expirationTime), num(a.duration), "api")
        return true
    end
    return false
end
local function AskGame()
    if not ByIdAPI then return nil end
    local ok, found = pcall(AskGameRaw)
    if not ok then return nil end
    -- Not there any more: drop it, unless it was found another way (by its name)
    if not found and S.via == "api" then SetAura(false) end
    return found
end

-- One buff by its place in the list: "end", "match" (with its details), "next" or "unreadable"
local UnitBuffOld = UnitBuff
local function ReadAura(i, tname)
    local sid, aname, exp, dur, inst
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local a = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not a then return "end" end
        sid, aname, exp, dur, inst = a.spellId, a.name, a.expirationTime, a.duration, a.auraInstanceID
    elseif UnitBuffOld then
        local n, _, _, _, d, e, _, _, _, s = UnitBuffOld("player", i)
        if n == nil then return "end" end
        sid, aname, exp, dur = s, n, e, d
    else
        return "end"
    end
    sid, aname = num(sid), str(aname)
    if sid == nil and aname == nil then return "unreadable" end
    if sid == TRANCE_ID or (tname and aname == tname) then
        return "match", num(exp), num(dur), num(inst)
    end
    return "next"
end

-- The whole buff list: at login, after a loading screen, and when the game says everything changed
local function FullScan(deep)
    local found = AskGame()
    if found then S.auraReliable = true return end
    if found == false and not deep then SetAura(false) return end
    -- Look through the buffs: by name, and to know whether they can be read at all
    local reliable = true
    SetAura(false)
    for i = 1, 40 do
        local ok2, res, e, d, inst = pcall(ReadAura, i, ns.tranceName)
        if not ok2 or res == "unreadable" then
            reliable = false
            if not ok2 then break end
        elseif res == "end" then
            break
        elseif res == "match" then
            SetAura(true, inst, e, d)
            break
        end
    end
    S.auraReliable = reliable
end

local function ReadInstance(inst)
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID) then return end
    local ok, a = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, "player", inst)
    if ok and type(a) == "table" then
        S.auraExp, S.auraDur = num(a.expirationTime), num(a.duration)
    end
end

-- Only what changed, as the game reports it: a few entries instead of the whole list
local function AuraChanges(info)
    local added = info.addedAuras
    if added then
        for i = 1, #added do
            local a = added[i]
            local sid, n = num(a.spellId), str(a.name)
            if sid == TRANCE_ID or (n and n == ns.tranceName) then
                -- Found by its number: the game can confirm it later. By its name only: we follow it ourselves.
                SetAura(true, num(a.auraInstanceID), num(a.expirationTime), num(a.duration), sid == TRANCE_ID and "api" or "list")
            elseif sid == nil and n == nil then
                S.auraReliable = false   -- a buff we can't read: maybe Shadow Trance
            end
        end
    end
    local inst = S.auraInst
    if not S.aura then return end
    if not inst then
        -- Found without its number: ask the game directly whenever something leaves
        if info.removedAuraInstanceIDs then FullScan(S.via == "list") end
        return
    end
    local upd = info.updatedAuraInstanceIDs
    if upd then
        for i = 1, #upd do if num(upd[i]) == inst then ReadInstance(inst) break end end
    end
    local gone = info.removedAuraInstanceIDs
    if gone then
        for i = 1, #gone do if num(gone[i]) == inst then SetAura(false) break end end
    end
end

-- Shadow Bolt with no cast time means the next one is instant
-- When Shadow Bolt gets its normal cast time back, the proc is over, whatever the other
-- signals still say: in combat the game may not tell that the buff left, so a buff seen
-- earlier would keep the alert up until its end.
local function CheckInstant()
    local id = S.sbId
    local ct = id and CastTime(id)
    if not ct then S.instant = false return end
    if ct > 0 then
        castBase = ct
        if S.instant then
            if S.aura then SetAura(false) end
            S.overlay, S.glow = false, false
        end
        S.instant = false
    else
        S.instant = castBase ~= nil   -- only trust a 0 if a real cast time was seen before
    end
end

----------------------------------------------------------------------
-- The common engine. Each proc says how it shows itself (its "mode"):
--   trance : Shadow Trance's own signals above (buff, game events, cast time)
--   instant: a spell's cast time drops to 0 (Maelstrom Weapon)
--   faster : a spell casts faster than usual, compared with a reference spell that the
--            proc does not touch, so haste does not count (Decimation, Eclipse...)
--   free   : a spell's cost drops (Clearcasting...): read in combat on Forever (14 Oct 2026)
--   usable : the game says a spell can be used (Overpower, Execute...)
--   aura   : nothing readable changes (Remorseless Attacks...): no detection, no sound; only
--            the game shows it, once its buff is known (AuraShow.lua, 0.17.0)
-- Everything is read from the spells themselves: Forever hides buffs from addons in combat.
----------------------------------------------------------------------
local G = {}            -- per proc: what the engine knows
ns.engine = G
local function GS(key)
    local g = G[key]
    if not g then g = { ratio = {}, costBase = {} }; G[key] = g end
    return g
end

-- Faster than usual. The usual ratio is the highest one seen (the proc only lowers it);
-- it is learned again when the talents change. Optional: the spell itself must also be
-- faster than its own slowest cast seen (a reference sped up by another effect is then
-- not mistaken for the proc).
local function CheckFaster(p, g)
    g.q, g.cut = nil, nil
    local ct = g.id and CastTime(g.id)
    if not (ct and ct > 0) then g.on = false return end
    if p.selfCheck then
        if not g.maxCt or ct > g.maxCt then g.maxCt = ct end
    end
    local refId, ref
    for _, rid in ipairs(g.refIds or {}) do
        local c = CastTime(rid)
        if c and c > 0 then refId, ref = rid, c break end
    end
    if not ref then
        if p.selfCheck and g.maxCt then g.on = ct < g.maxCt * (p.threshold or 0.9) end
        return                               -- nothing to compare with: keep the last answer
    end
    local r = ct / ref
    local base = g.ratio[refId]
    -- The usual ratio is learned only while the spell is at its own usual speed (a flat cut
    -- on both spells, such as Nature's Grace, would raise it and make haste look like a proc)
    local learn = not (p.selfCheck and g.maxCt and ct < g.maxCt * 0.95)
    if not base or (r > base and learn) then base = r; g.ratio[refId] = r end
    local on = r < base * (p.threshold or 0.9)
    -- Kept for counting stacks (0.18.0): how much faster than usual, and the seconds cut
    if not (p.selfCheck and g.maxCt and ct >= g.maxCt * 0.95) then
        g.q = r / base
        if g.maxCt then g.cut = (1 - r / base) * g.maxCt / 1000 end
    end
    if on and p.selfCheck then on = ct < g.maxCt * 0.95 end
    if on and p.fullCut and g.maxCt then
        -- Charges (Eclipse): seconds taken off the usual cast time, haste set aside. Shown
        -- only when the cut is full (4 charges at rank 3: 2 s). The largest cut seen so far
        -- stands for "full" until the full one at rank 3 has been seen.
        local cut = (1 - r / base) * g.maxCt / 1000
        g.maxCut = math.max(g.maxCut or 0, cut)
        on = cut >= math.max(0.25, math.min(p.fullCut, g.maxCut * 0.9))
    end
    g.on = on
end

-- Instant: the cast time is 0, and a real cast time was seen before
local function CheckInstantProc(g)
    local ct = g.id and CastTime(g.id)
    g.ct = ct
    if not ct then g.on = false return end
    if ct > 0 then
        g.base, g.on = ct, false
        if not g.maxCt or ct > g.maxCt then g.maxCt = ct end   -- its usual speed (stacks below)
    else g.on = g.base ~= nil end
end

-- Cost of a spell (the first resource it uses), or nil when the game can't say
local function CostRead(id)
    local t
    if C_Spell and C_Spell.GetSpellPowerCost then
        local ok, v = pcall(C_Spell.GetSpellPowerCost, id)
        if not ok then return nil end
        t = v
    elseif GetSpellPowerCost then
        local ok, v = pcall(GetSpellPowerCost, id)
        if not ok then return nil end
        t = v
    end
    if type(t) ~= "table" or secret(t) then return nil end
    local c = t[1]
    if type(c) ~= "table" then return 0 end   -- no cost at all
    return num(c.cost)
end
local function CostOf(id)
    if not readStamp then return CostRead(id) end
    if costAt[id] == readStamp then return costVal[id] end
    local v = CostRead(id)
    costAt[id], costVal[id] = readStamp, v
    return v
end
-- Whether a spell costs at most "free" times its usual cost right now (usual cost learned)
local function IsFree(g, id, free)
    local c = CostOf(id)
    if not c then return nil end
    local b = g.costBase[id]
    if not b or c > b then b = c; g.costBase[id] = c end
    return b > 0 and c <= b * free, c
end
-- Free (or cheaper): any watched spell costs at most "free" times its usual cost
local function CheckFree(p, g)
    local seen, on = false, false
    local now = GetTime()
    for _, id in ipairs(g.watch or {}) do
        local c = CostOf(id)
        -- skipInstant: a spell with no cast time is made free by something else (Maelstrom Weapon)
        if c and p.skipInstant and CastTime(id) == 0 then c = nil end
        if c then
            seen = true
            local b = g.costBase[id]
            if not b or c > b then b = c; g.costBase[id] = c end
            if b > 0 and c <= b * (p.free or 0) then on = true end
        end
    end
    if not seen then
        -- The cost can't be read any more: the proc ends at the latest with its usual length
        if g.on and g.seenAt and now - g.seenAt > (p.dur or 15) then g.on = false end
        return
    end
    g.seenAt = now
    -- Missile Barrage: not when Clearcasting (checked just before) explains the free spell
    if on and p.unless and G[p.unless] and G[p.unless].on then on = false end
    -- Searing Light: not when another spell is free too (Inner Focus makes any spell free).
    -- Their costs are read every time, so their usual cost is known before it matters.
    if g.others then
        local otherFree = false
        for _, id in ipairs(g.others) do
            if IsFree(g, id, 0) then otherFree = true end
        end
        if otherFree then on = false end
    end
    g.on = on
end

-- Usable: shown while the game says the spell can be used. For procs that open a short
-- window (Overpower, Revenge), "usable with more rage" counts too, so the alert never
-- flickers with the rage bar; for states like Execute it does not (decided by Ben,
-- 14 October 2026). Checked in game, 13 October 2026: this answer stays readable in
-- combat on Forever, and the wrong stance makes it "no". A short "no" (under 0.3 s) is
-- ignored. A cast hides the alert at once; with holdCd it stays hidden for the whole
-- cooldown, otherwise until the game says "no" (window closed: the next "yes" is a new
-- proc) or the cooldown is over.
-- Revenge is not used up by its cast: the game keeps saying "yes" for the rest of the
-- window (seen in game, 14 October 2026).
-- Another stance (0.23.27): Overpower and Revenge followed by Shadowflare itself, from the
-- game's hit feed. The feed doesn't say whose attack the target dodged: in a group, a dodge on
-- someone else's attack shows Overpower too (said in the option's tooltip).
ns.stanceTrack = {}     -- proc key -> { at = when, untilT = end of the window, guid = target }
local function StanceNow()
    if not GetShapeshiftForm then return nil end
    local ok, i = pcall(GetShapeshiftForm)
    i = ok and num(i) or nil
    if not i then return nil end
    if i == 0 then return 0 end
    if not GetShapeshiftFormInfo then return nil end
    local ok2, _, _, _, sid = pcall(GetShapeshiftFormInfo, i)
    return ok2 and num(sid) or nil
end
ns.StanceNow = StanceNow
local function TargetGUID()
    local ok, gid = pcall(UnitGUID, "target")
    return ok and str(gid) or nil
end
-- The trigger is followed, the window is open, and the player is in another stance (read; if
-- the stance can't be read, nothing is shown: never a false alert)
function ns.StanceTracked(p, now)
    if not ns.Cfg(p.key).otherStances then return false end
    local t = ns.stanceTrack[p.key]
    if not t or now >= t.untilT then return false end
    if t.guid and t.guid ~= TargetGUID() then return false end
    local s = StanceNow()
    return s ~= nil and s ~= p.stance
end
-- The hit feed: listened to only by a warrior with one of the options on
local feed = CreateFrame("Frame")
local function OnFeed(unit, what, flag)
    if not S.inCombat then return end
    what, flag = str(what), str(flag)
    if not what then return end
    local now = GetTime()
    for _, p in ipairs(ns.PROCS) do
        local hit = false
        if p.stanceTrack == "targetDodge" then
            hit = unit == "target" and what == "DODGE"
        elseif p.stanceTrack == "avoided" then
            hit = unit == "player" and (what == "DODGE" or what == "PARRY" or what == "BLOCK" or flag == "BLOCK")
        end
        if hit and ns.Cfg(p.key).otherStances then
            ns.stanceTrack[p.key] = { at = now, untilT = now + (p.dur or 5),
                guid = p.stanceTrack == "targetDodge" and TargetGUID() or nil }
            if ns.WakeAt then ns.WakeAt(now + (p.dur or 5)) end
            if ns.RequestRefresh then ns.RequestRefresh() end
        end
    end
end
feed:SetScript("OnEvent", function(_, _, unit, what, flag) OnFeed(unit, what, flag) end)
function ns.UpdateStanceFeed()
    local want = false
    if ns.playerClass == "WARRIOR" and ns.db then
        for _, p in ipairs(ns.PROCS) do
            if p.stanceTrack and ns.Cfg(p.key).otherStances and ns.Cfg(p.key).enabled then want = true end
        end
    end
    if want == (feed.on or false) then return end
    feed.on = want
    if want then
        if not (feed.RegisterUnitEvent and pcall(feed.RegisterUnitEvent, feed, "UNIT_COMBAT", "player", "target")) then
            pcall(feed.RegisterEvent, feed, "UNIT_COMBAT")
        end
    else
        pcall(feed.UnregisterEvent, feed, "UNIT_COMBAT")
        for k in pairs(ns.stanceTrack) do ns.stanceTrack[k] = nil end
    end
end

S.ids = {}              -- usable procs: the known spell (kept for the warrior test lines)
local IsSpellUsableAPI = (C_Spell and C_Spell.IsSpellUsable) or IsUsableSpell
local function UsableRaw(id, noPower)
    local u, lack = IsSpellUsableAPI(id)
    return u == true or (noPower and lack == true)
end
local function CheckUsable(p, g, now)
    local id = g.id
    if not id or not IsSpellUsableAPI then g.raw = false return end
    local ok, on = pcall(UsableRaw, id, p.noPower ~= false)
    on = ok and on or false
    if on and p.combatOnly and not S.inCombat then on = false end
    if on and p.notStealthed and IsStealthed then
        local okS, st = pcall(IsStealthed)
        if okS and st == true then on = false end
    end
    -- 0.23.27: in another stance the game says no; the trigger followed by Shadowflare counts
    -- there (option, off by default), shown with the stance to take
    g.stanceHint, g.trackAt = nil, nil
    if not on and p.stanceTrack and S.inCombat and ns.StanceTracked(p, now) then
        on, g.stanceHint, g.trackAt = true, p.stance, ns.stanceTrack[p.key].at
    end
    -- When the window opened (0.21.3): the game says "yes" from the kill, dodge or parry on,
    -- even while the alert waits for the cooldown. An alert shown at the end of the cooldown
    -- then counts its time from there, not from the moment it shows (Victory Rush: a kill
    -- during the cooldown leaves only part of its 20 s; seen by Ben, 21 October 2026).
    -- A short "no" (under 0.3 s) does not open a new window.
    if on and not g.seenOn and not (g.seenOffAt and now - g.seenOffAt < 0.3) then g.openAt = g.trackAt or now end
    if g.seenOn and not on then g.seenOffAt = now end
    g.seenOn = on
    if g.wait and ((not on and not p.holdCd) or now - g.castAt >= (p.cd or 1)) then
        g.wait = false
        g.raw, g.offAt = on, nil   -- after a cast, no grace time
        return
    end
    -- no grace after combat, nor for an alert that follows the target (0.23.16: gone at once)
    if g.raw and not on then g.offAt = (not p.onTarget and (S.inCombat or not p.combatOnly)) and now or nil end
    g.raw = on
end
local function UsableSource(g, now)
    if g.wait then return nil end   -- just cast: gone, even if the game still says yes
    if g.raw then return "usable" end
    if g.offAt and now - g.offAt < 0.3 then return "usable" end
end

-- Overlay: on while the game shows its own proc alert for the spell (events below).
-- If the end is missed, the proc ends at the latest a little after its usual length.
local OVERLAY_MAP = {}  -- spell number in the game's alert event -> proc
for _, p in ipairs(ns.PROCS) do
    for _, id in ipairs(p.overlayIds or {}) do OVERLAY_MAP[id] = p end
end
local function CheckOverlay(p, g, now)
    if g.on and g.onAt and now - g.onAt > (p.dur or 15) + 2 then g.on = false end
end

-- How many stacks a stacking proc has right now (0.18.0). At its maximum it is the alert of
-- before (g.on). Below, each proc counts them from what the game still lets addons read:
--   Heating Up (stackAt): how much faster Pyroblast is than usual, compared with Fireball
--   Eclipse (perCharge): the seconds taken off Starfire, 0.5 s a charge at rank 3
--   Maelstrom Weapon (perStack): Lightning Bolt's mana cost, 20% off a stack
local function CountStacks(p, g)
    if g.on then return p.stacks end
    if p.mode == "casts" then return g.cn or 0 end
    if p.stackAt then
        local q = g.q
        if not q then return 0 end
        for i = #p.stackAt, 1, -1 do
            if q < p.stackAt[i] then return i end
        end
        return 0
    elseif p.perCharge then
        local cut = g.cut
        if not (cut and g.q and g.q < 0.95) then return 0 end
        local n = math.floor(cut / p.perCharge + 0.5)
        if n < 0 then n = 0 elseif n > p.stacks - 1 then n = p.stacks - 1 end
        return n
    elseif p.perStack then
        local id = g.id
        if not id then return 0 end
        local c = CostOf(id)
        local cut
        if c then
            local b = g.costBase[id]
            if not b or c > b then b = c; g.costBase[id] = c end
            if b > 0 and c > 0 then cut = 1 - c / b end
        end
        -- Free (Clearcasting) or cost unreadable: the cast time instead (haste can blur it)
        if not cut and g.ct and g.ct > 0 and g.maxCt and g.maxCt > 0 then cut = 1 - g.ct / g.maxCt end
        if not cut then return 0 end
        local n = math.floor(cut / p.perStack + 0.5)
        if n < 0 then n = 0 elseif n > p.stacks - 1 then n = p.stacks - 1 end
        return n
    end
    return 0
end

-- Reset (0.20.0): whether a spell is on cooldown right now. Forever's API never hides that one
-- answer (isActive), even in combat. nil when the client can't tell.
local function CdActive(id)
    if not (C_Spell and C_Spell.GetSpellCooldown) then return nil end
    local ok, v = pcall(function()
        local info = C_Spell.GetSpellCooldown(id)
        if type(info) ~= "table" or info.isActive == nil then return nil end
        return info.isActive == true
    end)
    if ok then return v end
end
ns.CdActive = CdActive
-- 0.23.29 (CurseForge, Stormstrike resets sometimes missed): while the global cooldown runs,
-- the game says "on cooldown" for Stormstrike too, and an Enhancement Shaman keeps it running.
-- isOnGCD (never secret in Forever's API docs) tells when only the global cooldown is left:
-- Stormstrike's own cooldown is over. Blizzard: to be trusted only right after
-- SPELL_UPDATE_COOLDOWN, so it is read there only (see the cooldown frame below).
local function GcdOnly(id)
    if not (C_Spell and C_Spell.GetSpellCooldown) then return false end
    local ok, info = pcall(C_Spell.GetSpellCooldown, id)
    if not ok or type(info) ~= "table" then return false end
    local okA, v = pcall(function() return info.isActive == true and info.isOnGCD == true end)
    return okA and v or false
end

-- How long a reset alert stays (setting "Show for", 2 to 10 s)
function ns.ShowFor(key)
    local v = num(ns.Cfg(key).showFor) or 4
    if v < 2 then v = 2 elseif v > 10 then v = 10 end
    return v
end

-- After the spell is cast, its cooldown ending much earlier than usual means it was reset.
-- The first second is skipped (the cooldown is being set up), and so is the last moment of the
-- usual cooldown. 0.23.29: 1 s (was 1.6 s); the global cooldown is now told apart (GcdOnly).
local RESET_FROM = 1.0
local function CheckReset(p, g, now)
    if g.on then
        if not S.inCombat or now - (g.onAt or now) > ns.ShowFor(p.key) then g.on = false end
        return
    end
    local id, at = g.id, g.castAt
    if not id or not at then return end
    if not S.inCombat then g.castAt = nil return end
    local since = now - at
    if since >= (p.cd or 8) - 0.6 then g.castAt = nil return end   -- the usual end of the cooldown
    if since < RESET_FROM then return end
    if CdActive(id) == false then
        g.on, g.onAt, g.castAt = true, now, nil
    end
end

-- 0.23.29: every change of a cooldown, in combat: a reset proc whose spell has only the global
-- cooldown left was reset (read at once, as Blizzard asks)
local cdFeed = CreateFrame("Frame")
pcall(cdFeed.RegisterEvent, cdFeed, "SPELL_UPDATE_COOLDOWN")
cdFeed:SetScript("OnEvent", function()
    if not S.inCombat or not ns.db then return end
    local now, hit = GetTime(), false
    for _, p in ipairs(ns.PROCS) do
        if p.mode == "reset" and p.class == ns.playerClass then
            local g = G[p.key]
            if g and not g.on and g.id and g.castAt and ns.Cfg(p.key).enabled then
                local since = now - g.castAt
                if since >= RESET_FROM and since < (p.cd or 8) - 0.6 and GcdOnly(g.id) then
                    g.on, g.onAt, g.castAt = true, now, nil
                    hit = true
                end
            end
        end
    end
    if hit then ns.Refresh() end
end)

-- Stacks counted from the casts (0.23.14, Arcane Blast): each cast of the spell adds one, up
-- to the maximum; they all go p.dur seconds after the first one. The spell's cost, raised by
-- each stack, tells when they are gone sooner (out of combat, death...): back to its usual
-- cost a moment after the last cast means no stack. The usual cost is learned when no stack
-- can be up (and again after each level, as it grows with the level).
local function CheckCasts(p, g, now)
    if g.winStart and now - g.winStart >= (p.dur or 15) then g.winStart, g.cn = nil, 0 end
    local id = g.id
    local c = id and CostOf(id)
    if c and c > 0 then
        if not g.winStart then
            g.costUsual = c
        elseif g.costUsual and c > g.costUsual * 1.05 then
            g.rose = true   -- the cost does follow the stacks in this client
        elseif g.rose and g.lastCast and now - g.lastCast > 1 and c <= g.costUsual * 1.03 then
            g.winStart, g.cn = nil, 0   -- the cost is back to usual: the stacks are gone
        end
    end
    g.cn = g.cn or 0
    g.on = g.cn >= (p.stacks or 1)
    if g.winStart and ns.WakeAt then ns.WakeAt(g.winStart + (p.dur or 15)) end
end

local function CheckProc(p, now)
    local g = GS(p.key)
    local m = p.mode
    if m == "overlay" then CheckOverlay(p, g, now)
    elseif m == "faster" then CheckFaster(p, g)
    elseif m == "instant" then CheckInstantProc(g)
    elseif m == "free" then CheckFree(p, g)
    elseif m == "usable" then CheckUsable(p, g, now)
    elseif m == "reset" then CheckReset(p, g, now)
    elseif m == "casts" then CheckCasts(p, g, now) end
    if p.stacks then g.n = CountStacks(p, g) end
end

-- Whether the player has the spell a proc watches (otherwise its alert is built only if needed)
function ns.Knows(key)
    if key == "trance" then return S.sbId ~= nil end
    local g = G[key]
    if g and (g.id or (g.watch and #g.watch > 0)) then return true end
    local p = ns.PROC_BY[key]
    return not (p and (p.mode == "usable" or p.mode == "faster" or p.mode == "instant" or p.mode == "free" or p.mode == "reset" or p.mode == "casts"))
end

-- Spells that leave a free proc up when cast (0.23.28: Arcane Missiles and Clearcasting)
local NOT_SPENT = {}
for _, p in ipairs(ns.PROCS) do
    if p.notSpentBy then
        NOT_SPENT[p.key] = {}
        for _, sid in ipairs(p.notSpentBy) do NOT_SPENT[p.key][sid] = true end
    end
end

-- The spells of each mode that start a proc over, or end it, when cast (see the casts frame)
local CAST_MAP = {}     -- spell id -> list of { proc, role }
local function MapCast(id, p, role)
    local l = CAST_MAP[id]
    if not l then l = {}; CAST_MAP[id] = l end
    l[#l + 1] = { p = p, role = role }
end

-- A cast whose number isn't listed, but whose name is a listed spell's: the same roles (0.23.29,
-- higher ranks). Names are read once per number; built again when the spellbook changes.
local nameRoles, nameOf = nil, {}
local function NameOf(id)
    local n = nameOf[id]
    if n == nil then n = ns.SpellName(id) or false; nameOf[id] = n end
    return n or nil
end
local function RolesByName(id)
    if not nameRoles then
        nameRoles = {}
        for mid, roles in pairs(CAST_MAP) do
            local n = NameOf(mid)
            if n and not nameRoles[n] then nameRoles[n] = roles end
        end
    end
    local n = NameOf(id)
    return n and nameRoles[n] or nil
end
local function ResetCastNames()
    nameRoles = nil
    for k in pairs(nameOf) do nameOf[k] = nil end
end

-- 0.23.29 (CurseForge, luniumx: Arcane Blast gone after learning rank 2): a spell's higher ranks
-- can have numbers Shadowflare doesn't list (Forever made Arcane Blast a talent with ranks). The
-- player's own spell of the same name is found by its name, in the player's language.
local function InList(list, id)
    for _, v in ipairs(list) do if v == id then return true end end
    return false
end
local function KnownByName(id)
    local name = ns.SpellName(id)
    if not name or not (C_Spell and C_Spell.GetSpellInfo) then return nil end
    local ok, info = pcall(C_Spell.GetSpellInfo, name)
    local sid = ok and type(info) == "table" and num(info.spellID) or nil
    if not sid or ns.SpellName(sid) ~= name then return nil end
    local known = false
    if IsPlayerSpell then local okK, v = pcall(IsPlayerSpell, sid); known = okK and v end
    return known and sid or nil
end

local function LearnSpells()
    S.sbId = Known(ns.SB_IDS)
    local mine = ns.playerClass
    for _, p in ipairs(ns.PROCS) do
        if p.mode ~= "trance" and (not mine or p.class == mine) then
            local g = GS(p.key)
            g.id = p.cast and Known(p.cast) or nil
            if p.cast then
                local other = KnownByName(p.cast[1])
                if other and not InList(p.cast, other) then g.id = other end   -- a rank not listed
            end
            if p.refs then
                g.refIds = {}
                for _, list in ipairs(p.refs) do
                    local rid = Known(list)
                    if rid then g.refIds[#g.refIds + 1] = rid end
                end
            end
            if p.others then
                g.others = {}
                for _, list in ipairs(p.others) do
                    local oid = Known(list)
                    if oid then g.others[#g.others + 1] = oid end
                end
            end
            if p.watch then
                g.watch = {}
                for _, list in ipairs(p.watch) do
                    local wid = Known(list)
                    if wid then g.watch[#g.watch + 1] = wid end
                end
            end
            if p.mode == "usable" then S.ids[p.key] = g.id end
        end
    end
    -- kept for the test lines
    S.sfId = G.decimation and G.decimation.id
    S.immoId = G.decimation and G.decimation.refIds and G.decimation.refIds[2]
end

-- The talents changed: the usual speeds and costs are learned again
local function ForgetUsual()
    for _, g in pairs(G) do g.ratio, g.costBase, g.maxCt, g.maxCut = {}, {}, nil, nil end
end

----------------------------------------------------------------------
-- Sound. Either the game's own proc alert (its sound and its arcs), or one of ours,
-- or none. Ours turns the game's alert off so the two never overlap: the game plays
-- its sound only while its own alert is on (setting "displaySpellActivationOverlays").
-- Only a proc the game itself alerts for (Shadow Trance) offers the game's choice.
----------------------------------------------------------------------
ns.GAME_SOUND = 23287   -- the sound the game plays when its proc alert appears
ns.SOUNDS = {
    { key = "power",   id = 23287 },
    { key = "raid",    id = 8959 },
    { key = "ready",   id = 8960 },
    { key = "alarm",   id = 12889 },
    { key = "whisper", id = 3081 },
    { key = "ping",    id = 3175 },
}

local function SoundID(key)
    for _, s in ipairs(ns.SOUNDS) do if s.key == key then return s.id end end
end

function ns.PlaySoundID(id)
    if id then pcall(PlaySound, id, "Master") end
end

local function SetGameAlert(on)
    local v = on and "1" or "0"
    pcall(function()
        if C_CVar and C_CVar.SetCVar then C_CVar.SetCVar("displaySpellActivationOverlays", v)
        else SetCVar("displaySpellActivationOverlays", v) end
    end)
end

-- Sound when a proc starts. The game's choice plays nothing here: the game does it.
local function PlayAlert(cfg)
    ns.PlaySoundID(SoundID(cfg.soundChoice))
end
ns.PlayAlert = PlayAlert
ns.SetGameAlert = SetGameAlert
-- The game's alert follows the sound choice of the player's class proc that has one
-- (Shadow Trance for a warlock; Fingers of Frost for a mage, always on: its alert is its signal)
function ns.SyncGameAlert()
    local want
    for _, p in ipairs(ns.PROCS) do
        if p.gameAlert and p.class == ns.playerClass then
            want = p.gameSoundOnly or ns.Cfg(p.key).soundChoice == "game"
            break
        end
    end
    if want == nil then return end
    local ok, v = pcall(function()
        if C_CVar and C_CVar.GetCVar then return C_CVar.GetCVar("displaySpellActivationOverlays") end
        return GetCVar("displaySpellActivationOverlays")
    end)
    local on = ok and (v == "1" or v == 1 or v == true)
    if ok and v ~= nil and on ~= want then SetGameAlert(want) end
end

function ns.SetSound(key)
    local cfg, p = ns.Cur(), ns.PROC_BY[ns.Selected()]
    if key == "game" and not p.gameAlert then key = "power" end
    if p.gameSoundOnly then key = "game" end
    if p.mode == "aura" then key = "none" end
    cfg.soundChoice = key
    if p.gameAlert then ns.SyncGameAlert() end   -- decided by the player's own class proc
    if key == "game" then ns.PlaySoundID(ns.GAME_SOUND) else PlayAlert(cfg) end -- preview
    if ns.Options.Refresh then ns.Options:Refresh() end
end

----------------------------------------------------------------------
-- Debug only: what the game tells about the buff, the moment a proc is seen.
-- Runs once per proc and only with /flare debug on.
----------------------------------------------------------------------
local function desc(v)
    if v == nil then return "nil" end
    if secret(v) then return "secret" end
    local ok, t = pcall(tostring, v)
    return ok and t or "?"
end

local function Diagnose(key)
    if key ~= "trance" and key ~= "decimation" then return end
    local out = {}
    if key == "decimation" then
        out[#out + 1] = ("soul fire=%s (cast %s) - reference cast %s"):format(desc(S.sfId),
            desc(S.sfId and CastTime(S.sfId)), desc(S.sbId and CastTime(S.sbId)))
        ns.Print("diag: " .. table.concat(out, " - "))
        return
    end
    -- 1. direct question by spell number
    if not ByIdAPI then
        out[#out + 1] = "byId=absent"
    else
        local ok, a = pcall(ByIdAPI, TRANCE_ID)
        if not ok then out[#out + 1] = "byId=error(" .. desc(a) .. ")"
        elseif a == nil then out[#out + 1] = "byId=nil"
        else
            local ok2, id, n, e = pcall(function() return a.spellId, a.name, a.expirationTime end)
            out[#out + 1] = ok2 and ("byId=found(id " .. desc(id) .. ", name " .. desc(n) .. ", end " .. desc(e) .. ")")
                or ("byId=" .. desc(a))
        end
    end
    -- 2. the buff list, one by one
    local total, hidden, match = 0, 0, "no"
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 40 do
            local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
            if not ok then out[#out + 1] = "list=error at " .. i break end
            if not a then break end
            total = total + 1
            local sid, n = num(a.spellId), str(a.name)
            if sid == nil and n == nil then hidden = hidden + 1 end
            if sid == TRANCE_ID or (n and n == ns.tranceName) then match = "yes (" .. i .. ")" end
        end
        out[#out + 1] = ("list=%d buffs, %d unreadable, trance %s"):format(total, hidden, match)
    end
    -- 3. the older way
    if UnitBuffOld then
        local found = "no"
        for i = 1, 40 do
            local ok, n, _, _, _, _, _, _, _, sid = pcall(UnitBuffOld, "player", i)
            if not ok then found = "error" break end
            if n == nil then break end
            if num(sid) == TRANCE_ID or str(n) == ns.tranceName then found = "yes (" .. i .. ")" break end
        end
        out[#out + 1] = "unitbuff trance " .. found
    end
    out[#out + 1] = "overlay=" .. tostring(S.overlay) .. " glow=" .. tostring(S.glow)
    ns.Print("diag: " .. table.concat(out, " - "))
    pcall(ns.SecretProbe, "proc")
end

----------------------------------------------------------------------
-- Debug only: does this client hand out "secret" buff data that could be shown on
-- screen without being read (Blizzard's display-only rule)? Runs with /flare debug,
-- when a proc is detected, or with /flare probe.
----------------------------------------------------------------------
local function What(ok, v)
    if not ok then return "error" end
    if v == nil then return "nil" end
    if secret(v) then return "secret" end
    if type(v) == "table" then
        local n = 0
        for _ in pairs(v) do n = n + 1 if n > 50 then break end end
        local sid = rawget(v, "spellId")
        local first = rawget(v, 1)
        local extra = ""
        if sid ~= nil then extra = ", spellId " .. desc(sid) end
        if type(first) == "table" then
            extra = extra .. ", first: spellId " .. desc(rawget(first, "spellId")) .. ", name " .. desc(rawget(first, "name"))
        elseif first ~= nil then extra = extra .. ", first " .. desc(first) end
        return "table(" .. n .. extra .. ")"
    end
    return type(v) .. " " .. desc(v)
end

local auraNote = "none seen"
function ns.AuraEventNote(info)
    if type(info) ~= "table" then auraNote = "no details" return end
    if secret(info) then auraNote = "secret" return end
    local added = rawget(info, "addedAuras")
    local n = type(added) == "table" and #added or 0
    local first = n > 0 and added[1]
    auraNote = ("full=%s, added=%d%s"):format(desc(rawget(info, "isFullUpdate")), n,
        type(first) == "table" and (", spellId " .. desc(rawget(first, "spellId")) .. ", name " .. desc(rawget(first, "name"))
            .. ", id " .. desc(rawget(first, "auraInstanceID"))) or "")
end

function ns.SecretProbe(reason)
    local out = {}
    local tf = CreateFrame("Frame")
    local tx = tf:CreateTexture()
    out[#out + 1] = ("display-only: frame=%s, texture=%s, shown=%s, issecret=%s"):format(
        type(tf.SetAlphaFromBoolean) == "function" and "yes" or "no",
        type(tx.SetAlphaFromBoolean) == "function" and "yes" or "no",
        type(tf.SetShown) == "function" and "yes" or "no",
        type(issecretvalue) == "function" and "yes" or "no")
    local function names(t)
        if type(t) ~= "table" then return "absent" end
        local list = {}
        for k, v in pairs(t) do if type(v) == "function" then list[#list + 1] = tostring(k) end end
        table.sort(list)
        return #list .. " (" .. table.concat(list, ", ", 1, math.min(#list, 12)) .. (#list > 12 and ", ..." or "") .. ")"
    end
    out[#out + 1] = "C_CooldownViewer: " .. names(C_CooldownViewer)
    out[#out + 1] = "C_Secrets: " .. names(C_Secrets)
    local U = C_UnitAuras or {}
    local tname = ns.tranceName
    local calls = {
        { "byId", U.GetPlayerAuraBySpellID, TRANCE_ID },
        { "byName", U.GetAuraDataBySpellName, "player", tname, "HELPFUL" },
        { "buffIndex", U.GetBuffDataByIndex, "player", 1 },
        { "auraIndex", U.GetAuraDataByIndex, "player", 1, "HELPFUL" },
        { "unitAuras", U.GetUnitAuras, "player", "HELPFUL" },
        { "slots", U.GetAuraSlots, "player", "HELPFUL" },
    }
    for _, c in ipairs(calls) do
        if type(c[2]) ~= "function" then
            out[#out + 1] = c[1] .. "=absent"
        elseif c[1] == "byName" and not tname then
            out[#out + 1] = "byName=no name"
        else
            out[#out + 1] = c[1] .. "=" .. What(pcall(c[2], select(3, unpack(c))))
        end
    end
    out[#out + 1] = "last aura event: " .. auraNote
    out[#out + 1] = "in combat=" .. tostring(S.inCombat)
    ns.Print("|cff40c0fftest secret|r " .. (reason or "now") .. ": " .. table.concat(out, " - "))
    pcall(ns.SecrecyProbe)
    pcall(ns.ViewerProbe)
end

-- Which buffs the game marks as secret, asked by spell number (any class, from any
-- character). Spell numbers of other classes are the usual ones and may differ in Forever.
local AURA_IDS = {
    { "Shadow Trance", 17941 }, { "Decimation", 440870 }, { "Backlash", 34936 },
    { "Clearcasting mage", 12536 }, { "Clearcasting druid", 16870 }, { "Clearcasting shaman", 16246 },
    { "Missile Barrage", 44401 }, { "Hot Streak", 48108 }, { "Fingers of Frost", 44544 },
    { "Maelstrom Weapon", 53817 }, { "Infusion of Light", 54149 }, { "Eclipse", 408248 },
    { "Nature's Grace", 16886 }, { "Enrage", 12880 }, { "Flurry", 12966 },
}
function ns.SecrecyProbe()
    local CS = C_Secrets
    if type(CS) ~= "table" then return end
    local out = {}
    for _, a in ipairs(AURA_IDS) do
        local parts = {}
        if type(CS.ShouldSpellAuraBeSecret) == "function" then
            parts[#parts + 1] = "secret " .. What(pcall(CS.ShouldSpellAuraBeSecret, a[2]))
        end
        if type(CS.GetSpellAuraSecrecy) == "function" then
            parts[#parts + 1] = "level " .. What(pcall(CS.GetSpellAuraSecrecy, a[2]))
        end
        out[#out + 1] = a[1] .. " (" .. a[2] .. "): " .. table.concat(parts, ", ")
    end
    local g = {}
    for _, f in ipairs({ "HasSecretRestrictions", "ShouldAurasBeSecret", "ShouldCooldownsBeSecret" }) do
        if type(CS[f]) == "function" then g[#g + 1] = f .. "=" .. What(pcall(CS[f])) end
    end
    ns.Print("|cff40c0fftest secrecy|r " .. table.concat(g, ", "))
    -- several short lines, so the chat does not cut them
    for i = 1, #out, 5 do
        ns.Print("|cff40c0fftest secrecy|r " .. table.concat(out, " - ", i, math.min(i + 4, #out)))
    end
end

-- The game's own Cooldown Manager: does it show the proc, and can an addon see that?
function ns.ViewerProbe()
    local CV = C_CooldownViewer
    local head = {}
    if type(CV) == "table" and type(CV.IsCooldownViewerAvailable) == "function" then
        head[#head + 1] = "available=" .. What(pcall(CV.IsCooldownViewerAvailable))
    end
    if type(CV) == "table" and type(CV.GetCooldownViewerCategorySet) == "function" then
        for cat = 0, 3 do
            head[#head + 1] = "category " .. cat .. "=" .. What(pcall(CV.GetCooldownViewerCategorySet, cat, true))
        end
    end
    ns.Print("|cff40c0fftest viewer|r " .. table.concat(head, ", "))
    for _, name in ipairs({ "BuffIconCooldownViewer", "BuffBarCooldownViewer", "EssentialCooldownViewer", "UtilityCooldownViewer" }) do
        local v = _G[name]
        if not v then
            ns.Print("|cff40c0fftest viewer|r " .. name .. ": absent")
        else
            local kids = { pcall(v.GetChildren, v) }
            local total, shown, lines = 0, 0, {}
            for i = 2, #kids do
                local c = kids[i]
                total = total + 1
                local okS, isShown = pcall(c.IsShown, c)
                if okS and isShown == true then shown = shown + 1 end
                if #lines < 4 and okS and (isShown == true or secret(isShown)) then
                    local sid = "?"
                    for _, m in ipairs({ "GetSpellID", "GetAuraSpellID", "GetCooldownID" }) do
                        if type(c[m]) == "function" then sid = m .. " " .. What(pcall(c[m], c)) break end
                    end
                    lines[#lines + 1] = ("shown %s, alpha %s, %s, cooldownID %s"):format(desc(isShown),
                        What(pcall(c.GetAlpha, c)), sid, desc(rawget(c, "cooldownID")))
                end
            end
            ns.Print(("|cff40c0fftest viewer|r %s: shown=%s, %d items, %d shown%s"):format(name,
                desc(select(2, pcall(v.IsShown, v))), total, shown, #lines > 0 and (" - " .. table.concat(lines, " / ")) or ""))
        end
    end
end

----------------------------------------------------------------------
-- State: works out which alerts show, and until when
----------------------------------------------------------------------
local wakeAt, wakeToken = nil, 0
-- One wake-up at the next time something should end (aura end, test end). A later one
-- waits: the earlier wake-up refreshes everything and asks again.
local function WakeAt(t)
    if not t or t == wakeAt then return end
    local now = GetTime()
    if wakeAt and wakeAt > now and wakeAt < t then return end
    wakeAt = t
    wakeToken = wakeToken + 1
    local token = wakeToken
    C_Timer.After(math.max(0, t - now) + 0.05, function()
        if token == wakeToken then wakeAt = nil; ns.Refresh() end
    end)
end

ns.WakeAt = WakeAt
local PS = {}            -- per proc: active, startedAt, source
ns.procState = PS
ns.testUntil = {}        -- per proc: end of a test

-- Where each proc's signal comes from, or nil
local function SourceOf(key)
    if key == "trance" then
        if S.aura then return "aura"
        elseif S.overlay then return "overlay"
        elseif S.glow then return "glow"
        elseif S.instant and not (S.auraGoneAt and GetTime() - S.auraGoneAt < 0.6) then return "cast-time" end
    else
        local p, g = ns.PROC_BY[key], G[key]
        if not g then return nil end
        if p.mode == "usable" then return UsableSource(g, GetTime()) end
        -- Below its maximum: shown from the number of stacks the player chose
        if p.stacks and not g.on and g.n and g.n > 0 and g.n >= (ns.FromStacks(key) or p.stacks) then return "stacks" end
        if g.on then
            if p.mode == "reset" then return "reset" end
            if p.mode == "free" then return "cost" end
            if p.mode == "overlay" then return "overlay" end
            return "cast-time"
        end
    end
end

-- Grouped checks (0.20.1). The game sends some events many times a second in a fight (rage,
-- energy, mana, buffs), often several at the same moment. The first one is checked at once;
-- the ones that follow within 0.1 s are checked together, once, 0.1 s after the first.
-- Rare events (combat, casts, the game's proc alerts) are still checked at once.
local lastRefresh, refreshQueued = -1, false
local REFRESH_GAP = 0.1
local function RunQueued()
    refreshQueued = false
    lastRefresh = GetTime()
    ns.Refresh()
end
function ns.RequestRefresh()
    if refreshQueued then return end
    local now = GetTime()
    local wait = lastRefresh + REFRESH_GAP - now
    if wait <= 0 then lastRefresh = now; ns.Refresh() return end
    refreshQueued = true
    C_Timer.After(wait, RunQueued)
end

function ns.Refresh()
    if not ns.db then return end
    local now = GetTime()
    readCount = readCount + 1
    readStamp = readCount     -- each spell read once during this check
    -- A buff whose end time has passed is gone, even if the game's notice was missed
    if S.aura and S.auraExp and S.auraExp > 0 and now > S.auraExp + 0.5 then SetAura(false) end
    local mine = ns.playerClass
    if mine == "WARRIOR" then ns.UpdateStanceFeed() end   -- 0.23.27: the hit feed, only if wanted
    if mine == "WARLOCK" then CheckInstant() end
    for _, p in ipairs(ns.PROCS) do
        if p.class == mine and p.mode ~= "trance" then CheckProc(p, now) end
    end
    local anyActive = false
    for _, p in ipairs(ns.PROCS) do
        local key, cfg = p.key, ns.Cfg(p.key)
        local st = PS[key]
        if not st then st = {}; PS[key] = st end
        local wasActive = st.active
        local src = (ns.Mine(p) and cfg.enabled) and SourceOf(key) or nil
        local active = src ~= nil
        -- Only in combat (0.22.0, on by default): nothing shows or plays between fights. The proc
        -- is still followed, so one already up when a fight starts keeps its real time left.
        local hide = cfg.onlyCombat and not S.inCombat
        local g = G[key]
        local pdur = (p.mode == "reset" and ns.ShowFor(key)) or (ns.AuraShow and ns.AuraShow.Dur(key)) or p.dur or ns.DURATION
        -- 0.23.3 (seen by Ben on Victory Rush): a window ends when its time runs out, even if
        -- the game still says "usable" a moment longer (it often does, by a few tenths of a
        -- second). Before, the time started again at 20 s for that moment, then the alert went.
        -- Still usable 2 s after: a new kill, dodge or parry renewed it, it shows again.
        local owned = ns.AuraShow and ns.AuraShow.Owns(key)
        -- 0.23.12 (seen by Ben): waiting for its cooldown after a cast, out of combat nothing
        -- checked again at its end (no regular check then, and the game sends nothing: the
        -- spell stays "usable" the whole time). The alert came back seconds late, or not at all
        -- for a buff about to end. A check is now planned for the end of the cooldown.
        if g and g.wait and p.holdCd and g.castAt then WakeAt(g.castAt + (p.cd or 1) + 0.02) end
        -- Held back during its cooldown when the game shows it (0.23.5): cast, its frame goes
        -- with a burst; it comes back when the cooldown is over, if the buff is still there
        if p.gameHold and ns.AuraShow then
            local held = (g and g.wait) and true or false
            if held ~= (st.held or false) then
                st.held = held
                ns.AuraShow.Hold(key, held)
                if held and owned and st.active and not hide then
                    pcall(function() ns.Display:Get(key):PlayExit(true) end)
                end
            end
        end
        -- 0.23.27: a dodge or a parry seen in another stance is a new window for sure: none of
        -- the guards below (made for the game's late "yes") hold it back
        if g and g.trackAt then
            if st.spent and g.trackAt > st.spentAt then st.spent = nil end
            if st.ranOutAt and g.trackAt > st.ranOutAt then st.ranOutAt = nil end
        end
        -- (the game shows it: the game's own time left, nothing of this applies)
        if p.mode == "usable" and not p.noTimer and not owned then
            if active and st.active and st.startedAt and now >= st.startedAt + pdur then
                st.spent, st.spentAt = true, now
            end
            if st.spent then
                if not active then st.spent = nil                  -- the game said no: over
                elseif now - st.spentAt >= 2 then st.spent = nil   -- renewed: a new window
                else active = false; WakeAt(st.spentAt + 2) end
            end
        end
        -- 0.23.3: a usable proc that just ran out does not come back for a moment's "yes" from
        -- the game (it came back for about 0.2 s): within 1.5 s, the "yes" has to hold 0.5 s.
        -- Its time still counts from when the window opened.
        if p.mode == "usable" and not p.onTarget and not owned and active and not st.active and st.ranOutAt and now - st.ranOutAt < 1.5 then
            st.backAt = st.backAt or now
            if now - st.backAt < 0.5 then active = false; WakeAt(st.backAt + 0.5) end
        else
            st.backAt = nil
        end
        -- Shadow Bolt cast and still instant a moment later: a new proc came right after
        if key == "trance" and active and st.active and S.boltAt and S.boltAt > st.startedAt
            and now - S.boltAt > 0.3 and src == "cast-time" then
            st.active = false
        end
        if key == "trance" and S.boltAt and now - S.boltAt > 0.3 then S.boltAt = nil end
        -- Same for the other instant or free procs: cast, and still instant or free just after
        if g and g.castAt2 and key ~= "trance" then
            if active and st.active and g.castAt2 > st.startedAt and now - g.castAt2 > 0.3 then st.active = false end
            if now - g.castAt2 > 0.3 then g.castAt2 = nil end
        end
        -- Stacks (0.18.0): each new stack starts the time left again; the sound plays only
        -- when the maximum is reached
        local n = (active and p.stacks) and ((g and g.n and g.n > 0) and g.n or p.stacks) or nil
        if active and st.active and n and st.n and n > st.n then
            st.startedAt = (p.fromFirst and g and g.winStart) or now   -- Arcane Blast: from the first stack
            if n == p.stacks and not hide then PlayAlert(cfg); ns.Display:Accent(key) end
        end
        if active and not st.active then
            st.startedAt = (p.fromFirst and g and g.winStart) or now
            -- A warrior ability shown at the end of its cooldown: its window opened earlier
            if p.mode == "usable" and not p.noTimer and g and g.openAt and g.openAt < now then
                local pd = p.dur or ns.DURATION
                if now - g.openAt < pd then st.startedAt = g.openAt end
            end
            if (not n or n == p.stacks) and not hide then PlayAlert(cfg) end
            -- Came again while shown: the punch of its entrance (0.23.0)
            if wasActive and not hide then ns.Display:Accent(key) end
            if ns.debug then
                ns.Print(L.DETECTED:format(ns.Info(key).name .. ", " .. src))
                pcall(Diagnose, key)
            end
        elseif not active and st.active and ns.debug then
            ns.Print(L.ENDED)
        end
        st.active, st.source, st.n = active, src, n
        if key == "trance" then S.active, S.source = active, src end
        local endUsed = wasActive and not active and ns.UsedRecently(key)
        if wasActive and not active then st.ranOutAt = (not endUsed) and now or nil end
        if active then st.ranOutAt = nil end
        if hide then active = false end   -- followed, not shown

        local exp, dur
        local fromTest = false
        if active then
            anyActive = true
            if key == "trance" and S.aura and S.auraExp and S.auraExp > 0 then
                exp = S.auraExp
                dur = (S.auraDur and S.auraDur > 0) and S.auraDur or pdur
                WakeAt(exp + 0.55)   -- just after the safety margin above
            elseif p.noTimer then
                exp, dur = nil, pdur       -- a state (Execute...): no time left to show
            else
                exp, dur = st.startedAt + pdur, pdur
                if p.mode == "usable" then WakeAt(exp) end   -- ends right when its time runs out (0.23.3)
            end
        else
            local tu = ns.testUntil[key]
            if tu and now < tu then
                active, exp, dur, fromTest = true, tu, pdur, true
                n = p.stacks   -- a test shows the maximum
                WakeAt(exp)
                if p.noTimer then exp = nil end   -- no time left in game either (0.20.0)
            end
        end
        ns.Display:Set(key, active, exp, dur, fromTest, n, endUsed)
        if p.stanceTrack then ns.Display:SetHint(key, (active and not fromTest and g and g.stanceHint) or nil) end
    end
    readStamp = nil
    if ns.AuraShow then ns.AuraShow.SyncEnabled() end
    ns.anyActive = anyActive
    ns.UpdatePolling()
end

-- The light check: only in combat or while an alert is up, never otherwise
local ticker
local function Poll()
    -- Shadow Trance is a warlock's: only a warlock asks the game about its buff (0.20.1)
    if ns.isWarlock and not S.aura then AskGame() end   -- once found, the game's notices say when it leaves
    ns.Refresh()   -- the regular check never holds back the next event
end
function ns.UpdatePolling()
    local need = ns.hasProcs and (S.inCombat or ns.anyActive)   -- worked out once, at login
    if need and not ticker then
        ticker = C_Timer.NewTicker(0.2, Poll)
    elseif not need and ticker then
        ticker:Cancel()
        ticker = nil
    end
end

-- Shows the chosen proc's alert for 10 seconds
function ns.Test(key)
    key = key or ns.Selected()
    local p, cfg = ns.PROC_BY[key], ns.Cfg(key)
    ns.testUntil[key] = GetTime() + (p.dur or ns.DURATION)
    if cfg.soundChoice == "game" then ns.PlaySoundID(ns.GAME_SOUND) else PlayAlert(cfg) end
    ns.Refresh()
end

-- The sound of a proc, played on demand (the Play button of the settings, 0.22.0)
function ns.PlayChoice(key)
    local cfg = ns.Cfg(key or ns.Selected())
    if cfg.soundChoice == "game" then ns.PlaySoundID(ns.GAME_SOUND) else PlayAlert(cfg) end
end

-- Reset (0.22.0): the proc's look back to its defaults. Kept: whether it is on, its place and
-- size on screen (and those of its time left and number of stacks).
local KEEP = { "enabled", "enabledByUser", "x", "y", "scale", "tox", "toy", "timerSize", "sox", "soy", "stackSize" }
function ns.ResetLook(key)
    key = key or ns.Selected()
    local old = ns.procs[key] or {}
    local t = {}
    for _, k in ipairs(KEEP) do t[k] = old[k] end
    ns.procs[key] = t
    local c = ns.Cfg(key)   -- the defaults fill the rest
    if ns.moving then ns.Display:SetMoving(false) end
    local a = ns.Display:Get(key)
    a:ApplyPosition()
    a:ApplyLook()
    ns.SyncGameAlert()
    if ns.AuraShow then pcall(ns.AuraShow.Apply, key) end
    ns.Refresh()
    if ns.Options.Refresh then ns.Options:Refresh() end
    return c
end

-- A setting of the chosen proc changed
function ns.SetOption(key, value)
    ns.Cur()[key] = value
    local a = ns.Display:Get(ns.Selected())
    a:ApplyPosition()
    a:ApplyLook()
    if ns.Options.Refresh then ns.Options:Refresh() end
end

-- The options page now shows another proc
function ns.Select(key)
    if not ns.PROC_BY[key] then return end
    if ns.moving then ns.Display:SetMoving(false) end
    ns.db.selected = key
    if ns.Options.Refresh then ns.Options:Refresh() end
end

----------------------------------------------------------------------
-- Profiles: named sets of settings for every proc. Each character uses one; a character
-- that never picked one uses the default profile (the first one, from before profiles).
----------------------------------------------------------------------
-- 0.23.1: characters are told apart by their unique ID (GUID). In Forever, characters can share
-- a first name and differ by their surname, so "Name - Realm" (the key up to 0.23.0) mixed them up.
local function Realm() return str(GetRealmName and GetRealmName()) end
function ns.OldCharKey()   -- the key up to 0.23.0: first name and realm
    local n, r = str(UnitName and UnitName("player")), Realm()
    if n and r and n ~= "" and r ~= "" and n ~= UNKNOWNOBJECT then return n .. " - " .. r end
end
function ns.CharKey()
    if not UnitGUID then return ns.OldCharKey() end   -- no IDs in this client: the old key
    local ok, g = pcall(UnitGUID, "player")
    g = ok and str(g) or nil
    if g and g ~= "" then return g end
end
-- The character's full name, the way the game shows it: first name and surname
function ns.CharFullName()
    if not UnitName then return nil end
    local ok, n, sur = pcall(UnitName, "player")
    if not ok then return nil end
    n, sur = str(n), str(sur)
    if not n or n == "" or n == UNKNOWNOBJECT then return nil end
    if not sur or sur == "" or sur == Realm() or n:sub(-#sur) == sur then return n end
    local sep = " "
    pcall(function()
        local s = Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR
        if type(s) == "string" and s ~= "" then sep = s end
    end)
    return n .. sep .. sur
end
-- Remembers how to show this character in the options (full name, realm, class)
function ns.NoteChar()
    local db, ck = ns.db, ns.CharKey()
    if not (db and ck) then return end
    local name = ns.CharFullName()
    if not name then return end
    if type(db.charInfo) ~= "table" then db.charInfo = {} end
    local _, class = UnitClass("player")
    db.charInfo[ck] = { name = name, realm = Realm(), class = str(class) }
end
-- A character as the options show it: "Firstname Surname - Realm"
function ns.CharLabel(ck)
    local i = ns.db and type(ns.db.charInfo) == "table" and ns.db.charInfo[ck]
    if type(i) ~= "table" or type(i.name) ~= "string" then return nil end
    if type(i.realm) == "string" and i.realm ~= "" then return i.name .. " - " .. i.realm, i.class end
    return i.name, i.class
end
-- The profile this character picked. A character from before 0.23.1 has none under its ID
-- yet: it takes the one saved under its first name (kept for now, so a second character with
-- the same first name finds it too). Otherwise nil, and the default profile is used.
function ns.CharProfile()
    local db, ck = ns.db, ns.CharKey()
    if ck and db.chars[ck] ~= nil then return db.chars[ck] end
    local old = ns.OldCharKey()
    if old then return db.chars[old] end
end
-- The characters that use a profile (only those whose full name is known)
function ns.ProfileChars(profile)
    local t = {}
    for ck, pn in pairs(ns.db.chars) do
        if pn == profile then
            local label, class = ns.CharLabel(ck)
            if label then t[#t + 1] = { key = ck, label = label, class = class } end
        end
    end
    table.sort(t, function(a, b) return a.label:lower() < b.label:lower() end)
    return t
end

function ns.ProfileNames()
    local t = {}
    for n, v in pairs(ns.db.profiles) do
        if type(n) == "string" and type(v) == "table" then t[#t + 1] = n end
    end
    table.sort(t, function(a, b) return a:lower() < b:lower() end)
    return t
end

-- The profile a character falls back on: the default one, else the first, else a new one
function ns.FallbackProfile()
    local db = ns.db
    if type(db.defaultProfile) == "string" and type(db.profiles[db.defaultProfile]) == "table" then
        return db.defaultProfile
    end
    local first = ns.ProfileNames()[1]
    if not first then
        first = L.PROFILE_DEFAULT
        db.profiles[first] = { procs = {}, anim023 = true, anim0232 = true, ab0234 = true }
    end
    db.defaultProfile = first
    return first
end

-- Points the settings at a profile (data only; see ns.SwitchProfile for the screen)
function ns.UseProfile(name)
    local db = ns.db
    if type(name) ~= "string" or type(db.profiles[name]) ~= "table" then name = ns.FallbackProfile() end
    local prof = db.profiles[name]
    if type(prof.procs) ~= "table" then prof.procs = {} end
    ns.profileName, ns.procs = name, prof.procs
    local ck = ns.CharKey()
    if ck then db.chars[ck] = name; ns.NoteChar() end
end

----------------------------------------------------------------------
-- Saved settings
----------------------------------------------------------------------
-- Which alerts are on (0.22.0, asked by Ben). On a first install only the character's class
-- (and the weapon and enchant alerts, for every class) are on. A profile is shared by several
-- characters: the first time a class logs in with it, that class's alerts are switched on,
-- except those the player switched off himself. Profiles from before 0.22.0 keep their choices.
function ns.FirstSight()
    local mine = ns.playerClass
    local prof = ns.db and ns.db.profiles[ns.profileName]
    if not (mine and prof) then return end
    if type(prof.seen) ~= "table" then
        prof.seen = {}
        if ns.freshInstall then
            for _, p in ipairs(ns.PROCS) do
                local c = ns.Cfg(p.key)
                if not c.enabledByUser then c.enabled = (p.class == mine and not (p.defaults and p.defaults.enabled == false)) and true or false end
            end
        else
            for _, c in ipairs(ns.CLASSES) do prof.seen[c] = true end   -- upgrade: nothing changes
        end
    end
    if not prof.seen[mine] then
        for _, p in ipairs(ns.PROCS) do
            if p.class == mine then
                local c = ns.Cfg(p.key)
                -- 0.23.16: an alert off by default (Conflagrate) stays off until ticked
                if c.enabled == false and not c.enabledByUser and not (p.defaults and p.defaults.enabled == false) then c.enabled = true end
            end
        end
    end
    prof.seen[mine] = true
end
-- A tick in the list of alerts: remembered as the player's own choice
function ns.SetEnabled(key, on)
    local c = ns.Cfg(key)
    c.enabled, c.enabledByUser = on and true or false, true
    local a = ns.Display:Get(key)
    if a then a:ApplyLook() end
    -- 0.23.28: an alert switched off has no game frame; ticked, it gets one now (out of combat,
    -- else after the fight)
    if on and ns.AuraShow and ns.PROC_BY[key] then pcall(ns.AuraShow.Setup, ns.PROC_BY[key]) end
    ns.Refresh()
    if ns.Options.Refresh then ns.Options:Refresh() end
end
function ns.InCombat() return S.inCombat and true or false end

local function LoadSettings()
    ns.freshInstall = (ShadowflareDB == nil) -- nothing saved yet: first install, no notes
    local db = ShadowflareDB or {}
    ShadowflareDB = db
    for k, v in pairs(GLOBAL_DEFAULTS) do
        if db[k] == nil then db[k] = v end
    end
    if type(db.procs) ~= "table" then
        -- From 0.8 and before: one set of settings, Shadow Trance's
        db.procs = {}
        local t = {}
        for _, k in ipairs(OLD_KEYS) do
            if db[k] ~= nil then t[k] = db[k] end
        end
        if next(t) then db.procs.trance = t end
    end
    for _, k in ipairs(OLD_KEYS) do db[k] = nil end
    -- From 0.11 and before: one set of settings for the whole account, now the first profile
    if type(db.profiles) ~= "table" then
        db.profiles = { [L.PROFILE_DEFAULT] = { procs = db.procs } }
        db.defaultProfile = L.PROFILE_DEFAULT
    end
    db.procs = nil
    if type(db.chars) ~= "table" then db.chars = {} end
    if type(db.charInfo) ~= "table" then db.charInfo = {} end
    ns.MigrateAnims(db)
    ns.db = db
    ns.UseProfile(ns.CharProfile())
    local tr = ns.Cfg("trance")
    if tr.style == "blizzard" then tr.style = "blz449492" end
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
local f = CreateFrame("Frame")
local function Reg(e) pcall(f.RegisterEvent, f, e) end
local DETECTION = {
    "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE",
    "SPELL_ACTIVATION_OVERLAY_SHOW", "SPELL_ACTIVATION_OVERLAY_HIDE",
    "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
    "SPELL_UPDATE_USABLE", "ACTIONBAR_UPDATE_USABLE", "UPDATE_SHAPESHIFT_FORM",
    "PLAYER_TARGET_CHANGED",   -- 0.23.16: alerts that follow the target are checked at once
}
Reg("ADDON_LOADED")
Reg("PLAYER_LOGIN")
for _, e in ipairs(DETECTION) do Reg(e) end
-- The player's buffs only (never the target's, the party's or the nameplates')
if not (f.RegisterUnitEvent and pcall(f.RegisterUnitEvent, f, "UNIT_AURA", "player")) then Reg("UNIT_AURA") end
-- A weapon's name comes from the game a moment after it is asked for (0.20.0)
local items = CreateFrame("Frame")
pcall(items.RegisterEvent, items, "GET_ITEM_INFO_RECEIVED")
items:SetScript("OnEvent", function(_, _, id)
    if not ns.db then return end
    for _, p in ipairs(ns.PROCS) do
        if p.item and p.item == id then UpdateInfo() return end
    end
end)
-- The player's own casts: a Shadow Bolt ends the proc, or shows that a new one came right after
local casts = CreateFrame("Frame")
if casts.RegisterUnitEvent then pcall(casts.RegisterUnitEvent, casts, "UNIT_SPELLCAST_SUCCEEDED", "player") end
-- Which spells matter to which proc when cast
for _, p in ipairs(ns.PROCS) do
    if p.mode == "usable" and p.hideOnCast ~= false then
        for _, sid in ipairs(p.cast) do MapCast(sid, p, "used") end
    elseif p.mode == "instant" then
        for _, sid in ipairs(p.cast) do MapCast(sid, p, "spent") end
    elseif p.mode == "free" then
        for _, list in ipairs(p.watch) do for _, sid in ipairs(list) do MapCast(sid, p, "spent") end end
    elseif p.mode == "reset" then
        for _, sid in ipairs(p.cast) do MapCast(sid, p, "reset") end
    elseif p.mode == "casts" then
        for _, sid in ipairs(p.cast) do MapCast(sid, p, "stack") end
    end
    for _, sid in ipairs(p.renew or {}) do MapCast(sid, p, "renew") end
end

-- The spells that use up each proc (0.23.0: a proc that ends just after one was used, else it
-- ran out; its way out differs)
local USE_MAP = {}
for _, p in ipairs(ns.PROCS) do
    local function add(sid) local l = USE_MAP[sid]; if not l then l = {}; USE_MAP[sid] = l end; l[#l + 1] = p.key end
    if p.mode ~= "casts" then   -- Arcane Blast's casts add stacks, they don't use it up
        for _, sid in ipairs(p.cast or {}) do add(sid) end
        for _, list in ipairs(p.watch or {}) do for _, sid in ipairs(list) do add(sid) end end
    end
end
function ns.UsedRecently(key)
    local g = G[key]
    return g and g.usedAt and GetTime() - g.usedAt < 0.8 or false
end

casts:SetScript("OnEvent", function(_, _, unit, _, spellID)
    if unit ~= "player" or not ns.db then return end
    local id = num(spellID)
    if not id then return end
    local now = GetTime()
    local users = USE_MAP[id]
    if users then for _, k in ipairs(users) do GS(k).usedAt = now end end
    for _, p in ipairs(ns.PROCS) do   -- a free spell is used by any cast
        if p.mode == "free" and PS[p.key] and PS[p.key].active then GS(p.key).usedAt = now end
    end
    if SB[id] then GS("trance").usedAt = now end
    local roles = CAST_MAP[id] or RolesByName(id)
    if roles then
        local refresh = false
        for _, r in ipairs(roles) do
            local p, g, st = r.p, GS(r.p.key), PS[r.p.key]
            if r.role == "used" then
                -- A usable proc cast: its alert goes at once
                g.wait, g.castAt = true, now
                refresh = true
            elseif r.role == "reset" then
                -- The spell whose cooldown can be reset (Stormstrike): its cooldown starts now,
                -- and a reset alert still up goes
                g.castAt, g.on = now, false
                refresh = true
                -- /flare debug: whether this client tells if the spell is on cooldown
                if ns.debug then
                    C_Timer.After(2, function()
                        ns.Print(("%s on cooldown 2 s after the cast: %s"):format(ns.SpellName(id) or tostring(id), tostring(ns.CdActive(id))))
                    end)
                end
            elseif r.role == "stack" then
                -- A cast that adds a stack (Arcane Blast): the first one starts the 15 s
                if not g.winStart or now - g.winStart >= (p.dur or 15) then g.winStart, g.cn, g.rose = now, 0, false end
                g.cn = math.min((g.cn or 0) + 1, p.stacks or 1)
                g.lastCast = now
                refresh = true
            elseif r.role == "renew" then
                -- Cast again while the proc lasts (Decimation: Shadow Bolt or Searing Pain
                -- on a target below 35%): its time left starts again
                if st and st.active then st.startedAt = now; refresh = true end
            elseif r.role == "spent" and st and st.active then
                -- The spell it speeds up or makes free: if it is still so a moment later,
                -- a new proc came right after
                g.castAt2 = now
                C_Timer.After(0.1, ns.Refresh)
                C_Timer.After(0.35, ns.Refresh)
            end
        end
        if refresh then ns.Refresh() end
        -- Several procs can share a spell (Shadow Bolt): go on for Shadow Trance
    end
    -- Any cast can end a free proc (Clearcasting is used by the next spell, whichever it is)
    local freeUp = false
    for _, p in ipairs(ns.PROCS) do
        local st = PS[p.key]
        if p.mode == "free" and st and st.active and not (NOT_SPENT[p.key] and NOT_SPENT[p.key][id]) then
            GS(p.key).castAt2 = now   -- still free just after: a new proc came from this cast
            freeUp = true
        end
    end
    if freeUp then
        C_Timer.After(0.1, ns.Refresh)
        C_Timer.After(0.35, ns.Refresh)
    end
    if not (SB[id] and S.active) then return end
    S.boltAt = GetTime()
    -- The cast time changes a moment after the cast: look again just after
    C_Timer.After(0.1, ns.Refresh)
    C_Timer.After(0.35, ns.Refresh)
end)

local FREQUENT = { SPELL_UPDATE_USABLE = true, ACTIONBAR_UPDATE_USABLE = true, UPDATE_SHAPESHIFT_FORM = true }

-- A buff change on the player. In combat Forever can hand back the event's details as
-- secret values (0.13.0: "isFullUpdate" made an error on every Rejuvenation or shapeshift),
-- so each one is checked before use, and anything unexpected falls back to asking the game.
local function OnAuraEvent(info)
    local partial = false
    if type(info) == "table" then
        local full = info.isFullUpdate
        if secret(full) then
            AskGame()   -- details hidden: only the game's direct answer
            return
        end
        partial = not full
    end
    if partial then
        AuraChanges(info)
        if S.via ~= "list" then AskGame() end   -- the game's direct answer, whatever the list said
    else
        FullScan(type(info) == "table")
    end
end

f:SetScript("OnEvent", function(_, event, a1, a2)
    if event == "UNIT_AURA" then
        if a1 ~= "player" then return end
        if ns.debug and ns.AuraEventNote then pcall(ns.AuraEventNote, a2) end
        -- Only Shadow Trance is read from buffs; the other procs are just looked at again
        -- (stealth, shapeshift...)
        if ns.isWarlock and not pcall(OnAuraEvent, a2) then pcall(AskGame) end
        -- Out of combat the buffs can be read: learn the numbers of the procs' buffs
        if not S.inCombat and ns.AuraShow then ns.AuraShow.QueueScan() end
        ns.RequestRefresh()
        return
    end
    if event == "ADDON_LOADED" then
        if a1 ~= ADDON then return end
        LoadSettings()
        ns.Display:Init()
        ns.Options:Init()
        f:UnregisterEvent("ADDON_LOADED")
        return
    end
    if not ns.db then return end

    if event == "PLAYER_LOGIN" then
        local _, class = UnitClass("player")
        ns.playerClass = class
        ns.hasProcs = ns.Has(class)
        ns.isWarlock = class == "WARLOCK"
        -- The character's ID is surely known now: its own profile, else the default one
        ns.UseProfile(ns.CharProfile())
        ns.FirstSight()   -- which alerts are on, the first time (0.22.0)
        -- A warlock: the game's own proc alert follows this profile's Shadow Trance sound
        ns.SyncGameAlert()
        -- The options open on a proc of the player's class
        local sel = ns.PROC_BY[ns.db.selected]
        if not sel or (sel.class ~= class and not sel.gear and ns.Has(class)) then
            for _, p in ipairs(ns.PROCS) do if p.class == class then ns.db.selected = p.key break end end
        end
        UpdateInfo()
        LearnSpells()
        if S.sbId then CheckInstant() end
        if not ns.db.welcomed then
            ns.Print(L.LOADED)
            ns.db.welcomed = true
        end
        ns.Display:Prepare(class)   -- the alerts of this class, built now so a proc never waits
        if ns.Has(class) and ns.AuraShow then pcall(ns.AuraShow.Init) end
        if not ns.Has(class) then
            -- No proc for this class: nothing to watch, so nothing is listened to
            f:UnregisterAllEvents()
            casts:UnregisterAllEvents()
        end
        return
    elseif event == "SPELLS_CHANGED" then
        ResetCastNames()
        LearnSpells()
        if not ns.tranceName then UpdateInfo() end
        if S.sbId and not castBase then CheckInstant() end
    elseif event == "CHARACTER_POINTS_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
        ForgetUsual()      -- usual speeds and costs (Soul Fire...) are learned again
        LearnSpells()
    elseif event == "PLAYER_ENTERING_WORLD" then
        FullScan(true)
        S.inCombat = UnitAffectingCombat and UnitAffectingCombat("player") and true or false
        if ns.AuraShow then ns.AuraShow.QueueScan() end
    elseif event == "PLAYER_REGEN_DISABLED" then
        S.inCombat = true
        if ns.AuraShow then ns.AuraShow.CombatChanged(true) end
        if ns.AuraShow then ns.AuraShow.ApplyAll() end   -- "Only in combat": the game's frames show again
    elseif event == "PLAYER_REGEN_ENABLED" then
        S.inCombat = false
        if ns.AuraShow then ns.AuraShow.CombatChanged(false) end
        if ns.AuraShow then ns.AuraShow.ApplyAll() end
        -- Buffs readable again: a proc still up after the fight teaches its buff's number
        if ns.AuraShow then ns.AuraShow.QueueScan() end
    elseif event == "SPELL_ACTIVATION_OVERLAY_SHOW" then
        local id = num(a1)
        if ns.debug then ns.Print("game proc alert shown: spell " .. desc(id) .. " (" .. tostring(id and ns.SpellName(id)) .. ")") end
        local op = id and OVERLAY_MAP[id]
        if op then
            local g = GS(op.key)
            g.on, g.onAt = true, GetTime()
            ns.Refresh()
            return
        end
        if id ~= TRANCE_ID then return end
        S.overlay = true
        local tex = num(a2) or str(a2)
        if tex then ns.db.blizzTex = tex end
    elseif event == "SPELL_ACTIVATION_OVERLAY_HIDE" then
        local id = num(a1)
        if ns.debug then ns.Print("game proc alert hidden: spell " .. desc(id)) end
        local op = id and OVERLAY_MAP[id]
        if op then
            GS(op.key).on = false
            ns.Refresh()
            return
        end
        if id == nil then
            for _, q in pairs(OVERLAY_MAP) do GS(q.key).on = false end
        end
        if not (id == nil or id == TRANCE_ID) then return end
        S.overlay = false
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
        local id = num(a1)
        if ns.debug then ns.Print("game button glow: spell " .. desc(id) .. " (" .. tostring(id and ns.SpellName(id)) .. ")") end
        if not (id and (SB[id] or id == TRANCE_ID)) then return end
        S.glow = true
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        local id = num(a1)
        if not (id == nil or SB[id] or id == TRANCE_ID) then return end
        S.glow = false
    end
    -- The events that come many times a second in a fight are grouped; the rare ones
    -- (combat start and end, the game's proc alerts, talents) are checked at once
    if FREQUENT[event] then ns.RequestRefresh() else ns.Refresh() end
end)

-- Whether a proc is for this character: its class, or a weapon or enchant (every class)
function ns.Mine(p)
    return p.class == ns.playerClass or (p.gear == true and ns.playerClass ~= nil)
end

-- Whether Shadowflare has at least one proc for a class
function ns.Has(class)
    for _, p in ipairs(ns.PROCS) do if p.class == class then return true end end
    return false
end

----------------------------------------------------------------------
-- Warrior test (debug only): what the game tells addons about Overpower and Revenge,
-- in and out of combat. Nothing runs unless /flare debug is on, on a warrior.
-- Printed only when something changes.
----------------------------------------------------------------------
local OVERPOWER, REVENGE = ns.OVERPOWER_IDS, ns.REVENGE_IDS
local probe = CreateFrame("Frame")
local probeLast, probeTicker, probeStarted = {}, nil, false

local function Usable(id)
    if C_Spell and C_Spell.IsSpellUsable then
        local ok, u, noPower = pcall(C_Spell.IsSpellUsable, id)
        if ok then return "C_Spell", u, noPower end
        return "C_Spell", "error", desc(u)
    end
    if IsUsableSpell then
        local ok, u, noPower = pcall(IsUsableSpell, id)
        if ok then return "IsUsableSpell", u, noPower end
        return "IsUsableSpell", "error", desc(u)
    end
    return "none"
end

local function Cooldown(id)
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, cd = pcall(C_Spell.GetSpellCooldown, id)
        if ok and type(cd) == "table" then
            local st, du = num(cd.startTime), num(cd.duration)
            if st and du then return (st > 0 and du > 1.6) and ("%.1f"):format(st + du - GetTime()) or "0" end
            return "secret"
        end
        return ok and "nil" or "error"
    end
    if GetSpellCooldown then
        local ok, st, du = pcall(GetSpellCooldown, id)
        if ok then
            st, du = num(st), num(du)
            if st and du then return (st > 0 and du > 1.6) and ("%.1f"):format(st + du - GetTime()) or "0" end
            return "secret"
        end
        return "error"
    end
    return "none"
end

local function ProbeOne(label, list)
    local id = Known(list)
    if not id then return label .. ": not known" end
    local api, u, noPower = Usable(id)
    local form = GetShapeshiftForm and select(2, pcall(GetShapeshiftForm)) or "?"
    return ("%s (%d): usable=%s, no rage=%s, cooldown=%s, stance=%s [%s]"):format(
        label, id, desc(u), desc(noPower), Cooldown(id), desc(form), api)
end

local function Probe(reason)
    if not ns.debug then return end
    for _, item in ipairs({ { "Overpower", OVERPOWER }, { "Revenge", REVENGE } }) do
        local line = ProbeOne(item[1], item[2])
        -- the cooldown counts down: compare without it
        local key = line:gsub("cooldown=[%d%.]+", "cooldown=x")
        if key ~= probeLast[item[1]] then
            probeLast[item[1]] = key
            ns.Print("|cffff8040test|r " .. line .. (reason and (" - " .. reason) or ""))
        end
    end
end
ns.WarriorProbe = Probe

function ns.StartWarriorProbe()
    if probeStarted then return end
    probeStarted = true
    for _, e in ipairs({ "SPELL_UPDATE_USABLE", "ACTIONBAR_UPDATE_USABLE", "SPELL_UPDATE_COOLDOWN",
                         "UPDATE_SHAPESHIFT_FORM", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
        pcall(probe.RegisterEvent, probe, e)
    end
    probe:SetScript("OnEvent", function(_, event)
        if not ns.debug then return end
        if event == "PLAYER_REGEN_DISABLED" then
            ns.Print("|cffff8040test|r combat starts")
            probeLast = {}
        elseif event == "PLAYER_REGEN_ENABLED" then
            ns.Print("|cffff8040test|r combat ends")
        end
        Probe(event == "UPDATE_SHAPESHIFT_FORM" and "stance changed" or nil)
    end)
    -- Also every 0.2 s, in case the game sends no event
    probeTicker = C_Timer.NewTicker(0.2, function() if ns.debug then Probe() end end)
end

----------------------------------------------------------------------
-- Debug only: can the game's spell cost be read in combat? (for procs that make a
-- spell free, such as Clearcasting). Each spell cast prints its cost once out of
-- combat and once in combat.
----------------------------------------------------------------------
local costFrame, costSeen = CreateFrame("Frame"), {}
local function CostLine(id)
    local parts = {}
    if C_Spell and C_Spell.GetSpellPowerCost then
        local ok, t = pcall(C_Spell.GetSpellPowerCost, id)
        if not ok then return "C_Spell: error" end
        if type(t) ~= "table" then return "C_Spell: " .. desc(t) end
        if secret(t) then return "C_Spell: secret" end
        for i = 1, 3 do
            local c = t[i]
            if type(c) ~= "table" then break end
            parts[#parts + 1] = ("cost=%s, type=%s, min=%s, percent=%s"):format(
                desc(c.cost), desc(c.name or c.type), desc(c.minCost), desc(c.costPercent))
        end
        if #parts == 0 then return "C_Spell: no cost" end
        return "C_Spell: " .. table.concat(parts, " / ")
    end
    if GetSpellPowerCost then
        local ok, t = pcall(GetSpellPowerCost, id)
        if not ok then return "old API: error" end
        if type(t) == "table" and type(t[1]) == "table" then
            return ("old API: cost=%s, type=%s"):format(desc(t[1].cost), desc(t[1].name or t[1].type))
        end
        return "old API: " .. desc(t)
    end
    return "no API"
end
-- Listened to only once /flare debug is on
local function StartCostProbe()
    if costFrame.RegisterUnitEvent then pcall(costFrame.RegisterUnitEvent, costFrame, "UNIT_SPELLCAST_SUCCEEDED", "player") end
end
costFrame:SetScript("OnEvent", function(_, _, unit, _, spellID)
    if not ns.debug or unit ~= "player" then return end
    local id = num(spellID)
    if not id then return end
    local fight = S.inCombat or (UnitAffectingCombat and UnitAffectingCombat("player")) or false
    local key = id .. (fight and "c" or "o")
    if costSeen[key] then return end
    costSeen[key] = true
    local name = ns.SpellName(id) or tostring(id)
    local ok, line = pcall(CostLine, id)
    ns.Print(("|cff40c0fftest cost|r %s (%d), %s: %s"):format(tostring(name), id,
        fight and "in combat" or "out of combat", ok and line or "error"))
end)

----------------------------------------------------------------------
-- /flare ids (0.23.22): every spell and buff number Shadowflare uses, with the name this
-- client gives it, in a box to copy. Made to check the released game against the beta in one
-- go, on any character: the game names every spell, whatever the class. "?" = not in this client.
----------------------------------------------------------------------
local ID_SINGLE = { "spell", "buffIds", "overlayIds", "enchantSpell" }   -- each number named
local ID_RANKS = { "cast", "refs", "watch", "others", "renew" }          -- lists of spell ranks
local function IdName(id)
    local n = ns.SpellName(id)
    if n then return (n:gsub("[|;]", "/")) end
    return "?"
end
function ns.IdsReport()
    local lines, missing = {}, 0
    local okB, ver, build, _, toc = pcall(GetBuildInfo)
    lines[1] = ("Shadowflare %s - client %s (%s) - interface %s - %s"):format(ns.version,
        tostring(okB and ver), tostring(okB and build), tostring(okB and toc), tostring(GetLocale and GetLocale()))
    for _, p in ipairs(ns.PROCS) do
        local parts = { p.class .. " " .. p.key }
        for _, f in ipairs(ID_SINGLE) do
            local v = p[f]
            local list = type(v) == "number" and { v } or (type(v) == "table" and v or nil)
            if list then
                local t = {}
                for _, id in ipairs(list) do
                    local n = IdName(id)
                    if n == "?" then missing = missing + 1 end
                    t[#t + 1] = id .. "=" .. n
                end
                parts[#parts + 1] = f .. " " .. table.concat(t, ",")
            end
        end
        for _, f in ipairs(ID_RANKS) do
            local v = p[f]
            if type(v) == "table" then
                -- one list of ranks, or a list of lists (refs, watch, others)
                local lists = type(v[1]) == "table" and v or { v }
                for _, l in ipairs(lists) do
                    if type(l) == "table" and #l > 0 then
                        local found, miss, name = 0, {}, nil
                        for _, id in ipairs(l) do
                            local n = IdName(id)
                            if n == "?" then miss[#miss + 1] = id; missing = missing + 1
                            else found = found + 1; name = name or n end
                        end
                        parts[#parts + 1] = ("%s %s %d/%d%s"):format(f, name or "?", found, #l,
                            #miss > 0 and (" miss " .. table.concat(miss, ",")) or "")
                    end
                end
            end
        end
        if p.item then
            local get = C_Item and C_Item.GetItemNameByID
            local okI, n = false, nil
            if get then okI, n = pcall(get, p.item) end
            parts[#parts + 1] = "item " .. p.item .. "=" .. tostring(okI and str(n) or "?")
        end
        lines[#lines + 1] = table.concat(parts, " ; ")
    end
    return table.concat(lines, " ## "), missing   -- no "|": the game reads it as a code
end

local function ShowIds()
    local ok, text, missing = pcall(ns.IdsReport)
    if not ok then ns.Print("ids: " .. tostring(text)) return end
    ns.Print(L.IDS_DONE:format(missing))
    ns.Ask({ title = L.IDS_TITLE, text = L.IDS_TEXT, edit = true, value = text, readOnly = true,
        okText = CLOSE or "Close", cancelText = false })
end

----------------------------------------------------------------------
-- Slash command
----------------------------------------------------------------------
local function MemoryKB()
    local ok = pcall(UpdateAddOnMemoryUsage)
    if not ok then return nil end
    local get = (C_AddOns and C_AddOns.GetAddOnMemoryUsage) or GetAddOnMemoryUsage
    local ok2, kb = pcall(get, ADDON)
    return ok2 and num(kb) or nil
end

SLASH_SHADOWFLARE1 = "/flare"
SLASH_SHADOWFLARE2 = "/shadowflare"
SLASH_SHADOWFLARE3 = "/trance"
SlashCmdList.SHADOWFLARE = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "notes" then
        ns.ShowNotes(nil)
    elseif msg == "test" then
        ns.Test()
    elseif msg == "move" or msg == "unlock" or msg == "lock" then
        if ns.moving then ns.Display:SetMoving(false) else ns.Display:StartPlacing(false) end
    elseif msg == "center" or msg == "reset" then
        ns.Display:Center()
    elseif msg == "buffs" then
        ns.AuraShow.ListBuffs()
    elseif msg == "gameshow" then
        ns.AuraShow.Toggle()
    elseif msg == "ids" then
        ShowIds()   -- every number Shadowflare uses, named by this client (0.23.22)
    elseif msg == "gstest" then
        ns.AuraShow.Report()   -- diagnosis of the game's frames (0.23.6)
    elseif msg == "probe" then
        local ok, err = pcall(ns.SecretProbe, "asked")
        if not ok then ns.Print("probe error: " .. tostring(err)) end
    elseif msg == "debug" then
        ns.debug = not ns.debug
        ns.Print(ns.debug and L.DEBUG_ON or L.DEBUG_OFF)
        costSeen = {}
        if ns.debug then StartCostProbe() else pcall(costFrame.UnregisterAllEvents, costFrame) end
        if ns.debug and ns.playerClass == "WARRIOR" then
            ns.StartWarriorProbe()
            probeLast = {}
            Probe("now")
        end
        if ns.debug then
            ns.Print(("class=%s - spell=%s - shadow bolt=%s (cast %s, normal %s) - soul fire=%s (cast %s) - buffs readable=%s - source=%s"):format(
                tostring(ns.playerClass), tostring(ns.tranceName), tostring(S.sbId),
                tostring(S.sbId and CastTime(S.sbId)), tostring(castBase),
                tostring(S.sfId), tostring(S.sfId and CastTime(S.sfId)),
                tostring(S.auraReliable), tostring(S.source)))
            local kb = MemoryKB()
            if kb then ns.Print(L.MEMORY:format(kb)) end
        end
    else
        if not ns.Has(ns.playerClass) then ns.Print(L.NO_CLASS) end
        if ns.Settings then ns.Settings:Toggle() else ns.Options:Open() end   -- the settings window (0.22.0)
    end
end
