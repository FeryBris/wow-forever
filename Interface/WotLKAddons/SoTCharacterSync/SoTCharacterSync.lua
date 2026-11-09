local TARGET_GUILD = "Stalkers of Time"

local frame = CreateFrame("Frame")
SoTCharacterSyncDB = SoTCharacterSyncDB or {}

-- Combat rating indices (WotLK 3.3.5a). Kept local since a couple of these
-- (marked below) are uncertain from documentation alone and need a
-- live-client check; wrapped in safeCall() below so a wrong/missing one
-- just yields nil instead of breaking the rest of the collected data.
-- Note: like haste/expertise/armor penetration below, the hit_* stats are
-- the RATING-derived % only (gear/enchants) — base/racial/talent hit
-- bonuses (e.g. Draenei, Precision) aren't included, since 3.3.5a has no
-- single API that returns the fully combined total the way GetCritChance
-- etc. do for crit.
local CR_HIT_MELEE = 6
local CR_HIT_RANGED = 7
local CR_HIT_SPELL = 8
local CR_HASTE_MELEE = 18
local CR_HASTE_SPELL = 20
local CR_ARMOR_PENETRATION = 25
local CR_RESILIENCE_PLAYER_DAMAGE_TAKEN = 27 -- uncertain, verify in-game

-- Populated by guildMembership() below whenever it can see a confirmed
-- membership in the target guild — read by collectData() so the rank
-- doesn't need a second GetGuildInfo() call (which returns all of this in
-- one shot: guildName, guildRankName, guildRankIndex, guildRealm).
local lastGuildRankName = nil
local lastGuildRankIndex = nil

-- Returns true (confirmed member), false (confirmed NOT a member — in a
-- different guild, or in none), or nil (not known yet). GetGuildInfo's
-- guild-name string is often still nil right at PLAYER_ENTERING_WORLD even
-- though IsInGuild() already reports true, since the roster/name hasn't
-- arrived from the server yet — callers must treat nil as "don't touch
-- this character's data yet", never as "not a member", or that load delay
-- ends up deleting an already-synced character's entry.
local function guildMembership()
  if not IsInGuild() then
    return false
  end
  local guildName, rankName, rankIndex = GetGuildInfo("player")
  if not guildName then
    return nil
  end
  if guildName == TARGET_GUILD then
    lastGuildRankName = rankName
    lastGuildRankIndex = rankIndex
  end
  return guildName == TARGET_GUILD
end

