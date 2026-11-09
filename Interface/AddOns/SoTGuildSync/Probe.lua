-- SoTGuildSync probe: reads one sample of every guild data source and saves
-- the raw result to SoTGuildSyncDB.probe, so we can see what Forever really
-- returns before building the export.
--
--   /sotguild probe   then open the guild bank (bank is captured on open),
--   then /reload or log out to write SavedVariables.
--
-- Every value is recorded with ns.Capture (api name, args, return count,
-- value and type per return, "secret" where the client hides it).

local _, ns = ...
local Capture, First = ns.Capture, ns.First

local SAMPLE_ROSTER = 5
local SAMPLE_LOG = 15
local SAMPLE_BANK_SLOTS = 10
local SAMPLE_BANK_LOG = 5
local BANK_SLOTS_PER_TAB = 98 -- MAX_GUILDBANK_SLOTS_PER_TAB in FrameXML
local WAIT = 5 -- seconds to wait for an async answer

local probe -- current result table
local running = false

local function Range(path, count, ...)
	local list = {}
	local extra = { ... }
	for i = 1, count do
		local args = {}
		for _, a in ipairs(extra) do
			args[#args + 1] = a
		end
		args[#args + 1] = i
		list[i] = Capture(path, unpack(args))
	end
	return list
end

local function Num(rec)
	local n = rec and First(rec)
	return type(n) == "number" and n or 0
end

-- Records whether the async event fired and its payload.
local function Waited(section, event, fired, ...)
	section.waited = section.waited or {}
	section.waited[event] = { fired = fired, payload = fired and ns.Plain({ ... }) or nil }
end

---------------------------------------------------------------------------
-- Steps (each one calls nextStep when done)
---------------------------------------------------------------------------
local function StepGates(nextStep)
	probe.gates = {
		Capture("C_ChatInfo.InChatMessagingLockdown"),
		Capture("IsGuildLeader"),
		Capture("C_GuildInfo.IsGuildOfficer"),
		Capture("C_GuildInfo.CanViewOfficerNote"),
		Capture("C_GuildInfo.IsEncounterGuildNewsEnabled"),
		Capture("C_GuildInfo.AreGuildEventsEnabled"),
		Capture("C_GuildInfo.IsGuildReputationEnabled"),
		Capture("C_AchievementInfo.AreGuildAchievementsEnabled"),
		Capture("C_TradeSkillUI.IsGuildTradeSkillsEnabled"),
		Capture("C_GuildBank.IsGuildBankEnabled"),
	}
	nextStep()
end

local function StepIdentity(nextStep)
	local clubId = First(Capture("C_Club.GetGuildClubId"))
	probe.identity = {
		Capture("GetGuildInfo", "player"),
		Capture("C_GuildInfo.GetMOTD"),
		Capture("C_GuildInfo.GetInfoText"),
		Capture("GetGuildFactionGroup"),
		Capture("C_GuildInfo.GetGuildTabardInfo", "player"),
		Capture("C_Reputation.GetGuildFactionData"),
		Capture("C_GuildInfo.GetPreferredPlaySettings"),
		Capture("GetTotalAchievementPoints", true),
		Capture("C_Club.GetGuildClubId"),
		clubId and Capture("C_Club.GetClubInfo", clubId) or { api = "C_Club.GetClubInfo", skipped = "no clubId" },
	}
	nextStep()
end

local function StepRanks(nextStep)
	local numRec = Capture("GuildControlGetNumRanks")
	local n = Num(numRec)
	local names, flags = {}, {}
	-- Index 0 too: tells us whether these are 0- or 1-based on Forever.
	for i = 0, n do
		names[#names + 1] = Capture("GuildControlGetRankName", i)
		flags[#flags + 1] = Capture("C_GuildInfo.GuildControlGetRankFlags", i)
	end
	probe.ranks = { num = numRec, names = names, flags = flags }
	nextStep()
end

local function StepRoster(nextStep)
	local section = { request = Capture("C_GuildInfo.GuildRoster") }
	probe.roster = section
	ns.WaitFor("GUILD_ROSTER_UPDATE", WAIT, function(fired, ...)
		Waited(section, "GUILD_ROSTER_UPDATE", fired, ...)
		section.num = Capture("GetNumGuildMembers")
		local n = math.min(Num(section.num), SAMPLE_ROSTER)
		section.info = Range("GetGuildRosterInfo", n)
		section.lastOnline = Range("GetGuildRosterLastOnline", n)
		nextStep()
	end, nextStep)
end

local function StepClub(nextStep)
	local section = {}
	probe.club = section
	local clubId = First(Capture("C_Club.GetGuildClubId"))
	if not clubId then
		section.skipped = "no guild clubId"
		return nextStep()
	end
	section.members = Capture("C_Club.GetClubMembers", clubId)
	local ids = section.members.values and section.members.values[1]
	section.count = type(ids) == "table" and #ids or nil
	section.info = {}
	if type(ids) == "table" then
		for i = 1, math.min(#ids, SAMPLE_ROSTER) do
			section.info[i] = Capture("C_Club.GetMemberInfo", clubId, ids[i])
		end
	end
	nextStep()
end

-- Query -> event -> count -> first rows. Used by event log, news, recipes.
local function AsyncList(key, queryApi, event, countApi, rowApi)
	return function(nextStep)
		local section = { request = Capture(queryApi) }
		probe[key] = section
		ns.WaitFor(event, WAIT, function(fired, ...)
			Waited(section, event, fired, ...)
			section.num = Capture(countApi)
			section.rows = Range(rowApi, math.min(Num(section.num), SAMPLE_LOG))
			nextStep()
		end, nextStep)
	end
end

local StepEventLog = AsyncList("eventLog", "QueryGuildEventLog", "GUILD_EVENT_LOG_UPDATE",
	"GetNumGuildEvents", "GetGuildEventInfo")
local StepNews = AsyncList("news", "QueryGuildNews", "GUILD_NEWS_UPDATE",
	"GetNumGuildNews", "C_GuildInfo.GetGuildNewsInfo")
local StepRecipes = AsyncList("recipes", "QueryGuildRecipes", "GUILD_TRADESKILL_UPDATE",
	"GetNumGuildTradeSkill", "GetGuildTradeSkillInfo")

---------------------------------------------------------------------------
-- Guild bank: only readable while the bank window is open, so it runs on
-- GUILDBANKFRAME_OPENED after a probe.
---------------------------------------------------------------------------
local function BankSteps(bank)
	return {
		function(nextStep)
			bank.numTabs = Capture("GetNumGuildBankTabs")
			bank.money = Capture("GetGuildBankMoney")
			bank.tabs = Range("GetGuildBankTabInfo", Num(bank.numTabs))
			nextStep()
		end,
		function(nextStep)
			bank.queryTab = Capture("QueryGuildBankTab", 1)
			ns.WaitFor("GUILDBANKBAGSLOTS_CHANGED", WAIT, function(fired, ...)
				Waited(bank, "GUILDBANKBAGSLOTS_CHANGED", fired, ...)
				bank.slots = {}
				for slot = 1, BANK_SLOTS_PER_TAB do
					local link = Capture("GetGuildBankItemLink", 1, slot)
					if First(link) then
						bank.slots[#bank.slots + 1] = { slot = slot, link = link, info = Capture("GetGuildBankItemInfo", 1, slot) }
						if #bank.slots >= SAMPLE_BANK_SLOTS then
							break
						end
					end
				end
				nextStep()
			end, nextStep)
		end,
		function(nextStep)
			bank.queryLog = Capture("QueryGuildBankLog", 1)
			ns.WaitFor("GUILDBANKLOG_UPDATE", WAIT, function(fired, ...)
				Waited(bank, "GUILDBANKLOG_UPDATE", fired, ...)
				bank.numTransactions = Capture("GetNumGuildBankTransactions", 1)
				bank.transactions = Range("GetGuildBankTransaction",
					math.min(Num(bank.numTransactions), SAMPLE_BANK_LOG), 1)
				nextStep()
			end, nextStep)
		end,
		function(nextStep)
			-- The money log is the tab after the last item tab.
			local moneyTab = (MAX_GUILDBANK_TABS or 8) + 1
			bank.queryMoneyLog = Capture("QueryGuildBankLog", moneyTab)
			ns.WaitFor("GUILDBANKLOG_UPDATE", WAIT, function(fired, ...)
				Waited(bank, "GUILDBANKLOG_UPDATE (money)", fired, ...)
				bank.numMoneyTransactions = Capture("GetNumGuildBankMoneyTransactions")
				bank.moneyTransactions = Range("GetGuildBankMoneyTransaction",
					math.min(Num(bank.numMoneyTransactions), SAMPLE_BANK_LOG))
				nextStep()
			end, nextStep)
		end,
	}
end

ns.On("GUILDBANKFRAME_OPENED", function()
	-- Only after a probe, and only for the guild master (the export is GM-only).
	if not (SoTGuildSyncDB and SoTGuildSyncDB.probe) or running or not IsGuildLeader() then
		return
	end
	local bank = { capturedAt = time() }
	running = true
	ns.Print("guild bank open, probing it...")
	ns.RunSteps(BankSteps(bank), function()
		SoTGuildSyncDB.probe.bank = bank
		running = false
		ns.Print(("bank probe done: %d tabs, %d sample items. /reload to save."):format(
			Num(bank.numTabs), bank.slots and #bank.slots or 0))
	end)
end)

---------------------------------------------------------------------------
-- Summary: counts, missing APIs and secret values found anywhere.
---------------------------------------------------------------------------
local function Summarize(node, out)
	if type(node) ~= "table" then
		return
	end
	if node.api then
		if node.missing then
			out.missing[node.api] = true
		elseif node.error then
			out.errors[node.api] = node.error
		end
		if node.types then
			for _, t in pairs(node.types) do
				if t == "secret" then
					out.secret[node.api] = true
				end
			end
		end
	end
	for _, v in pairs(node) do
		if v == "<secret>" then
			out.secret[node.api or "?"] = true
		end
		Summarize(v, out)
	end
end

local function Keys(t)
	local list = {}
	for k in pairs(t) do
		list[#list + 1] = k
	end
	table.sort(list)
	return table.concat(list, ", ")
end

ns.commands.probe = function()
	if running then
		ns.Print("a probe is already running")
		return
	end
	if not IsInGuild() then
		ns.Print("not in a guild")
		return
	end
	local version, build = GetBuildInfo()
	probe = {
		meta = {
			addonVersion = ns.VERSION,
			startedAt = time(),
			character = UnitName("player"),
			realm = GetRealmName(),
			build = version .. "." .. build,
		},
	}
	running = true
	ns.Print("probing guild APIs (about 20 seconds)...")
	ns.RunSteps({ StepGates, StepIdentity, StepRanks, StepRoster, StepClub, StepEventLog, StepNews, StepRecipes }, function()
		probe.meta.finishedAt = time()
		local s = { missing = {}, errors = {}, secret = {} }
		Summarize(probe, s)
		probe.summary = s
		SoTGuildSyncDB = SoTGuildSyncDB or {}
		SoTGuildSyncDB.probe = probe
		running = false
		ns.Print(("done. roster %d, club %s, event log %d, news %d, recipes %d."):format(
			Num(probe.roster.num), tostring(probe.club.count),
			Num(probe.eventLog.num), Num(probe.news.num), Num(probe.recipes.num)))
		if next(s.missing) then ns.Print("missing: " .. Keys(s.missing)) end
		if next(s.errors) then ns.Print("errors: " .. Keys(s.errors)) end
		if next(s.secret) then ns.Print("secret values from: " .. Keys(s.secret)) end
		ns.Print("now open the guild bank (optional), then /reload to save.")
	end)
end
