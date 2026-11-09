-- Turning a table into a string that survives a chat box, and back again.
--
-- Written by hand rather than with LibSerialize and LibDeflate, which is what
-- WeakAuras and DBM both do. LibDeflate is GPLv3 -- measured from the copy
-- shipped on this client, not remembered -- and a work combining it would have
-- to be GPL too. LibSerialize beside it is MIT and would be allowed, but it
-- would be the first embedded library in the project, and a profile is a few
-- hundred bytes: there is nothing here worth compressing.
--
-- The format is length-prefixed rather than delimited, because a delimiter can
-- turn up inside a value and a length cannot:
--
--   T<count>:           a table, followed by <count> key and value pairs
--   S<length>:<bytes>   a string, escaped first (see Escape)
--   N<number>;          a number
--   B0 / B1             false / true
--
-- The whole payload is printable ASCII. That matters for one reason above all:
-- the pipe character opens a color escape in WoW's text handling and would be
-- swallowed on the way through a chat frame.

local ADDON, FP = ...
local L = FP.L

local PREFIX    = "FP1"
local MAX_DEPTH = 8     -- our settings are three deep; this is a guard, not a limit

-- ---------------------------------------------------------------------------
-- Escaping
-- ---------------------------------------------------------------------------

local function Escape(text)
    -- The percent sign first, or the escapes added below would be escaped a
    -- second time and decode to the wrong thing.
    text = text:gsub("%%", "%%25")
    text = text:gsub("|", "%%7C")
    -- Printable ASCII *without* the space: copying and pasting adds line breaks
    -- and spaces of its own, so the decoder throws all whitespace away before
    -- it reads anything. A space that survived escaping would be destroyed by
    -- that, and a profile called "My Raid Setup" would never import.
    text = text:gsub("[^!-~]", function(c)
        return string.format("%%%02X", c:byte())
    end)
    return text
end

local function Unescape(text)
    -- One left-to-right pass handles both layers: "%2541" was a literal "%41"
    -- before escaping and becomes one again here.
    return (text:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end))
end

-- ---------------------------------------------------------------------------
-- Checksum
--
-- djb2, kept in plain arithmetic rather than the bit library: every
-- intermediate stays below 2^53, where a double is still exact, so this gives
-- the same answer on any Lua build.
-- ---------------------------------------------------------------------------

function FP:Checksum(text)
    local hash = 5381
    for index = 1, #text do
        hash = (hash * 33 + text:byte(index)) % 4294967296
    end
    return string.format("%08x", hash)
end

-- ---------------------------------------------------------------------------
-- Encoding
-- ---------------------------------------------------------------------------

-- Keys are sorted before they are written. Without that, pairs() would order
-- them differently from one session to the next, and the same profile would
-- produce a different checksum every time it was exported.
local function SortedKeys(t)
    local keys = {}
    for key in pairs(t) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b)
        local typeA, typeB = type(a), type(b)
        if typeA ~= typeB then return typeA < typeB end
        return tostring(a) < tostring(b)
    end)
    return keys
end

