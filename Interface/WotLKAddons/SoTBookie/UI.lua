--========================================================================--
-- SoTBookie / UI.lua
-- The single window (Aktivni | Historie | Dluhy | Zebricek | Nastaveni)
-- plus its confirm dialogs. All user-facing text is Czech WITHOUT
-- diacritics beyond Latin-1 (stock 3.3.5 font lacks the glyphs).
-- Hand-built Blizzard-style frames: this addon bundles no AceGUI/AceConfig.
-- Contract: Docs/DESIGN.md ("UI"). Load-bearing rules implemented here:
--  * never auto-opens, never plays a sound, no OnUpdate handler anywhere
--  * every string that came off the wire is rendered through W.EscapeText
--  * row frames are pooled per pane (create once, reuse, hide the surplus)
--    and a refresh only re-renders the pane that is currently visible
--  * no rules and no money math live here - all of it is Core's (W:Do*,
--    W:ComputePlan, W:PreviewPlan); the UI only asks and renders
--========================================================================--

local W = LibStub("AceAddon-3.0"):GetAddon("SoTBookie")

---------------------------------------------------------------- dimensions

local WIN_W, WIN_H  = 500, 560
local PANE_INSET    = 10
local PANE_W        = WIN_W - PANE_INSET * 2   -- 480
local SCROLLBAR_W   = 26                       -- room for the template's bar
local CONTENT_W     = PANE_W - SCROLLBAR_W     -- 454
local TEXT_W        = CONTENT_W - 10
local CREATE_BAR_H  = 34
local ROW_GAP       = 6
local LINE_GAP      = 2
local BTN_H         = 21
local PAY_H         = 14
local STAT_ROW_H    = 16
local DEBT_ROW_H    = 30
local BIG_STAKE     = 1000                     -- confirm above this stake
local MAX_POPUP_PAY = 8                        -- payment lines in the dialog

local C_OPEN   = "|cff40ff40"
local C_LOCKED = "|cffff9a20"
local C_MINE   = "|cffffd200"
local C_GREY   = "|cff909090"
local C_END    = "|r"

local COL_GOLD  = { 1.00, 0.82, 0.00 }
local COL_GREY  = { 0.60, 0.60, 0.60 }
local COL_GREEN = { 0.25, 1.00, 0.25 }
local COL_RED   = { 1.00, 0.30, 0.30 }

-- SetTexture returns truthy only when the file exists in this client -
-- probe candidates at load so a wrong guess can never leave an invisible
-- (yet clickable) button. The last candidate must be a stock item icon.
local texProbe
local function firstValidTexture(...)
    texProbe = texProbe or UIParent:CreateTexture()
    for i = 1, select("#", ...) do
        local path = select(i, ...)
        if texProbe:SetTexture(path) then
            texProbe:SetTexture(nil)
            return path
        end
    end
    return (select(select("#", ...), ...))
end

-- Padlock pair for the author's lock TOGGLE: solid golden Blizzard lock
-- button faces, one per state, so open/locked is readable at a glance
-- (the earlier GuildBank lock was small and washed-out - UAT round 4).
local LOCK_LOCKED = firstValidTexture(
    "Interface\\Buttons\\LockButton-Locked-Up",
    "Interface\\GuildBankFrame\\UI-GuildBankFrame-Lock",
    "Interface\\Icons\\INV_Misc_Key_03")
local LOCK_UNLOCKED = firstValidTexture(
    "Interface\\Buttons\\LockButton-Unlocked-Up",
    "Interface\\GuildBankFrame\\UI-GuildBankFrame-Lock",
    "Interface\\Icons\\INV_Misc_Key_03")
local LOCK_IS_ICON = (LOCK_LOCKED:find("^Interface\\Icons\\")
    or LOCK_UNLOCKED:find("^Interface\\Icons\\")) and true or false

------------------------------------------------------------------- state

local frame                 -- the window; the global name "SoTBookieFrame" only
                            -- exists because UISpecialFrames needs one
local panes   = {}          -- ["active"|"history"|"stats"] = pane frame
local tabButtons = {}
local currentTab = "active"
local refresh, selectTab    -- forward declarations (used by row callbacks)

local TABS = {
    { key = "active",   label = "Aktivni" },
    { key = "history",  label = "Historie" },
    { key = "debts",    label = "Dluhy" },
    { key = "stats",    label = "Zebricek" },
    { key = "settings", label = "Nastaveni" },
}

------------------------------------------------------------------ helpers

local function esc(s) return W.EscapeText(s) end

-- 3.3.5 auto-sizes a width-constrained FontString, but the two measurements
-- disagree on some builds; take the larger one so wrapped text never clips.
local function textHeight(fs)
    local a, b = fs:GetStringHeight(), fs:GetHeight()
    return (b > a) and b or a
end

