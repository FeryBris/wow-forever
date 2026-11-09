-- Minimal encode-only JSON encoder (ported from the WotLK SoTGuildSync).
-- The launcher reads SoTGuildSyncDB.json; nothing here ever decodes JSON.

local _, ns = ...

local ESCAPES = {
	['"'] = '\\"',
	['\\'] = '\\\\',
	['\n'] = '\\n',
	['\r'] = '\\r',
	['\t'] = '\\t',
}

local function encodeString(s)
	local escaped = tostring(s):gsub('[%c"\\]', function(c)
		return ESCAPES[c] or string.format("\\u%04x", string.byte(c))
	end)
	return '"' .. escaped .. '"'
end

local function isArray(t)
	local count = 0
	for _ in pairs(t) do
		count = count + 1
	end
	if count == 0 then
		return true -- empty tables become empty arrays
	end
	for i = 1, count do
		if t[i] == nil then
			return false
		end
	end
	return true
end

local encodeValue

local function encodeArray(t)
	local parts = {}
	for i = 1, #t do
		parts[i] = encodeValue(t[i])
	end
	return '[' .. table.concat(parts, ',') .. ']'
end

local function encodeObject(t)
	local parts = {}
	local n = 0
	for k, v in pairs(t) do
		n = n + 1
		parts[n] = encodeString(k) .. ':' .. encodeValue(v)
	end
	return '{' .. table.concat(parts, ',') .. '}'
end

encodeValue = function(v)
	local vt = type(v)
	if vt == 'string' then
		return encodeString(v)
	elseif vt == 'number' then
		if v ~= v or v == math.huge or v == -math.huge then
			return 'null'
		end
		return tostring(v)
	elseif vt == 'boolean' then
		return v and 'true' or 'false'
	elseif vt == 'table' then
		if isArray(v) then
			return encodeArray(v)
		end
		return encodeObject(v)
	end
	return 'null'
end

ns.EncodeJSON = encodeValue
