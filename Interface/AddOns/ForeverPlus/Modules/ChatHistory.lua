-- The chat, kept across sessions. Phase 6.3.
--
-- **Built while it could not work, and it works now.** Decided by the owner
-- against the recommendation, when build 69977 handed nothing back: the code
-- is right and starts working the day Blizzard fixes the client. Build 70009
-- did, on 2026-09-26, before a line of this was written.
--
-- **Every channel, not only the conversations.** Also against the
-- recommendation, and the owner's reason is the better one: channel numbers
-- move between characters and channel names differ by language, so "only
-- whispers and guild" is not a line that can be drawn reliably. A cap per
-- window keeps the file honest instead, and the standard it is held to is the
-- diagnostics report, which was thrown out of the saved file for outweighing
-- the settings ten to one.
--
-- **When nothing comes back it says nothing**: no separator and no line, so a
-- first login reads exactly like a fresh session. A rule drawn over zero lines
-- reads as a fault.
--
-- Kept per character, beside the profiles rather than inside one: what a
-- character read is not a setting another character should inherit.

local ADDON, FP = ...
local L = FP.L
local M = FP:GetModule("Chat")

local history = { restored = false, added = {} }

-- Only the permanent windows. A whisper window is opened for a session and
-- closed with it, so there is no window to put its lines back into. The combat
-- log is left out as well: a fight from yesterday is not something anybody
-- scrolls back to, and it would fill the cap in seconds.
local function Windows(fn)
    local combatLog = rawget(_G, "COMBATLOG")
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local name = "ChatFrame" .. i
        local frame = _G[name]
        if type(frame) == "table" and type(frame.AddMessage) == "function"
           and frame ~= combatLog then
            fn(frame, name)
        end
    end
end

-- Three decimals are more than any eye can tell apart, and the file keeps a
-- color per line.
local function Round(value)
    value = tonumber(value)
    if not value then return nil end
    return math.floor(value * 1000 + 0.5) / 1000
end

local function Store()
    local key = FP.charKey
    if not (key and type(FP.global) == "table") then return nil end
    if type(FP.global.chatHistory) ~= "table" then FP.global.chatHistory = {} end
    return FP.global.chatHistory, key
end

--- Writes every window down, newest lines up to the cap.
function history:Save()
    local all, key = Store()
    if not all then return end
    if not M.db.history then
        all[key] = nil
        return
    end

    local cap = math.min(math.max(0, math.floor(tonumber(M.db.historyLines) or 100)),
                         M:WindowCapacity())
    local windows = {}
    Windows(function(frame, name)
        local wanted = {}
        for _, line in ipairs(M:LinesOf(frame)) do
            -- Lines this module printed back, search results among them, are
            -- copies of lines that are there already.
            if line.text:sub(1, #M.REPRINT) ~= M.REPRINT then
                wanted[#wanted + 1] = line
            end
        end

        -- As they are, timestamp links included: their numbers are unique
        -- across sessions, so a line put back can still be Shift clicked.
        local kept = {}
        for index = math.max(1, #wanted - cap + 1), #wanted do
            local line = wanted[index]
            kept[#kept + 1] = { line.text, Round(line.r), Round(line.g), Round(line.b) }
        end
        if #kept > 0 then windows[name] = kept end
    end)

    all[key] = next(windows) and {
        stamp = date("%Y-%m-%d %H:%M:%S"), windows = windows,
    } or nil
end

--- Puts the kept lines back, once per session, behind what a window holds.
--
-- **BackFillMessage adds a line at the old end of a window** and never pushes
-- a newer one out: a full window refuses it. So the kept lines go in newest
-- first, each behind the last, and the few lines a window already holds by
-- now, the client's greeting among them, stay exactly where they are. Read in
-- the client's source on 2026-09-27. The first version emptied each window
-- and wrote everything in again, which cost those few lines what the client
-- had added them with: the line id a report or a whisper menu works from.
function history:Restore()
    if self.restored then return end
    self.restored = true
    if not M.db.history then return end

    local all, key = Store()
    local kept = all and all[key]
    if type(kept) ~= "table" or type(kept.windows) ~= "table" then return end

    Windows(function(frame, name)
        local lines = kept.windows[name]
        if type(lines) ~= "table" or #lines == 0 then return end

        if type(frame.BackFillMessage) ~= "function" then
            -- Said once rather than failing quietly: a history that never
            -- comes back looks exactly like a setting that did not save.
            if not history.warned then
                history.warned = true
                FP:Warn(L["Chat: this client cannot add older lines to a "
                    .. "chat window, so the saved chat is not restored."])
            end
            return
        end

        for index = #lines, 1, -1 do
            local line = lines[index]
            if type(line) == "table" and type(line[1]) == "string" then
                -- Kept before web addresses became links, or with their switch
                -- set the other way.
                local text = M:ConvertAddresses(line[1])
                pcall(frame.BackFillMessage, frame, text, line[2], line[3], line[4])
                history.added[text] = true
            end
        end
    end)
end

function history:Enable()
    self.events = self.events or CreateFrame("Frame")
    -- PLAYER_LOGOUT comes before the saved file is written, on a logout and on
    -- a /reload alike, which is the one moment every line is still there.
    self.events:RegisterEvent("PLAYER_LOGOUT")
    self.events:SetScript("OnEvent", function()
        FP:Safe("Chat:SaveHistory", history.Save, history)
    end)
    self:Restore()
end

-- Everything is read at the moment of saving, so a changed setting needs
-- nothing now.
function history:Apply() end

function history:Disable()
    if self.events then self.events:UnregisterAllEvents() end
    if M.enabled or not next(self.added) then return end

    -- The module switched off: the lines put back were never the client's,
    -- and off is the client's chat. Switched on again, they come back.
    local added = self.added
    Windows(function(frame)
        if type(frame.RemoveMessagesByPredicate) ~= "function" then return end
        pcall(frame.RemoveMessagesByPredicate, frame, function(message)
            local ok, mine = pcall(function() return added[message] == true end)
            return ok and mine
        end)
    end)
    self.added = {}
    self.restored = false
end

M:Part("history", history)
