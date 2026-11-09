-- The chat window itself: the wheel, fading, the look of the text, the buttons
-- and tabs around it, and the arrow keys in its input line.
--
-- **Selecting and copying chat text is left as the client has it**, which is
-- off. The client can mark chat text with a drag and copy it on release, and
-- this file switched that on, first behind a switch and then always. The
-- owner asked on 2026-09-27 to leave it exactly as it is natively, so nothing
-- here touches SetTextCopyable any more.
--
-- Every part remembers what a window had before it touched it, and puts that
-- back when switched off, so turning a setting off restores the client's own
-- state rather than a value this file guessed at.

local ADDON, FP = ...
local L = FP.L
local M = FP:GetModule("Chat")

-- ---------------------------------------------------------------------------
-- The mouse wheel, carried over from ChatTweaks
--
-- **The one place this module replaces rather than hooks.** ChatTweaks did it
-- in 0.1.0: the wheel handler of every chat window is ours, and the client's
-- is kept and put back when the part stops. A hook would scroll twice, the
-- client's lines and then ours. It has run since the first release without a
-- report, and it is on the list for phase 7's taint audit rather than changed
-- in passing.
-- ---------------------------------------------------------------------------

local wheel = { saved = {} }

local function OnMouseWheel(frame, delta)
    local db = M.db
    local step = db.scrollStep or 3
    local jump = db.fastScroll and IsShiftKeyDown and IsShiftKeyDown()
    if delta > 0 then
        if jump then frame:ScrollToTop()
        else for _ = 1, step do frame:ScrollUp() end end
    else
        if jump then frame:ScrollToBottom()
        else for _ = 1, step do frame:ScrollDown() end end
    end
end

function wheel:Frames()
    M:EachFrame(function(frame)
        if self.saved[frame] ~= nil then return end
        self.saved[frame] = frame:GetScript("OnMouseWheel") or false
        frame:EnableMouseWheel(true)
        frame:SetScript("OnMouseWheel", OnMouseWheel)
    end)
end

wheel.Enable = wheel.Frames

-- The handler reads the settings when the wheel turns, so there is nothing to
-- redo when one changes.
function wheel:Apply() end

function wheel:Disable()
    for frame, original in pairs(self.saved) do
        frame:SetScript("OnMouseWheel", original or nil)
    end
    wipe(self.saved)
end

M:Part("wheel", wheel)

-- ---------------------------------------------------------------------------
-- Fading
-- ---------------------------------------------------------------------------

local fade = { original = {} }

function fade:Frames()
    M:EachFrame(function(frame)
        if self.original[frame] == nil then
            local okFading, fading = pcall(frame.GetFading, frame)
            local okTime, visible = pcall(frame.GetTimeVisible, frame)
            -- Not `a and b or c`: a window that was not fading answers false,
            -- and the idiom would turn that into true.
            local was = true
            if okFading and fading ~= nil then was = fading and true or false end
            self.original[frame] = {
                fading  = was,
                visible = (okTime and tonumber(visible)) or 120,
            }
        end

        if M.db.noFade then
            -- Both, as ChatTweaks found: on some builds SetFading(false) alone
            -- does nothing once the visible time has already run out.
            pcall(frame.SetFading, frame, false)
            pcall(frame.SetTimeVisible, frame, 3600)
        else
            pcall(frame.SetFading, frame, true)
            pcall(frame.SetTimeVisible, frame, M.db.fadeAfter or 10)
        end
    end)
end

fade.Enable, fade.Apply = fade.Frames, fade.Frames

function fade:Disable()
    for frame, was in pairs(self.original) do
        pcall(frame.SetFading, frame, was.fading and true or false)
        pcall(frame.SetTimeVisible, frame, was.visible)
    end
    wipe(self.original)
end

M:Part("fade", fade)

-- ---------------------------------------------------------------------------
-- The background fading with the lines, Gematriah's request of 2026-10-19
--
-- **The client never fades a window's background out.** It brightens it while
-- the mouse is over the window and takes it back to the opacity the player
-- chose, read in FloatingChatFrame.lua for build 70425, so an opaque
-- background stays as a dark block where the lines have gone. With this on,
-- the background and the tabs go with the newest line still showing, by the
-- client's own formula, CalculateLineAlphaValueFromTimestamp in its
-- ScrollingMessageFrame.lua, so they fade in the same seconds as the text. A
-- new message, a scroll or a click into the window brings the lines back and
-- the background with them; so do the mouse over the window and its input
-- line in use, the owner's choices of 2026-10-20, and the tabs go too, his
-- word the same day.
--
-- **The client's own alpha is kept and only scaled.** A hook after every
-- SetAlpha on a piece of the background, a tab and the dock's overflow button
-- records what the client set and draws that times this part's factor. So the
-- opacity the player chose, 100 percent included, is exactly what comes back,
-- and switching this off draws the client's own values again. Nothing here
-- writes the client's fading or its Lua state, see the pitfall about Blizzard
-- methods that write in AGENTS.md; what is read is plain fields and methods
-- read in its code to write nothing. A tab with an unread message in its
-- window keeps the client's alpha, or a whisper in another tab would go
-- unseen.
--
-- The hooks go in the first time the setting is on, so a player who never
-- uses it gets none.
-- ---------------------------------------------------------------------------

local backdrop = {
    active = false,
    frames = {},    -- every chat window seen, in order
    known  = {},    -- [window] = its name
    factor = {},    -- [window] = 0 to 1, how much of the background shows
    wanted = {},    -- [piece] = the alpha the client last set
    owner  = {},    -- [piece] = its window, or "dock" for the overflow button
    isTab  = {},    -- [piece] = true for a tab
}
local drawing = false

local function BackdropWanted()
    return M.db.fadeBackground and not M.db.noFade
end

--- How long the background takes to go when the mouse leaves or the input
--- line closes over lines that have faded already: the client's own time for
--- fading a window out.
local function FadeOutTime()
    return tonumber(rawget(_G, "CHAT_FRAME_FADE_OUT_TIME")) or 2
end

--- The window whose lines decide for a piece: its own, or for a docked tab
--- and the overflow button, the window the dock shows.
local function Decider(piece)
    local frame = backdrop.owner[piece]
    local docked = frame == "dock"
        or (backdrop.isTab[piece] and type(frame) == "table"
            and FP:Truth(rawget(frame, "isDocked")))
    if docked then
        local dock = rawget(_G, "GENERAL_CHAT_DOCK")
        local selected = type(dock) == "table" and rawget(dock, "selected")
        if type(selected) == "table" then return selected end
        return nil
    end
    return frame
end

local function FactorFor(piece)
    if not backdrop.active then return 1 end
    if backdrop.isTab[piece] then
        local util = rawget(_G, "ChatFrameUtil")
        if type(util) == "table" and type(util.IsTabAlerting) == "function" then
            local ok, alerting = pcall(util.IsTabAlerting, piece)
            if ok and FP:Truth(alerting) then return 1 end
        end
    end
    local frame = Decider(piece)
    return (frame and backdrop.factor[frame]) or 1
end

--- One piece at the client's alpha times its factor.
local function DrawPiece(piece)
    local wanted = backdrop.wanted[piece]
    if wanted == nil then return end
    drawing = true
    pcall(piece.SetAlpha, piece, wanted * FactorFor(piece))
    drawing = false
