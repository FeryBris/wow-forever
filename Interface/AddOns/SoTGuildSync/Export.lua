-- SoTGuildSync export: the guild snapshot the launcher uploads.
--
-- Guild master only. Saved on login (once the roster and event log answer),
-- on roster/event-log updates while playing (throttled), every 10 minutes,
-- and on logout or /reload. WoW writes SavedVariables on logout/reload, and
-- the launcher reads SoTGuildSyncDB.json after the game closes.
--
-- Field shapes are from probe runs 1-2 (web/docs/FOREVER_PLAN.md,
-- "Probe results"). Member fields keep the WotLK names so the launcher's
-- existing GuildRosterMember parser still reads them; new fields are extra.

local _, ns = ...

local SAVE_THROTTLE = 30 -- seconds between saves triggered by update events
local REFRESH_EVERY = 600 -- seconds between roster/event-log refresh requests

local lastSave = 0

-- Value or nil when the client keeps it secret.
local function S(v)
	if ns.IsSecret(v) then
		return nil
	end
	return v
end

local function NonEmpty(s)
	s = S(s)
	if type(s) == "string" and s ~= "" then
		return s
	end
	return nil
end

local function Ago(y, m, d, h)
	y, m, d, h = S(y), S(m), S(d), S(h)
	if y == nil and m == nil and d == nil and h == nil then
		return nil
	end
	return { years = y or 0, months = m or 0, days = d or 0, hours = h or 0 }
end

---------------------------------------------------------------------------
-- Communities roster, by GUID: race, classId, presence, professions and
-- last-online, which GetGuildRosterInfo doesn't give. (doc, measured run 1)
---------------------------------------------------------------------------
local function ClubMembersByGuid()
	local byGuid = {}
	local clubId = C_Club.GetGuildClubId()
	if not clubId then
		return byGuid
	end
	local ids = C_Club.GetClubMembers(clubId)
	if ns.IsSecret(ids) or type(ids) ~= "table" then
		return byGuid
	end
	for _, memberId in ipairs(ids) do
		local m = C_Club.GetMemberInfo(clubId, memberId)
		local guid = m and S(m.guid)
		if guid then
			byGuid[guid] = m
		end
	end
	return byGuid
end