-- Calls fn(...) and returns its first result, or nil if fn doesn't exist
-- or errors — used for the less-certain combat/spell APIs so one wrong
-- function name never breaks the rest of collectData().
local function safeCall(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, result = pcall(fn, ...)
  if ok then
    return result
  end
  return nil
end

-- Like safeCall, but preserves every return value instead of just the
-- first — needed for APIs like GetTalentTabInfo/GetTalentInfo that report
-- several fields at once (safeCall alone would silently discard all but
-- the first, e.g. dropping pointsSpent right off GetTalentTabInfo).
local function safeCallMulti(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, a, b, c, d, e = pcall(fn, ...)
  if ok then
    return a, b, c, d, e
  end
  return nil
end

-- Like safeCall, but returns the function's SECOND result (for the few
-- APIs, like GetManaRegen, where the value we want isn't the first one).
local function safeCallSecond(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, _, second = pcall(fn, ...)
  if ok then
    return second
  end
  return nil
end

-- Like safeCall, but keeps EVERY return value instead of capping at 5 —
-- needed for wide-return APIs like GetFactionInfo (14 values) and
-- GetCurrencyListInfo (9 values), where safeCallMulti's cap silently
-- truncated fields past position 5. Returns a 1-indexed table where
-- result[1] is the wrapped function's own first return value (pcall's ok
-- flag is consumed here, not part of the result), or nil on error/missing fn.
local function safeCallPacked(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local packed = { pcall(fn, ...) }
  if not packed[1] then
    return nil
  end
  table.remove(packed, 1)
  return packed
end

-- WotLK item link core segment: item:itemID:enchant:gem1:gem2:gem3:gem4:...
-- Enchant/gem fields are empty (not "0") when unused, hence %d* not %d+.
-- Only itemId/enchantId come from the link itself - confirmed live that
-- the link's own gem-position segments are NOT the socketed gems' actual
-- item IDs (a Kel'Thuzad's Hood link reported 3621/3545 there, while
-- GetInventoryItemGems("player", slot) correctly reports 41285/40133 for
-- the same helm) - collectCurrentEquipment fills gemIds in from that API
-- instead, which is the real source for what's actually socketed.
local function parseItemLink(link)
  if not link then
    return nil
  end
  local itemId, enchantId = link:match("item:(%d+):(%d*)")
  if not itemId then
    return nil
  end
  return {
    itemId = tonumber(itemId),
    enchantId = tonumber(enchantId) or 0,
  }
end

-- WotLK's numeric item rarity (GetItemInfo's 3rd return) in name-string form,
-- matching Blizzard's own API naming convention (used server-side to resolve
-- item_qualities.name) so no separate mapping table is needed downstream.
local ITEM_QUALITY_NAMES = {
  [0] = "Poor", [1] = "Common", [2] = "Uncommon", [3] = "Rare",
  [4] = "Epic", [5] = "Legendary", [6] = "Artifact", [7] = "Heirloom",
}

-- Full item metadata comes straight from THIS server's own item cache (via
-- the same GameTooltip-backing data GetItemInfo reads from) rather than
-- Blizzard's live API, which reflects modern retail values that often don't
-- match a 3.3.5a server's item levels/stats at all. Only equipped items are
-- ever covered this way (a client only ever caches what it's actually seen).
local function collectCurrentEquipment()
  local items = {}
  for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
    local link = GetInventoryItemLink("player", slot)
    local parsed = parseItemLink(link)
    if parsed then
      -- itemRarity, itemStackCount and sellPrice are skipped (not useful here).
      local name, _, rarity, level, _, itemType, itemSubType, _, equipLoc, texture =
        GetItemInfo(link)

      -- Unlike GetInventoryItemLink, this one takes just the slot - no unit
      -- arg (confirmed live: passing "player", slot returned nothing at
      -- all - saved data came back with every gemId 0 - while plain
      -- GetInventoryItemGems(slot) correctly returns the socketed gems).
      -- 4, not 3 - matches this data's own gem_1_id..gem_4_id column shape
      -- server-side; a blacksmith-added extra socket (Socket Bracer/Gloves)
      -- on top of an item's own innate sockets can exceed 3 total, so
      -- capping at 3 here would silently drop that socket's gem.
      local gem1, gem2, gem3, gem4 = safeCallMulti(GetInventoryItemGems, slot)
      parsed.gemIds = { gem1 or 0, gem2 or 0, gem3 or 0, gem4 or 0 }

      parsed.name = name
      parsed.level = level
      parsed.quality = rarity and ITEM_QUALITY_NAMES[rarity] or nil
      parsed.itemType = itemType
      parsed.itemSubType = itemSubType
      -- equipLoc is a raw token like "INVTYPE_CHEST" — split into the bare
      -- key ("CHEST") and a localized label via the same global string
      -- constant the game client itself uses to display slot names.
      parsed.equipLocType = equipLoc and equipLoc:gsub("^INVTYPE_", "") or nil
      parsed.equipLocName = equipLoc and _G[equipLoc] or nil
      -- texture is a full path like "Interface\Icons\INV_Chest_Plate06" —
      -- keep just the bare, lowercased file name (matches how item icons
      -- are conventionally referenced elsewhere).
      parsed.icon = texture and texture:match("([^\\]+)$"):lower() or nil

      table.insert(items, parsed)
    end
  end
  return items
end

-- Same defensive shape check as isNestedPoints/isGlyphList below — an
-- inactive slot last written by a pre-dual-spec addon version (a flat
-- {item,item,...} array with no first_equipment/second_equipment wrapper
-- at all) reads back as nil through these string keys rather than
-- colliding with real data, but the explicit check keeps this in sync
-- with the same defensive style used everywhere else in this file.
local function isEquipmentList(items)
  if type(items) ~= "table" then
    return false
  end
  if items[1] == nil then
    return true -- empty table — fine either way
  end
  return type(items[1]) == "table"
end

-- Equipment is tied to the active dual-spec loadout the same way talents
-- and glyphs are (see collectTalents below for why this server's client
-- can only ever read the currently-active group) — a character can gear
-- up differently per spec (e.g. a tank/DPS Warrior), so a single flat
-- snapshot would silently overwrite one spec's set with the other's every
-- time the player switches. Routes into first_equipment/second_equipment
-- by active group number, preserving the other slot from `previous`.
--
-- `equipmentChanged` gates whether this call actually re-scans at all -
-- confirmed live: this server's dual-spec doesn't auto-swap gear on a
-- group switch, so re-gearing under group 1 and THEN switching to group 2
-- without touching any items left the player still physically wearing
-- their group-1 set. Scanning unconditionally on every refresh (including
-- ones triggered purely by ACTIVE_TALENT_GROUP_CHANGED) captured that
-- unchanged gear as if it were group 2's real loadout, clobbering
-- second_equipment's actual saved set with a snapshot that was never
-- equipped under it. Only a real PLAYER_EQUIPMENT_CHANGED (see
-- scheduleRefresh's equipmentChanged flag) is trustworthy evidence that
-- whatever's currently worn belongs to whichever group is active *right
-- now*; a pure talent-group switch on its own tells us nothing new about
-- either slot, so both just carry forward from `previous` untouched.
--
-- GetActiveTalentGroup() is deliberately read HERE (scan time, once the
-- debounce has settled), not captured back at the PLAYER_EQUIPMENT_CHANGED
-- event itself - confirmed live, this is what the original file comment
-- on the debounce below was about: switching dual-spec groups and then
-- quickly re-gearing can fire the equipment event before the
-- server-confirmed group switch has caught up, so reading the group too
-- early risks the OLD (pre-switch) value. Reading it late, after settling,
-- gets this common order (switch, then gear) right. The much rarer reverse
-- order (gear, then quickly switch before this debounce elapses) can still
-- misattribute - accepted tradeoff, see this file's git history for the
-- other direction's fix, reverted because it broke the common case.
local function collectEquipment(previous, equipmentChanged)
  local firstEquipment = previous and previous.first_equipment
  local secondEquipment = previous and previous.second_equipment

  if firstEquipment == nil and secondEquipment == nil and isEquipmentList(previous) and previous[1] ~= nil then
    firstEquipment = previous
    secondEquipment = previous
  end

  firstEquipment = firstEquipment or {}
  secondEquipment = secondEquipment or {}

  if not isEquipmentList(firstEquipment) then
    firstEquipment = {}
  end
  if not isEquipmentList(secondEquipment) then
    secondEquipment = {}
  end

  if equipmentChanged then
    local activeGroup = safeCall(GetActiveTalentGroup) or 1
    local current = collectCurrentEquipment()
    if activeGroup == 2 then
      secondEquipment = current
    else
      firstEquipment = current
    end
  end

  return {
    first_equipment = firstEquipment,
    second_equipment = secondEquipment,
  }
end

-- Confirmed live in-game (a throwaway /sgsdebug slash command, since
-- removed) that this server's client does NOT support reading a
-- dual-spec talent group other than whichever one is currently active —
-- GetTalentTabInfo/GetTalentInfo's optional
-- talentGroup argument either breaks the call entirely (nil/0 back, even
-- for the ACTIVE group) or gets silently ignored. There is no way to see
-- both loadouts in one snapshot without the player switching specs
-- in-game, so this only ever reads the active one.
--
-- Returns the dominant (most points) tree's name for display, plus every
-- tree's full per-talent point array (all 3, not just the dominant one —
-- a build can spend meaningful points in more than one tree, e.g. a
-- Demonology Warlock still putting points in Affliction), in tab order.
local function collectActiveTalentTree()
  local numTabs = safeCall(GetNumTalentTabs) or 0
  local perTree = {}
  local dominantName, dominantSpent = nil, -1

  for tab = 1, numTabs do
    local name, _, pointsSpent = safeCallMulti(GetTalentTabInfo, tab)
    local points = {}
    local numTalents = safeCall(GetNumTalents, tab) or 0
    for t = 1, numTalents do
      local _, _, _, _, currentRank = safeCallMulti(GetTalentInfo, tab, t)
      table.insert(points, currentRank or 0)
    end
    table.insert(perTree, points)

    if name and pointsSpent and pointsSpent > dominantSpent then
      dominantName = name
      dominantSpent = pointsSpent
    end
  end

  return dominantName, perTree
end

-- A carried-forward points array must already be in the current
-- "one array per tree" shape ({{...},{...},{...}}) — an inactive slot
-- that hasn't been refreshed since an older addon version (which wrote a
-- single flat {rank,rank,...} array) would otherwise carry that stale
-- shape forward forever, failing the launcher's deserialization for this
-- character's WHOLE entry over just one stale field. Resets to empty
-- instead; it'll be refreshed with real data next time that spec is
-- actually played.
local function isNestedPoints(points)
  if type(points) ~= "table" then
    return false
  end
  if points[1] == nil then
    return true -- empty table — fine either way
  end
  return type(points[1]) == "table"
