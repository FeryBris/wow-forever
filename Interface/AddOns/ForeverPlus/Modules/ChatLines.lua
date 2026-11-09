-- What a chat line says: channel and group labels, shortened names, race and
-- class icons, and the full name one hover away.
--
-- **Rewritten after the line is in the window, never before.** The only way
-- to change a line on its way in would be to replace the window's AddMessage,
-- which puts this addon inside the client's chat handler for every message,
-- whispers included, and a whisper's handler is what remembers who to reply
-- to. So AddMessage is hooked, which runs after the client and leaves it
-- clean, and the line just added is changed where it sits, through the
-- window's own TransformMessages. It is drawn after the handler returns, so
-- the old text never reaches the screen.
--
-- The string work is in Core/ChatText.lua, where the test harness can reach
-- it. This file decides when, and keeps what the hover needs.

local ADDON, FP = ...
local L = FP.L
local M = FP:GetModule("Chat")

local lines = { hooked = {} }

-- The group chats that carry a label, each with the client format string its
-- label comes out of. The bracket text is read from the client at the time it
-- is needed, so it is always in the client's language.
local GROUPS = {
    { type = "GUILD",                format = "CHAT_GUILD_GET" },
    { type = "OFFICER",              format = "CHAT_OFFICER_GET" },
    { type = "PARTY",                format = "CHAT_PARTY_GET" },
    { type = "PARTY_LEADER",         format = "CHAT_PARTY_LEADER_GET" },
    { type = "RAID",                 format = "CHAT_RAID_GET" },
    { type = "RAID_LEADER",          format = "CHAT_RAID_LEADER_GET" },
    { type = "RAID_WARNING",         format = "CHAT_RAID_WARNING_GET" },
    { type = "INSTANCE_CHAT",        format = "CHAT_INSTANCE_CHAT_GET" },
    { type = "INSTANCE_CHAT_LEADER", format = "CHAT_INSTANCE_CHAT_LEADER_GET" },
}

local MAX_LABEL = 24

