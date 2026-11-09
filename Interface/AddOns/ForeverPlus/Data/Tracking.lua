-- The trackings worth being reminded about, and which of them share a slot.
--
-- Data rather than code, in its own file for the same reason Data/Buffs.lua
-- is: nothing here reads the game, decides anything or draws anything. It is a
-- list, and the tracking section of Modules/BuffExpiry.lua is what makes it
-- mean something.
--
-- ---------------------------------------------------------------------------
-- A spell, never a profession
-- ---------------------------------------------------------------------------
--
-- The request this comes from asked for a check on Mining and Herbalism. That
-- route is closed: the Classic skill line API hands back display names, and
-- comparing against one is the thing the locale rule forbids outright, so it
-- would break on the first client that is not English.
--
-- Knowing Find Minerals *is* having Mining far enough to track. It is a
-- numeric id, FP:KnowsSpell answers it on this build, and the profession is
-- therefore never asked about at all.
--
-- ---------------------------------------------------------------------------
-- Groups: what cannot be on at the same time
-- ---------------------------------------------------------------------------
--
-- **A group is satisfied by any one of its members**, and that is the whole
-- reason the field exists. Find Minerals and Find Herbs exclude each other, so
-- a character with both professions can never have both, and a warning that
-- asked for both would be one they could not clear. Asking for *one of them*
-- is a question with an answer.
--
-- **Find Treasure is not in that group**, and on this build that is a change
-- rather than an oversight. In original Classic the three excluded each other;
-- the owner brought back from the Deep Dive panel that Blizzard has confirmed
-- Find Treasure now runs alongside any other tracking. So it stands alone: the
-- only thing that satisfies it is itself.
--
-- That difference is not measured here and cannot easily be, since it takes a
-- Dwarf with a gathering profession. Nothing rests on it either way: a group
-- is satisfied by any member being active, which is right whether or not its
-- members actually exclude each other. Being wrong about it only ever makes
-- this quieter.
--
-- ---------------------------------------------------------------------------
-- The ids
-- ---------------------------------------------------------------------------
--
-- **Two of three verified on build 69913, 2026-09-21**, by name through
-- `/fplus buffs tracking` rather than by counting failures: 2580 is Find
-- Minerals here and 2383 is Find Herbs.
--
-- **All three are verified as of 2026-09-21.** 2481 was the last one written
-- from memory, and the owner ran it on a Dwarf the same evening: the row, the
-- match and the warning all behaved. Memory is what this project has been wrong
-- about before, thirty four ids went into Data/Buffs.lua on an inference and the
-- client knew none of them, so being right this time is a measurement rather
-- than a vindication.
--
-- **Do not add a fourth id because these turned out right.** That is the
-- reasoning that produced the thirty four.
--
-- ---------------------------------------------------------------------------
-- What is deliberately absent
-- ---------------------------------------------------------------------------
--
-- * **The hunter trackings**, humanoids and beasts and the rest. They are a
--   decision somebody makes per pull rather than a tool they meant to have
--   running, and the owner judged three entries enough to start with.
-- * **Everything in the minimap filter list.** Innkeeper, Flight Master and
--   the other nineteen are not tracking at all: they are filters, several are
--   on permanently, and `type` in the client's own answer tells them apart.
--
-- `label` is ours and is only a fallback: the page and the chat show the
-- client's own name for the spell wherever it will give one.

local ADDON, FP = ...
local L = FP.L

FP.trackingTypes = {
    { id = "minerals", spell = 2580, label = L["Find Minerals"],
      group = "gathering", default = true },

    { id = "herbs",    spell = 2383, label = L["Find Herbs"],
      group = "gathering", default = true },

    -- Ticked like the other two, and safe for the same reason rather than for
    -- a new one: nothing is ever said about a spell the character has not
    -- learned, so everybody who is not a Dwarf sees exactly what a character
    -- without Mining sees, which is nothing at all. A Dwarf who tracks
    -- something else on purpose unticks it once.
    { id = "treasure", spell = 2481, label = L["Find Treasure"],
      group = "treasure",  default = true },
}