end

-- Writes the active spec's data into first_* or second_* to match its
-- actual dual-spec group number (1 or 2) — `previous` (this character's
-- last-saved talents, if any) fills in the OTHER, currently-inactive
-- group's slot unchanged, rather than ever overwriting it with empty.
-- Both specs end up populated naturally over time as the player actually
-- plays each one, one snapshot at a time.
local function collectTalents(previous)
  local activeGroup = safeCall(GetActiveTalentGroup) or 1
  local dominantName, perTree = collectActiveTalentTree()

  local firstTree = previous and previous.first_tree or nil
  local firstPoints = previous and previous.first_points or {}
  local secondTree = previous and previous.second_tree or nil
  local secondPoints = previous and previous.second_points or {}

  if not isNestedPoints(firstPoints) then
    firstPoints = {}
  end
  if not isNestedPoints(secondPoints) then
    secondPoints = {}
  end

  if activeGroup == 2 then
    secondTree, secondPoints = dominantName, perTree
  else
    firstTree, firstPoints = dominantName, perTree
  end

  return {
    first_tree = firstTree,
    first_points = firstPoints,
    second_tree = secondTree,
    second_points = secondPoints,
    -- Which dual-spec group was actually active during THIS collection —
    -- the website uses this to mark which spec is current vs. a
    -- carried-forward snapshot of the other, since first_points/
    -- second_points look identical either way once collected.
    active_group = activeGroup,
  }
end

-- Glyphs are tied to the active dual-spec loadout the same way talents
-- are — reuses the exact same "read the active group only, route into
-- first_glyphs/second_glyphs by group number, preserve the other slot
-- from the previous snapshot" approach as collectTalents() above, rather
-- than re-discovering that same server limitation from scratch.
--
-- GLYPHTYPE_MAJOR/GLYPHTYPE_MINOR are NOT base FrameXML globals — they're
-- defined inside Blizzard_GlyphUI.lua, a lazy-loaded addon that only
-- loads once the player actually opens their in-game Glyphs panel. Since
-- this runs at login (PLAYER_ENTERING_WORLD), that addon is normally
-- still unloaded, so both globals were nil and every comparison silently
-- failed — confirmed live via real synced data where every glyph's type
-- came back null. GetGlyphSocketInfo's glyphType return is always the
-- plain number 1 (major) or 2 (minor) regardless of whether that addon
-- has loaded, so compare against those literals instead.
local GLYPH_TYPE_MAJOR = 1
local GLYPH_TYPE_MINOR = 2

local function collectActiveGlyphs()
  local glyphs = {}
  local numSockets = safeCall(GetNumGlyphSockets) or 0
  for socket = 1, numSockets do
    local enabled, glyphType, glyphSpell = safeCallMulti(GetGlyphSocketInfo, socket)
    if enabled and glyphSpell then
      local name = safeCall(GetSpellInfo, glyphSpell)
      local kind = nil
      if glyphType == GLYPH_TYPE_MAJOR then
        kind = "major"
      elseif glyphType == GLYPH_TYPE_MINOR then
        kind = "minor"
      end
      table.insert(glyphs, { id = glyphSpell, name = name, type = kind })
    end
  end
  return glyphs
end

-- Same defensive shape check as isNestedPoints above — protects against
-- a future addon version changing the glyph entry shape the same way
-- talent points did, without needing to rediscover that class of bug
-- again from a live "invalid type" error.
local function isGlyphList(glyphs)
  if type(glyphs) ~= "table" then
    return false
  end
  if glyphs[1] == nil then
    return true -- empty table — fine either way
  end
  return type(glyphs[1]) == "table"