local function Professions(c)
	local list = {}
	if not c then
		return list
	end
	for _, n in ipairs({ 1, 2 }) do
		local id = S(c["profession" .. n .. "ID"])
		if type(id) == "number" and id > 0 then
			-- Rank is always 1 on Forever (GuildOS, measured run 1): not exported.
			list[#list + 1] = { id = id, name = NonEmpty(c["profession" .. n .. "Name"]) }
		end
	end
	return list
end

---------------------------------------------------------------------------
-- Members: GetGuildRosterInfo (17 returns, order measured run 1) joined
-- with the Communities roster by GUID.
---------------------------------------------------------------------------
local function CollectMembers()
	local club = ClubMembersByGuid()
	local members = {}
	local total = GetNumGuildMembers()
	for i = 1, total do
		local name, rankName, rankIndex, level, _, zone, publicNote, officerNote,
			isOnline, _, classFile, _, _, isMobile, _, _, guid = GetGuildRosterInfo(i)
		name = S(name)
		if name then
			guid = S(guid)
			local c = guid and club[guid]
			local online = S(isOnline) and true or false
			local lastOnline
			if not online then
				if c then
					lastOnline = Ago(c.lastOnlineYear, c.lastOnlineMonth, c.lastOnlineDay, c.lastOnlineHour)
				end
				lastOnline = lastOnline or Ago(GetGuildRosterLastOnline(i))
			end
			members[#members + 1] = {
				-- WotLK-compatible fields (launcher GuildRosterMember)
				name = name, -- Forever names are "First Last"
				class = S(classFile),
				level = S(level),
				guildRank = S(rankName),
				guildRankIndex = S(rankIndex), -- 0-based, 0 = guild master
				zone = NonEmpty(zone),
				publicNote = NonEmpty(publicNote),
				officerNote = NonEmpty(officerNote),
				isOnline = online,
				-- achievementPoints: always -1 on Forever (run 1), left out.
				-- Forever additions
				guid = guid,
				isMobile = S(isMobile) and true or false,
				classId = c and S(c.classID) or nil,
				raceId = c and S(c.race) or nil,
				presence = c and S(c.presence) or nil, -- Enum.ClubMemberPresence
				lastOnline = lastOnline, -- relative ("how long ago"), nil when online
				professions = Professions(c),
			}
		end
	end
	return members
end

---------------------------------------------------------------------------
-- Ranks: GuildControlGetRankName / GetRankFlags are 1-based (measured run 1);
-- exported with index = i - 1 so it matches members' guildRankIndex.
---------------------------------------------------------------------------
local function CollectRanks()
	local ranks = {}
	for i = 1, GuildControlGetNumRanks() do
		local flags = C_GuildInfo.GuildControlGetRankFlags(i)
		ranks[#ranks + 1] = {
			index = i - 1,
			name = S(GuildControlGetRankName(i)),
			permissions = (not ns.IsSecret(flags) and type(flags) == "table") and flags or {},
		}
	end
	return ranks
end

-- Localized labels for the permission flags (FrameXML GUILDCONTROL_OPTIONn).
local function PermissionLabels()
	local labels = {}
	local i = 1
	while type(_G["GUILDCONTROL_OPTION" .. i]) == "string" do
		labels[i] = _G["GUILDCONTROL_OPTION" .. i]
		i = i + 1
	end
	return labels
end

---------------------------------------------------------------------------
-- Guild event log: GetGuildEventInfo (8 returns, measured runs 1-2).
-- Index 1 is the oldest; the log holds at most 100 rows and rolls over.
-- invite: actor invited target. join: actor joined. promote/demote: actor
-- changed target's rank to `rank`. Time is "how long ago", hour precision.
-- Names can be nil until the client has them cached (run 1 vs run 2).
---------------------------------------------------------------------------
local function CollectEventLog()
	local rows = {}
	for i = 1, GetNumGuildEvents() do
		local eventType, actor, target, rank, y, m, d, h = GetGuildEventInfo(i)
		rows[#rows + 1] = {
			type = S(eventType),
			actor = NonEmpty(actor),
			target = NonEmpty(target),
			rank = NonEmpty(rank),
			ago = Ago(y, m, d, h),
		}
	end
	return rows
end

---------------------------------------------------------------------------
function ns.Export(trigger)
	if not IsInGuild() or not IsGuildLeader() then
		return false
	end
	local guildName, _, _, guildRealm = GetGuildInfo("player")
	local total, online = GetNumGuildMembers()
	local faction = GetGuildFactionGroup() -- 0 = Horde (measured run 1), 1 = Alliance
	local data = {
		version = ns.VERSION,
		trigger = trigger,
		updatedAt = time(),
		exportedBy = UnitName("player"),
		guildName = S(guildName),
		realm = S(guildRealm) or GetRealmName(),
		guild = {
			faction = (faction == 0 and "Horde") or (faction == 1 and "Alliance") or nil,
			motd = NonEmpty(C_GuildInfo.GetMOTD()),
			infoText = NonEmpty(C_GuildInfo.GetInfoText()),
			memberCount = S(total),
			onlineCount = S(online),
		},
		ranks = CollectRanks(),
		permissionLabels = PermissionLabels(),
		members = CollectMembers(),
		eventLog = CollectEventLog(),
	}
	SoTGuildSyncDB = SoTGuildSyncDB or {}
	SoTGuildSyncDB.export = data
	SoTGuildSyncDB.json = ns.EncodeJSON(data)
	lastSave = time()
	return true, data
end

local function Request()
	if IsInGuild() and IsGuildLeader() then
		C_GuildInfo.GuildRoster()
		QueryGuildEventLog()
	end
end

-- At most one save per SAVE_THROTTLE; an update inside the window is
-- delayed, not dropped (at login the event log answers seconds after the roster).
local pending = false
local function ThrottledExport(event)
	local wait = SAVE_THROTTLE - (time() - lastSave)
	if wait <= 0 then
		ns.Export(event)
	elseif not pending then
		pending = true
		C_Timer.After(wait, function()
			pending = false
			ns.Export(event)
		end)
	end
end

ns.On("PLAYER_LOGIN", function()
	-- The roster and event log answer asynchronously; their update events save.
	Request()
	C_Timer.NewTicker(REFRESH_EVERY, Request)
end)
ns.On("GUILD_ROSTER_UPDATE", ThrottledExport)
ns.On("GUILD_EVENT_LOG_UPDATE", ThrottledExport)
-- Synchronous final save from already-loaded data (no async queries possible
-- here). PLAYER_LEAVING_WORLD also covers /reload (WotLK addon's approach).
ns.On("PLAYER_LOGOUT", function()
	ns.Export("logout")
end)
ns.On("PLAYER_LEAVING_WORLD", function()
	ns.Export("leaving")
end)

ns.commands.export = function()
	if not IsGuildLeader() then
		ns.Print("export is guild master only")
		return
	end
	local ok, data = ns.Export("manual")
	if ok then
		ns.Print(("exported %d members, %d ranks, %d event log rows. /reload to write it."):format(
			#data.members, #data.ranks, #data.eventLog))
	end
end
