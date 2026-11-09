-- SoTCharacterSync export: one entry per guild character on this account,
-- in SoTCharacterSyncDB.characters (keyed by full name "First Last") plus
-- SoTCharacterSyncDB.json for the launcher.
--
-- Scope (decided 2026-11-09): gear, talents, professions, stats,
-- reputations, currencies, collections, Legacy, PvP. No bags, no bank.
-- Every API and shape below was measured by probe runs 1-3
-- (web/docs/FOREVER_PLAN.md, "SoTCharacterSync"). Field names follow the
-- WotLK addon where the meaning is the same.

local _, ns = ...

local TARGET_GUILD = "Stalkers of Time"
local DEBOUNCE = 5 -- seconds: many events fire together (login, gear swap)
local MAJOR_FACTION_PVP_RANK = 2800 -- "PvP Rank Points": renown level = honor rank 0-14
local MAJOR_FACTION_LEGACY = 2802 -- "Legacy Track": level 1-90
local HONOR_CURRENCY = 1792

local ITEM_QUALITY_NAMES = {
	[0] = "Poor", [1] = "Common", [2] = "Uncommon", [3] = "Rare",
	[4] = "Epic", [5] = "Legendary", [6] = "Artifact", [7] = "Heirloom",
}

local played -- { total, level, at } from TIME_PLAYED_MSG, once per login

-- Value or nil when secret.
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

---------------------------------------------------------------------------
-- Identity. UnitName returns first and last name separately (measured).
---------------------------------------------------------------------------
local function FullName()
	local first, last = UnitName("player")
	first, last = S(first), S(last)
	if not first then
		return nil
	end
	if last and last ~= "" then
		return first .. " " .. last
	end
	return first
end

local GENDERS = { [2] = "Male", [3] = "Female" }

---------------------------------------------------------------------------
-- Gear: GetInventoryItemLink + C_Item.GetItemInfo (no global GetItemInfo
-- on Forever) + C_Item.GetDetailedItemLevelInfo (real item level).
-- GetAverageItemLevel is broken (always /16), so averageItemLevel is ours.
---------------------------------------------------------------------------
local function CollectEquipment()
	local items, sum, count = {}, 0, 0
	for slot = 1, 19 do
		local link = S(GetInventoryItemLink("player", slot))
		local itemId, enchantId = link and link:match("item:(%d+):(%d*)")
		if itemId then
			local name, _, quality, _, _, itemType, itemSubType, _, equipLoc, icon = C_Item.GetItemInfo(link)
			local itemLevel = C_Item.GetDetailedItemLevelInfo(link)
			local gemIds = {}
			for i = 1, 4 do
				local _, gemLink = C_Item.GetItemGem(link, i)
				local gemId = gemLink and gemLink:match("item:(%d+)")
				gemIds[i] = tonumber(gemId) or 0
			end
			local current, maximum = GetInventoryItemDurability(slot)
			items[#items + 1] = {
				slot = slot,
				itemId = tonumber(itemId),
				enchantId = tonumber(enchantId) or 0,
				gemIds = gemIds,
				name = S(name),
				level = S(itemLevel),
				quality = quality and ITEM_QUALITY_NAMES[quality] or nil,
				itemType = S(itemType),
				itemSubType = S(itemSubType),
				equipLocType = equipLoc and (equipLoc:gsub("^INVTYPE_", "")) or nil,
				equipLocName = equipLoc and _G[equipLoc] or nil,
				iconId = S(icon), -- Forever returns a file ID, not a path
				link = link,
				durability = current and { current = current, max = maximum } or nil,
			}
			-- Shirt (4) and tabard (19) don't count toward item level.
			if slot ~= 4 and slot ~= 19 and type(itemLevel) == "number" then
				sum, count = sum + itemLevel, count + 1
			end
		end
	end
	local average = count > 0 and math.floor(sum / count * 100 + 0.5) / 100 or nil
	return items, average
end