--- What the player typed into a label field, made safe to put in a line.
--
-- A pipe opens an escape sequence and would take the rest of the line with
-- it, so it goes. So does space at either end, which is invisible in a field
-- and very visible in brackets.
local function CleanLabel(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("|", ""):match("^%s*(.-)%s*$")
    if text == "" then return nil end
    return text:sub(1, MAX_LABEL)
end

-- ---------------------------------------------------------------------------
-- The full name, one hover away
--
-- The owner's condition for shortening at all, raised in the same breath as
-- the feature: a shortened name can make two people look alike, so the full
-- one has to be a hover away, with class and guild. The whisper half of the
-- same condition needs no code: a click whispers the link, and the link is
-- never shortened.
-- ---------------------------------------------------------------------------

-- The full name behind each shortened link, and the guid behind each line.
-- Bounded, oldest first out: a chat window keeps a few hundred lines, and a
-- name that has scrolled away is never hovered again.
local MAX_REMEMBERED = 400

local function Bounded()
    return { order = {}, map = {} }
end

local fullNames, guids = Bounded(), Bounded()

local function Remember(store, key, value)
    if store.map[key] == nil then
        store.order[#store.order + 1] = key
        if #store.order > MAX_REMEMBERED then
            store.map[table.remove(store.order, 1)] = nil
        end
    end
    store.map[key] = value
end

--- Called by the rewrite for every name it shortened.
local function RememberName(open, full)
    -- "|Hplayer:<target>|h" is what the line carries; the hover is handed the
    -- same thing without the two markers.
    local link = open:match("^|H(.-)|h$")
    if link then Remember(fullNames, link, full) end
end

--- The line id inside a player link: player:<name>:<line id>:<chat type>...
local function LineIdOf(link)
    return tonumber(link:match("^player:[^:]*:(%d+)"))
end

-- What a web address's link starts with, see "A web address, to copy" below.
local WEB_LINK = "addon:" .. ADDON .. ":web:"

local function OnHyperlinkEnter(frame, link)
    if not M.enabled then return end
    local plain = FP:Plain(link)
    if not plain then return end
    if plain:sub(1, #WEB_LINK) == WEB_LINK then
        if M.db.webAddresses ~= false then
            FP:ShowTip(frame, { L["Click to select this web address for copying."] }, "TOP")
        end
        return
    end
    if not plain:find("^player:") then return end
    local full = fullNames.map[plain]
    if not full then return end

    local lineId = LineIdOf(plain)
    local guid = lineId and guids.map[lineId]
    if FP.ShowPlayerCard then
        FP:ShowPlayerCard(frame, full, guid)
    end
end

local function OnHyperlinkLeave(frame)
    FP:HideTip(frame)
    if GameTooltip and GameTooltip:GetOwner() == frame then GameTooltip:Hide() end
end

--- The speaker of a line, from what the client handed AddMessage with it.
--
-- **Read off the line rather than off a chat event of our own.** The client
-- passes the chat event's own arguments along with every line a player wrote,
-- packed into one table after the event's name, and the eleventh and twelfth
-- of them are the line id and the speaker's guid. Measured by the probe on
-- 2026-09-27 and read in the client's source the same day. A line without
-- them, a system message above all, has no speaker, and nothing is said.
--
-- @return the guid and the line id, either of them nil when not readable
local function SpeakerOf(eventArgs)
    if type(eventArgs) ~= "table" then return nil end
    local guid = FP:Plain(rawget(eventArgs, 12))
    local ok, id = pcall(function()
        local value = rawget(eventArgs, 11)
        return type(value) == "number" and value > 0 and value or nil
    end)
    return guid, ok and id or nil
end

-- ---------------------------------------------------------------------------
-- Race and class icons
--
-- **One switch each and a size, by the owner's decision at the gate**, and
-- deliberately not per chat type, channel and tab: three axes of visibility is
-- the menu Better Forever Chat's own comment section complains about.
--
-- The guid is asked once and the answer kept: a race and a class do not
-- change, which is the line phase 5.1 drew for what may be cached. A guid the
-- client will not answer for, which is identity and so something C_Secrets
-- covers, gets no icons rather than guessed ones.
-- ---------------------------------------------------------------------------

local MAX_SPEAKERS = 1000
local speakers, speakerCount = {}, 0
local atlasExists = {}

--- Whether this client has an atlas by that name. Asked once per name.
local function HasAtlas(name)
    if atlasExists[name] == nil then
        local info = C_Texture and C_Texture.GetAtlasInfo
        local ok, found = pcall(info or function() end, name)
        atlasExists[name] = (ok and type(found) == "table") or false
    end
    return atlasExists[name]
end

--- What the client says about a speaker: class token, race token, sex.
--
-- Only an answer is kept. A speaker the client knows nothing about yet, or
-- will not say, is asked again on their next line, which costs one call.
local function SpeakerInfo(guid)
    if speakers[guid] then return speakers[guid] end
    if not GetPlayerInfoByGUID then return nil end

    local ok, _, class, _, race, sex = pcall(GetPlayerInfoByGUID, guid)
    class, race = ok and FP:Plain(class), ok and FP:Plain(race)
    if not (class or race) then return nil end
    local okSex, female = pcall(function() return sex == 3 end)

    speakerCount = speakerCount + 1
    if speakerCount > MAX_SPEAKERS then
        wipe(speakers)
        speakerCount = 1
    end
    speakers[guid] = { class = class, race = race, female = okSex and female }
    return speakers[guid]
end

--- The markup for one atlas at the chosen size, or "" when there is none.
local function Icon(atlas, size)
    if not (atlas and HasAtlas(atlas)) then return "" end
    return ("|A:%s:%d:%d|a"):format(atlas, size, size)
end

--- The icons in front of a speaker's name, or nil for none.
--
-- The tokens are ASCII, "NightElf" and "WARRIOR", and never display text, so
-- lowering them into an atlas name is not the byte based folding the locale
-- rule forbids. The atlas names are the client's own: classicon-<class> and
-- raceicon128-<race>-<sex>, where the client's own table renames Scourge to
-- undead. An atlas this build does not have draws nothing.
--
-- **SD portraits since 2026-10-18**, CF5 on CurseForge: the client carries
-- raceicon-sd-<race>-<sex> beside the HD art, 64 units like raceicon-<race>,
-- so a style of its own rather than a size, read in the atlas list of the
-- Forever client that Ketho/BlizzardInterfaceResources keeps. Not for every
-- race and sex: a race without one keeps its HD portrait, a known race in
-- the other style rather than a guess.
local RACE_ATLAS = { scourge = "undead" }

--- The atlas of a race's portrait in the style the page asks for.
local function RaceAtlas(race, sex, style)
    if style == "sd" then
        local atlas = "raceicon-sd-" .. race .. "-" .. sex
        if HasAtlas(atlas) then return atlas end
    end
    local atlas = "raceicon128-" .. race .. "-" .. sex
    if not HasAtlas(atlas) then atlas = "raceicon-" .. race .. "-" .. sex end
    return atlas
end

local function IconsFor(guid)
    local db = M.db
    if not (guid and (db.classIcons or db.raceIcons)) then return nil end
    local info = SpeakerInfo(guid)
    if not info then return nil end

    local size = math.floor(tonumber(db.iconSize) or 14)
    local out = ""
    if db.raceIcons and info.race then
        local race = info.race:lower()
        race = RACE_ATLAS[race] or race
        local sex = info.female and "female" or "male"
        out = out .. Icon(RaceAtlas(race, sex, db.raceStyle), size)
    end
    if db.classIcons and info.class then
        out = out .. Icon("classicon-" .. info.class:lower(), size)
    end
    return out ~= "" and (out .. " ") or nil
end

-- ---------------------------------------------------------------------------
-- The rewrite
-- ---------------------------------------------------------------------------

--- Forgets every channel label that is only a number.
--
-- **A number in a channel's field always means the channel's own number.**
-- Found by the owner on 2026-09-27: a field shows its channel's number, and
-- clicking into it and out again stored that number as a label of its own.
-- When he then swapped two channels, the stored "6" moved with its channel to
-- place 5, place 6 showed its own number, and both read "6". So a label that
-- is only a number is never kept: the field shows the number again, worked
-- out from the line, and a reordered channel reads as its new place. Nobody
-- labels a channel with another channel's number on purpose.
local function NumbersAreDefaults()
    local labels = M.db and M.db.labels
    if type(labels) ~= "table" then return end
    for key, label in pairs(labels) do
        if type(key) == "string" and key:find("^channel:%d+$")
           and type(label) == "string" and label:find("^%d+$") then
            labels[key] = nil
        end
    end
end

--- What RewriteChatLine needs, from the current settings. Worked out when a
--- setting changes rather than for every line.
local function BuildOptions()
    local db = M.db
    local labels = db.labels or {}

    -- A numbered channel reads as its number unless the player wrote
    -- something else, the owner's default of 2026-09-27, and that includes a
    -- channel joined later: the number is worked out when a line arrives, not
    -- stored per channel. An emptied field is stored as an empty label and
    -- means the client's own text.
    --
    -- All of it answers to one switch, on by default since 2026-09-27: off
    -- leaves every label as the client writes it, and keeps what was typed.
    local on = db.channelLabels ~= false
    local channels, groups = {}, {}
    if on then
        for key, label in pairs(labels) do
            local number = type(key) == "string" and tonumber(key:match("^channel:(%d+)$") or "")
            if number then channels[number] = CleanLabel(label) or false end
        end
        for _, group in ipairs(GROUPS) do
            local clean = CleanLabel(labels[group.type])
            local text, token = FP:ChatFormatLabel(rawget(_G, group.format))
            if clean and text then
                groups[#groups + 1] = { text = text, token = token, label = clean }
            end
        end
    end

    -- Never nothing to do: the brackets on a timestamp alone are a change.
    return { channels = channels, channelNumbers = on, groups = groups,
             nameStyle = db.nameStyle or "full", onName = RememberName,
             webLink = db.webAddresses ~= false and WEB_LINK or nil }
end

-- ---------------------------------------------------------------------------
-- Shift and a click on a timestamp
--
-- Puts the whole line into the chat input, unsent: the owner's decision at
-- the gate, once it was explained that no addon can write the clipboard. The
-- probe confirmed that on 2026-09-27: CopyToClipboard is restricted.
--
-- **Into an open input through the client's own ChatFrameUtil.InsertLink**,
-- which is the call every bag addon makes when an item is shift clicked. It
-- inserts into the active input and does nothing when there is none, exactly
-- as a shift clicked item does.
--
-- **A closed input is opened, against the recommendation.** The owner chose
-- it on 2026-09-27 after the risk was put to him, and it is on by default
-- behind a switch of its own. The risk, read in the client's source: opening
-- the input through ChatFrameUtil.OpenChat writes the client's own record of
-- the active input, ACTIVE_CHAT_EDIT_BOX and its neighbours, from our code, and
-- whatever the client later reads from there runs as if an addon had done it.
-- That can surface as "blocked by an addon", as a chat line refused in a
-- dungeon, or as a /cast from the input refused, and not every time. **If any
-- of that is ever reported, this switch is the first thing to turn off.**
--
-- The timestamp becomes a link of ours, "addon:ForeverPlus:line:<n>", which
-- the client hands to EventRegistry's SetItemRef when it is clicked, and it is
-- written in square brackets like every other link in a line: without them it
-- did not read as something to click, the owner's report of 2026-09-27.
--
-- **The number is unique across sessions**, the second the session started
-- and a count, so a line the history puts back keeps a link that still finds
-- it rather than one a new line of this session also carries.
-- ---------------------------------------------------------------------------

local STAMP_LINK = "addon:" .. ADDON .. ":line:"
local SESSION    = tostring(type(time) == "function" and time() or 0)
local stampCount = 0

--- The timestamp the client put at the head of a line added just now.
--
-- Made with the client's own TimeUtil.BetterDate and the format it used, for
-- this second and the one before, so a line that crossed a second on its way
-- in is still recognised. Never matched by a pattern that guesses at what a
-- time looks like: the AM and PM markers are the client's own words.
local function StampOf(line)
    local format = M.CVar("showTimestamps")
    local better = type(TimeUtil) == "table" and TimeUtil.BetterDate
    if not format or format == "none" or type(better) ~= "function" then return nil end

    local now = time()
    for _, moment in ipairs({ now, now - 1 }) do
        local ok, text = pcall(better, format, moment)
        text = ok and FP:Plain(text)
        if text and line:sub(1, #text) == text then return text end
    end
    return nil
end

--- The line in that window that carries this link, or nil.
local function LineWithLink(frame, link)
    local needle = "|H" .. link .. "|h"
    local found
    local function Search(window)
        for _, line in ipairs(M:LinesOf(window)) do
            if line.text:find(needle, 1, true) then found = line.text end
        end
    end
    if type(frame) == "table" and frame.GetMessageInfo then Search(frame) end
    if not found then M:EachFrame(function(window) if not found then Search(window) end end) end
    return found
end

local function OnStampClick(link, frame)
    if not (M.enabled and M.db.stampClick) then return end
    link = FP:Plain(link)
    if not link or link:sub(1, #STAMP_LINK) ~= STAMP_LINK then return end

    -- The client's own modifier for putting a link into the chat, which is
    -- Shift unless the player moved it.
    local modified
    if IsModifiedClick then
        modified = FP:Truth(select(2, pcall(IsModifiedClick, "CHATLINK")))
    elseif IsShiftKeyDown then
        modified = FP:Truth(select(2, pcall(IsShiftKeyDown)))
    end
    if modified ~= true then return end

    local line = LineWithLink(frame, link)
    if not line then return end
    -- As it reads on screen, and without the marker a printed search result
    -- carries in front.
    local text = FP:ChatVisibleText(line)
    local marker = FP:ChatVisibleText(M.REPRINT)
    if text:sub(1, #marker) == marker then text = text:sub(#marker + 1) end

    local util = type(ChatFrameUtil) == "table" and ChatFrameUtil or {}
    local insert = util.InsertLink or _G.ChatEdit_InsertLink
    if type(insert) ~= "function" then return end
    -- The client answers true when the line went somewhere, which is when an
    -- input was open.
    if insert(text) then return end

    -- None was: opened with the line already in it, through the call the
    -- client's own reply key uses, when the player wants that. See the head
    -- of this section for what it risks. With that switched off, a click
    -- while the input is closed does nothing, as the switch's hover says: the
    -- line asking for Enter first went on 2026-10-06, the owner's word, since
    -- the click opens the input itself by default.
    if M.db.stampOpen ~= false and type(util.OpenChat) == "function" then
        pcall(util.OpenChat, text, frame)
    end
end

-- ---------------------------------------------------------------------------
-- A web address, to copy
--
-- N03 of the plan for after the launch: a left click on an address in a line
-- opens a small window with it selected, and the player copies it with Ctrl+C,
-- since no addon can write the clipboard. The recognizing is in
-- Core/ChatText.lua, and only a click ever opens this. Off gives every address
-- back as plain text, see SyncAddresses, and leaves the rest of a line alone.
-- ---------------------------------------------------------------------------

local ADDRESS_WIDTH = 420

local addressWindow

--- The window, built once and reused for every address.
local function AddressWindow()
    if addressWindow then return addressWindow end
    local PAD = FP.PANEL_PAD
    local f = FP:CreatePanel("ForeverPlusAddressWindow", ADDRESS_WIDTH, L["Web address"], "")
    FP:KeepAboveSettings(f)

    f.box = FP:CreateCopyBox(f, "", ADDRESS_WIDTH - 2 * PAD)
    f.box:SetPoint("TOPLEFT", PAD, -FP.PANEL_HEADER)
    -- Out of the field and out of the window in one go, as the Close button.
    f.box.editBox:SetScript("OnEscapePressed", function() f:Hide() end)

    local close = FP:CreateButton(f, L["Close"], 80, function() f:Hide() end)
    close:SetPoint("BOTTOMRIGHT", -PAD, PAD)

    local hint = FP:FontString(f, "OVERLAY", "body")
    hint:SetPoint("LEFT", f, "BOTTOMLEFT", PAD, PAD + 11)
    hint:SetText(L["Press Ctrl+C to copy."])
    FP:FitLabel(hint, f, close)

    f:SetHeight(FP.PANEL_HEADER + 22 + 12 + 22 + PAD)

    addressWindow = f
    return f
end

local function OnAddressClick(link, button)
    if not (M.enabled and M.db.webAddresses ~= false) then return end
    link = FP:Plain(link)
    if not link or link:sub(1, #WEB_LINK) ~= WEB_LINK then return end
    if button ~= "LeftButton" then return end

    local f = AddressWindow()
    f.box:SetCopyText(link:sub(#WEB_LINK + 1))
    f:Show()
    f.box.editBox:SetFocus()
    f.box.editBox:HighlightText()
end

--- A line brought in line with the switch as it is now: one put back from the
--- history may have been written either way.
function M:ConvertAddresses(text)
    if self.db.webAddresses ~= false then
        return FP:LinkWebAddresses(text, WEB_LINK)
    end
    return FP:UnlinkWebAddresses(text, WEB_LINK)
end

--- Listens for a click on a timestamp or an address, once and for good. Each
--- asks its own switch at the moment of the click.
local function WatchLinks()
    if lines.linksWatched then return end
    lines.linksWatched = true
    local function OnClick(link, button, frame)
        FP:Safe("Chat:StampClick", OnStampClick, link, frame)
        FP:Safe("Chat:AddressClick", OnAddressClick, link, button)
    end
    if type(EventRegistry) == "table" and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("SetItemRef",
            function(_, link, _, button, frame) OnClick(link, button, frame) end, lines)
    elseif hooksecurefunc and type(_G.SetItemRef) == "function" then
        hooksecurefunc("SetItemRef", function(link, _, button, frame) OnClick(link, button, frame) end)
    end
end

--- Changes the line just added, where it sits in the window.
--
-- **The client's TransformMessages hands each entry over unpacked**: the text,
-- the color, then whatever the line was added with, and it stores whatever
-- the transform returns as the new entry. So the predicate is asked about the
-- text and the transform returns the new text followed by everything else,
-- untouched. The first version of this took one table per entry, which is the
-- shape of the buffer underneath, and changed nothing at all: read in the
-- client's source on 2026-09-27, ScrollingMessageFrame.lua.
--
-- Both run as the window's own code through an elevation barrier the client
-- provides for exactly this, so what is written back is not tainted.
--
-- Every entry holding the old text is changed, which in practice is the one
-- just added: an older identical line was changed when it arrived and holds
-- the new text already.
local function Replace(frame, old, new)
    if type(frame.TransformMessages) ~= "function" then return false end
    local changed = false
    local ok = pcall(frame.TransformMessages, frame,
        function(message)
            -- A secret line raises on the comparison, and a secret line is
            -- one to leave alone anyway.
            local usable, same = pcall(function() return message == old end)
            return usable and same
        end,
        function(message, ...)
            changed = true
            return new, ...
        end)
    return ok and changed
end

-- The client's own text of every line changed this session, by its new
-- text, so that switching the module off can hand each line back as the
-- client wrote it: asked for by the owner on 2026-09-27, off is the client's
-- chat. More than ten windows of 128 lines each can hold.
local originals, originalCount = {}, 0
local MAX_ORIGINALS = 2000

local function Keep(new, old)
    if originals[new] == nil then
        originalCount = originalCount + 1
        if originalCount > MAX_ORIGINALS then
            wipe(originals)
            originalCount = 1
        end
    end
    originals[new] = old
end

--- The switch for web addresses changed: every line that holds one follows it,
--- and nothing else in a line moves.
--
-- A line changed here goes on pointing at what the client wrote, so switching
-- the whole module off still hands back the client's own text.
local function SyncAddresses()
    local on = M.db.webAddresses ~= false
    local before = lines.addressesOn
    lines.addressesOn = on
    -- The first look at login has nothing to follow: lines of this session
    -- link themselves, and the history asks M:ConvertAddresses.
    if before == nil or before == on then return end
    if not on and addressWindow then addressWindow:Hide() end

    M:EachFrame(function(frame)
        if type(frame.TransformMessages) ~= "function" then return end
        pcall(frame.TransformMessages, frame,
            function(message)
                -- A secret line raises, and a secret line is left alone.
                local ok, changes = pcall(function()
                    return M:ConvertAddresses(message) ~= message
                end)
                return ok and changes
            end,
            function(message, ...)
                local new = M:ConvertAddresses(message)
                Keep(new, originals[message] or message)
                return new, ...
            end)
    end)
end

--- Every changed line back as the client wrote it.
local function Revert()
    if not next(originals) then return end
    M:EachFrame(function(frame)
        if type(frame.TransformMessages) ~= "function" then return end
        pcall(frame.TransformMessages, frame,
            function(message)
                local ok, old = pcall(function() return originals[message] end)
                return ok and old ~= nil
            end,
            function(message, ...)
                return originals[message], ...
            end)
    end)
    wipe(originals)
    originalCount = 0
end

local function OnAddMessage(frame, text, eventArgs)
    local opts = lines.opts
    if not (M.enabled and opts) then return end
    local plain = FP:Plain(text)
    if not plain then return end

    local guid, lineId = SpeakerOf(eventArgs)
    if guid and lineId then Remember(guids, lineId, guid) end

    opts.prefix = IconsFor(guid)
    -- Every timestamp in square brackets, the owner's decision of 2026-09-27,
    -- and a link of ours around it while the Shift click is on.
    local stamp = StampOf(plain)
    if stamp then
        local link
        if M.db.stampClick then
            stampCount = stampCount + 1
            link = STAMP_LINK .. SESSION .. "." .. stampCount
        end
        opts.stamp = { text = stamp, link = link }
    end
    local new = FP:RewriteChatLine(plain, opts)
    opts.prefix, opts.stamp = nil, nil
    if not new then return end

    if Replace(frame, plain, new) then
        Keep(new, plain)
    elseif not lines.warned then
        -- Said once, rather than failing quietly on every line: a label that
        -- never appears looks exactly like a setting that did not save.
        lines.warned = true
        FP:Warn(L["Chat: this client would not let a line be changed after it "
            .. "arrived, so labels and names stay as the game writes them."])
    end
end

function lines:Frames()
    if not hooksecurefunc then return end
    M:EachFrame(function(frame)
        if self.hooked[frame] then return end
        self.hooked[frame] = true
        -- What the client adds a player's line with: the text, the color,
        -- three ids, the event's name, and the event's own arguments packed
        -- into one table. Only the last is read.
        hooksecurefunc(frame, "AddMessage",
            function(window, text, _, _, _, _, _, _, _, eventArgs)
                local ok = pcall(OnAddMessage, window, text, eventArgs)
                if not ok and not lines.faulted then
                    lines.faulted = true
                    FP:Warn(L["Chat: changing a line failed once and is left "
                        .. "alone from now on this session."])
                    lines.opts = nil
                end
            end)
        if frame.HookScript then
            frame:HookScript("OnHyperlinkEnter", function(window, link)
                pcall(OnHyperlinkEnter, window, link)
            end)
            frame:HookScript("OnHyperlinkLeave", function(window)
                pcall(OnHyperlinkLeave, window)
            end)
        end
    end)
end

--- Keeps a label with its channel when the client swaps two channels.
--
-- Asked for by the owner on 2026-09-27: a reordered channel keeps what it was
-- called. The client reorders its channels one swap at a time, through
-- C_ChatInfo.SwapChatChannelsByChannelIndex, and carries their colors across
-- itself, read in its ChatConfigFrame.lua the same day. A label is stored
-- against the number, so without this it would stay behind on the number
-- while its channel moves on. A channel's own number needs nothing: it is read
-- off every line as it arrives.
--
-- Swapped whether or not the module is running, since the labels are the
-- player's and would come back wrong the day it is switched on again.
local function FollowSwaps()
    if lines.swapsWatched then return end
    local info = C_ChatInfo
    if not (hooksecurefunc and type(info) == "table"
            and type(info.SwapChatChannelsByChannelIndex) == "function") then
        return
    end
    lines.swapsWatched = true
    hooksecurefunc(info, "SwapChatChannelsByChannelIndex", function(first, second)
        FP:Safe("Chat:ChannelSwap", function()
            local labels = M.db and M.db.labels
            first, second = tonumber(first), tonumber(second)
            if type(labels) ~= "table" or not first or not second then return end
            NumbersAreDefaults()
            local a, b = "channel:" .. first, "channel:" .. second
            labels[a], labels[b] = labels[b], labels[a]
            if M.enabled then lines:Apply() end
        end)
    end)
end

function lines:Apply()
    NumbersAreDefaults()
    self.opts = (not self.faulted) and BuildOptions() or nil
    self:Frames()
    FollowSwaps()
    WatchLinks()
    SyncAddresses()
end


function lines:Enable()
    self:Apply()
end

function lines:Disable()
    self.opts = nil
    if addressWindow then addressWindow:Hide() end
    -- The module switched off, not a setting changed: the lines go back.
    if not M.enabled then Revert() end
end

M:Part("lines", lines)

-- ---------------------------------------------------------------------------
-- The label fields on the page
--
-- One row per channel the character is in, read from the client rather than
-- listed here, and one per group chat whose label the client's format strings
-- give. Each row has the chat's color beside the field, which is the client's
-- own color setting and is changed through the client's own call.
-- ---------------------------------------------------------------------------

local ROW_H   = 26
local FIELD_W = 110
local SWATCH  = 14

--- The numbered channels the character is in, as { number, name } pairs.
local function Channels()
    local out = {}
    local ok, list = pcall(function() return { GetChannelList() } end)
    if not ok then return out end
    -- Three values per channel: number, name, disabled.
    for i = 1, #list, 3 do
        local number, name = tonumber(list[i]), FP:Plain(list[i + 1])
        if number and name then out[#out + 1] = { number, name } end
    end
    return out
end

--- What the fields are for, in the order they are shown.
local function Wanted()
    local out = {}
    for _, channel in ipairs(Channels()) do
        out[#out + 1] = {
            key = "channel:" .. channel[1],
            title = channel[1] .. ". " .. channel[2],
            chatType = "CHANNEL" .. channel[1],
            default = tostring(channel[1]),
        }
    end
    for _, group in ipairs(GROUPS) do
        local text = FP:ChatFormatLabel(rawget(_G, group.format))
        if text then
            out[#out + 1] = { key = group.type, title = text, chatType = group.type }
        end
    end
    return out
end

local function Signature(list)
    local keys = {}
    for i, want in ipairs(list) do keys[i] = want.key .. "=" .. want.title end
    return table.concat(keys, "|")
end

local function ChatColor(chatType)
    local info = type(ChatTypeInfo) == "table" and ChatTypeInfo[chatType]
    if type(info) ~= "table" then return nil end
    return info.r, info.g, info.b
end

--- Stores what the player typed. A numbered channel's field starts out with
--- its number, so emptying it is a choice of its own, the client's text, and
--- is kept as an empty label rather than forgotten.
local function SetLabel(want, value)
    M.db.labels = M.db.labels or {}
    local clean = CleanLabel(value)
    if want.default then
        if not clean then
            clean = ""
        elseif clean:find("^%d+$") then
            -- Only a number: the channel's own, whichever it is by then. See
            -- NumbersAreDefaults.
            clean = nil
        end
    end
    M.db.labels[want.key] = clean
    lines:Apply()
end

local function BuildRow(holder, want, width)
    local row = FP:CreateInput(holder, want.title, {
        width = FIELD_W,
        Get = function()
            local stored = (M.db.labels or {})[want.key]
            if stored == nil then return want.default or "" end
            return stored
        end,
        Set = function(value) SetLabel(want, value) end,
    })
    FP:ApplyLevel(row, "primary")
    row:SetHeight(ROW_H)

    -- The color, left of the field.
    local swatch = CreateFrame("Button", nil, row)
    swatch:SetSize(SWATCH, SWATCH)
    local field = row.editBox and row.editBox:GetParent()
    if field then
        swatch:SetPoint("RIGHT", field, "LEFT", -8, 0)
    else
        swatch:SetPoint("RIGHT", row, "RIGHT", -(FIELD_W + 8), 0)
    end
    local fill = swatch:CreateTexture(nil, "ARTWORK")
    fill:SetAllPoints()
    FP:AddBorder(swatch)
    -- The label stops short of the swatch, which sits in front of the field.
    FP:FitLabel(row.text, row, swatch)

    local function Paint()
        local r, g, b = ChatColor(want.chatType)
        if r then
            fill:SetColorTexture(r, g, b, 1)
            swatch:Show()
        else
            swatch:Hide()
        end
    end
    swatch:SetScript("OnClick", function()
        local r, g, b = ChatColor(want.chatType)
        if not r then return end
        FP:PickColor(r, g, b, 1, false, function(nr, ng, nb)
            if _G.ChangeChatColor then pcall(_G.ChangeChatColor, want.chatType, nr, ng, nb) end
            fill:SetColorTexture(nr, ng, nb, 1)
        end)
    end)
    FP:Tooltip(swatch, want.title, L["Sets this chat's color using the "
        .. "client's own color picker."])

    local base = row.Refresh
    row.Refresh = function(self)
        if base then base(self) end
        Paint()
    end
    row:Refresh()

    local explain = L["Replaces the label before this chat's lines. Leave it "
        .. "empty to use the client's label."]
    FP:Tooltip(row, want.title, explain)
    FP:Tooltip(row.tooltipTargets, want.title, explain)
    return row
end

local function Layout(holder)
    local wanted = Wanted()
    local signature = Signature(wanted)
    if holder.signature == signature then
        for _, row in ipairs(holder.rows or {}) do row:Refresh() end
        return holder.height or 1
    end

    for _, row in ipairs(holder.rows or {}) do row:Hide() end
    holder.rows = {}
    holder.signature = signature

    local y = 0
    for _, want in ipairs(wanted) do
        local row = BuildRow(holder, want, holder:GetWidth())
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, -y)
        holder.rows[#holder.rows + 1] = row
        y = y + ROW_H
    end

    if #wanted == 0 then
        holder.empty = holder.empty or FP:FontString(holder, "OVERLAY", "body")
        holder.empty:SetPoint("TOPLEFT", FP.ROW_TEXT_X, -4)
        holder.empty:SetText(L["No channels to label yet."])
        holder.empty:Show()
        y = ROW_H
    elseif holder.empty then
        holder.empty:Hide()
    end

    holder.height = math.max(y, 1)
    return holder.height
end

--- Rebuilds the rows when the client's list of channels changes.
--
-- **Right after a login the client is in no channel yet.** It joins General,
-- Trade and the rest one by one over the next seconds; the probe recorded an
-- empty channel list at login, and on 2026-09-27 the owner opened the page in
-- that moment and saw only the group chats, where a /reload showed them all.
-- So the rows follow the client's own notices that its channels changed, a
-- moment later, and only while the page can be seen: opening it checks anyway.
local function WatchChannels()
    if lines.channelsWatched then return end
    lines.channelsWatched = true
    local frame = CreateFrame("Frame")
    for _, event in ipairs({ "CHANNEL_UI_UPDATE", "CHAT_MSG_CHANNEL_NOTICE" }) do
        pcall(frame.RegisterEvent, frame, event)
    end
    local function Rebuild()
        local holder = lines.labelsHolder
        if holder and holder:IsVisible() then
            FP:Safe("Chat:ChannelRows", M.RefreshLabels, M, holder)
        end
    end
    frame:SetScript("OnEvent", function()
        if C_Timer and C_Timer.After then C_Timer.After(0.2, Rebuild) else Rebuild() end
    end)
end

function M:BuildLabels(holder, width)
    holder:SetWidth(width)
    lines.labelsHolder = holder
    WatchChannels()
    return Layout(holder)
end

--- Channels come and go while the page is closed, so the rows are checked
--- whenever it is opened, and while it is open by WatchChannels above.
function M:RefreshLabels(holder)
    local height = Layout(holder)
    if holder.Resize then holder:Resize(height) end
end
