-- Pure string work on chat lines: names, labels, search patterns.
--
-- No frames and no events, which is what lets tools/luatest.py run it. The
-- chat module decides when a line is rewritten and what the player chose;
-- this file only knows how a finished line is put together and how to change
-- the parts of it that are the player's to change.
--
-- **Everything here works on the line's own structure, never on its words.**
-- A channel is found by the number in its link, a group label by the bracket
-- text the client's own format string produced, a name by the player link
-- around it. Nothing is compared against English, so a German client is
-- rewritten by the same code. That is the locale rule in AGENTS.md, and the
-- one place it would be easiest to break.

local ADDON, FP = ...

--- The first character of a word, whole even when it takes several bytes.
--
-- A name here can begin with a letter outside ASCII, and cutting a UTF-8
-- sequence in half draws a box where the initial should be.
local function FirstCharacter(word)
    return word:match("^[\1-\127\194-\244][\128-\191]*") or word:sub(1, 1)
end

--- A name written the way the player chose.
--
-- Names on WoW Forever come in two parts as a rule, "Barnabrotgus Abashed",
-- which is why shortening saves more room here than on an ordinary realm. A
-- name of one word is returned as it came: there is nothing to shorten, and an
-- initial alone would say less than the name.
--
-- @param style  "full", "initial" (B. Abashed), "first" (Barnabrotgus, the
--               owner's addition of 2026-09-27), "surname" (Abashed) or
--               "initials" (B. A.)
function FP:ShortenName(name, style)
    if type(name) ~= "string" or name == "" or not style or style == "full" then
        return name
    end

    -- A realm after a hyphen belongs to somebody from elsewhere and stays as
    -- it is. A character name cannot contain a hyphen, so the last one is
    -- where the realm begins.
    local base, realm = name, ""
    local cut = name:find("%-[^%-]*$")
    if cut and cut > 1 then base, realm = name:sub(1, cut - 1), name:sub(cut) end

    local words = {}
    for word in base:gmatch("%S+") do words[#words + 1] = word end
    if #words < 2 then return name end

    local first, last = words[1], words[#words]
    if style == "initial" then
        return FirstCharacter(first) .. ". " .. last .. realm
    elseif style == "first" then
        return first .. realm
    elseif style == "surname" then
        return last .. realm
    elseif style == "initials" then
        local out = {}
        for _, word in ipairs(words) do out[#out + 1] = FirstCharacter(word) .. "." end
        return table.concat(out, " ") .. realm
    end
    return name
end

--- The label a client format string puts in brackets, and the link around it.
--
-- `CHAT_PARTY_LEADER_GET` reads "|Hchannel:PARTY|h[Party Leader]|h %s: " on an
-- English client, and the bracket text is what a line of that type carries.
-- Reading it out of the client's own string is what keeps a group label field
-- working in every language, the way ErrorFilter reads ERR_OUT_OF_MANA.
--
-- @return the bracket text, and the link token or nil when the label is not a
--         link (a raid warning is plain text on most builds)
function FP:ChatFormatLabel(format)
    if type(format) ~= "string" then return nil end
    local token, text = format:match("|Hchannel:([^|]+)|h%[(.-)%]|h")
    if token then return text, token end
    text = format:match("%[(.-)%]")
    return text, nil
end

-- How far into a line a plain label may sit and still be the line's own. A
-- raid warning's "[Raid Warning]" is not a link, so it is found by its text,
-- and the same words typed by a player further along are not a label.
local PLAIN_LABEL_REACH = 40

--- A chat line with the player's labels and name style applied.
--
-- @param text  the finished line, as a chat frame received it
-- @param opts  {
--   channels  = { [channel number] = label, or false for the client's own },
--   channelNumbers = true: a channel with no entry reads as its number,
--   groups    = { { text = bracket text, token = link token or nil,
--                   label = replacement }, ... },  only the ones set
--   nameStyle = see ShortenName,
--   onName    = function(link, full) called for every name shortened, with
--               the link's opening and the name as it was written,
--   prefix    = text put in front of the first player link, which is the
--               speaker's: the race and class icons,
--   stamp     = { text = the timestamp the client wrote, link = link data or
--               nil }, which puts a line's leading timestamp in brackets and,
--               with a link, makes it a link of ours
-- }
-- @return the new line, or nil when nothing changed
function FP:RewriteChatLine(text, opts)
    if type(text) ~= "string" or type(opts) ~= "table" then return nil end
    local out = text

    -- The timestamp first, while it is still the very start of the line. It
    -- is found by being exactly the text the client's own formatting produced
    -- for this moment, never by a pattern guessing at what a time looks like.
    --
    -- **Always in square brackets**, the owner's decisions of 2026-09-27:
    -- first for the clickable one, since everything that can be clicked in a
    -- chat line is written in them and a bare time did not read as something
    -- to click, then for every one. The space after it stays outside the link,
    -- and a format that brings brackets of its own keeps its one pair.
    local stamp = opts.stamp
    if type(stamp) == "table" and type(stamp.text) == "string" and stamp.text ~= ""
       and out:sub(1, #stamp.text) == stamp.text then
        local clock, space = stamp.text:match("^(.-)(%s*)$")
        if not (clock:sub(1, 1) == "[" and clock:sub(-1) == "]") then
            clock = "[" .. clock .. "]"
        end
        if type(stamp.link) == "string" then
            clock = "|H" .. stamp.link .. "|h" .. clock .. "|h"
        end
        out = clock .. space .. out:sub(#stamp.text + 1)
    end

    -- Numbered channels, by the number in the link. The label is the client's
    -- own text, "1. General - Elwynn Forest", and it changes with the zone, so
    -- the number is the only thing a stored label can be keyed by. A channel
    -- joined later has no entry and, with channelNumbers, reads as its number
    -- like the others; false is a player who cleared the field and wants the
    -- client's text back.
    local channels = opts.channels or {}
    if next(channels) or opts.channelNumbers then
        out = out:gsub("(|Hchannel:[Cc][Hh][Aa][Nn][Nn][Ee][Ll]:(%d+)|h)%[(.-)%](|h)",
            function(open, number, _, close)
                local label = channels[tonumber(number)]
                if label == nil and opts.channelNumbers then label = number end
                if label then return open .. "[" .. label .. "]" .. close end
            end)
    end

    -- Group labels, by the exact text the client's format string produced.
    -- Party and Party Leader share a link token and differ in that text, which
    -- is why the text is part of what is matched and not only the token.
    for _, group in ipairs(opts.groups or {}) do
        if group.text and group.label then
            local old, new
            if group.token then
                old = "|Hchannel:" .. group.token .. "|h[" .. group.text .. "]|h"
                new = "|Hchannel:" .. group.token .. "|h[" .. group.label .. "]|h"
            else
                old = "[" .. group.text .. "]"
                new = "[" .. group.label .. "]"
            end
            local at = out:find(old, 1, true)
            if at and (group.token or at <= PLAIN_LABEL_REACH) then
                out = out:sub(1, at - 1) .. new .. out:sub(at + #old)
            end
        end
    end

    -- Names, in the display half of a player link only. The link itself, which
    -- is what a click whispers or invites, is never touched: a shortened name
    -- can make two people look alike, and the whisper must still reach the
    -- one that was clicked.
    if opts.nameStyle and opts.nameStyle ~= "full" then
        out = out:gsub("(|Hplayer:[^|]*|h)%[(.-)%](|h)", function(open, inner, close)
            local color, name, reset = inner:match("^(|c%x%x%x%x%x%x%x%x)(.-)(|r)$")
            if not color then name = inner end
            local short = FP:ShortenName(name, opts.nameStyle)
            if short == name then return nil end
            if opts.onName then opts.onName(open, name) end
            return open .. "[" .. (color or "") .. short .. (reset or "") .. "]" .. close
        end)
    end

    -- In front of the speaker, outside the link, so the icons are not part of
    -- what a click on the name does.
    if type(opts.prefix) == "string" and opts.prefix ~= "" then
        local at = out:find("|Hplayer:", 1, true)
        if at then out = out:sub(1, at - 1) .. opts.prefix .. out:sub(at) end
    end

    if opts.webLink then out = FP:LinkWebAddresses(out, opts.webLink) end

    return (out ~= text) and out or nil
end

-- ---------------------------------------------------------------------------
-- Web addresses
--
-- N03 of the plan for after the launch, settled with the owner on 2026-10-30:
-- what starts with http://, https:// or www. becomes a link of ours, written in
-- square brackets in the line's own color, and a click offers it for copying.
-- A bare example.com stays plain, his choice, and so does an email address.
--
-- **The address travels inside the link**, "<link><address>", rather than in a
-- table of this session: the history keeps lines as they are, so one put back
-- tomorrow still knows what it points at.
-- ---------------------------------------------------------------------------

-- Where an address cannot go on, in ASCII and in the quotes and stops of the
-- languages this client is played in, which a sentence may close it with. The
-- spaces are written out: %s asks the locale, which may call a byte of a
-- letter outside ASCII a space, and the "à" in a path has one.
local ADDRESS_STOP = "[ \t\r\n\"<>`{}\\^|]"
local ADDRESS_STOPS = { "«", "»", "“", "”", "„", "‘", "’", "…", "。", "、", "，", "！", "？", "）" }

local HTTP_START = "[Hh][Tt][Tt][Pp][Ss]?://"
local WWW_START  = "[Ww][Ww][Ww]%."

--- Does what stands in front of `start` make it part of something longer?
--- xhttp://, name@www.example.com, a.www.example.com. A letter outside ASCII
--- does too, and a quote opening in front of the address does not.
local function InsideWord(run, start)
    if start == 1 then return false end
    local before = run:sub(start - 1, start - 1)
    if before:byte() < 128 then return before:find("[%w_@%.%-/:]") ~= nil end
    for _, mark in ipairs(ADDRESS_STOPS) do
        if run:sub(start - #mark, start - 1) == mark then return false end
    end
    return true
end

--- Where an address may begin at or after `from`, or nil.
local function AddressStart(run, from)
    while true do
        local http = run:find(HTTP_START, from)
        local www  = run:find(WWW_START, from)
        local start = (http and www) and math.min(http, www) or http or www
        if not start then return nil end
        if not InsideWord(run, start) then return start end
        from = start + 1
    end
end

--- The last byte of the address beginning at `start`.
--
-- The sentence around an address must not enter it, and what belongs to its
-- path must not be lost: a stop at the very end is the sentence's, and a
-- closing bracket is the address's only while it has its opening one inside.
-- Text this cannot settle stays as it is written.
local function AddressEnd(run, start)
    local stop = (run:find(ADDRESS_STOP, start) or #run + 1) - 1
    for _, mark in ipairs(ADDRESS_STOPS) do
        local at = run:find(mark, start, true)
        if at and at - 1 < stop then stop = at - 1 end
    end
    while stop >= start do
        local last = run:sub(stop, stop)
        if last:find("[%.,;:!%?']") then
            stop = stop - 1
        elseif last == ")" or last == "]" then
            local address = run:sub(start, stop)
            local _, closes = address:gsub("%" .. last, "")
            local _, opens = address:gsub(last == ")" and "%(" or "%[", "")
            if closes <= opens then break end
            stop = stop - 1
        else
            break
        end
    end
    return stop
end

--- Is there an address here at all, rather than a prefix alone?
local function PlausibleAddress(address)
    local host = address:match("^" .. HTTP_START .. "(.*)$")
    if host then return host:find("^[%w\128-\255]") ~= nil end
    -- www. has to name a domain: a further dot with something on both sides.
    return address:find("^" .. WWW_START .. "[%w\128-\255][^%./]*%.[%w\128-\255]") ~= nil
end

--- The addresses in a stretch of text with no escape sequence in it.
local function LinkInRun(run, link)
    local out, at, scan = {}, 1, 1
    while true do
        local start = AddressStart(run, scan)
        if not start then break end
        local stop = AddressEnd(run, start)
        local address = run:sub(start, stop)
        if PlausibleAddress(address) then
            -- A pair of brackets the writer put around it is the link's pair.
            local from, to = start, stop
            if run:sub(start - 1, start - 1) == "[" and run:sub(stop + 1, stop + 1) == "]" then
                from, to = start - 1, stop + 1
            end
            out[#out + 1] = run:sub(at, from - 1)
            out[#out + 1] = "|H" .. link .. address .. "|h[" .. address .. "]|h"
            at, scan = to + 1, to + 1
        else
            scan = start + 1
        end
    end
    if at == 1 then return run end
    out[#out + 1] = run:sub(at)
    return table.concat(out)
end

--- The last byte of the escape sequence at `bar`, which holds a pipe.
--
-- A link is passed over whole, what it points at and what it shows: an item's
-- name is no address, and neither is an address that is a link already, so a
-- line can come through here twice and stay as it is.
local function EscapeEnd(text, bar)
    local kind = text:sub(bar + 1, bar + 1)
    if kind == "H" then
        local _, open = text:find("|h", bar + 2, true)
        if not open then return #text end
        local _, close = text:find("|h", open + 1, true)
        return close or #text
    elseif kind == "T" or kind == "A" or kind == "K" then
        local _, stop = text:find("|" .. kind:lower(), bar + 2, true)
        return stop or #text
    elseif kind == "c" then
        -- |cAARRGGBB, or |cn<name>: with a color by name.
        if text:sub(bar + 2, bar + 2) == "n" then
            return text:find(":", bar + 3, true) or #text
        end
        return math.min(bar + 9, #text)
    end
    return math.min(bar + 1, #text)
end

--- A line with every readable web address made a link.
--
-- @param link  what comes in front of the address in the link
-- @return the line, the same string when it holds none
function FP:LinkWebAddresses(text, link)
    if type(text) ~= "string" or type(link) ~= "string" then return text end
    -- Most lines hold none, and this runs for every line there is.
    if not (text:find("[Hh][Tt][Tt][Pp]") or text:find(WWW_START)) then return text end

    local out, at = {}, 1
    while at <= #text do
        local bar = text:find("|", at, true)
        if not bar then
            out[#out + 1] = LinkInRun(text:sub(at), link)
            break
        end
        if bar > at then out[#out + 1] = LinkInRun(text:sub(at, bar - 1), link) end
        local stop = EscapeEnd(text, bar)
        out[#out + 1] = text:sub(bar, stop)
        at = stop + 1
    end
    return table.concat(out)
end

--- A line with those links made plain text again, for when the switch goes off.
function FP:UnlinkWebAddresses(text, link)
    if type(text) ~= "string" or type(link) ~= "string" then return text end
    local needle = "|H" .. link
    local out, at = {}, 1
    while true do
        local from, to = text:find(needle, at, true)
        if not from then break end
        local open = text:find("|h", to + 1, true)
        local close = open and text:find("|h", open + 2, true)
        if not close then break end
        out[#out + 1] = text:sub(at, from - 1)
        out[#out + 1] = text:sub(to + 1, open - 1)
        at = close + 2
    end
    if at == 1 then return text end
    out[#out + 1] = text:sub(at)
    return table.concat(out)
end

--- A line as it reads on screen: without colors, links, icons or textures.
--
-- What a search is matched against, so that looking for "General" finds the
-- word somebody wrote and not the channel number hidden in a link.
function FP:ChatVisibleText(text)
    if type(text) ~= "string" then return "" end
    return (text:gsub("|c%x%x%x%x%x%x%x%x", "")
                :gsub("|r", "")
                :gsub("|H.-|h(.-)|h", "%1")
                :gsub("|T.-|t", "")
                :gsub("|A.-|a", ""))
end

--- Whether a line starts with a command only the client's own code may run.
--
-- A line this addon writes into a chat input cannot run one, see the arrow keys
-- in Modules/ChatWindow.lua. The command is cut out the way the client's
-- ParseText does it, so a space in front makes a line no command there and none
-- here. IsSecureCmd is Blizzard Lua, read for build 70862: it only reads.
--
-- **Where the client does not answer, every command counts.** A harmless one held
-- back costs an Alt, and a refused one brings up a dialog whose first button
-- disables the whole addon.
function FP:IsSecureChatLine(line)
    if type(line) ~= "string" then return false end
    local command = line:match("^(/[^%s]+)")
    if not command then return false end
    local ask = rawget(_G, "IsSecureCmd")
    if type(ask) ~= "function" then return true end
    local ok, secure = pcall(ask, command)
    return not ok or secure == true
end

--- A Lua pattern that finds `query` anywhere, ignoring the case of A to Z.
--
-- **Not string.lower**, which is byte based in WoW's Lua and forbidden on game
-- text by the locale rule. Every ASCII letter becomes a class of both its
-- cases, and every other byte is matched as itself: a German umlaut in the
-- query still finds itself, and nothing anywhere is folded.
function FP:SearchPattern(query)
    if type(query) ~= "string" or query == "" then return nil end
    local escaped = query:gsub("(%W)", "%%%1")
    return (escaped:gsub("%a", function(letter)
        return "[" .. letter:upper() .. letter:lower() .. "]"
    end))
end