---------------------------------------------------------------------------
-- Talents: one spec per class (measured). Trait tree via the active config;
-- selected node -> activeEntry -> definitionID -> spellID (measured).
-- Shape matches the website's Forever handling (web commit c7344250):
-- talents.first_points = { format = "trait", configId, importString, selected }.
---------------------------------------------------------------------------
local function CollectTalents()
	local specIndex = C_SpecializationInfo.GetSpecialization()
	local specId, specName, _, _, role
	if type(specIndex) == "number" then
		specId, specName, _, _, role = C_SpecializationInfo.GetSpecializationInfo(specIndex)
	end
	local talents = { first_tree = S(specName), active_group = 1, specId = S(specId), role = S(role) }
	local configId = C_ClassTalents.GetActiveConfigID()
	if not configId then
		return talents -- below ~level 11 there is no config (GuildArmory)
	end
	local selected = {}
	local info = C_Traits.GetConfigInfo(configId)
	local treeId = info and info.treeIDs and info.treeIDs[1]
	local nodes = treeId and C_Traits.GetTreeNodes(treeId) or {}
	for _, nodeId in ipairs(nodes) do
		local node = C_Traits.GetNodeInfo(configId, nodeId)
		if node and (node.ranksPurchased or 0) > 0 and node.activeEntry then
			local entry = C_Traits.GetEntryInfo(configId, node.activeEntry.entryID)
			local definition = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
			selected[#selected + 1] = {
				nodeId = nodeId,
				entryId = node.activeEntry.entryID,
				rank = node.activeEntry.rank,
				maxRanks = node.maxRanks,
				spellId = definition and definition.spellID or nil,
			}
		end
	end
	talents.first_points = {
		format = "trait",
		configId = configId,
		treeId = treeId,
		importString = NonEmpty(C_Traits.GenerateImportString(configId)),
		selected = selected,
	}
	return talents
end

---------------------------------------------------------------------------
-- Professions: GetProfessions positions 1-2 primary, 3 archaeology,
-- 4 fishing, 5 cooking (measured). Own skill levels are real (unlike the
-- guild roster). WotLK-shaped keys plus a full list.
---------------------------------------------------------------------------
local function CollectProfessions()
	local result = { list = {} }
	local indexes = { GetProfessions() }
	for position = 1, 7 do
		local index = indexes[position]
		if type(index) == "number" then
			local name, _, skill, maxSkill, _, _, skillLine = GetProfessionInfo(index)
			name = S(name)
			if name then
				result.list[#result.list + 1] = {
					position = position, name = name, skillLine = S(skillLine),
					skill = S(skill), maxSkill = S(maxSkill),
				}
				if position == 1 then
					result.first, result.firstSkill = name, S(skill)
				elseif position == 2 then
					result.second, result.secondSkill = name, S(skill)
				elseif position == 4 then
					result.fishing = S(skill)
				elseif position == 5 then
					result.cooking = S(skill)
				end
			end
		end
	end
	return result
end

---------------------------------------------------------------------------
-- Stats (measured run 1). Kept under stats.first_stats like WotLK.
---------------------------------------------------------------------------
local function CollectStats()
	local function stat(i)
		return S((UnitStat("player", i)))
	end
	local base, effectiveArmor = UnitArmor("player")
	local apBase, apPos, apNeg = UnitAttackPower("player")
	local rapBase, rapPos, rapNeg = UnitRangedAttackPower("player")
	local _, powerToken = UnitPowerType("player")
	return {
		first_stats = {
			strength = stat(1), agility = stat(2), stamina = stat(3),
			intellect = stat(4), spirit = stat(5),
			armor = S(effectiveArmor) or S(base),
			health = S(UnitHealthMax("player")),
			powerType = S(powerToken),
			power = S(UnitPowerMax("player")),
			attackPower = apBase and (apBase + (apPos or 0) + (apNeg or 0)) or nil,
			rangedAttackPower = rapBase and (rapBase + (rapPos or 0) + (rapNeg or 0)) or nil,
			crit = S(GetCritChance()),
			rangedCrit = S(GetRangedCritChance()),
			spellCrit = S(GetSpellCritChance(2)),
			spellPower = S(GetSpellBonusDamage(2)),
			healing = S(GetSpellBonusHealing()),
			haste = S(GetHaste()),
			hit = S(GetHitModifier()),
			spellHit = S(GetSpellHitModifier()),
			dodge = S(GetDodgeChance()),
			parry = S(GetParryChance()),
			block = S(GetBlockChance()),
		},
	}
