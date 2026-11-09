-- The search bar on the chat window.
--
-- Its shape is the owner's, from 2026-09-23: a switch, the top right corner of
-- the chat, and visible only while the mouse is over the chat or the input line
-- is open, since both mean the player is dealing with the chat and neither is
-- true while they are playing. It is also the answer to the commenter who
-- asked Better Forever Chat to remove its search button.
--
-- What it does is the owner's as well, from 2026-09-27: Enter prints every
-- line of that chat window that matches, again and whole, timestamp and sender
-- included. The line above them says what was searched for and how many were
-- found, and every line printed carries a small mark in front, so an old
-- whisper printed again cannot be taken for a new one, and a second search
-- does not find the first one's results.

local ADDON, FP = ...
local L, N = FP.L, FP.N
local M = FP:GetModule("Chat")

local search = {}

local MARK       = M.REPRINT
local MAX_PRINT  = 100
local CHECK      = 0.15
local FADE_TIME  = 0.25   -- seconds from nothing to fully drawn
local BAR_W, BAR_H = 150, 20
-- How long the bar stays once the mouse has left the chat, while it is moved
-- away from its corner: the time to cross from the chat to wherever it sits.
local GRACE      = 0.6

--- Prints every line of `frame` that matches `query`, under a line saying so.
local function Search(frame, query)
    query = (query or ""):match("^%s*(.-)%s*$")
    local pattern = FP:SearchPattern(query)
    if not (frame and pattern) then return end

    local found = {}
    for _, line in ipairs(M:LinesOf(frame)) do
        -- A line this printed earlier is not a result: it is a copy of one.
        if line.text:sub(1, #MARK) ~= MARK
           and FP:ChatVisibleText(line.text):find(pattern) then
            found[#found + 1] = line
        end
    end

    -- The newest ones when there are too many: printing a whole window back
    -- into itself pushes out the very lines it is printing.
    local first = math.max(1, #found - MAX_PRINT + 1)
    local shown = #found - first + 1
    -- Whole sentences for every case, so a language can word each one: one
    -- line, several, and several of which only the last are printed.
    local quoted = query:gsub("|", "||")
    local text
    if shown < #found then
        text = L["Search for \"%s\": %d matching lines, showing the latest %d"]:format(quoted, #found, shown)
    else
        text = FP:Plural(#found, N["Search for \"%s\": %d line"],
            N["Search for \"%s\": %d lines"]):format(quoted, #found)
    end
    local header = "|cff808080" .. text .. "|r"
    frame:AddMessage(MARK .. header)

    for index = first, #found do
        local line = found[index]
        frame:AddMessage(MARK .. line.text, line.r, line.g, line.b)
    end
end

-- ---------------------------------------------------------------------------
-- The bar
-- ---------------------------------------------------------------------------

--- The window the bar belongs to: the selected tab of the docked windows,
--- or the first window where there is no dock.
local function Target()
    local dock = rawget(_G, "GENERAL_CHAT_DOCK")
    local selected = rawget(_G, "FCFDock_GetSelectedWindow")
    if dock and type(selected) == "function" then
        local ok, frame = pcall(selected, dock)
        if ok and type(frame) == "table" then return frame end
    end
    return _G.DEFAULT_CHAT_FRAME or _G.ChatFrame1
end

local function InputOpen()
    local open = false
    M:EachFrame(function(frame, name)
        if open then return end
        local box = M:EditBoxOf(frame, name)
        if box and box.HasFocus then
            local ok, focus = pcall(box.HasFocus, box)
            open = ok and focus and true or false
        end
    end)
    return open
end

local function Build()
    if search.bar then return search.bar end

    local bar = CreateFrame("Frame", "ForeverPlusChatSearch", UIParent)
    bar:SetSize(BAR_W, BAR_H)
    bar:SetFrameStrata("HIGH")
    -- An offset may point past the screen's edge; the bar stops there.
    bar:SetClampedToScreen(true)
    bar:Hide()
    local bg = FP:Texture(bar, "BACKGROUND", FP.colors.bg)
    bg:SetAllPoints()
    FP:AddBorder(bar)

    -- The field stops short of the X at the end of the bar.
    local box = CreateFrame("EditBox", nil, bar)
    box:SetPoint("TOPLEFT", 5, 0)
    box:SetPoint("BOTTOMRIGHT", -(BAR_H + 2), 0)
    box:SetFontObject(FP:Font("body") or "GameFontHighlightSmall")
    box:SetAutoFocus(false)

    local hint = FP:FontString(bar, "OVERLAY", "faint")
    hint:SetPoint("LEFT", 6, 0)
    hint:SetText(L["Search"])

    -- An X that empties the field, asked for by the owner on 2026-09-27: a
    -- plain letter, the sign every search field uses. It is always there and
    -- reads dim while there is nothing to clear, so the bar keeps one shape.
    local clear = CreateFrame("Button", nil, bar)
    clear:SetSize(BAR_H, BAR_H)
    clear:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
    FP:Texture(clear, "HIGHLIGHT", FP.colors.hover):SetAllPoints()
    local cross = FP:FontString(clear, "OVERLAY", "body")
    cross:SetPoint("CENTER", 0, 0)
    cross:SetText("X")

    local function Hint()
        local empty = (box:GetText() or "") == ""
        hint:SetShown(empty)
        -- Read at the moment of painting: the color tokens are changed in
        -- place when the scheme changes.
        local color = empty and FP.colors.textOff or FP.colors.textOn
        cross:SetTextColor(color[1], color[2], color[3])
    end

    clear:SetScript("OnClick", function()
        box:SetText("")
        box:ClearFocus()
        Hint()
    end)
    FP:Tooltip(clear, L["Clear"], L["Empties the search field."])

    box:SetScript("OnTextChanged", Hint)
    box:SetScript("OnEnterPressed", function(self)
        FP:Safe("Chat:Search", Search, search.target or Target(), self:GetText())
        self:ClearFocus()
    end)
    box:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)

    -- The keyboard rules from every other field in the addon: captured only
    -- while focused, released on losing focus and on hide. A field that holds
    -- the keyboard without focus stops the character moving.
    box:SetScript("OnEditFocusGained", function(self) FP:HoldKeys(self) end)
    box:SetScript("OnEditFocusLost", function(self) FP:ReleaseKeys(self) end)
    bar:SetScript("OnHide", function() box:ClearFocus() end)

    -- Fading toward `goal`: see Fade below.
    bar.goal = 0
    bar:SetAlpha(0)

    bar:EnableMouse(true)
    bar:SetScript("OnMouseDown", function() box:SetFocus() end)
    FP:Tooltip(bar, L["Search"], L["Type a search and press Enter to display "
        .. "every matching line in this chat window again. Press Escape or "
        .. "click the X to clear the search."])

    bar.box = box
    Hint()
    search.bar = bar
    return bar
end

--- Where the bar sits in a chat window: what it hangs from, and the offset.
--
-- **From the window's background, not the window**, since the owner's report
-- of 2026-10-18: the combat log stretches its background up over its filter
-- bar, "My actions" and the rest, and starts the window itself that much
-- lower, so a bar hung from the window dropped onto the filter bar whenever
-- that tab was chosen. The backgrounds of docked windows lie on each other,
-- so the bar keeps its place across tabs. FloatingChatFrame_UpdateBackground
-- Anchors in the client's code for build 70425 puts a background 7 units
-- right of its window, 8 more beside a scroll bar, and 3 above it, plus the
-- filter bar's height; the offset takes the first three back, so every other
-- window shows the bar exactly where it always sat.
local function Anchor(target)
    local background = rawget(target, "Background")
    if type(background) ~= "table" or type(background.GetRight) ~= "function" then
        return target, -2, -2
    end
    local scrollbar = rawget(target, "ScrollBar") and 8 or 0
    return background, -2 - 7 - scrollbar, -2 - 3
end

--- Is the mouse over a chat window, its background included: the combat
--- log's filter bar lies outside the window itself.
local function OverWindow(target)
    local okOver, over = pcall(target.IsMouseOver, target)
    if okOver and over then return true end
    local background = rawget(target, "Background")
    if type(background) == "table" and type(background.IsMouseOver) == "function" then
        local okBack, overBack = pcall(background.IsMouseOver, background)
        return okBack and overBack == true
    end
    return false
end

--- Shows the bar over the chat it belongs to, or hides it.
local function Update()
    local bar = search.bar
    if not bar then return end

    -- From the corner it has always sat in, by the offsets on the page,
    -- CF6.8: one pair for every chat window.
    local x = tonumber(M.db.searchX) or 0
    local y = tonumber(M.db.searchY) or 0
    local moved = x ~= 0 or y ~= 0

    -- Standing all the time when the page asks for it, the owner's wish of
    -- 2026-10-18; then it neither comes nor goes, so it does not fade.
    local always = M.db.searchAlways == true

    local target = Target()
    local focused = bar.box:HasFocus()
    local visible = false
    if target and target:IsVisible() then
        visible = always or focused or OverWindow(target) or bar:IsMouseOver()
            or InputOpen()
        -- A bar moved out of the chat stays a moment after the mouse leaves
        -- it, so the mouse can reach it across the gap.
        local now = GetTime()
        if visible then
            search.wanted = now
        elseif moved and search.wanted and now - search.wanted < GRACE then
            visible = true
        end
    end

    -- How solid, and whether it fades: both under the bar's own switch.
    local fade = M.db.searchFade ~= false and not always
    local opacity = math.min(1, math.max(0.2, (tonumber(M.db.searchAlpha) or 70) / 100))

    if visible then
        if search.target ~= target or search.x ~= x or search.y ~= y then
            search.target, search.x, search.y = target, x, y
            local anchor, dx, dy = Anchor(target)
            bar:ClearAllPoints()
            bar:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", dx + x, dy + y)
        end
        bar.goal = opacity
        if not bar:IsShown() then
            bar:SetAlpha(fade and 0 or opacity)
            bar:Show()
        elseif not fade then
            bar:SetAlpha(opacity)
        end
    else
        -- Faded out by the OnUpdate, which hides it at nothing.
        bar.goal = 0
        if not fade then bar:Hide() end
    end
end

--- One step of the fade, every frame.
--
-- Fading, the owner's addition of 2026-09-27: the bar comes and goes over a
-- moment rather than at once, toward the opacity picked, `goal`. Not the
-- client's UIFrameFadeIn, which keeps every fade in one shared table that the
-- client's own chat fading reads as well.
--
-- **Driven from the ticker, which runs every frame anyway**, rather than from
-- the bar's own OnUpdate. The fade starts at nothing, and whether a frame
-- drawn at nothing still gets its own updates is not measured on this client:
-- this way it does not matter. Moved on 2026-09-27 when the bar was reported
-- gone; the cause turned out to be the module switched off, not the fade.
local function Fade(elapsed)
    local bar = search.bar
    if not (bar and bar:IsShown()) then return end
    local alpha, goal = bar:GetAlpha(), bar.goal or 0
    if math.abs(alpha - goal) < 0.01 then
        if alpha ~= goal then bar:SetAlpha(goal) end
        if goal == 0 then bar:Hide() end
        return
    end
    local step = elapsed / FADE_TIME
    alpha = (alpha < goal) and math.min(goal, alpha + step)
                           or math.max(goal, alpha - step)
    bar:SetAlpha(alpha)
end

function search:Apply()
    if not M.db.search then return self:Disable() end

    Build()
    if not self.ticker then
        self.ticker = CreateFrame("Frame")
        local waited = 0
        self.ticker:SetScript("OnUpdate", function(_, elapsed)
            Fade(elapsed)
            waited = waited + elapsed
            if waited < CHECK then return end
            waited = 0
            FP:Safe("Chat:SearchBar", Update)
        end)
    end
    self.ticker:Show()
end

search.Enable = search.Apply

--- Takes every line a search printed out of every window again.
local function RemovePrinted()
    M:EachFrame(function(frame)
        if type(frame.RemoveMessagesByPredicate) ~= "function" then return end
        pcall(frame.RemoveMessagesByPredicate, frame, function(message)
            local ok, printed = pcall(function() return message:sub(1, #MARK) == MARK end)
            return ok and printed
        end)
    end)
end

function search:Disable()
    if self.ticker then self.ticker:Hide() end
    if self.bar then self.bar:Hide() end
    -- The whole module switched off rather than the bar: its results were
    -- lines the client never wrote, and off is the client's chat.
    if not M.enabled then RemovePrinted() end
end

M:Part("search", search)
