-- Buffs that are missing, running out, or a rank behind what you know.
--
-- Which buffs? The ones in Data/Buffs.lua for your class, and nothing else.
-- That is a deliberate reversal of how this module used to work: it watched
-- anything with a long enough timer, which needed no list to maintain but also
-- could not say a word about a buff that had *gone*, since a buff that is not
-- there has no duration to judge. Missing is the case the warning was for.
--
-- Three states, and they are different problems:
--
--   missing    you can cast it, you know it, it is not on you
--   expiring   it is on you and inside the warning window
--   upgrade    a better rank of the same line is trained and you are not
--              using it. Frost Armor while Ice Armor is known
--   handout    you have it, and somebody near you does not. The icon then
--              carries a count instead of a countdown
--
-- Weapon imbues and poisons are in as well. They are not auras, so they are
-- read off the weapon rather than by spell id, see Core/Weapon.lua, and a slot
-- holding a shield is never warned about.
--
-- So is minimap tracking, which is not a buff by any reading: Find Minerals,
-- Find Herbs and Find Treasure sit in a minimap slot. It is folded in here
-- rather than given a module of its own because to the player it is the same
-- thing, a picture of something that should be on and is not, and a second row
-- of icons for one occasional warning earns its space badly. Everything about
-- it is in one section below, and none of the buff machinery reaches into it.
--
-- Two thresholds with a fixed ten-minute boundary rather than a fraction of
-- the buff's own length. A quarter of a Battle Shout is forty five seconds,
-- which is a warning standing for a quarter of every shout, and a quarter of
-- an armour spell is seven and a half minutes.
--
-- Nothing is read in combat, because on this client nothing can be. See the
-- long note above ReadPlayerAura.
--
-- The display takes no mouse input unless it is being positioned. A
-- mouse-enabled frame in the middle of the screen would swallow clicks meant
-- for the world behind it.

local ADDON, FP = ...
local L, N = FP.L, FP.N

-- A measurement rather than a feature, and it comes down before a release:
-- AGENTS.md, step 7 of Releasing. While on, every change between the client
-- answering about auras and refusing to is written to FP.global.auraReads,
-- with the kind of place and whether a fight was on, so a battleground can be
-- played without typing anything and read afterwards. Asked on 2026-10-04:
-- whether buffs can be read in a running battleground, after the gate
-- measurement of 2026-10-03 found every read refused before the start.
--
-- **Answered the same morning, and off since.** One battleground with it on:
-- refused from entering at 10:52:52 until the battle had ended at 11:12:55,
-- read every second, in combat and out of it, then answering again on the
-- scoreboard. See PLACE_SWITCHES for what followed.
local COLLECTING = false