end

---------------------------------------------------------------------------
-- Reputation (measured): every row, headers included, after expanding all
-- headers (collapsed headers hide their children). WotLK keys name /
-- standing / value / max, plus factionId and threshold.
---------------------------------------------------------------------------
local function CollectReputation()
	-- Expand only when something is collapsed: expanding can fire
	-- UPDATE_FACTION, which would schedule another save (see ScheduleSave).
	for i = 1, C_Reputation.GetNumFactions() do
		local f = C_Reputation.GetFactionDataByIndex(i)
		if f and f.isHeader and f.isCollapsed then
			C_Reputation.ExpandAllFactionHeaders()
			break
		end
	end
	local rows = {}
	for i = 1, C_Reputation.GetNumFactions() do
		local f = C_Reputation.GetFactionDataByIndex(i)
		if f and S(f.name) then
			rows[#rows + 1] = {
				name = f.name,
				factionId = S(f.factionID),
				standing = S(f.reaction),
				value = S(f.currentStanding),
				min = S(f.currentReactionThreshold),
				max = S(f.nextReactionThreshold),
				isHeader = f.isHeader and true or false,
				isChild = f.isChild and true or false,
				atWar = f.atWarWith and true or false,
			}
		end
	end
	return rows
end

---------------------------------------------------------------------------
-- Currency (measured): list rows have no ID, so it comes from the row link.
-- Honor is its own currency (1792, measured).
---------------------------------------------------------------------------
local function CollectCurrency()
	local items = {}
	for i = 1, C_CurrencyInfo.GetCurrencyListSize() do
		local c = C_CurrencyInfo.GetCurrencyListInfo(i)
		if c and not c.isHeader and S(c.name) then
			local link = C_CurrencyInfo.GetCurrencyListLink(i)
			items[#items + 1] = {
				name = c.name,
				currencyId = link and C_CurrencyInfo.GetCurrencyIDFromLink(link) or nil,
				count = S(c.quantity),
				max = S(c.maxQuantity),
			}
		end
	end
	local honor = C_CurrencyInfo.GetCurrencyInfo(HONOR_CURRENCY)
	return { honor = honor and S(honor.quantity) or nil, items = items }
end

