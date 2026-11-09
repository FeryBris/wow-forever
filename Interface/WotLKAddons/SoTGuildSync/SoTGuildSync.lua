-- Fills the gap SoTCharacterSync can't: SoTCharacterSync only ever reports
-- the character actually logged in and running the addon+launcher, so any
-- guild member who doesn't play with both never shows up. GetGuildRosterInfo,
-- unlike a character's own equipment/stats, is visible for the WHOLE guild
-- from any single logged-in member's client — so this addon just needs one
-- person running it to keep the full roster up to date, regardless of which
-- character that happens to be on any given day.
SoTGuildSync = CreateFrame("Frame")
SoTGuildSyncDB = SoTGuildSyncDB or {}

-- Tried enriching this with race/gender via GetGuildRosterInfo's guid +
-- GetPlayerInfoByGUID, so roster-only members (who never run
-- SoTCharacterSync) could still show a real portrait instead of falling
-- back to a class icon. Confirmed live on this server: GetGuildRosterInfo
-- doesn't return a guid at all (that return value is a later-patch
-- addition genuine 3.3.5a doesn't have), and there's no other way to query
-- an arbitrary guild member's race/gender without a live unit token for
-- them — so this addon can only ever report the shallow roster fields
-- below. race/gender for a roster-only member has to come from that
-- member eventually running SoTCharacterSync themselves.
local function CollectGuildData()
  local members = {}

  if not IsInGuild() then
    return members
  end

  for i = 1, GetNumGuildMembers(true) do
    local name, rankName, rankIndex, level, _classDisplayName, zone,
          publicNote, officerNote, isOnline, _status, class, achievementPoints =
      GetGuildRosterInfo(i)

    table.insert(members, {
      name = name,
      -- Non-localized token (e.g. "WARLOCK"), matching SoTCharacterSync's
      -- `class` field — normalized server-side the same way for both.
      class = class,
      level = level,
      guildRank = rankName,
      guildRankIndex = rankIndex,
      zone = zone,
      publicNote = publicNote,
      officerNote = officerNote,
      -- GetGuildRosterInfo's "boolean" returns are actually 1/nil in this
      -- client, not true/false — coerce to a real boolean or the JSON
      -- encoder writes a bare 1, which the launcher's Rust side (typed as
      -- an actual bool) rejects.
      isOnline = isOnline and true or false,
      -- The only source of this for a character that never runs
      -- SoTCharacterSync itself — without it, roster-only members would
      -- never get achievement points on the site at all.
      achievementPoints = achievementPoints,
    })
  end

  return members
end

-- Saves whatever the roster currently looks like. Safe to call from any
-- event, including GUILD_ROSTER_UPDATE (live refresh while playing) and
-- PLAYER_LOGOUT/PLAYER_LEAVING_WORLD (covers both a normal exit and
-- /reload) — it doesn't matter which character triggers it, since the
-- roster itself isn't tied to whoever's logged in.
local function SaveGuildData()
  if not IsInGuild() then
    return
  end

  local members = CollectGuildData()
  local guildName = (GetGuildInfo("player"))
  local realm = GetRealmName()
  local updatedAt = time()

  -- Kept as both a plain Lua table (human-inspectable via /run, and usable
  -- by any other addon that wants it) and pre-encoded `json` — the one
  -- field the launcher's reader actually parses — same dual-storage
  -- convention SoTCharacterSync uses for its `characters` table.
  SoTGuildSyncDB = {
    guildName = guildName,
    realm = realm,
    updatedAt = updatedAt,
    members = members,
    json = SoTGuildSync_EncodeJSON({
      guildName = guildName,
      realm = realm,
      updatedAt = updatedAt,
      members = members,
    }),
  }
end

SoTGuildSync:RegisterEvent("PLAYER_LOGIN")
SoTGuildSync:RegisterEvent("PLAYER_LOGOUT")
SoTGuildSync:RegisterEvent("PLAYER_LEAVING_WORLD")
SoTGuildSync:RegisterEvent("GUILD_ROSTER_UPDATE")

SoTGuildSync:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    -- Roster info isn't necessarily fresh yet at login; request it and
    -- let the resulting GUILD_ROSTER_UPDATE event do the actual save.
    GuildRoster()
  else
    SaveGuildData()
  end
end)
