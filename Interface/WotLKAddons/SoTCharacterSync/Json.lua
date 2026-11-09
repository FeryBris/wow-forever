-- Minimal encode-only JSON encoder for SoTCharacterSync.
-- Only ever writes data out; nothing in this addon ever needs to read
-- JSON back in, so there is no decoder.

local ESCAPES = {
  ['"'] = '\\"',
  ['\\'] = '\\\\',
  ['\n'] = '\\n',
  ['\r'] = '\\r',
  ['\t'] = '\\t',
}

local function encodeString(s)
  return '"' .. tostring(s):gsub('[%c"\\]', ESCAPES) .. '"'
end

local function isArray(t)
  local count = 0
  for _ in pairs(t) do
    count = count + 1
  end
  if count == 0 then
    return true -- treat empty tables as empty arrays
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
      return '0' -- NaN/inf can't happen from the game API values we send, guard anyway
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
  return 'null' -- nil and anything else (function, userdata) we never pass in
end

function SoTCharacterSync_EncodeJSON(value)
  return encodeValue(value)
end
