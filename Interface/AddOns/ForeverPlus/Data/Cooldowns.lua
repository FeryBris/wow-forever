-- The long cooldowns the info bar keeps for every character.
--
-- Gated with the owner on 2026-10-10: **everything of twenty hours or more**,
-- since a shorter one is ready again before anybody switches character, and
-- **the transmutes grouped by kind**, Arcanite and Legionite a line each and
-- every elemental transmute in one, which reads "Ready" as soon as one of them
-- is. Whether the elemental ones share a cooldown on WoW Forever is not known,
-- and the earliest of them is right either way.
--
-- Out of the Wowhead Forever database the same day, every id resolved to the
-- name beside it and every cooldown read off its tooltip there. Only Dedicated
-- Study can be seen in game before the launch: every recipe here lies above
-- the beta's level 30. **The list is meant to grow** once WoW Forever's
-- professions are known at the launch, the owner's plan.
--
-- An entry is either `spells`, of which the character has the line when it
-- knows one, or an `item` it carries, with the `requires` it needs to use it:
-- a Salt Shaker kept after Leatherworking was unlearned cannot be used. A line
-- is named by the client, in the player's language, unless it has a `label`.

local ADDON, FP = ...
local L = FP.L

FP.COOLDOWNS = {
    -- A perk of the Legacy tree, so it can be given back there.
    { key = "dedicatedStudy", spells = { 1225469 } },   -- Dedicated Study, 23 hours

    { key = "mooncloth", spells = { 18560 } },          -- Mooncloth, almost 4 days

    { key = "arcanite", spells = { 17187 } },           -- Transmute: Arcanite, almost 2 days
    { key = "legionite", spells = { 1317279 } },        -- Transmute: Legionite, new on WoW Forever, almost 2 days

    { key = "elementalTransmutes", label = L["Elemental Transmutes"],   -- 23 hours each
      spells = {
          17559,   -- Transmute: Air to Fire
          17560,   -- Transmute: Fire to Earth
          17561,   -- Transmute: Earth to Water
          17562,   -- Transmute: Water to Air
          17563,   -- Transmute: Undeath to Water
          17564,   -- Transmute: Water to Undeath
          17565,   -- Transmute: Life to Earth
          17566,   -- Transmute: Earth to Life
      } },

    { key = "saltShaker", item = 15846,                 -- Salt Shaker, almost 3 days
      requires = { 2108, 3104, 3811, 10662 } },         -- Leatherworking, any rank
}

-- Left out by the same rule: Transmute: Iron to Gold and Mithril to Truesilver,
-- an hour each on WoW Forever where Classic had two days, and Transmute:
-- Elemental Fire, ten minutes. Cured Rugged Hide has no cooldown there any
-- more; the Salt Shaker that refines its salt has.