---------------------------------------------------------------------------
-- Collections: collected mount IDs (isCollected = return 11, doc), pet and
-- toy counts.
---------------------------------------------------------------------------
local function CollectCollections()
	local mounts = {}
	for _, id in ipairs(C_MountJournal.GetMountIDs() or {}) do
		local isCollected = select(11, C_MountJournal.GetMountInfoByID(id))
		if isCollected == true then
			mounts[#mounts + 1] = id
		end
	end
	local _, petsOwned = C_PetJournal.GetNumPets()
	return {
		mountIds = mounts,
		petsOwned = S(petsOwned),
		toys = S(C_ToyBox.GetNumLearnedDisplayedToys()),
	}
end

---------------------------------------------------------------------------
-- Legacy (measured run 2): the whole achievement list is Legacy, 1 Legacy
-- Point each. GetAchievementInfo(category, index): id, name, points,
-- completed, month, day, year (2-digit), description, flags, icon, reward.
-- The "Legacy Track" major faction (2802) level is exported next to it;
-- whether it equals the points is not confirmed yet.
---------------------------------------------------------------------------
local function CollectLegacy()
	local categories, achievements, completedCount = {}, {}, 0
	for _, catId in ipairs(GetCategoryList() or {}) do
		local title, parentId = GetCategoryInfo(catId)
		categories[#categories + 1] = { id = catId, title = S(title), parentId = S(parentId) }
		for i = 1, (GetCategoryNumAchievements(catId, true)) or 0 do
			local id, name, _, completed, month, day, year, _, _, _, reward = GetAchievementInfo(catId, i)
			if type(id) == "number" then
				local a = { id = id, categoryId = catId, name = S(name), completed = completed == true, reward = NonEmpty(reward) }
				if a.completed then
					completedCount = completedCount + 1
					if year and month and day then
						a.completedOn = string.format("%04d-%02d-%02d", 2000 + year, month, day)
					end
				else
					a.criteria = {}
					for c = 1, GetAchievementNumCriteria(id) or 0 do
						local text, _, done, quantity, required = GetAchievementCriteriaInfo(id, c, true)
						a.criteria[c] = { text = S(text), done = done == true, quantity = S(quantity), required = S(required) }
					end
				end
				achievements[#achievements + 1] = a
			end
		end
	end
	local track = C_MajorFactions.GetMajorFactionData(MAJOR_FACTION_LEGACY)
	return {
		completed = completedCount,
		total = #achievements,
		trackLevel = track and S(track.renownLevel) or nil,
		trackMax = track and S(track.maxLevel) or nil,
		categories = categories,
		achievements = achievements,
	}
end

---------------------------------------------------------------------------
-- PvP (measured run 3): honor rank is the "PvP Rank Points" major faction
-- (2800): renown level = rank 0-14, 750 points per level, weekly progressive
-- cap (weekNumber, currentWeekProgressiveMaxLevel). GetPVPLifetimeStats =
-- lifetime HK + highest rank (Enum.PvPRanks: Rank_1 = 5 .. Rank_14 = 18).
---------------------------------------------------------------------------
local function CollectPvp()
	local lifetimeHK, highestRankEnum = GetPVPLifetimeStats()
	local rank = C_MajorFactions.GetMajorFactionProgressionInfo(MAJOR_FACTION_PVP_RANK)
	highestRankEnum = S(highestRankEnum)
	return {
		lifetimeHonorableKills = S(lifetimeHK),
		highestRank = (type(highestRankEnum) == "number" and highestRankEnum >= 5) and (highestRankEnum - 4) or 0,
		rank = rank and S(rank.renownLevel) or nil,
		rankPoints = rank and S(rank.renownReputationEarned) or nil,
		rankPointsToNext = rank and S(rank.renownLevelThreshold) or nil,
		rankMax = rank and S(rank.maxLevel) or nil,
		weekNumber = rank and S(rank.weekNumber) or nil,
		weekMaxRank = rank and S(rank.currentWeekProgressiveMaxLevel) or nil,
		honor = S(UnitHonor("player")),
		honorMax = S(UnitHonorMax("player")),
		honorLevel = S(UnitHonorLevel("player")),
		pvpName = NonEmpty(UnitPVPName("player")),
	}
end

---------------------------------------------------------------------------
local lastSaveAt = 0 -- GetTime() of the last save

local function InTargetGuild()
	local guildName = GetGuildInfo("player")
	return S(guildName) == TARGET_GUILD
end

function ns.CollectCharacter()
	local name = FullName()
	if not name then
		return nil
	end
	local _, classFile, classId = UnitClass("player")
	local _, raceFile, raceId = UnitRace("player")
	local _, guildRank, guildRankIndex = GetGuildInfo("player")
	local lifetimeHK = GetPVPLifetimeStats()
	local equipment, averageItemLevel = CollectEquipment()
	local db = SoTCharacterSyncDB
	local levelUps = db.levelUps and db.levelUps[name] or {}
	return {
		-- WotLK-compatible
		name = name,
		class = S(classFile),
		race = S(raceFile),
		gender = GENDERS[UnitSex("player")],
		guildRank = S(guildRank),
		guildRankIndex = S(guildRankIndex),
		level = S(UnitLevel("player")),
		gold = S(GetMoney()), -- copper
		equipment = { first_equipment = equipment },
		talents = CollectTalents(),
		honorableKills = S(lifetimeHK),
		achievementPoints = 0, -- always 0 on Forever; Legacy replaces it
		stats = CollectStats(),
		professions = CollectProfessions(),
		reputation = CollectReputation(),
		currency = CollectCurrency(),
		levelUps = levelUps,
		updatedAt = time(),
		-- Forever additions
		guid = S(UnitGUID("player")),
		classId = S(classId),
		raceId = S(raceId),
		realm = GetRealmName(),
		averageItemLevel = averageItemLevel,
		xp = { current = S(UnitXP("player")), max = S(UnitXPMax("player")), rested = S(GetXPExhaustion()) },
		played = played,
		preset = S(C_GameRules.GetForeverExperiencePreset()), -- Enum: 0 Classic, 1 Enhanced
		legacy = CollectLegacy(),
		pvp = CollectPvp(),
		collections = CollectCollections(),
	}
end

-- Adds or refreshes this character's entry. Never removes one: at logout
-- the client already reports "not in guild" (measured for SoTGuildSync),
-- so a missing guild is never treated as "left the guild" here. The
-- guild roster sync tells the site who is still a member.
local function Save(trigger)
	if not InTargetGuild() then
		return false
	end
	local ok, character = pcall(ns.CollectCharacter)
	if not ok then
		ns.Print("export failed: " .. tostring(character))
		return false
	end
	if not character or not character.level then
		return false
	end
	character.trigger = trigger
	lastSaveAt = GetTime()
	SoTCharacterSyncDB.characters = SoTCharacterSyncDB.characters or {}
	SoTCharacterSyncDB.characters[character.name] = character
	SoTCharacterSyncDB.json = ns.EncodeJSON(SoTCharacterSyncDB.characters)
	return true, character
end
ns.SaveCharacter = Save

local pending = false
local function ScheduleSave(trigger)
	-- Events caused by our own save (e.g. UPDATE_FACTION after expanding
	-- reputation headers) must not schedule the next one.
	if pending or GetTime() - lastSaveAt < 2 then
		return
	end
	pending = true
	C_Timer.After(DEBOUNCE, function()
		pending = false
		Save(trigger)
	end)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
ns.On("PLAYER_ENTERING_WORLD", function(_, isInitialLogin, isReloadingUi)
	SoTCharacterSyncDB = SoTCharacterSyncDB or {}
	if isInitialLogin or isReloadingUi then
		-- Prints "Total time played" to chat, once per login/reload.
		RequestTimePlayed()
	end
	ScheduleSave("PLAYER_ENTERING_WORLD")
end)

ns.On("TIME_PLAYED_MSG", function(_, total, thisLevel)
	played = { total = S(total), level = S(thisLevel), at = time() }
	ScheduleSave("TIME_PLAYED_MSG")
end)

-- PLAYER_LEVEL_UP payload starts with the new level (doc).
ns.On("PLAYER_LEVEL_UP", function(_, newLevel)
	local name = FullName()
	newLevel = S(newLevel)
	if name and type(newLevel) == "number" then
		SoTCharacterSyncDB.levelUps = SoTCharacterSyncDB.levelUps or {}
		SoTCharacterSyncDB.levelUps[name] = SoTCharacterSyncDB.levelUps[name] or {}
		table.insert(SoTCharacterSyncDB.levelUps[name], { level = newLevel, achievedAt = time() })
	end
	ScheduleSave("PLAYER_LEVEL_UP")
end)

for _, event in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "TRAIT_CONFIG_UPDATED", "SKILL_LINES_CHANGED",
	"PLAYER_MONEY", "UPDATE_FACTION", "CURRENCY_DISPLAY_UPDATE", "ACHIEVEMENT_EARNED",
	"NEW_MOUNT_ADDED", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "PLAYER_GUILD_UPDATE", "PLAYER_XP_UPDATE" }) do
	ns.On(event, function()
		ScheduleSave(event)
	end)
end

ns.commands.export = function()
	local ok, c = Save("manual")
	if ok then
		ns.Print(("saved %s: level %s, %d items, %d talents, %d/%d Legacy, rank %s. /reload to write it."):format(
			c.name, tostring(c.level), #c.equipment.first_equipment,
			#(c.talents.first_points and c.talents.first_points.selected or {}),
			c.legacy.completed, c.legacy.total, tostring(c.pvp.rank)))
	else
		ns.Print("not saved (only characters in " .. TARGET_GUILD .. ")")
	end
end