-- Multi-piece Blizzard templates (UIPanelButtonTemplate, InputBoxTemplate)
-- REQUIRE a named frame on 3.3.5: their middle texture anchors to
-- "$parentLeft"/"$parentRight" by global name — anonymous frames render
-- only the two end caps.
local buttonCounter = 0
local function makeButton(parent, label, onClick, minWidth)
    buttonCounter = buttonCounter + 1
    local b = CreateFrame("Button", "SoTBookieButton" .. buttonCounter,
        parent, "UIPanelButtonTemplate")
    b:SetHeight(BTN_H)
    b:SetText(label)
    -- auto-size to the label so Czech words never touch the caps
    local fs = b:GetFontString()
    local w = ((fs and fs:GetStringWidth()) or 40) + 22
    if minWidth and minWidth > w then w = minWidth end
    b:SetWidth(math.ceil(w))
    b:SetScript("OnClick", onClick)
    return b
end

-- Small icon button (author "admin" actions) with a mouseover tooltip.
-- Plain Button, no template - anonymous frames are safe here (no $parent
-- anchored pieces). isItemIcon crops the standard icon border fringe.
local function makeIcon(parent, texture, isItemIcon, tipTitle, tipText, onClick, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(size or 18)
    b:SetHeight(size or 18)
    b:SetNormalTexture(texture)
    if isItemIcon then
        local t = b:GetNormalTexture()
        if t then t:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
    end
    b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    -- 3.3.5 leaves a path-set highlight texture unanchored on plain Buttons:
    -- it drew as a stray square offset from the icon (UAT round 4). Pin it.
    local hl = b:GetHighlightTexture()
    if hl then
        hl:ClearAllPoints()
        hl:SetAllPoints(b)
    end
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        -- title/text may be functions: some tooltips depend on live state
        -- (lock toggle wording, which chat channel an announce would hit)
        GameTooltip:SetText(type(tipTitle) == "function" and tipTitle(self) or tipTitle)
        local txt = type(tipText) == "function" and tipText(self) or tipText
        if txt then GameTooltip:AddLine(txt, 0.8, 0.8, 0.8, true) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function makeCheck(parent, label, onClick)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetWidth(22)
    cb:SetHeight(22)
    cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    cb.label:SetJustifyH("LEFT")
    if label then cb.label:SetText(label) end
    cb:SetScript("OnClick", onClick)
    return cb
end

local function setChecked(cb, value)
    if value then cb:SetChecked(true) else cb:SetChecked(false) end
end

local function color(fs, c) fs:SetTextColor(c[1], c[2], c[3]) end

local function rowSeparator(row)
    local line = row:CreateTexture(nil, "BACKGROUND")
    line:SetTexture(0.4, 0.4, 0.4, 0.35)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 2, 0)
    line:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -2, 0)
end

-- Row pooling: rows are created on first use and reused forever after.
local function acquireRow(pane, index, ctor)
    local row = pane.rows[index]
    if not row then
        row = ctor(pane)
        pane.rows[index] = row
    end
    row:Show()
    return row
end

local function hideSurplusRows(pane, used)
    for i = used + 1, #pane.rows do pane.rows[i]:Hide() end
end

local function anchorRow(pane, row, prev)
    row:ClearAllPoints()
    if prev then
        row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -ROW_GAP)
    else
        row:SetPoint("TOPLEFT", pane.content, "TOPLEFT", 0, 0)
    end
end

local function finishList(pane, used, total)
    hideSurplusRows(pane, used)
    pane.content:SetHeight(total > 0 and total or 1)
    if used == 0 then pane.empty:Show() else pane.empty:Hide() end
end

local function campLine(bet, side, me)
    local names, count = {}, 0
    for name, s in pairs(bet.p) do
        if s == side then
            count = count + 1
            names[count] = name
        end
    end
    table.sort(names, W.ByteLess)
    for i = 1, count do
        if names[i] == me then
            names[i] = C_MINE .. esc(names[i]) .. C_END
        else
            names[i] = esc(names[i])
        end
    end
    local label = (side == "Y") and "ANO" or "NE"
    if count == 0 then
        return ("%s (0): %s-%s"):format(label, C_GREY, C_END)
    end
    return ("%s (%d): %s"):format(label, count, table.concat(names, ", "))
end

local STATUS_WORDS = {
    open = "OTEVRENA", locked = "ZAMCENA",
    cancelled = "ZRUSENA", resolved = "ROZHODNUTA",
}

local function statusWord(bet)
    if bet.status == "open" then return C_OPEN .. STATUS_WORDS.open .. C_END end
    if bet.status == "locked" then
        -- inline padlock glyph so "locked" is visible at a glance
        return C_LOCKED .. ("|T%s:12|t "):format(LOCK_LOCKED)
            .. STATUS_WORDS.locked .. C_END
    end
    return C_GREY .. (STATUS_WORDS[bet.status] or bet.status:upper()) .. C_END
end

-------------------------------------------------------- confirm dialogs

-- StaticPopup_OnClick's callback signature is not identical across 3.3.5
-- builds (some pass the dialog first, some the data), so pick whichever
-- argument carries our marker instead of guessing - and never close over
-- the bet, so a stale popup can't act on a stale upvalue.
local function popupData(a, b)
    if type(a) == "table" and a.SoTBookie then return a end
    if type(b) == "table" and b.SoTBookie then return b end
    return nil
end

local function submitCreate(text, gold)
    if not W:DoCreate(text, gold) then return end -- Core prints the reason
    local pane = panes.active
    pane.textBox:SetText("")
    pane.goldBox:SetText("")
    pane.textBox:ClearFocus()
    pane.goldBox:ClearFocus()
    pane.updateCounter()