-- Its errors are raised at level 0, without a file and line in front: FP:Encode
-- hands them on as the reason an export failed, and the player reads it.
local function EncodeValue(value, out, depth)
    if depth > MAX_DEPTH then
        error(L["Nested more than %d levels deep"]:format(MAX_DEPTH), 0)
    end

    local kind = type(value)
    if kind == "string" then
        local escaped = Escape(value)
        out[#out + 1] = "S" .. #escaped .. ":" .. escaped

    elseif kind == "number" then
        -- %.14g gives back the same double without trailing noise.
        out[#out + 1] = "N" .. string.format("%.14g", value) .. ";"

    elseif kind == "boolean" then
        out[#out + 1] = value and "B1" or "B0"

    elseif kind == "table" then
        local keys = SortedKeys(value)
        out[#out + 1] = "T" .. #keys .. ":"
        for index = 1, #keys do
            EncodeValue(keys[index], out, depth + 1)
            EncodeValue(value[keys[index]], out, depth + 1)
        end

    else
        error(L["Cannot include a %s in an export string"]:format(kind), 0)
    end
end

--- A value as a transport string, or nil and a reason.
function FP:Encode(value)
    local out = {}
    local ok, err = pcall(EncodeValue, value, out, 0)
    if not ok then return nil, tostring(err) end

    local payload = table.concat(out)
    return PREFIX .. ":" .. self:Checksum(payload) .. ":" .. payload
end

-- ---------------------------------------------------------------------------
-- Decoding
--
-- Every step returns ok first, so that a decoded false is never mistaken for a
-- failure.
-- ---------------------------------------------------------------------------

local function DecodeValue(text, pos, depth)
    if depth > MAX_DEPTH then return false, L["nested too deeply"] end
    if pos > #text then
        return false, L["the string ends before a value is complete"]
    end

    local tag = text:sub(pos, pos)

    if tag == "S" then
        local colon = text:find(":", pos + 1, true)
        if not colon then return false, L["a string is missing its length"] end
        local length = tonumber(text:sub(pos + 1, colon - 1))
        if not length or length < 0 then
            return false, L["a string has an invalid length"]
        end
        local stop = colon + length
        if stop > #text then
            return false, L["a string extends beyond the end of the data"]
        end
        return true, Unescape(text:sub(colon + 1, stop)), stop + 1

    elseif tag == "N" then
        local stop = text:find(";", pos + 1, true)
        if not stop then return false, L["a number has no terminating marker"] end
        local number = tonumber(text:sub(pos + 1, stop - 1))
        if not number then return false, L["a number is not a number"] end
        return true, number, stop + 1

    elseif tag == "B" then
        local flag = text:sub(pos + 1, pos + 1)
        if flag == "1" then return true, true,  pos + 2 end
        if flag == "0" then return true, false, pos + 2 end
        return false, L["a boolean is neither true nor false"]

    elseif tag == "T" then
        local colon = text:find(":", pos + 1, true)
        if not colon then return false, L["a table is missing its size"] end
        local count = tonumber(text:sub(pos + 1, colon - 1))
        if not count or count < 0 then
            return false, L["a table has an invalid size"]
        end
        -- Each pair costs at least four characters, so a count larger than the
        -- string itself is a corrupt one. Without this check a bad number would
        -- sit in the loop below until the client gave up.
        if count > #text then
            return false, L["a table specifies more entries than the string "
                .. "contains"]
        end

        local out = {}
        local cursor = colon + 1
        for _ = 1, count do
            local okKey, key, afterKey = DecodeValue(text, cursor, depth + 1)
            if not okKey then return false, key end
            local okValue, value, afterValue = DecodeValue(text, afterKey, depth + 1)
            if not okValue then return false, value end
            out[key] = value
            cursor = afterValue
        end
        return true, out, cursor
    end

    return false, L["unknown marker at position %d"]:format(pos)
end

--- A transport string back to a value, or nil and a reason.
--
-- A bad checksum rejects the whole string. Half-applying an import is the one
-- outcome worth going out of the way to prevent: it leaves behind settings
-- that look deliberate and are not.
function FP:Decode(text)
    if type(text) ~= "string" then return nil, L["nothing to import"] end

    -- Line breaks and spaces come free with copying and pasting, and none of
    -- them can occur inside the payload: it is printable ASCII with every
    -- space escaped away.
    text = text:gsub("%s", "")
    if text == "" then return nil, L["nothing to import"] end

    local version, checksum, payload = text:match("^(%w+):(%x+):(.*)$")
    if not version then
        return nil, L["this does not look like a ForeverPlus string"]
    end
    if version ~= PREFIX then
        return nil, L["this string is version %s, but this build reads %s"]:format(version, PREFIX)
    end
    if checksum ~= self:Checksum(payload) then
        -- Length is the useful clue here. A string that arrives short was cut
        -- on the way in, which is a different problem from a corrupt one, and
        -- the person pasting it cannot tell them apart without being told.
        return nil, L["the string is damaged or incomplete (%d characters "
            .. "received). If you pasted it, it may have been truncated. "
            .. "Paste it again and check that the end matches"]:format(#text)
    end

    local ok, value, after = DecodeValue(payload, 1, 0)
    if not ok then return nil, value end
    if after <= #payload then
        return nil, L["unexpected text after the end of the data"]
    end
    return value
end