end

local function collectGlyphs(previous)
  local activeGroup = safeCall(GetActiveTalentGroup) or 1
  local glyphs = collectActiveGlyphs()

  local firstGlyphs = previous and previous.first_glyphs or {}
  local secondGlyphs = previous and previous.second_glyphs or {}

  if not isGlyphList(firstGlyphs) then
    firstGlyphs = {}
  end
  if not isGlyphList(secondGlyphs) then
    secondGlyphs = {}
  end

  if activeGroup == 2 then
    secondGlyphs = glyphs
  else
    firstGlyphs = glyphs
  end

  return {
    first_glyphs = firstGlyphs,
    second_glyphs = secondGlyphs,
  }
end

-- GetProfessions()/GetProfessionInfo() don't exist in the 3.3.5a client
-- (that shortcut API was added in a later expansion) — WotLK only has the
-- generic skill-line list, the same one the base Character panel's Skills
-- tab reads from. Professions and secondary skills aren't tagged as such;
-- they're just entries in that list, identified here by name.
local PRIMARY_PROFESSIONS = {
  Alchemy = true, Blacksmithing = true, Enchanting = true, Engineering = true,
  Herbalism = true, Inscription = true, Jewelcrafting = true, Leatherworking = true,
  Mining = true, Skinning = true, Tailoring = true,
}

local function collectProfessions()
  local result = {
    first = nil, firstSkill = nil,
    second = nil, secondSkill = nil,
    firstAid = nil, cooking = nil, fishing = nil,
  }

  local primaries = {}
  local numSkills = safeCall(GetNumSkillLines) or 0
  for i = 1, numSkills do
    local name, isHeader, _, skillRank = GetSkillLineInfo(i)
    if not isHeader and name then
      if PRIMARY_PROFESSIONS[name] then
        table.insert(primaries, { name = name, rank = skillRank })
      elseif name == "First Aid" then
        result.firstAid = skillRank
      elseif name == "Cooking" then
        result.cooking = skillRank
      elseif name == "Fishing" then
        result.fishing = skillRank
      end
    end
  end

  if primaries[1] then
    result.first = primaries[1].name
    result.firstSkill = primaries[1].rank
  end
  if primaries[2] then
    result.second = primaries[2].name
    result.secondSkill = primaries[2].rank
  end

  return result
end

local function maxSpellBonusDamage()
  -- Schools 2-7 (physical is 1); most classes only ever have one
  -- non-zero school, so the max across all of them is that value.
  -- https://wowwiki-archive.fandom.com/wiki/API_GetSpellBonusDamage
  local best = 0
  for school = 2, 7 do
    local value = safeCall(GetSpellBonusDamage, school) or 0
    if value > best then
      best = value
    end
  end
  return best
end

local function collectCurrentStats()
  return {
    strength = select(1, UnitStat("player", 1)),
    agility = select(1, UnitStat("player", 2)),
    stamina = select(1, UnitStat("player", 3)),
    intellect = select(1, UnitStat("player", 4)),
    spirit = select(1, UnitStat("player", 5)),
    armor = select(1, UnitArmor("player")),
    health = UnitHealthMax("player"),
    mana = UnitPowerMax("player"),

    attack_power = select(1, UnitAttackPower("player")),
    melee_crit = safeCall(GetCritChance),
    melee_haste = safeCall(GetCombatRatingBonus, CR_HASTE_MELEE),
    melee_hit = safeCall(GetCombatRatingBonus, CR_HIT_MELEE),
    expertise = safeCall(GetExpertise),
    armor_penetration = safeCall(GetCombatRatingBonus, CR_ARMOR_PENETRATION),

    ranged_attack_power = select(1, UnitRangedAttackPower("player")),
    ranged_crit = safeCall(GetRangedCritChance),
    ranged_hit = safeCall(GetCombatRatingBonus, CR_HIT_RANGED),

    spell_power = maxSpellBonusDamage(),
    spell_crit = safeCall(GetSpellCritChance, 2),
    spell_haste = safeCall(GetCombatRatingBonus, CR_HASTE_SPELL),
    spell_hit = safeCall(GetCombatRatingBonus, CR_HIT_SPELL),
    spell_penetration = safeCall(GetSpellPenetration),
    mana_regen = safeCallSecond(GetManaRegen),

    dodge = safeCall(GetDodgeChance),
    parry = safeCall(GetParryChance),
    block = safeCall(GetBlockChance),
    block_value = safeCall(GetShieldBlock),
    defense_rating = safeCall(UnitDefense, "player"),
    resilience = safeCall(GetCombatRatingBonus, CR_RESILIENCE_PLAYER_DAMAGE_TAKEN),

    resistance_arcane = select(2, UnitResistance("player", 6)),
    resistance_fire = select(2, UnitResistance("player", 2)),
    resistance_frost = select(2, UnitResistance("player", 5)),
    resistance_nature = select(2, UnitResistance("player", 3)),
    resistance_shadow = select(2, UnitResistance("player", 4)),
  }
end

-- Stats are just as spec-dependent as equipment - crit/hit/spell power/etc.
-- all bake in whatever's currently worn, so they're split first_stats/
-- second_stats and gated by the same equipmentChanged evidence as
-- collectEquipment above, for the same reason: this server's dual-spec
-- doesn't auto-swap gear, so a pure talent-group switch alone would read
-- back a mix of the NEW talents with the OLD (still-equipped) gear's
-- stats - not a real snapshot of either spec - and wrongly attribute it to
-- the newly-active group. Only a confirmed PLAYER_EQUIPMENT_CHANGED is
-- trustworthy evidence that what's currently worn actually belongs to
-- whichever group is active right now.
local function isStatsTable(stats)
  return type(stats) == "table"