end

StaticPopupDialogs["SoTBookie_BIG_STAKE"] = {
    text = "Vysoky vklad: opravdu %dg?",
    button1 = "Vyhlasit",
    button2 = "Zpet",
    OnAccept = function(a, b)
        local data = popupData(a, b)
        if data then submitCreate(data.text, data.gold) end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-- Resolve confirm is a CUSTOM frame: the 3-button StaticPopup variant put
-- "Zpet" outside the dialog (3.3.5 never widens for three wide buttons -
-- UAT round 4), and the announce choice was always meant to be a checkbox
-- (DESIGN "UI"). ESC hides the frame via UISpecialFrames = a safe "Zpet".
local resolveDialog
local resolveAnnounce = false -- checkbox state, sticky for the session

local function buildResolveDialog()
    local d = CreateFrame("Frame", "SoTBookieResolveFrame", UIParent)
    d:SetWidth(380)
    d:SetPoint("CENTER", UIParent, "CENTER", 0, 110)
    d:SetFrameStrata("DIALOG")
    d:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 },
    })
    d:EnableMouse(true) -- nothing behind the money question should fire
    d:Hide()
    table.insert(UISpecialFrames, "SoTBookieResolveFrame")

    d.msg = d:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    d.msg:SetPoint("TOPLEFT", d, "TOPLEFT", 16, -16)
    d.msg:SetWidth(380 - 32)
    d.msg:SetJustifyH("LEFT")

    d.announce = makeCheck(d, "Oznamit vysledek do chatu", function(self)
        resolveAnnounce = self:GetChecked() and true or false
    end)
    d.announce:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 12, 38)

    d.cancel = makeButton(d, "Zpet", function() d:Hide() end, 80)
    d.cancel:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -14, 12)
    d.ok = makeButton(d, "Rozhodnout", function()
        d:Hide()
        W:DoResolve(d.betId, d.win, resolveAnnounce)
    end, 110)
    d.ok:SetPoint("RIGHT", d.cancel, "LEFT", -6, 0)
    return d
end