end

local function HookPiece(piece, frame, isTab)
    if type(piece) ~= "table" or type(piece.SetAlpha) ~= "function" then return end
    backdrop.owner[piece], backdrop.isTab[piece] = frame, isTab or nil
    if backdrop.wanted[piece] ~= nil then return end

    local ok, alpha = pcall(piece.GetAlpha, piece)
    backdrop.wanted[piece] = (ok and FP:PlainNumber(alpha)) or 1
    hooksecurefunc(piece, "SetAlpha", function(self, value)
        if drawing then return end
        local plain = FP:PlainNumber(value)
        if plain then backdrop.wanted[self] = plain end
        if backdrop.active then DrawPiece(self) end
    end)
end

--- How much of the newest line still shows, 1 while the client is not
--- fading this window's lines at all: no fading, scrolled up, or text being
--- selected, which is when its own CanEffectivelyFade says no. A window that
--- cannot be read keeps its background.
local function LinesShowing(frame)
    local ok, alpha = pcall(function()
        if not (frame:GetFading() and frame:AtBottom()) or frame:IsSelectingText() then
            return 1
        end
        local now = GetTime()
        local override = rawget(frame, "overrideFadeTimestamp") or 0
        local best = 0
        for _, line in ipairs(rawget(frame, "visibleLines") or {}) do
            local info = rawget(line, "messageInfo")
            local stamp = type(info) == "table" and info.timestamp
            if type(stamp) == "number" then
                local a = frame:CalculateLineAlphaValueFromTimestamp(now,
                    math.max(stamp, override))
                if a > best then best = a end
            end
        end
        return best
    end)
    if ok and type(alpha) == "number" then return alpha end
    return 1
end

-- How far above a window the mouse still counts as over it: the tabs, as
-- FCF_OnUpdate counts them for build 70425, and the combat log's filter bar.
local TAB_ROOM = 28

--- The mouse over the window or its tabs, read here rather than through the
--- client's own hover: that one waits for the pointer to stand on the very
--- same pixel for a fifth of a second, which the owner's mouse never did on
--- 2026-10-20, so the lines came back while typing and not under the mouse.
local function Hovered(frame)
    local top = TAB_ROOM
    local quick = rawget(_G, "CombatLogQuickButtonFrame_Custom")
    if quick and frame == rawget(_G, "COMBATLOG") then
        local ok, height = pcall(quick.GetHeight, quick)
        top = top + ((ok and FP:PlainNumber(height)) or 0)
    end
    local ok, over = pcall(frame.IsMouseOver, frame, top, -2, -2, 2)
    if ok and FP:Truth(over) then return true end
    local buttons = rawget(frame, "buttonFrame")
    if type(buttons) == "table" and buttons.IsMouseOver then
        local okButtons, overButtons = pcall(buttons.IsMouseOver, buttons)
        if okButtons and FP:Truth(overButtons) then return true end
    end
    return false
end

--- The mouse over the window, or the client fading it in for a drag or a
--- resize, or its input line in use, however it was opened. Shared with the
--- reveal part below.
local function Attended(frame, name)
    if Hovered(frame) or FP:Truth(rawget(frame, "hasBeenFaded")) then return true end
    local box = M:EditBoxOf(frame, name)
    if box then
        local ok, focus = pcall(box.HasFocus, box)
        if ok and FP:Truth(focus) then return true end
    end
    return false
end

local function BackdropStep(elapsed)
    local changed = nil
    for _, frame in ipairs(backdrop.frames) do
        local target = 1
        local okShown, shown = pcall(frame.IsShown, frame)
        if okShown and FP:Truth(shown)
           and not Attended(frame, backdrop.known[frame]) then
            target = LinesShowing(frame)
        end
        local was = backdrop.factor[frame] or 1
        local now = math.min(1, math.max(target, was - elapsed / FadeOutTime()))
        if math.abs(now - was) > 0.001 then
            backdrop.factor[frame] = now
            changed = changed or {}
            changed[frame] = true
        end
    end
    if not changed then return end
    for piece in pairs(backdrop.wanted) do
        local frame = Decider(piece)
        if frame and changed[frame] then DrawPiece(piece) end
    end
end