--- A setting's duration, in whatever unit reads best for it.
--
-- Whole minutes where it is whole minutes, seconds below one, and mm:ss in
-- between. The minimum duration reaches down to half a minute now, and "0 min"
-- is not a setting anybody can act on.
local function Duration(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    if seconds < 60 then return L["%d s"]:format(seconds) end
    if seconds % 60 == 0 then return L["%d min"]:format(math.floor(seconds / 60)) end
    return L["%d:%02d min"]:format(math.floor(seconds / 60), seconds % 60)
end

-- Defined at the bottom, with the controls they belong to, and declared here
-- because the option list immediately below names them.
--
-- Third time in this one file. Lua resolves a name when it compiles the
-- function that uses it, so a local declared further down is not that local to
-- anything above -- it is a global, and a nil one.
local BuildList, RefreshList, BuildPicker, RefreshPicker

local M = FP:RegisterModule("BuffExpiry", {
    default = true,
    desc    = L["Warns when a long buff is running out."],

    -- A tab of its own, which partly reverses what phase 1 did here, and the
    -- reasoning is in ROADMAP.md under phase 1.5 rather than only in this
    -- commit. The short version: phase 1 removed a page that built its own
    -- controls and drifted away from the module's own description of itself.
    -- This one is generated from the option list below, so there is still only
    -- one such description. What earns it back is the size this module is
    -- about to become: per class tables, rank families and their own
    -- suppression rules do not belong under a row in a list of nine others.
    page      = N["Buffs"],
    pageOrder = 20,

    -- And off the module list altogether, asked for on 2026-09-19 once the
    -- page was seen in game. A row that cannot be opened and only leads
    -- somewhere else is a row that earns its space badly. The switch moved to
    -- the top of the page instead, and on 2026-09-30 onto the page's tab.
    hidden = true,

    options = {
        -- Three levels on this page, and they are about meaning rather than
        -- about color. A section divides it, a setting that stands on its own
        -- is loud, and a setting that only narrows the one above it is quiet
        -- and indented.
        { type = "group", label = L["General"] },

        -- The module's own switch, and the only one that turns the whole
        -- thing off rather than one part of it. **It is the box on the Buffs
        -- tab since 2026-09-30**, and this entry only words it there: the
        -- page no longer draws it as a row.
        -- A sentence rather than a label, and no "all": the switches below
        -- can silence a kind of warning while this one is still on, so "all
        -- buff warnings are on" would be a claim this switch cannot make.
        { type = "module", labelOn  = L["Buff warnings are on"],
          labelOff = L["Buff warnings are off"],
          desc  = L["The master switch for this page. Everything on it only "
               .. "decides what it warns about and when.|n|nOff means no icons "
               .. "at all. The settings are kept, so turning it back on "
               .. "restores what you had."] },

        -- The four kinds of warning. They were sub rows folded away under the
        -- master switch until it moved to the tab, and stand on their own
        -- since, in General as the owner asked.
        { key = "selfBuffs", type = "toggle", default = true,
          label = L["Your own buffs"],
          desc  = L["Armor spells, shouts, Inner Fire: anything you cast on "
               .. "yourself that runs out."] },

        { key = "groupBuffs", type = "toggle", default = true,
          label = L["Group buffs"],
          desc  = L["Buffs you also put on other people. The icon shows how "
               .. "many nearby players are missing the buff, except in "
               .. "combat."] },

        -- Read off the weapon rather than off the player, so a shield in
        -- the off hand is never mentioned. The hover said that until
        -- 2026-10-05, when the owner had it say what the switch does instead.
        { key = "enchants", type = "toggle", default = true,
          label = L["Weapon imbues and poisons"],
          desc  = L["Warnings about the imbues, poisons, Firestones and "
               .. "Spellstones on your weapons."] },

        { key = "tracking", type = "toggle", default = true,
          label = L["Tracking"],
          desc  = L["Shows an icon whenever none of the tracking abilities "
               .. "you selected in the Tracking section is active. Either "
               .. "gathering tracking ability is enough."] },

        -- The icon size, the countdown and the look of a missing icon stood
        -- here until the redesign of 2026-10-15, and two sections further down
        -- moved the two displays. All of it belongs to a bar since, set in bar
        -- management, which this button and the one on the Consumables page
        -- both open. See Core/Bars.lua.
        { type = "group", label = L["Bars"] },

        { type = "action", label = L["Manage bars"], width = 150,
          desc  = L["Opens bar settings for buffs and consumables: size, "
               .. "appearance and screen position."],
          run   = function() FP:OpenBarManager() end },

        -- When a warning is allowed at all, as opposed to what it watches.
        -- Each of these stands on its own: none of them narrows another.
        { type = "group", label = L["Conditions"] },

        { key = "warnShort", type = "number", default = 10,
          label = L["Warn short buffs at"], min = 5, max = 120, step = 5,
          format = Duration,
          desc  = L["Applies to every buff lasting under 10 minutes."] },

        { key = "warnMedium", type = "number", default = 180,
          label = L["Warn medium buffs at"], min = 30, max = 900, step = 30,
          format = Duration,
          desc  = L["Applies to every buff lasting 10 to 29 minutes."] },

        { key = "warnLong", type = "number", default = 300,
          label = L["Warn long buffs at"], min = 60, max = 1800, step = 60,
          format = Duration,
          desc  = L["Applies to every buff lasting 30 minutes or more."] },

        -- 48 rather than the 64 this started at. Sixty four was chosen when
        -- the display showed one expiring buff at a time; it now shows a
        -- missing buff, a rank behind, and one icon per blessing a Paladin
        -- owes you, and four of those across the middle of the screen is a
        -- wall rather than a warning.
        --
        -- The default moves and nothing stored moves with it. Anybody who
        -- picked a size chose it, and a release that resizes somebody's
        -- display for them is a release they have to undo.
        -- Two places where a missing buff is arguably not worth mentioning.
        -- Both default to warning anyway: they are real cases, and neither is
        -- universal enough to decide for somebody. Dead is not among them,
        -- because that one is a rule rather than a choice.
        --
        -- No heading over them and nothing to unfold, asked for on 2026-09-20:
        -- two switches behind a collapsed heading are two switches nobody
        -- finds. They sit with the other "when does it warn" settings instead,
        -- which is what they are.
        { key = "warnMounted", type = "toggle", default = true,
          label = L["Warn while mounted"],
          desc  = L["Off: no warnings while you are mounted."] },

        { key = "warnResting", type = "toggle", default = true,
          label = L["Warn in a rested area"],
          desc  = L["Off: no warnings in cities and inns."] },

        -- Where a buff somebody else could give you is worth an icon, one
        -- switch per kind of place. Asked for by the owner on 2026-09-27,
        -- after his first dungeon group: while he waited for it, those icons
        -- stood in the middle of the screen through everything else he was
        -- doing. It began as one switch, "only in instances"; he split it the
        -- same day into dungeons, raids and battlegrounds, battlegrounds off,
        -- and added the open world as a fourth. **The open world is off
        -- by default**, which is what the single switch did: the report that
        -- started it came from outside an instance. A buff you can cast
        -- yourself answers to none of these.
        --
        -- **The battleground switch is gone again**, since 2026-10-04: a
        -- battleground refuses every aura read from the gate until the battle
        -- has ended, measured, so it could never show anything. See
        -- PLACE_SWITCHES.
        { key = "othersInDungeons", type = "toggle", default = true,
          label = L["Buffs from others in dungeons"],
          desc  = L["Warnings about a buff another class in your group could "
               .. "give you, while you are in a dungeon."] },

        { key = "othersInRaids", type = "toggle", default = true,
          label = L["Buffs from others in raids"],
          desc  = L["Warnings about a buff another class in your group could "
               .. "give you, while you are in a raid."] },

        { key = "othersInWorld", type = "toggle", default = false,
          label = L["Buffs from others in the open world"],
          desc  = L["Warnings about a buff another class in your group could "
               .. "give you, anywhere outside a dungeon, a raid or a "
               .. "battleground."] },

        -- How near a group member has to be to count, the owner's request of
        -- 2026-10-04, after a Paladin far across the Barrens was counted the
        -- moment he entered the zone. The default of 100 yards is his. It
        -- reaches only where the client says how far somebody is, see
        -- DistanceTo; elsewhere the older answers decide, see Reachable.
        { key = "reachYards", type = "number", default = 100,
          label = L["Count group members within"], min = 10, max = 200, step = 10,
          format = function(v) return L["%d yd"]:format(v) end,
          desc  = L["Group members farther away are not counted for buffs "
               .. "they could give you or buffs you could give them."] },


        -- General Warnings and Combat Buffs stood here as two sections, each
        -- with buttons that moved its display, and a gray line said that a
        -- buff could not change displays. All three went with the redesign of
        -- 2026-10-15, the owner's word: every buff chooses its bar in its own
        -- details since, and the bars are moved in bar management.

        -- No heading here. The picker below carries its own, "Class buffs",
        -- which is a fixed one with a rule, and two headings over one list is
        -- one more than the list has parts.
        { type = "custom",
          build   = function(holder, width) return BuildPicker(holder, width) end,
          refresh = function() RefreshPicker() end },


        { type = "group", label = L["Buffs on You Right Now"] },

        -- Not a setting at all, which is the whole reason the option framework
        -- has a way out. Before this it was the only thing keeping BuffExpiry
        -- on a page of its own.
        { type = "custom",
          build   = function(holder, width) return BuildList(holder, width) end,
          refresh = function() RefreshList() end },


        -- Which individual buffs the player has switched off, keyed by
        -- "CLASS/entryId". Absent means all of them are on, which is why there
        -- is no default table here: one shared between profiles by reference
        -- is a bug waiting for somebody to find it.
        { key = "off", type = "store" },

        -- Which trackings the player wants running, keyed by entry id. Absent
        -- means the entry's own default rather than on or off, because they
        -- differ: gathering starts ticked and a racial nobody chose does not.
        { key = "trackPick", type = "store" },

        -- How many targets a capped group buff has to be up on, keyed the same
        -- way as `off`. Thorns had the only one until 2026-10-05; see
        -- `targets` in Data/Buffs.lua for the six that joined it.
        { key = "targets", type = "store" },

        -- Which of those are tracked on every group or raid member instead of
        -- a number, keyed the same way. The owner's switch of 2026-10-05.
        { key = "targetsAll", type = "store" },

        -- Whether such a buff is tracked on yourself as well, keyed the same
        -- way, and whether the profile's older settings were carried over to
        -- that meaning: see CarryOverTargets. Both since 2026-10-06.
        { key = "targetsSelf", type = "store" },
        { key = "targetsSplit", type = "store" },

        -- Whether an entry with `combatOnly` warns only during a fight, keyed
        -- the same way. Battle Shout's switch, since 2026-10-07.
        { key = "combatOnly", type = "store" },

        -- Whether an entry with `offerSwitch` draws its icon when somebody else
        -- could give it, keyed the same way: see M:OfferWarns.
        { key = "offerWarn", type = "store" },
},
})

local TICK = 1      -- seconds between checks

-- The icons are drawn on the profile's bars since the redesign of 2026-10-15,
-- see Core/Bars.lua and Core/Warnings.lua. This module only says what it
-- wants on them: every item names its entry and the bar the entry starts
-- on, General Warnings or, for what `display = "tracker"` sends below the
-- middle of the screen, Combat Buffs. Where the bars sit by default, and why
-- Combat Buffs sits 21 percent below the middle, is in Core/Warnings.lua.

-- The lines between the three lengths, in seconds.
--
-- **Two of these used to be one**, and the comment here used to say that
-- everything Vanilla hands out is either a couple of minutes or half an hour,
-- so nothing real sits near the boundary. That is false on this build, measured
-- on 2026-09-22: **four entries last exactly ten minutes**, Thorns, Inner Fire,
-- Shadow Protection and Lightning Shield, and they landed on the long side of a
-- strictly-less-than comparison. Five minutes of warning on a ten minute buff
-- leaves the icon up for half its life.
--
-- So there are three bands now, and the middle one exists for those four. The
-- lengths this build actually uses are listed in Data/Buffs.lua; the short band
-- holds Battle Shout and Touch of Weakness, the middle one everything from ten
-- minutes to half an hour, and the long one the armour spells and the hour long
-- group buffs.
local SHORT_BUFF  = 600     -- under ten minutes
local MEDIUM_BUFF = 1800    -- under half an hour

--- How much has to be left before a buff is worth showing.
--
-- Two settings with a fixed boundary, which replaced a single fraction of the
-- buff's own length. A quarter of a Battle Shout is forty five seconds, and a
-- quarter of an armour spell is seven and a half minutes: one fraction cannot
-- serve both.
--
-- **Battle Shout runs three minutes on this build**, not the two it ran in
-- Vanilla, which is what both of these comments said until 2026-09-22. Read
-- off this game's own spell database rather than the client, so it is a source
-- rather than a measurement; nothing depends on the number, since the duration
-- shown is always the one read off the aura.
local function WarnWindow(duration)
    duration = duration or 0
    if duration < SHORT_BUFF  then return M.db.warnShort  end
    if duration < MEDIUM_BUFF then return M.db.warnMedium end
    return M.db.warnLong
end

-- ---------------------------------------------------------------------------
-- Reading, and when it is allowed at all
--
-- Measured on build 69913, 2026-09-19, and written up in AGENTS.md. In combat
-- this client answers nothing about auras: walking the slots raises on all
-- forty, and asking by spell id or by name returns nil without raising, for a
-- buff demonstrably still on the player. The combat log never fires and the
-- UNIT_AURA payload carries two fields neither of which can be touched.
--
-- So nothing is read in combat. Everything is read while the client still
-- answers, the expiry times are kept, and the countdown afterwards is
-- arithmetic on numbers already in hand, which is exact rather than
-- approximate and cheaper than scanning once a second.
--
-- The one thing that still works in a fight is UNIT_SPELLCAST_SUCCEEDED, which
-- carries a plain readable spell id. That is what lets a recast clear its own
-- warning, and it is the reason a missing self buff may be shown in combat at
-- all: the player can act on it and we can see them do it.
-- ---------------------------------------------------------------------------

--- What the last look found, per entry id. Survives combat; that is the point.
M.seen = {}

--- The same, for entries that come one per caster: every variant rather than
--- the first one found, because holding one blessing says nothing about the
--- other two.
M.seenVariants = {}

--- Which of this character's tracked spells they have actually learned.
local known = {}

local function ClassToken()
    if not UnitClass then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and token or nil
end

local function InCombat()
    return InCombatLockdown and InCombatLockdown() and true or false
end

--- Which of the two displays an entry draws on.
--
-- **Every entry names its own, and there is no rule behind it.** There was one
-- for an afternoon, deriving it from `kind`, and the owner took it out on
-- 2026-09-22 after looking at what it produced: it sent the armour spells,
-- Righteous Fury and Demon Armor down there, all of which run half an hour and
-- are never recast in a fight, and it sent Thorns down as a self buff when
-- Thorns is cast on somebody else.
--
-- What the lower display is actually for is **a buff that can run out while you
-- are fighting**, and no field in these tables answers that question. Length
-- comes close and gets Thorns wrong; `kind` gets the half hour buffs wrong. So
-- it is a per entry decision, made by the person who has to look at the screen.
local function DisplayFor(entry)
    return entry.display or "warnings"
end

local function BuffKey(class, entry)
    -- A buff of no class has one switch for every class, see FP.sharedBuffs.
    if entry.shared then return "ALL/" .. tostring(entry.id) end
    return tostring(class) .. "/" .. tostring(entry.id)
end

--- The key an entry's bar and own warning time are kept under, see
--- Core/Bars.lua. The page's own key with the page in front of it.
local function EntryKey(class, entry)
    return "buffs:" .. BuffKey(class, entry)
end
M.EntryKey = EntryKey

--- The bar an entry starts on: what used to be the display it drew on.
local function FactoryBar(entry)
    if DisplayFor(entry) == "tracker" then return "combat" end
    return "general"
end
M.FactoryBar = FactoryBar

--- How much has to be left of a buff before it warns: the entry's own time
--- where the player gave it one, the page's rule for its length otherwise.
--
-- Zero is a time, and means no warning before the buff runs out; the missing
-- warning and the rank warning are not affected, since neither is a time.
function M:WarnAt(class, entry, duration)
    local own = FP.Bars.Warn(FP.Bars.Store(), EntryKey(class, entry))
    if own then return own end
    return WarnWindow(duration)
end

--- The non-localized race token and the race id of the player.
--
-- Both, because they come from different places and either alone would be a
-- claim. The id is out of this build's own database; the token is what this
-- game has always returned for that id, which is knowledge rather than a
-- measurement, and knowledge is the thing this project has been wrong about.
local function RaceOf()
    if not UnitRace then return nil, nil end
    local ok, _, token, id = pcall(UnitRace, "player")
    if not ok then return nil, nil end
    return token, id
end

-- The filtered list, and the character it was filtered for. Neither the class
-- nor the race can change under a running character, so this is worked out
-- once rather than on every tick; the key is what makes that safe rather than
-- merely true today.
local raceEntries, raceEntriesKey

--- Entries for this character, whatever their switches say.
--
-- The class, and where an entry names a race, the race as well. A racial is
-- the only thing in the tables that is not a property of the class alone, and
-- filtering here rather than at each reader means every one of them, the scan,
-- the evaluation, the cast watcher and the known-spell pass, gets the same
-- answer without being told about races at all.
local function ClassEntries()
    local class = ClassToken()
    local token, id = RaceOf()

    local key = tostring(class) .. "/" .. tostring(token) .. "/" .. tostring(id)
    if raceEntriesKey ~= key then
        local out = {}
        for _, entry in ipairs(FP.classBuffs[class] or {}) do
            if not (entry.race or entry.raceId)
               or entry.race == token or entry.raceId == id then
                out[#out + 1] = entry
            end
        end
        -- And the buffs of no class, which every character has alike.
        for _, entry in ipairs(FP.sharedBuffs or {}) do out[#out + 1] = entry end
        raceEntries, raceEntriesKey = out, key
    end

    return class, raceEntries
end

local KIND_SETTING = {
    self   = "selfBuffs",
    group  = "groupBuffs",
    aura   = "selfBuffs",     -- an aura is a self buff that never expires
    weapon = "enchants",
}

--- Whether an entry's kind is switched off in General, which leaves its row
--- in the class block with nothing to do.
local function KindOff(entry)
    -- A buff of no class answers to its own tick alone: "Your own buffs" is
    -- about the spells a character casts on itself.
    if entry.shared then return false end
    local setting = KIND_SETTING[entry.kind]
    return setting ~= nil and M.db[setting] == false
end

--- Has the player switched this one off on the selection page?
--
-- Two ways to be off: the master switch for its kind, or the switch on its own
-- row. Either is enough, and neither clears the other, so turning a kind back
-- on restores exactly what was there before rather than everything.
function M:BuffOff(class, entry)
    local setting = KIND_SETTING[entry.kind]
    if setting and self.db[setting] == false then return true end

    local off = self.db.off
    local stored = off and off[BuffKey(class, entry)]

    -- Nothing stored means the entry's own answer, which is on for all but one
    -- of them. `default = false` is for a buff somebody might reasonably not
    -- want running: see Touch of Weakness in Data/Buffs.lua.
    if stored == nil then return entry.default == false end
    return stored and true or false
end

--- How many people a capped group buff has to be up on.
--
-- Thorns and the buffs built like it. A group buff otherwise means everybody,
-- and Thorns in practice means the tank, so the player says how many targets
-- they are actually keeping it on and the count is measured against that.
function M:TargetCount(class, entry)
    local spec = entry.targets
    if not spec then return nil end
    local stored = self.db.targets and self.db.targets[BuffKey(class, entry)]
    return tonumber(stored) or spec.default or 1
end

function M:SetTargetCount(class, entry, value)
    -- Created on demand, like `off`: a default table in the option schema
    -- would be shared between every profile by reference.
    self.db.targets = self.db.targets or {}
    self.db.targets[BuffKey(class, entry)] = value
end

--- Whether a capped group buff is tracked on every group or raid member
--- rather than on a number of them.
--
-- The owner's switch of 2026-10-05, so that nobody has to set the number to
-- the size of the group each time. Off unless stored, and only for an entry
-- with a stepper to stand in for.
function M:TargetsAll(class, entry)
    if not entry.targets then return false end
    local stored = self.db.targetsAll and self.db.targetsAll[BuffKey(class, entry)]
    return stored == true
end

function M:SetTargetsAll(class, entry, value)
    self.db.targetsAll = self.db.targetsAll or {}
    self.db.targetsAll[BuffKey(class, entry)] = value and true or nil
end

--- Whether a buff handed to others is tracked on yourself as well.
--
-- Since 2026-10-06, the owner's choice: the tick on the row says whether the
-- buff is tracked at all, and this whether on you. On unless stored, which is
-- what the tick meant before, except where `targets` carries `onSelf = false`:
-- Amplify and Dampen Magic replace each other, so on by default, ticking both
-- would ask for two buffs on you that cannot both be there.
function M:TargetsSelf(class, entry)
    local spec = entry.targets
    if not spec then return true end
    local stored = self.db.targetsSelf and self.db.targetsSelf[BuffKey(class, entry)]
    if stored == nil then return spec.onSelf ~= false end
    return stored == true
end

function M:SetTargetsSelf(class, entry, value)
    self.db.targetsSelf = self.db.targetsSelf or {}
    self.db.targetsSelf[BuffKey(class, entry)] = value and true or false
end

--- Whether an entry warns only during a fight.
--
-- Battle Shout's switch, asked for on CurseForge on 2026-10-07 by a Warrior
-- who saw the warning between every pull. It costs rage, and rage runs down
-- out of combat, so the warning asked for something that often could not be
-- done. In a fight the cast is seen by UNIT_SPELLCAST_SUCCEEDED, so the icon
-- goes away when it is answered. On unless stored, the owner's word, and only
-- for an entry declaring `combatOnly` in Data/Buffs.lua.
function M:CombatOnly(class, entry)
    if not entry.combatOnly then return false end
    local stored = self.db.combatOnly and self.db.combatOnly[BuffKey(class, entry)]
    if stored == nil then return true end
    return stored == true
end

function M:SetCombatOnly(class, entry, value)
    self.db.combatOnly = self.db.combatOnly or {}
    self.db.combatOnly[BuffKey(class, entry)] = value and true or false
end

--- Does a buff somebody else could give draw its icon?
--
-- Shadow Protection's switch, the owner's word of 2026-11-04, after an icon he
-- did not need in a group with a Priest on 2026-10-10. The tick on the row
-- could silence it only by ending a Priest's own tracking and count as well.
-- Only the icon answers to this, like the switches per place: the offer stays
-- in the list of buffs on you and in the scan. Nothing stored means on, so a
-- profile from before goes on warning, and one that starts from nothing stores
-- off, see `fresh`. Only for an entry declaring `offerSwitch` in Data/Buffs.lua.
function M:OfferWarns(class, entry)
    if not entry.offerSwitch then return true end
    local stored = self.db.offerWarn and self.db.offerWarn[BuffKey(class, entry)]
    return stored ~= false
end

function M:SetOfferWarns(class, entry, value)
    self.db.offerWarn = self.db.offerWarn or {}
    self.db.offerWarn[BuffKey(class, entry)] = value and true or false
end

--- The camp bonuses a class wants watched, see FP.campBonuses.
--
-- Per class, like every switch on this page but the tick of Camp Benefits
-- itself, so a Warrior and a Mage sharing a profile keep their own: one wants
-- strength, the other mana. Three at most, the owner's word of 2026-10-15,
-- since no character carries more at once.
local MAX_CAMP_PICKS = 3

local function CampKey(class, bonus)
    return tostring(class) .. "/" .. tostring(bonus.id)
end

function M:CampWanted(class, bonus)
    local stored = self.db.camp and self.db.camp[CampKey(class, bonus)]
    return stored == true
end

--- The ticked bonuses of a class, in the order of the table.
function M:CampPicks(class)
    local out = {}
    for _, bonus in ipairs(FP.campBonuses or {}) do
        if self:CampWanted(class, bonus) then out[#out + 1] = bonus end
    end
    return out
end

--- Whether a class has as many bonuses ticked as it may.
function M:CampFull(class)
    return #self:CampPicks(class) >= MAX_CAMP_PICKS
end

--- Ticks one bonus or takes the tick away. Never a fourth: false then.
function M:SetCampWanted(class, bonus, value)
    if value and not self:CampWanted(class, bonus) and self:CampFull(class) then
        return false
    end
    -- Created on demand, like `off`.
    self.db.camp = self.db.camp or {}
    self.db.camp[CampKey(class, bonus)] = value and true or nil
    return true
end

--- Gives a profile's older settings their meaning under the new tick, once.
--
-- Until 2026-10-06 the tick was your own copy alone, and the count beside it
-- stood on its own, so a Druid keeping Thorns on the tank left the row
-- unticked with a count of one. The tick means the buff is tracked at all
-- since, which would have stopped that, so such a row is ticked once with
-- "Track on yourself" off: the same thing in the new words. Remembered in the
-- profile, so a row unticked on purpose later stays unticked.
function M:CarryOverTargets()
    local db = self.db
    if type(db) ~= "table" or db.targetsSplit then return end
    for class, entries in pairs(FP.classBuffs or {}) do
        for _, entry in ipairs(entries) do
            if entry.targets then
                local key = BuffKey(class, entry)
                local stored = db.off and db.off[key]
                local unticked
                if stored == nil then unticked = (entry.default == false)
                else unticked = (stored == true) end
                local count = tonumber(db.targets and db.targets[key]) or 0
                local everybody = db.targetsAll and db.targetsAll[key] == true
                if unticked and (count > 0 or everybody) then
                    db.off = db.off or {}
                    db.off[key] = false
                    db.targetsSelf = db.targetsSelf or {}
                    db.targetsSelf[key] = false
                end
            end
        end
    end
    db.targetsSplit = true
end

--- The entries of a class this one cannot sit beside on a player.
--
-- Amplify Magic and Dampen Magic replace each other, so asking for both would
-- leave an icon nobody could clear; `excludes` in Data/Buffs.lua names them.
local function Excluded(class, entry)
    local out = {}
    for _, id in ipairs(entry.excludes or {}) do
        for _, other in ipairs(FP.classBuffs[class] or {}) do
            if other.id == id then out[#out + 1] = other end
        end
    end
    return out
end

--- Switches one buff on or off.
function M:SetBuffOff(class, entry, value)
    -- Created on demand. A default table in the option schema would be shared
    -- between every profile by reference.
    self.db.off = self.db.off or {}

    -- Both answers are written down rather than only the off one. Absent used
    -- to mean on, which cannot express an entry that starts off: switching one
    -- of those on would store nothing and it would read as off again on the
    -- next look.
    self.db.off[BuffKey(class, entry)] = value and true or false
end

--- What a profile that starts from nothing holds beyond the defaults, see
--- EmptyProfile in Core/Config.lua: the defaults that changed after profiles
--- had been kept with the old ones.
--
-- **Shadowguard starts off since 2026-10-18**, the owner's word, written here
-- rather than as `default = false` on its entry: a profile from before stored
-- nothing for it and keeps it on, unless it was switched off there. **So does
-- the icon for Shadow Protection from others since 2026-11-04**, see
-- M:OfferWarns.
function M.fresh(branch)
    branch.off = { ["PRIEST/shadowguard"] = true }
    branch.offerWarn = { ["PRIEST/shadowProtection"] = false }
end

-- ---------------------------------------------------------------------------
-- Weapon enchants
--
-- A Shaman imbue and a Rogue poison are not auras. They live on the weapon and
-- they are read in Core/Weapon.lua, which Consumables reads too: neither module
-- can tell an imbue from an oil, so both ask the one question the client
-- answers and share the code that asks it.
--
-- The threshold treats them as long buffs. Every imbue and poison in this
-- content runs half an hour or more, so the ten minute boundary is never
-- close, and asking the client for a duration it does not offer would buy
-- nothing.
-- ---------------------------------------------------------------------------

local SLOT = FP.WeaponSlot


--- Can this character cast anything that satisfies the entry?
--
-- A Mage below the level for any armour spell has nothing missing; they simply
-- do not have it yet. For a weapon entry the question is whether there is a
-- weapon there at all.
local function Castable(entry)
    -- Nothing to learn for a buff anyone can have, Camp Benefits.
    if entry.anyone then return true end

    -- The pet's mood needs Feed Pet and nothing more: a Hunter below 10 has no
    -- pet to ask about.
    if entry.kind == "pet" then
        for _, id in ipairs(entry.requires or {}) do
            if known[id] then return true end
        end
        return false
    end

    if entry.kind == "weapon" then
        if not FP:HasWeapon(entry.slot) then return false end
        -- Having a weapon is not being able to enchant it. Found on a level 1
        -- Shaman, who was told their main hand imbue was missing before they
        -- had one to cast: a warning nobody can clear is the thing the rule in
        -- AGENTS.md exists to prevent.
        if not entry.requires then return true end
        for _, id in ipairs(entry.requires) do
            if known[id] then return true end
        end
        return false
    end

    for _, line in ipairs(entry.lines or {}) do
        for _, id in ipairs(line) do
            if known[id] then return true end
        end
    end
    return false
end

--- The best rank of this entry the player actually knows.
--
-- What they would cast if they cast it now, so it is also what a missing buff
-- should be named and pictured as.
local function BestKnown(entry)
    for _, line in ipairs(entry.lines or {}) do
        for rank = #line, 1, -1 do
            if known[line[rank]] then return line[rank] end
        end
    end
    return nil
end

--- The icon to show for a buff that is not on the player.
--
-- There is no aura to take one from, so it comes from the spell instead, or
-- from the weapon itself where there is no spell at all.
local function EntryIcon(entry)
    -- Feed Pet, since feeding is what the icon asks for.
    if entry.kind == "pet" then
        return FP:SpellIcon(entry.requires and entry.requires[1])
    end

    if entry.kind == "weapon" then
        -- The imbue you would cast, before the weapon you would cast it on.
        -- Both are pictures of something true, and this one is the more useful
        -- of the two: a Rockbiter icon says an imbue is missing, where a
        -- picture of your own axe says you are holding an axe.
        --
        -- It is also the more reliable. The weapon's texture needs
        -- GetInventoryItemTexture, which nobody had asked this build about,
        -- and when that returns nothing the icon is drawn with no texture at
        -- all: present, in its place, and invisible.
        for _, id in ipairs(entry.requires or {}) do
            if known[id] then
                local icon = FP:SpellIcon(id)
                if icon then return icon end
            end
        end

        local slot = SLOT[entry.slot]
        if slot and GetInventoryItemTexture then
            local ok, texture = pcall(GetInventoryItemTexture, "player", slot)
            if ok and texture then return texture end
        end
        return nil
    end

    local icon = FP:SpellIcon(BestKnown(entry))
    if icon then return icon end

    -- Nothing in it is known, which is the ordinary case for a buff somebody
    -- else would cast: the best rank of the first line is then the picture,
    -- since there is no "what you would cast" to go on.
    local first = entry.lines and entry.lines[1]
    return first and FP:SpellIcon(first[#first]) or nil
end

--- Re-reads which spells this character knows.
--
-- Once per spellbook change rather than once per scan: it walks every rank of
-- every entry for the class, and nothing about it changes between two ticks.
function M:RefreshKnown()
    for id in pairs(known) do known[id] = nil end

    local _, entries = ClassEntries()
    for _, entry in ipairs(entries) do
        for _, line in ipairs(entry.lines or {}) do
            for _, id in ipairs(line) do
                if FP:KnowsSpell(id) then known[id] = true end
            end
        end
        -- A weapon entry has no lines, only the spells that let you enchant
        -- with it. Forgetting these here would make Castable answer no for
        -- every Shaman alive.
        for _, id in ipairs(entry.requires or {}) do
            if FP:KnowsSpell(id) then known[id] = true end
        end
    end

    -- The tracking spells, which belong to a profession rather than to a
    -- class, so they are asked for whoever this is. This is the whole of the
    -- profession gate: a character who has never trained Mining does not know
    -- Find Minerals, nothing is ever put in this table for them, and the
    -- warning has nothing to arm from.
    for _, entry in ipairs(FP.trackingTypes or {}) do
        if FP:KnowsSpell(entry.spell) then known[entry.spell] = true end
    end
end

--- The Hunter pet's mood: 1 unhappy, 2 content, 3 happy, or nil while there
--- is no living Hunter pet or the client will not say.
--
-- Asked of the client when the display is drawn rather than kept, so there is
-- nothing to go stale. C_PetInfo.GetPetHappiness carries no secrecy marker in
-- this build's API documentation, where UnitHealth carries three; read behind
-- a pcall and through PlainNumber all the same, as everything here is.
local function PetHappiness()
    if not (C_PetInfo and C_PetInfo.GetPetHappiness) then return nil end
    if HasPetUI then
        local ok, _, isHunterPet = pcall(HasPetUI)
        if not ok or FP:Truth(isHunterPet) ~= true then return nil end
    end
    if UnitIsDead then
        local ok, dead = pcall(UnitIsDead, "pet")
        if ok and FP:Truth(dead) == true then return nil end
    end
    local ok, happiness = pcall(C_PetInfo.GetPetHappiness)
    if not ok then return nil end
    return FP:PlainNumber(happiness)
end

--- One aura on the player, asked for by id rather than found by walking.
--
-- By id on purpose. Enumerating means a single secret aura can poison the
-- whole pass; asking for what we already know we want confines any refusal to
-- that one buff.
local function ReadPlayerAura(spellId)
    local get = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
    if not get then return nil end

    local ok, aura = pcall(get, spellId)
    if not ok or type(aura) ~= "table" then return nil end
    return aura
end

--- A counted buff's charges from its stack, or nil when it cannot be handled.
--
-- A buff with one charge shows no stack and reads 0, measured on Touch of
-- Weakness on 2026-09-29, and the shield probe has read it so ever since. The
-- aura is there, so 0 is one.
local function ChargesOf(aura)
    local n = FP:PlainNumber(aura.applications)
    if n == nil then return nil end
    return math.max(n, 1)
end

--- What is satisfying this entry right now, or nil.
local function ReadEntry(entry)
    for lineIndex, line in ipairs(entry.lines or {}) do
        -- Highest rank first. Somebody who knows two ranks has the better one
        -- up, and finding the weaker one first would report a downgrade that
        -- is not there.
        for rank = #line, 1, -1 do
            local aura = ReadPlayerAura(line[rank])
            if aura then
                return {
                    spellId  = line[rank],
                    line     = lineIndex,
                    rank     = rank,
                    icon     = aura.icon,
                    name     = aura.name,
                    duration = aura.duration or 0,
                    expires  = aura.expirationTime or 0,
                    -- For the tooltip of Camp Benefits, which is the only
                    -- place that says what a camp gave.
                    instance = FP:PlainNumber(aura.auraInstanceID),
                    -- Only for a counted entry, and only when the number can be
                    -- handled: a secret one would raise at the first
                    -- comparison, and nil makes the count stand aside.
                    charges  = entry.counted and ChargesOf(aura) or nil,
                }
            end
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- What a camp gave
--
-- Written on Camp Benefits and nowhere else, see FP.campBonuses in
-- Data/Buffs.lua: its description names each object at the fire, and a
-- bonus is known by the names of the objects that give it. Read out of combat
-- with everything else, and only while a bonus is ticked.
-- ---------------------------------------------------------------------------

-- Every object's name, kept once the client has given all thirty. Until then
-- the list is built again on each look, and a name still missing leaves its
-- line unmatched, which reads as unknown rather than as missing.
local campNames

local function ItemName(item)
    local get = C_Item and C_Item.GetItemNameByID
    if get then
        local ok, name = pcall(get, item)
        name = ok and FP:Plain(name) or nil
        if name then return name end
    end
    -- Not fetched yet: asked for, and there on a later look.
    local request = C_Item and C_Item.RequestLoadItemDataByID
    if request then pcall(request, item) end
    return nil
end

local function CampNames()
    if campNames then return campNames, true end
    local list, complete = {}, true
    for _, bonus in ipairs(FP.campBonuses or {}) do
        for _, item in ipairs(bonus.objects or {}) do
            local name = ItemName(item)
            if name then list[#list + 1] = { name = name, bonus = bonus.id, item = item }
            else complete = false end
        end
    end
    if complete then campNames = list end
    return list, complete
end

--- The description of Camp Benefits, or nil.
--
-- The aura's tooltip has the name, the description and the time left, one
-- line each, measured on 2026-10-15; the description is the second.
local function CampText(instance)
    local get = C_TooltipInfo and C_TooltipInfo.GetUnitBuffByAuraInstanceID
    if not (get and instance) then return nil end
    local ok, data = pcall(get, "player", instance)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then
        return nil
    end
    local line = data.lines[2]
    return type(line) == "table" and FP:Plain(line.leftText) or nil
end

--- What Camp Benefits lists: [bonus id] = true, or nil when it cannot be
--- told; and the lines no object's name matched.
local function ReadCamp(state)
    local text = state and CampText(state.instance)
    if not text then return nil, {} end
    return FP:CampListed(text, (CampNames()))
end

--- The ticked bonuses that a class buff on the player stands in for.
local function CampCovered(picks)
    local out = {}
    for _, bonus in ipairs(picks) do
        for _, id in ipairs(FP:CampCounterparts(bonus)) do
            if ReadPlayerAura(id) then
                out[bonus.id] = true
                break
            end
        end
    end
    return out
end

--- The ticked bonuses with an aura of their own, `ownAura`, that is on the
--- player: [bonus id] = when it ends, 0 for never. Read by id like the rest.
local function CampOwn(picks)
    local out = {}
    for _, bonus in ipairs(picks) do
        if bonus.ownAura then
            local aura = ReadPlayerAura(bonus.spell)
            if aura then out[bonus.id] = FP:PlainNumber(aura.expirationTime) or 0 end
        end
    end
    return out
end

--- Which of those are still on at `now`. Counted down from the read in a
--- fight, where nothing can be read: the end of an aura is a known time.
local function OwnAt(own, now)
    local out = {}
    for id, expires in pairs(own or {}) do
        if expires <= 0 or expires > now then out[id] = true end
    end
    return out
end

--- The picture of a bonus that is missing: its first object's.
local function CampIcon(bonus)
    local get = C_Item and C_Item.GetItemIconByID
    local first = bonus.objects and bonus.objects[1]
    if get and first then
        local ok, icon = pcall(get, first)
        if ok and icon then return icon end
    end
    return FP:SpellIcon(bonus.spell) or FP.FALLBACK_ICON
end

-- ---------------------------------------------------------------------------
-- Buffs that come one per caster
--
-- A Paladin can put one blessing on you. Two Paladins therefore mean two
-- blessings, and a Warrior carrying Might while Kings is also on offer is
-- short one. The old model treated the whole set as a single slot and said so
-- in a comment; it was wrong, and the owner caught it.
--
-- Three numbers decide what is shown:
--
--   wanted   how many the class asks for, from Data/Buffs.lua
--   casters  how many people in range could cast one, which is the real cap
--   active   how many of the wanted ones are on you now
--
-- Wanting three while standing next to one Paladin means one. Asking for more
-- than anybody present can give is the warning nobody can clear.
-- ---------------------------------------------------------------------------

-- Answered once per variant and remembered. FP:SpellName goes to the client
-- and this is asked inside a loop that runs every second.
local variantKnown = {}

--- Does this client know the spell behind a variant at all?
--
-- **The guard that keeps a guessed id from becoming a permanent warning.**
-- Blessing of Kings did not exist in Vanilla and its ids here are the Burning
-- Crusade ones, taken on faith. If this build does not have them, a Warrior
-- would be told for ever that Kings is missing, and no Paladin alive could
-- clear it. A variant the client does not recognize is simply not asked for.
local function VariantExists(entry, variant)
    local cached = variantKnown[variant.ids]
    if cached ~= nil then return cached end

    local exists = false
    for _, id in ipairs(variant.ids) do
        if FP:SpellName(id) then
            exists = true
            break
        end
    end

    variantKnown[variant.ids] = exists
    return exists
end

--- Which variants of an entry are on the player, keyed by variant id.
local function ReadVariants(entry)
    local active = {}
    for _, variant in ipairs(entry.variants or {}) do
        -- Highest rank first, as everywhere else.
        for rank = #variant.ids, 1, -1 do
            local aura = ReadPlayerAura(variant.ids[rank])
            if aura then
                active[variant.id] = {
                    spellId  = variant.ids[rank],
                    icon     = aura.icon,
                    name     = aura.name,
                    duration = aura.duration or 0,
                    expires  = aura.expirationTime or 0,
                    source   = aura.sourceUnit,
                }
                break
            end
        end
    end
    return active
end

--- Has the player switched warnings off for the state they are in?
--
-- Two separate settings rather than one, because they are unrelated situations
-- and somebody may well want to be quiet in an inn while still being told on
-- a mount.
--
-- A third, shapeshifted, was built and taken straight back out on 2026-09-20.
-- It does not mean what it sounds like: a Druid in bear form can still be
-- handed a blessing, a Warrior is in a stance permanently, and the classes
-- where it would have mattered are not the ones this addon warns for.
local function Suppressed(db)
    if db.warnMounted == false and IsMounted then
        local ok, mounted = pcall(IsMounted)
        if ok and FP:Truth(mounted) == true then return true end
    end

    if db.warnResting == false and IsResting then
        local ok, resting = pcall(IsResting)
        if ok and FP:Truth(resting) == true then return true end
    end

    return false
end

-- Which switch each kind of place answers to. The second return of
-- IsInInstance is a token rather than display text, the same kind of word as
-- a class token, so comparing against it is allowed; outside every instance it
-- reads "none". A type this list does not know answers to no switch at all,
-- which is the quiet direction. **No arena**: WoW Forever's content has none,
-- the owner's correction of 2026-09-27, so one would be such a type.
--
-- **No battleground either**, since 2026-10-04. The client refuses every aura
-- read there from the gate until the battle has ended, in combat and out of
-- it, measured with COLLECTING at the top of this file through a whole
-- battle. A warning about a buff somebody else gives could never be cleared
-- there, Blind() kept it away anyway, and the switch that seemed to allow it
-- was taken out once the measurement answered the owner's question whether it
-- could go. A profile that stored it keeps a key nothing reads.
local PLACE_SWITCHES = {
    none  = "othersInWorld",
    party = "othersInDungeons",
    raid  = "othersInRaids",
}

--- The switch for the place the player is in, or nil when there is none.
local function PlaceSwitch()
    if not IsInInstance then return nil end
    local ok, _, kind = pcall(IsInInstance)
    kind = ok and FP:Plain(kind)
    return kind and PLACE_SWITCHES[kind] or nil
end

--- Will this client answer a question about auras at all, right now?
--
-- **Asked rather than inferred, and that distinction is the whole bug.** A
-- refused read and an absent buff both come back as nil from
-- GetPlayerAuraBySpellID, so nothing downstream can tell them apart, and
-- Scan treats nil as "gone" because that is what it means when the client is
-- answering.
--
-- InCombatLockdown() was standing in for "the client will answer" and is not
-- the same question. Reported from an instance on 2026-09-20: missing icons
-- appeared mid fight for buffs the player was wearing, including their own
-- Inner Fire, and cleared only when the fight ended. One scan in a moment
-- where reads were refused while the lockdown flag was still false wiped the
-- entire state, and every scan after it was skipped for being in combat, so
-- the wipe stood until combat ended.
--
-- The index route is the detector because it is the one that says no out loud:
-- measured on this build, it raises where the by id route quietly returns nil.
-- An empty slot 1 on a player with no buffs returns nil without raising, which
-- is an answer and not a refusal.
local function ReadsAllowed()
    local byIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if not byIndex then return false end
    return (pcall(byIndex, "player", 1, "HELPFUL"))
end

-- Whether the last scan found the client answering. nil until the first one,
-- which counts as answering: nothing has been read, and nothing is shown then
-- anyway.
--
-- **A battleground refuses every aura read out of combat too.** Measured by
-- the owner on 2026-10-03 at the gate of one: all forty index reads refused,
-- no fight anywhere. Scan stood aside correctly, but what other people give
-- you was still judged, against a picture in which none of it had ever been
-- seen, so five buffs he was wearing showed as missing. Combat already hid
-- those icons; a refusal now does the same, by the same rule: nothing rather
-- than something stale.
local answering = nil

--- One line in the measurement log, see COLLECTING at the top of the file.
-- The zone is display text and only ever read by a person, never compared.
local function NoteReads(allowed)
    local log = type(FP.global.auraReads) == "table" and FP.global.auraReads or {}
    local okPlace, _, kind = pcall(IsInInstance)
    local zone = GetRealZoneText and FP:Plain(select(2, pcall(GetRealZoneText)))
    log[#log + 1] = string.format("%s  %s  %s, %s, %s",
        date("%Y-%m-%d %H:%M:%S"),
        allowed and "answers" or "REFUSES",
        tostring(okPlace and FP:Plain(kind) or "?"),
        InCombat() and "in combat" or "out of combat",
        tostring(zone or "?"))
    while #log > 200 do table.remove(log, 1) end
    FP.global.auraReads = log
end

--- Is this a moment where nothing can be known about buffs others give?
-- In combat, or while the client refuses aura reads.
local function Blind()
    return InCombat() or answering == false
end

--- Reads everything, and only while the client will answer.
function M:Scan()
    -- Dead is not a state to read or to warn from: everything is missing and
    -- none of it is actionable. Keeping the last living state rather than
    -- wiping it means the display is right again the moment you are back up,
    -- without waiting for a scan.
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return end

    local before = answering
    answering = ReadsAllowed()
    if COLLECTING and answering ~= before then
        FP:Safe("BuffExpiry:NoteReads", NoteReads, answering)
    end
    if not answering then return end

    local now = GetTime()
    local enchants = FP:WeaponEnchants()

    local class, entries = ClassEntries()
    local picks = self:CampPicks(class)
    for _, entry in ipairs(entries) do
        if entry.kind == "weapon" then
            -- The buff place only. A stone or an oil sits in the other place
            -- on WoW Forever and says nothing about a poison or an imbue: see
            -- Core/Weapon.lua.
            local hand = enchants and enchants[entry.slot]
            local side = hand and hand.buff
            if side and side.has then
                self.seen[entry.id] = {
                    duration = SHORT_BUFF,   -- long, see the note above
                    expires  = now + side.remaining,
                    -- What the tooltip called it, "Rockbiter 1". The only
                    -- thing anywhere that says which imbue is on the weapon
                    -- and how old it is: see BetterImbue.
                    name     = side.name,
                    icon     = GetInventoryItemTexture
                               and GetInventoryItemTexture("player", SLOT[entry.slot]),
                }
            else
                self.seen[entry.id] = nil
            end
        elseif entry.kind == "pet" then
            -- Not an aura. Asked of the client when the display is drawn.
        elseif entry.perCaster then
            self.seenVariants[entry.id] = ReadVariants(entry)
        else
            local state = ReadEntry(entry)
            self.seen[entry.id] = state
            -- What the camp gave, while the player has ticked a bonus to
            -- watch; nil until read, which counts as unknown.
            if state and entry.camp and #picks > 0 then
                state.listed, state.unmatched = ReadCamp(state)
            end
            if state and state.charges then
                self.mostCharges[entry.id] =
                    math.max(self.mostCharges[entry.id] or 0, state.charges)
                -- A read within two seconds of a cast sees the buff whole, so
                -- its charges are what a recast gives now: a talent learned or
                -- unlearned since moves it, where the most ever read would not.
                local left = (state.expires or 0) - GetTime()
                if (state.duration or 0) > 0 and left >= state.duration - 2 then
                    self.fullCharges[entry.id] = state.charges
                end
            end
        end
    end

    -- And what other people are offering. Read exactly like your own, because
    -- the aura is on you either way; only who can cast it differs.
    for _, offer in ipairs(self:Offers()) do
        if offer.entry.perCaster then
            self.seenVariants[offer.entry.id] = ReadVariants(offer.entry)
        else
            self.seen[offer.entry.id] = ReadEntry(offer.entry)
        end
    end

    -- And the class buffs that replace a ticked camp bonus, read by id like
    -- every buff above, and the bonuses with an aura of their own.
    self.campCovered = CampCovered(picks)
    self.campOwn = CampOwn(picks)

    -- There was a second guard here for one morning, and it was wrong.
    --
    -- It discarded any pass that cleared every tracked entry while the player
    -- still carried auras, on the reasoning that the two contradict each
    -- other. They do not. A Warlock tracks one buff; removing it clears
    -- everything the addon knows about while the player still has food, a
    -- flask and whatever else, none of which is tracked. The guard read that
    -- as a contradiction and restored the buff it had just correctly removed,
    -- so the warning never appeared at all.
    --
    -- It was insurance against a hypothesis that was never measured, and it
    -- broke a measured case within hours of being written. ReadsAllowed above
    -- addresses the mechanism that was actually observed, and stands alone.

    -- Only true once a real look has happened, which matters more than it
    -- sounds: see Evaluate. The time is kept for /fplus buffs status, where
    -- "the last successful read was four minutes ago" is the one number that
    -- explains a display nobody can otherwise account for.
    self.scanned  = true
    self.scannedAt = GetTime()
end

--- A rank the player knows that beats the one they are wearing.
--
-- Within the active line only. Frost Armor into Ice Armor is an upgrade and
-- worth saying; Ice Armor into Mage Armor is a different choice in the same
-- slot and must never be suggested.
local function BetterRank(entry, state)
    local line = entry.lines and entry.lines[state.line]
    if not line then return nil end
    for rank = #line, state.rank + 1, -1 do
        if known[line[rank]] then return line[rank] end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- A better imbue than the one on the weapon
--
-- Asked for on 2026-09-20. A Shaman who trains Rockbiter 5 while rank 3 is
-- still on the axe gets the same "there is a better one" icon every other buff
-- gives, and got nothing at all before: a weapon entry has no aura, so there
-- was no rank to compare against.
--
-- What there is to go on is the line the client printed on the tooltip,
-- "Rockbiter 1 (51 min)". Two things come out of it and neither is an English
-- word: the trailing number is the rank, and the leading characters say which
-- imbue it is.
--
-- The second sounds worse than it is. An enchant is not named after its spell,
-- "Rockbiter 1" against "Rockbiter Weapon", but in most languages both are
-- built from the same word. So the line whose spell name the enchant points at
-- most strongly is the line that is on the weapon, see FP:EnchantEvidence:
-- the start they share, or the enchant's whole name inside the spell's, which
-- is how a German client, reported on 2026-10-05, finds "Felsbeißer 2" in
-- "Waffe des Felsbeißers". Nothing here is compared to a literal.
--
-- **A line learned from a cast needs neither reading**: the spell that put it
-- there is its rank, see *Learning a line from the cast* in Core/Weapon.lua.
-- That is also the only way on the clients whose spells and enchants use
-- different words, the Spanish "Arma comerrocas" for "Muerdepiedras 1".
--
-- **Silent unless it is sure.** No trailing number, no clear winner among the
-- lines, or a rank higher than the line is long, and nothing is claimed. An
-- upgrade icon the player cannot clear is the worst kind of wrong: they are
-- already using the best imbue they have, and no action makes it go away.
-- ---------------------------------------------------------------------------

-- Three characters is enough to separate Rockbiter from Frostbrand, Windfury
-- and Flametongue, and short enough to survive a language that inflects the
-- word. Below it the match is a coincidence.
local MIN_SHARED = 3

--- Which imbue is on the weapon, and at which rank.
-- @return rank, and the line it belongs to
local function ReadEnchantRank(entry, name)
    if type(name) ~= "string" or not entry.rankLines then return nil end

    local learned = FP:LearnedEnchant(name)
    if learned then
        for _, line in ipairs(entry.rankLines) do
            for rank, id in ipairs(line) do
                if id == learned then return rank, line end
            end
        end
    end

    local rank = tonumber(name:match("(%d+)%s*$"))
    if not rank then return nil end

    local best, shared, tied = nil, 0, false
    for _, line in ipairs(entry.rankLines) do
        for _, id in ipairs(line) do
            local spell = FP:SpellName(id)
            local run   = spell and FP:EnchantEvidence(name, spell) or 0
            if run > shared then
                best, shared, tied = line, run, false
            elseif run == shared and best and line ~= best then
                tied = true
            end
        end
    end

    if not best or tied or shared < MIN_SHARED then return nil end
    -- A number past the end of the line means the reading is wrong, not that
    -- the client has a rank the table does not know: the tables are measured.
    if rank > #best then return nil end
    return rank, best
end

--- A rank of the imbue on the weapon that has been trained since it was put on.
local function BetterImbue(entry, state)
    local rank, line = ReadEnchantRank(entry, state and state.name)
    if not rank then return nil end

    for better = #line, rank + 1, -1 do
        if known[line[better]] then return line[better] end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Handing buffs out
--
-- A group buff carries a small number: how many people near you do not have
-- it. No names, by decision, not even on hover: for buffing a group the count
-- is the thing you act on.
--
-- **It disappears in combat**, because other players cannot be read there at
-- all. A number frozen at the pull would keep claiming something that has
-- stopped being true while the player can do nothing to clear it, which is the
-- rule in AGENTS.md exactly. A group is buffed before a pull anyway.
--
-- Read by *name* rather than by id, which is the one place that is the better
-- route: every rank of a buff shares a display name, so one lookup covers a
-- whole family instead of ten. The name still comes from the client, so the
-- locale rule holds.
-- ---------------------------------------------------------------------------

-- How often the group is walked. A Priest in a full raid is three entries
-- across forty units, and none of it changes between two ticks.
local COUNT_EVERY = 2

local nameCache = {}

--- The distinct display names an entry can appear under.
local function EntryNames(entry)
    local cached = nameCache[entry.id]
    if cached then return cached end

    local names, already = {}, {}
    for _, line in ipairs(entry.lines or {}) do
        for _, id in ipairs(line) do
            local name = FP:SpellName(id)
            if name and not already[name] then
                already[name] = true
                names[#names + 1] = name
            end
        end
    end

    nameCache[entry.id] = names
    return names
end

--- Everybody else in the group, as unit tokens.
local function GroupUnits()
    local out = {}
    local size = (GetNumGroupMembers and GetNumGroupMembers()) or 0
    if size <= 1 then return out end

    if IsInRaid and IsInRaid() then
        for index = 1, size do
            local unit = "raid" .. index
            -- The player is in the raid list and is not somebody to hand a
            -- buff to: their own copy is the missing state, with its own icon.
            --
            -- Asked through FP:Truth, because UnitIsUnit answered with a
            -- secret in a dungeon on 2026-09-27 (see Tooltip.lua). An answer
            -- that cannot be read keeps the unit, which costs at most a count
            -- that includes the player, rather than an error on every pass.
            local ok, same = pcall(UnitIsUnit or function() end, unit, "player")
            if not (ok and FP:Truth(same) == true) then
                out[#out + 1] = unit
            end
        end
    else
        for index = 1, size - 1 do out[#out + 1] = "party" .. index end
    end
    return out
end

--- Which map a unit is on, or nil when the client will not say.
local function MapOf(unit)
    local get = C_Map and C_Map.GetBestMapForUnit
    if not get then return nil end
    local ok, id = pcall(get, unit)
    if not ok then return nil end
    -- One comparison inside a pcall before the number goes anywhere: a secret
    -- raises on it, see FP:Truth.
    local plain, number = pcall(function()
        return (type(id) == "number" and id == id) and id or nil
    end)
    return plain and number or nil
end

--- How far away a unit is, in yards, or nil when the client will not say.
--
-- Two routes, neither marked as secret in this build's API documentation,
-- where UnitInRange is. **Both are withheld inside an instance**, measured in
-- a battleground on 2026-10-04: UnitDistanceSquared answered 0 and "not
-- checked", UnitPosition an instance id and no coordinates. **In the open
-- world both answer plainly**, measured by the owner on 2026-10-10:
-- UnitDistanceSquared said 3 and 5, checked, for a Druid and a Priest beside
-- him, 2 yards each, and about 1.45 million for two members in Undercity,
-- 1206 and 1217 yards, while UnitPosition gave coordinates for all four.
local function DistanceTo(unit)
    if UnitDistanceSquared then
        local ok, squared, checked = pcall(UnitDistanceSquared, unit)
        if ok and FP:Truth(checked) == true then
            -- Arithmetic inside the pcall: a secret raises on it.
            local plain, yards = pcall(function()
                if type(squared) ~= "number" or squared < 0 then return nil end
                return math.sqrt(squared)
            end)
            if plain and yards then return yards end
        end
    end

    if UnitPosition then
        local function Where(who)
            local ok, y, x, _, instance = pcall(UnitPosition, who)
            if not ok then return nil end
            local plain, a, b, c = pcall(function()
                if type(y) ~= "number" or type(x) ~= "number" then return nil end
                return y + 0, x + 0, instance
            end)
            if plain and a then return a, b, c end
            return nil
        end
        local y1, x1, i1 = Where("player")
        local y2, x2, i2 = Where(unit)
        if y1 and y2 then
            local plain, same = pcall(function() return i1 == i2 end)
            if plain and same then
                return math.sqrt((y1 - y2) ^ 2 + (x1 - x2) ^ 2)
            end
            -- Another continent or instance is as far as it gets.
            if plain then return math.huge end
        end
    end
    return nil
end

--- Is this unit somebody you could actually buff right now?
--
-- Only who is in range counts, so the number is an instruction rather than a
-- statistic. Somebody two rooms away cannot be buffed and their auras are not
-- reliable anyway.
--
-- **Four answers, in order of how exact they are, and only a readable one
-- decides.**
--
--   distance    yards from DistanceTo, near within the reachYards setting
--   range       a spell's reach, where the client says it checked
--   visibility  the same zone or instance, loaded on this client
--   map         the same map as you, for when visibility cannot be read
--
-- Measured by the owner in a group on 2026-09-28: `UnitInRange` came back
-- secret, and this function used to take an answer it could not read as "in
-- range", so everybody in the group counted wherever they were. That was the
-- CurseForge report of icons for players far away on the way to a dungeon. The
-- same evening `UnitIsVisible` and `C_Map.GetBestMapForUnit` both read plainly
-- for a group member in the owner's zone: `true`, and 1421 for both of them.
--
-- **Visibility is not about a hundred yards here**, which is what it was taken
-- for that evening. On 2026-10-03 a Paladin far across the Barrens was counted
-- the moment he entered the owner's zone, and on 2026-10-04 all fourteen
-- members of a running battleground answered `true`. So it tells a zone or an
-- instance apart and nothing nearer, which is why distance comes first now.
-- Inside a dungeon it still decides alone, measured on 2026-09-28 with the
-- owner inside and four players outside: `false`, readably, while the
-- distance routes and the player's own map answer nothing there.
--
-- Nothing readable at all still counts the player, as before: that is the
-- owner's decision to make, and it has not been needed yet.
local function Reachable(unit)
    -- Every answer through FP:Truth, for the reason given in GroupUnits. One
    -- that cannot be read leaves the unit out, the quiet direction.
    if not UnitExists or FP:Truth(select(2, pcall(UnitExists, unit))) ~= true then
        return false
    end
    if UnitIsDeadOrGhost
       and FP:Truth(select(2, pcall(UnitIsDeadOrGhost, unit))) ~= false then
        return false
    end
    if UnitIsConnected
       and FP:Truth(select(2, pcall(UnitIsConnected, unit))) == false then
        return false
    end

    local yards = DistanceTo(unit)
    if yards then
        return yards <= (tonumber(M.db and M.db.reachYards) or 100)
    end

    if UnitInRange then
        local ok, inRange, checked = pcall(UnitInRange, unit)
        -- Only when the client says it checked, and says so readably.
        if ok and FP:Truth(checked) == true then
            local near = FP:Truth(inRange)
            if near ~= nil then return near end
        end
    end

    if UnitIsVisible then
        local ok, visible = pcall(UnitIsVisible, unit)
        local seen = nil
        if ok then seen = FP:Truth(visible) end
        if seen ~= nil then return seen end
    end

    local mine, theirs = MapOf("player"), MapOf(unit)
    if mine and theirs and mine ~= theirs then return false end
    return true
end

-- Whether this client tells us who cast an aura. Decided by observation
-- rather than assumed: the field is standard in the modern API and has never
-- been read here, and the counting below means something different depending
-- on the answer.
M.knowsSource = false

--- Is one of *your* copies of this entry on that unit?
--
-- Only meaningful for a buff that comes one per caster. The owner asked for
-- the count to be about what *he* still has to cast rather than about who is
-- unblessed, which needs the caster of each aura.
--
-- @return true, false, or nil when the client will not say who cast it
local function MineOn(unit, entry)
    local get = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
    if not get then return nil end

    local answered = false
    for _, name in ipairs(EntryNames(entry)) do
        local ok, aura = pcall(get, unit, name, "HELPFUL")
        if ok and type(aura) == "table" then
            -- A caster this client will not name counts as not named.
            local source = FP:Plain(aura.sourceUnit)
            if source ~= nil then
                answered = true
                M.knowsSource = true
                if UnitIsUnit then
                    local asked, same = pcall(UnitIsUnit, source, "player")
                    -- Never touched directly. UnitIsUnit answers true on a
                    -- modern client and 1 on an old one, and anything that
                    -- came back from this client can be secret, which raises
                    -- on the first comparison.
                    if asked then
                        local usable, yes = pcall(function()
                            return same == true or same == 1
                        end)
                        if usable and yes then return true end
                    end
                end
            end
        end
    end

    -- Auras were found but none of them said who cast it, so the question
    -- cannot be answered on this client.
    if not answered and not M.knowsSource then return nil end
    return false
end

--- How long that unit has left on this buff, or nil when they have none.
local function RemainingOn(unit, entry, now)
    local get = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
    if not get then return nil end

    local best
    for _, name in ipairs(EntryNames(entry)) do
        local ok, aura = pcall(get, unit, name, "HELPFUL")
        if ok and type(aura) == "table" then
            -- A buff with no timer at all never runs out, so it sorts above
            -- everything with one. Worked out inside a pcall, because an
            -- expiry this client will not show is a secret number and the
            -- first comparison with it raises; such a buff is skipped.
            local usable, left = pcall(function()
                local expires = aura.expirationTime or 0
                return (expires > 0) and (expires - now) or math.huge
            end)
            if usable and (not best or left > best) then best = left end
        end
    end
    return best
end

--- How many people near you want this buff and do not have it.
function M:CountMissing(entry)
    if entry.kind ~= "group" then return 0 end

    -- **Only for a buff you can actually hand out.** Asked by the owner on
    -- 2026-09-22 in the form that makes it obvious: a Druid does not need to
    -- know that thirty people are about to lose Fortitude. That is the
    -- priest's business, and the Druid's interest in Fortitude begins and ends
    -- with whether it is on him.
    --
    -- The two callers disagreed about this before it moved here. The icons
    -- asked `Castable` first and were right; the list on the settings page did
    -- not and would print a number next to a buff the character has not
    -- learned. One gate, so they cannot drift again.
    --
    -- Buffs other people are offering never reach this function at all: they
    -- come in through Offers and carry no count by construction.
    if not Castable(entry) then return 0 end

    -- Other players' auras cannot be read either, so a count would call
    -- everybody unbuffed.
    if Blind() then return 0 end

    local now, missing, present = GetTime(), 0, 0
    -- The entry's own time where it has one, for the count as well, the
    -- owner's word of 2026-10-15; at zero only somebody without it counts.
    -- Without one, the page's middle window, as it always was.
    local window = FP.Bars.Warn(FP.Bars.Store(), EntryKey(ClassToken(), entry))
                   or WarnWindow(SHORT_BUFF)

    for _, unit in ipairs(GroupUnits()) do
        if Reachable(unit) then
            local _, class = nil, nil
            if UnitClass then
                local ok, _, token = pcall(UnitClass, unit)
                class = ok and FP:Plain(token) or nil
            end

            if FP:BuffAppliesTo(entry, class) then
                present = present + 1
                if entry.perCaster then
                    -- Counts who is missing *your* copy rather than who is
                    -- unblessed, which is what the owner asked for: with two
                    -- Paladins the other one's work is not yours to redo.
                    --
                    -- Falls back to "has none at all" where the client will
                    -- not name the caster. Different question, same shape of
                    -- answer, and /fplus buffs status says which one is live
                    -- rather than leaving the number to be misread.
                    local mine = MineOn(unit, entry)
                    if mine == false then
                        missing = missing + 1
                    elseif mine == nil then
                        local left = RemainingOn(unit, entry, now)
                        if not left or left <= window then missing = missing + 1 end
                    end
                else
                    local left = RemainingOn(unit, entry, now)
                    -- The same threshold the player gets for themselves, which
                    -- the owner asked for if it proved affordable. Somebody
                    -- about to lose it is worth one cast now rather than two
                    -- later.
                    if not left or left <= window then missing = missing + 1 end
                end
            end
        end
    end

    -- A capped entry is measured against the number of targets the player
    -- asked for rather than against the group. One person carrying it with a
    -- setting of one means nothing is missing, however many others are
    -- standing there without it.
    --
    -- Capped by who is present as well, which is the same reasoning as the
    -- Paladin cap above: asking for three targets in a party of two would
    -- leave an icon nobody can clear.
    if entry.targets then
        -- Everybody the count reaches, when the player asked for that, which
        -- is exactly what a group buff without a cap counts.
        if self:TargetsAll(ClassToken(), entry) then return missing end
        local want = math.min(self:TargetCount(ClassToken(), entry) or 0, present)
        return math.max(0, want - (present - missing))
    end

    return missing
end

--- The non-localized class token of a unit, or nil.
local function UnitClassToken(unit)
    if not UnitClass then return nil end
    local ok, _, token = pcall(UnitClass, unit)
    return ok and FP:Plain(token) or nil
end

-- ---------------------------------------------------------------------------
-- Tracking, which is not a buff
--
-- Asked for on CurseForge: Find Minerals and Find Herbs switch off when you
-- die, and it is easy to run half a session before noticing. Confirmed on this
-- build the same day, by dying: tracking really does go out with you, even
-- though this is the retail filter list rather than Vanilla's single slot.
--
-- **The player says what they want running, and the icon is there whenever it
-- is not.** That is the whole rule. It went through two shapes first and the
-- second one is worth recording, because it is the one this replaced: arming
-- on the death and clearing on any tracking at all. The reason that shape
-- existed was that the addon had to *guess* whether somebody not tracking ore
-- had forgotten or had chosen, and a guess in that direction nags people.
--
-- A list to tick removes the guess. Somebody who ticked Find Herbs has said
-- what they want, so a standing icon is not a nag, it is the thing they asked
-- for, and it also catches the case a death trigger never could: logging in
-- and never switching it on at all.
--
-- Three things fall out of that, and each one is a decision rather than an
-- implementation detail:
--
--   * **A group is satisfied by any one member.** Find Minerals and Find Herbs
--     exclude each other, so asking for both is asking for something nobody
--     can give. Find Treasure stands alone: see Data/Tracking.lua.
--   * **Nothing is said about a tracking the character does not know.** The
--     row can be ticked, the warning still never comes. That is the profession
--     gate, and it is what makes an icon defensible by default.
--   * **Nothing is said when the slot cannot be found**, because then turning
--     tracking on could not be observed either, and a warning nobody can clear
--     is worse than no warning.
--
-- **None of the aura machinery reaches in here.** Tracking is a minimap slot,
-- not an aura on the player, so whether the client is answering about auras
-- says nothing about whether it will answer about this, and the reverse.
-- ---------------------------------------------------------------------------

--- A value from the client, or nil when it cannot be touched at all.
--
-- A secret value survives the read and survives tostring, then raises on the
-- first comparison. Everything below this line compares, so everything is
-- proved comparable before it is kept. See FP:Truth in Core/Util.lua.
local function Usable(value)
    if not pcall(function() return value == value end) then return nil end
    return value
end

--- The two calls that read the tracking slots, from wherever this build keeps
--- them.
--
-- C_Minimap is measured present on 69913 and a namespace existing says nothing
-- about its contents, so the old globals are tried as well. Classic keeps them
-- there; retail moved them into the namespace; this build is Vanilla content
-- on a modern engine and could be either.
local function TrackingReaders()
    local api = _G.C_Minimap
    local count = (api and api.GetNumTrackingTypes) or _G.GetNumTrackingTypes
    local info  = (api and api.GetTrackingInfo)     or _G.GetTrackingInfo
    if type(count) ~= "function" or type(info) ~= "function" then return nil end
    return count, info
end

-- Where the spell id sits when GetTrackingInfo answers with loose values:
-- name, texture, active, category, nested, spellID. That is the Classic shape
-- and it is not this build's, see below.
local SLOT_SPELL_AT = 6

--- One field of a table the client handed over, or nil when it will not give
--- it up.
local function Field(holder, key)
    local ok, value = pcall(function() return holder[key] end)
    if not ok then return nil end
    return Usable(value)
end

--- The four things a slot has to say, out of either shape of answer.
--
-- **Measured on build 69913, 2026-09-21: this client returns one table.**
-- GetTrackingInfo hands back a single structure rather than the five loose
-- values Classic returns, and the first version of this read it positionally.
-- Everything then went wrong quietly: the name came back as the table itself,
-- active as nil, no slot ever matched, and the dump printed `table: 0000023652`
-- in the place where the answer was supposed to be. It had the shape in its
-- hands and stringified it rather than opening it, which is the same mistake
-- the gossip options cost a morning, in a file that already says so twice.
--
-- The positional shape is kept underneath. It costs four lines, this client is
-- still moving, and one of the two is now known to be right here.
local function SlotFields(packed)
    local first = packed[2]
    if type(first) == "table" then
        return Field(first, "name"), Field(first, "texture"),
               FP:Truth(Field(first, "active")),
               Field(first, "spellID") or Field(first, "spellId"),
               Field(first, "type")
    end
    return Usable(first), Usable(packed[3]), FP:Truth(packed[4]),
           Usable(packed[SLOT_SPELL_AT + 1]), nil
end

--- Every tracking slot, as plain values, or nil when this client will not say.
local function ReadSlots()
    local count, info = TrackingReaders()
    if not count then return nil end

    local ok, total = pcall(count)
    if not ok or type(total) ~= "number" then return nil end

    local slots = {}
    for index = 1, total do
        local packed = { pcall(info, index) }
        if packed[1] then
            local name, texture, active, spell, kind = SlotFields(packed)
            slots[#slots + 1] = {
                index   = index,
                name    = name,
                texture = texture,
                active  = active,
                spell   = spell,
                -- "spell" or "other", measured. Not display text: it is a
                -- token the client compares against itself, like the class
                -- token, and it reads the same in every language.
                kind    = kind,
            }
        end
    end
    return slots
end

--- Two textures that are the same picture.
--
-- One side is a file id and the other a path, depending on which call produced
-- it, so both shapes are handled. Lowercasing is safe on a texture path: it is
-- ASCII the client never shows anybody, which is the opposite of the game text
-- the locale rule is about.
local function SameTexture(a, b)
    if a == nil or b == nil then return false end
    if a == b then return true end
    if type(a) == "string" and type(b) == "string" then
        return a:lower() == b:lower()
    end
    return false
end

--- Which slot holds this tracking type, by three routes in order of certainty.
--
-- Not one of them compares against text this addon wrote down. The name route
-- holds what the client calls the slot against what the client calls the
-- spell, so it is the client agreeing with itself and reads the same on a
-- German install.
local function SlotFor(slots, entry)
    for _, slot in ipairs(slots) do
        if type(slot.spell) == "number" and slot.spell == entry.spell then
            return slot, "spell id"
        end
    end

    local name = FP:SpellName(entry.spell)
    if type(name) == "string" and name ~= "" then
        for _, slot in ipairs(slots) do
            if slot.name == name then return slot, "name" end
        end
    end

    local icon = FP:SpellIcon(entry.spell)
    for _, slot in ipairs(slots) do
        if SameTexture(slot.texture, icon) then return slot, "texture" end
    end

    return nil, nil
end

--- What the last look at the minimap slots found.
--
-- `on` is the last answer taken while the player was alive, which is the whole
-- point of keeping it: at the moment PLAYER_DEAD arrives the slots may already
-- have been emptied by the very death being reported.
M.trackState = {
    active = 0,      -- how many slots were on, filters included
    spells = 0,      -- how many of those were tracking spells
    most = 0,        -- most ever on at once, which answers the slot question
    slot = {},       -- entry id -> the slot it was found in
    how = {},        -- entry id -> which of the three routes found it
    icon = {},       -- entry id -> the client's own picture for it
    at = nil,        -- when a read last succeeded, and nil until one has
}

--- Is there anything on this character for the warning to be about?
--
-- Most characters know none of these. For them this whole section costs three
-- table lookups a second and never touches the minimap at all.
function M:WatchesTracking()
    for _, entry in ipairs(FP.trackingTypes or {}) do
        if known[entry.spell] then return true end
    end
    return false
end

--- Does the player want this one running?
--
-- Stored per entry rather than as a list of exceptions, because the defaults
-- are not all the same: the two gathering trackings start ticked and Find
-- Treasure does not, so "absent means on" could not express both.
function M:TrackingWanted(entry)
    local picked = self.db.trackPick and self.db.trackPick[entry.id]
    if picked == nil then return entry.default == true end
    return picked == true
end

function M:SetTrackingWanted(entry, value)
    local picked = self.db.trackPick
    if not picked then
        picked = {}
        self.db.trackPick = picked
    end
    picked[entry.id] = value and true or false
end

--- Reads the slots and keeps what the warning needs.
--
-- Its own read rather than part of Scan, and not behind ReadsAllowed: that
-- gate asks whether auras can be read, and this is not an aura.
--
-- @param force  read anyway, for the dump, which has to report on a character
--               who has none of these as much as on one who has them all
function M:ScanTracking(force)
    local state = self.trackState
    if not force and (self.db.tracking == false or not self:WatchesTracking()) then
        return
    end

    -- Not in a fight and not while dead, and that is about the reading rather
    -- than about the drawing: the display is already silent in both, so a read
    -- there could only ever confirm something nobody is being shown.
    --
    -- It also keeps a question shut that nobody has answered. Whether this
    -- client will talk about tracking in combat has never been measured, and
    -- everything it refuses in combat it refuses in a shape that costs
    -- something to handle. Not asking is free.
    --
    -- Nothing goes stale by it. The last answer stands until combat ends, and
    -- PLAYER_REGEN_ENABLED runs an update whose scan happens before its
    -- evaluation, so the first icon after a fight is drawn from a fresh read.
    if not force then
        if InCombat() then return end
        if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return end
    end

    local slots = ReadSlots()
    if not slots then return end

    state.slots, state.at = slots, GetTime()

    -- Two counts, and the difference between them is the measurement that
    -- corrected this feature once already.
    --
    -- **Measured 2026-09-21: the tracking list here is mostly not tracking.**
    -- Twenty four entries, of which nineteen are minimap filters: Innkeeper,
    -- Flight Master, Mailbox, quest points of interest. Five were on, and four
    -- of those five are filters that are on permanently and say nothing about
    -- what the player is hunting for.
    --
    -- Neither number decides anything now, since a warning asks about one
    -- named tracking rather than about tracking in general. They are kept for
    -- the dump, where "5 on, 1 of them a spell" is the line that explains the
    -- other twenty three.
    local active, spells = 0, 0
    for _, slot in ipairs(slots) do
        if slot.active == true then
            active = active + 1
            if slot.kind == "spell" then spells = spells + 1 end
        end
    end
    state.active, state.spells = active, spells
    if active > state.most then state.most = active end

    for _, entry in ipairs(FP.trackingTypes or {}) do
        local slot, how = SlotFor(slots, entry)
        state.slot[entry.id], state.how[entry.id] = slot, how
        -- Kept even while the slot is off, because the icon is needed for
        -- exactly the case where it is: a warning about something absent has
        -- nothing else to take a picture from.
        if slot and slot.texture then state.icon[entry.id] = slot.texture end
    end
end

--- Is this one running right now?
--
-- Three things have to be true and each of them is a reason to stay quiet:
-- the character knows it, the slot for it was found, and the slot says on.
-- The middle one matters most. Without a slot the addon cannot see the player
-- fix it either, and a warning nobody can clear is the one kind this addon
-- does not draw.
function M:TrackingActive(entry)
    if not known[entry.spell] then return false end
    local slot = self.trackState.slot[entry.id]
    return (slot and slot.active == true) or false
end

--- Can this one produce a warning at all on this character?
function M:TrackingUsable(entry)
    return known[entry.spell] and self.trackState.slot[entry.id] ~= nil
end

--- One warning per group the player asked for and is not getting.
--
-- A group rather than an entry, and that is the answer to the question this
-- feature was nearly built around: a character with both gathering professions
-- cannot have both trackings on, so two icons demanding both would be two
-- icons they can never clear. One of them running satisfies the pair.
--
-- @return a list, usually empty, at most one item per group
function M:TrackingWarnings()
    local out = {}
    if self.db.tracking == false then return out end

    -- Out of combat only, decided for this display on its own terms rather
    -- than borrowed from the buff rule, which is scoped to buffs on purpose.
    -- Two reasons of its own: nobody opens the tracking menu mid fight, and
    -- whether this client answers about tracking during one has not been
    -- measured, so an icon there could be one nothing can take away.
    if InCombat() then return out end

    -- Nothing has been read yet, so nothing is known to be off. The same
    -- discipline as the buffs: absent and unreadable are different answers.
    if not self.trackState.at then return out end

    local wanted, satisfied, order = {}, {}, {}
    for index, entry in ipairs(FP.trackingTypes or {}) do
        if self:TrackingWanted(entry) and self:TrackingUsable(entry) then
            local group = entry.group or entry.id
            if not wanted[group] then
                wanted[group] = entry
                order[#order + 1] = { group = group, index = index }
            end
            if self:TrackingActive(entry) then satisfied[group] = true end
        end
    end

    for _, item in ipairs(order) do
        if not satisfied[item.group] then
            local entry = wanted[item.group]
            out[#out + 1] = {
                kind = "missing",
                tracking = entry,
                icon = self.trackState.icon[entry.id] or FP:SpellIcon(entry.spell),
                -- After the missing buffs, before anything merely running out,
                -- and each group a hair apart from the next. Equal keys would
                -- let two icons swap places between two ticks, because
                -- table.sort is free to reorder what it cannot tell apart.
                sort = 0.75 + item.index / 1000,
            }
        end
    end

    return out
end

-- ---------------------------------------------------------------------------
-- Buffs somebody else could put on you
--
-- The other two thirds of a group buff are about what *you* cast. This is the
-- third: a Warlock with a Paladin in the group and no Blessing on him.
--
-- The hard part is that the client will tell you whether *you* have learned a
-- spell and will not tell you that about anybody else. So this infers it from
-- their class and their level, which is a guess, and the guess is protected by
-- putting every `minLevel` in Data/Buffs.tbl too high rather than too low: a
-- late warning is a nuisance, a warning aimed at somebody who cannot cast the
-- spell is one nobody can clear.
--
-- **Out of combat only**, and that follows from the rule rather than from
-- convenience. In combat other players cannot be read, the person who would
-- cast it cannot be seen doing so, and you cannot cast it yourself. An icon
-- there would be one that nothing could take away.
-- ---------------------------------------------------------------------------

--- A unit's level as a plain number, or 0 when the client will not say.
--
-- Measured readable on 2026-09-23, in combat and out of it. Guarded anyway,
-- because it is compared against a number on the very next line and anything
-- this client hands back can be secret.
local function LevelOf(unit)
    if not UnitLevel then return 0 end
    local ok, level = pcall(UnitLevel, unit)
    if not ok then return 0 end
    local usable = pcall(function() return level > 0 end)
    return (usable and type(level) == "number") and level or 0
end

--- Entries other people present could cast on you.
--
-- **Once per entry, however many people could cast it.** The comment here
-- promised that from the start and the code did not keep it: every Paladin in
-- range added the Blessing entry again, so the per caster evaluation ran once
-- per Paladin and each run already counted every Paladin. Reported from a
-- group on 2026-09-27, two Paladins and four icons where two was the most
-- there could ever be. Who is present is counted where it is needed, in
-- Givers, not by repeating the entry.
function M:Offers()
    -- Before the cache, so a list taken a moment before the refusal began is
    -- not handed out for the rest of its interval.
    if Blind() then return {} end
    local now = GetTime()
    if self.offersAt and (now - self.offersAt) < COUNT_EVERY then
        return self.offers or {}
    end

    local offers, offered = {}, {}
    if not Blind() then
        local mine = ClassToken()
        for _, unit in ipairs(GroupUnits()) do
            if Reachable(unit) then
                local class = UnitClassToken(unit)
                local level = LevelOf(unit)

                -- Same class as yours is skipped: you can cast it yourself, so
                -- it is already an entry of your own and would be a second
                -- icon for one buff.
                if class and class ~= mine then
                    for _, entry in ipairs(FP.classBuffs[class] or {}) do
                        if not offered[entry]
                           and entry.kind == "group"
                           and not entry.ownClassOnly
                           and FP:BuffAppliesTo(entry, mine)
                           and level >= (entry.minLevel or 0)
                           and not self:BuffOff(class, entry)
                           and self:TargetsSelf(class, entry) then
                            offered[entry] = true
                            offers[#offers + 1] = { entry = entry, class = class }
                        end
                    end
                end
            end
        end
    end

    self.offers, self.offersAt = offers, now
    return offers
end

--- The counts for every group entry, recomputed at most every COUNT_EVERY.
function M:GroupCounts()
    local now = GetTime()
    if self.countsAt and (now - self.countsAt) < COUNT_EVERY then
        return self.counts or {}
    end

    -- Own class only, which is the other half of the same answer: a count is
    -- an instruction to cast something, so it exists only where casting is
    -- possible.
    local counts = {}
    local _, entries = ClassEntries()
    for _, entry in ipairs(entries) do
        if entry.kind == "group" then
            counts[entry.id] = self:CountMissing(entry)
        end
    end

    self.counts, self.countsAt = counts, now
    return counts
end

--- The player's assigned role, or "NONE" when the client has no such thing.
--
-- Guarded rather than assumed. Role assignment is a modern feature and this is
-- Vanilla content; if the call is missing, everybody is NONE. No blessing
-- declares a role since Salvation and Light left the table on 2026-11-03, so
-- this only matters again for a variant that names one.
local function PlayerRole()
    if not UnitGroupRolesAssigned then return "NONE" end

    local ok, role = pcall(UnitGroupRolesAssigned, "player")
    if not ok then return "NONE" end

    -- Never compared directly: anything from this client can come back secret.
    local usable, text = pcall(tostring, role)
    if not usable then return "NONE" end
    local readable = pcall(function() return text == "" end)
    return readable and text or "NONE"
end

--- The variants a class wants that this client actually has, and that the
--- player's current role actually wants.
function M:WantedHere(entry, class)
    local role = PlayerRole()
    local out = {}

    for _, id in ipairs(FP:WantedVariants(entry, class) or {}) do
        local variant = entry.byVariant and entry.byVariant[id]
        local fits = variant ~= nil
            and (variant.notRole  == nil or variant.notRole  ~= role)
            and (variant.onlyRole == nil or variant.onlyRole == role)

        if fits and VariantExists(entry, variant) then out[#out + 1] = id end
    end

    return out
end

--- Everybody present who could put one of this entry's blessings on you.
--
-- One function per person, answering whether they could cast a particular
-- blessing: yourself by what you have learned, anybody else by their level
-- against the level that blessing is trained at. Only the level can be seen
-- for somebody else, and since 2026-09-27 it is compared per blessing: a
-- Paladin at 15 can give Might and Wisdom and is asked for nothing else.
--
-- Counts yourself when it is your own class and you have learned it, because
-- a Paladin blesses themselves like anybody else.
function M:Givers(entry, ownerClass)
    local givers = {}

    local function VariantOf(id)
        return entry.byVariant and entry.byVariant[id]
    end

    if ClassToken() == ownerClass and Castable(entry) then
        givers[#givers + 1] = function(id)
            local variant = VariantOf(id)
            for _, spell in ipairs(variant and variant.ids or {}) do
                if known[spell] then return true end
            end
            return false
        end
    end

    for _, unit in ipairs(GroupUnits()) do
        if Reachable(unit) and UnitClassToken(unit) == ownerClass then
            local level = LevelOf(unit)
            if level >= (entry.minLevel or 0) then
                givers[#givers + 1] = function(id)
                    local variant = VariantOf(id)
                    return variant ~= nil
                        and level >= (variant.minLevel or entry.minLevel or 0)
                end
            end
        end
    end

    return givers
end

-- Below this level any blessing on you is enough, and none at all asks for
-- one. Decided by the owner on 2026-09-27, from a group, and it reverses half
-- of an older decision: until then a Warlock carrying Might was told for as
-- long as it lasted that Wisdom would be better, because the class list does
-- not want Might. While levelling that is noise, and a blessing of any kind is
-- worth more than an icon about which one. At the level cap the choice starts
-- to matter again, and there the full rule below still stands.
--
-- Sixty and not the client's level cap: this beta caps at 20, and the rule is
-- about the game WoW Forever will be, where 60 is the end.
local FULL_BLESSING_LEVEL = 60

--- What the blessing entry has to say, worked out once for the icons and the
--- list on the settings page, so the two cannot disagree.
--
-- @return a table: `wanted` (ids, most wanted first), `held` ([id] = state
--         for what is on you and has not run out), `askList` and `ask` (what
--         to ask for, as a list and as a set), `short` (expiry items for the
--         held ones that are running out), `givers` (see Givers)
function M:PlanPerCaster(entry, ownerClass, now)
    local plan = {
        wanted = self:WantedHere(entry, ClassToken()),
        held = {}, ask = {}, askList = {}, short = {},
        givers = self:Givers(entry, ownerClass),
    }
    if #plan.wanted == 0 then return plan end

    local active = self.seenVariants[entry.id] or {}

    -- **An expiry that has passed is not a buff**, and saying so here is the
    -- whole of a bug reported from Wailing Caverns on 2026-09-22: two blessings
    -- ran out during a fight and the icons kept counting, into negative
    -- numbers, until a reload. Nothing is rescanned in combat, so the state
    -- stands; every other branch in this file already discards a remaining time
    -- of zero or less and this one did not.
    --
    -- A blessing that ran out is not asked for again either, which is the other
    -- half of the same rule: nothing is rescanned in combat and a recast is not
    -- seen for a blessing, so an icon asking for it would be one nothing could
    -- clear before the fight ends. Out of combat the next scan has it gone.
    local function Running(state)
        if not state then return false, nil end
        local remaining = (state.expires or 0) > 0
            and ((state.expires or 0) - now) or nil
        -- No remaining time at all means a buff that does not expire, which
        -- is held rather than gone.
        return (not remaining or remaining > 0), remaining
    end

    local anyHeld = false
    for _, state in pairs(active) do
        if Running(state) then anyHeld = true end
    end

    local candidates, heldSet = {}, {}
    for _, id in ipairs(plan.wanted) do
        local state = active[id]
        local running, remaining = Running(state)
        if running then
            plan.held[id], heldSet[id] = state, true
            candidates[#candidates + 1] = id
            -- Every wanted blessing that is on you and running out is worth
            -- saying on its own, whatever the asking below decides.
            if remaining and remaining <= self:WarnAt(ownerClass, entry, state.duration) then
                plan.short[#plan.short + 1] = {
                    kind = "expiring", entry = entry, variant = id,
                    icon = state.icon, remaining = remaining,
                    sort = 1 + remaining,
                }
            end
        elseif not state then
            candidates[#candidates + 1] = id
        end
    end

    if #plan.givers == 0 then return plan end

    -- **At the cap: one wanted blessing per Paladin who can give it.** `held`
    -- counts only the blessings the class *wants*, confirmed with the owner on
    -- 2026-09-19: a Warlock blessed with Might has a full slot and still
    -- nothing they asked for, so the icon stays and says "you have a blessing,
    -- just not one you want". PlanGifts in Core/Util.lua charges what you hold
    -- to whoever could have cast it and asks each remaining Paladin for one
    -- blessing that Paladin can actually cast.
    local ask = FP:PlanGifts(candidates, heldSet, plan.givers)

    -- **Below it: any blessing is enough, and one is all that is asked for.**
    -- See FULL_BLESSING_LEVEL.
    if LevelOf("player") < FULL_BLESSING_LEVEL then
        if anyHeld then
            ask = {}
        else
            ask = { ask[1] }
        end
    end

    plan.askList = ask
    for _, id in ipairs(ask) do plan.ask[id] = true end
    return plan
end

--- Could anybody present give this blessing?
local function AnyGiver(givers, id)
    for _, can in ipairs(givers) do
        if can(id) then return true end
    end
    return false
end

--- What a per caster entry should put on screen.
--
-- Returns a list of display items rather than one, because the owner chose an
-- icon per missing blessing over a single icon with a count: two missing
-- blessings are two different things to ask for, and one icon cannot say
-- which.
function M:EvaluatePerCaster(entry, ownerClass, now)
    local out = {}
    local plan = self:PlanPerCaster(entry, ownerClass, now)

    -- Nobody present could renew anything, so nothing is said at all, not even
    -- that a blessing is running out: that would be a warning no action of
    -- yours could answer.
    if #plan.givers == 0 then return out end

    for _, id in ipairs(plan.askList) do
        local variant = entry.byVariant and entry.byVariant[id]
        local best = variant and variant.ids[#variant.ids]
        out[#out + 1] = {
            kind = "missing", entry = entry, variant = id,
            icon = FP:SpellIcon(best), sort = 0,
        }
    end

    for _, item in ipairs(plan.short) do out[#out + 1] = item end
    return out
end

--- What should be on screen, worst first.
--
-- Reads nothing. Everything here comes from the last scan plus the clock,
-- which is what makes it work in combat.
function M:Evaluate()
    -- Never while dead. Everything is missing then and none of it can be
    -- acted on, so this is a rule rather than an option. It was written into
    -- the roadmap and never built, which showed up in the same instance report
    -- that found the refused reads above.
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return {} end

    -- The two that *are* options, and both default to warning.
    if Suppressed(self.db) then return {} end

    local out = {}

    -- Tracking, above the check below rather than under it. That one asks
    -- whether the auras have ever been read, and this does not come from an
    -- aura: a character who has not been able to read a buff all session can
    -- still be told that their herb tracking is off.
    --
    -- The two guards above it do apply. Dead and the mounted and resting
    -- switches are conditions of the whole display, about when it may speak at
    -- all, rather than about what it is speaking of.
    for _, item in ipairs(self:TrackingWarnings()) do
        out[#out + 1] = item
    end

    -- Nothing has been read yet, so no *buff* is known to be missing. Log in
    -- during a fight and every buff you have would otherwise be reported as
    -- gone, which is the exact failure the rule in AGENTS.md exists to stop:
    -- a warning nobody can clear, because casting it would not be seen either.
    if not self.scanned then return out end

    local now = GetTime()
    local class, entries = ClassEntries()
    local counts = self:GroupCounts()

    for _, entry in ipairs(entries) do
        if entry.warns == false then
            -- Nothing at all from this entry: its tracker is the whole of it.
            -- Seals are the case, and saying "your Seal is missing" every
            -- thirty seconds is exactly the metronome that kept short buffs
            -- out of these tables in the first place.
            --
            -- Note that this is **not** the same question as `entry.tracker`.
            -- Battle Shout is tracked and still warns, because a countdown
            -- cannot say that the buff is gone or that somebody near you is
            -- owed it.

        elseif self:CombatOnly(class, entry) and not InCombat() then
            -- Nothing out of a fight for an entry the player wants to hear
            -- about only in one. See M:CombatOnly.

        elseif entry.kind == "pet" then
            -- The pet's mood, the owner's request of 2026-10-05. Out of combat
            -- only: Feed Pet cannot be used in a fight, so an icon there would
            -- ask for something nobody can do. Content is a plain icon,
            -- unhappy the missing look with its red border.
            if not self:BuffOff(class, entry) and Castable(entry)
               and not InCombat() then
                local happiness = PetHappiness()
                if happiness == 1 then
                    out[#out + 1] = { kind = "missing", entry = entry,
                                      icon = EntryIcon(entry), sort = 0.25 }
                elseif happiness == 2 then
                    out[#out + 1] = { kind = "notice", entry = entry,
                                      icon = EntryIcon(entry), sort = 0.8 }
                end
            end

        elseif entry.charges and InCombat() and not self:Counting(entry) then
            -- Nothing at all about a charge buff while the fight is on, and
            -- this is the rule rather than an exception to it. A countdown may
            -- stand in combat because it is arithmetic on an expiry read
            -- before the fight, which is exact. A charge buff does not end at
            -- a time, it ends when something hits you, and this client cannot
            -- see that happen by any route. So what the addon believes here is
            -- a guess, and *nothing rather than something stale* says not to
            -- draw a guess.
            --
            -- It comes back the moment combat ends, off a fresh read.
            --
            -- **Unless the entry is counted**, see Counting below: then the
            -- hits that spend it can be seen after all, and the entry falls
            -- through to the ordinary branch, which warns once the count
            -- reaches none.

        elseif entry.camp and not self:BuffOff(class, entry)
               and #self:CampPicks(class) > 0 then
            -- Bonuses ticked: each is watched on its own, and Camp Benefits
            -- only for running out. With none ticked, the branch below
            -- watches it like any buff of your own.
            for _, item in ipairs(self:EvaluateCamp(entry, class, now)) do
                out[#out + 1] = item
            end

        elseif entry.perCaster and not self:BuffOff(class, entry) then
            -- Its own shape: one icon per blessing still wanted, rather than
            -- one icon for the whole set.
            for _, item in ipairs(self:EvaluatePerCaster(entry, class, now)) do
                item.waiting = counts[entry.id] or 0
                out[#out + 1] = item
            end

        elseif entry.targets and not self:BuffOff(class, entry)
               and not self:TargetsSelf(class, entry) and Castable(entry) then
            -- Tracked, but not on yourself, so nothing is said about your own
            -- copy while the count underneath may still be asking for people
            -- to be covered. This is the Druid who keeps Thorns on the tank
            -- and never carries it himself.
            local waiting = counts[entry.id] or 0
            if waiting > 0 then
                out[#out + 1] = {
                    kind = "handout", entry = entry, waiting = waiting,
                    icon = EntryIcon(entry), sort = 2e6 - waiting,
                }
            end

        elseif not self:BuffOff(class, entry) and Castable(entry) then
            local state = self.seen[entry.id]
            local waiting = counts[entry.id] or 0
            local remaining = state and (state.expires or 0) > 0
                and ((state.expires or 0) - now) or nil

            if not state or (remaining and remaining <= 0)
               or state.charges == 0 then
                -- Gone, or it ran out while we were not allowed to look, or
                -- a counted shield has spent its last charge.
                out[#out + 1] = {
                    kind = "missing", entry = entry, waiting = waiting,
                    icon = EntryIcon(entry), sort = 0,
                }
            elseif remaining and remaining <= self:WarnAt(class, entry, state.duration)
                   and not entry.tracker then
                -- A tracked entry skips this branch and only this one. The
                -- countdown is already on screen, so warning that it is nearly
                -- gone is the same sentence twice in two places. Falling
                -- through means a rank or a handout can still be reported,
                -- which is what a countdown genuinely cannot say.
                out[#out + 1] = {
                    kind = "expiring", entry = entry, icon = state.icon,
                    remaining = remaining, waiting = waiting,
                    sort = 1 + remaining,
                }
            else
                -- Two ways to be a rank behind, and they read different
                -- things: an aura carries its own rank, an enchant carries a
                -- name the tooltip printed.
                local better
                if entry.kind == "weapon" then
                    better = BetterImbue(entry, state)
                else
                    better = BetterRank(entry, state)
                end
                if better then
                    out[#out + 1] = {
                        kind = "upgrade", entry = entry, waiting = waiting,
                        icon = FP:SpellIcon(better) or state.icon,
                        sort = 1e6,
                    }
                elseif waiting > 0 then
                    -- You have it, somebody near you does not, and you are the
                    -- one who can fix that.
                    out[#out + 1] = {
                        kind = "handout", entry = entry, waiting = waiting,
                        icon = state.icon or EntryIcon(entry),
                        sort = 2e6 - waiting,
                    }
                end
            end
        end
    end

    -- Buffs other people could put on you. Nothing here checks Castable: you
    -- cannot cast these, that is the whole point, and whether somebody present
    -- can is what Offers already decided.
    --
    -- Only where the player asked for them: dungeons, raids, battlegrounds and
    -- the open world each have a switch. Decided here rather than in Offers,
    -- so the list of buffs on you still says what the group could give: it is
    -- a description, and only the icons are a warning.
    local offers = {}
    local place = PlaceSwitch()
    if place and self.db[place] == true then
        offers = self:Offers()
    end
    for _, offer in ipairs(offers) do
        local entry = offer.entry

        if not self:OfferWarns(offer.class, entry) then
            -- No icon, by the player's own switch. See M:OfferWarns.
        elseif entry.perCaster then
            -- One icon per blessing still wanted, marked as somebody else's
            -- to give. No `goto` to skip the branch below: WoW runs Lua 5.1
            -- and does not have it.
            for _, item in ipairs(self:EvaluatePerCaster(entry, offer.class, now)) do
                item.fromOthers = true
                -- The entry belongs to the giver's class block, and that is
                -- where its bar and its own time are set.
                item.ownerClass = offer.class
                item.sort = item.sort + 0.5
                out[#out + 1] = item
            end
        else
            local state = self.seen[entry.id]
            local remaining = state and (state.expires or 0) > 0
                and ((state.expires or 0) - now) or nil

            if not state or (remaining and remaining <= 0) then
                out[#out + 1] = {
                    kind = "missing", entry = entry, fromOthers = true,
                    ownerClass = offer.class,
                    icon = EntryIcon(entry), sort = 0.5,
                }
            elseif remaining and remaining <= self:WarnAt(offer.class, entry, state.duration) then
                out[#out + 1] = {
                    kind = "expiring", entry = entry, fromOthers = true,
                    ownerClass = offer.class,
                    icon = state.icon, remaining = remaining,
                    sort = 1 + remaining,
                }
            end
        end
    end

    -- Missing first: it is the older problem, and it is the one that has been
    -- true for longest by the time anybody looks.
    table.sort(out, function(a, b) return a.sort < b.sort end)
    return out
end

--- Where the ticked camp bonuses stand: the plan, Camp Benefits' time left,
--- and whether it is on. For the icons and for the list on the page alike, so
--- the two cannot disagree.
function M:CampPlan(entry, class, now)
    local state = self.seen[entry.id]
    local remaining = state and (state.expires or 0) > 0
        and ((state.expires or 0) - now) or nil
    local active = state ~= nil and not (remaining and remaining <= 0)
    local missing, fromCamp = FP:PlanCamp(self:CampPicks(class), active,
        state and state.listed, self.campCovered, OwnAt(self.campOwn, now))
    return missing, fromCamp, remaining, state
end

--- The icons for the ticked camp bonuses: one per bonus missing, in the
--- picture of the first object that gives it, and Camp Benefits running out
--- while anything ticked rests on it.
function M:EvaluateCamp(entry, class, now)
    local out = {}
    local missing, fromCamp, remaining, state = self:CampPlan(entry, class, now)
    for index, bonus in ipairs(missing) do
        out[#out + 1] = {
            -- `variant` tells one bonus's icon from another's.
            kind = "missing", entry = entry, variant = bonus.id,
            icon = CampIcon(bonus), sort = index / 100,
        }
    end
    if fromCamp and remaining and remaining <= self:WarnAt(class, entry, state.duration) then
        out[#out + 1] = {
            kind = "expiring", entry = entry, icon = state.icon,
            remaining = remaining, sort = 1 + remaining,
        }
    end
    return out
end

--- Said once per character: what a tracked group buff cannot see.
--
-- Asked for by the owner on 2026-09-22, when Battle Shout was added to the
-- tracker. The weakness is real and it is worth one line of chat: **another
-- player's cast is not readable during a fight**, so a shout somebody else gave
-- you leaves the tracker empty while you are plainly buffed. It sorts itself
-- out the moment combat ends and a real read is possible again.
--
-- Attached to the property rather than to the class. Any future group buff on
-- the lower display has exactly the same hole, and hardcoding "warrior" here
-- would mean the next one ships without the notice.
--
-- **Once per character and per entry.** Until build 70009 that meant once per
-- session, because the client handed nothing back; since 2026-09-26 it means
-- once. The character is its guid (`FP:CharacterKey`), so a name the client
-- decides to spell differently does not bring the line back.
local noticeChecked = false

local function TrackerNotice()
    if noticeChecked then return end

    local key = FP:CharacterKey()
    -- An empty spellbook means the answer would be "you cannot cast it" for
    -- everything, which is not an answer. Try again on the next tick.
    if not key or not next(known) or type(FP.global) ~= "table" then return end
    noticeChecked = true

    local _, entries = ClassEntries()
    for _, entry in ipairs(entries) do
        if DisplayFor(entry) == "tracker" and entry.kind == "group"
           and Castable(entry) then
            FP.global.noticed = FP.global.noticed or {}
            local slot = key .. "/" .. entry.id
            if not FP.global.noticed[slot] then
                FP.global.noticed[slot] = true
                local name = FP:SpellName(BestKnown(entry)) or FP:T(entry.label)
                FP:Print(L["During combat, the client cannot check whether "
                      .. "%s is active on you. The addon can only track it "
                      .. "from your own casts. If another player casts it on "
                      .. "you, it may be reported as missing until combat "
                      .. "ends. This message is shown once per character."],
                    name)
            end
        end
    end
end

--- The tracked buffs that are running right now.
--
-- Deliberately short, and it reads only what `Scan` and `NoteCast` have already
-- put in `self.seen`, so the tracker costs no extra look at the client.
--
-- **No suppression and no dead check**, unlike the warning list. Those two exist
-- because a warning asks the player for something, and asking somebody who is
-- mounted, resting or dead is pointless. A tracker asks for nothing: it reports
-- a buff the player is wearing, and a dead player is wearing none, so the list
-- empties itself without a rule.
--
-- **Nothing is drawn for a buff that is absent**, which is the whole difference
-- and the owner's own decision on 2026-09-22: it makes it a tracker rather than
-- a warning with a longer face.
function M:Tracked()
    -- **No `scanned` guard**, unlike the warning list, and the difference is
    -- the direction of the inference. That guard exists because a buff nobody
    -- has managed to read yet must not be reported as *missing*: absence
    -- inferred from silence is the failure AGENTS.md keeps warning about. A
    -- tracker only ever draws what is positively known to be running, from an
    -- aura that was read or a cast that was seen, so there is nothing here for
    -- that guard to protect. Logging in during a fight and casting a Seal is
    -- exactly the case it would otherwise break.
    local now = GetTime()
    local class, entries = ClassEntries()
    local out = {}

    for _, entry in ipairs(entries) do
        -- The same switch as every other buff, in the same list on the same
        -- page: a tracker the player does not want is one they unticked. It
        -- also has to be castable, or a warrior below the level for Battle
        -- Shout would have an entry that can never draw anything.
        if entry.tracker and not self:BuffOff(class, entry)
           and Castable(entry) then
            local state     = self.seen[entry.id]
            local expires   = state and (state.expires or 0) or 0
            local remaining = expires > 0 and (expires - now) or nil

            if remaining and remaining > 0 then
                out[#out + 1] = {
                    entry     = entry,
                    kind      = "tracker",
                    -- Behind every warning sharing this display. A countdown
                    -- that is simply running is the least urgent thing there.
                    sort      = 3e6 + remaining,
                    icon      = state.icon or FP:SpellIcon(state.spellId),
                    name      = state.name,
                    -- The measured length where there is one, the table's
                    -- figure otherwise. The countdown turns red at a share of
                    -- it, so it has to be there even on a first cast.
                    duration  = (state.duration or 0) > 0
                                and state.duration or entry.duration,
                    remaining = remaining,
                }
            end
        end
    end
    return out
end

-- Defined with the counting below, and used by NoteCast above it.
local FullCharges

--- A cast landed. If it was one of ours, the warning has answered itself.
--
-- The only update available in combat, and the whole reason a missing self
-- buff may be shown during a fight at all.
function M:NoteCast(spellId)
    if not spellId then return end
    -- Any cast of the player's own, for the crits a Water Shield counts: see
    -- NoteCritSign.
    self.critGate:Cast(GetTime())

    local _, entries = ClassEntries()
    for _, entry in ipairs(entries) do
        for lineIndex, line in ipairs(entry.lines or {}) do
            for rank = 1, #line do
                if line[rank] == spellId then
                    local previous = self.seen[entry.id]
                    -- The duration comes from the last time this was read
                    -- properly. Without one, it is recorded as present with no
                    -- timer, which stops the nagging without inventing a
                    -- countdown nobody measured.
                    --
                    -- **Unless the entry carries one**, which is what makes a
                    -- tracker work on the first cast of a session: a player who
                    -- pulls before buffing has never given the addon a chance
                    -- to read the aura, and an icon with no time on it is the
                    -- one thing a countdown display must not be. The measured
                    -- value still wins whenever there is one.
                    local duration = (previous and previous.duration) or 0
                    if duration <= 0 then duration = entry.duration or 0 end
                    self.seen[entry.id] = {
                        spellId  = spellId,
                        line     = lineIndex,
                        rank     = rank,
                        icon     = FP:SpellIcon(spellId)
                                   or (previous and previous.icon),
                        name     = previous and previous.name,
                        duration = duration,
                        expires  = duration > 0 and (GetTime() + duration) or 0,
                        -- A fresh shield is a full one. The wait since the last
                        -- spent charge is not reset: see NoteHit.
                        charges  = entry.counted and FullCharges(entry) or nil,
                    }
                    return
                end
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Learning what a weapon buff is called, from its cast
--
-- A German Shaman reported on CurseForge on 2026-10-05 that the main hand
-- imbue was always reported missing, and found that on some clients no name
-- comparison can ever work: the Spanish one calls the spell "Arma comerrocas"
-- and prints "Muerdepiedras 1" on the weapon. His idea, built here in our own
-- way: watch the cast. Both hands are read when an imbue or a poison is sent,
-- and again a moment after it went off, and the one line that appeared or was
-- renewed is kept as that spell's, for the account. See *Learning a line from
-- the cast* in Core/Weapon.lua for how that line is found and used.
--
-- **It also makes a wrong warning honest.** Where a name cannot be matched,
-- the imbue on the weapon is taken for a stone and reported missing, which is
-- the warning nobody could clear before. Recasting it is now what clears it,
-- and for good, so the one action the warning asks for is the one that fixes
-- the reading.
--
-- UNIT_SPELLCAST_SENT goes out before the server has done anything, so the
-- first reading is the weapon as it was. Then several looks, since the
-- enchant arrives a moment after the cast does.
-- ---------------------------------------------------------------------------

local LEARN_AFTER  = { 0.3, 1, 2, 4 }   -- seconds after the cast to look again
local LEARN_WINDOW = 10                 -- seconds a sent cast may take to succeed

local weaponCasts   -- spell id -> true, for this class's weapon buffs
local sentCast      -- { spell, before, at } for the one just sent

--- The spells that put this class's own buff on a weapon: every rank of every
--- imbue, and of every poison since `casts` lists them all.
local function WeaponCasts()
    if weaponCasts then return weaponCasts end
    local casts = {}
    local _, entries = ClassEntries()
    for _, entry in ipairs(entries) do
        if entry.kind == "weapon" then
            for _, line in ipairs(entry.rankLines or {}) do
                for _, id in ipairs(line) do casts[id] = true end
            end
            for _, id in ipairs(entry.names or {}) do casts[id] = true end
            for _, id in ipairs(entry.casts or {}) do casts[id] = true end
        end
    end
    weaponCasts = casts
    return casts
end

-- The spell id goes through PlainNumber first. Both events are marked in this
-- build's API documentation as secret while spell casts are restricted, and
-- only the second has been measured plain for the player in a fight.
function M:NoteWeaponSent(spellId)
    spellId = FP:PlainNumber(spellId)
    if not (spellId and WeaponCasts()[spellId]) then return end
    -- A weapon that could not be read leaves nothing to compare against, and
    -- whatever the cast put there would look new beside everything else.
    local before = FP:WeaponLines()
    sentCast = before and { spell = spellId, before = before, at = GetTime() } or nil
end

function M:NoteWeaponCast(spellId)
    spellId = FP:PlainNumber(spellId)
    local cast = sentCast
    if not (cast and cast.spell == spellId and GetTime() - cast.at < LEARN_WINDOW) then
        return
    end
    sentCast = nil
    if not (C_Timer and C_Timer.After) then return end

    for _, delay in ipairs(LEARN_AFTER) do
        C_Timer.After(delay, function()
            if cast.done then return end
            local after = FP:WeaponLines()
            local line = after and FP:CastLine(cast.before, after)
            if not line then return end
            cast.done = true
            FP:LearnEnchantLine(line.name, cast.spell)
            FP:Safe("BuffExpiry:Update", M.Update, M)
        end)
    end
end

-- ---------------------------------------------------------------------------
-- Counting charges in a fight
--
-- The Shaman shields, the Troll priest's Shadowguard and since 2026-10-11
-- Inner Fire, the entries that carry `counted`, and nothing else. Everything
-- about the aura stays unreadable in combat, but UNIT_COMBAT reaches an addon
-- for the player inside the lockdown with plain values, measured 2026-09-27,
-- and the probe of 2026-09-29 found the rule the hits follow: a WOUND spends a
-- charge when the last charge went at least `cooldown` seconds before, a dodge
-- or a miss spends none, and a recast fills the shield without restarting that
-- wait. Held against the charges read after 36 fights, it was right in 35.
-- Inner Fire's rule is the owner's word, no cooldown and physical hits only,
-- with the probe's addition of 2026-10-11 that a hit of no damage spends
-- nothing; it held in all four fights the probe read the same evening, and
-- spell hits spend none, the owner's certain word.
--
-- **Water Shield's charges go on the Shaman's own critical spells too**, the
-- owner's word of 2026-10-16, under the cooldown the hits share, and no addon
-- can tell whose crit a crit was. What it can see is the mana the shield gives
-- back for every charge it spends, 3 percent of the maximum, which reaches
-- UNIT_COMBAT for the player as ENERGIZE. A gain of exactly that size beside a
-- crit that may have been the player's own spell spends a charge like a hit,
-- under the same cooldown, so a crit and a hit inside one spend one. A gain
-- of another size is another source's, and one without a crit a tick's: see
-- NoteMana. **Built unmeasured, the owner's choice of 2026-10-17**, since no
-- Shaman of his reached Water Shield's level before the beta closed. If the
-- gain or the crit never arrives, the hits alone count, as before.
--
-- So the count is a prediction rather than a reading, and two things keep it
-- honest. It starts from a real read before the fight and is replaced by a
-- real read after it, so an error lives exactly as long as the fight. And it
-- only ever says one thing, that the shield is empty, which the player answers
-- with a recast that is seen: the test in AGENTS.md holds.
-- ---------------------------------------------------------------------------

--- When each counted entry last spent a charge, by entry id. Survives a
--- recast, which is the measured behaviour, and a read, which cannot see it.
M.spentAt = {}

--- The most charges ever read for an entry, by entry id.
M.mostCharges = {}

--- The charges a read of a fresh cast showed last, by entry id: what a recast
--- gives now. The owner asked on 2026-10-11 whether unlearning Improved Inner
--- Fire brings the count back down, and with the most ever read alone it
--- would not have until the next reload.
M.fullCharges = {}

--- What a recast gives: what the last fresh cast showed, or else the table's
--- figure, or more if more was ever read.
FullCharges = function(entry)
    local fresh = M.fullCharges[entry.id]
    if fresh then return fresh end
    local most = M.mostCharges[entry.id] or 0
    return math.max(most, entry.counted and entry.counted.charges or 0)
end

--- Is this entry being counted right now?
--
-- Only while the last look knows how many charges there are. A shield read
-- without a usable count, or never read at all this session, is not counted,
-- and then the old rule applies: nothing at all in combat.
function M:Counting(entry)
    if not entry.counted then return false end
    local state = self.seen[entry.id]
    if state ~= nil and state.charges == nil then return false end
    -- A buff of many charges that has only ever read one is a client that
    -- shows no stack for it, and its count would be empty after one hit. Not
    -- counted then; a buff never read this session is counted as before.
    local known = math.max(self.fullCharges[entry.id] or 0,
                           self.mostCharges[entry.id] or 0)
    if (entry.counted.charges or 0) > 1 and known == 1 then return false end
    return true
end

--- A hit on the player. Spends a charge from every counted entry it can.
--
-- An entry with `physical` takes only a physical hit, school 1, a melee or a
-- ranged attack, and one with `absorbed = false` none that did no damage:
-- one a shield took, flagged ABSORB with an amount of 0, and one of 0 without
-- the flag, see `counted` in Data/Buffs.lua.
function M:NoteHit(action, flag, amount, school)
    local kind = FP:Plain(action)
    if kind == "ENERGIZE" then return self:NoteMana(amount) end
    if kind ~= "WOUND" then return end
    local physical = FP:PlainNumber(school) == 1
    local absorbed = FP:Plain(flag) == "ABSORB" or FP:PlainNumber(amount) == 0
    local now = GetTime()
    local _, entries = ClassEntries()
    for _, entry in ipairs(entries) do
        local counted = entry.counted
        local state = counted and self.seen[entry.id]
        if state and (state.charges or 0) > 0
           and (physical or not counted.physical)
           and (not absorbed or counted.absorbed ~= false) then
            local last = self.spentAt[entry.id]
            if not last or now - last >= counted.cooldown then
                state.charges = state.charges - 1
                self.spentAt[entry.id] = now
            end
        end
    end
end

--- The player's maximum mana, which reads plainly where the mana does not.
local function ManaMax()
    if not UnitPowerMax then return nil end
    local mana = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0
    local ok, value = pcall(UnitPowerMax, "player", mana)
    return ok and FP:PlainNumber(value) or nil
end

-- How near a crit and the mana it made the shield give back must come, either
-- way round, and how long before the crit the player's own cast may lie: a
-- bolt is still travelling after its cast. See FP:NewCritGate.
M.critGate = FP:NewCritGate(0.5, 3)

--- The share of the maximum mana the shield the player wears gives back for a
--- spent charge, while it has charges, or nil.
local function WornShieldShare(self)
    local _, entries = ClassEntries()
    for _, entry in ipairs(entries) do
        local counted = entry.counted
        local state = counted and counted.mana and self.seen[entry.id]
        local share = state and counted.mana[state.spellId]
        if share and (state.charges or 0) > 0 then return share end
    end
    return nil
end

--- Spends a charge from every shield that gives mana back, as of `at`, under
--- the cooldown the hits keep.
local function SpendForMana(self, at)
    local _, entries = ClassEntries()
    for _, entry in ipairs(entries) do
        local counted = entry.counted
        local state = counted and counted.mana and self.seen[entry.id]
        if state and counted.mana[state.spellId] and (state.charges or 0) > 0 then
            local last = self.spentAt[entry.id]
            if not last or at - last >= counted.cooldown then
                state.charges = state.charges - 1
                self.spentAt[entry.id] = at
            end
        end
    end
end

--- A mana gain on the player, the size of the share the worn shield gives
--- back. Spends a charge only beside a crit that may have been the player's
--- own spell, which spends Water Shield's charges on WoW Forever.
--
-- **The crit is the gate, the owner's concern of 2026-10-17**: a mana source
-- that ticks, a drink, a totem or the camp's bonus, may happen to give the
-- same share, and would then have emptied the count in a fight tick by tick.
-- A tick comes without a crit. So the gain spends a charge when a crit comes
-- within half a second of it, either way round; a gain left waiting for a
-- crit that never comes spends nothing.
--
-- A charge a hit spent gives its mana back too. It comes without a crit and
-- inside the hit's cooldown, so it spends nothing more either way.
function M:NoteMana(amount)
    amount = FP:PlainNumber(amount)
    if not amount or amount <= 0 then return end
    local share = WornShieldShare(self)
    if not share then return end
    local max = ManaMax()
    if not (max and FP:IsShieldMana(amount, max, share)) then return end
    local at = self.critGate:Mana(GetTime())
    if at then SpendForMana(self, at) end
end

--- A UNIT_COMBAT event on any unit, for the crits that may have been the
--- player's own spells: see FP:IsSpellCritSign. Only one that comes after a
--- cast of the player's own counts, and it pairs with a gain that came just
--- before it, or waits half a second for one.
function M:NoteCritSign(unit, action, flag, school)
    if not FP:IsSpellCritSign(FP:Plain(unit), FP:Plain(action), FP:Plain(flag),
                              FP:PlainNumber(school)) then
        return
    end
    local at = self.critGate:Crit(GetTime())
    if at then SpendForMana(self, at) end
end

-- ---------------------------------------------------------------------------
-- What goes on the bars
--
-- Every item says which entry it is about and which bar that entry starts on;
-- Core/Warnings.lua finds the bar the player chose and draws it there, beside
-- whatever the Consumables page has on the same bar.
-- ---------------------------------------------------------------------------

--- Names an item's entry, its factory bar, and which of the entry's icons it is.
local function Route(item, class)
    if item.tracking then
        item.key = "buffs:track/" .. tostring(item.tracking.id)
        item.factory = "general"
    elseif item.entry then
        item.key = EntryKey(item.ownerClass or class, item.entry)
        item.factory = FactoryBar(item.entry)
    else
        item.key, item.factory = "buffs:?", "general"
    end
    -- One entry can draw several icons: a blessing per variant, a running
    -- countdown beside a warning, its own copy beside one somebody owes it.
    item.rid = item.key .. "|" .. tostring(item.variant or "") .. "|"
        .. tostring(item.kind) .. (item.fromOthers and "|o" or "")
    return item
end

function M:Update()
    -- The settings page shows the same data. While it is open, the ticker that
    -- drives the countdown keeps the list current too.
    local menu = _G.ForeverPlusMenu
    if menu and menu:IsShown() then RefreshList() end

    -- Reading is only possible out of combat, so that is when it happens. In
    -- combat this runs on what the last look found plus the clock, which is
    -- exact for an expiry and is the only thing the client permits.
    self:Scan()

    -- A read of its own, because the minimap slots are not auras and nothing
    -- that stops Scan applies to them.
    FP:Safe("BuffExpiry:ScanTracking", M.ScanTracking, self)

    FP:Safe("BuffExpiry:TrackerNotice", TrackerNotice)

    -- The running countdowns and the warnings together; the bars sort them,
    -- so that anything wrong comes before anything that is merely running: a
    -- missing shout matters more than a Seal with twenty seconds left.
    local class = ClassToken()
    local items = {}
    for _, item in ipairs(self:Tracked()) do items[#items + 1] = Route(item, class) end
    for _, item in ipairs(self:Evaluate()) do items[#items + 1] = Route(item, class) end
    FP:HandIn("buffs", items)
end

--- Moves the bar the warnings start on. What /fplus buffs did before the bars
--- were the profile's, kept so the command still does something useful.
function M:TogglePreview()
    if FP.MoveBars then FP:MoveBars("general") end
end


local function VariantName(entry, id)
    local variant = entry.byVariant and entry.byVariant[id]
    if not variant then return tostring(id) end
    return FP:SpellName(variant.ids[#variant.ids]) or id
end

--- Every tracked buff for this class, with the verdict on it.
--
-- Feeds both the chat command and the list on the settings page, so the two
-- cannot drift apart. It reports on the *tracked* entries rather than on
-- whatever happens to be on the player, because that is the question worth
-- answering: not "what do I have" but "what is this addon doing about it".
function M:Inspect()
    local now = GetTime()
    local class, entries = ClassEntries()
    local rows = {}

    -- A per caster entry becomes one row per blessing the class wants, because
    -- a single row saying "Blessing: missing" cannot tell you *which* of the
    -- three you are short, which is the only useful part.
    local function PerCasterRows(entry, ownerClass)
        -- The same plan the icons are drawn from, so this list and the icons
        -- cannot disagree about whether a blessing is on you or worth asking
        -- for. They did once: the list counted a blessing that had run out as
        -- missing while the icons said nothing.
        local plan = self:PlanPerCaster(entry, ownerClass, now)
        if #plan.wanted == 0 then return end

        for _, id in ipairs(plan.wanted) do
            local state = plan.held[id]
            local row = {
                entry = entry, variant = id,
                fromOthers = (ownerClass ~= class) and ownerClass or nil,
                name = VariantName(entry, id),
                icon = state and state.icon,
                waiting = 0,
            }

            if state then
                local remaining = (state.expires or 0) > 0
                    and ((state.expires or 0) - now) or nil
                row.duration, row.remaining = state.duration, remaining
                if remaining and remaining <= self:WarnAt(ownerClass, entry, state.duration) then
                    row.verdict = "showing"
                else
                    row.verdict = "waiting"
                end
            elseif plan.ask[id] then
                row.verdict = "missing"
            elseif not AnyGiver(plan.givers, id) then
                -- Nobody present can cast it: no Paladin at all, or none who
                -- has reached the level it is trained at.
                row.verdict = "unknown"
            else
                -- Wanted, absent, and there is no Paladin left to ask, or one
                -- blessing is all that is asked for below the level cap. Not
                -- a fault and not something to warn about.
                row.verdict = "waiting"
            end

            rows[#rows + 1] = row
        end
    end

    -- Ticked camp bonuses get a row each, like the blessings: one row for Camp
    -- Benefits could not say which bonus is missing.
    local function CampRows(entry)
        local missing, _, remaining, state = self:CampPlan(entry, class, now)
        local gone = {}
        for _, bonus in ipairs(missing) do gone[bonus.id] = true end
        for _, bonus in ipairs(self:CampPicks(class)) do
            local row = {
                entry = entry, spell = bonus.spell, waiting = 0,
                name = FP:T(bonus.label) or bonus.id,
                icon = CampIcon(bonus),
            }
            if gone[bonus.id] then
                row.verdict = "missing"
            elseif self.campCovered and self.campCovered[bonus.id] then
                -- A class buff stands in for it: nothing to say.
                row.verdict = "waiting"
            elseif bonus.ownAura then
                -- Its own aura runs, which is all there is to it.
                row.verdict = "waiting"
            else
                row.duration, row.remaining = state and state.duration, remaining
                if remaining and remaining <= self:WarnAt(class, entry, state.duration) then
                    row.verdict = "showing"
                else
                    row.verdict = "waiting"
                end
            end
            rows[#rows + 1] = row
        end
    end

    for _, entry in ipairs(entries) do
        if entry.perCaster then
            PerCasterRows(entry, class)
        elseif entry.camp and not self:BuffOff(class, entry)
               and #self:CampPicks(class) > 0 then
            CampRows(entry)
        else
            local state = self.seen[entry.id]
            local row = {
                entry   = entry,
                spell   = state and state.spellId,
                waiting = (entry.kind == "group") and self:CountMissing(entry) or 0,
                name  = (state and state.name) or FP:SpellName(BestKnown(entry))
                        or FP:T(entry.label) or entry.id,
                icon  = (state and state.icon) or EntryIcon(entry),
            }

            if self:BuffOff(class, entry)
               or (entry.targets and not self:TargetsSelf(class, entry)) then
                row.verdict = "off"
            elseif not Castable(entry) then
                -- Not trained, or for a weapon entry nothing in that hand that
                -- could take an enchant. Either way nothing is missing.
                row.verdict = "unknown"
            elseif entry.kind == "pet" then
                -- Not an aura, so nothing in `seen`: the mood asked for now,
                -- and showing exactly while Evaluate draws an icon for it.
                local happiness = PetHappiness()
                row.verdict = (happiness and happiness < 3 and not InCombat())
                              and "showing" or "waiting"
            elseif entry.tracker then
                -- A tracker has two states and neither of them is "missing".
                -- Either it is running, in which case it is on screen, or it
                -- is not, in which case there is nothing to say. Falling
                -- through to the verdicts below would have this list report a
                -- Seal nobody has cast yet as missing, which is the one
                -- sentence the entry exists to avoid saying.
                local remaining = state and (state.expires or 0) > 0
                    and ((state.expires or 0) - now) or nil
                row.duration  = state and state.duration
                row.remaining = remaining
                row.verdict   = (remaining and remaining > 0)
                                and "showing" or "waiting"

            elseif not state then
                row.verdict = "missing"
            else
                local remaining = (state.expires or 0) > 0
                    and ((state.expires or 0) - now) or nil
                row.duration  = state.duration
                row.remaining = remaining

                if remaining and remaining <= 0 then
                    row.verdict = "missing"
                elseif remaining and remaining <= self:WarnAt(class, entry, state.duration) then
                    row.verdict = "showing"
                elseif BetterRank(entry, state) then
                    row.verdict = "upgrade"
                elseif row.waiting > 0 then
                    row.verdict = "handout"
                else
                    row.verdict = "waiting"
            end
        end

        rows[#rows + 1] = row
        end
    end

    -- And what other people are offering, which is the half that is easiest to
    -- doubt and therefore the half most worth listing.
    for _, offer in ipairs(self:Offers()) do
        local entry = offer.entry

        if entry.perCaster then
            PerCasterRows(entry, offer.class)
        else
            local state = self.seen[entry.id]
            local row = {
                entry = entry,
                spell = state and state.spellId,
                fromOthers = offer.class,
                name  = (state and state.name) or FP:T(entry.label) or entry.id,
                icon  = (state and state.icon) or EntryIcon(entry),
                waiting = 0,
            }

            local remaining = state and (state.expires or 0) > 0
                and ((state.expires or 0) - now) or nil
            row.duration, row.remaining = state and state.duration, remaining

            if not state or (remaining and remaining <= 0) then
                row.verdict = "missing"
            elseif remaining and remaining <= self:WarnAt(offer.class, entry, state.duration) then
                row.verdict = "showing"
            else
                row.verdict = "waiting"
        end

        rows[#rows + 1] = row
        end
    end

    -- Worst first, and within a verdict by how little is left.
    local RANK = { missing = 0, upgrade = 1, showing = 2, handout = 3,
                   waiting = 4, unknown = 5, off = 6 }
    table.sort(rows, function(a, b)
        if RANK[a.verdict] ~= RANK[b.verdict] then
            return RANK[a.verdict] < RANK[b.verdict]
        end
        return (a.remaining or math.huge) < (b.remaining or math.huge)
    end)
    return rows
end

--- Holds every id in Data/Buffs.lua up against the client.
--
-- Those numbers were written from memory, and build 69913 is newer than the
-- memory they came from. They are claims until this says otherwise. An id the
-- client does not recognize is a buff that will silently never warn, which is
-- the worst kind of wrong: nothing breaks, it just quietly does less than it
-- promises.
--
-- The result goes into the saved file rather than into chat. Two hundred lines
-- of spell names is not something to read in a chat frame. Since build 70009
-- the file also hands it back, so it stays until the next verify replaces it.
function M:VerifyTables()
    local known, unknown = {}, {}

    for _, entry in ipairs(FP:AllClassBuffs()) do
        if entry.kind == "weapon" then
            -- The enchant itself is read off the weapon rather than looked up,
            -- so there are no ids there. The spells that *let* you enchant are
            -- ordinary ids and very much want checking.
            known[#known + 1] = string.format("%s %s = weapon slot %s",
                entry.class, entry.id, tostring(entry.slot))
        end

        local ids = FP:BuffSpellIds(entry)
        for _, id in ipairs(entry.requires or {}) do ids[#ids + 1] = id end
        -- The poison names a weapon line is sorted by: an id this build does
        -- not know would quietly leave that poison looking like a stone.
        for _, id in ipairs(entry.names or {}) do ids[#ids + 1] = id end
        -- And every rank whose cast teaches a line its place: an id this build
        -- does not know is a rank whose renewal never teaches anything.
        for _, id in ipairs(entry.casts or {}) do ids[#ids + 1] = id end

        -- Once each: the first rank of a poison is both a name and a cast.
        local seen = {}
        for _, id in ipairs(ids) do
            if not seen[id] then
                seen[id] = true
                local name = FP:SpellName(id)
                local line = string.format("%s %s %d = %s",
                    entry.class, entry.id, id, name or "UNKNOWN")
                if name then known[#known + 1] = line
                else unknown[#unknown + 1] = line end
            end
        end
    end

    -- The camp's hidden bonuses, which the hover names, and the class buffs
    -- standing in for one that the class tables leave out. Whether the client
    -- knows a hidden aura at all is part of what this answers.
    for _, bonus in ipairs(FP.campBonuses or {}) do
        local ids = { bonus.spell }
        for _, id in ipairs(bonus.ids or {}) do ids[#ids + 1] = id end
        for _, id in ipairs(ids) do
            local name = FP:SpellName(id)
            local line = string.format("camp %s %d = %s", bonus.id, id, name or "UNKNOWN")
            if name then known[#known + 1] = line
            else unknown[#unknown + 1] = line end
        end
    end

    FP.global.buffCheck = {
        checked = #known + #unknown,
        unknown = #unknown,
        known   = known,
        missing = unknown,
    }

    FP:Print("Buff tables: %d ids checked, |cffffffff%d|r not recognized by "
        .. "this client.", #known + #unknown, #unknown)
    for index = 1, math.min(#unknown, 8) do
        DEFAULT_CHAT_FRAME:AddMessage("  |cffff5555" .. unknown[index] .. "|r")
    end
    if #unknown > 8 then
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "  |cff888888... and %d more|r", #unknown - 8))
    end
    FP:Print("Full result is in the saved settings. |cff888888/reload|r puts "
        .. "it on disk.")
end

--- What the camp bonuses come to, in chat: what Camp Benefits says, what of
--- it was recognized, and where each ticked bonus stands.
--
-- The instrument for the one guess in the feature, that the description names
-- an object the way its item does: a line no name matched is printed as such.
function M:CampStatus()
    local entry
    for _, shared in ipairs(FP.sharedBuffs or {}) do
        if shared.camp then entry = shared end
    end
    if not entry then return FP:Print("No camp entry in the buff tables.") end

    local class = ClassToken()
    local names, complete = CampNames()
    FP:Print("Camp bonuses: %d of 30 object names known%s.", #names,
        complete and "" or ", the rest asked of the client")

    local state = ReadEntry(entry)
    local listed
    if not state then
        FP:Print("Camp Benefits is not on you.")
    else
        local left = math.max(0, (state.expires or 0) - GetTime())
        local text = CampText(state.instance)
        FP:Print("Camp Benefits is on you, %s left. Its description:",
            FP:FormatTime(left))
        if not text then
            DEFAULT_CHAT_FRAME:AddMessage("  |cffff5555unreadable|r")
        else
            for raw in (text:gsub("\r", "") .. "\n"):gmatch("(.-)\n") do
                if raw:match("%S") then
                    DEFAULT_CHAT_FRAME:AddMessage("  |cffffffff" .. raw .. "|r")
                end
            end
            local unmatched
            listed, unmatched = FP:CampListed(text, names)
            for _, line in ipairs(unmatched) do
                DEFAULT_CHAT_FRAME:AddMessage("  |cffff5555no object matched:|r " .. line)
            end
            if listed then
                local found = {}
                for _, bonus in ipairs(FP.campBonuses or {}) do
                    if listed[bonus.id] then found[#found + 1] = bonus.id end
                end
                FP:Print("Recognized: %s.",
                    #found > 0 and table.concat(found, ", ") or "nothing")
            else
                FP:Print("Recognized: unknown, so no ticked bonus is called missing "
                    .. "while Camp Benefits is on.")
            end
        end
    end

    local picks = self:CampPicks(class)
    if #picks == 0 then
        return FP:Print("Nothing ticked for %s: Camp Benefits is watched as a whole.",
            tostring(class))
    end
    local covered, own = CampCovered(picks), CampOwn(picks)
    local now = GetTime()
    local missing = FP:PlanCamp(picks, state ~= nil, listed, covered, OwnAt(own, now))
    local gone = {}
    for _, bonus in ipairs(missing) do gone[bonus.id] = true end
    FP:Print("Ticked for %s:", tostring(class))
    for _, bonus in ipairs(picks) do
        local verdict
        local name = bonus.ownAura and (FP:SpellName(bonus.spell) or tostring(bonus.spell))
        if covered[bonus.id] then verdict = "|cff44ff44a class buff stands in|r"
        elseif gone[bonus.id] and bonus.ownAura then
            verdict = "|cffff5555missing|r, " .. name .. " is not on you, so it can be had again"
        elseif gone[bonus.id] then verdict = "|cffff5555missing|r"
        elseif bonus.ownAura then
            local ends = own[bonus.id] or 0
            verdict = "|cff44ff44had|r, " .. name .. " on you"
                .. (ends > 0 and (", " .. FP:FormatTime(math.max(0, ends - now)) .. " left") or "")
        else verdict = "|cff44ff44from the camp|r" end
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  %s: %s", bonus.id, verdict))
    end
end

--- The same verdicts, in chat.
--
-- Built because "the icon did not appear" has too many possible causes to
-- guess at. This says which one it was, per buff.
local WORDING = {
    missing = "|cffff5555missing|r",
    upgrade = "|cffffaa00better rank known|r",
    showing = "|cff44ff44showing|r",
    handout = "|cff4499ffothers are missing it|r",
    waiting = "|cff888888not yet|r",
    unknown = "|cff888888not trained, or no weapon|r",
    off     = "|cff888888switched off|r",
}

--- Why the weapon entries are or are not doing anything.
--
-- **Three things have to be true before an imbue can ever be shown**, and from
-- outside they fail identically: the client has to offer the call at all, the
-- hand has to hold a weapon, and the character has to know a spell that could
-- enchant it. A Shaman reported weapon enchants "not working at all" on
-- 2026-09-20, which could have been any of the three, and guessing which would
-- have meant fixing the wrong one.
function M:WeaponStatus()
    -- Collected as well as printed. Three rounds of this were read off cropped
    -- screenshots, and the line that mattered was below the fold every time.
    local lines = {}
    local function Say(fmt, ...)
        local text = string.format(fmt, ...)
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffffff" .. text .. "|r")
        lines[#lines + 1] = (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    end
    local function mark(ok) return ok and "yes" or "no" end

    FP:Print("Weapon enchants, the three things that have to be true:")

    local exists = _G.GetWeaponEnchantInfo ~= nil
    Say("%-28s %s", "GetWeaponEnchantInfo exists", mark(exists))

    if exists then
        -- select("#") rather than the length operator: the call returns nils
        -- in the middle when nothing is enchanted, and the length of a table
        -- with holes is free to stop at the first one. That is how a count of
        -- five appeared, which is no shape this call has.
        --
        -- **Measured on this build: twelve values.** Neither the six of old
        -- Classic nor the eight of retail, but three slots of four, main hand
        -- then off hand then ranged. So the off hand does begin at five and
        -- the module was unpacking it correctly after all.
        local count  = select("#", pcall(GetWeaponEnchantInfo))
        local packed = { pcall(GetWeaponEnchantInfo) }
        if not packed[1] then
            Say("%-28s", "  the call raised")
        else
            Say("%-28s %d values", "  it returns", count - 1)
            for i = 2, count do
                Say("      [%d] %s", i - 1, tostring(packed[i]))
            end
        end
    end

    for _, slot in ipairs({ "main", "off" }) do
        Say("%-28s %s", "a weapon in the " .. slot .. " hand", mark(FP:HasWeapon(slot)))
    end

    -- What the client itself reports per kind, the call the placing rests on
    -- since 2026-11-06. Every field of every entry rather than what the code
    -- reads of them: 2 is Temporary, a stone or an oil, and 3 is Imbue. Seen for
    -- Rockbiter only, see Core/Weapon.lua, so this is the line to ask a player
    -- for about a stone, an oil, a poison or a Warlock's stone.
    local kinds = C_Item and C_Item.GetWeaponEnchantInfo
    Say("%-28s %s", "C_Item.GetWeaponEnchantInfo", mark(kinds ~= nil))
    for index, slot in ipairs(kinds and { "main", "off" } or {}) do
        local shown = pcall(function()
            local count = 0
            for _, enchant in pairs(kinds(index - 1)) do
                count = count + 1
                local fields = {}
                for key, value in pairs(enchant) do
                    fields[#fields + 1] = key .. "=" .. tostring(value)
                end
                table.sort(fields)
                Say("      %s [%d] %s", slot, count, table.concat(fields, " "))
            end
            if count == 0 then Say("      %s %s", slot, "an empty list") end
        end)
        if not shown then Say("      %s %s", slot, "the call raised") end
    end

    -- What the addon makes of each hand, and the text it read that from, both
    -- hands and near the top. Added on 2026-09-26 for a Rogue whose Instant
    -- Poison was reported missing while Crippling Poison was seen: the answer
    -- is in the exact wording of one tooltip line, the dump further down only
    -- ever covered the main hand, and a screenshot of this command has to
    -- catch the line that matters before the fold.
    -- Both places per hand since the same day, because WoW Forever keeps two:
    -- the buff place for a poison or an imbue, the coating place for a stone
    -- or an oil. Which line went where is the reading most likely to be wrong,
    -- so it is the first thing said.
    local found = FP:WeaponEnchants()
    local tipReader = C_TooltipInfo and C_TooltipInfo.GetInventoryItem
    -- A place learned from a cast says so, with the spell that taught it,
    -- since 2026-10-05: the one reading that does not rest on names.
    local function Place(label, side)
        if side and side.has then
            local learned = ""
            if side.learned then
                learned = string.format(", learned from casting %s",
                    tostring(FP:SpellName(side.learned) or side.learned))
            end
            Say("%-28s %s, %d min left%s", label, tostring(side.name or "unnamed"),
                math.floor((side.remaining or 0) / 60 + 0.5), learned)
        else
            Say("%-28s %s", label, "nothing")
        end
    end
    for _, slot in ipairs({ "main", "off" }) do
        local hand = found and found[slot]
        Place(slot .. " hand poison or imbue", hand and hand.buff)
        Place(slot .. " hand stone or oil", hand and hand.coating)
        -- Which reading settled it: what the client reports per kind, which
        -- holds in every language, or the names.
        if hand and hand.placedBy then
            Say("%-28s %s", "  placed by", hand.placedBy == "kind"
                and "what the client reports per kind"
                or "names and learned casts")
        end
        local ok, data = false, nil
        if tipReader then ok, data = pcall(tipReader, "player", SLOT[slot]) end
        if ok and type(data) == "table" then
            for index, line in ipairs(data.lines or {}) do
                local text = type(line) == "table" and line.leftText
                if type(text) == "string" and text ~= "" then
                    Say("      %s [%d] %s", slot, index, (text:gsub("|", "||")))
                end
            end
        end
    end

    -- What the upgrade check makes of the enchant, spelled out. It rests on
    -- two readings of one string, and a reading is something to check rather
    -- than to believe: if this line says "cannot tell", the icon staying away
    -- is the feature working, not the feature missing.
    local enchants = FP:WeaponEnchants()
    for _, entry in ipairs(FP.classBuffs[ClassToken()] or {}) do
        if entry.kind == "weapon" and entry.rankLines then
            local hand = enchants and enchants[entry.slot]
            local name = hand and hand.buff and hand.buff.name
            Say("%-28s %s", entry.label .. " reads as", name or "nothing on it")
            if name then
                local rank, line = ReadEnchantRank(entry, name)
                if not rank then
                    Say("%-28s %s", "  which imbue and rank",
                        "cannot tell, so no upgrade is claimed")
                else
                    local best = 0
                    for i = #line, 1, -1 do
                        if known[line[i]] then best = i break end
                    end
                    Say("%-28s rank %d of %s, best trained is %s", "  which imbue and rank",
                        rank, tostring(FP:SpellName(line[#line])),
                        best > 0 and ("rank " .. best) or "none")
                end
            end
        end
    end

    -- Is the imbue an aura on the player rather than an enchant on the weapon?
    --
    -- **The question this whole branch got wrong if the answer is yes.** In
    -- Vanilla a Shaman imbue is a temporary weapon enchant and shows up in
    -- GetWeaponEnchantInfo. This build is Vanilla content on a modern engine
    -- and has already turned out to carry things Vanilla did not, so "it is an
    -- enchant" is an assumption nobody measured, and the call reporting false
    -- with Rockbiter applied is exactly what a wrong assumption looks like.
    local reader = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
    if not reader then
        Say("%-28s %s", "imbue as an aura on you", "cannot ask, no reader")
    else
        local found = {}
        for _, entry in ipairs(FP.classBuffs[ClassToken()] or {}) do
            for _, id in ipairs(entry.requires or {}) do
                if known[id] then
                    local ok, aura = pcall(reader, id)
                    if ok and aura then
                        found[#found + 1] = string.format("%d (%s)", id,
                            tostring(FP:SpellName(id)))
                    end
                end
            end
        end
        Say("%-28s %s", "imbue as an aura on you",
            #found > 0 and table.concat(found, ", ") or "none of the ones you know")
    end

    -- The quiet one. An entry whose `requires` list has no match is skipped
    -- entirely and says nothing at all, which looks exactly like the feature
    -- being broken.
    for _, entry in ipairs(FP.classBuffs[ClassToken()] or {}) do
        if entry.kind == "weapon" and entry.requires then
            local learned = {}
            for _, id in ipairs(entry.requires) do
                if known[id] then learned[#learned + 1] = id end
            end
            Say("%-28s %d of %d known%s", entry.label,
                #learned, #entry.requires,
                #learned > 0 and ("  " .. table.concat(learned, ", ")) or
                "  so this entry is skipped")
        end
    end

    -- Everything on the player, by number rather than by name.
    --
    -- **Asking by id can only find what somebody already guessed.** Both
    -- routes above ask whether a *known* imbue id is there, and both said no,
    -- which leaves two possibilities they cannot separate: the aura exists
    -- under an id that is not the one you cast, which is ordinary, or nothing
    -- was applied at all. Enumerating answers both without a guess in it.
    --
    -- Out of combat only, and that is not caution. Measured on this build: in
    -- combat every one of forty index reads raises. A refusal does not end the
    -- list either, because a secret aura still occupies its index and real
    -- ones sit behind it.
    local byIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if not byIndex then
        Say("%-28s %s", "everything on you", "cannot ask, no reader")
    elseif InCombatLockdown and InCombatLockdown() then
        Say("%-28s %s", "everything on you",
            "in combat, where this client answers nothing. Try again after.")
    else
        local seen, refused = 0, 0
        Say("%s", "everything on you right now:")
        for index = 1, 40 do
            local ok, aura = pcall(byIndex, "player", index, "HELPFUL")
            if not ok then
                refused = refused + 1
            elseif aura then
                seen = seen + 1
                Say("      [%d] %s  %s", index,
                    tostring(aura.spellId), tostring(aura.name))
            end
        end
        if seen == 0 then
            Say("      %s", "nothing readable at all")
        end
        if refused > 0 then
            Say("      %s", refused .. " index reads were refused")
        end
    end

    -- The enchant id, straight out of the item link.
    --
    -- **The number is already there and nobody had looked.** An item link is
    -- `item:<item>:<enchant>:...`, so the second field is the temporary
    -- enchant as a plain integer, zero when there is none. Language
    -- independent by construction, one call rather than a tooltip, and
    -- GetInventoryItemLink demonstrably works here since FP:HasWeapon is built on
    -- it.
    --
    -- It says *what* is on the weapon and never how long is left. The tooltip
    -- is still the only place the remaining time exists.
    for _, slot in ipairs({ "main", "off" }) do
        local ok, link = pcall(GetInventoryItemLink, "player", SLOT[slot])
        if not ok or not link then
            Say("%-28s %s", slot .. " hand link", "nothing")
        else
            local item, enchant = link:match("|?H?item:(%d+):(%d+)")
            Say("%-28s item %s, enchant %s", slot .. " hand link",
                tostring(item), tostring(enchant))
            -- The raw link too, with its pipes doubled so chat prints it as
            -- text instead of rendering it.
            Say("      raw: %s", (link:gsub("|", "||")))
        end
    end

    -- And what the weapon itself says it is carrying.
    --
    -- A temporary enchant is a line on the item's own tooltip. If the addon
    -- cannot see it through GetWeaponEnchantInfo and cannot see it as an aura,
    -- the tooltip is the last place it could be hiding, and it is also the
    -- place the player is reading it from.
    local tip = C_TooltipInfo and C_TooltipInfo.GetInventoryItem
    if not tip then
        Say("%-28s %s", "main hand tooltip", "cannot ask, no reader")
    else
        local ok, data = pcall(tip, "player", SLOT.main)
        if not ok or type(data) ~= "table" then
            Say("%-28s %s", "main hand tooltip", "nothing came back")
        else
            -- **Every field of every line, not just the text.**
            --
            -- A tooltip line is a table, and reading only leftText out of it
            -- is the same mistake the gossip options cost this morning: the
            -- shape was assumed instead of printed. If there is a line type
            -- for an enchant, neither color nor text matching is needed, and
            -- there may be structured values where the words say "(60 min)".
            Say("%s", "main hand tooltip, every field:")
            for index, line in ipairs(data.lines or {}) do
                if type(line) ~= "table" then
                    Say("      [%d] %s", index, tostring(line))
                else
                    local keys = {}
                    for key in pairs(line) do
                        if type(key) == "string" then keys[#keys + 1] = key end
                    end
                    table.sort(keys)
                    local parts = {}
                    for _, key in ipairs(keys) do
                        local value = rawget(line, key)
                        if type(value) ~= "table" then
                            parts[#parts + 1] = key .. "=" .. tostring(value)
                        else
                            parts[#parts + 1] = key .. "=<table>"
                        end
                    end
                    Say("      [%d] %s", index, table.concat(parts, "  "))
                end
            end

            -- And what the line types are called, so a number in the dump
            -- above can be read as a name.
            local names = {}
            pcall(function()
                for key in pairs(_G.Enum and _G.Enum.TooltipDataLineType or {}) do
                    if type(key) == "string" then
                        names[#names + 1] = key .. "="
                            .. tostring(_G.Enum.TooltipDataLineType[key])
                    end
                end
            end)
            table.sort(names)
            Say("%s", "tooltip line types this build knows:")
            Say("      %s", #names > 0 and table.concat(names, ", ") or "none")
        end
    end

    -- The format strings that would make the tooltip readable without
    -- comparing against game text.
    --
    -- The tooltip is now the only place a Shaman imbue is visible on this
    -- build, and picking its line out by matching English words is the one
    -- thing the locale rule forbids outright. The way through is the client
    -- own formats: build a pattern from ITEM_ENCHANT_TIME_LEFT_MIN and match
    -- that, exactly as ErrorFilter builds its filters from ERR_OUT_OF_MANA.
    -- Whether this build has them decides whether the feature is buildable at
    -- all, so it is asked here rather than assumed either way.
    Say("%s", "format strings for a tooltip enchant line:")
    for _, name in ipairs({ "ITEM_ENCHANT_TIME_LEFT_SEC", "ITEM_ENCHANT_TIME_LEFT_MIN",
                            "ITEM_ENCHANT_TIME_LEFT_HOURS", "ITEM_ENCHANT_TIME_LEFT_DAYS",
                            "ENCHANTED_TOOLTIP_LINE" }) do
        Say("      %-30s %s", name, tostring(_G[name]))
    end

    FP.global.weaponCheck = { stamp = date("%Y-%m-%d %H:%M:%S"), lines = lines }
    FP:Print("Written to the saved file as well. One /reload and it is on disk.")
end

--- /fplus buffs range: every answer Reachable could use, raw, per group member.
--
-- Written on 2026-10-03 for a report from the owner: alone in the south of
-- the Barrens, a Paladin far in the north, and the blessing icon came the
-- moment that Paladin crossed into the zone. One of the three answers in
-- Reachable said yes across most of a zone, and which one is not readable
-- from outside. The last two lines per unit are candidates for a real
-- distance, not used by Reachable yet.
--
-- Each value is printed as it came: "raised" when the call refused, "secret"
-- when it answered something that cannot be compared, else the value itself.
function M:RangeStatus()
    -- Collected as well as printed, and kept in the saved file. The first run
    -- of this, on 2026-10-03, was lost: the chat history keeps a hundred lines
    -- a window, and a battleground afterwards filled them with flag and honor
    -- lines before the owner reloaded.
    local lines = {}
    local function Say(fmt, ...)
        local text = string.format(fmt, ...)
        DEFAULT_CHAT_FRAME:AddMessage(text)
        lines[#lines + 1] = (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    end
    local function Keep()
        local runs = type(FP.global.rangeCheck) == "table" and FP.global.rangeCheck or {}
        runs[#runs + 1] = { stamp = date("%Y-%m-%d %H:%M:%S"), lines = lines }
        while #runs > 6 do table.remove(runs, 1) end
        FP.global.rangeCheck = runs
        FP:Print("Written to the saved file as well, with the five runs before "
            .. "it. One /reload and it is on disk.")
    end

    local function Shown(ok, ...)
        if not ok then return "raised" end
        local out = {}
        for i = 1, math.max(select("#", ...), 1) do
            local v = select(i, ...)
            local text
            local plain = pcall(function()
                if type(v) == "table" then
                    -- A position comes back as a vector: opened, since a
                    -- table printed with tostring has measured nothing.
                    text = string.format("{x=%s, y=%s}", tostring(v.x), tostring(v.y))
                else
                    text = tostring(v) .. ""
                end
                return v == v
            end)
            out[#out + 1] = plain and text or "secret"
        end
        return table.concat(out, ", ")
    end
    local function Ask(fn, ...)
        if not fn then return "absent" end
        return Shown(pcall(fn, ...))
    end

    local units = GroupUnits()
    if #units == 0 then
        Say("Range answers: not in a group, so there is nobody to measure.")
        return Keep()
    end
    local map = MapOf("player")
    Say("Range answers, your map %s, %s:", tostring(map),
        InCombat() and "in combat" or "out of combat")
    for _, unit in ipairs(units) do
        local okName, name = pcall(UnitName, unit)
        local plain = okName and pcall(function() return name == name end)
        local yards = DistanceTo(unit)
        Say("  |cffffd100%s|r %s: counted %s, distance %s", unit,
            plain and tostring(name) or "?", tostring(Reachable(unit)),
            yards and string.format("%.0f yd", yards) or "unknown")
        Say("    UnitInRange %s | UnitIsVisible %s | map %s",
            Ask(UnitInRange, unit), Ask(UnitIsVisible, unit), tostring(MapOf(unit)))
        Say("    UnitDistanceSquared %s | UnitPosition %s",
            Ask(UnitDistanceSquared, unit), Ask(UnitPosition, unit))
        Say("    map position %s | CheckInteractDistance(4) %s",
            map and Ask(C_Map and C_Map.GetPlayerMapPosition, map, unit) or "no map",
            Ask(CheckInteractDistance, unit, 4))
    end
    Keep()
end

--- Everything this build will say about tracking, printed once.
--
-- The measuring half of the feature, and it answered the phase: which of the
-- C_Minimap calls are really there, how many slots exist, what the call
-- returns, and what this build calls each id in Data/Tracking.lua. Two of the
-- three ids were confirmed that way and the third is still waiting for a
-- Dwarf.
--
-- What it is for now is the other question, the one somebody has when no icon
-- appears. Four separate things make this feature go quiet on purpose, and
-- every one of them looks the same from outside: not ticked, not trained, no
-- slot found, already running. The block at the end says which.
--
-- Not scaffolding, and it does not come out before the release. It writes
-- nothing on its own and says nothing unless it is asked: the tracking
-- equivalent of `/fplus buffs weapon`, which earned its keep the same way.
function M:TrackingStatus()
    local lines = {}
    local function Say(fmt, ...)
        local text = string.format(fmt, ...)
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffffff" .. text .. "|r")
        lines[#lines + 1] = (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    end

    --- Any value from the client, made safe to print.
    local function Describe(value)
        local ok, text = pcall(tostring, value)
        if not ok then return "|cffff5555<unreadable>|r" end
        if not pcall(function() return text == "" end) then
            return "|cffff5555<secret>|r"
        end
        return text
    end

    --- A table the client returned, opened and printed key by key.
    --
    -- `tostring` on one says `table: 0000023652C839C0`, and that is exactly
    -- what the first round of this printed, twenty four times, while the whole
    -- answer sat one dereference away. A dump exists to show a shape nobody
    -- has seen; stringifying the shape is not showing it.
    local function Open(value)
        local keys = {}
        pcall(function()
            for key in pairs(value) do
                if type(key) == "string" then keys[#keys + 1] = key end
            end
        end)
        if #keys == 0 then return "|cffff5555a table with no readable keys|r" end

        table.sort(keys)
        local parts = {}
        for _, key in ipairs(keys) do
            parts[#parts + 1] = key .. "=" .. Describe(Field(value, key))
        end
        return table.concat(parts, "  ")
    end

    FP:Print("Tracking, and what this build says about it:")

    -- Asked again rather than trusted: this command is reachable while the
    -- module is switched off, and then the table it reads was last filled at
    -- login or never.
    FP:Safe("BuffExpiry:RefreshKnown", M.RefreshKnown, self)

    local api = _G.C_Minimap
    Say("%-28s %s", "C_Minimap", type(api) == "table" and "present" or "absent")
    for _, name in ipairs({ "GetNumTrackingTypes", "GetTrackingInfo", "SetTracking" }) do
        local inNamespace = type(api) == "table" and type(api[name]) == "function"
        local asGlobal    = type(_G[name]) == "function"
        Say("      %-24s %s", name,
            (inNamespace and "C_Minimap" or "")
            .. ((inNamespace and asGlobal) and " and " or "")
            .. (asGlobal and "global" or "")
            .. ((inNamespace or asGlobal) and "" or "|cffff5555nowhere|r"))
    end

    local count, info = TrackingReaders()
    if not count then
        Say("%s", "no reader at all, so this feature can never say anything here")
        FP.global.trackingCheck = { stamp = date("%Y-%m-%d %H:%M:%S"), lines = lines }
        return
    end

    local ok, total = pcall(count)
    if not ok or type(total) ~= "number" then
        Say("%-28s %s", "how many tracking types", "the call raised")
        FP.global.trackingCheck = { stamp = date("%Y-%m-%d %H:%M:%S"), lines = lines }
        return
    end
    Say("%-28s %d", "how many tracking types", total)

    -- Every return of every slot, opened where it is a table.
    --
    -- **Measured 2026-09-21: one table per slot**, rather than the five loose
    -- values Classic returns. Both shapes are still printed, because a build
    -- that moved once can move again, and the loose one costs three lines here.
    Say("%s", "every slot, every value it returns:")
    for index = 1, total do
        local returns = select("#", pcall(info, index)) - 1
        local packed  = { pcall(info, index) }
        if not packed[1] then
            Say("      [%d] |cffff5555raised|r", index)
        elseif returns == 1 and type(packed[2]) == "table" then
            Say("      [%d] %s", index, Open(packed[2]))
        else
            local parts = {}
            for at = 2, returns + 1 do
                parts[#parts + 1] = (at - 1) .. "=" .. Describe(packed[at])
            end
            Say("      [%d] %s", index, table.concat(parts, "  "))
        end
    end

    FP:Safe("BuffExpiry:ScanTracking", M.ScanTracking, self, true)
    local state = self.trackState

    Say("%-28s %d on now, %d of them a spell, %d at once at most",
        "slots switched on", state.active or 0, state.spells or 0,
        state.most or 0)
    if (state.most or 0) > 1 then
        Say("      %s", "several at once, so nothing here cancels anything else")
    else
        Say("      %s", "never two at once so far. Switch one on while another "
            .. "is on and run this again: that is the whole test")
    end
    -- The second number is the one that matters, and the first is why: most of
    -- this list is minimap filters rather than anything the player hunts for,
    -- and several of those are on permanently.
    if (state.active or 0) > 0 and (state.spells or 0) == 0 then
        Say("      %s", "everything on is a filter rather than a tracking spell")
    end

    -- Every entry held against the client, and every reason it could be
    -- silent. Each of these fails quietly by design, so this is the only place
    -- the difference between "not wanted", "not trained", "not found" and
    -- "already running" is visible at all.
    for _, entry in ipairs(FP.trackingTypes or {}) do
        local name = FP:SpellName(entry.spell)
        Say("%-28s %s", entry.label .. " (" .. entry.spell .. ")",
            name and ("this client calls it " .. name)
                 or "|cffff5555this client does not know that id|r")
        Say("      %-22s %s", "you want it",
            self:TrackingWanted(entry) and "ticked" or "not ticked, so it is never mentioned")
        Say("      %-22s %s", "you know it", known[entry.spell] and "yes"
            or "no, so nothing is ever shown for it")

        local slot, how = state.slot[entry.id], state.how[entry.id]
        if not slot then
            Say("      %-22s %s", "which slot", "|cffff5555none matched|r")
        else
            Say("      %-22s %d, matched by %s, %s", "which slot", slot.index,
                tostring(how), slot.active == true and "on" or "off")
        end
    end

    -- And the verdict, per group, which is what the display is drawn from.
    --
    -- The dump reads the slots even in a fight, because it was asked to and
    -- because a measurement that refuses to measure is worthless. The verdict
    -- below still has to report what the *display* does, and the display looks
    -- at neither, so the two say different things here on purpose.
    local warnings = self:TrackingWarnings()
    if InCombat() or (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) then
        Say("%-28s %s", "on screen right now",
            "nothing: in combat or dead, where this is neither read nor shown. "
            .. "The slot lines above are from the read this command just did")
    elseif #warnings == 0 then
        Say("%-28s %s", "on screen right now", self.db.tracking == false
            and "nothing: tracking warnings are switched off"
            or  "nothing, so everything you ticked is either running or "
                .. "outside what this character can do")
    else
        for _, item in ipairs(warnings) do
            Say("%-28s %s", "on screen right now",
                tostring(item.tracking.label) .. ", or whatever else is in its group")
        end
    end

    FP.global.trackingCheck = { stamp = date("%Y-%m-%d %H:%M:%S"), lines = lines }
    FP:Print("Written to the saved file as well. One /reload and it is on disk.")
end

function M:Status()
    local class = ClassToken()
    -- The race token is here rather than hidden, and it earns the two words: a
    -- racial entry matches on it, an entry that names the wrong token is
    -- silently never shown, and this is the one line where the client says
    -- which token it actually uses for this character.
    local race = RaceOf()
    FP:Print("BuffExpiry for %s (%s): short buffs warn at %s, long ones at %s. "
        .. "In combat nothing is read; the countdown runs on what was last "
        .. "seen out of it.",
        tostring(class), tostring(race),
        Duration(self.db.warnShort), Duration(self.db.warnLong))

    -- When the display and the world disagree, this is the first number to
    -- look at. Nothing is read in combat, so the times on screen come from
    -- whenever this last succeeded, and a long gap explains a display that
    -- otherwise looks like nonsense.
    if self.scannedAt then
        local age = math.floor(GetTime() - self.scannedAt)
        if answering == false then
            DEFAULT_CHAT_FRAME:AddMessage("  |cffff5555The client refuses aura "
                .. "reads right now, so buffs from others are not shown.|r")
        end
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "  |cff888888Last successful read: %ds ago.%s|r", age,
            (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player"))
                and " Dead, so nothing is shown." or ""))
    else
        DEFAULT_CHAT_FRAME:AddMessage("  |cffff5555Nothing has been read yet, "
            .. "so nothing is shown at all.|r")
    end

    -- One line for tracking, which lives on this page and is not a buff, so
    -- it never appears in the list below. The long version is
    -- /fplus buffs tracking.
    if self.db.tracking == false then
        DEFAULT_CHAT_FRAME:AddMessage("  |cff888888Tracking: off.|r")
    elseif InCombat() or (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) then
        -- Says nothing rather than saying what it last knew. Neither state
        -- reads the slots, so "everything you picked is running" would be a
        -- claim about a minute ago dressed as one about now.
        DEFAULT_CHAT_FRAME:AddMessage("  |cff888888Tracking: not read in "
            .. "combat or while dead, and nothing is shown there either.|r")
    else
        local missing = {}
        for _, item in ipairs(self:TrackingWarnings()) do
            missing[#missing + 1] = tostring(item.tracking.label)
        end

        local usable = 0
        for _, entry in ipairs(FP.trackingTypes or {}) do
            if self:TrackingWanted(entry) and self:TrackingUsable(entry) then
                usable = usable + 1
            end
        end

        DEFAULT_CHAT_FRAME:AddMessage("  |cff888888Tracking: "
            .. (#missing > 0 and (table.concat(missing, " and ") .. " not running")
                or usable > 0 and "everything you picked is running"
                or "nothing picked that this character can do")
            .. ".|r")
    end

    local rows = self:Inspect()
    if #rows == 0 then
        return FP:Print("|cff888888No buffs are tracked for this class.|r")
    end

    -- Says which question the group count is answering. Without this the
    -- number is ambiguous: "missing mine" and "missing any" are different
    -- claims and the client decides which one is available.
    for _, row in ipairs(rows) do
        if row.entry and row.entry.perCaster then
            DEFAULT_CHAT_FRAME:AddMessage(self.knowsSource
                and "  |cff888888Blessings: counting who is missing yours.|r"
                or  "  |cff888888Blessings: this client does not say who cast "
                    .. "an aura, so the count is of who has none at all.|r")
            break
        end
    end

    for _, row in ipairs(rows) do
        local timing = ""
        if row.remaining and row.remaining > 0 then
            timing = string.format(" %s of %s",
                FP:FormatTime(row.remaining), FP:FormatTime(row.duration or 0))
        end
        local others = ""
        if (row.waiting or 0) > 0 then
            others = string.format(" |cff4499ff(%d near you missing)|r", row.waiting)
        elseif row.fromOthers then
            others = string.format(" |cff4499ff(from a %s in your group)|r",
                tostring(row.fromOthers):lower())
        end
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "  |cffffffff%-24s|r %s%s%s",
            tostring(row.name), WORDING[row.verdict] or row.verdict,
            timing, others))
    end
end

function M:OnEnable()
    self:CarryOverTargets()

    self:RefreshKnown()

    -- The camp's thirty objects by name, asked for now so that they are there
    -- before the first look at Camp Benefits.
    FP:Safe("BuffExpiry:CampNames", CampNames)

    -- What the measurement wrote leaves the saved file once it is off, so a
    -- finished one does not stay there for good.
    if not COLLECTING and type(FP.global) == "table" then
        FP.global.auraReads = nil
    end

    self.watcher = self.watcher or CreateFrame("Frame")
    self.watcher:SetScript("OnEvent", function(_, event, unit, second, spellId, fourth, fifth)
        if event == "SPELLS_CHANGED" or event == "PLAYER_LEVEL_UP"
           or event == "PLAYER_ENTERING_WORLD" then
            -- A trip to the trainer changes what counts as missing and what
            -- counts as a rank behind. Not every class has its buffs at level
            -- one, and several of them are talents, so this is the normal case
            -- rather than an edge one.
            --
            -- Falls through to the update below rather than returning: the
            -- ticker would catch it within a second, but only if there is a
            -- ticker, and the module is built to survive C_Timer being absent.
            FP:Safe("BuffExpiry:RefreshKnown", M.RefreshKnown, M)

            -- The tracking rows say "not trained" when this character cannot
            -- use one, and that answer has just moved. The page repaints
            -- itself whenever somebody looks at it, which covers every case
            -- but one: the window standing open at the trainer while the
            -- profession is learned. Here rather than on the ticker, because
            -- this is the moment it changes and the ticker is once a second.
            local menu = _G.ForeverPlusMenu
            if menu and menu:IsShown() then
                FP:Safe("BuffExpiry:RefreshPicker", RefreshPicker)
            end
        end

        if event == "UNIT_COMBAT" then
            -- A hit on the player, for the counted buffs: action, flag,
            -- amount and school, "WOUND" for a hit that landed. The third
            -- argument is named for the cast events and is the flag here.
            -- On any unit, a crit that may have been the player's own spell,
            -- for Water Shield.
            FP:Safe("BuffExpiry:NoteCritSign", M.NoteCritSign, M, unit, second,
                    spellId, fifth)
            if unit ~= "player" then return end
            FP:Safe("BuffExpiry:NoteHit", M.NoteHit, M, second, spellId, fourth, fifth)

        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            -- The only update the client gives us in combat, and the reason a
            -- missing self buff may be shown during a fight at all.
            if unit ~= "player" then return end
            FP:Safe("BuffExpiry:NoteCast", M.NoteCast, M, spellId)
            FP:Safe("BuffExpiry:NoteWeaponCast", M.NoteWeaponCast, M, spellId)

        elseif event == "UNIT_SPELLCAST_SENT" then
            -- Unit, target, cast guid and spell id, so the spell comes fourth.
            -- Nothing on screen changes yet, so no update: see NoteWeaponSent.
            if unit == "player" then
                FP:Safe("BuffExpiry:NoteWeaponSent", M.NoteWeaponSent, M, fourth)
            end
            return

        elseif event == "UNIT_AURA" and unit ~= "player" then
            return
        end

        FP:Safe("BuffExpiry:Update", M.Update, M)
    end)

    -- UNIT_AURA carries nothing usable in combat on this build, but it still
    -- fires, and out of combat it is the cheapest signal that a rescan is
    -- worth doing.
    self.watcher:RegisterEvent("UNIT_AURA")
    self.watcher:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    -- Every hit on the player, which is what the Shaman shields are counted
    -- down by. Plain values inside the lockdown, measured 2026-09-27.
    self.watcher:RegisterEvent("UNIT_COMBAT")
    self.watcher:RegisterEvent("SPELLS_CHANGED")
    self.watcher:RegisterEvent("PLAYER_LEVEL_UP")
    -- Belt and braces. The spellbook is readable by PLAYER_LOGIN, when this
    -- module is enabled, but the first RefreshKnown happens before any of
    -- these are registered and a spellbook that was not ready yet would leave
    -- every buff looking untrained until the next trainer visit.
    self.watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    -- Leaving combat is the first moment the client will answer again, so it
    -- is the first moment anything can be corrected.
    self.watcher:RegisterEvent("PLAYER_REGEN_ENABLED")

    -- The one the tracking warning runs on, and it goes through the guarded
    -- registration rather than the lines above. RegisterEvent raises on an
    -- event this build does not know, which would take the rest of OnEnable
    -- down with it, and this is a name nobody had tried here. Losing it costs
    -- nothing worse than the icon appearing or clearing on the next tick
    -- rather than instantly, and the warning says it was refused rather than
    -- leaving that to be blamed on the feature.
    FP:RegisterEvents(self.watcher, {
        MINIMAP_UPDATE_TRACKING = true,
    }, "BuffExpiry")

    -- The pet's mood changing, and the pet itself coming or going. Guarded
    -- like the line above; the ticker would catch either within a second.
    FP:RegisterEvents(self.watcher, {
        UNIT_HAPPINESS = true,
        UNIT_PET = true,
    }, "BuffExpiry")

    -- Guarded for the same reason, and only for a class that puts its own
    -- buff on a weapon: it is what lets a cast teach a weapon line its place.
    if next(WeaponCasts()) then
        FP:RegisterEvents(self.watcher, {
            UNIT_SPELLCAST_SENT = true,
        }, "BuffExpiry")
    end

    -- UNIT_AURA fires when auras change, not while they tick down, so the
    -- countdown needs its own beat.
    if C_Timer and C_Timer.NewTicker then
        self.ticker = self.ticker or C_Timer.NewTicker(TICK, function()
            FP:Safe("BuffExpiry:Update", M.Update, M)
        end)
    else
        -- Without a ticker the icon would still appear, but the countdown
        -- would freeze and it would linger after the buff is gone.
        FP:Warn(L["BuffExpiry: C_Timer.NewTicker is missing, so the countdown "
              .. "only updates when a buff changes."])
    end

    self:Update()
end

--- Settings changed while the module stays on.
--
-- Nothing to rebuild: the bars read their settings on every draw, so one
-- update is the whole job.
function M:Reapply()
    -- A profile switched to may still hold the older meaning of the tick.
    self:CarryOverTargets()
    FP:Safe("BuffExpiry:Update", M.Update, M)
end

function M:OnDisable()
    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end
    if self.watcher then self.watcher:UnregisterAllEvents() end
    -- Only this page's icons leave the bars; the Consumables page keeps its own
    -- on a bar the two share.
    FP:HandIn("buffs", {})
end

-- ---------------------------------------------------------------------------
-- The list of buffs on you right now
--
-- Every timed buff with the verdict on it, shown underneath the module's
-- options. It answers the one question the settings cannot: "why did my
-- warning not appear?" -- too short, not yet, or showing.
--
-- This list is the reason BuffExpiry had a page of its own for so long. It is
-- not a setting, and an option framework that can only render settings has
-- nowhere to put it. The `custom` entry is that nowhere.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- The spells behind a row, in the game's own tooltip
--
-- Asked for by the owner on 2026-09-26: a row on this page names a spell, so
-- hovering it names it in the game's tooltip. Blizzard's design on purpose, by
-- the owner's rule of the same day: a tooltip that shows one of the game's own
-- objects stays the game's.
--
-- **One line per buff, and nothing more**, which took three steps the same
-- afternoon. It began as the game's full spell card. That described one buff
-- out of four for an entry that covers several, the Hunter's aspects, the
-- Paladin's seals and blessings, so those became a list of every buff the entry
-- tracks, each once at its best rank. The rank came off the list at the
-- owner's word, and then the owner asked for every row to look like that list:
-- a row for one buff is a single line of icon and name, a row for several is
-- the entry's name over one such line per buff. **The list of buffs on you
-- right now is the one exception** and keeps the game's full card for the
-- buff you are wearing, also at the owner's word.
-- ---------------------------------------------------------------------------

--- The best rank of each buff an entry covers, one spell per name.
--
-- By name rather than by line, asked for by the owner on 2026-09-28. A line of
-- ranks can change its name on the way up: Frost Armor becomes Ice Armor, Demon
-- Skin becomes Demon Armor, a blessing gains its Greater version. A player on
-- CurseForge read only "Frost Armor" on the Mage's row and asked for Ice Armor
-- to be added, which had been there all along; now the hover says so. The names
-- are the client's own and are only compared with each other, so the locale
-- rule holds.
--
-- For each name, the best rank this character knows, which is the one they
-- would cast; else the highest rank under that name. In the order the line
-- reaches them, which is the order they are learned.
local function BestOfEachName(entry)
    local out = {}
    for _, line in ipairs(entry.lines or {}) do
        local order, best, top = {}, {}, {}
        for _, id in ipairs(line) do
            -- An id the client cannot name stands on its own and draws nothing.
            local name = FP:SpellName(id) or id
            if top[name] == nil then order[#order + 1] = name end
            top[name] = id
            if known[id] then best[name] = id end
        end
        for _, name in ipairs(order) do
            out[#out + 1] = best[name] or top[name]
        end
    end
    return out
end

--- The spells a row stands for, as a list.
--
-- One, where the row is about one: the buff actually on the player, when the
-- list of buffs on you knows which it is, or one caster's variant, a blessing
-- say. Otherwise one per buff the entry covers. Empty for a weapon entry,
-- which stands for a slot rather than for a spell.
local function SpellsForRow(entry, variant, active)
    if active then return { active } end
    if type(entry) ~= "table" then return {} end
    local ranks = variant and entry.byVariant and entry.byVariant[variant]
    if ranks and ranks.ids then
        for index = #ranks.ids, 1, -1 do
            if known[ranks.ids[index]] then return { ranks.ids[index] } end
        end
        return { ranks.ids[#ranks.ids] }
    end
    return BestOfEachName(entry)
end

--- The game's full card for one spell. False when the client draws none.
local function ShowSpellCard(owner, spell)
    if not (spell and GameTooltip and GameTooltip.SetSpellByID) then return false end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if pcall(GameTooltip.SetSpellByID, GameTooltip, spell)
       and GameTooltip:NumLines() > 0 then
        GameTooltip:Show()
        return true
    end
    GameTooltip:Hide()
    return false
end

local function SpellLine(id)
    local name = FP:SpellName(id)
    if not name then return nil end
    local icon = FP:SpellIcon(id)
    return (icon and string.format("|T%s:14:14:0:0|t ", tostring(icon)) or "") .. name
end

--- Names the spells in the game's tooltip, one line each: icon and name.
--
-- One spell is one line and nothing else. Several stand under the entry's own
-- name, which is what they have in common. No rank, by the owner's word: which
-- rank is picked still decides the spell behind each line, see BestOfEachName,
-- but saying it is not what the tooltip is for.
local function ShowSpellLines(owner, title, spells)
    if not GameTooltip then return false end
    local lines = {}
    for _, id in ipairs(spells) do
        local line = SpellLine(id)
        if line then lines[#lines + 1] = line end
    end
    if #lines == 0 then return false end

    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if #lines == 1 then
        GameTooltip:SetText(lines[1], 1, 1, 1)
    else
        GameTooltip:SetText(title or "", 1, 1, 1)
        for _, line in ipairs(lines) do GameTooltip:AddLine(line, 1, 1, 1) end
    end
    GameTooltip:Show()
    return true
end

--- Hangs the spells behind a row on it.
--
-- Both arguments are asked when the pointer arrives rather than when the row
-- is built: a rank learned during the session changes the answer, and a row in
-- the list of buffs on you holds a different buff from one refresh to the next.
--
-- `fullCard` keeps the game's whole card for a row that stands for one spell:
-- the list of buffs on you right now, which is the one exception to the
-- lines.
local function AttachSpellCard(row, spellsOf, titleOf, fullCard)
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        local ok, spells = pcall(spellsOf)
        if not ok or type(spells) ~= "table" or #spells == 0 then return end
        if fullCard and #spells == 1 and ShowSpellCard(self, spells[1]) then
            return
        end
        local title = type(titleOf) == "function" and titleOf() or titleOf
        ShowSpellLines(self, title, spells)
    end)
    row:SetScript("OnLeave", function(self)
        if GameTooltip and GameTooltip:GetOwner() == self then GameTooltip:Hide() end
    end)
end

local MAX_LIST_ROWS = 12
local LIST_ROW_H    = 19

--- How tall the list has to be for a given number of rows.
--
-- It used to reserve all twelve whether or not there were twelve buffs, on the
-- grounds that a list which grew and shrank would resize the window. It does
-- not: the window is sized to its tallest page and the page scrolls, so all the
-- reservation ever bought was a screenful of empty space.
--
-- The height is only put into effect when the page lays out -- on opening,
-- closing or searching -- and not on every tick. A list that re-flowed once a
-- second would move the rows under the pointer.
local function ListHeight(shown)
    return math.max(shown, 1) * LIST_ROW_H + 32
end

-- What each verdict reads as in the list. The verdict itself is an identity
-- the code compares, and stays English; only this is shown. "unknown" reads
-- as unavailable since 2026-10-07, the owner's word after the Russian review:
-- it is set for a spell not trained, for a blessing no Paladin present can
-- give, and for a hand holding nothing an imbue can take, and "unknown" only
-- named the first.
local VERDICT_TEXT = {
    missing = L["missing"], upgrade = L["upgrade"], showing = L["showing"],
    handout = L["handout"], waiting = L["waiting"], unknown = L["unavailable"],
    off = L["off"],
}

local VERDICT_COLOR = {
    missing = { 0.95, 0.35, 0.35 },   -- you can cast it and it is not on you
    upgrade = { 1.00, 0.70, 0.10 },   -- a better rank is trained
    showing = { 0.30, 0.85, 0.45 },   -- on screen at this moment
    handout = { 0.30, 0.60, 1.00 },   -- you have it, somebody near you does not
    waiting = { 0.60, 0.60, 0.65 },   -- watched, but not in the window yet
    unknown = { 0.45, 0.45, 0.50 },   -- nothing to cast it with
    off     = { 0.45, 0.45, 0.50 },   -- switched off by hand
}

local function CreateListRow(parent, width)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(width - 4, LIST_ROW_H)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(14, 14)
    icon:SetPoint("LEFT")
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    row.icon = icon

    local name = FP:FontString(row, "OVERLAY", "body")
    name:SetPoint("LEFT", icon, "RIGHT", 7, 0)
    name:SetWidth(width * 0.52)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    row.name = name

    local timing = FP:FontString(row, "OVERLAY", "faint")
    timing:SetPoint("RIGHT")
    timing:SetJustifyH("RIGHT")
    row.timing = timing

    -- The buff's own full card on hover, the one exception to the lines;
    -- RefreshList says which buff the row holds.
    AttachSpellCard(row,
        function() return SpellsForRow(row.entry, row.variant, row.spell) end,
        function() return row.entry and (FP:T(row.entry.label) or row.entry.id) end,
        true)

    row:Hide()
    return row
end

--- Fills the list on the settings page from the same data the chat command
--- uses, so the two can never drift apart.
function RefreshList()
    if not M.listRows then return end

    local rows = M:Inspect()

    for index = 1, MAX_LIST_ROWS do
        local widget, entry = M.listRows[index], rows[index]
        widget.entry, widget.variant = entry and entry.entry, entry and entry.variant
        widget.spell = entry and entry.spell
        if not entry then
            widget:Hide()
        else
            widget.icon:SetTexture(entry.icon)
            widget.name:SetText(entry.name)
            widget.name:SetTextColor(unpack(
                VERDICT_COLOR[entry.verdict] or VERDICT_COLOR.waiting))
            -- Only a buff that is actually on you has a time to show.
            if entry.remaining and entry.remaining > 0 then
                widget.timing:SetText(L["%s of %s"]:format(
                    FP:FormatTime(entry.remaining), FP:FormatTime(entry.duration or 0)))
            else
                widget.timing:SetText(FP:T(VERDICT_TEXT[entry.verdict]) or entry.verdict)
            end
            widget:Show()
        end
    end

    -- More buffs than rows: say so rather than silently dropping the rest.
    if #rows > MAX_LIST_ROWS then
        local last = M.listRows[MAX_LIST_ROWS]
        last.entry, last.variant, last.spell = nil, nil, nil
        last.icon:SetTexture(nil)
        last.name:SetText(L["... and %d more"]:format(#rows - MAX_LIST_ROWS + 1))
        last.name:SetTextColor(0.6, 0.6, 0.65)
        last.timing:SetText("")
    end

    if M.listEmpty then M.listEmpty:SetShown(#rows == 0) end
    if M.listHolder and M.listHolder.Resize then
        M.listHolder:Resize(ListHeight(math.min(#rows, MAX_LIST_ROWS)))
    end

    -- The one genuinely surprising thing about this display, said where
    -- somebody is already looking at it rather than in a chat line nobody
    -- asked for.
    if M.listNote then
        if InCombatLockdown and InCombatLockdown() then
            M.listNote:SetText(L["In combat, these are the remaining times "
                .. "recorded just before the fight, continuing to count "
                .. "down. Buffs cast on you by other players appear after "
                .. "combat ends."])
        else
            M.listNote:SetText("")
        end
    end
end


--- Builds the list into the frame the option framework hands over.
--
-- A fixed number of rows, filled on every refresh. Reserving the space keeps
-- the height steady: a list that grew and shrank would move everything below
-- it in the module list every time a buff came or went.
--
-- @return the height the entry needs
function BuildList(holder, width)
    M.listHolder = holder
    M.listRows   = {}

    local previous
    for index = 1, MAX_LIST_ROWS do
        local row = CreateListRow(holder, width)
        if previous then
            row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, 0)
        else
            row:SetPoint("TOPLEFT", holder, "TOPLEFT", 2, 0)
        end
        M.listRows[index] = row
        previous = row
    end

    -- Sits where the first row would be, for when there are no rows to show.
    M.listEmpty = FP:FontString(holder, "OVERLAY", "faint")
    M.listEmpty:SetPoint("TOPLEFT", 2, -1)
    M.listEmpty:SetText(L["No timed buffs on you."])
    M.listEmpty:Hide()

    -- Shown and empty rather than hidden when there is nothing to report: a
    -- hidden string takes no room, so it would be cut off in the moment it
    -- first had something to say.
    -- Anchored to the bottom of the frame rather than under the last row: rows
    -- that are hidden still have a position, so anchoring to row twelve would
    -- leave the note stranded far below a list of three.
    M.listNote = FP:FontString(holder, "OVERLAY", "faint")
    M.listNote:SetPoint("BOTTOMLEFT", 2, 2)
    M.listNote:SetWidth(width - 4)
    M.listNote:SetJustifyH("LEFT")
    M.listNote:SetWordWrap(true)
    M.listNote:SetTextColor(1, 0.6, 0.2)
    M.listNote:SetHeight(26)

    RefreshList()
    return ListHeight(MAX_LIST_ROWS)
end

-- ---------------------------------------------------------------------------
-- The selection page
--
-- Every class, alphabetically, every buff under it, one switch each, under one
-- fixed heading that does not fold.
--
-- **Folded per class, except the one being played.** This said the opposite
-- until 2026-09-20, when the owner asked for the other arrangement: nine open
-- blocks is a page nobody reads to the end, and nine closed ones is a list of
-- tabs, so the one that concerns him starts open and the rest are a click.
--
-- The heading above them is a different element from the class blocks and not
-- the same one with a flag. A fixed heading divides the page; a block folds
-- away. Both were called a heading here for a while, and that alone cost a
-- round of misunderstanding.
--
-- Generated from Data/Buffs.lua rather than declared in the option schema.
-- These rows are not settings the module owns: they come out of the tables,
-- they change when the tables change, and writing thirty option entries by
-- hand would be a second description of something that already describes
-- itself.
-- ---------------------------------------------------------------------------

local PICK_ROW_H  = 22

--- The class's name in the client's language, and its color.
--
-- Both come from the game rather than from us: the token is what our tables
-- are keyed by, the name is what the player reads.
local function ClassLabel(token)
    local names = _G.LOCALIZED_CLASS_NAMES_MALE
    return (names and names[token]) or token
end

local function ClassColor(token)
    local colors = _G.RAID_CLASS_COLORS
    local c = colors and colors[token]
    if c then return c.r, c.g, c.b end
    return 0.80, 0.80, 0.85
end

--- What to call one entry on the page.
--
-- A single family takes the client's own name for its best rank, which is both
-- localized and the words the player sees on their own action bar. An entry
-- covering several alternatives takes our label instead: "Blessing" is the
-- honest description of five spells, and naming it after one of them would be
-- a lie about what the switch does.
local function EntryLabel(entry)
    if entry.kind ~= "weapon" and #(entry.lines or {}) == 1 then
        local line = entry.lines[1]
        local name = FP:SpellName(line[#line])
        if name then return name end
    end
    return FP:T(entry.label) or entry.id
end

--- A note marking a row that is tracked rather than warned about.
--
-- Asked for by the owner on 2026-09-22, in his words: the row should say that
-- these are personal trackers that only do something on the class that has
-- them. Two rows sitting in the same list doing opposite things is the case
-- this exists for, and a reader who has to switch one on to find out which it
-- is has been told nothing.
--
-- **"timer only" rather than "tracker"**, because it says what the switch does
-- instead of naming a mechanism: it shows a running time and it never says a
-- word about the buff being missing.
--
-- Shown in every class block rather than only in your own, unlike the race note
-- beside it, because this describes the entry and not the reader.
local function TrackerNote(entry)
    if not entry.tracker then return "" end
    return "  |cff888888" .. L["(timer only)"] .. "|r"
end

-- A note naming the lower display, "(Combat Buffs)", stood after every buff
-- drawn there from 2026-10-11, when a buff could not change displays. It went
-- with the redesign of 2026-10-15, the owner's word: the bar is chosen in each
-- buff's details since, so the note had nothing left to say.

--- A note on a row that only ever speaks to its own class.
--
-- Battle Shout, since 2026-09-27: nobody but a Warrior is told it is missing,
-- so in anybody else's copy of the Warrior block the switch does nothing, and
-- a row that does nothing without saying so reads as broken. Shown in every
-- block, like the timer note, because it describes the entry.
local function OwnClassNote(entry)
    if not entry.ownClassOnly then return "" end
    return "  |cff888888" .. L["(own class only)"] .. "|r"
end

--- What to call one tracking row.
--
-- The client's own name for the spell where it gives one, which is localized
-- and is the words on the player's own minimap button. Our own label is the
-- fallback for an id this build does not know, which is a real case rather
-- than a defensive one: Find Treasure is written from memory and wants a Dwarf
-- to check it.
--
-- The suffix is the profession gate made visible. A row can be ticked by
-- anybody and only ever does something for somebody who has learned the
-- spell, so a row that is going to stay silent says so rather than looking
-- broken later.
local function TrackingLabel(entry)
    local name = FP:SpellName(entry.spell) or FP:T(entry.label) or entry.id
    if known[entry.spell] then return name end
    return name .. "  |cff888888" .. L["(not trained)"] .. "|r"
end

--- A note on a row this character can never use, or nothing.
--
-- **Only in your own class block.** Everywhere else the whole block belongs to
-- somebody else, and pointing at one row inside it as not yours says nothing
-- the block does not already say. In your own it is the difference between a
-- switch you chose not to use and a switch that was never yours: the entry is
-- filtered out long before the warning, so ticking it does nothing at all, and
-- a row that does nothing without saying so reads as broken.
local function RaceNote(entry, own)
    if not own or not (entry.race or entry.raceId) then return "" end
    local token, id = RaceOf()
    if entry.race == token or entry.raceId == id then return "" end
    return "  |cff888888" .. L["(not your race)"] .. "|r"
end

--- Class tokens in the order the page shows them.
local function SortedClasses()
    local out = {}
    for class in pairs(FP.classBuffs or {}) do out[#out + 1] = class end
    table.sort(out)
    return out
end

-- Every frame on the picker in display order, so folding and laying out are a
-- single pass over one list.
--   { frame, height, indent, class = <token>, row = true }
local pickerEntries = {}

-- [class token] = true while that block is folded away. View state rather than
-- a setting: nobody configures which classes are open, and storing it would
-- put "Druid is closed" into every exported profile.
local pickerClosed = {}

-- [entry key] = true while an entry's details are open. View state as well,
-- for the same reason.
local detailsOpen = {}

--- Whether a warning time means anything for an entry: one that warns before
--- it runs out, or a group buff, whose count of players missing it uses the
--- time too. A permanent aura, the pet's mood and a countdown that never warns
--- have none, the owner's word of round 5.
local function Timed(entry)
    if entry.kind == "group" then return true end
    if entry.kind ~= "self" and entry.kind ~= "weapon" then return false end
    return not entry.tracker and entry.warns ~= false
end

--- The page's time for an entry right now, for its details while it follows
--- the page: the buff's own length decides which of the three, and a buff never
--- seen is taken for a long one, which is what most of them are.
function M:InheritedWarn(class, entry)
    local duration
    if class == ClassToken() then
        local state = self.seen[entry.id]
        duration = state and (state.duration or 0) > 0 and state.duration or nil
    end
    duration = duration or entry.duration or MEDIUM_BUFF
    return WarnWindow(duration)
end

--- Every entry of this character that is switched on, with its factory bar,
--- for the counts in bar management.
function M:BarEntries()
    local out = {}
    local class, entries = ClassEntries()
    for _, entry in ipairs(entries) do
        if not KindOff(entry) and not self:BuffOff(class, entry) then
            out[#out + 1] = { key = EntryKey(class, entry), factory = FactoryBar(entry) }
        end
    end
    for _, entry in ipairs(FP.trackingTypes or {}) do
        if self.db.tracking ~= false and self:TrackingWanted(entry) then
            out[#out + 1] = { key = "buffs:track/" .. tostring(entry.id), factory = "general" }
        end
    end
    return out
end

--- The page's three warning times back to their defaults, for restoring the
--- default setup with its box for warning times ticked.
function M:ResetWarningTimes()
    local defaults = FP:OptionDefaults(self)
    self.db.warnShort  = defaults.warnShort
    self.db.warnMedium = defaults.warnMedium
    self.db.warnLong   = defaults.warnLong
end

function RefreshPicker()
    FP:RefreshBarValues()
    for _, entry in ipairs(pickerEntries) do
        if entry.frame.Refresh then entry.frame:Refresh() end
    end
end

--- Places the picker and sizes it to what is showing.
--
-- Positions against the holder with a running offset instead of chaining each
-- row to the one above it. **A chain cannot skip a hidden row**: a hidden frame
-- keeps its anchors and its place, so folding a class away would leave exactly
-- the gap it used to fill.
local function LayoutPicker(holder)
    local y = -2
    for _, entry in ipairs(pickerEntries) do
        -- `hidden` is asked every time rather than stored, because it answers
        -- to a switch the player can flip while looking at this page.
        if entry.row and (pickerClosed[entry.class]
                          or (entry.hidden and entry.hidden())) then
            entry.frame:Hide()
        else
            entry.frame:ClearAllPoints()
            entry.frame:SetPoint("TOPLEFT", holder, "TOPLEFT", entry.indent, y)
            entry.frame:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -2, y)
            entry.frame:Show()
            y = y - entry.height
        end
    end

    local height = math.max(-y + 8, 1)
    holder:SetHeight(height)
    -- Set by the menu on a custom option that declares liveHeight. Absent while
    -- the page is still being built, which is why it is asked for rather than
    -- assumed.
    if holder.OnResized then holder.OnResized() end
    return height
end

--- An icon and a name as one line of the game's tooltip, or nil.
local function IconLine(icon, name)
    if not name then return nil end
    return (icon and string.format("|T%s:14:14:0:0|t ", tostring(icon)) or "") .. name
end

--- The hover of a camp bonus, in the game's tooltip since it shows the game's
--- spells and items: what the tick does, the bonus itself where the client
--- names it, the objects that give it, and the class buffs that replace it.
--
-- The owner asked for the buff to be seen in the hover, and for one tick to
-- cover every version of it: the three objects are those versions.
--
-- `campName` is what the row above calls Camp Benefits, the client's own name
-- for it where it gives one, so the hover and the row cannot disagree on a
-- client in another language.
local function ShowCampCard(owner, bonus, reason, campName)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(FP:T(bonus.label) or bonus.id, 1, 1, 1)
    GameTooltip:AddLine(L["Warns when neither this bonus nor a replacement "
        .. "class buff is active. If no bonuses are selected, tracks %s "
        .. "itself."]:format(campName or L["Camp Benefits"]), 1, 0.82, 0, true)
    local buff = SpellLine(bonus.spell)
    if buff then GameTooltip:AddLine(buff, 1, 1, 1) end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["Given by these camp objects:"], 0.6, 0.6, 0.6)
    local iconOf = C_Item and C_Item.GetItemIconByID
    for _, item in ipairs(bonus.objects or {}) do
        local icon
        if iconOf then
            local ok, found = pcall(iconOf, item)
            icon = ok and found or nil
        end
        local line = IconLine(icon, ItemName(item))
        if line then GameTooltip:AddLine(line, 1, 1, 1) end
    end

    -- One line per name, the best rank this character knows, as on every
    -- buff row: Blessing of Wisdom and Greater Blessing of Wisdom, say.
    local counter = BestOfEachName({ lines = { FP:CampCounterparts(bonus) } })
    local shown = {}
    for _, id in ipairs(counter) do
        local line = SpellLine(id)
        if line then shown[#shown + 1] = line end
    end
    if #shown > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["These class buffs also count:"],
            0.6, 0.6, 0.6)
        for _, line in ipairs(shown) do GameTooltip:AddLine(line, 1, 1, 1) end
    end

    if reason then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(reason, 1, 0.82, 0, true)
    end
    GameTooltip:Show()
end

--- The bonuses a camp can give, a tick each under Camp Benefits.
--
-- Rows that qualify the one above, so they are grayed out and locked while
-- Camp Benefits is off, like every such row on the page, and shown with its
-- details. Three at most: with three ticked the rest are grayed out as well,
-- and hovering one lights up the ticks that used them up.
local function BuildCampRows(holder, entry, master, hidden)
    local campRows = {}
    local NOT_IN_USE = L["Not in use until another setting here allows it."]

    for _, bonus in ipairs(FP.campBonuses or {}) do
        local this = bonus
        local function Untracked() return M:BuffOff("ALL", entry) end
        local function Full()
            return not M:CampWanted(ClassToken(), this) and M:CampFull(ClassToken())
        end
        local function Blocked() return Untracked() or Full() end

        local row = FP:CreateToggle(holder, FP:T(this.label) or this.id,
            function() return M:CampWanted(ClassToken(), this) end,
            function(value)
                if Blocked() then return end
                M:SetCampWanted(ClassToken(), this, value)
                RefreshPicker()
                FP:Safe("BuffExpiry:Update", M.Update, M)
            end)
        row:SetHeight(PICK_ROW_H)

        local paint = row.Refresh
        row.Refresh = function(self, ...)
            if paint then paint(self, ...) end
            self:SetAlpha(Blocked() and 0.4 or 1)
        end
        row:Refresh()

        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            local reason
            if Untracked() then
                reason = NOT_IN_USE
            elseif Full() then
                reason = L["Select up to three bonuses, the most you can "
                    .. "have at once."]
            end
            ShowCampCard(self, this, reason, EntryLabel(entry))
        end)
        row:SetScript("OnLeave", function(self)
            if GameTooltip and GameTooltip:GetOwner() == self then GameTooltip:Hide() end
        end)
        FP:PointAtCause(row, Blocked, function()
            if Untracked() then return { master } end
            local out = {}
            for _, other in ipairs(campRows) do
                if M:CampWanted(ClassToken(), other.bonus) then
                    out[#out + 1] = other.frame
                end
            end
            return out
        end)

        campRows[#campRows + 1] = { frame = row, bonus = this }
        pickerEntries[#pickerEntries + 1] =
            { frame = row, height = PICK_ROW_H, indent = 26, row = true, hidden = hidden }
    end
end

--- The section of buffs that belong to no class: a fixed heading, and a row
--- per buff with its tick and the game's own card on hover.
local function BuildSharedRows(holder)
    if #(FP.sharedBuffs or {}) == 0 then return end
    local heading, headingHeight = FP:SectionHeading(holder, L["Buffs for "
                                                          .. "All Classes"])
    pickerEntries[#pickerEntries + 1] =
        { frame = heading, height = headingHeight, indent = 2 }

    for _, entry in ipairs(FP.sharedBuffs) do
        local item = entry
        local row = FP:CreateToggle(holder, EntryLabel(item),
            function() return not M:BuffOff("ALL", item) end,
            function(value)
                M:SetBuffOff("ALL", item, not value)
                RefreshPicker()
                FP:Safe("BuffExpiry:Update", M.Update, M)
            end)
        row:SetHeight(PICK_ROW_H)
        AttachSpellCard(row, function() return SpellsForRow(item) end,
            EntryLabel(item))
        pickerEntries[#pickerEntries + 1] =
            { frame = row, height = PICK_ROW_H, indent = 14 }
        M.pickerRows[#M.pickerRows + 1] = row

        -- Details like a class buff's: its bar and its own warning time.
        local key, factory = EntryKey("ALL", item), FactoryBar(item)
        local function Shut() return not detailsOpen[key] end
        FP:MakeEntryRow(row, {
            key = key, factory = factory,
            isOpen = function() return detailsOpen[key] == true end,
            toggle = function() detailsOpen[key] = not detailsOpen[key] end,
            onToggled = function() LayoutPicker(holder) end,
        })
        if row.boxHit then
            AttachSpellCard(row.boxHit, function() return SpellsForRow(item) end,
                EntryLabel(item))
        end
        for _, detail in ipairs(FP:EntryDetails(holder, {
            key = key, factory = factory, timed = Timed(item),
            inherited = function() return M:InheritedWarn("ALL", item) end,
            blocked = function() return M:BuffOff("ALL", item) end,
            causes = function() return { row } end,
            changed = function()
                RefreshPicker()
                FP:Safe("BuffExpiry:Update", M.Update, M)
            end,
        })) do
            pickerEntries[#pickerEntries + 1] = {
                frame = detail, height = detail.rowHeight, indent = 26,
                row = true, hidden = Shut,
            }
        end

        -- What the camp gives, inside the same details: the ticks are this
        -- entry's own, like everything else in there.
        if item.camp then BuildCampRows(holder, item, row, Shut) end
    end
end

function BuildPicker(holder, width)
    M.pickerRows = {}
    pickerEntries = {}

    local mine = ClassToken()

    -- The buffs of no class, above the class blocks, the owner's word of
    -- 2026-10-15. A section of their own, since they belong to every class.
    BuildSharedRows(holder)

    -- One fixed heading over the lot. It divides the page; it does not fold.
    local heading, headingHeight = FP:SectionHeading(holder, L["Class Buffs"])
    pickerEntries[#pickerEntries + 1] =
        { frame = heading, height = headingHeight, indent = 2 }

    for _, class in ipairs(SortedClasses()) do
        -- Folded unless it is the class being played, and only decided once:
        -- reopening the window must not shut what the player just opened.
        if pickerClosed[class] == nil then
            pickerClosed[class] = (class ~= mine)
        end

        -- A local of its own. `class` is the loop variable, and every closure
        -- below would otherwise read whatever it holds at the end.
        local token = class

        local head, headHeight = FP:CollapsibleHeading(holder,
            ClassLabel(class) .. (class == mine and ("  |cff888888" .. L["(you)"] .. "|r") or ""),
            { ClassColor(class) },
            function() return not pickerClosed[token] end,
            function() pickerClosed[token] = not pickerClosed[token] end)
        head.OnToggled = function() LayoutPicker(holder) end
        pickerEntries[#pickerEntries + 1] =
            { frame = head, height = headHeight, indent = 2 }

        for _, entry in ipairs(FP.classBuffs[class]) do
            -- The same FP:CreateToggle the option framework uses, so a row
            -- here looks and behaves like a row anywhere else in the window.
            local item = entry
            local row = FP:CreateToggle(holder,
                EntryLabel(entry) .. TrackerNote(entry)
                                  .. OwnClassNote(entry)
                                  .. RaceNote(entry, class == mine),
                function() return not M:BuffOff(token, item) end,
                function(value)
                    -- Locked while its kind is off, like any row another
                    -- setting has made meaningless: a click here would change
                    -- a setting nobody can see.
                    if KindOff(item) then return end
                    M:SetBuffOff(token, item, not value)
                    -- The layout, not just the display: a capped entry has a
                    -- stepper under it that appears and disappears with it.
                    LayoutPicker(holder)
                    RefreshPicker()
                    FP:Safe("BuffExpiry:Update", M.Update, M)
                end)
            row:SetHeight(PICK_ROW_H)

            -- Faded while its kind is off in General, since 2026-10-06. It
            -- used to stay at full strength and unticked, and a CurseForge
            -- player took Arcane Intellect for broken.
            local tick = row.Refresh
            function row:Refresh()
                tick(self)
                self:SetAlpha(KindOff(item) and 0.4 or 1)
            end
            row:Refresh()

            pickerEntries[#pickerEntries + 1] = {
                frame = row, height = PICK_ROW_H, indent = 14,
                class = token, row = true,
            }
            M.pickerRows[#M.pickerRows + 1] = row

            -- A group buff meant for a few people rather than for everybody
            -- says how many, on a row of its own underneath. It is a `sub`
            -- setting in the sense the window uses everywhere: it qualifies
            -- the row above it and means nothing without it, so it is indented
            -- and it goes away when that row is switched off.
            -- The card alone. Thorns carried a note of ours under it for an
            -- afternoon, about the stepper below it, and the owner took it out:
            -- that row explains itself when hovered.
            if item.kind == "pet" then
                -- No spell behind this row, so it says what it does itself.
                FP:Tooltip(row, EntryLabel(item),
                    L["Shows an icon whenever your pet is not happy, with a "
                    .. "red border when it becomes unhappy. The icon is "
                    .. "hidden during combat."])
            else
                AttachSpellCard(row, function() return SpellsForRow(item) end,
                    EntryLabel(item))
            end

            -- Hovered while its kind is off, the kind's switch in General
            -- lights up: the owner's request of 2026-10-06.
            FP:PointAtCause(row, function() return KindOff(item) end,
                function() return { FP:OptionRow(M, KIND_SETTING[item.kind]) } end)

            -- **The rest of the row opens the entry's details** since the
            -- redesign of 2026-10-15, and the box alone switches it. Every
            -- control that belongs to this one entry is in there: its bar, its
            -- own warning time, and the rows it had under it before, which
            -- stood open until then.
            local key, factory = EntryKey(token, item), FactoryBar(item)
            local function Shut() return not detailsOpen[key] end
            FP:MakeEntryRow(row, {
                key = key, factory = factory,
                isOpen = function() return detailsOpen[key] == true end,
                toggle = function() detailsOpen[key] = not detailsOpen[key] end,
                onToggled = function() LayoutPicker(holder) end,
            })
            -- The box is a button of its own now, and would be a hole in the
            -- middle of the row where the card goes away.
            if row.boxHit then
                if item.kind == "pet" then
                    FP:Tooltip(row.boxHit, EntryLabel(item),
                        L["Shows an icon whenever your pet is not happy, with a "
                        .. "red border when it becomes unhappy. The icon is "
                        .. "hidden during combat."])
                else
                    AttachSpellCard(row.boxHit, function() return SpellsForRow(item) end,
                        EntryLabel(item))
                end
            end

            local function Untracked()
                return KindOff(item) or M:BuffOff(token, item)
            end
            for _, detail in ipairs(FP:EntryDetails(holder, {
                key = key, factory = factory, timed = Timed(item),
                inherited = function() return M:InheritedWarn(token, item) end,
                inheritedHelp = item.kind == "group" and L["Off: uses this "
                    .. "page's warning times. Your buff uses the setting for "
                    .. "its duration; group counts use the setting for buffs "
                    .. "lasting 10 to 29 minutes."] or nil,
                blocked = Untracked,
                causes = function()
                    if KindOff(item) then
                        return { FP:OptionRow(M, KIND_SETTING[item.kind]) }
                    end
                    return { row }
                end,
                changed = function()
                    RefreshPicker()
                    FP:Safe("BuffExpiry:Update", M.Update, M)
                end,
            })) do
                pickerEntries[#pickerEntries + 1] = {
                    frame = detail, height = detail.rowHeight, indent = 26,
                    class = token, row = true, hidden = Shut,
                }
            end

            -- A buff you hand out to others asks where it is tracked, under a
            -- tick that says whether it is tracked at all: on you, on a number
            -- of other players, or on everybody in the group. Since
            -- 2026-10-06, the owner's choice: the rows below are grayed out
            -- and locked while the tick is off. Before, the tick was your own
            -- copy and the count stood beside it on its own, which a Druid
            -- keeping Thorns on the tank used unticked; "Track on yourself"
            -- off says that now, and CarryOverTargets moved such settings.
            -- A switch under the tick, grayed out with it: what the two entries
            -- that declare one below have in common.
            local function SwitchUnderTick(label, desc, get, set)
                local under = FP:CreateToggle(holder, label, get, function(value)
                    if Untracked() then return end
                    set(value)
                    RefreshPicker()
                    FP:Safe("BuffExpiry:Update", M.Update, M)
                end)
                under:SetHeight(PICK_ROW_H)
                FP:Tooltip(under, label, function()
                    if not Untracked() then return desc end
                    return desc .. "|n|n"
                        .. L["Not in use until another setting here allows "
                        .. "it."]
                end)
                local paint = under.Refresh
                under.Refresh = function(self, ...)
                    if paint then paint(self, ...) end
                    self:SetAlpha(Untracked() and 0.4 or 1)
                end
                under:Refresh()
                FP:PointAtCause(under, Untracked, function()
                    if KindOff(item) then
                        return { FP:OptionRow(M, KIND_SETTING[item.kind]) }
                    end
                    return { row }
                end)
                pickerEntries[#pickerEntries + 1] = {
                    frame = under, height = PICK_ROW_H, indent = 26,
                    class = token, row = true, hidden = Shut,
                }
            end

            -- Battle Shout's "Only warn in combat", the owner's choice of
            -- 2026-10-07. See M:CombatOnly.
            if item.combatOnly then
                SwitchUnderTick(L["Only warn in combat"],
                    L["Warns about this buff only during a fight."],
                    function() return M:CombatOnly(token, item) end,
                    function(value) M:SetCombatOnly(token, item, value) end)
            end

            -- Shadow Protection's icon when somebody else could give it, the
            -- owner's choice of 2026-11-04. See M:OfferWarns. **Not grayed out
            -- on a Priest**, whom it does not reach: a profile is shared
            -- between characters, and the Priest may be where it is set.
            if item.offerSwitch then
                SwitchUnderTick(item.offerSwitch.label, item.offerSwitch.desc,
                    function() return M:OfferWarns(token, item) end,
                    function(value) M:SetOfferWarns(token, item, value) end)
            end

            if item.targets then
                local spec = item.targets
                local master = row

                local function Untracked() return M:BuffOff(token, item) end

                -- What grays the rows below out: the kind in General while it
                -- is off, else the tick above them.
                local function MasterCause()
                    if KindOff(item) then
                        return FP:OptionRow(M, KIND_SETTING[item.kind])
                    end
                    return master
                end

                local NOT_IN_USE = L["Not in use until another setting here "
                                .. "allows it."]

                -- A row's hover, with the sentence every grayed out row ends on.
                local function Explained(text, blocked)
                    return function()
                        if not blocked() then return text end
                        return text .. "|n|n" .. NOT_IN_USE
                    end
                end

                -- Faded with the alpha a row anywhere in the window gets when
                -- another setting makes it meaningless.
                local function Fade(frame, blocked)
                    local paint = frame.Refresh
                    frame.Refresh = function(self, ...)
                        if paint then paint(self, ...) end
                        self:SetAlpha(blocked() and 0.4 or 1)
                    end
                    frame:Refresh()
                end

                -- Your own copy. Of two buffs that replace each other on a
                -- player only one can be on you, so switching one on here
                -- switches the other off: the owner's rule of 2026-10-05, on
                -- this switch since the tick stopped meaning your own copy.
                local selfRow = FP:CreateToggle(holder, L["Track on yourself"],
                    function() return M:TargetsSelf(token, item) end,
                    function(value)
                        if Untracked() then return end
                        M:SetTargetsSelf(token, item, value)
                        if value then
                            for _, other in ipairs(Excluded(token, item)) do
                                M:SetTargetsSelf(token, other, false)
                            end
                        end
                        RefreshPicker()
                        FP:Safe("BuffExpiry:Update", M.Update, M)
                    end)
                selfRow:SetHeight(PICK_ROW_H)
                FP:Tooltip(selfRow, L["Track on yourself"],
                    Explained(L["Also tracks this buff on you."], Untracked))
                Fade(selfRow, Untracked)
                FP:PointAtCause(selfRow, Untracked, function() return { MasterCause() } end)
                pickerEntries[#pickerEntries + 1] = {
                    frame = selfRow, height = PICK_ROW_H, indent = 26,
                    class = token, row = true, hidden = Shut,
                }

                -- Built below the stepper, and named here so the stepper can
                -- point at it.
                local allRow
                local function CapBlocked()
                    return Untracked() or M:TargetsAll(token, item)
                end
                local capRow = FP:CreateStepper(holder,
                    L["Track on friendly targets"], {
                    Get = function() return M:TargetCount(token, item) end,
                    Set = function(value)
                        -- Locked while it is grayed out: the number means
                        -- nothing then, and a click must not change it unseen.
                        if CapBlocked() then return end
                        M:SetTargetCount(token, item, value)
                        FP:Safe("BuffExpiry:Update", M.Update, M)
                    end,
                    min = spec.min, max = spec.max, step = 1,
                    Format = function(v)
                        if v == 0 then return L["off"] end
                        return FP:Plural(v, N["%d player"], N["%d players"]):format(v)
                    end,
                })
                FP:Tooltip(capRow.tooltipTargets, L["Track on friendly targets"],
                    Explained(L["How many other players must have this buff "
                        .. "active, not counting you. Outside combat, the "
                        .. "icon shows how many are still missing it."], CapBlocked))
                capRow:SetHeight(PICK_ROW_H)
                Fade(capRow, CapBlocked)
                FP:PointAtCause(capRow, CapBlocked, function()
                    if Untracked() then return { MasterCause() } end
                    return { allRow }
                end)
                pickerEntries[#pickerEntries + 1] = {
                    frame = capRow, height = PICK_ROW_H, indent = 26,
                    class = token, row = true, hidden = Shut,
                }

                -- Everybody instead of a number, the owner's switch of
                -- 2026-10-05, under the stepper it stands in for. Off by
                -- default, like everything else about these entries.
                allRow = FP:CreateToggle(holder,
                    L["Track on every group or raid member"],
                    function() return M:TargetsAll(token, item) end,
                    function(value)
                        if Untracked() then return end
                        M:SetTargetsAll(token, item, value)
                        if value then
                            for _, other in ipairs(Excluded(token, item)) do
                                M:SetTargetsAll(token, other, false)
                            end
                        end
                        RefreshPicker()
                        FP:Safe("BuffExpiry:Update", M.Update, M)
                    end)
                allRow:SetHeight(PICK_ROW_H)
                FP:Tooltip(allRow, L["Track on every group or raid member"],
                    Explained(L["Tracks this buff on every member of your "
                        .. "group or raid instead of using the number above. "
                        .. "Outside combat, the icon shows how many are "
                        .. "still missing it."], Untracked))
                Fade(allRow, Untracked)
                FP:PointAtCause(allRow, Untracked, function() return { MasterCause() } end)
                pickerEntries[#pickerEntries + 1] = {
                    frame = allRow, height = PICK_ROW_H, indent = 26,
                    class = token, row = true, hidden = Shut,
                }
            end
        end
    end

    -- Tracking, immediately after the classes, which is where the owner asked
    -- for it on 2026-09-21. It is not a class buff and it is the same question
    -- as one: which of the things you could have running do you want to be
    -- told about.
    --
    -- **A fixed heading with a rule, so it ends the section above rather than
    -- sitting inside it**, asked for the same day. That is what a rule means
    -- on this page, and it brings the other half of the rule with it: a
    -- section never folds. Nobody can put this block away and later find that
    -- the tracking setting has gone.
    local head, headHeight = FP:SectionHeading(holder, L["Tracking"])
    pickerEntries[#pickerEntries + 1] =
        { frame = head, height = headHeight, indent = 2 }

    for _, entry in ipairs(FP.trackingTypes or {}) do
        local item = entry
        local row = FP:CreateToggle(holder, TrackingLabel(item),
            function() return M:TrackingWanted(item) end,
            function(value)
                M:SetTrackingWanted(item, value)
                -- Its details gray out with it.
                RefreshPicker()
                FP:Safe("BuffExpiry:Update", M.Update, M)
            end)
        row:SetHeight(PICK_ROW_H)

        -- Two things on every refresh rather than once at build time.
        --
        -- The label, because a profession learned during the session moves the
        -- answer, and a row that still reads "not trained" an hour later is
        -- worse than one that never did.
        --
        -- The level, because each of these answers to the heading above rather
        -- than to a row above it: there is nothing here for them to qualify.
        -- A class buff is the other case, which is why those stay quiet and
        -- indented and these do not. The color arrives with the role: see the
        -- page rules in AGENTS.md.
        local base = row.Refresh
        row.Refresh = function(self)
            base(self)
            self.text:SetText(TrackingLabel(item))
            FP:ApplyLevel(self, "primary")
        end

        -- The tracking spell in one line, like every buff row above.
        AttachSpellCard(row, function() return { item.spell } end,
            function() return TrackingLabel(item) end)

        pickerEntries[#pickerEntries + 1] =
            { frame = row, height = PICK_ROW_H, indent = 2 }
        M.pickerRows[#M.pickerRows + 1] = row

        -- Details like a buff's, with a bar and no time: tracking does not
        -- run out, it is on or off.
        local key = "buffs:track/" .. tostring(item.id)
        local function Shut() return not detailsOpen[key] end
        FP:MakeEntryRow(row, {
            key = key, factory = "general",
            isOpen = function() return detailsOpen[key] == true end,
            toggle = function() detailsOpen[key] = not detailsOpen[key] end,
            onToggled = function() LayoutPicker(holder) end,
        })
        if row.boxHit then
            AttachSpellCard(row.boxHit, function() return { item.spell } end,
                function() return TrackingLabel(item) end)
        end
        local function Unwanted()
            return M.db.tracking == false or not M:TrackingWanted(item)
        end
        for _, detail in ipairs(FP:EntryDetails(holder, {
            key = key, factory = "general", timed = false,
            blocked = Unwanted,
            causes = function()
                if M.db.tracking == false then return { FP:OptionRow(M, "tracking") } end
                return { row }
            end,
            changed = function()
                RefreshPicker()
                FP:Safe("BuffExpiry:Update", M.Update, M)
            end,
        })) do
            -- A row of its own here rather than a class block's, so it hides
            -- by the same test LayoutPicker asks of a class row.
            pickerEntries[#pickerEntries + 1] = {
                frame = detail, height = detail.rowHeight, indent = 14,
                row = true, hidden = Shut,
            }
        end
    end

    RefreshPicker()
    return LayoutPicker(holder)
end
