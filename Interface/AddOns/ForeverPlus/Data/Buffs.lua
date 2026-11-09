-- Curated buff tables, one block per class, as numeric spell ids.
--
-- Data rather than code, which is why it sits in its own folder and its own
-- file. Nothing here reads the game, decides anything or draws anything; it is
-- a list, and BuffExpiry is what makes it mean something.
--
-- ---------------------------------------------------------------------------
-- Why ids and never names
-- ---------------------------------------------------------------------------
--
-- The locale rule: an id is the same number on every client, a name is not.
-- Display names are resolved at runtime through C_Spell.GetSpellInfo, so this
-- file carries no game text at all and works on a German or Russian install
-- without a translation. The English words in `label` below are ours, for the
-- selection page, and never compared against anything.
--
-- ---------------------------------------------------------------------------
-- Lines: ranks and slots are different things
-- ---------------------------------------------------------------------------
--
-- Every entry holds one or more `lines`. A line is a rank family, ordered
-- weakest first, where a later entry is strictly better than an earlier one.
-- Several lines in one entry are alternatives that share a slot.
--
--   Frost Armor and Ice Armor are one line: Ice Armor is the upgrade, and a
--   Mage wearing rank 2 while rank 3 is trained wants to know.
--
--   Mage Armor is a second line in the same entry: it occupies the same slot,
--   so any of them satisfies the entry, but it is a *choice* rather than an
--   upgrade and must never be suggested to somebody in Ice Armor.
--
-- So: satisfied when any spell from any line is up. "A better version exists"
-- only ever compares within one line.
--
-- ---------------------------------------------------------------------------
-- Kinds
-- ---------------------------------------------------------------------------
--
--   self    you cast it on yourself, it expires, you forget it
--   group   you cast it on other people too, so it also carries a count of how
--           many of them are missing it
--   aura    a permanent toggle: Hunter Aspects, Paladin Auras. Never expires,
--           so only its complete absence is worth saying, and only to the
--           player who can cast it
--   weapon  a weapon imbue or poison. Not an aura at all and not readable the
--           same way, so it is tracked through the weapon enchant API. Its
--           `requires` are the spells that let the character put it on,
--           `names` the spells whose names a tooltip line is compared with,
--           and `casts` every spell whose cast puts it on, which is how a
--           line learns its place in any language: see Core/Weapon.lua
--   pet     not a buff at all: whether the Hunter's pet is happy, asked of
--           the client when the display is drawn. Its `requires` is Feed
--           Pet, which makes it answerable and is what it is pictured as
--
-- `default = false` starts an entry switched off on the selection page. Every
-- entry without it starts on; the two that carry it are Touch of Weakness and
-- Thorns. It is for a buff a player might reasonably not want running at all,
-- rather than for one that is merely situational.
--
-- `targets` gives a group buff a second switch, for a spell that is handed to
-- a few chosen people rather than to everybody. Thorns had it alone until
-- 2026-10-05, when the owner asked for six more built the same way: Amplify
-- Magic and Dampen Magic, Unending Breath and Detect Invisibility, Water
-- Breathing and Water Walking. The tick on such a row says whether the buff is
-- tracked at all, since 2026-10-06, and three rows under it say where:
-- "Track on yourself", a stepper "Track on friendly targets" whose number is
-- how many **other** players it has to stay up on, from `{ default, min, max }`,
-- and the switch below. All three are grayed out while the tick is off.
-- "Track on yourself" starts on, and off where `targets` carries
-- `onSelf = false`.
-- Ticked with "Track on yourself" off and a count of one means "not on me, on
-- one other person". Until that day the tick was your own copy and the count
-- stood on its own beside it; BuffExpiry carries such settings over.
--
-- **Under the stepper sits a switch, "Track on every group or raid member"**,
-- the owner's addition of the same day, so that nobody has to set the number
-- to the size of the group: on, it asks for everybody the group counts reach,
-- exactly as a group buff without a cap does, and the stepper fades while it
-- is. Stored per buff in `targetsAll` in BuffExpiry, off by default.
--
-- `excludes` names entries of the same class that cannot sit on one player
-- beside this one. Tracking one on yourself switches that off for the other,
-- and the same holds for the switch for every member: Amplify Magic and Dampen
-- Magic replace each other, so both asked for on one player would leave an
-- icon nobody could clear. The owner's rule of 2026-10-05, on the tick then
-- and on "Track on yourself" since the tick means tracked at all. Both start
-- with "Track on yourself" off, `onSelf = false`, his word of 2026-10-06:
-- on, ticking both would have asked for both on him.
--
-- `tracker = true` gives an entry a slot on the tracker display: drawn for as
-- long as it is running, with its remaining time, and never drawn for being
-- absent. It needs a `duration` in seconds as its starting value, for the first
-- cast of a session, and that number is replaced by the real one the moment the
-- buff is seen out of combat.
--
-- **A tracker replaces the expiry warning and nothing else.** Being told a buff
-- is nearly gone while a countdown for it is already on screen is the same
-- sentence twice, so that one branch stands down. Everything a countdown cannot
-- say still warns: that the buff is missing, that a weaker rank is running,
-- that somebody near you is owed it. Battle Shout is the entry that uses this.
--
-- `display = "tracker"` sends an entry's icons to the lower display instead of
-- the warning display, and says nothing about *when* they appear.
--
-- **Every entry that wants it says so, and nothing is derived.** A rule based
-- on `kind` existed for an afternoon and was removed on 2026-09-22 for putting
-- the half hour buffs down there, where nobody recasts them mid fight, and for
-- calling Thorns a self buff. The question the lower display answers is "can
-- this run out while I am fighting", which no field here can be read off.
--
-- Five entries carry it today: the Seals, Battle Shout, Inner Fire, Touch of
-- Weakness and the shield spells. Everything else, including Thorns at ten
-- minutes, draws on the warning display above.
--
-- `warns = false` takes an entry out of the warning list altogether, so the
-- tracker is the only thing it ever draws. Seals set it: thirty seconds is too
-- short for any warning to be anything but a metronome, missing included. An
-- entry with `warns = false` and no `tracker` would be invisible, which is
-- nothing anybody needs, so the two go together.
--
-- `charges = true` marks a buff that ends when something spends it rather than
-- when its timer runs out, and **it means the entry says nothing at all during
-- a fight**. This client cannot see a charge being spent, measured 2026-09-20:
-- no event of any kind, and every aura read in combat is refused. So the
-- countdown would go on running on a buff that is already gone.
--
-- That is the rule in `AGENTS.md` rather than an exception to it. A countdown
-- may stand in combat because it is arithmetic on a known value, an expiry
-- time read before the fight. A charge buff does not end at a known time, so
-- there is no arithmetic to do and nothing worth drawing.
--
-- `counted = { cooldown, charges }` is the way out for a charge buff whose
-- charges can be followed: the Shaman shields, and the Troll priest's
-- Shadowguard since 2026-10-01, all three spent by any hit. The aura
-- is still unreadable in a fight, but every hit on the player reaches an addon
-- as a plain UNIT_COMBAT, so the charges read before the fight are counted
-- down: one per hit, at most one per `cooldown` seconds, and back to `charges`
-- when the player recasts it. At none left the entry warns in combat like any
-- self buff, which is allowed because a recast is seen. What a count gets
-- wrong is corrected by the first read after the fight.
--
-- Two more fields narrow which hits spend one, for Inner Fire since
-- 2026-10-11: `physical = true` counts only a physical hit, school 1, which is
-- a melee or a ranged attack, and `absorbed = false` lets a hit that did no
-- damage spend none. That is one a shield absorbed, which UNIT_COMBAT flags
-- ABSORB with an amount of 0, seen by the shield probe on a priest on
-- 2026-09-29, and one of 0 without the flag, which came in the same moment as
-- another hit and spent nothing in the probe's Inner Fire fights of
-- 2026-10-11.
--
-- `classes` applies to group buffs only and says who the buff counts for when
-- handing it out. Absent means everybody. A Warrior does not need Arcane
-- Intellect and must not appear in its count.
--
-- `ownClassOnly = true` keeps a group buff to the class that casts it: nobody
-- else is ever told it is missing, and the caster's own entry, the count of
-- people owed one included, is untouched. Battle Shout carries it, decided by
-- the owner on 2026-09-27 after a dungeon group: its reach is short and it
-- covers only the shouting Warrior's own party, so the Mage it warned was
-- often standing where no shout could have reached. He may widen it later;
-- until then it stays with Warriors.
--
-- `race` and `raceId` narrow an entry to one race, and an entry that names
-- neither is for the whole class. Both are given rather than one, because each
-- comes from a different place and either alone would be a claim: the id is out
-- of this build's own database and the token is what `UnitRace` returns for it,
-- which is knowledge rather than a measurement. Matching on either means being
-- wrong about one costs nothing. **Undead is `Scourge` there**, which is the
-- kind of trap the locale rule exists for: the display name and the token are
-- different words.
--
-- `minLevel` is the level at which somebody of that class can first cast the
-- entry at all, and it exists for one reason: deciding whether the Paladin
-- standing next to you could bless you. The client answers `IsSpellKnown` for
-- you and for nobody else, so for other people this is inferred from their
-- class and their level, and there is no way to check it.
--
-- **It cannot express a talent, and no number can.** A class and a level say
-- nothing about where somebody spent their points, so a talent-granted group
-- buff would be reported as owed by people who cannot give it. Trueshot Aura
-- is the one entry in this file that is talent-granted, and it is kept honest
-- by its class list rather than by its level: see the note there. Any future
-- entry in the same position needs the same care.
--
-- **When unsure, put it too high rather than too low.** Too high means a
-- warning that arrives late; too low means one that cannot be cleared,
-- because the person it points at has not learned the spell yet. Those are
-- not equally bad.
--
-- They were written from memory, and that was the only option until
-- 2026-09-21, when a source for them turned up. talentsforever.com publishes
-- the beta client's own spellbooks as JSON: every trainer spell to 60 with the
-- level each rank is learned at, read out of build 1.60.1.69876 and licensed
-- CC BY 4.0.
--
--   https://talentsforever.com/data.json
--
-- Checked against it the same day, and eight of the nine agreed. **Aspect of
-- the Wild was wrong by sixteen levels**, 30 here against 46 in the client,
-- and wrong in the direction this note calls the worse one: every Hunter
-- between those levels was owed a buff they could not have learned yet.
-- Corrected below.
--
-- **Trueshot Aura was the open one and is closed.** That source had it as a
-- talent *and* as five trainer ranks starting at 25, where this file carried
-- three ids and a 40, and there was no way to tell which reading was right
-- without ids. The database below settled it on 2026-09-21: five ranks, the
-- 25 is rank 1, and the two missing ones are ids this game added.
--
-- **That source carries no spell ids at all**, so it settles levels and nothing
-- else.
--
-- ---------------------------------------------------------------------------
-- A second source, and this one has the ids
-- ---------------------------------------------------------------------------
--
-- Wowhead runs a section for this game, handed over by the owner on
-- 2026-09-21 and read the same evening:
--
--   https://www.wowhead.com/forever/spells/abilities/priest
--
-- It is this build's own spell data rather than Vanilla's: **id, rank, level,
-- race and class per spell**, plus the tooltip and the duration on each spell's
-- own page. The priest list alone runs to 318 entries and carries the reworked
-- racials the owner had to supply as a screenshot a day earlier.
--
-- Touch of Weakness below came out of it whole, and it paid for itself
-- immediately: the six ranks are 2652, 19261, 19262, 19264, 19265 and 19266,
-- so **19263 is not one of them**, and a contiguous run is exactly what would
-- have been written down from memory.
--
-- **It closed the buff table backlog the same evening.** Those gaps were parked
-- for want of a real database for this client, and every one of them was a
-- missing rank, which is the one thing a list with ids, ranks and levels
-- answers directly. Seven ids came out of it: three ranks of Aspect of the
-- Beast, two of Trueshot Aura, and the top ordinary rank of each of the two
-- blessings.
--
-- **Four of those seven are ids this game added**, in the 1299xxx range, and
-- none of them exists in Classic. No amount of remembering would have produced
-- them, and that is the argument for the source in one line.
--
-- Read rather than trusted, all the same: `/fplus buffs verify` still holds
-- every id against the client, which is the only source that is not a claim
-- about the client but the client itself.
--
-- ---------------------------------------------------------------------------
-- How long these actually last on this build
-- ---------------------------------------------------------------------------
--
-- Read out of this game's own database on 2026-09-22, when the question came up
-- of whether the short buff warning threshold still has any user. The answer
-- was not what Vanilla would predict, and the numbers are worth having written
-- down before somebody reasons from memory again:
--
--   1 hour     every Blessing, Mark of the Wild, Arcane Intellect,
--              Power Word: Fortitude, Divine Spirit, and the Greater and
--              Prayer versions of each
--   30 min     Righteous Fury, Demon Skin, Mage Armor
--   20 min     Prayer of Shadow Protection
--   10 min     Thorns, Inner Fire, Shadow Protection, Lightning Shield
--   3 min      Battle Shout
--   2 min      Touch of Weakness
--   30 sec     every Seal
--
-- **Blessings are the surprise**: five minutes in Vanilla, an hour here. So is
-- the hour on Fortitude and Mark of the Wild, both of which were half that.
-- This build hands out long buffs and a very short tail, with nothing in
-- between except Battle Shout.
--
-- **That table is the reason there are three warning thresholds and not two.**
-- Four entries last exactly ten minutes, which was the old boundary, and a
-- strictly-less-than comparison put them on the long side: five minutes of
-- warning on a ten minute buff, so the icon stood for half its life. The owner
-- asked for a middle band on 2026-09-22, defaulting to three minutes, and it
-- covers everything from ten minutes up to half an hour.
--
-- Worth keeping in view when adding an entry: **the bands are about the buff's
-- real length on this client**, not about the number anybody remembers. A
-- blessing moved from five minutes in Vanilla to an hour here, which is two
-- bands' difference.
--
-- ---------------------------------------------------------------------------
-- What is deliberately absent
-- ---------------------------------------------------------------------------
--
-- * **Profession buffs.** This client introduces some, and they do not stack
--   with the class versions. Their ids are not knowable from here, so they
--   wait for a collector rather than being guessed. See ROADMAP.md phase 1.5.
-- * **Anything that lasts under two minutes, as a warning.** Slice and Dice,
--   shields. A warning every thirty seconds is not a warning, it is a
--   metronome, and that has not changed.
--
--   **Seals left this list on 2026-09-22** and are the exception that proves
--   it: they are in the file as a `tracker`, which is a different thing from
--   a warning. It stands while the buff runs and says nothing when it does
--   not, so the objection above has nothing to bite on. Anything else short
--   enough to be excluded here can follow the same way, one entry at a time.
-- * **Situational buffs.** Underwater breathing, invisibility detection,
--   resistance auras for one fight. Nobody wants to be told they forgot
--   Unending Breath on the way to the bank.
-- * **Stances, forms, presences.** Not buffs, and never missing.
-- * **Shaman totems.** Strength of Earth and its relatives are real group
--   buffs in this content, and they are left out because the buff falls off
--   the moment somebody walks out of the radius. Tracking them would mean a
--   warning every time the group moves, which is a warning nobody can act on
--   and nobody would keep.
-- * **Blood Pact**, from a Warlock's imp. A genuine group buff that arrives
--   from a pet rather than from a spell somebody casts, so "who present could
--   cast this" has no answer for it and the whole mechanism does not fit.
-- * **Commanding Shout.** Not a group version of Battle Shout but a separate
--   stamina buff, and a Burning Crusade one at that.
--
--   All three were offered to the owner on 2026-09-19 and declined. Written
--   down so their absence reads as a decision rather than as an oversight,
--   which is the only reason this list exists.
--
-- ---------------------------------------------------------------------------
-- These numbers are written from memory and are not trusted
-- ---------------------------------------------------------------------------
--
-- Build 69913 is newer than the assistant's knowledge, and this is Vanilla
-- content on a modern engine rather than Vanilla itself. So every id here was
-- a claim rather than a fact, and `/fplus buffs verify` holds the lot against
-- the client, names what it finds and lists what it does not recognize.
--
-- **Verified again on 2026-09-21**, after the backlog was closed: 201 ids, none
-- of them unrecognized, and every one of the thirteen added that day resolving
-- to the name it was meant to. The four in the 1299xxx range are real on build
-- 69913 rather than ahead of it.
--
-- **What that does not prove is that anybody can learn them**, and the owner
-- raised it before the report was read. A spell record can exist while no class
-- trains it: Sanctity Aura would have resolved cleanly right up to the moment
-- it was deleted for being attached to no class at all.
--
-- It costs nothing when it happens. Everything downstream of an id is gated on
-- `known[id]`, which comes from `IsPlayerSpell`, so an id nobody can learn
-- never enters that table, never satisfies an entry, is never chosen as the
-- best known rank and never suggests an upgrade. The one id that could do harm
-- is one pointing at a *different* spell the player does know, and that is
-- exactly what checking the name catches.
--
-- **Verified on 2026-09-19.** Every id resolving to exactly the spell
-- intended, in the right rank order and the right family. The only ones the
-- client did not know were Blessing of Sanctuary, which does not exist in this
-- version at all, and they have been taken out.
--
-- **This build is Vanilla plus a short list, not Vanilla plus Burning
-- Crusade.** Greater Blessing of Kings existing made it look like the whole
-- expansion was here, so forty two higher rank ids went in on that assumption.
-- Thirty four of them were unknown. What this client actually has beyond
-- Vanilla, measured:
--
--   Blessing of Kings and every Greater blessing
--   Battle Shout rank 7
--   Rockbiter Weapon ranks 5 to 7
--
-- The other thirty four are gone. **Do not add a rank because a neighboring
-- one exists**: that reasoning is what produced them, and a rank the tables do
-- not know counts as *not present*, which puts a warning on screen for a buff
-- the player is already wearing.
--
-- Read the names, do not count the failures. An id that resolves to the wrong
-- spell passes the count and is still wrong, and both faults found here were
-- caught by reading.
--
-- Run it again after any client patch, and after any change here. An id this
-- client does not know is the worst kind of wrong: nothing breaks, the buff
-- simply never warns.