-- Cancel is destructive and its icon sits next to announce - confirm it.
StaticPopupDialogs["SoTBookie_CANCEL"] = {
    text = 'Zrusit sazku "%s"?',
    button1 = "Zrusit sazku",
    button2 = "Zpet",
    OnAccept = function(a, b)
        local data = popupData(a, b)
        if data then W:DoCancel(data.betId) end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

local function resolvePopupText(bet, win)
    local plan = W:PreviewPlan(bet, win)
    local lines = {}
    lines[1] = ('Rozhodnout "%s"'):format(esc(bet.text))
    lines[2] = ("Vyhrava strana %s - bank %dg."):format(win == "Y" and "ANO" or "NE", plan.pot)
    if #plan.payments == 0 then
        lines[3] = "Na druhe strane nikdo neni - sazku radsi zrus."
    else
        for i = 1, math.min(#plan.payments, MAX_POPUP_PAY) do
            local pay = plan.payments[i]
            lines[#lines + 1] = ("%s -> %s %dg"):format(esc(pay.from), esc(pay.to), pay.gold)
        end
        if #plan.payments > MAX_POPUP_PAY then
            lines[#lines + 1] = ("...a dalsich %d plateb"):format(#plan.payments - MAX_POPUP_PAY)
        end
    end
    return table.concat(lines, "\n")
end

-- Re-render (or dismiss) the open dialog on every store change: the window
-- behind it stays clickable and the network keeps flowing, so the plan the
-- author approves must always be the plan that will execute.
local function refreshResolveDialog()
    local d = resolveDialog
    if not d or not d:IsShown() then return end
    local bet = W:GetBet(d.betId)
    if not bet or (bet.status ~= "open" and bet.status ~= "locked") then
        d:Hide() -- resolved/cancelled elsewhere: the question is moot
        return
    end
    local plan = W:PreviewPlan(bet, d.win)
    d.msg:SetText(resolvePopupText(bet, d.win))
    -- DESIGN: resolve is UI-blocked while either camp is empty
    if #plan.payments == 0 then d.ok:Disable() else d.ok:Enable() end
    d:SetHeight(math.ceil(textHeight(d.msg)) + 88)
end

local function askResolve(betId, win)
    local bet = W:GetBet(betId)
    if not bet then return end
    resolveDialog = resolveDialog or buildResolveDialog()
    resolveDialog.betId, resolveDialog.win = betId, win
    setChecked(resolveDialog.announce, resolveAnnounce)
    resolveDialog:Show()
    refreshResolveDialog()
end

--------------------------------------------------------- active bet rows

-- All row callbacks are installed once, at row creation, and read the bet id
-- off the row - no per-refresh closure churn.
local function onYesClick(self) W:DoJoin(self:GetParent().betId, "Y") end
local function onNoClick(self) W:DoJoin(self:GetParent().betId, "N") end

-- Lock is a TOGGLE (UAT round 4): open -> lock, locked -> unlock. The
-- tooltip re-fires after the click so the hovering cursor reads the new
-- state instead of the stale one.
local function lockTipTitle(self)
    local bet = W:GetBet(self:GetParent().betId)
    return (bet and bet.status == "locked") and "Odemknout sazku" or "Zamknout sazku"
end

local function lockTipText(self)
    local bet = W:GetBet(self:GetParent().betId)
    if bet and bet.status == "locked" then
        return "Znovu otevre pridavani a zmeny stran."
    end
    return "Zmrazi strany. Pak rozhodnout, zrusit, nebo zase odemknout."
end

local function onLockClick(self)
    local bet = W:GetBet(self:GetParent().betId)
    if not bet then return end
    if bet.status == "open" then
        W:DoLock(bet.id)
    else
        W:DoUnlock(bet.id)
    end
    if GameTooltip:IsOwned(self) then
        self:GetScript("OnEnter")(self)
    end
end
local function onYesWonClick(self) askResolve(self:GetParent().betId, "Y") end
local function onNoWonClick(self) askResolve(self:GetParent().betId, "N") end
local function onAnnounceClick(self) W:AnnounceCreate(self:GetParent().betId) end

local function onCancelClick(self)
    local id = self:GetParent().betId
    local bet = id and W:GetBet(id)
    if not bet then return end
    StaticPopup_Show("SoTBookie_CANCEL", esc(bet.text), nil,
        { SoTBookie = true, betId = id })
end

local function newActiveRow(pane)
    local row = CreateFrame("Frame", nil, pane.content)
    row:SetWidth(CONTENT_W)

    -- author-only "admin" icon cluster, top-right (announcing someone
    -- else's statement is the author's call alone - drama guard, A2.16)
    row.iCancel = makeIcon(row, "Interface\\Buttons\\UI-GroupLoot-Pass-Up", false,
        "Zrusit sazku", "Sazka padne bez placeni. Zepta se na potvrzeni.",
        onCancelClick)
    row.iCancel:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -3)

    row.iAnnounce = makeIcon(row, "Interface\\Icons\\Ability_Warrior_BattleShout", true,
        "Oznamit do chatu", function()
            local ch = W:AnnounceChannel()
            local name = ch == "RAID" and "RAID" or ch == "PARTY" and "PARTY" or "GUILD"
            return ("Posle jednu radku do %s chatu, at se lidi pridaji."):format(name)
        end,
        onAnnounceClick)
    row.iAnnounce:SetPoint("RIGHT", row.iCancel, "LEFT", -6, 0)

    -- lock toggle: bigger than its neighbours on purpose - it is the one
    -- stateful control in the cluster (~24 px, DESIGN TODO 3)
    row.iLock = makeIcon(row, LOCK_UNLOCKED, LOCK_IS_ICON,
        lockTipTitle, lockTipText, onLockClick, 24)
    -- anchored in fillActiveRow: its neighbour (announce) comes and goes

    row.statement = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.statement:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -4)
    row.statement:SetWidth(TEXT_W - 84) -- keep clear of the icon cluster
    row.statement:SetJustifyH("LEFT")

    row.meta = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.meta:SetPoint("TOPLEFT", row.statement, "BOTTOMLEFT", 0, -LINE_GAP)
    row.meta:SetWidth(TEXT_W)
    row.meta:SetJustifyH("LEFT")

    row.yesLine = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.yesLine:SetPoint("TOPLEFT", row.meta, "BOTTOMLEFT", 0, -LINE_GAP)
    row.yesLine:SetWidth(TEXT_W)
    row.yesLine:SetJustifyH("LEFT")

    row.noLine = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.noLine:SetPoint("TOPLEFT", row.yesLine, "BOTTOMLEFT", 0, -LINE_GAP)
    row.noLine:SetWidth(TEXT_W)
    row.noLine:SetJustifyH("LEFT")

    row.yes    = makeButton(row, "ANO", onYesClick, 44)
    row.no     = makeButton(row, "NE", onNoClick, 44)
    row.yesWon = makeButton(row, "Vyhra ANO", onYesWonClick)
    row.noWon  = makeButton(row, "Vyhra NE", onNoWonClick)
    row.shown  = {}

    rowSeparator(row)
    return row
end

-- Buttons flow left to right over whatever is visible for this bet and WRAP
-- to a new line when the row runs out of width (auto-sized Czech labels do
-- not fit one line on author rows). Returns the number of lines used.
local function layoutButtons(row, anchor)
    local prev, lineStart
    local x, lines = 0, 0
    for i = 1, #row.shown do
        local b = row.shown[i]
        local w = b:GetWidth()
        b:ClearAllPoints()
        if not prev then
            b:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
            lineStart, x, lines = b, w, 1
        elseif x + 4 + w > CONTENT_W then
            b:SetPoint("TOPLEFT", lineStart, "BOTTOMLEFT", 0, -4)
            lineStart, x, lines = b, w, lines + 1
        else
            b:SetPoint("LEFT", prev, "RIGHT", 4, 0)
            x = x + 4 + w
        end
        b:Show()
        prev = b
    end
    return lines
end

local function fillActiveRow(row, bet, me)
    row.betId = bet.id
    row.statement:SetText(esc(bet.text))
    row.meta:SetText(("%dg · od %s · %s · %s"):format(
        bet.gold, esc(bet.author), W.AgeText(bet.firstSeen), statusWord(bet)))
    row.yesLine:SetText(campLine(bet, "Y", me))
    row.noLine:SetText(campLine(bet, "N", me))

    local isOpen = (bet.status == "open")
    local isAuthor = (bet.author == me)
    local mySide = bet.p[me]
    if isOpen then row.yes:Enable() else row.yes:Disable() end
    if isOpen then row.no:Enable() else row.no:Disable() end
    if mySide == "Y" then row.yes:LockHighlight() else row.yes:UnlockHighlight() end
    if mySide == "N" then row.no:LockHighlight() else row.no:UnlockHighlight() end

    -- admin icons: lock toggles for any live bet, announce only while open
    -- (inviting people onto a frozen bet is nonsense), cancel always
    if isAuthor then
        row.iLock:SetNormalTexture(isOpen and LOCK_UNLOCKED or LOCK_LOCKED)
        row.iLock:ClearAllPoints()
        -- close the gap the hidden announce icon would leave on locked rows
        row.iLock:SetPoint("RIGHT", isOpen and row.iAnnounce or row.iCancel,
            "LEFT", -6, 0)
        row.iLock:Show()
        if isOpen then row.iAnnounce:Show() else row.iAnnounce:Hide() end
        row.iCancel:Show()
    else
        row.iLock:Hide()
        row.iAnnounce:Hide()
        row.iCancel:Hide()
    end

    -- bottom row: joining for everyone; resolving belongs to the LOCKED
    -- stage only (user decision 2026-08-18 - an open bet is not resolvable
    -- without locking first, and the row stays uncluttered)
    local shown = row.shown
    wipe(shown)
    shown[1] = row.yes
    shown[2] = row.no
    if isAuthor and not isOpen then
        shown[#shown + 1] = row.yesWon
        shown[#shown + 1] = row.noWon
    else
        row.yesWon:Hide()
        row.noWon:Hide()
    end
    local btnLines = layoutButtons(row, row.noLine)

    local h = 4 + textHeight(row.statement)
        + LINE_GAP + textHeight(row.meta)
        + LINE_GAP + textHeight(row.yesLine)
        + LINE_GAP + textHeight(row.noLine)
        + btnLines * (BTN_H + 4) + 6
    row:SetHeight(h)
    return h
end

local function renderActive(pane)
    local bets = W:GetActiveBets()
    local me = W:Me()
    local prev, total = nil, 0
    for i = 1, #bets do
        local row = acquireRow(pane, i, newActiveRow)
        local h = fillActiveRow(row, bets[i], me)
        anchorRow(pane, row, prev)
        prev, total = row, total + h + ROW_GAP
    end
    finishList(pane, #bets, total)
end

-------------------------------------------------------------- history rows

-- History is a read-only paper trail: payment handshakes happen on the
-- Dluhy tab; here each payment just shows its current state.

local PAY_WORDS = {
    [0] = C_GREY .. "neuhrazeno" .. C_END,
    [1] = C_LOCKED .. "ohlaseno, ceka na potvrzeni" .. C_END,
    [2] = C_OPEN .. "zaplaceno" .. C_END,
}

local function newHistoryRow(pane)
    local row = CreateFrame("Frame", nil, pane.content)
    row:SetWidth(CONTENT_W)

    row.statement = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.statement:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -4)
    row.statement:SetWidth(TEXT_W)
    row.statement:SetJustifyH("LEFT")

    row.result = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.result:SetPoint("TOPLEFT", row.statement, "BOTTOMLEFT", 0, -LINE_GAP)
    row.result:SetWidth(TEXT_W)
    row.result:SetJustifyH("LEFT")

    row.note = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.note:SetPoint("TOPLEFT", row.result, "BOTTOMLEFT", 0, -LINE_GAP)
    row.note:SetWidth(TEXT_W)
    row.note:SetJustifyH("LEFT")
    color(row.note, COL_GREY)

    row.pays = {}
    rowSeparator(row)
    return row
end

local function payWidget(row, index)
    local w = row.pays[index]
    if not w then
        w = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        w:SetWidth(CONTENT_W - 20)
        w:SetHeight(PAY_H)
        w:SetJustifyH("LEFT")
        row.pays[index] = w
    end
    w:Show()
    return w
end

local function fillHistoryRow(row, bet, me)
    row.betId = bet.id
    row.statement:SetText(esc(bet.text))

    local plan, note
    if bet.status == "cancelled" then
        row.result:SetText(C_GREY .. "ZRUSENA" .. C_END)
    elseif bet.status == "resolved" then
        plan = W:ComputePlan(bet)
        local side = (bet.win == "Y") and "ANO" or "NE"
        local who = esc(bet.resolvedBy or bet.author)
        if plan then
            row.result:SetText(("Vyhralo %s · bank %dg · rozhodl(a) %s %s"):format(
                side, plan.pot, who, W.AgeText(bet.resolvedAt)))
        else
            row.result:SetText(("Vyhralo %s · rozhodl(a) %s %s"):format(
                side, who, W.AgeText(bet.resolvedAt)))
            note = "platebni plan se synchronizuje..."
        end
    else
        row.result:SetText(C_GREY .. "VYPRSELA" .. C_END)
    end

    if note then
        row.note:SetText(note)
        row.note:Show()
    else
        row.note:Hide()
    end

    local payments = plan and plan.payments or nil
    local count = payments and #payments or 0
    local anchor = note and row.note or row.result
    for i = 1, count do
        local pay = payments[i]
        local w = payWidget(row, i)
        w:SetText(("%s -> %s %dg · %s"):format(
            esc(pay.from), esc(pay.to), pay.gold, PAY_WORDS[W:PayState(bet, i)]))
        color(w, (pay.from == me or pay.to == me) and COL_GOLD or COL_GREY)
        w:ClearAllPoints()
        if i == 1 then
            w:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -3)
        else
            w:SetPoint("TOPLEFT", row.pays[i - 1], "BOTTOMLEFT", 0, -1)
        end
    end
    for i = count + 1, #row.pays do row.pays[i]:Hide() end

    local h = 4 + textHeight(row.statement) + LINE_GAP + textHeight(row.result)
    if note then h = h + LINE_GAP + textHeight(row.note) end
    if count > 0 then h = h + 3 + count * (PAY_H + 1) end
    h = h + 6
    row:SetHeight(h)
    return h
end

local function renderHistory(pane)
    local bets = W:GetHistoryBets()
    local me = W:Me()
    local prev, total = nil, 0
    for i = 1, #bets do
        local row = acquireRow(pane, i, newHistoryRow)
        local h = fillHistoryRow(row, bets[i], me)
        anchorRow(pane, row, prev)
        prev, total = row, total + h + ROW_GAP
    end
    finishList(pane, #bets, total)
end

----------------------------------------------------------------- debt rows

-- Dluhy tab: one row per counterparty+direction, aggregated over every
-- resolved bet. The button drives the handshake in bulk: I claim all my
-- payments to them ("Zaplaceno"), or confirm all theirs to me ("Prislo").

local function onDebtClick(self)
    local entry = self:GetParent().entry
    if not entry then return end
    W:DoPayAll(entry, entry.dir == "owe" and 1 or 2)
end

local function newDebtRow(pane)
    local row = CreateFrame("Frame", nil, pane.content)
    row:SetWidth(CONTENT_W)
    row:SetHeight(DEBT_ROW_H)

    row.action = makeButton(row, "Zaplaceno", onDebtClick, 96)
    row.action:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -3)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -7)
    row.text:SetWidth(TEXT_W - 110)
    row.text:SetJustifyH("LEFT")

    rowSeparator(row)
    return row
end

local function fillDebtRow(row, entry)
    row.entry = entry
    if entry.dir == "owe" then
        row.text:SetText(("Dluzis hraci %s: %s%dg%s"):format(
            esc(entry.name), C_MINE, entry.total, C_END))
        row.action:SetText("Zaplaceno")
        if entry.claimed >= entry.total then
            row.action:Disable() -- everything claimed, receiver's turn
            row.text:SetText(row.text:GetText()
                .. C_GREY .. "  (ohlaseno, ceka na potvrzeni)" .. C_END)
        else
            row.action:Enable()
        end
    else
        local claimedNote = entry.claimed > 0
            and (C_LOCKED .. "  (ohlasil zaplaceni)" .. C_END) or ""
        row.text:SetText(("%s ti dluzi: %s%dg%s%s"):format(
            esc(entry.name), C_OPEN, entry.total, C_END, claimedNote))
        row.action:SetText("Prislo")
        row.action:Enable()
    end
    return DEBT_ROW_H
end

local function renderDebts(pane)
    local list = W:GetDebts()
    local prev, total = nil, 0
    for i = 1, #list do
        local row = acquireRow(pane, i, newDebtRow)
        local h = fillDebtRow(row, list[i])
        anchorRow(pane, row, prev)
        prev, total = row, total + h + ROW_GAP
    end
    finishList(pane, #list, total)
end

---------------------------------------------------------------- stats rows

local function newStatsRow(pane)
    local row = CreateFrame("Frame", nil, pane.content)
    row:SetWidth(CONTENT_W)
    row:SetHeight(STAT_ROW_H)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 4, 0)
    row.name:SetWidth(150)
    row.name:SetJustifyH("LEFT")

    row.net = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.net:SetPoint("TOPLEFT", row.name, "TOPRIGHT", 4, 0)
    row.net:SetWidth(70)
    row.net:SetJustifyH("RIGHT")

    row.record = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.record:SetPoint("TOPLEFT", row.net, "TOPRIGHT", 10, 0)
    row.record:SetWidth(CONTENT_W - 240)
    row.record:SetJustifyH("LEFT")
    color(row.record, COL_GREY)
    return row
end

local function statsList(pane)
    local list = pane.statBuffer
    wipe(list)
    for name, s in pairs(W:ComputeStats()) do
        list[#list + 1] = { name = name, net = s.net, wins = s.wins,
            losses = s.losses, best = s.best }
    end
    table.sort(list, function(a, b)
        if a.net ~= b.net then return a.net > b.net end
        return W.ByteLess(a.name, b.name)
    end)
    return list
end

local function renderStats(pane)
    local list = statsList(pane)
    local me = W:Me()
    local prev, total = nil, 0
    for i = 1, #list do
        local s = list[i]
        local row = acquireRow(pane, i, newStatsRow)
        row.name:SetText(s.name == me and (C_MINE .. esc(s.name) .. C_END) or esc(s.name))
        row.net:SetText(("%s%dg"):format(s.net > 0 and "+" or "", s.net))
        if s.net > 0 then
            color(row.net, COL_GREEN)
        elseif s.net < 0 then
            color(row.net, COL_RED)
        else
            color(row.net, COL_GREY)
        end
        row.record:SetText(("%dV/%dP · nejvic %dg"):format(s.wins, s.losses, s.best))
        anchorRow(pane, row, prev)
        prev, total = row, total + STAT_ROW_H + ROW_GAP
    end
    finishList(pane, #list, total)
end

------------------------------------------------------------------ settings

local function renderSettings(pane)
    local p = W.db.profile
    setChecked(pane.optAutoLock, p.autoLockOnCombat)
    setChecked(pane.optSound, p.newBetSound)
    setChecked(pane.optMinimap, p.minimap.hide)
end

------------------------------------------------------------------ scaffolding

local RENDER = {
    active   = renderActive,
    history  = renderHistory,
    debts    = renderDebts,
    stats    = renderStats,
    settings = renderSettings,
}

function refresh()
    -- the resolve dialog lives outside the window and must track the store
    -- even when the window itself is hidden
    refreshResolveDialog()
    if not frame or not frame:IsShown() then return end
    local pane = panes[currentTab]
    if pane then RENDER[currentTab](pane) end
end

function selectTab(key)
    currentTab = key
    for i = 1, #TABS do
        local tab = TABS[i]
        if tab.key == key then
            tabButtons[tab.key]:LockHighlight()
            panes[tab.key]:Show()
        else
            tabButtons[tab.key]:UnlockHighlight()
            panes[tab.key]:Hide()
        end
    end
    refresh()
end

local function onTabClick(self) selectTab(self.tabKey) end

local function newPane(parent)
    local pane = CreateFrame("Frame", nil, parent) -- unnamed: nothing looks it up
    pane:SetPoint("TOPLEFT", parent, "TOPLEFT", PANE_INSET, -60)
    pane:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -PANE_INSET, 40)
    pane:Hide()
    pane.rows = {}
    return pane
end

-- The scroll frame must be named: UIPanelScrollFrameTemplate's OnLoad and
-- OnScrollRangeChanged look their scroll bar up as "<name>ScrollBar".
local function addScroll(pane, name, topOffset, bottomOffset)
    local scroll = CreateFrame("ScrollFrame", name, pane, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -topOffset)
    scroll:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -SCROLLBAR_W, bottomOffset)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(CONTENT_W)
    content:SetHeight(1)
    scroll:SetScrollChild(content)

    -- Wheel scrolling drives the slider (not SetVerticalScroll) so the bar
    -- stays in sync; the template's own handler needs the same lookup.
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local bar = _G[self:GetName() .. "ScrollBar"]
        if bar then bar:SetValue(bar:GetValue() - delta * 25) end
    end)

    pane.scroll = scroll
    pane.content = content

    pane.empty = pane:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    pane.empty:SetPoint("TOP", scroll, "TOP", 0, -24)
    pane.empty:Hide()
    return scroll