function backdrop:Frames()
    if not self.active then return end
    local pieces = rawget(_G, "CHAT_FRAME_TEXTURES")
    M:EachFrame(function(frame, name)
        if not self.known[frame] then
            self.known[frame] = name
            self.frames[#self.frames + 1] = frame
        end
        if type(pieces) == "table" then
            for _, key in ipairs(pieces) do HookPiece(_G[name .. key], frame) end
        end
        HookPiece(_G[name .. "Tab"], frame, true)
    end)
    local dock = rawget(_G, "GENERAL_CHAT_DOCK")
    if type(dock) == "table" then HookPiece(rawget(dock, "overflowButton"), "dock") end
end

function backdrop:Apply()
    if not BackdropWanted() then return self:Disable() end
    if not self.driver then
        self.driver = CreateFrame("Frame")
        self.driver:Hide()
        self.driver:SetScript("OnUpdate", function(_, elapsed)
            -- A fault is said once rather than every frame, and the client
            -- draws the background again until the setting is applied anew.
            if not FP:Safe("Chat backdrop:Step", BackdropStep, elapsed) then
                backdrop:Disable()
            end
        end)
    end
    self.active = true
    self:Frames()
    self.driver:Show()
end

backdrop.Enable = backdrop.Apply

function backdrop:Disable()
    if not self.active then return end
    self.active = false
    if self.driver then self.driver:Hide() end
    wipe(self.factor)
    for piece in pairs(self.wanted) do DrawPiece(piece) end
end

M:Part("backdrop", backdrop)

-- ---------------------------------------------------------------------------
-- Faded lines back under the mouse and while typing, the owner's wish of
-- 2026-10-20
--
-- The client brings faded lines back only for a scroll or a click into the
-- window, through ResetAllFadeTimes in its ScrollingMessageFrame.lua, after
-- which they stay the window's visible time again. This does the same while
-- the mouse is over the window, as the client fades it in for that, and while
-- its input line has the focus, however it was opened. Once neither holds,
-- the lines stay their full time, as after a click, the owner's choice the
-- same day, and with "Fade the background with the messages" on the
-- background follows them.
--
-- **ResetAllFadeTimes writes the window's fade times in our name**, which the
-- pitfall about Blizzard methods that write would refuse. It is the write the
-- mouse wheel has made since 0.1.0, through ScrollUp and its siblings, which
-- call it for every turn of the wheel, and which the taint audit of
-- 2026-10-18 kept: the chat window is no protected frame, and the fields are
-- its own display state.
-- ---------------------------------------------------------------------------

local reveal = { active = false, frames = {}, known = {}, held = {} }
local REVEAL_EVERY = 1     -- seconds between two resets while held
local REVEAL_POLL  = 0.1   -- how often the mouse and the input are looked at

local function RevealWanted()
    return M.db.revealChat and not M.db.noFade
end

local function Reset(frame)
    pcall(frame.ResetAllFadeTimes, frame)
end

local function RevealStep()
    local now = GetTime()
    for _, frame in ipairs(reveal.frames) do
        local okShown, shown = pcall(frame.IsShown, frame)
        if okShown and FP:Truth(shown) and Attended(frame, reveal.known[frame]) then
            local last = reveal.held[frame]
            if not last or now - last >= REVEAL_EVERY then
                reveal.held[frame] = now
                Reset(frame)
            end
        elseif reveal.held[frame] then
            -- Once more as the mouse leaves or the input closes, so the full
            -- time counts from here, as after a click.
            reveal.held[frame] = nil
            Reset(frame)
        end
    end
end

function reveal:Frames()
    if not self.active then return end
    M:EachFrame(function(frame, name)
        if not self.known[frame] then
            self.known[frame] = name
            self.frames[#self.frames + 1] = frame
        end
    end)
end

function reveal:Apply()
    if not RevealWanted() then return self:Disable() end
    if not self.driver then
        self.driver = CreateFrame("Frame")
        self.driver:Hide()
        local waited = 0
        self.driver:SetScript("OnUpdate", function(_, elapsed)
            waited = waited + elapsed
            if waited < REVEAL_POLL then return end
            waited = 0
            -- Said once rather than every tenth of a second, as above.
            if not FP:Safe("Chat reveal:Step", RevealStep) then
                reveal:Disable()
            end
        end)
    end
    self.active = true
    self:Frames()
    self.driver:Show()
end

reveal.Enable = reveal.Apply

--- Nothing to give back: the lines fade by the client's own times again.
function reveal:Disable()
    if not self.active then return end
    self.active = false
    if self.driver then self.driver:Hide() end
    wipe(self.held)
end

M:Part("reveal", reveal)

-- ---------------------------------------------------------------------------
-- The look of the text: room between lines, and an outline
--
-- The text size is the client's own and lives in Chat.lua. The outline is set
-- together with it, since a font is a path, a size and flags in one call, and
-- the client's own size change reads the flags back from the window, so an
-- outline set here survives the tab menu.
-- ---------------------------------------------------------------------------

local look = { original = {} }

function look:Frames()
    M:EachFrame(function(frame)
        local was = self.original[frame]
        if not was then
            local okSpacing, spacing = pcall(frame.GetSpacing, frame)
            local okFont, _, _, flags = pcall(frame.GetFont, frame)
            was = {
                spacing = (okSpacing and tonumber(spacing)) or 0,
                flags   = (okFont and flags) or "",
            }
            self.original[frame] = was
        end

        -- Extra room on top of what the client had, so zero means the client's
        -- own spacing rather than a value this addon chose.
        pcall(frame.SetSpacing, frame, was.spacing + (M.db.spacing or 0))

        local outline = M.db.outline
        local flags = (outline and outline ~= "NONE") and outline or was.flags
        local ok, path, size = pcall(frame.GetFont, frame)
        if ok and path and size then pcall(frame.SetFont, frame, path, size, flags) end
    end)
end

look.Enable, look.Apply = look.Frames, look.Frames

function look:Disable()
    for frame, was in pairs(self.original) do
        pcall(frame.SetSpacing, frame, was.spacing)
        local ok, path, size = pcall(frame.GetFont, frame)
        if ok and path and size then pcall(frame.SetFont, frame, path, size, was.flags) end
    end
    wipe(self.original)
end

M:Part("look", look)

-- ---------------------------------------------------------------------------
-- The chat buttons
--
-- **Moved into a hidden frame rather than hidden.** The client shows these
-- buttons again whenever it likes and fades the frame holding the scroll
-- buttons in and out with the chat, so a Hide from here would not last and an
-- alpha would be overwritten. A frame whose parent is hidden stays hidden
-- whatever is done to it, and it takes no clicks. Switching off hands every
-- button back to the parent it came from.
-- ---------------------------------------------------------------------------

local buttons = { moved = {} }

-- The ones down the left of the chat, by the names the client gives them.
-- A name this build does not have costs nothing. The text to speech button
-- was found by the probe on 2026-09-27, shown and hanging off UIParent.
local LEFT_BUTTONS = {
    "ChatFrameMenuButton", "ChatFrameChannelButton",
    "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton",
    "QuickJoinToastButton", "TextToSpeechButtonFrame",
}

local stash

local function Stash(frame)
    if type(frame) ~= "table" or buttons.moved[frame] ~= nil
       or type(frame.SetParent) ~= "function" then
        return
    end
    local ok, parent = pcall(frame.GetParent, frame)
    if not ok then return end

    if not stash then
        stash = CreateFrame("Frame")
        stash:Hide()
    end
    buttons.moved[frame] = parent or false
    pcall(frame.SetParent, frame, stash)
end

function buttons:Frames()
    if not M.db.hideButtons then return self:Disable() end

    -- None of these are protected on any build this has seen, and the rule is
    -- kept anyway: a parent is changed out of combat or not at all.
    if InCombatLockdown and InCombatLockdown() then
        return FP:OutOfCombat("Chat buttons", function()
            if M.enabled then buttons:Frames() end
        end)
    end

    for _, name in ipairs(LEFT_BUTTONS) do Stash(_G[name]) end
    M:EachFrame(function(frame)
        -- The up, down and newest buttons beside each window, and the one
        -- that appears over the window when it is scrolled back.
        Stash(rawget(frame, "buttonFrame"))
        Stash(rawget(frame, "ScrollToBottomButton"))
    end)
end

buttons.Enable, buttons.Apply = buttons.Frames, buttons.Frames

function buttons:Disable()
    if not next(self.moved) then return end
    if InCombatLockdown and InCombatLockdown() then
        return FP:OutOfCombat("Chat buttons back", function() buttons:Disable() end)
    end
    for frame, parent in pairs(self.moved) do
        pcall(frame.SetParent, frame, parent or UIParent)
    end
    wipe(self.moved)
end

M:Part("buttons", buttons)

-- ---------------------------------------------------------------------------
-- Tabs only under the mouse, and the opacity of their background
--
-- **The tab's pictures and text go transparent, the tab itself is left
-- alone.** The client fades each tab's own alpha in and out with the chat and
-- reads the levels from globals, and writing those globals from here would put
-- this addon inside the client's fading code. The pieces a tab is drawn from
-- are a level below all that, and nothing the client does touches their alpha:
-- it only shows, hides and colors them, read in FloatingChatFrame.lua for
-- build 70425.
--
-- The glow a tab wears when a message arrives in it is left out, so a whisper
-- in a window nobody is looking at still says so.
--
-- **The background's opacity**, CF6.7 on CurseForge, settled with the owner on
-- 2026-10-18: one setting for every tab, which reaches the pieces behind the
-- name, the plain ones and the selected tab's, and leaves the name, the light
-- under the mouse and the glow as they are. At 100, the default, the client's
-- own look, and nothing is touched while the tabs are not hidden either.
-- ---------------------------------------------------------------------------

local tabs = { shown = nil }

-- The pieces of a tab's background, by the keys the client's tab template
-- gives them.
local BACKGROUND = { "Left", "Middle", "Right", "ActiveLeft", "ActiveMiddle", "ActiveRight" }

local function EachTab(fn)
    M:EachFrame(function(frame, name)
        local tab = _G[name .. "Tab"]
        if type(tab) == "table" then fn(tab, frame) end
    end)
end

--- The background's opacity from 0 to 1, as the page sets it.
local function Backdrop()
    return math.max(0, math.min(1, (tonumber(M.db.tabAlpha) or 100) / 100))
end

--- Every tab shown or hidden, its background at `backdrop`, the page's
--- opacity unless given.
local function ShowTabs(visible, backdrop)
    backdrop = backdrop or Backdrop()
    EachTab(function(tab)
        local glow = rawget(tab, "glow")
        local ground = {}
        for _, key in ipairs(BACKGROUND) do
            local region = rawget(tab, key)
            if region then ground[region] = true end
        end
        local ok, regions = pcall(function() return { tab:GetRegions() } end)
        if not ok then return end
        for _, region in ipairs(regions) do
            if region ~= glow then
                local alpha = visible and 1 or 0
                if visible and ground[region] then alpha = backdrop end
                pcall(region.SetAlpha, region, alpha)
            end
        end
    end)
    tabs.shown = visible
end

--- Is the mouse anywhere the tabs belong to: a chat window, a tab, the dock?
local function Hovered()
    local over = false
    local function Check(frame)
        if over or type(frame) ~= "table" then return end
        local okShown, shown = pcall(frame.IsVisible, frame)
        if not (okShown and shown) then return end
        local ok, yes = pcall(frame.IsMouseOver, frame)
        if ok and yes then over = true end
    end
    Check(_G.GeneralDockManager)
    EachTab(function(tab, frame)
        Check(tab)
        Check(frame)
    end)
    return over
end

local TAB_CHECK = 0.15

function tabs:Frames()
    if not M.db.tabsOnHover then
        if self.ticker then self.ticker:Hide() end
        -- Shown always, at the page's opacity: said for every window again,
        -- so one that opened since gets it too.
        if Backdrop() < 1 then return ShowTabs(true) end
        return self:Disable()
    end

    if not self.ticker then
        self.ticker = CreateFrame("Frame")
        local waited = 0
        self.ticker:SetScript("OnUpdate", function(_, elapsed)
            waited = waited + elapsed
            if waited < TAB_CHECK then return end
            waited = 0
            local want = Hovered()
            if want ~= tabs.shown then ShowTabs(want) end
        end)
    end
    self.ticker:Show()
    -- Said again for every window, including one that opened while the tabs
    -- were hidden and was never told.
    ShowTabs(Hovered())
end

tabs.Enable, tabs.Apply = tabs.Frames, tabs.Frames

--- The client's own tabs again, every piece fully drawn, once something here
--- touched them.
function tabs:Disable()
    if self.ticker then self.ticker:Hide() end
    if self.shown ~= nil then ShowTabs(true, 1) end
    self.shown = nil
end

M:Part("tabs", tabs)

-- ---------------------------------------------------------------------------
-- Arrow keys in the input line
--
-- **The client's input line ignores plain arrow keys, and no addon can change
-- that.** Its template carries ignoreArrows="true", read in the client's
-- ChatFrameEditBox.xml, and nothing in the API sets that flag;
-- SetAltArrowKeyMode is a different switch. Measured by the owner on
-- 2026-09-27: with that switch at false, as this file used to set it, Alt and
-- Up walked back through what was sent and Up alone did nothing. So the plain
-- keys are caught here, and the lines walked in by hand.
--
-- **Built against the recommendation**, the owner's choice once the costs were
-- put to him:
--   * a line walked in is written into the client's input by this addon, the
--     same kind of taint as a Shift click opening a closed input: a later chat
--     line or a /cast from that input can be refused, and not every time
--   * SetPropagateKeyboardInput is restricted in a fight, so a key cannot be
--     kept from the game the way it is outside one. See Keep below for what
--     stands in there since 2026-11-07, and what it costs
--
-- The lines are the ones the client adds to its own history, collected by a
-- hook on AddHistoryLine, so what comes back is what Alt and Up would bring.
-- Session only, like the client's own.
--
-- **Except a secure command, which this file never writes into the input**,
-- since the owner's report of 2026-11-07. /target player typed by hand went
-- through; the same line brought back with Up and sent came back as
-- ADDON_ACTION_FORBIDDEN TargetUnit(), with the client's dialog whose first
-- button disables the addon. From the Enter key to TargetUnit, the client's
-- ChatFrameEditBox.lua for build 70862 reads nothing this file writes, and he
-- measured the same day that SetText and Insert run from /run are both refused,
-- with none of this file's keys involved. So the refusal goes with text an addon
-- wrote, however the client knows. Nothing can press Alt and Up instead: the API
-- simulates no keys, only the mouse after a gamepad's input, and the input has no
-- call for its history. So such a line keeps its place in the list, Walk leaves
-- the input empty there and names Alt and Up in chat, his choice that day.
-- FP:IsSecureChatLine tells them apart.
-- ---------------------------------------------------------------------------

local input = { lines = {}, hooked = {} }
local MAX_LINES = 32

--- The chat input that has the keyboard right now, or nil.
local function ActiveBox()
    local util = type(ChatFrameUtil) == "table" and ChatFrameUtil
    local get = util and util.GetActiveWindow
    local box = type(get) == "function" and get() or nil
    if type(box) ~= "table" then return nil end
    local ok, focused = pcall(box.HasFocus, box)
    return (ok and focused) and box or nil
end

local function Remember(_, text)
    input.index = nil
    text = FP:Plain(text)
    if not text then return end
    local lines = input.lines
    if lines[#lines] ~= text then
        lines[#lines + 1] = text
        if #lines > MAX_LINES then table.remove(lines, 1) end
    end
end

--- One step back (-1) or forward (1) through what was sent.
local function Walk(box, step)
    local lines = input.lines
    if #lines == 0 then return end
    local index = math.max(1, math.min(#lines + 1, (input.index or #lines + 1) + step))
    local moved = index ~= input.index
    input.index = index
    local text = lines[index] or ""
    if FP:IsSecureChatLine(text) then
        -- Once per arrival, not for every press at the end of the list.
        if moved then
            FP:Print(L["Use Alt and Up for %s. The game blocks this command on the plain arrow keys."], text)
        end
        text = ""
    end
    -- Nothing written where nothing changes: every write here is in this
    -- addon's name, and an input left alone stays the player's own.
    local ok, same = pcall(function() return box:GetText() == text end)
    if ok and same then return end
    pcall(box.SetText, box, text)
    pcall(box.SetCursorPosition, box, #text)
end

local function Modified()
    return (IsAltKeyDown and IsAltKeyDown()) or (IsShiftKeyDown and IsShiftKeyDown())
        or (IsControlKeyDown and IsControlKeyDown())
end

local function InFight()
    return InCombatLockdown and InCombatLockdown()
end

--- Holds the keyboard below the listener, or lets go of it, for a fight.
--
-- The owner's report of 2026-11-07: his character walked while Up brought a line
-- back in a fight, since SetPropagateKeyboardInput is restricted there and cannot
-- decide key by key. EnableKeyboard is protected only on a protected frame, see
-- FP:HoldKeys, so a frame that always keeps keys may be switched on. **Switched on
-- during a press it counts only from the next press**, measured by him the same
-- day: with the listener switching it on for Up, the first press still walked and
-- the second did not.
--
-- So it stands for as long as a chat input has the keyboard in a fight, the
-- listener above it hearing a key first. **That costs every plain key the input
-- does not use itself**: a function key or the left arrow does nothing until the
-- input closes. **With a modifier held it stands aside**, so that a bind with Ctrl
-- or Alt goes on working, and Alt and Up reaches the input as ever.
local function Keep(on)
    local keeper = input.keeper
    if keeper then pcall(keeper.EnableKeyboard, keeper, on and true or false) end
end

--- The keeper as it should be right now. A listener not listening, as one built
--- in a fight, has no use for it, and nothing else may ever leave it on.
local function KeepInFight(fight)
    local listener = input.listener
    local ok, listening = false, false
    if listener then ok, listening = pcall(listener.IsKeyboardEnabled, listener) end
    Keep(fight and ok and FP:Truth(listening) and M.enabled and M.db.arrowHistory
         and not Modified() and ActiveBox())
end

--- Lets every key through, which is the only state safe to be caught in.
local function PassAll()
    local listener = input.listener
    if listener and not InFight() then
        pcall(listener.SetPropagateKeyboardInput, listener, true)
    end
end

local function OnKeyDown(listener, key)
    local walk = (key == "UP" or key == "DOWN") and M.enabled and M.db.arrowHistory
                 and not Modified() and ActiveBox()
    -- Up and Down with the input open are kept from the game, everything
    -- else goes on as if this frame were not there. In a fight the keeper below
    -- does that already, and is only looked at again, in case it was left on.
    if InFight() then
        KeepInFight(true)
    else
        pcall(listener.SetPropagateKeyboardInput, listener, not walk)
    end
    if walk then Walk(walk, key == "UP" and -1 or 1) end
end

local function OnEvent(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        -- The last moment a key can be let through before a fight begins, in
        -- case the one before it was kept. InCombatLockdown is not true yet.
        PassAll()
        KeepInFight(true)
    elseif event == "PLAYER_REGEN_ENABLED" then
        Keep(false)
    else
        KeepInFight(InFight())
    end
end

--- Listens to the keyboard only while a chat input has it, in a fight as well.
--
-- This used to stop at once in a fight, so an input opened there had no arrow
-- keys, the owner's report of 2026-11-07, while one opened before the fight kept
-- them. EnableKeyboard is protected only on a protected frame, which this is not,
-- see FP:HoldKeys; SetPropagateKeyboardInput is restricted, and PassAll has already
-- let every key through as the fight began.
--
-- **Never in a fight for a listener that keeps keys**, as one built during a fight
-- would, after a /reload there: nothing could tell it otherwise, and the player
-- could neither move nor cast until the fight ended.
local function Listen(on)
    local listener = input.listener
    if not listener then return end
    local fight = InFight()
    if not fight then
        pcall(listener.SetPropagateKeyboardInput, listener, true)
    elseif on then
        local ok, passes = pcall(listener.GetPropagateKeyboardInput, listener)
        if not (ok and FP:Truth(passes)) then return end
    end
    pcall(listener.EnableKeyboard, listener, on and true or false)
    Keep(on and fight and not Modified())
end

function input:Frames()
    if not self.keeper then
        -- A stratum below the listener, so the listener hears a key first. It
        -- needs a handler to count as taking keys, and keeps them by default.
        local keeper = CreateFrame("Frame", nil, UIParent)
        keeper:SetFrameStrata("LOW")
        pcall(keeper.SetPropagateKeyboardInput, keeper, false)
        keeper:SetScript("OnKeyDown", function() end)
        keeper:EnableKeyboard(false)
        self.keeper = keeper
    end
    if not self.listener then
        local listener = CreateFrame("Frame", nil, UIParent)
        pcall(listener.SetPropagateKeyboardInput, listener, true)
        listener:SetScript("OnKeyDown", function(frame, key)
            FP:Safe("Chat:ArrowKey", OnKeyDown, frame, key)
        end)
        listener:SetScript("OnKeyUp", PassAll)
        listener:RegisterEvent("PLAYER_REGEN_DISABLED")
        listener:RegisterEvent("PLAYER_REGEN_ENABLED")
        listener:RegisterEvent("MODIFIER_STATE_CHANGED")
        listener:SetScript("OnEvent", OnEvent)
        self.listener = listener
    end

    M:EachFrame(function(frame, name)
        local box = M:EditBoxOf(frame, name)
        if not box or self.hooked[box] then return end
        self.hooked[box] = true
        if hooksecurefunc and box.AddHistoryLine then
            hooksecurefunc(box, "AddHistoryLine", Remember)
        end
        if box.HookScript then
            box:HookScript("OnEditFocusGained", function()
                input.index = nil
                if M.enabled and M.db.arrowHistory then Listen(true) end
            end)
            box:HookScript("OnEditFocusLost", function() Listen(false) end)
        end
    end)
end

input.Enable, input.Apply = input.Frames, input.Frames

function input:Disable()
    Listen(false)
end

M:Part("input", input)

-- ---------------------------------------------------------------------------
-- The left edge, and the input line above the window
--
-- Species's two wishes on CurseForge of 2026-10-14, decided with the owner on
-- 2026-10-15: see *CF2* in planning/1.0.0/PLANNING-BUFFS-AND-LAYOUT.md. Read
-- in the client's code for build 70425 before a line was written.
--
-- **Both are settled in the main window's Edit Mode selection.** That window
-- is an Edit Mode system, and its selection, the outline Edit Mode draws and
-- drags it by, reaches 32 units past its left side for the buttons there, 60
-- above it for the tabs and 32 below it for the input line:
-- EditModeChatFrameSystemTemplate. Edit Mode keeps the window on the screen
-- by that rectangle, EditModeSystemMixin:UpdateClampOffsets, and snaps it by
-- it, so the selection itself moves rather than only the clamp. The clamp
-- alone was the first version, and the owner found on 2026-10-18 that it left
-- the window 32 units above the bottom edge, under an outline with nothing in
-- it. While the buttons are hidden and the switch is on, the selection's left
-- side comes in to the window's border; while the input line is above, its
-- top is that of the tabs standing on it, and its bottom the border's. The
-- window does not move by itself. The resize grip stands on the selection's
-- bottom right and keeps its place on the window. No other chat window is an
-- Edit Mode system or carries an inset.
--
-- **The input line above, between the window and its tabs.** Every window's
-- input line hangs from the window's bottom left in the client's XML, and the
-- client's code never moves it. While the switch is on, it sits right on the
-- window's top border instead, its other anchor kept, and **the tabs stand on
-- the input line**, the owner's word of 2026-10-18: first the input line went
-- above the tabs, then the tabs under the window, where the client's tab
-- textures, made to stand on something, looked upside down, and turning them
-- would have meant following every redraw of a tab. Lifted are the dock,
-- which carries the tabs of the docked windows and which the client hangs
-- from the main window's top in FCFDock_SetPrimary, and the tab of every
-- window of its own, which it hangs there in FCF_SetTabPosition. Hooks after
-- both put ours back.
--
-- **Or above the tabs**, the third place since 1.0.2, silhouetteone's
-- request of 2026-10-20, since the input line between pushed the tabs up: the
-- tabs stay where the client puts them and the input line sits on their top,
-- measured from the window's own tab. The choice is `inputPlace`, "below",
-- "between" or "above"; it was the switch `inputTop` until migration 9 to 10.
--
-- Nothing else of the client's is written, and all of it goes back to the
-- anchors and insets read before. All of it waits for the end of a fight,
-- like the buttons, although none of these frames is protected on this build.
--
-- **The window back on its own anchor whenever the insets change**, S5 of the
-- 1.0.2 brief: Species found it off the left edge again after every logout,
-- 2026-10-20. Read in the client's code for build 70450: at every layout,
-- EditModeManagerFrameMixin:UpdateLayoutInfo, Edit Mode first hangs every
-- system at the screen's top left, InitSystemAnchors, and then on its saved
-- anchor, ApplySystemAnchor, and the client keeps the window on the screen by
-- whatever insets it has at that moment. A layout applied before this module
-- has set its own keeps the window inside the client's selection, 32 units
-- from the left and from the bottom, and setting the insets afterwards moves
-- nothing that is already placed. So the window is hung on the anchor Edit
-- Mode saved for it again, after every layout and every change of the insets.
-- **Not measured**: which of the two happens at a login, and whether the
-- client moves the window or its anchor when it keeps it on the screen; the
-- anchor Edit Mode saved is right in both cases. `/fplus chat edges` prints
-- what happened since the login.
-- ---------------------------------------------------------------------------

local edges = { boxes = {}, tabs = {}, dock = nil, selection = nil, grip = nil,
                insets = nil, hooked = false, touched = false, log = {} }

-- What the edges did since the login, the newest last, for /fplus chat edges.
local LOG_MAX = 24

local function Note(fmt, ...)
    local ok, text = pcall(string.format, fmt, ...)
    local now = GetTime and GetTime() or 0
    local log = edges.log
    log[#log + 1] = string.format("%.1f ", now) .. (ok and text or fmt)
    if #log > LOG_MAX then table.remove(log, 1) end
end

--- Where the input line sits: "below", the client's place, "between" the
--- window and its tabs, or "above" the tabs.
local function InputPlace()
    local place = M.db and M.db.inputPlace
    if place == "between" or place == "above" then return place end
    return "below"
end

--- Whether either setting has anything to do: the left edge only while the
--- buttons are hidden, the input line whenever it is not below the window.
local function Wanting()
    local db = M.db
    return (InputPlace() ~= "below" or (db.leftEdge and db.hideButtons)) and true or false
end

local BORDER   = 4  -- the corners of the window's border, past its background
local TOP_EDGE = 7  -- the background 3 above the window, and its border 4 more
local LIFT     = 36 -- the input line, 32 high, on the border 4 above the background

--- Every anchor a region has, as it has them.
local function Points(region)
    local out = {}
    local ok, count = pcall(region.GetNumPoints, region)
    if not ok or type(count) ~= "number" then return out end
    for index = 1, count do
        local okPoint, point, relative, relativePoint, x, y = pcall(region.GetPoint, region, index)
        if okPoint and point then out[#out + 1] = { point, relative, relativePoint, x, y } end
    end
    return out
end

local function Place(region, points)
    pcall(region.ClearAllPoints, region)
    for _, p in ipairs(points) do
        pcall(region.SetPoint, region, p[1], p[2], p[3], p[4], p[5])
    end
end

--- How far above the window its border reaches, which is where the input line
--- sits while it is above.
local function TopEdge(frame, name)
    local background = _G[name .. "Background"]
    local ok, top, frameTop = pcall(function()
        return background and background:GetTop(), frame:GetTop()
    end)
    if ok and top and frameTop and top >= frameTop then return top - frameTop + BORDER end
    return TOP_EDGE
end

--- How far above the window its tabs reach while they stand where the client
--- puts them, which is where the input line sits while it is above them: a
--- tab 32 high on the background, 3 above the window, without a measure.
--
-- Worked out from the background and the tab's height rather than read off
-- the tab, which may have been put back down a moment ago and not be drawn
-- there yet. FCF_SetTabPosition and FCFDock_SetPrimary stand every tab on
-- the background's top.
local TABS_TOP = 35

local function TabsTop(frame, name)
    local tab, background = _G[name .. "Tab"], _G[name .. "Background"]
    local ok, base, frameTop, height = pcall(function()
        return background:GetTop(), frame:GetTop(), tab:GetHeight()
    end)
    if ok and base and frameTop and height and height > 0 and base >= frameTop then
        return base - frameTop + height
    end
    return TABS_TOP
end

--- Every window's input line right on its top border, or on top of its tabs,
--- or back where it was. `place` is "below", "between" or "above".
--
-- Only the anchor the client's XML gives it, its top left on the window's
-- bottom left, is replaced; an input line anchored any other way, by another
-- addon say, is left as it is.
local function PlaceBoxes(place)
    M:EachFrame(function(frame, name)
        local box = M:EditBoxOf(frame, name)
        if not box then return end
        local saved = edges.boxes[box]
        if place == "below" then
            if saved then
                Place(box, saved)
                edges.boxes[box] = nil
            end
            return
        end
        if not saved then
            saved = Points(box)
            if #saved == 0 then return end
            edges.boxes[box] = saved
        end
        local room = place == "above" and TabsTop(frame, name) or TopEdge(frame, name)
        local points, moved = {}, false
        for _, p in ipairs(saved) do
            if p[1] == "TOPLEFT" and p[2] == frame and p[3] == "BOTTOMLEFT" then
                points[#points + 1] = { "BOTTOMLEFT", frame, "TOPLEFT", p[4], room }
                moved = true
            else
                points[#points + 1] = p
            end
        end
        if moved then
            Place(box, points)
        else
            edges.boxes[box] = nil
        end
    end)
end

--- The client's dock for the docked windows' tabs, or nil.
local function DockOf()
    local dock = rawget(_G, "GENERAL_CHAT_DOCK") or rawget(_G, "GeneralDockManager")
    return type(dock) == "table" and dock or nil
end

--- The two anchors FCFDock_SetPrimary gives the dock, its bottom corners on
--- the top corners of the main window's background, among what it has now.
local function DockAnchors(dock)
    local left, right
    for _, p in ipairs(Points(dock)) do
        if p[1] == "BOTTOMLEFT" and p[3] == "TOPLEFT" then left = p end
        if p[1] == "BOTTOMRIGHT" and p[3] == "TOPRIGHT" then right = p end
    end
    if left and right and left[2] == right[2] then return { left, right } end
    return nil
end

--- How far above the window's background the input line reaches while it is
--- above, which is what the tabs stand on then.
local function Lift(frame, name)
    local box = M:EditBoxOf(frame, name)
    local background = _G[name .. "Background"]
    local ok, top, base = pcall(function()
        return box and box:GetTop(), background and background:GetTop()
    end)
    if ok and top and base and top > base then return top - base end
    return LIFT
end

--- The dock on the main window's input line, or back on the window.
--
-- The client hangs its bottom corners from the background's top corners;
-- raised, the same two anchors are lifted by the input line, and put back at
-- nothing when the switch goes off.
local function PlaceDock(raised)
    local dock = DockOf()
    local anchors = dock and DockAnchors(dock)
    if not anchors then return end
    local lift = 0
    if raised then
        local primary = dock.primary
        if type(primary) ~= "table" then return end
        lift = Lift(primary, primary:GetName() or "")
    elseif not edges.dock then
        return
    end
    local background = anchors[1][2]
    Place(dock, {
        { "BOTTOMLEFT", background, "TOPLEFT", anchors[1][4] or 0, lift },
        { "BOTTOMRIGHT", background, "TOPRIGHT", anchors[2][4] or 0, lift },
    })
    edges.dock = raised or nil
end

--- Every tab on its window's input line, or back on the window: the dock, and
--- the tab of every window of its own.
--
-- Such a tab hangs by its bottom left from the background's top left, set in
-- FCF_SetTabPosition, and is lifted the same way. A docked tab is anchored to
-- the dock or to the tab before it and goes up with the dock.
local function PlaceTabs(raised)
    PlaceDock(raised)
    M:EachFrame(function(frame, name)
        local tab = _G[name .. "Tab"]
        local background = _G[name .. "Background"]
        if type(tab) ~= "table" or type(background) ~= "table" then return end
        local now = Points(tab)
        local p = #now == 1 and now[1]
        if not (p and p[1] == "BOTTOMLEFT" and p[2] == background and p[3] == "TOPLEFT") then
            -- Docked, or anchored by somebody else: not this function's.
            edges.tabs[tab] = nil
            return
        end
        if raised then
            Place(tab, { { "BOTTOMLEFT", background, "TOPLEFT", p[4] or 0, Lift(frame, name) } })
            edges.tabs[tab] = true
        elseif edges.tabs[tab] then
            Place(tab, { { "BOTTOMLEFT", background, "TOPLEFT", p[4] or 0, 0 } })
            edges.tabs[tab] = nil
        end
    end)
end

--- Puts ours back after the client anchors the dock or a tab again. Hooked
--- once; asks every time whether there is anything to do.
local function Hook()
    if edges.hooked or not hooksecurefunc then return end
    edges.hooked = true
    local function Again()
        if M.enabled and InputPlace() ~= "below" then
            FP:Safe("Chat edges:Tabs", edges.Apply, edges)
        end
    end
    for _, name in ipairs({ "FCFDock_SetPrimary", "FCF_SetTabPosition" }) do
        if type(rawget(_G, name)) == "function" then hooksecurefunc(name, Again) end
    end
    -- After the layout, so the anchor Edit Mode has just applied is the one
    -- the window is hung on again. Looked up at the call, since the part is
    -- defined further down.
    local manager = rawget(_G, "EditModeManagerFrame")
    if type(manager) == "table" and type(manager.UpdateLayoutInfo) == "function" then
        hooksecurefunc(manager, "UpdateLayoutInfo", function()
            FP:Safe("Chat edges:Layout", edges.AfterLayout)
        end)
    end
end

--- How far above the main window its tabs reach, or nil.
local function TabsAbove(frame)
    local regions = { _G[(frame:GetName() or "") .. "Tab"] }
    local dock = DockOf()
    if dock and dock.primary == frame then regions[#regions + 1] = dock end
    local ok, frameTop = pcall(frame.GetTop, frame)
    if not (ok and frameTop) then return nil end
    local highest
    for _, region in ipairs(regions) do
        local okTop, top = pcall(region.GetTop, region)
        if okTop and top and (not highest or top > highest) then highest = top end
    end
    return highest and math.max(0, highest - frameTop) or nil
end

--- How far the window covers past one of its own sides once nothing hangs
--- there: its background and the border around it. `side` is "GetLeft" or
--- "GetBottom", the two the switches clear.
local function Outside(frame, side)
    local background = _G[(frame:GetName() or "") .. "Background"]
    local ok, from, to = pcall(function()
        return background and background[side](background), frame[side](frame)
    end)
    if ok and from and to then return math.min(0, from - to - BORDER) end
    return 0
end

--- The selection's offsets from the window's corners: the client's own, with
--- the room for the buttons, the input line and the tabs where they really
--- are. With the input line in either upper place nothing is below the
--- window, so its border may reach the bottom of the screen.
local function Wanted(frame, left, right, top, bottom)
    local db = M.db
    if db.leftEdge and db.hideButtons then left = Outside(frame, "GetLeft") end
    if InputPlace() ~= "below" then
        local box = M:EditBoxOf(frame)
        local ok, boxTop, frameTop = pcall(function()
            return box and box:GetTop(), frame:GetTop()
        end)
        if ok and boxTop and frameTop and boxTop > frameTop then
            top = math.max(top, boxTop - frameTop)
        end
        top = math.max(top, TabsAbove(frame) or 0)
        bottom = Outside(frame, "GetBottom")
    end
    return left, right, top, bottom
end

--- Where the main window's left and bottom edges are on the screen, for the
--- log: "12.0/40.0", or "?" before the client has placed it.
local function Where(frame)
    local ok, left, bottom = pcall(function() return frame:GetLeft(), frame:GetBottom() end)
    if ok and type(left) == "number" and type(bottom) == "number" then
        return string.format("%.1f/%.1f", left, bottom)
    end
    return "?"
end

--- The main window hung on the anchor Edit Mode keeps for it, so the client
--- keeps it on the screen by the insets set just now.
--
-- Through the frame's own SetPoint and ClearAllPoints, which Edit Mode keeps
-- as SetPointBase and ClearAllPointsBase before it puts its own in their
-- place, EditModeSystemMixin:OnSystemLoad: so nothing of Edit Mode's runs or
-- is written from here, and the anchor is the one it saved, divided by the
-- window's scale the way ApplySystemAnchor divides it. Without a saved
-- anchor the window's own points are set again, which places it anew.
-- Never while it is dragged.
local function Reanchor(frame, why)
    if type(frame.SetPointBase) ~= "function"
       or type(frame.ClearAllPointsBase) ~= "function" then
        return
    end
    local okDrag, dragging = pcall(function()
        local selection = frame.Selection
        return frame.isDragging
            or (selection and selection.IsDragging and selection:IsDragging())
    end)
    if not okDrag or dragging then return end

    local okScale, scale = pcall(frame.GetScale, frame)
    scale = (okScale and type(scale) == "number" and scale > 0) and scale or 1
    local points = {}
    local info = rawget(frame, "systemInfo")
    if type(info) == "table" then
        for _, key in ipairs({ "anchorInfo", "anchorInfo2" }) do
            local a = info[key]
            if type(a) == "table" and a.point and type(a.offsetX) == "number"
               and type(a.offsetY) == "number" then
                points[#points + 1] = { a.point, a.relativeTo, a.relativePoint,
                                        a.offsetX / scale, a.offsetY / scale }
            end
        end
    end
    local from = "Edit Mode's anchor"
    if #points == 0 then
        points, from = Points(frame), "its own points"
    end
    if #points == 0 then return end

    local before = Where(frame)
    pcall(frame.ClearAllPointsBase, frame)
    for _, p in ipairs(points) do
        pcall(frame.SetPointBase, frame, p[1], p[2], p[3], p[4], p[5])
    end
    Note("%s: hung on %s, %s before, %s after", why, from, before, Where(frame))
end

--- Whether an anchor holds a corner of the window to the same corner, the way
--- an anchor in XML without a frame named holds it to its parent.
local function OnCorner(p, corner, frame)
    return p[1] == corner and (p[2] == frame or p[2] == nil)
       and (p[3] == corner or p[3] == nil)
end

--- The main window's selection where the settings want it, or back where the
--- client had it.
--
-- Only the shape the client's XML gives it is moved, its top left and bottom
-- right on the window's own corners; a selection anchored any other way is
-- left alone. The insets Edit Mode works out from it at its next layout are
-- set at once as well, the way UpdateClampOffsets sets them, and the window
-- is hung on its anchor again whenever they change or `force` asks for it.
local function PlaceSelection(wanting, force)
    local frame = _G.ChatFrame1
    local selection = type(frame) == "table" and frame.Selection
    if type(selection) ~= "table" or type(frame.SetClampRectInsets) ~= "function" then
        return
    end
    local grip = frame.EditModeResizeButton

    if not edges.selection then
        if not wanting then return end
        local points = Points(selection)
        if #points ~= 2 or not OnCorner(points[1], "TOPLEFT", frame)
           or not OnCorner(points[2], "BOTTOMRIGHT", frame) then
            return
        end
        edges.selection = points
        edges.grip = type(grip) == "table" and Points(grip) or nil
    end

    local saved = edges.selection
    local left, top, right, bottom = saved[1][4], saved[1][5], saved[2][4], saved[2][5]
    if wanting then left, right, top, bottom = Wanted(frame, left, right, top, bottom) end

    Place(selection, {
        { "TOPLEFT", frame, "TOPLEFT", left, top },
        { "BOTTOMRIGHT", frame, "BOTTOMRIGHT", right, bottom },
    })
    -- However far the bottom moved, the grip keeps its place on the window.
    local hung = edges.grip
    if hung and #hung == 1 and hung[1][2] == selection then
        local p = hung[1]
        Place(grip, { { p[1], p[2], p[3], p[4], p[5] - (bottom - saved[2][5]) } })
    end
    pcall(frame.SetClampRectInsets, frame, left, right, top, bottom)

    -- A change smaller than half a unit is the measuring, not a change.
    local was, changed = edges.insets, false
    local now = { left, right, top, bottom }
    for index = 1, 4 do
        if not was or math.abs((was[index] or 0) - now[index]) >= 0.5 then changed = true end
    end
    edges.insets = wanting and now or nil
    if changed or force then
        Note("insets %.1f %.1f %.1f %.1f%s", left, right, top, bottom,
            wanting and "" or ", the client's")
        Reanchor(frame, force and "after a layout" or "insets changed")
    end

    if not wanting then edges.selection, edges.grip = nil, nil end
end

--- Everything in place for the settings: `force` hangs the window on its
--- anchor again even when the insets did not change, which a new layout of
--- Edit Mode's asks for.
local function ApplyEdges(force)
    -- Nothing of the client's is touched while neither switch asks for it,
    -- and what was touched goes back the moment neither does.
    local wanting = Wanting()
    if not wanting and not edges.touched then return end
    if InCombatLockdown and InCombatLockdown() then
        return FP:OutOfCombat("Chat edges", function()
            if M.enabled then ApplyEdges(force) end
        end)
    end
    Hook()
    -- The input line and the tabs first: the selection is measured from where
    -- they are. Between the window and its tabs, the tabs are lifted by the
    -- input line under them; above the tabs, the input line is placed on top
    -- of the tabs where the client keeps them, so they go back first.
    local place = InputPlace()
    if place == "above" then
        PlaceTabs(false)
        PlaceBoxes(place)
    else
        PlaceBoxes(place)
        PlaceTabs(place == "between")
    end
    PlaceSelection(wanting, force)
    edges.touched = wanting
end

--- After Edit Mode has applied a layout: at every login, at a change of
--- layout and when changes in Edit Mode are reverted.
function edges.AfterLayout()
    if not M.enabled then return end
    if not (Wanting() or edges.touched) then return end
    Note("Edit Mode applied a layout")
    ApplyEdges(true)
end

-- Not edges.Apply itself as Enable and Frames: a part is called with the
-- module as its second argument, which would read as `force`.
function edges:Apply() ApplyEdges(false) end

edges.Enable, edges.Frames = edges.Apply, edges.Apply

function edges:Disable()
    if not edges.touched then return end
    if InCombatLockdown and InCombatLockdown() then
        return FP:OutOfCombat("Chat edges back", function() edges:Disable() end)
    end
    PlaceBoxes("below")
    PlaceTabs(false)
    PlaceSelection(false)
    edges.touched = false
end

--- What the edges are doing, for /fplus chat edges. English, like every
--- answer to a typed command.
function M:EdgeStatus()
    local db = self.db or {}
    FP:Print("Chat edges: module %s, left edge %s with buttons hidden %s, "
        .. "input line %s, touched %s.", self.enabled and "on" or "off",
        tostring(db.leftEdge), tostring(db.hideButtons), InputPlace(),
        tostring(edges.touched))
    local frame = _G.ChatFrame1
    if type(frame) ~= "table" then return FP:Print("There is no ChatFrame1.") end

    local function Name(region)
        if region == nil then return "parent" end
        if type(region) == "string" then return region end
        local ok, name = pcall(region.GetName, region)
        return (ok and name) or "anonymous"
    end
    local function Line(label, points)
        local out = {}
        for _, p in ipairs(points) do
            out[#out + 1] = string.format("%s %s %s %.1f %.1f", tostring(p[1]),
                Name(p[2]), tostring(p[3]), tonumber(p[4]) or 0, tonumber(p[5]) or 0)
        end
        DEFAULT_CHAT_FRAME:AddMessage("  " .. label .. ": "
            .. (#out > 0 and table.concat(out, ", ") or "none"))
    end

    Line("window", Points(frame))
    local okLeft, left = pcall(frame.GetLeft, frame)
    local okBottom, bottom = pcall(frame.GetBottom, frame)
    DEFAULT_CHAT_FRAME:AddMessage(string.format("  left %s, bottom %s",
        okLeft and tostring(left) or "?", okBottom and tostring(bottom) or "?"))
    local okInsets, l, r, t, b = pcall(frame.GetClampRectInsets, frame)
    if okInsets then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  insets %s %s %s %s",
            tostring(l), tostring(r), tostring(t), tostring(b)))
    end
    if type(frame.Selection) == "table" then Line("selection", Points(frame.Selection)) end

    local info = rawget(frame, "systemInfo")
    if type(info) == "table" then
        for _, key in ipairs({ "anchorInfo", "anchorInfo2" }) do
            local a = info[key]
            if type(a) == "table" then
                Line("Edit Mode " .. key, { { a.point, a.relativeTo, a.relativePoint,
                                              a.offsetX, a.offsetY } })
            end
        end
        DEFAULT_CHAT_FRAME:AddMessage("  default position: "
            .. tostring(info.isInDefaultPosition))
    else
        DEFAULT_CHAT_FRAME:AddMessage("  no Edit Mode layout on the window yet")
    end
    for _, line in ipairs(edges.log) do
        DEFAULT_CHAT_FRAME:AddMessage("  |cff888888" .. line .. "|r")
    end
end

M:Part("edges", edges)
