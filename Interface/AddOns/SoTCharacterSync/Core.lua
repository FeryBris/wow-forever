-- SoTCharacterSync: shared helpers (same as SoTGuildSync Core.lua).
-- Files share code through the addon's private table (ns); the only global
-- is the SavedVariables table SoTCharacterSyncDB.

local ADDON_NAME, ns = ...

-- Hardcoded, not read from the TOC: the client caches TOC metadata until a
-- full restart, so after /reload it would report a stale version.
ns.VERSION = "0.4.0"

local PREFIX = "|cff69ccf0SoT Character Sync|r: "

function ns.Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(msg))
end

---------------------------------------------------------------------------
-- Secret values (12.0 restriction, Forever runs the retail system): a secret
-- may be passed around but not read, compared or indexed. issecretvalue
-- (doc) tells them apart. Pattern from GuildOS Core/Compat.lua.
---------------------------------------------------------------------------
function ns.IsSecret(v)
	return issecretvalue ~= nil and issecretvalue(v) and true or false
end

-- Resolves "C_GuildInfo.GetMOTD" or "GetGuildInfo" to the function, or nil.
-- Looking APIs up by name lets the probe record a missing one instead of erroring.
function ns.Resolve(path)
	local obj = _G
	for part in string.gmatch(path, "[^.]+") do
		if type(obj) ~= "table" then
			return nil
		end
		obj = obj[part]
	end
	if type(obj) == "function" then
		return obj
	end
	return nil
end

-- Plain-data copy for SavedVariables. Secrets become "<secret>", functions
-- and userdata become their type name, cycles are cut.
local function Plain(v, seen, depth)
	if ns.IsSecret(v) then
		return "<secret>"
	end
	local t = type(v)
	if t == "string" or t == "number" or t == "boolean" or t == "nil" then
		return v
	end
	if t ~= "table" then
		return "<" .. t .. ">"
	end
	if depth > 6 or seen[v] then
		return "<cycle>"
	end
	seen[v] = true
	local out = {}
	for k, val in pairs(v) do
		if not ns.IsSecret(k) then
			out[k] = Plain(val, seen, depth + 1)
		end
	end
	seen[v] = nil
	return out
end

function ns.Plain(v)
	return Plain(v, {}, 0)
end

-- Keeps trailing nils countable (select("#") counts them; # does not).
local function Pack(...)
	return { n = select("#", ...), ... }
end

-- Calls an API by name and records exactly what came back:
--   { api, args, n = number of returns, values = {...}, types = {...} }
-- or { api, missing = true } / { api, error = "..." }.
-- types[i] is the Lua type or "secret", so nil holes and secrets stay visible.
function ns.Capture(path, ...)
	local rec = { api = path }
	if select("#", ...) > 0 then
		rec.args = ns.Plain({ ... })
	end
	local fn = ns.Resolve(path)
	if not fn then
		rec.missing = true
		return rec
	end
	local r = Pack(pcall(fn, ...))
	if not r[1] then
		rec.error = tostring(r[2])
		return rec
	end
	rec.n = r.n - 1
	rec.values, rec.types = {}, {}
	for i = 2, r.n do
		local v = r[i]
		rec.types[i - 1] = ns.IsSecret(v) and "secret" or type(v)
		rec.values[i - 1] = ns.Plain(v)
	end
	return rec
end

-- First return value of a capture (nil if missing, failed or secret).
function ns.First(rec)
	if rec.values and rec.types and rec.types[1] ~= "secret" then
		return rec.values[1]
	end
	return nil
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
local handlers = {}

frame:SetScript("OnEvent", function(_, event, ...)
	local list = handlers[event]
	if not list then
		return
	end
	for i = #list, 1, -1 do
		list[i](event, ...)
	end
end)

function ns.On(event, fn)
	if not handlers[event] then
		handlers[event] = {}
		local ok = pcall(frame.RegisterEvent, frame, event)
		if not ok then
			ns.Print("cannot register event " .. event)
		end
	end
	table.insert(handlers[event], fn)
end

function ns.Off(event, fn)
	local list = handlers[event]
	if not list then
		return
	end
	for i = #list, 1, -1 do
		if list[i] == fn then
			table.remove(list, i)
		end
	end
	if #list == 0 then
		handlers[event] = nil
		frame:UnregisterEvent(event)
	end
end

-- Calls cb(true, ...) when the event fires, or cb(false) after `timeout`
-- seconds. The Query*/GuildRoster APIs answer asynchronously this way.
-- If cb errors, onError is called (pass the step's nextStep so a run continues).
function ns.WaitFor(event, timeout, cb, onError)
	local done = false
	local handler
	local function finish(fired, ...)
		if done then
			return
		end
		done = true
		ns.Off(event, handler)
		local ok, err = pcall(cb, fired, ...)
		if not ok then
			ns.Print("error after " .. event .. ": " .. tostring(err))
			if onError then
				onError()
			end
		end
	end
	handler = function(_, ...)
		finish(true, ...)
	end
	ns.On(event, handler)
	C_Timer.After(timeout, function()
		finish(false)
	end)
end

-- Runs async steps in order; each step is function(nextStep).
function ns.RunSteps(steps, done)
	local i = 0
	local function nextStep()
		i = i + 1
		local step = steps[i]
		if not step then
			if done then
				done()
			end
			return
		end
		local ok, err = pcall(step, nextStep)
		if not ok then
			ns.Print("step " .. i .. " failed: " .. tostring(err))
			nextStep()
		end
	end
	nextStep()
end

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------
ns.commands = {}

SLASH_SOTCHARSYNC1 = "/sotchar"
SlashCmdList.SOTCHARSYNC = function(msg)
	local cmd = string.lower(string.match(msg or "", "^%s*(%S*)") or "")
	local fn = ns.commands[cmd]
	if fn then
		fn(msg)
	else
		ns.Print("commands: /sotchar status, /sotchar export (save now), /sotchar probe (diagnostics)")
	end
end

ns.commands.status = function()
	local db = SoTCharacterSyncDB or {}
	ns.Print("version " .. ns.VERSION)
	local count = 0
	for name, c in pairs(db.characters or {}) do
		count = count + 1
		ns.Print(("  %s: level %s, saved %s (%s)"):format(name, tostring(c.level),
			date("%Y-%m-%d %H:%M", c.updatedAt), tostring(c.trigger)))
	end
	if count == 0 then
		ns.Print("no characters saved yet (only characters in the guild are saved)")
	end
end

ns.On("PLAYER_LOGIN", function()
	SoTCharacterSyncDB = SoTCharacterSyncDB or {}
end)