end

local function buildActivePane(parent)
    local pane = newPane(parent)
    panes.active = pane

    -- named: InputBoxTemplate's middle border piece anchors by $parent name
    local box = CreateFrame("EditBox", "SoTBookieStatementBox", pane, "InputBoxTemplate")
    box:SetPoint("TOPLEFT", pane, "TOPLEFT", 8, -6)
    box:SetWidth(250)
    box:SetHeight(20)
    box:SetAutoFocus(false)
    box:SetMaxLetters(150)
    pane.textBox = box

    local counter = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    counter:SetPoint("LEFT", box, "RIGHT", 8, 0)
    counter:SetWidth(28)
    counter:SetJustifyH("RIGHT")
    pane.counter = counter

    local gold = CreateFrame("EditBox", "SoTBookieGoldBox", pane, "InputBoxTemplate")
    gold:SetPoint("LEFT", counter, "RIGHT", 10, 0)
    gold:SetWidth(56)
    gold:SetHeight(20)
    gold:SetAutoFocus(false)
    gold:SetNumeric(true)
    gold:SetMaxLetters(7)
    pane.goldBox = gold

    local gLabel = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    gLabel:SetPoint("LEFT", gold, "RIGHT", 4, 0)
    gLabel:SetText("g")

    function pane.updateCounter()
        -- measure what will actually be sent: diacritics transliterate to
        -- 1-byte ASCII, so raw box text would overstate the cost
        local left = W.TEXT_COST_MAX - W.TextCost(W.SanitizeText(box:GetText()))
        counter:SetText(tostring(left))
        if left < 0 then
            color(counter, COL_RED)
        else
            color(counter, COL_GREY)
        end
    end

    local function tryCreate()
        local text = box:GetText() or ""
        local goldText = gold:GetText() or ""
        local amount = tonumber(goldText)
        if amount and amount > BIG_STAKE then
            StaticPopup_Show("SoTBookie_BIG_STAKE", amount, nil,
                { SoTBookie = true, text = text, gold = goldText })
        else
            submitCreate(text, goldText)
        end
    end

    box:SetScript("OnTextChanged", pane.updateCounter)
    box:SetScript("OnEnterPressed", tryCreate)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    gold:SetScript("OnEnterPressed", tryCreate)
    gold:SetScript("OnEscapePressed", gold.ClearFocus)

    local call = makeButton(pane, "Vyhlasit", tryCreate)
    call:SetPoint("LEFT", gLabel, "RIGHT", 8, 0)

    addScroll(pane, "SoTBookieFrameActiveScroll", CREATE_BAR_H, 0)
    pane.empty:SetText("Zadne otevrene sazky. Vypis prvni!")
    pane.updateCounter()
    return pane