local ADDON, FP = ...
local L = FP.L

-- Named once and used twice: both weapon slots want the same list, and two
-- copies of nineteen numbers is two things to keep in step.
--
-- By line rather than as one heap, because a rank only means something inside
-- its own line. Rockbiter 3 into Rockbiter 5 is an upgrade worth mentioning;
-- Rockbiter into Flametongue is a different choice in the same slot and must
-- never be suggested, exactly as with the armour spells.
local SHAMAN_IMBUE_LINES = {
    { 8017, 8018, 8019, 10399, 16314, 16315, 16316 },   -- Rockbiter Weapon
    { 8024, 8027, 8030, 16339, 16341, 16342 },          -- Flametongue Weapon
    { 8033, 8038, 10456, 16355, 16356 },                -- Frostbrand Weapon
    { 8232, 8235, 10486, 16362 },                       -- Windfury Weapon
}

-- Flat, for the question "does this Shaman know any imbue at all", which is
-- what decides whether a bare weapon is worth a warning.
local SHAMAN_IMBUES = {}
for _, line in ipairs(SHAMAN_IMBUE_LINES) do
    for _, id in ipairs(line) do SHAMAN_IMBUES[#SHAMAN_IMBUES + 1] = id end
end

-- The spells that coat a weapon with each Rogue poison, first rank only. Only
-- their names are used, see the Rogue entries below.
local ROGUE_POISONS = {
    8679,    -- Instant Poison
    3408,    -- Crippling Poison
    2823,    -- Deadly Poison
    5761,    -- Mind-numbing Poison
    13219,   -- Wound Poison
}

-- The Warlock's stones, which WoW Forever made weapon imbues: each one is used
-- on the weapon rather than held in the off hand. Asked for by the owner on
-- 2026-10-05, and every id read off the Wowhead section for this game the same
-- day, the stones themselves through its tooltip service, since the item pages
-- draw their text with script. The stones are cast with the same new weapon
-- effect #360 as poisons and Shaman imbues, so they sit in the buff place and
-- an oil can sit beside them. **The Spellstone was rebuilt the same way**,
-- shadow and spell haste where the Firestone gives fire and critical strike,
-- under ids this game added: 1237152, 1237156 and 1237159.
--
-- What the Warlock learns, and what tells the addon a stone can be made.
local WARLOCK_STONE_CREATES = {
    6366, 17951, 17952, 17953,   -- Create Firestone: Lesser, plain, Greater, Major
    2362, 17727, 17728,          -- Create Spellstone: plain, Greater, Major
}

-- What using a stone casts, every rank. Each rank carries the stone's own
-- name, Firestone or Spellstone, so the first of each is enough to compare a
-- line with, and all of them teach a line its place.
local WARLOCK_STONE_NAMES = { 758, 1237152 }
local WARLOCK_STONE_CASTS = {
    758, 17945, 17947, 17949,      -- Firestone: Lesser, plain, Greater, Major
    1237152, 1237156, 1237159,     -- Spellstone: plain, Greater, Major
}

-- Every rank's coating spell, which is what a cast of it reports. A weapon
-- line learns its place from that cast, see *Learning a line from the cast*
-- in Core/Weapon.lua, so a rank missing here is one whose line is never
-- learned, and a Rogue who keeps renewing it pays for poison and teaches the
-- addon nothing. Asked for by the owner on 2026-10-05 for exactly that reason.
--
-- Each id read off the Wowhead section for this game the same day, one at a
-- time, and each carries the new weapon effect #360. **Instant Poison VI is
-- 11340**: the page for 11343 is the recipe that makes the item, "Create
-- Item", which is the trap of counting ids. Some higher ranks show there
-- without their numeral, Crippling Poison 11202 and Wound Poison 13225 to
-- 13227; the effect is what marks them as coatings.
local ROGUE_POISON_CASTS = {
    8679, 8686, 8688, 11338, 11339, 11340,   -- Instant Poison
    2823, 2824, 11355, 11356, 25351,         -- Deadly Poison
    3408, 11202,                             -- Crippling Poison
    5761, 8693, 11399,                       -- Mind-numbing Poison
    13219, 13225, 13226, 13227,              -- Wound Poison
}

FP.classBuffs = {

    -- -----------------------------------------------------------------------
    DRUID = {
        { id = "markOfTheWild", kind = "group", label = L["Mark of the Wild"],
          minLevel = 1,
          lines = {
              { 1126, 5232, 6756, 5234, 8907, 9884, 9885 },   -- Mark of the Wild
              { 21849, 21850 },                               -- Gift of the Wild
          } },
        -- **Not a self buff, and it never was.** Carried as one since the
        -- tables were written, caught on 2026-09-22 when the display rule
        -- derived from `kind` sent it to the wrong place and the owner asked
        -- why. This build's own data settles it: 30 yard range, and the text
        -- reads "Thorns sprout from the friendly target". You cast it on
        -- somebody else.
        --
        -- **Off by default, and it is the second entry in the file to be**,
        -- after Touch of Weakness. A group buff normally means everybody, and
        -- Thorns in practice means the tank: a Druid who blanket casts it on
        -- five people is wasting mana rather than playing well. So an entry
        -- that would nag about four missing people is one nobody wants
        -- switched on for them.
        --
        -- **Two independent questions, which is what the shape is for.** The
        -- tick box asks about the copy on you and behaves like every other
        -- entry in this file. `targets` asks a second question the tick box
        -- cannot: how many *other* players you are keeping it on. You are never
        -- counted there, and the two do not depend on each other, so a Druid
        -- who never carries Thorns himself and keeps it on the tank sets the
        -- counter to one and leaves the box unticked.
        --
        -- **It starts at zero**, meaning nobody is watched, on top of the entry
        -- starting unticked. Nothing about Thorns says anything until somebody
        -- asks it to, which is right for a buff whose usual pattern is one
        -- target chosen deliberately.
        --
        -- **The number on the icon is what is left to do**: how many of those
        -- players you still have to reach, not how many exist. Asking for three
        -- with one of them covered reads as two, and it is capped by who is
        -- actually present so a party of two cannot leave an icon nobody can
        -- clear.
        --
        -- **Reshaped on 2026-10-06**, at the owner's word: the tick tracks
        -- the buff at all, and "Track on yourself" under it is the first of
        -- the two questions below, so every setting of the buff is grayed
        -- out with the tick. A Druid keeping it on the tank ticks it and
        -- switches "Track on yourself" off; older settings are carried over.
        --
        -- **Decided three times on 2026-09-22**, and the two discarded answers
        -- are recorded because both are tempting. It was briefly a plain self
        -- buff, on the argument that this addon is about the buffs on you: true
        -- of the tick box, and it loses the tank entirely, because a self entry
        -- only ever shows in the Druid's own block. It was also briefly a
        -- counter that included you, which conflated the two questions above.
        { id = "thorns", kind = "group", label = L["Thorns"],
          minLevel = 6, default = false,
          targets = { default = 0, min = 0, max = 4 },
          lines = { { 467, 782, 1075, 8914, 9756, 9910 } } },

        -- **Omen of Clarity does not belong here at all**, settled on
        -- 2026-09-21 and written down because this file called it a gap for a
        -- day. It is 16864, every Druid has it from level 20 here rather than
        -- only a talented one, and the Wowhead Forever database gives the two
        -- facts that end it: **no duration, and the flag "Passive spell"**.
        --
        -- A passive is a buff like any other. What it is not is a buff worth
        -- **tracking**: it cannot be cast, cannot expire and cannot be
        -- missing, so a warning about it has nothing to report and a player
        -- reading one would have nothing to do.
        --
        -- That is the same rule that kept the Undead's Touch of the Grave out
        -- of the racials in phase 4.5, and it is worth stating once: **a
        -- passive belongs in no version of this table**, however much of a
        -- buff it is.
        --
        -- The reasoning that got here first was worse and is recorded so it is
        -- not repeated: that a Druid might simply not want it running. That
        -- treats it as a choice, which it is not.
    },

    -- -----------------------------------------------------------------------
    HUNTER = {
        -- Nature resistance for the party, so it counts as a group buff even
        -- though it is cast on nobody.
        -- 46 rather than the 30 this file carried until 2026-09-21: the
        -- beta client's own spellbook puts rank 1 there, and so does Vanilla.
        -- The old number was a plain misremembering and cost sixteen levels
        -- of warnings nobody could clear. See the note on `minLevel` above.
        { id = "aspectOfTheWild", kind = "group", label = L["Aspect of the Wild"],
          minLevel = 46,
          lines = { { 20043, 20190 } } },
        -- **Closed 2026-09-21 out of the Wowhead Forever database**, and then
        -- corrected twice more the same evening, which is the whole story of
        -- this entry: every time somebody looked, it was less like Classic.
        --
        -- Five ranks. The two that were missing are the cheapest, 1299346 at
        -- 25 and 1299348 at 32, both ids this game added. The old note guessed
        -- the 25 might be a talented Hunter buying rank 1 early. It is rank 1.
        --
        -- **It buffs ranged attack power and nothing else here.** In Classic
        -- it gave melee and ranged, which is why six melee classes used to be
        -- listed below. The tooltip on this build reads "Increases the Ranged
        -- Attack Power of party members within 45 yards", so a Warrior, Rogue,
        -- Paladin, Shaman or Druid gets nothing from it and must never be told
        -- they are missing it. Hunter only.
        --
        -- **Rank 1 is a talent**, marked as one in its own tooltip, with the
        -- ranks above it sold by trainers. That would be a real problem for
        -- the group half of this entry: `minLevel` exists to guess whether the
        -- player next to you *could* cast something, from their class and
        -- their level, and no such guess can see a talent. A Hunter who never
        -- took it would be reported as owing the group a buff they cannot
        -- give, which is the exact failure the header calls the worse one.
        --
        -- **The class list closes that hole on its own**, which is why nothing
        -- else here changes. `classes` decides who an entry is offered to, and
        -- an entry is never offered by somebody of your own class, so with
        -- Hunter alone in the list there is no pair of players for which this
        -- can be offered at all. `minLevel` is left at its true value and now
        -- reaches nothing.
        { id = "trueshotAura", kind = "group", label = L["Trueshot Aura"],
          minLevel = 25,
          lines = { { 1299346, 1299348, 19506, 20905, 20906 } },
          classes = { "HUNTER" } },

        -- Always one of them up, never expiring, so only "none at all" is
        -- worth saying. Cheetah and Pack are travel choices and are left out:
        -- being told you are not in Cheetah while fighting would be absurd.
        --
        -- Aspect of the Wild appears here as well as above, and that is
        -- deliberate rather than a slip. It is a group buff *and* it occupies
        -- the aspect slot, so a Hunter running it is both handing something
        -- out and not missing an aspect. It is the only id in this file that
        -- belongs to two entries.
        -- **Aspect of the Beast was one id of four until 2026-09-21**, when
        -- the Wowhead Forever database closed it. In Classic it is a single
        -- rank that only makes you untrackable; this build gives it melee
        -- attack power and ranks it to 60, and the three ranks above the first
        -- are ids this game added: 1299445, 1299446 and 1299447 at levels 40,
        -- 50 and 60. Not guessable, and not guessed.
        --
        -- Until then a Hunter past rank 1 read as wearing no aspect at all.
        { id = "aspect", kind = "aura", label = L["Aspect"],
          lines = {
              { 13165, 14318, 14319, 14320, 14321, 14322, 25296 },  -- Hawk
              { 13163 },                                            -- Monkey
              { 13161, 1299445, 1299446, 1299447 },                 -- Beast
              { 20043, 20190 },                                     -- Wild
          } },

        -- **Not a buff: the pet's mood.** The owner's request of 2026-10-05,
        -- gated the same evening: an icon whenever the pet is not happy,
        -- plain while it is content and with a missing buff's red border once
        -- it is unhappy, never in combat, where it cannot be fed, and **on by
        -- default**, since a pet that is not happy hits for less. Read with
        -- C_PetInfo.GetPetHappiness, which this build's API documentation
        -- does not mark secret, unlike health and power. Feed Pet is 6991,
        -- trained at 10, out of the Wowhead Forever database.
        { id = "petHappiness", kind = "pet", label = L["Pet Happiness"],
          requires = { 6991 } },
    },

    -- -----------------------------------------------------------------------
    MAGE = {
        { id = "arcaneIntellect", kind = "group", label = L["Arcane Intellect"],
          minLevel = 1,
          lines = {
              { 1459, 1460, 1461, 10156, 10157 },   -- Arcane Intellect
              { 23028 },                            -- Arcane Brilliance
          },
          classes = { "MAGE", "PRIEST", "WARLOCK", "DRUID", "SHAMAN", "PALADIN", "HUNTER" } },

        { id = "mageArmor", kind = "self", label = L["Armor Spell"],
          lines = {
              { 168, 7300, 7301, 7302, 7320, 10219, 10220 },  -- Frost then Ice Armor
              { 6117, 22782, 22783 },                         -- Mage Armor
          } },

        -- **Handed to single players, and off by default**, both of them and
        -- the four below in the Shaman and Warlock blocks: the owner's request
        -- of 2026-10-05 for buffs no dungeon needs that should still be
        -- trackable. Built exactly like Thorns, see `targets` in the header.
        -- Ids, ranks and levels out of the Wowhead Forever database the same
        -- day; every one of the six lasts ten minutes at thirty yards there.
        --
        -- **In Classic the two replace each other on a player**, so `excludes`
        -- keeps one of them on you at most, and both start off on you,
        -- `onSelf = false`. Two rows rather than one, the owner's
        -- choice, so that a Mage can keep Dampen Magic on the tank and Amplify
        -- Magic on the healers.
        { id = "amplifyMagic", kind = "group", label = L["Amplify Magic"],
          minLevel = 18, default = false, excludes = { "dampenMagic" },
          targets = { default = 0, min = 0, max = 4, onSelf = false },
          lines = { { 1008, 8455, 10169, 10170 } } },
        { id = "dampenMagic", kind = "group", label = L["Dampen Magic"],
          minLevel = 12, default = false, excludes = { "amplifyMagic" },
          targets = { default = 0, min = 0, max = 4, onSelf = false },
          lines = { { 604, 8450, 8451, 10173, 10174 } } },
    },

    -- -----------------------------------------------------------------------
    PALADIN = {
        -- **One blessing per Paladin, not one blessing full stop.** An earlier
        -- version of this file said the opposite in a comment, and it was
        -- wrong: two Paladins in the group means two blessings on you, and a
        -- Warrior carrying Might while Kings is also on offer is short one.
        --
        -- So `variants` names them and `wanted` says which ones a class asks
        -- for, in the order it asks. How many of those it can actually have is
        -- decided at runtime by how many Paladins are in range: wanting three
        -- and standing next to one Paladin means one.
        --
        -- Blessing of Sanctuary is not in this version of the game. Its four
        -- Classic ids, 20911 to 20914, were the only ones in this whole file
        -- that build 69913 did not recognize, and the owner confirmed the
        -- spell is gone rather than moved. Written down so the next person to
        -- notice a missing blessing does not go looking for a wrong id.
        -- **Might and Wisdom are each one rank short at the top.** Checked
        -- 2026-09-21 against the beta client's own spellbook: it sells seven
        -- ranks of Might and six of Wisdom, both ending at 60, where the
        -- lists below stop at six and five. Only a level 60 Paladin can cast
        -- the missing ones, so nothing shows on this beta, which caps at 20.
        -- At 60 it would be a blessing the addon does not recognize and
        -- therefore reports as missing while you are wearing it.
        --
        -- The two ids are not written from memory here on purpose. Read them
        -- from a Paladin who has them.
        -- **Each blessing carries the level it is learned at**, and `minLevel`
        -- on the entry is only the lowest of them. Until 2026-09-27 the entry
        -- level was the only one, so a Paladin at 15 was asked for Kings and
        -- Salvation as readily as for Might: a Warlock at 15 in a group with
        -- Paladins at 15 and 16 got icons that neither of them could ever
        -- clear. The levels are this game's own, read off the Wowhead Forever
        -- database that day, and two of them are not Vanilla's: Kings is
        -- trained at 20 rather than being a talent, which the database marks
        -- as "Was a talent", and every level is the one of the lowest rank.
        { id = "blessing", kind = "group", label = L["Blessing"],
          minLevel = 4,
          perCaster = true,
          variants = {
              -- Kings was missing here entirely until the owner pointed it
              -- out. Verified 2026-09-19: 20217 is Blessing of Kings and
              -- 25898 is the Greater version, both known to this client. In
              -- Vanilla it was a Protection talent, which is why no level
              -- could have been trusted for it there; here it is trained.
              --
              -- **That is also how the Greater blessings got here.** They were
              -- absent from every line until Kings arrived with one attached,
              -- and their absence fails in the worst direction: a Paladin
              -- handing out Greater Blessing of Might would have left everyone
              -- told that Might was missing while they were wearing it. A
              -- blessing the tables do not recognize is a blessing that does
              -- not count as present.
              { id = "kings",     minLevel = 20, ids = { 20217, 25898 } },
              -- The top ordinary rank of each, 25291 and 25290, both at 60
              -- and both missing until 2026-09-21. A Paladin casting one read
              -- as having cast nothing, so the whole group was told it was
              -- owed a blessing it was already wearing. Greater ranks follow.
              { id = "might",     minLevel = 4,
                ids = { 19740, 19834, 19835, 19836, 19837, 19838,
                        25291, 25782, 25916 } },
              { id = "wisdom",    minLevel = 14,
                ids = { 19742, 19850, 19852, 19853, 19854,
                        25290, 25894, 25918 } },
              -- **Salvation and Light are gone since 2026-11-03**, P01 of
              -- `planning/AFTER-LAUNCH-PLAN.md` on the branch
              -- `plan/after-launch`: WoW Forever's launch notes remove both,
              -- the Greater versions with them, and the owner had them taken
              -- out ahead of the launch on that word. Their ids may
              -- still resolve to a name on the client, which is why they are
              -- deleted here rather than left to `VariantExists`: a name says
              -- nothing about whether a Paladin can still cast the spell, and
              -- an entry here is a blessing somebody gets asked for. Oath of
              -- Light, which the notes add, is not their replacement and is
              -- not in this table.
              --
              -- Both carried a role, Salvation `notRole = "TANK"` and Light
              -- `onlyRole = "TANK"`; `WantedHere` still honors either field
              -- for a variant that declares one, and none does now.
          },

          -- Ordered by how much the class wants it, because when fewer
          -- Paladins are present than blessings are wanted, the top of the
          -- list is what gets asked for.
          --
          -- **These lists are the author's opinion, not a measurement.** They
          -- came from ordinary practice plus three examples the owner gave:
          -- a Warrior wants Kings and Might, a Warlock Kings and Wisdom, an
          -- enhancement Shaman Kings, Might and Wisdom. Everything else is
          -- extrapolated from those, and a class list that is wrong here shows
          -- up as a blessing asked for that nobody wanted. Correcting one is a
          -- one line change.
          wanted = {
              WARRIOR = { "kings", "might" },
              ROGUE   = { "kings", "might" },
              HUNTER  = { "kings", "might", "wisdom" },
              SHAMAN  = { "kings", "might", "wisdom" },
              PALADIN = { "kings", "might", "wisdom" },
              DRUID   = { "kings", "might", "wisdom" },
              PRIEST  = { "kings", "wisdom" },
              MAGE    = { "kings", "wisdom" },
              WARLOCK = { "kings", "wisdom" },
          } },

        { id = "aura", kind = "aura", label = L["Aura"],
          lines = {
              { 465, 10290, 643, 10291, 1032, 10292, 10293 }, -- Devotion
              { 7294, 10298, 10299, 10300, 10301 },           -- Retribution
              { 19746 },                                      -- Concentration
              { 19876, 19895, 19896 },                        -- Shadow Resistance
              { 19888, 19897, 19898 },                        -- Frost Resistance
              { 19891, 19899, 19900 },                        -- Fire Resistance
              -- **Sanctity Aura was here and is gone**, taken out on
              -- 2026-09-21 by the owner's decision. Two sources agree: the
              -- beta client's spellbook lists it as removed, and the Wowhead
              -- Forever database has the spell but attaches it to no class at
              -- all. It was left in for a day on the argument that a dead
              -- alternative in this entry costs nothing while deleting a live
              -- one costs a warning; the owner weighed that against a table
              -- carrying a spell no Paladin can learn and chose the table.
              --
              -- Put it back if a Paladin is ever seen with it. That is the
              -- whole cost of being wrong here: one line.
          } },

        { id = "righteousFury", kind = "self", label = L["Righteous Fury"],
          lines = { { 25780 } } },

        -- ---------------------------------------------------------------
        -- The first tracker entry, and the first thing in this file that is
        -- not a warning.
        --
        -- Thirty seconds is far too short to warn about: a reminder that
        -- arrives every half minute is a metronome, which is why this file's
        -- header rules out everything under two minutes and still does. A
        -- **tracker** is the other thing: it stands while the buff runs, says
        -- how long is left, and shows nothing at all when nothing is up. It
        -- never says a word about a buff being missing, so it cannot nag.
        --
        -- **Why a Seal can be tracked in a fight at all**, which is the whole
        -- question this entry was built on. A countdown during combat is
        -- arithmetic on a cast that was seen, and it is honest only while
        -- nothing invisible can end the buff early. For a charge buff
        -- something can, which is what `charges = true` is for. For a Seal on
        -- this build nothing can:
        --
        --   * **Judgement does not consume the Seal here.** Blizzard announced
        --     it for WoW Forever, and this build's own text for Judgement
        --     (20271) says it outright: "Unleash the energy of a Seal spell
        --     upon an enemy. Does not consume the Seal." That is a change from
        --     Vanilla, where the opposite was true, and assuming the Vanilla
        --     rule had put this entry in the same box as Lightning Shield.
        --   * Casting a different Seal replaces the running one, and that is
        --     an ordinary cast, which the client reports in combat.
        --   * A dispel is invisible, exactly as it is for every other buff in
        --     this file. Nothing new is being risked.
        --
        -- **One slot, not eight.** Only one Seal can be on a Paladin at a
        -- time, which the client's own spell text states, so these are lines
        -- in one entry the way the Mage armour spells are: alternatives that
        -- share a slot, never upgrades of each other. The tracker shows
        -- whichever is running.
        --
        -- **No rank warning**, decided 2026-09-22. Whether anybody downranks a
        -- Seal deliberately is not known, and a warning nobody wants is worse
        -- than a missing one. The idea of a general switch for rank warnings
        -- is in ROADMAP.md's backlog.
        --
        -- `duration` is what makes the first cast of a session usable. Every
        -- Seal in this build runs **30 seconds**, read off the Wowhead section
        -- for this game on 2026-09-22 and confirmed in the structured Duration
        -- field for Seal of Righteousness and Seal of the Crusader. It is a
        -- source and not a measurement, so it is only a starting value: the
        -- moment the addon sees a Seal out of combat it keeps the real number
        -- instead. Note also that the talent **Improved Seals adds damage, not
        -- time**, checked the same day, so no talent moves this figure.
        --
        -- The ids come from this build's own database rather than from memory,
        -- and two of them say why that matters: **Seal of Fury lives in the
        -- 1311xxx range** and **Seal of Martyrdom at 407798**, neither of which
        -- exists in any Classic client. Seal of Command rank 1 is a **talent**
        -- (20375) with the later ranks trained, which is why it is not in the
        -- ability list at all. Run /fplus buffs verify after touching this.
        { id = "seal", kind = "self", label = L["Seal"],
          display = "tracker", tracker = true, warns = false, duration = 30,
          lines = {
              -- Two rank 1 entries exist for Righteousness, 20154 and 21084,
              -- same level and same duration. **The spellbook casts 20154**,
              -- measured on a Paladin on 2026-09-23 by watching the cast
              -- event. 21084 stays anyway: it resolves on the client too,
              -- `known` drops it for anybody who does not have it, and missing
              -- the id a character does cast would mean the tracker never
              -- draws for them.
              { 20154, 21084, 20287, 20288, 20289, 20290, 20291, 20292, 20293 },
              { 21082, 20162, 20305, 20306, 20307, 20308 },       -- Crusader
              { 20375, 20915, 20918, 20919, 20920 },              -- Command
              { 1311649, 1311656, 20163, 20419, 20421, 20422, 20423 },  -- Fury
              { 20164 },                                          -- Justice
              { 20165, 20347, 20348, 20349 },                     -- Light
              { 20166, 20356, 20357 },                            -- Wisdom
              { 407798, 407799 },                                 -- Martyrdom
          } },
    },

    -- -----------------------------------------------------------------------
    PRIEST = {
        { id = "fortitude", kind = "group", label = L["Power Word: Fortitude"],
          minLevel = 1,
          lines = {
              { 1243, 1244, 1245, 2791, 10937, 10938 },   -- Power Word: Fortitude
              { 21562, 21564 },                           -- Prayer of Fortitude
          } },

        { id = "divineSpirit", kind = "group", label = L["Divine Spirit"],
          minLevel = 30,
          lines = {
              { 14752, 14818, 14819, 27841 },             -- Divine Spirit
              { 27681 },                                  -- Prayer of Spirit
          },
          classes = { "MAGE", "PRIEST", "WARLOCK", "DRUID", "SHAMAN", "PALADIN", "HUNTER" } },

        -- `offerSwitch`: a switch under the row for the icon somebody of another
        -- class gets when a Priest in the group could give this, apart from
        -- the tick, which also decides a Priest's own tracking and count. See
        -- M:OfferWarns in BuffExpiry.
        { id = "shadowProtection", kind = "group", label = L["Shadow Protection"],
          minLevel = 30,
          offerSwitch = {
              label = L["Warn about Shadow Protection from others"],
              desc  = L["Warns when Shadow Protection is missing or about to "
                     .. "expire and a Priest in your group could give it to "
                     .. "you. Only applies where buffs from others are "
                     .. "switched on under Conditions. A Priest's own warnings "
                     .. "and group count do not change."],
          },
          lines = {
              { 976, 10957, 10958 },                      -- Shadow Protection
              { 27683 },                                  -- Prayer of Shadow Protection
          } },

        -- **Twenty charges on WoW Forever**, the owner's word of 2026-10-11,
        -- more with the talent Improved Inner Fire: every melee or ranged hit
        -- spends one, a spell spends none, and none goes while a shield
        -- absorbs the hit. No cooldown between two is known. Until then it was
        -- a plain ten minute buff here, so a fight that spent the last charge
        -- said nothing about it until the fight ended. Counted like the Shaman
        -- shields since, at his word the same day, with the shield probe on a
        -- priest to hold the rule against the charges read after each fight.
        -- The talent needs no table: a recast fills to what a read of a fresh
        -- cast showed last, see FullCharges in BuffExpiry. **Measured the same
        -- evening** on his priest: the stack reads 20, and over four fights
        -- the count matched the charges read after each one, once a hit of 0
        -- damage spent nothing. In the long fight, which had a shield up for
        -- half a minute, he recast five and seven seconds after the count
        -- reached none, which fits shield hits spending nothing; had they
        -- spent, it would have been gone thirty seconds before his recast.
        { id = "innerFire", kind = "self", label = L["Inner Fire"],
          display = "tracker", charges = true,
          counted = { cooldown = 0, charges = 20, physical = true, absorbed = false },
          lines = { { 588, 7128, 602, 1006, 10951, 10952 } } },

        -- **The one racial that qualifies**, and the request this entry came
        -- from. Undead priests only, so it carries a race and no other priest
        -- is ever told about it.
        --
        -- Ids, ranks and levels read out of this build's own database on
        -- 2026-09-21 rather than from Vanilla: six ranks at 10, 20, 30, 40, 50
        -- and 60, and **19263 is not one of them**. A contiguous run of ids is
        -- exactly the inference that put thirty four wrong numbers in this file
        -- once, and here it would have been wrong again.
        --
        -- **It carries the Lightning Shield flaw, knowingly.** The database
        -- prints a ten minute duration and the tooltip says the next melee
        -- attack against you spends it, and this client cannot see a charge
        -- being spent. So during a fight the countdown can be claiming minutes
        -- about something already gone, and it corrects itself when the fight
        -- ends. The owner decided on 2026-09-21 that this is better than the
        -- alternatives rather than not building it: see ROADMAP.md phase 4.5.
        -- **Not counted in a fight, unlike the Shaman shields**, the owner's
        -- decision on 2026-09-29 after testing it at level 10: the aura reads
        -- 600 seconds as the database says, and its charge goes to melee only,
        -- but a melee hit and an arrow reach an addon as the same physical
        -- UNIT_COMBAT, so a count would be wrong against every archer.
        -- **The only entry in this file that starts switched off**, asked for
        -- by the owner on 2026-09-21. It costs a lot of mana for one melee
        -- attack, so keeping it up at all times is a choice rather than the
        -- obvious thing to do, and a warning about a buff somebody never meant
        -- to carry is the kind that teaches people to ignore warnings.
        --
        -- It was also the honest reading of what a default meant until build
        -- 70009: a cold start returned every setting to its default, so a buff
        -- that shipped switched on was switched on again every time the game
        -- started, for somebody who had turned it off the day before. The
        -- first reason stands on its own now that the client remembers.
        { id = "touchOfWeakness", kind = "self", label = L["Touch of Weakness"],
          display = "tracker",
          race = "Scourge", raceId = 5, default = false, charges = true,
          lines = { { 2652, 19261, 19262, 19264, 19265, 19266 } } },

        -- **The Troll priest's racial**, asked for on CurseForge on 2026-10-01
        -- by a player who wanted it tracked, and built the same day at the
        -- owner's word. Trolls only, so it carries a race the way Touch of
        -- Weakness does, and no other priest is ever told about it.
        --
        -- Read out of this game's own database on Wowhead the same day, since
        -- the owner asked for this game's spells rather than Classic's: six
        -- ranks at 20, 28, 36, 44, 52 and 60, and the race's id, 8, off the
        -- same pages. **28377 to 28382 are not the buff**, although the
        -- database files them as Troll priest ranks as well: they are the bolt
        -- the shield fires at an attacker, with no duration of their own.
        --
        -- **It corrects ROADMAP.md phase 4.5**, whose racial table of
        -- 2026-09-21 called Shadowguard a shadow bolt and no buff at all. The
        -- database now shows an aura that triggers that bolt; whether it was
        -- read wrongly then or changed since, its pages do not say.
        --
        -- Ten minutes and three charges, spent by a spell, melee or ranged
        -- hit at most once every 3.5 seconds, the database's own figure. That
        -- is the Shaman shields' rule, so it is counted in a fight the same
        -- way, where Touch of Weakness, spent by melee only, is not. On by
        -- default like every buff a class keeps up until 2026-10-18; a
        -- profile that starts from nothing has it off since, the owner's
        -- word, and one from before keeps it on, see `fresh` in BuffExpiry.
        -- Not seen in game: nobody on this account plays a Troll priest.
        { id = "shadowguard", kind = "self", label = L["Shadowguard"],
          display = "tracker",
          race = "Troll", raceId = 8, charges = true,
          counted = { cooldown = 3.5, charges = 3 },
          lines = { { 18137, 19308, 19309, 19310, 19311, 19312 } } },
    },

    -- -----------------------------------------------------------------------
    -- Poisons are items applied to a weapon rather than spells, so there are
    -- no ranks to walk and the enchant is what gets checked. The ids below
    -- name the poison effects for the selection page.
    ROGUE = {
        -- `requires` is the answer to a fault found on a level 1 character:
        -- having a weapon is not the same as being able to enchant it, and a
        -- warning about a poison you cannot apply is one you cannot clear.
        --
        -- **This id is a guess and the only unverified number left in this
        -- file.** Applying poisons is a proficiency learned from a quest
        -- rather than an ordinary spell, and its id is not something to claim
        -- from memory. If `/fplus buffs verify` does not recognize it, rogues
        -- get silence here until somebody reads the real one out of a rogue's
        -- spellbook, and silence is the right way for this to fail.
        --
        -- `names` is what the weapon reading compares a tooltip line against,
        -- to tell a poison from a stone on the same blade: see
        -- Core/Weapon.lua. The first rank of each poison is enough, because
        -- every higher rank's line begins with the same words. All five ids
        -- read off the Wowhead section for this game on 2026-09-26, where they
        -- carry these names and the new weapon effect every poison uses here.
        --
        -- `casts` is every rank, for learning a line from the cast that put
        -- it there, since 2026-10-05: see ROGUE_POISON_CASTS above.
        { id = "mainHandPoison", kind = "weapon", label = L["Main Hand Poison"],
          slot = "main", requires = { 2842 }, names = ROGUE_POISONS,
          casts = ROGUE_POISON_CASTS },
        { id = "offHandPoison", kind = "weapon", label = L["Off Hand Poison"],
          slot = "off", requires = { 2842 }, names = ROGUE_POISONS,
          casts = ROGUE_POISON_CASTS },
    },

    -- -----------------------------------------------------------------------
    SHAMAN = {
        -- One slot, two spells, exactly like the Mage's armour above: a
        -- Shaman wears one shield and the entry asks for *a* shield rather
        -- than for a particular one. Two lines rather than two entries is
        -- what stops the addon suggesting a switch from one to the other,
        -- which is a decision and not a rank.
        --
        -- **Water Shield does not exist in Classic**, so 408510 comes from
        -- this client and nowhere else: read off the talent tree with
        -- /fplus id on 2026-09-20, by a Shaman ten levels too junior to learn
        -- it. Only the rank the tree shows. The rest are a trainer's business
        -- and will be read the same way, never guessed: the ranks of a spell
        -- do not run in a neat row on this build.
        -- **Both are spent by charges**, which is why this carries the flag.
        -- Lightning Shield goes after three hits and keeps its ten minute
        -- timer running afterwards, and Water Shield works the same way.
        --
        -- **And both are counted in a fight**, `counted` below, since
        -- 2026-09-29. Measured on the owner's Shaman over 36 fights with
        -- Modules/ShieldProbe.lua: a hit spends a charge when the last charge
        -- went at least 3.5 seconds before, a dodge spends none, and a recast
        -- does not restart that wait. That rule predicted the charges left in
        -- 35 of the 36. Water Shield is taken to follow it on the owner's
        -- word; it could not be learned yet to measure.
        --
        -- **Water Shield's charges go on critical spells as well**, the
        -- owner's word of 2026-10-16, under the same cooldown, and whose crit
        -- a crit was reaches no addon. But each charge it spends gives back a
        -- share of the maximum mana, `mana` below by spell id, 3 percent out
        -- of the Wowhead Forever database, so a gain of that size beside a
        -- crit spends a charge the way a hit does; see NoteMana in
        -- BuffExpiry. **Built unmeasured, the owner's choice of 2026-10-17**,
        -- since no Shaman of his reaches the level before the beta closes:
        -- if the gain or the crit never arrives, the hits still count.
        { id = "shield", kind = "self", label = L["Shield Spell"], charges = true,
          counted = { cooldown = 3.5, charges = 3, mana = { [408510] = 3 } },
          display = "tracker",
          lines = {
              { 324, 325, 905, 945, 8134, 10431, 10432 },   -- Lightning Shield
              { 408510 },                                   -- Water Shield
          } },

        -- Thirty minutes and forgotten constantly, which is exactly the case
        -- this feature exists for.
        --
        -- `requires` lists the imbues themselves. A Shaman with a weapon and
        -- no imbue spell has nothing missing, and at level 1 that is most of
        -- them. Any one of these being trained is enough.
        --
        -- `rankLines` is read by nothing except the upgrade check and, since
        -- 2026-10-05, the learning of a weapon line from its cast, and that is
        -- on purpose: calling it `lines` would hand the whole file's aura
        -- machinery a weapon entry to read as if it were a buff, and a cast
        -- would then be recorded as an enchant with an invented expiry.
        { id = "mainHandImbue", kind = "weapon", label = L["Main Hand Imbue"],
          slot = "main", requires = SHAMAN_IMBUES, rankLines = SHAMAN_IMBUE_LINES },
        { id = "offHandImbue", kind = "weapon", label = L["Off Hand Imbue"],
          slot = "off", requires = SHAMAN_IMBUES, rankLines = SHAMAN_IMBUE_LINES },

        -- Off by default and built like Thorns, see Amplify Magic for why.
        { id = "waterBreathing", kind = "group", label = L["Water Breathing"],
          minLevel = 22, default = false,
          targets = { default = 0, min = 0, max = 4 },
          lines = { { 131 } } },
        { id = "waterWalking", kind = "group", label = L["Water Walking"],
          minLevel = 28, default = false,
          targets = { default = 0, min = 0, max = 4 },
          lines = { { 546 } } },
    },

    -- -----------------------------------------------------------------------
    WARLOCK = {
        -- Demon Skin is the same line as Demon Armor: one upgrades into the
        -- other, so a Warlock still in Demon Skin at 20 wants telling.
        -- Fel Armor is not in this version: 28176 is one of the 34 ids the
        -- client did not recognize. When it arrives it belongs here as a
        -- second line, an alternative in the same slot rather than an upgrade,
        -- so that nobody wearing it is told to switch to Demon Armor.
        { id = "demonArmor", kind = "self", label = L["Demon Armor"],
          lines = { { 687, 696, 706, 1086, 11733, 11734, 11735 } } },

        -- One entry for both stones, the owner's call on 2026-10-05: either
        -- one on the weapon is enough, the way Mage Armor sits beside Ice
        -- Armor, since they are a choice and not an upgrade. **On by default,
        -- against the recommendation**, which was off because every stone
        -- costs a soul shard. The main hand only: a Warlock wields one weapon
        -- and holds no second one. See WARLOCK_STONE_CASTS above for the ids.
        { id = "weaponStone", kind = "weapon", label = L["Firestone or Spellstone"],
          slot = "main", requires = WARLOCK_STONE_CREATES,
          names = WARLOCK_STONE_NAMES, casts = WARLOCK_STONE_CASTS },

        -- Off by default and built like Thorns, see Amplify Magic for why.
        -- **Detect Invisibility is one spell with three ranks here**, where
        -- Classic had Lesser, plain and Greater as three spells: 132, 2970 and
        -- 11743 at levels 26, 38 and 50, out of the Wowhead Forever database.
        { id = "unendingBreath", kind = "group", label = L["Unending Breath"],
          minLevel = 16, default = false,
          targets = { default = 0, min = 0, max = 4 },
          lines = { { 5697 } } },
        { id = "detectInvisibility", kind = "group", label = L["Detect Invisibility"],
          minLevel = 26, default = false,
          targets = { default = 0, min = 0, max = 4 },
          lines = { { 132, 2970, 11743 } } },
    },

    -- -----------------------------------------------------------------------
    WARRIOR = {
        -- **It moved display, not behaviour**, and the two questions being
        -- separate is what this entry is here to demonstrate.
        --
        -- The owner asked for the shout on the lower bar, next to the Seals,
        -- because that is where he is looking during a fight. He then watched a
        -- standing three minute countdown for an evening and asked for it back
        -- the way warnings work: nothing at all until it is nearly gone. Both
        -- requests are reasonable and they are about different things, so
        -- `display` answers *where* and `tracker` answers *when*.
        --
        -- So this entry is an ordinary warning in every respect. It appears
        -- when the shout is nearly gone, when it is gone, when a weaker rank is
        -- running and when somebody near you is owed one, and it appears on the
        -- lower display instead of the upper one. Nothing here is a tracker,
        -- which is why `tracker` is absent: the flag would put a permanent
        -- countdown back on screen.
        --
        -- **The honest weakness, and the warrior is told about it once.**
        -- Another warrior's shout lands on you without any cast of yours, and
        -- in combat this client reports nothing about other people. So a
        -- "missing" icon can stand there through a fight while you are plainly
        -- buffed, and it clears itself the moment combat ends. See the login
        -- note in BuffExpiry.
        --
        -- `duration` stays, even with no tracker reading it. It is what lets a
        -- shout cast in combat start a correct countdown on a character who
        -- has never been seen buffed out of combat. Three minutes, not the two
        -- it ran in Vanilla: read off this build's own database on 2026-09-22
        -- for rank 1 and rank 7, which agree.
        --
        -- `ownClassOnly`, see the head of this file: nobody but a Warrior is
        -- told the shout is missing.
        --
        -- `combatOnly`: a switch under the row, on by default, that keeps its
        -- warnings to a fight, where the rage to cast it is. See
        -- M:CombatOnly in BuffExpiry.
        { id = "battleShout", kind = "group", label = L["Battle Shout"],
          minLevel = 1, display = "tracker", duration = 180, ownClassOnly = true,
          combatOnly = true,
          lines = { { 6673, 5242, 6192, 11549, 11550, 11551, 25289 } } },
    },
}

-- An entry that names its variants still has to offer `lines`, because that
-- is what every reader in the addon walks. Deriving it here rather than typing
-- it a second time means the two can never disagree, which is the whole reason
-- the ranks are not simply repeated above.
for _, entries in pairs(FP.classBuffs) do
    for _, entry in ipairs(entries) do
        if entry.variants then
            entry.lines = {}
            entry.byVariant = {}
            for index, variant in ipairs(entry.variants) do
                entry.lines[index] = variant.ids
                entry.byVariant[variant.id] = variant
                variant.line = index
            end
        end
    end
end

--- The blessings a class asks for, in the order it asks for them.
--
-- An entry with no `wanted` list wants itself once, which is how every other
-- group buff behaves and keeps the caller from having two shapes to handle.
function FP:WantedVariants(entry, class)
    if not entry.wanted then return nil end
    return entry.wanted[class]
end

-- ---------------------------------------------------------------------------
-- Buffs that belong to no class
--
-- On the Buffs page above the class blocks, under a heading of their own, the
-- owner's word of 2026-10-15. Every character has them alike, so their switch
-- is one for every class: BuffExpiry keys them "ALL/<id>" rather than by the
-- class being played.
--
--   shared   belongs to no class; ClassEntries hands it to every character
--   anyone   nothing has to be learned for it, so it is never "not trained"
--
-- **Camp Benefits**, asked for on CurseForge on 2026-10-14: the buff a campfire
-- gives after a minute of sitting or crafting beside it. **Measured by the
-- owner on 2026-10-15** with a line of /run in game: one aura, "Camp Benefits",
-- spell 1229741, 3600 seconds, cast by the player, whatever the camp's
-- objects add. Off until ticked, his word: a player who ticks it wants it, so
-- it warns like a buff of their own, missing and running out, and its own tick
-- is its only switch, not "Your own buffs", which is about spells.
-- ---------------------------------------------------------------------------

FP.sharedBuffs = {
    { id = "campBenefits", kind = "self", label = L["Camp Benefits"],
      shared = true, anyone = true, default = false, duration = 3600,
      -- What the camp gives can be chosen under it, see FP.campBonuses.
      camp = true,
      lines = { { 1229741 } } },
}

-- ---------------------------------------------------------------------------
-- What a camp gives
--
-- Camp Benefits is one aura whatever the fire holds. Each object placed beside
-- the fire adds a bonus of its own, a hidden aura no addon can ask for by id,
-- **measured by the owner's probe on 2026-10-15**: no cast, no aura event and
-- no listing ever named one. The only place a bonus shows is the description
-- of Camp Benefits, a line per object, "Fish Bowl: All stats increased by
-- 8%.", so a bonus is recognized by the names of the objects that give it,
-- which the client resolves from their item ids in its own language.
--
-- **The owner's choice of the same day**: a player may tick up to three of
-- them, as many as one character can carry, and each is then watched on its
-- own, missing unless the camp lists it or a class buff that replaces it is
-- on. One tick covers all three objects that give a bonus, a profession's
-- three tiers. With nothing ticked, Camp Benefits is watched as a whole.
--
--   spell    the hidden aura, for its name in the hover; never read
--   objects  the item ids of the objects that give it, weakest first, out of
--            Method's guide and checked against the Wowhead Forever database
--            on 2026-10-15, all thirty by name
--   instead  class buffs that replace it on a player, as the class and the
--            entry above, with a blessing's variant
--   ids      the same for buffs the class tables leave out, see the list of
--            what is not in them: Strength of Earth, Moonkin Aura and Leader
--            of the Pack, every id checked against the same database
--
-- Which class buff replaces which bonus is out of the guides of 2026-10-15.
-- That one does is measured: Blessing of Kings took the Fish Bowl's line out of
-- the description the moment it arrived, and Camp Benefits with it, since the
-- Fish Bowl had been all it held.
-- ---------------------------------------------------------------------------

FP.campBonuses = {
    -- First Aid Kit, Toxin Study, Plague Doctor's Laboratory
    { id = "stamina", label = L["Stamina"], spell = 1230124,
      objects = { 279968, 279940, 279951 },
      instead = { { "PRIEST", "fortitude" } } },
    -- Sharpening Wheel, Anvil, Master Forge
    { id = "strength", label = L["Strength"], spell = 1230172,
      objects = { 279944, 279988, 279955 },
      ids = { 8076, 8162, 8163, 10441, 25362 } },       -- Strength of Earth
    -- Incense Candle, Greenhouse, Seed Hybridizer
    { id = "intellect", label = L["Intellect"], spell = 1229513,
      objects = { 279962, 279964, 279947 },
      instead = { { "MAGE", "arcaneIntellect" } } },
    -- Faction Banner, Spinning Wheel, Loom
    { id = "spirit", label = L["Spirit"], spell = 1229718,
      objects = { 279972, 279943, 279959 },
      instead = { { "PRIEST", "divineSpirit" } } },
    -- Fish Bowl, Fishing Rack, Fishing Hut
    { id = "allStats", label = L["All Stats (%)"], spell = 1230098,
      objects = { 279967, 279965, 279966 },
      instead = { { "PALADIN", "blessing", "kings" } } },
    -- Enchanted Lute, Arcane Salvager, Arcane Forge
    { id = "statsArmor", label = L["Armor, Stats and Resistances"], spell = 1230653,
      objects = { 279976, 279985, 279987 },
      instead = { { "DRUID", "markOfTheWild" } } },
    -- Lodestone, Rock Garden, Molten Foundry
    { id = "attackPower", label = L["Attack Power"], spell = 1230164,
      objects = { 279960, 279948, 279952 },
      instead = { { "PALADIN", "blessing", "might" } } },
    -- Camp Chair, Field Guide, Trapper's Workbench
    { id = "crit", label = L["Critical Strike Chance"], spell = 1229519,
      objects = { 279979, 279969, 279938 },
      ids = { 24907, 24932 } },                         -- Moonkin Aura, Leader of the Pack
    -- Mana Well, Fermenter, Alchemy Laboratory
    { id = "manaRegen", label = L["Mana Regeneration"], spell = 1230587,
      objects = { 279956, 279970, 279990 },
      instead = { { "PALADIN", "blessing", "wisdom" } } },
    -- Camp Tent, Tanning Rack, Sewing Machine. No class buff replaces it.
    -- **Not a line of Camp Benefits but an aura of its own**, measured by the
    -- owner on 2026-10-18: the tent hands the rested experience over at once
    -- and leaves Boosted Rest, a debuff of an hour in the player's debuff
    -- list, while which no more can be had. So it is read by its id, counts as
    -- had while it runs, and is missing once it can be had again, his word
    -- the same day; at the highest level too.
    { id = "rest", label = L["Rested Experience"], spell = 1229451, ownAura = true,
      objects = { 279978, 279941, 279945 } },
}

--- The class buffs that stand in for a camp bonus, as one list of spell ids.
--
-- Worked out from the class tables rather than typed again, so a rank added
-- there counts here as well, and kept on the bonus once worked out.
function FP:CampCounterparts(bonus)
    if bonus.counterIds then return bonus.counterIds end
    local out = {}
    for _, ref in ipairs(bonus.instead or {}) do
        local class, id, variant = ref[1], ref[2], ref[3]
        for _, entry in ipairs(self.classBuffs[class] or {}) do
            if entry.id == id then
                if variant then
                    local found = entry.byVariant and entry.byVariant[variant]
                    for _, spell in ipairs(found and found.ids or {}) do
                        out[#out + 1] = spell
                    end
                else
                    self:BuffSpellIds(entry, out)
                end
            end
        end
    end
    for _, spell in ipairs(bonus.ids or {}) do out[#out + 1] = spell end
    bonus.counterIds = out
    return out
end

--- Every entry, flattened, with its class alongside.
--
-- The selection page wants them class by class and alphabetically; the scanner
-- wants one flat list. Built once here rather than walked twice everywhere.
-- The buffs of no class come last, under "ALL".
function FP:AllClassBuffs()
    local out = {}
    local classes = {}
    for class in pairs(self.classBuffs) do classes[#classes + 1] = class end
    -- Alphabetical, because the page shows them that way and a stable order
    -- costs nothing. `pairs` gives no order at all.
    table.sort(classes)

    for _, class in ipairs(classes) do
        for _, entry in ipairs(self.classBuffs[class]) do
            entry.class = class
            out[#out + 1] = entry
        end
    end
    for _, entry in ipairs(self.sharedBuffs or {}) do
        entry.class = "ALL"
        out[#out + 1] = entry
    end
    return out
end

--- Does this buff count for a member of that class?
--
-- Only group buffs ask. A missing entry means everybody, which is the common
-- case and keeps the tables shorter than listing nine classes each time.
function FP:BuffAppliesTo(entry, class)
    if not entry.classes then return true end
    for _, name in ipairs(entry.classes) do
        if name == class then return true end
    end
    return false
end

--- Every spell id an entry mentions, in one list.
function FP:BuffSpellIds(entry, out)
    out = out or {}
    for _, line in ipairs(entry.lines or {}) do
        for _, id in ipairs(line) do out[#out + 1] = id end
    end
    return out
end
