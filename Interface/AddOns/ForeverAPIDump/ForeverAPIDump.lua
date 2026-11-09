-- ForeverAPIDump
-- Usage: /apidump  -> collects API data into ForeverAPIDumpDB
--        /reload   -> WoW writes WTF/Account/<acc>/SavedVariables/ForeverAPIDump.lua
-- Then run: python tools/forever-api/convert.py

local ADDON_NAME = ...
local PREFIX = "|cff33ff99ForeverAPIDump|r: "

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(msg))
end

local function SortedKeys(t)
	local keys = {}
	for k in pairs(t) do
		if type(k) == "string" then
			keys[#keys + 1] = k
		end
	end
	table.sort(keys)
	return keys
end

-- Deep copy of plain data only (strings/numbers/booleans/tables).
-- Functions and back-references (e.g. .System) are dropped; cycles are cut.
local SKIP_KEYS = { System = true }

local function Copy(v, seen, depth)
	local t = type(v)
	if t == "string" or t == "number" or t == "boolean" then
		return v
	end
	if t ~= "table" or depth > 12 or seen[v] then
		return nil
	end
	seen[v] = true
	local out = {}
	for k, val in pairs(v) do
		local kt = type(k)
		if (kt == "string" or kt == "number") and not SKIP_KEYS[k] then
			local c = Copy(val, seen, depth + 1)
			if c ~= nil then
				out[k] = c
			end
		end
	end
	seen[v] = nil
	return out
end

local function LoadAddOnSafe(name)
	local load = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
	if not load then
		return false, "no LoadAddOn"
	end
	local ok, loaded, reason = pcall(load, name)
	if not ok then
		return false, tostring(loaded)
	end
	return loaded and true or false, reason
end

---------------------------------------------------------------------------
-- 1) Blizzard_APIDocumentation (full signatures, events, enums, structures)
---------------------------------------------------------------------------
local function DumpDocumentation(db)
	local status = {}
	for _, name in ipairs({ "Blizzard_APIDocumentationGenerated", "Blizzard_APIDocumentation" }) do
		local loaded, reason = LoadAddOnSafe(name)
		status[name] = loaded and "loaded" or ("failed: " .. tostring(reason))
	end
	db.docStatus = status

	if type(APIDocumentation) ~= "table" or type(APIDocumentation.systems) ~= "table" then
		db.docStatus.result = "APIDocumentation not available"
		return 0
	end

	local systems = {}
	for _, system in ipairs(APIDocumentation.systems) do
		local c = Copy(system, {}, 0)
		if c then
			systems[#systems + 1] = c
		end
	end
	db.systems = systems
	db.docStatus.result = "ok"
	return #systems
end

---------------------------------------------------------------------------
-- 2) Everything that exists in _G (undocumented functions included)
---------------------------------------------------------------------------
local LUA_LIBS = { "string", "table", "math", "os", "bit", "coroutine", "debug" }

local function DumpGlobals(db)
	local functions, namespaces, libs = {}, {}, {}
	local isLib = {}
	for _, n in ipairs(LUA_LIBS) do isLib[n] = true end

	for _, k in ipairs(SortedKeys(_G)) do
		local ok, v = pcall(rawget, _G, k)
		if ok then
			local t = type(v)
			if t == "function" then
				functions[#functions + 1] = k
			elseif t == "table" and k:match("^C_") then
				local ns = {}
				for _, fk in ipairs(SortedKeys(v)) do
					ns[fk] = type(v[fk])
				end
				namespaces[k] = ns
			elseif t == "table" and isLib[k] then
				local lib = {}
				for _, fk in ipairs(SortedKeys(v)) do
					lib[#lib + 1] = fk
				end
				libs[k] = lib
			end
		end
	end

	db.globalFunctions = functions
	db.namespaces = namespaces
	db.luaLibs = libs
	db.Enum = Copy(Enum, {}, 0)
	db.Constants = Copy(Constants, {}, 0)
	return #functions
end

---------------------------------------------------------------------------
-- 3) Widget methods from real objects
---------------------------------------------------------------------------
local FRAME_TYPES = {
	"Frame", "Button", "CheckButton", "EditBox", "ScrollFrame", "Slider", "StatusBar",
	"Cooldown", "GameTooltip", "MessageFrame", "ScrollingMessageFrame", "SimpleHTML",
	"Model", "PlayerModel", "DressUpModel", "CinematicModel", "TabardModel", "ModelScene",
	"ColorSelect", "MovieFrame", "FogOfWarFrame", "UnitPositionFrame",
}
local ANIM_TYPES = {
	"Alpha", "Translation", "LineTranslation", "Scale", "LineScale", "Rotation",
	"Path", "FlipBook", "TextureCoordTranslation", "VertexColor",
}

local function Methods(obj)
	local mt = getmetatable(obj)
	local index = mt and mt.__index
	if type(index) ~= "table" then
		return nil
	end
	local list = {}
	for _, k in ipairs(SortedKeys(index)) do
		if type(index[k]) == "function" then
			list[#list + 1] = k
		end
	end
	return list
end

local function DumpWidgets(db)
	local widgets, failed = {}, {}
	local function Add(name, ok, obj)
		if ok and obj then
			widgets[name] = Methods(obj)
		else
			failed[#failed + 1] = name
		end
	end

	local parent = CreateFrame("Frame", nil, UIParent)
	parent:Hide()

	for _, ft in ipairs(FRAME_TYPES) do
		Add(ft, pcall(CreateFrame, ft, nil, parent))
	end
	Add("Texture", pcall(parent.CreateTexture, parent))
	Add("FontString", pcall(parent.CreateFontString, parent))
	Add("Line", pcall(parent.CreateLine, parent))
	Add("MaskTexture", pcall(parent.CreateMaskTexture, parent))
	Add("Font", pcall(CreateFont, "ForeverAPIDumpFont"))

	local okAG, ag = pcall(parent.CreateAnimationGroup, parent)
	Add("AnimationGroup", okAG, ag)
	if okAG and ag then
		Add("Animation", pcall(ag.CreateAnimation, ag))
		for _, at in ipairs(ANIM_TYPES) do
			local ok, anim = pcall(ag.CreateAnimation, ag, at)
			Add(at, ok, anim)
			if ok and anim and at == "Path" then
				Add("ControlPoint", pcall(anim.CreateControlPoint, anim))
			end
		end
	end

	db.widgets = widgets
	db.widgetsFailed = failed
end

---------------------------------------------------------------------------
local function Run()
	if InCombatLockdown() then
		Print("Leave combat first.")
		return
	end
	local db = {}
	local version, build, date, toc = GetBuildInfo()
	db.meta = {
		version = version, build = build, buildDate = date, toc = toc,
		projectID = WOW_PROJECT_ID, dumpedAt = time(), addonVersion = "1.0.0",
	}

	local nSys = DumpDocumentation(db)
	local nFn = DumpGlobals(db)
	DumpWidgets(db)

	ForeverAPIDumpDB = db
	Print(("Done. Build %s (%s), toc %s. Doc systems: %d (%s). Global functions: %d.")
		:format(tostring(version), tostring(build), tostring(toc), nSys, tostring(db.docStatus.result), nFn))
	Print("Now type /reload (or log out) to write the SavedVariables file.")
end

SLASH_FOREVERAPIDUMP1 = "/apidump"
SlashCmdList.FOREVERAPIDUMP = Run