end

local function buildHistoryPane(parent)
    local pane = newPane(parent)
    panes.history = pane
    addScroll(pane, "SoTBookieFrameHistoryScroll", 0, 0)
    pane.empty:SetText("Historie je zatim prazdna.")
    return pane
end

local function buildDebtsPane(parent)
    local pane = newPane(parent)
    panes.debts = pane
    addScroll(pane, "SoTBookieFrameDebtsScroll", 0, 0)
    pane.empty:SetText("Zadne dluhy. Cista prace!")
    return pane
end

local function buildStatsPane(parent)
    local pane = newPane(parent)
    panes.stats = pane
    pane.statBuffer = {}
    addScroll(pane, "SoTBookieFrameStatsScroll", 0, 0)
    pane.empty:SetText("Zatim zadne rozhodnute sazky.")
    return pane
end

local function buildSettingsPane(parent)
    local pane = newPane(parent)
    panes.settings = pane

    pane.optAutoLock = makeCheck(pane,
        "Kdyz zacne boj, zamknout moje otevrene sazky",
        function(self)
            W.db.profile.autoLockOnCombat = self:GetChecked() and true or false
        end)
    pane.optAutoLock:SetPoint("TOPLEFT", pane, "TOPLEFT", 4, -8)

    pane.optSound = makeCheck(pane, "Zvuk pri nove sazce (mimo boj)",
        function(self)
            W.db.profile.newBetSound = self:GetChecked() and true or false
            if self:GetChecked() then
                PlaySound("AuctionWindowOpen") -- instant preview of the cue
            end
        end)
    pane.optSound:SetPoint("TOPLEFT", pane.optAutoLock, "BOTTOMLEFT", 0, 2)

    pane.optMinimap = makeCheck(pane, "Skryt ikonu u minimapy", function(self)
        W.db.profile.minimap.hide = self:GetChecked() and true or false
        W:UpdateMinimapVisibility()
    end)
    pane.optMinimap:SetPoint("TOPLEFT", pane.optSound, "BOTTOMLEFT", 0, 2)

    local sync = makeButton(pane, "Nacist sazky od guildy",
        function() W:RequestSync() end)
    sync:SetPoint("TOPLEFT", pane.optMinimap, "BOTTOMLEFT", 4, -14)

    local syncNote = pane:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    syncNote:SetPoint("TOPLEFT", sync, "BOTTOMLEFT", 0, -4)
    syncNote:SetWidth(PANE_W - 20)
    syncNote:SetJustifyH("LEFT")
    syncNote:SetText("Vyzada si aktualni sazky od spoluhracu online. Bezne neni"
        .. " potreba - sync probehne sam po prihlaseni. Pouzij, kdyz ti neco chybi.")
    return pane
