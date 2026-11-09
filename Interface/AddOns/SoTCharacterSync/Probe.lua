-- SoTCharacterSync probe: reads one sample of every character data source
-- and saves the raw result to SoTCharacterSyncDB.probe, so we see what
-- Forever really returns before building the export.
--
--   /sotchar probe, wait for "done", then /reload or log out.
--
-- GuildArmory measured (Compatibility.lua): Forever is the retail API with
-- vanilla content, so a function existing proves nothing; only its return
-- values do. Every call below is recorded with ns.Capture (api, args, return
-- count, value and type per return, "secret" where hidden).

local _, ns = ...
local Capture, First = ns.Capture, ns.First

local SAMPLE = 10
local WAIT = 5
local INVENTORY_SLOTS = 19 -- INVSLOT_FIRST_EQUIPPED .. INVSLOT_LAST_EQUIPPED

local probe
local running = false

local function Num(rec)
	local n = rec and First(rec)
	return type(n) == "number" and n or 0
end

local function Waited(section, event, fired, ...)
	section.waited = section.waited or {}
	section.waited[event] = { fired = fired, payload = fired and ns.Plain({ ... }) or nil }
end

---------------------------------------------------------------------------
local function StepIdentity(nextStep)
	probe.identity = {
		Capture("C_ChatInfo.InChatMessagingLockdown"),
		Capture("UnitName", "player"),
		Capture("UnitGUID", "player"),
		Capture("UnitClass", "player"),
		Capture("UnitRace", "player"),
		Capture("UnitSex", "player"),
		Capture("UnitLevel", "player"),
		Capture("UnitFactionGroup", "player"),
		Capture("GetRealmName"),
		Capture("GetGuildInfo", "player"),
		Capture("GetMoney"),
		Capture("UnitXP", "player"),
		Capture("UnitXPMax", "player"),
		Capture("GetXPExhaustion"),
		Capture("IsXPUserDisabled"),
		Capture("GetBindLocation"),
		Capture("GetZoneText"),
		Capture("GetSubZoneText"),
		Capture("C_Map.GetBestMapForUnit", "player"),
	}
	nextStep()
end

-- RequestTimePlayed also prints "Total time played" to chat; that's expected.
local function StepPlayed(nextStep)
	local section = { request = Capture("RequestTimePlayed") }
	probe.played = section
	ns.WaitFor("TIME_PLAYED_MSG", WAIT, function(fired, ...)
		Waited(section, "TIME_PLAYED_MSG", fired, ...)
		nextStep()
	end, nextStep)
end

local function StepEquipment(nextStep)
	local slots = {}
	for slot = 1, INVENTORY_SLOTS do
		local linkRec = Capture("GetInventoryItemLink", "player", slot)
		local link = First(linkRec)
		local entry = { slot = slot, link = linkRec, id = Capture("GetInventoryItemID", "player", slot) }
		if link then
			entry.durability = Capture("GetInventoryItemDurability", slot)
			entry.itemLevel = Capture("C_Item.GetDetailedItemLevelInfo", link)
			entry.info = Capture("C_Item.GetItemInfo", link)
			entry.gem1 = Capture("C_Item.GetItemGem", link, 1)
		end
		slots[slot] = entry
	end
	probe.equipment = {
		slots = slots,
		-- GuildArmory measured it divides by 16 regardless of filled slots.
		averageItemLevel = Capture("GetAverageItemLevel"),
		equipmentSets = Capture("C_EquipmentSet.GetEquipmentSetIDs"),
	}
	nextStep()
end