end

local function collectStats(previous, equipmentChanged)
  local firstStats = previous and previous.first_stats
  local secondStats = previous and previous.second_stats

  -- Pre-split snapshot (a flat stats table with no first_stats/
  -- second_stats wrapper at all) has no way to tell which spec it was
  -- recorded under - seed BOTH slots from it, same migration approach as
  -- collectEquipment's legacy flat-list handling.
  if firstStats == nil and secondStats == nil and isStatsTable(previous) and next(previous) ~= nil then
    firstStats = previous
    secondStats = previous
  end

  firstStats = firstStats or {}
  secondStats = secondStats or {}

  if not isStatsTable(firstStats) then
    firstStats = {}
  end
  if not isStatsTable(secondStats) then
    secondStats = {}
  end

  if equipmentChanged then
    local activeGroup = safeCall(GetActiveTalentGroup) or 1
    local current = collectCurrentStats()
    if activeGroup == 2 then
      secondStats = current
    else
      firstStats = current
    end
  end

  return {
    first_stats = firstStats,
    second_stats = secondStats,
  }
end

-- Reported unfiltered — GetFactionInfo's isHeader/hasRep flags don't
-- reliably distinguish real factions from pure category headers on this
-- server (confirmed live: Argent Dawn, Booty Bay, Gadgetzan and several
-- other genuinely-gainable factions all report isHeader=true right
-- alongside actual category headers like "Classic"/"Inactive"), so rather
-- than guess wrong again, every row just gets reported as-is and the
-- website can decide what's worth showing. factionID isn't included —
-- confirmed live it's always nil on this client (that return value was
-- only added to GetFactionInfo in a later expansion than 3.3.5a), so name
-- is the only identifier available.
-- A single backward sweep only expands headers that were ALREADY visible
-- when it started — a header revealed by expanding an earlier (lower-
-- index) one is inserted at positions the sweep has already passed, so
-- its OWN collapsed state never gets checked. Confirmed live: this capped
-- the whole faction list at 50 even though the game has ~150+, because
-- Sons of Hodir/Alliance Vanguard (nested one level under Wrath of the
-- Lich King) stayed collapsed forever under the old single-pass version.
-- Repeats until a full pass finds nothing left to expand.
local function expandAllFactionHeaders()
  local expandedAny = true
  while expandedAny do
    expandedAny = false
    local n = safeCall(GetNumFactions) or 0
    for i = n, 1, -1 do
      local f = safeCallPacked(GetFactionInfo, i)
      -- name, description, standingId, barMin, barMax, barValue, atWarWith,
      -- canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild
      if f and f[9] and f[10] then
        safeCall(ExpandFactionHeader, i)
        expandedAny = true
      end
    end
  end
end

-- Top-level expansion headers (Classic / The Burning Crusade / Wrath of
-- the Lich King / Inactive) are the only rows with isHeader=true AND
-- isChild=false — confirmed live. Everything between the current
-- expansion's header and the next one is reported as-is, regardless of
-- ITS OWN isHeader/hasRep flags: those don't reliably mark "is this a
-- real faction" (Sons of Hodir/Alliance Vanguard are real, gainable
-- factions that ALSO happen to report isHeader=true), but index position
-- within the expansion's block is reliable.
local CURRENT_EXPANSION_FACTION_HEADER = "Wrath of the Lich King"

local function collectReputation()
  expandAllFactionHeaders()
  local n = safeCall(GetNumFactions) or 0

  local startIdx = nil
  for i = 1, n do
    local f = safeCallPacked(GetFactionInfo, i)
    if f and f[9] and not f[13] and f[1] == CURRENT_EXPANSION_FACTION_HEADER then
      startIdx = i
      break
    end
  end
  if not startIdx then
    return {}
  end

  local reputations = {}
  for i = startIdx + 1, n do
    local f = safeCallPacked(GetFactionInfo, i)
    if f and f[9] and not f[13] then
      break -- reached the next top-level header (e.g. "Inactive")
    end
    if f and f[1] then
      table.insert(reputations, {
        name = f[1],
        standing = f[3],
        value = f[6],
        max = f[5],
      })
    end
  end
  return reputations
end