end

local function createWindow()
    frame = CreateFrame("Frame", "SoTBookieFrame", UIParent)
    frame:SetWidth(WIN_W)
    frame:SetHeight(WIN_H)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0) -- default spot only
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 },
    })
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:Hide()
    table.insert(UISpecialFrames, "SoTBookieFrame") -- ESC closes the window

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", frame, "TOP", 0, -14)
    title:SetText("SoTBookie v" .. W.VERSION)

    -- drag handle: the title strip only, STOPPING short of the close button
    -- (a full-width mouse-enabled strip at the same frame level ate the
    -- close button's clicks - it only ever flickered its highlight)
    local grip = CreateFrame("Frame", nil, frame)
    grip:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -6)
    grip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -36, -6)
    grip:SetHeight(28)
    grip:EnableMouse(true)
    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnDragStart", function() frame:StartMoving() end)
    grip:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    close:SetFrameLevel(grip:GetFrameLevel() + 2) -- always above the grip

    local prev
    for i = 1, #TABS do
        local tab = TABS[i]
        local b = makeButton(frame, tab.label, onTabClick)
        b.tabKey = tab.key
        if prev then
            b:SetPoint("LEFT", prev, "RIGHT", 4, 0)
        else
            b:SetPoint("TOPLEFT", frame, "TOPLEFT", PANE_INSET + 4, -34)
        end
        tabButtons[tab.key] = b
        prev = b
    end

    buildActivePane(frame)
    buildHistoryPane(frame)
    buildDebtsPane(frame)
    buildStatsPane(frame)
    buildSettingsPane(frame)

    frame:SetScript("OnShow", refresh)
    -- one registration for the whole window; refresh() is a no-op while hidden
    W:RegisterMessage("SoTBookie_REFRESH", refresh)
end

------------------------------------------------------------------- public

-- Called from the slash command and the minimap icon. Never called on its
-- own: the window must not pop up because of a network event.
function W:ToggleWindow()
    if not frame then
        createWindow()
        selectTab(currentTab)
    end
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end