local function StepTalents(nextStep)
	local section = {
		specIndex = Capture("C_SpecializationInfo.GetSpecialization"),
		numSpecs = Capture("GetNumSpecializations"),
		configId = Capture("C_ClassTalents.GetActiveConfigID"),
	}
	probe.talents = section
	local specIndex = First(section.specIndex)
	if type(specIndex) == "number" then
		section.specInfo = Capture("C_SpecializationInfo.GetSpecializationInfo", specIndex)
	end
	local configId = First(section.configId)
	if not configId then
		section.skipped = "no active config (below ~level 11?)"
		return nextStep()
	end
	section.importString = Capture("C_Traits.GenerateImportString", configId)
	section.configInfo = Capture("C_Traits.GetConfigInfo", configId)
	local info = First(section.configInfo)
	local treeId = type(info) == "table" and type(info.treeIDs) == "table" and info.treeIDs[1]
	if not treeId then
		return nextStep()
	end
	section.treeNodes = Capture("C_Traits.GetTreeNodes", treeId)
	local nodes = First(section.treeNodes)
	section.nodeCount = type(nodes) == "table" and #nodes or nil
	-- Selected nodes (ranksPurchased > 0), first SAMPLE with their entry and
	-- definition (definition -> spellID is what a site would show).
	section.selected = {}
	section.selectedCount = 0
	if type(nodes) == "table" then
		for _, nodeId in ipairs(nodes) do
			local nodeRec = Capture("C_Traits.GetNodeInfo", configId, nodeId)
			local node = First(nodeRec)
			if type(node) == "table" and type(node.ranksPurchased) == "number" and node.ranksPurchased > 0 then
				section.selectedCount = section.selectedCount + 1
				if #section.selected < SAMPLE then
					local sample = { node = nodeRec }
					local entryId = type(node.activeEntry) == "table" and node.activeEntry.entryID
					if entryId then
						sample.entry = Capture("C_Traits.GetEntryInfo", configId, entryId)
						local entry = First(sample.entry)
						if type(entry) == "table" and entry.definitionID then
							sample.definition = Capture("C_Traits.GetDefinitionInfo", entry.definitionID)
						end
					end
					section.selected[#section.selected + 1] = sample
				end
			end
		end
	end
	nextStep()
end

local function StepProfessions(nextStep)
	local section = { list = Capture("GetProfessions") }
	section.info = {}
	if section.list.values then
		for i = 1, section.list.n or 0 do
			local index = section.list.values[i]
			if type(index) == "number" then
				section.info[#section.info + 1] = { position = i, info = Capture("GetProfessionInfo", index) }
			end
		end
	end
	probe.professions = section
	nextStep()
end

local function StepStats(nextStep)
	local stats = {}
	for i = 1, 5 do
		stats[#stats + 1] = Capture("UnitStat", "player", i)
	end
	for _, api in ipairs({ "GetCritChance", "GetRangedCritChance", "GetHaste", "GetMeleeHaste",
		"GetMastery", "GetDodgeChance", "GetParryChance", "GetBlockChance", "GetHitModifier",
		"GetSpellHitModifier", "GetExpertise", "GetManaRegen" }) do
		stats[#stats + 1] = Capture(api)
	end
	stats[#stats + 1] = Capture("UnitArmor", "player")
	stats[#stats + 1] = Capture("UnitHealthMax", "player")
	stats[#stats + 1] = Capture("UnitPowerType", "player")
	stats[#stats + 1] = Capture("UnitPowerMax", "player")
	stats[#stats + 1] = Capture("UnitAttackPower", "player")
	stats[#stats + 1] = Capture("UnitRangedAttackPower", "player")
	stats[#stats + 1] = Capture("UnitSpellHaste", "player")
	stats[#stats + 1] = Capture("GetSpellCritChance", 2) -- 2 = holy school
	stats[#stats + 1] = Capture("GetSpellBonusDamage", 2)
	stats[#stats + 1] = Capture("GetSpellBonusHealing")
	stats[#stats + 1] = Capture("UnitResistance", "player", 3) -- 3 = fire
	stats[#stats + 1] = Capture("GetCombatRating", 1)
	probe.stats = stats
	nextStep()
end

local function StepReputation(nextStep)
	local section = { num = Capture("C_Reputation.GetNumFactions"), watched = Capture("C_Reputation.GetWatchedFactionData") }
	section.rows = {}
	for i = 1, math.min(Num(section.num), SAMPLE) do
		section.rows[i] = Capture("C_Reputation.GetFactionDataByIndex", i)
	end
	probe.reputation = section
	nextStep()
end

local function StepCurrency(nextStep)
	local section = { num = Capture("C_CurrencyInfo.GetCurrencyListSize") }
	section.rows = {}
	for i = 1, math.min(Num(section.num), SAMPLE) do
		section.rows[i] = Capture("C_CurrencyInfo.GetCurrencyListInfo", i)
	end
	probe.currency = section
	nextStep()
end

local function StepAchievements(nextStep)
	local section = {
		points = Capture("GetTotalAchievementPoints"),
		completed = Capture("GetNumCompletedAchievements"),
		latest = Capture("GetLatestCompletedAchievements"),
		categories = Capture("GetCategoryList"),
	}
	local cats = First(section.categories)
	section.categoryCount = type(cats) == "table" and #cats or nil
	local firstAchievement = section.latest.values and section.latest.values[1]
	if type(firstAchievement) == "number" then
		section.latestInfo = Capture("GetAchievementInfo", firstAchievement)
	end
	probe.achievements = section
	nextStep()
end

local function StepPvp(nextStep)
	probe.pvp = {
		Capture("GetPVPLifetimeStats"),
		Capture("UnitHonor", "player"),
		Capture("UnitHonorLevel", "player"),
	}
	nextStep()
end

local function StepCollections(nextStep)
	local section = {
		numMounts = Capture("C_MountJournal.GetNumMounts"),
		numPets = Capture("C_PetJournal.GetNumPets"),
		toys = Capture("C_ToyBox.GetNumLearnedDisplayedToys"),
	}
	-- Collected mounts: isCollected is return 11 of GetMountInfoByID (doc).
	local ids = First(Capture("C_MountJournal.GetMountIDs"))
	if type(ids) == "table" then
		section.mountIdCount = #ids
		section.collectedMounts = {}
		for _, id in ipairs(ids) do
			local rec = Capture("C_MountJournal.GetMountInfoByID", id)
			if rec.values and rec.values[11] == true and #section.collectedMounts < SAMPLE then
				section.collectedMounts[#section.collectedMounts + 1] = rec
			end
		end
	end
	probe.collections = section
	nextStep()
end

local function StepBags(nextStep)
	local section = { bags = {}, backpackSample = {} }
	for bag = 0, 4 do
		section.bags[#section.bags + 1] = Capture("C_Container.GetContainerNumSlots", bag)
	end
	for slot = 1, math.min(Num(section.bags[1]), SAMPLE) do
		section.backpackSample[#section.backpackSample + 1] = Capture("C_Container.GetContainerItemInfo", 0, slot)
	end
	probe.bags = section
	nextStep()
end

---------------------------------------------------------------------------
-- Legacy (Forever-only): run 1 showed achievements exist and reward
-- "Earn 1 Legacy Point." (GetAchievementInfo return 11), while
-- GetTotalAchievementPoints is 0. ForeverCompanion (LegacyAPI.lua) finds the
-- Legacy tree as a parent category with 8 children, 65 achievements total.
-- Here: every category, every achievement, criteria for unfinished ones.
---------------------------------------------------------------------------
local MAX_CRITERIA = 5

local function StepLegacy(nextStep)
	local section = { categories = {} }
	probe.legacy = section
	local cats = First(Capture("GetCategoryList"))
	if type(cats) ~= "table" then
		section.skipped = "GetCategoryList returned no table"
		return nextStep()
	end
	local achievementCount = 0
	for _, catId in ipairs(cats) do
		local cat = {
			id = catId,
			info = Capture("GetCategoryInfo", catId),
			num = Capture("GetCategoryNumAchievements", catId, true),
			achievements = {},
		}
		for i = 1, Num(cat.num) do
			local a = { info = Capture("GetAchievementInfo", catId, i) }
			local v = a.info.values
			local achievementId, completed = v and v[1], v and v[4]
			if type(achievementId) == "number" and completed ~= true then
				a.numCriteria = Capture("GetAchievementNumCriteria", achievementId)
				a.criteria = {}
				for c = 1, math.min(Num(a.numCriteria), MAX_CRITERIA) do
					a.criteria[c] = Capture("GetAchievementCriteriaInfo", achievementId, c, true)
				end
			end
			cat.achievements[i] = a
			achievementCount = achievementCount + 1
		end
		section.categories[#section.categories + 1] = cat
	end
	section.achievementCount = achievementCount
	nextStep()
end

---------------------------------------------------------------------------
-- Forever rules: experience preset (Enum.ForeverExperiencePreset: Classic 0,
-- Enhanced 1), game mode, hardcore / self-found, every active game rule
-- (Enum.GameRule has 169 values), and the campsite benefit aura
-- (spell 1229741, from ForeverCompanion Data/Camps.lua).
---------------------------------------------------------------------------
local CAMP_AURA_SPELL = 1229741

local function StepForever(nextStep)
	local section = {
		preset = Capture("C_GameRules.GetForeverExperiencePreset"),
		gameMode = Capture("C_GameRules.GetActiveGameMode"),
		gameModeInfo = Capture("C_GameRules.GetCurrentGameModeDisplayInfo"),
		hardcore = Capture("C_GameRules.IsHardcoreActive"),
		selfFound = Capture("C_GameRules.IsSelfFoundAllowed"),
		standard = Capture("C_GameRules.IsStandard"),
		season = Capture("C_SeasonInfo.GetCurrentDisplaySeasonID"),
		seasonExpansion = Capture("C_SeasonInfo.GetCurrentDisplaySeasonExpansion"),
		campAura = Capture("C_UnitAuras.GetPlayerAuraBySpellID", CAMP_AURA_SPELL),
		activeRules = {},
	}
	if type(Enum) == "table" and type(Enum.GameRule) == "table" then
		for ruleName, ruleId in pairs(Enum.GameRule) do
			if First(Capture("C_GameRules.IsGameRuleActive", ruleId)) == true then
				section.activeRules[ruleName] = {
					id = ruleId,
					value = First(Capture("C_GameRules.GetGameRuleAsFloat", ruleId, 2)),
				}
			end
		end
	end
	probe.forever = section
	nextStep()
end

---------------------------------------------------------------------------
-- Level-ups: recorded whenever they happen (not part of a probe run).
-- PLAYER_LEVEL_UP payload starts with the new level (doc).
---------------------------------------------------------------------------
ns.On("PLAYER_LEVEL_UP", function(_, ...)
	SoTCharacterSyncDB = SoTCharacterSyncDB or {}
	SoTCharacterSyncDB.levelUpsSeen = SoTCharacterSyncDB.levelUpsSeen or {}
	table.insert(SoTCharacterSyncDB.levelUpsSeen, {
		at = time(),
		character = UnitName("player"),
		payload = ns.Plain({ ... }),
		unitLevelNow = UnitLevel("player"),
	})
end)

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
	if InCombatLockdown() then
		ns.Print("leave combat first")
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
	ns.Print("probing character APIs (a few seconds)...")
	ns.RunSteps({ StepIdentity, StepPlayed, StepEquipment, StepTalents, StepProfessions, StepStats,
		StepReputation, StepCurrency, StepAchievements, StepLegacy, StepForever, StepPvp, StepCollections, StepBags }, function()
		probe.meta.finishedAt = time()
		local s = { missing = {}, errors = {}, secret = {} }
		Summarize(probe, s)
		probe.summary = s
		SoTCharacterSyncDB = SoTCharacterSyncDB or {}
		SoTCharacterSyncDB.probe = probe
		running = false
		ns.Print(("done. talents: %s selected, professions %d, factions %d, currencies %d, achievements %s."):format(
			tostring(probe.talents.selectedCount), #probe.professions.info,
			Num(probe.reputation.num), Num(probe.currency.num), tostring(probe.legacy.achievementCount)))
		if next(s.missing) then ns.Print("missing: " .. Keys(s.missing)) end
		if next(s.errors) then ns.Print("errors: " .. Keys(s.errors)) end
		if next(s.secret) then ns.Print("secret values from: " .. Keys(s.secret)) end
		ns.Print("now /reload to save.")
	end)
end