-- month/day/year come straight from GetAchievementInfo as this client
-- reports them (confirmed live: e.g. 7/22/26 for a same-day completion) —
-- not reinterpreted here, the website can decide how to expand "26" into
-- a full year.
local function collectAchievements()
  local categories = safeCall(GetCategoryList)
  if type(categories) ~= "table" then
    return { total = 0, completed = 0, points = safeCall(GetTotalAchievementPoints) or 0, recent = {} }
  end

  local totalCount, completedCount = 0, 0
  local recent = {}

  for _, catID in ipairs(categories) do
    -- includeAll=true — without it, GetCategoryNumAchievements undercounts
    -- (confirmed live: 911 scanned vs. the 1058 the in-game Achievements
    -- frame itself reports for the same character), most likely because
    -- Feats of Strength and/or guild achievements are filtered out by
    -- default.
    local numAch = safeCall(GetCategoryNumAchievements, catID, true) or 0
    for i = 1, numAch do
      -- id, name, points, completed, month, day, year — month/day/year are
      -- return values #5-7, past safeCallMulti's 5-value cap.
      local a = safeCallPacked(GetAchievementInfo, catID, i)
      if a and a[1] then
        totalCount = totalCount + 1
        if a[4] then
          completedCount = completedCount + 1
          table.insert(recent, { id = a[1], name = a[2], points = a[3], month = a[5], day = a[6], year = a[7] })
        end
      end
    end
  end

  table.sort(recent, function(x, y)
    local xv = (x.year or 0) * 10000 + (x.month or 0) * 100 + (x.day or 0)
    local yv = (y.year or 0) * 10000 + (y.month or 0) * 100 + (y.day or 0)
    return xv > yv
  end)
  local recentTop = {}
  for i = 1, math.min(10, #recent) do
    table.insert(recentTop, recent[i])
  end

  return {
    total = totalCount,
    completed = completedCount,
    points = safeCall(GetTotalAchievementPoints) or 0,
    recent = recentTop,
  }
end

-- Unlike reputation, GetCurrencyListInfo's isHeader flag checked out fine
-- live (every excluded index really was a header), so this keeps the
-- straightforward "not isHeader" filter.
local function collectCurrency()
  local n = safeCall(GetCurrencyListSize) or 0
  for i = n, 1, -1 do
    local c = safeCallPacked(GetCurrencyListInfo, i)
    -- name, isHeader, isExpanded, isUnused, isWatched, count, extraCurrencyType, icon, itemID
    if c and c[2] and not c[3] then
      safeCall(ExpandCurrencyList, i, true)
    end
  end
  n = safeCall(GetCurrencyListSize) or 0

  local items = {}
  for i = 1, n do
    local c = safeCallPacked(GetCurrencyListInfo, i)
    if c and not c[2] then
      table.insert(items, { name = c[1], count = c[6], itemId = c[9] })
    end
  end

  return {
    honor = safeCall(GetHonorCurrency),
    arena = safeCall(GetArenaCurrency),
    items = items,
  }
end

-- GetNumArenaTeams() is unreliable on this server — confirmed live it
-- reports 0 for a character that GetArenaTeam(1)/GetArenaTeamRosterInfo
-- both return real, live data for when called directly. So this always
-- probes all 3 possible slots (2v2/3v3/5v5) via GetArenaTeam itself rather
-- than trusting the count, keeping whichever ones actually return a name.
--
-- teamName, teamSize, teamRating, weekPlayed, weekWins, seasonPlayed,
-- seasonWins, playerPlayed, seasonPlayerPlayed, teamRank, playerRating —
-- confirmed field order (AddOn Studio's GetArenaTeam docs); this server
-- also returns several more emblem/color values afterward (icon color,
-- border style, etc.) that aren't read here.
--
-- Roster: GetNumArenaTeamMembers() is presumably just as unreliable as
-- GetNumArenaTeams() (same subsystem), so team size (2/3/5, always known
-- from GetArenaTeam itself) is used as the loop bound instead — confirmed
-- live that GetArenaTeamRosterInfo returns real data synchronously, no
-- need to wait on ArenaTeamRoster()/ARENA_TEAM_ROSTER_UPDATE for it. If a
-- pass ever does come back with zero members (e.g. this is the very first
-- time this team's data has ever been requested client-side), the
-- previous snapshot is kept and a refresh is requested as a fallback.
-- Looks up by team NAME rather than slot index — `teams` is built with
-- table.insert (always a dense 1..N array, regardless of which of the 3
-- possible slots had a team) so a previous snapshot's array position
-- doesn't necessarily match this pass's, and slot index isn't a stable
-- identity anyway (Blizzard could in principle reassign which of 1/2/3 a
-- given bracket occupies).
local function findPreviousTeam(previous, name)
  if not previous then
    return nil
  end
  for _, team in ipairs(previous) do
    if team.name == name then
      return team
    end
  end
  return nil
end

local function collectArenaTeams(previous)
  local teams = {}
  for i = 1, 3 do
    local t = safeCallPacked(GetArenaTeam, i)
    if t and t[1] then
      local prevTeam = findPreviousTeam(previous, t[1])
      local size = t[2] or 0
      local members = {}
      for m = 1, size do
        -- name, rank, level, class, online, played, win, seasonPlayed,
        -- seasonWin, personalRating — confirmed field order (AddOn
        -- Studio's GetArenaTeamRosterInfo docs).
        local r = safeCallPacked(GetArenaTeamRosterInfo, i, m)
        if r and r[1] then
          table.insert(members, {
            name = r[1],
            rank = r[2],
            level = r[3],
            class = r[4],
            online = r[5] and true or false,
            played = r[6],
            wins = r[7],
            seasonPlayed = r[8],
            seasonWins = r[9],
            personalRating = r[10],
          })
        end
      end
      if #members == 0 then
        members = (prevTeam and prevTeam.members) or {}
        safeCall(ArenaTeamRoster, i)
      end

      table.insert(teams, {
        name = t[1],
        size = t[2],
        rating = t[3],
        weekPlayed = t[4],
        weekWins = t[5],
        seasonPlayed = t[6],
        seasonWins = t[7],
        playerPlayed = t[8],
        seasonPlayerPlayed = t[9],
        rank = t[10],
        playerRating = t[11],
        members = members,
      })
    end
  end
  return teams
end

-- todayHK, todayHonor, yesterdayHK, yesterdayHonor, lifetimeHK,
-- lifetimeRank — confirmed field order live. Unlike arena team roster,
-- this returns real data immediately after NotifyInspect("player") with
-- no need to wait for an INSPECT_HONOR_UPDATE round-trip. "lifetime" here
-- reads as current-season-only on this server (a level 80 with real past
-- honorable kills came back 0 across the board) rather than true
-- all-time — GetPVPLifetimeStats()'s honorableKills field already covers
-- the true lifetime total, so this is additional/complementary, not a
-- replacement.
local function collectHonorData()
  safeCall(NotifyInspect, "player")
  local h = safeCallPacked(GetInspectHonorData)
  if not h then
    return nil
  end
  return {
    todayHonorableKills = h[1],
    todayHonor = h[2],
    yesterdayHonorableKills = h[3],
    yesterdayHonor = h[4],
    lifetimeHonorableKills = h[5],
    lifetimeRank = h[6],
  }
end

-- UnitSex("player") returns 2 (male) or 3 (female) — 1 is "neuter",
-- reserved for non-player units and not expected here.
local function genderName()
  local sex = UnitSex("player")
  if sex == 2 then return "Male" end
  if sex == 3 then return "Female" end
  return nil
end

-- `equipmentChanged` (see collectEquipment's doc comment) is true for every
-- caller except the debounced refresh path when it was scheduled purely by
-- a talent-group switch with no accompanying PLAYER_EQUIPMENT_CHANGED.
local function collectData(equipmentChanged)
  if equipmentChanged == nil then
    equipmentChanged = true
  end

  local _, englishClass = UnitClass("player")
  local _, englishRace = UnitRace("player")
  -- SoTCharacterSyncDB.characters is initialized below, before any event can
  -- actually call collectData() (only ever runs off a real WoW event, by
  -- which point the whole file — including that init line — has loaded).
  local existing = SoTCharacterSyncDB.characters[UnitName("player")]

  return {
    name = UnitName("player"),
    class = englishClass,
    race = englishRace,
    gender = genderName(),
    guildRank = lastGuildRankName,
    guildRankIndex = lastGuildRankIndex,
    level = UnitLevel("player"),
    gold = GetMoney(),
    equipment = collectEquipment(existing and existing.equipment, equipmentChanged),
    talents = collectTalents(existing and existing.talents),
    glyphs = collectGlyphs(existing and existing.glyphs),
    honorableKills = safeCall(GetPVPLifetimeStats) or 0,
    achievementPoints = safeCall(GetTotalAchievementPoints) or 0,
    honorData = collectHonorData(),
    achievements = collectAchievements(),
    reputation = collectReputation(),
    currency = collectCurrency(),
    arenaTeams = collectArenaTeams(existing and existing.arenaTeams),
    stats = collectStats(existing and existing.stats, equipmentChanged),
    professions = collectProfessions(),
    updatedAt = time(),
  }
end

-- Keyed by character name so every guild alt played on this account keeps
-- its own entry instead of each login overwriting the last one. Stored as
-- raw Lua tables (not pre-encoded) so re-encoding the whole map below can
-- reuse the same json.lua encoder unchanged; `json` is the one field the
-- launcher actually reads, regenerated in full on every relevant event.
SoTCharacterSyncDB.characters = SoTCharacterSyncDB.characters or {}

-- Belt-and-suspenders: re-check here too, not just at file load, in case
-- something (an addon cache, a stale reload) ever leaves this unset by
-- the time an event fires.
local function ensureCharactersTable()
  SoTCharacterSyncDB.characters = SoTCharacterSyncDB.characters or {}
end

-- Only ever adds/refreshes this character's entry, never removes one.
-- Safe to call from any event, including ones that fire during logout/
-- reload teardown, when a membership read can be unreliable/stale —
-- worst case here is just skipping an update, never losing data.
--
-- equipmentChanged: see collectData/collectEquipment - defaults to true so
-- every caller except the debounced refresh (which passes its own tracked
-- value explicitly) keeps trusting whatever's currently worn.
local function refreshEntryIfMember(equipmentChanged)
  ensureCharactersTable()
  if guildMembership() == true then
    SoTCharacterSyncDB.characters[UnitName("player")] = collectData(equipmentChanged)
    SoTCharacterSyncDB.json = SoTCharacterSync_EncodeJSON(SoTCharacterSyncDB.characters)
  end
end

-- The only path allowed to remove an entry — reserved for
-- PLAYER_GUILD_UPDATE, the one event Blizzard fires specifically when
-- guild membership actually changes, so a "not a member" read here can
-- actually be trusted.
local function reconcileGuildMembership()
  ensureCharactersTable()
  local name = UnitName("player")
  local membership = guildMembership()
  if membership == true then
    SoTCharacterSyncDB.characters[name] = collectData()
  elseif membership == false then
    SoTCharacterSyncDB.characters[name] = nil
  end
  -- membership == nil (still not loaded): leave any existing entry alone.
  SoTCharacterSyncDB.json = SoTCharacterSync_EncodeJSON(SoTCharacterSyncDB.characters)
end

-- Fires off ArenaTeamRoster(i) in collectArenaTeams() above requests this
-- from the server; by the time ARENA_TEAM_ROSTER_UPDATE actually arrives,
-- the character's entry (with its empty/stale `members`) is already
-- saved — this fills it in in place rather than waiting for the next
-- full collectData() pass (equipment change, relog, etc.).
-- name, rank, level, class, online, played, win, seasonPlayed, seasonWin,
-- personalRating — confirmed field order (AddOn Studio's
-- GetArenaTeamRosterInfo docs).
local function refreshArenaRosters()
  ensureCharactersTable()
  local entry = SoTCharacterSyncDB.characters[UnitName("player")]
  if not entry or not entry.arenaTeams then
    return
  end
  for i, team in pairs(entry.arenaTeams) do
    local size = team.size or 0
    local members = {}
    for m = 1, size do
      local r = safeCallPacked(GetArenaTeamRosterInfo, i, m)
      if r and r[1] then
        table.insert(members, {
          name = r[1],
          rank = r[2],
          level = r[3],
          class = r[4],
          online = r[5] and true or false,
          played = r[6],
          wins = r[7],
          seasonPlayed = r[8],
          seasonWins = r[9],
          personalRating = r[10],
        })
      end
    end
    if #members > 0 then
      team.members = members
    end
  end
  SoTCharacterSyncDB.json = SoTCharacterSync_EncodeJSON(SoTCharacterSyncDB.characters)
end

-- reconcileGuildMembership above only ever touches the CURRENTLY LOGGED IN
-- character's own entry, keyed by its CURRENT name — so it can never catch
-- a stale entry left behind by a rename (the old name never logs in again
-- to trigger it) or a full character deletion (same problem, permanently).
-- Both leave a ghost entry that gets synced to the website forever,
-- looking like a second real character.
--
-- The fix: SoTCharacterSyncDB.characters is only ever populated for
-- confirmed TARGET_GUILD members (see refreshEntryIfMember/
-- reconcileGuildMembership), and Blizzard's live guild roster is the
-- authoritative "which characters are actually still in this guild right
-- now" answer — a renamed or deleted character simply stops appearing in
-- it under its old name. So on GUILD_ROSTER_UPDATE, prune any stored
-- character whose name isn't in the current roster.
--
-- Gated on guildMembership() == true (not just IsInGuild()), exactly like
-- reconcileGuildMembership — this account might currently be playing an
-- alt in some OTHER guild when this fires, and that other guild's roster
-- obviously doesn't contain any Stalkers of Time member names, which would
-- otherwise wipe every stored character.
local function pruneCharactersNotInRoster()
  ensureCharactersTable()
  if guildMembership() ~= true then
    return
  end

  local memberCount = GetNumGuildMembers(true)
  -- A freshly-requested roster can briefly report 0 before the server
  -- reply lands — never treat that as "empty guild, delete everything".
  if memberCount == nil or memberCount == 0 then
    return
  end

  if not memberCount or memberCount == 0 then
      GuildRoster() -- request/update the roster
      return
  end

  local currentNames = {}
  for i = 1, memberCount do
    local name = GetGuildRosterInfo(i)
    if name then
      currentNames[name] = true
    end
  end

  for storedName in pairs(SoTCharacterSyncDB.characters) do
    if not currentNames[storedName] then
      SoTCharacterSyncDB.characters[storedName] = nil
    end
  end
end

-- Equipping a full set fires PLAYER_EQUIPMENT_CHANGED once PER SLOT -
-- debouncing to the last event in a burst (no C_Timer in this client's
-- API, hence the manual OnUpdate elapsed-time tracking) lets the whole
-- swap finish before the actual scan/save, same reasoning as this file's
-- ARENA_TEAM_ROSTER_UPDATE handling elsewhere, just via a delay instead of
-- a later correction.
--
-- ACTIVE_TALENT_GROUP_CHANGED/PLAYER_TALENT_UPDATE share this same debounce
-- (originally added so active_group itself doesn't go stale on a forced
-- client exit - see collectTalents/refreshEntryIfMember) - but a pure
-- group switch must NOT also trigger an equipment re-scan: this server's
-- dual-spec doesn't auto-swap gear, so switching groups without touching
-- any items still reads back the OTHER group's physical gear, which
-- collectEquipment would otherwise happily (and wrongly) file under the
-- newly-active group, clobbering its real saved loadout. pendingEquipmentChange
-- tracks whether an actual PLAYER_EQUIPMENT_CHANGED occurred anywhere in
-- the current debounce window, so the eventual scan only touches equipment
-- when there's real evidence to justify it (see collectEquipment).
--
-- Known accepted gap: gearing up and then quickly switching groups, both
-- within this one debounce window, can still misattribute the gear to the
-- newly-active group (collectEquipment reads GetActiveTalentGroup() at
-- scan time, after the switch). The reverse and far more common order -
-- switch groups, then gear up - works correctly, which matters more here;
-- an earlier attempt to fix the rarer direction by capturing the group at
-- PLAYER_EQUIPMENT_CHANGED time instead broke this common case (reading
-- the group too early, before the server-confirmed switch caught up), so
-- it was reverted.
local REFRESH_DEBOUNCE_SECONDS = 1.0
local refreshDebounceElapsed = nil
local pendingEquipmentChange = false

frame:SetScript("OnUpdate", function(_, elapsed)
  if refreshDebounceElapsed == nil then
    return
  end
  refreshDebounceElapsed = refreshDebounceElapsed + elapsed
  if refreshDebounceElapsed >= REFRESH_DEBOUNCE_SECONDS then
    refreshDebounceElapsed = nil
    local equipmentChanged = pendingEquipmentChange
    pendingEquipmentChange = false
    refreshEntryIfMember(equipmentChanged)
  end
end)

local function scheduleRefresh(equipmentChanged)
  refreshDebounceElapsed = 0
  if equipmentChanged then
    pendingEquipmentChange = true
  end
end

frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_GUILD_UPDATE")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("PLAYER_MONEY")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("ARENA_TEAM_ROSTER_UPDATE")
frame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
frame:RegisterEvent("PLAYER_TALENT_UPDATE")

frame:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_GUILD_UPDATE" then
    reconcileGuildMembership()
    pruneCharactersNotInRoster()
  elseif event == "ARENA_TEAM_ROSTER_UPDATE" then
    refreshArenaRosters()
  elseif event == "PLAYER_EQUIPMENT_CHANGED" then
    scheduleRefresh(true)
  elseif event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
    scheduleRefresh(false)
  else
    refreshEntryIfMember()
  end
end)
