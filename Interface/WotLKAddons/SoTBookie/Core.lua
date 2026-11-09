--========================================================================--
-- SoTBookie / Core.lua
-- Addon setup, saved data, bet store, pot math, stats, announce lines.
-- Wire protocol lives in Comm.lua; window in UI.lua; icon in Minimap.lua.
-- Implementation contract: Docs/DESIGN.md — read it before touching the
-- store or the math; determinism rules (byte sort, integer gold) are
-- load-bearing for cross-client agreement on payments.
--========================================================================--

local W = LibStub("AceAddon-3.0"):NewAddon("SoTBookie",
    "AceEvent-3.0", "AceTimer-3.0", "AceComm-3.0",
    "AceSerializer-3.0", "AceConsole-3.0")
_G.SoTBookie = W

-- Hardcoded, NOT GetAddOnMetadata("SoTBookie", "Version"): the 3.3.5 client
-- returns nil for the Version field (observed in-game 2026-08-18 — the UI
-- fell back to a stale default). Keep in sync with ## Version in SoTBookie.toc.
W.VERSION = "1.0.1"

W.STATUS_RANK = { open = 0, locked = 1, cancelled = 2, resolved = 3 }
W.TEXT_COST_MAX = 100
W.GOLD_MIN, W.GOLD_MAX = 1, 1000000
W.EXPIRY_SECONDS = 72 * 3600
W.HISTORY_KEEP = 50
W.SYNC_RESOLVED_WINDOW = 14 * 24 * 3600

local defaults = {
    global = { bets = {}, aggregate = {} },
    char = { nonce = false, counter = 0 },
    profile = {
        minimap = { hide = false },
        autoLockOnCombat = false,
        newBetSound = false,
    },
}

--------------------------------------------------------------------- helpers

-- Locale-independent sort (strcoll differs between clients; bare `<` on
-- strings would desync the payment plan).
function W.ByteLess(a, b)
    local la, lb = #a, #b
    local n = la < lb and la or lb
    for i = 1, n do
        local ca, cb = string.byte(a, i), string.byte(b, i)
        if ca ~= cb then return ca < cb end
    end
    return la < lb
end

-- Serialization cost of a statement: AceSerializer escapes space/~/^ to two
-- bytes each; the wire budget is what matters, not the character count.
function W.TextCost(text)
    local extra = 0
    for _ in string.gmatch(text, "[ ~%^]") do extra = extra + 1 end
    return #text + extra
end

-- Czech + Slovak diacritics -> ASCII, keyed by the UTF-8 byte sequence.
-- The stock 3.3.5 font has no Latin-Extended glyphs (holes in our window
-- AND in chat), and the guild style is diacritics-free even for Latin-1
-- (user decision 2026-08-18) — so typed text is transliterated at the
-- sanitize gate and the wire/render layers only ever carry ASCII.
local TRANSLIT = {
    ["á"]="a", ["Á"]="A", ["ä"]="a", ["Ä"]="A", ["č"]="c", ["Č"]="C",
    ["ď"]="d", ["Ď"]="D", ["é"]="e", ["É"]="E", ["ě"]="e", ["Ě"]="E",
    ["í"]="i", ["Í"]="I", ["ĺ"]="l", ["Ĺ"]="L", ["ľ"]="l", ["Ľ"]="L",
    ["ň"]="n", ["Ň"]="N", ["ó"]="o", ["Ó"]="O", ["ô"]="o", ["Ô"]="O",
    ["ŕ"]="r", ["Ŕ"]="R", ["ř"]="r", ["Ř"]="R", ["š"]="s", ["Š"]="S",
    ["ť"]="t", ["Ť"]="T", ["ú"]="u", ["Ú"]="U", ["ů"]="u", ["Ů"]="U",
    ["ý"]="y", ["Ý"]="Y", ["ž"]="z", ["Ž"]="Z",
}

function W.SanitizeText(text)
    text = tostring(text or "")
    text = text:gsub("|", "")
    text = text:gsub("%c", "")
    text = text:gsub("[\194-\244][\128-\191]*", TRANSLIT)
    -- anything still non-ASCII has no glyph and no place on the wire
    text = text:gsub("[\128-\255]", "")
    return strtrim(text)
end

-- Render-side escape for any text that arrived over the wire: a modified
-- client can send raw markup no matter what our input box allows.
function W.EscapeText(text)
    return (tostring(text or ""):gsub("|", "||"))
end

-- All user-facing Czech is WITHOUT diacritics beyond Latin-1 (a i e u y o):
-- the stock 3.3.5 font has no c/r/s/z/e-hacek glyphs and renders holes,
-- in our window AND in chat lines guildmates see (user decision 2026-08-18).
function W.AgeText(t)
    local d = time() - (t or time())
    if d < 60 then return "ted" end
    if d < 3600 then return ("pred %d min"):format(math.floor(d / 60)) end
    if d < 86400 then return ("pred %d h"):format(math.floor(d / 3600)) end
    local days = math.floor(d / 86400)
    return days == 1 and "pred 1 dnem" or ("pred %d dny"):format(days)
end

function W:Me() return UnitName("player") end

function W:VersionNumber()
    local a, b, c = strsplit(".", W.VERSION)
    return (tonumber(a) or 0) * 10000 + (tonumber(b) or 0) * 100 + (tonumber(c) or 0)
end

-- Coalesced: a 15-bet sync burst fires dozens of Apply* calls; the UI only
-- needs one repaint.
function W:Refresh()
    if self.refreshPending then return end
    self.refreshPending = true
    self:ScheduleTimer(function()
        self.refreshPending = nil
        self:SendMessage("SoTBookie_REFRESH")
    end, 0.1)
end

------------------------------------------------------------------ lifecycle

function W:OnInitialize()
    -- NO math.randomseed here: the WoW client removes it from the math table
    -- (the client seeds its own RNG at startup) — calling it is an instant
    -- "attempt to call field 'randomseed' (a nil value)" that kills init.
    self.db = LibStub("AceDB-3.0"):New("SoTBookieDB", defaults)
    local c = self.db.char
    if not c.nonce then
        -- Random per-character id nonce: a SavedVariables wipe or reinstall
        -- resets the counter, and without the nonce the reused ids would
        -- silently hijack old bets still stored on guildmates' clients.
        local chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        local r1 = math.random(1, 36)
        local r2 = math.random(1, 36)
        local r3 = math.random(1, 36)
        c.nonce = chars:sub(r1, r1) .. chars:sub(r2, r2) .. chars:sub(r3, r3)
    end
    -- v0.9.x -> v1.0 migration: pre-toggle locked bets carry no lock epoch,
    -- so their S mirrors could never convey "locked" (le merge is strict).
    -- Their lock event was stamped with pe, adopt it (1 when chunks never
    -- landed and pe is still 0).
    for _, bet in pairs(self.db.global.bets) do
        if bet.status == "locked" and not bet.le then
            bet.le = (bet.pe and bet.pe > 0) and bet.pe or 1
        end
    end
    self:RegisterChatCommand("bet", "OnSlash")
    self:RegisterChatCommand("SoTBookie", "OnSlash")
end

function W:OnEnable()
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatStart")
    self:CommOnEnable()
    if self.MinimapOnEnable then self:MinimapOnEnable() end
    self:ScheduleTimer(function() self:PruneHistory() end, 60)
end

function W:OnSlash(input)
    input = strtrim(input or ""):lower()
    if input == "sync" then
        self:RequestSync()
    else
        self:ToggleWindow()
    end
end

function W:OnCombatStart()
    if not self.db.profile.autoLockOnCombat then return end
    local me = self:Me()
    for id, bet in pairs(self.db.global.bets) do
        if bet.author == me and bet.status == "open" and not self:IsExpired(bet) then
            self:DoLock(id)
        end
    end
end

------------------------------------------------------------------ bet store

function W:GetBet(id) return self.db.global.bets[id] end

function W:IsExpired(bet)
    return (bet.status == "open" or bet.status == "locked")
        and (time() - (bet.firstSeen or 0)) > W.EXPIRY_SECONDS
end

function W:CountCamps(bet)
    local y, n = 0, 0
    for _, side in pairs(bet.p) do
        if side == "Y" then y = y + 1 else n = n + 1 end
    end
    return y, n
end

function W:ParticipantCount(bet)
    local n = 0
    for _ in pairs(bet.p) do n = n + 1 end
    return n
end

-- Apply* mutators are shared by local actions and network handlers; they
-- enforce the state machine (total order open<locked<cancelled<resolved)
-- and never trust the caller.

function W:ApplyNew(id, author, text, gold, created)
    local bets = self.db.global.bets
    if bets[id] then return nil end -- id reuse/squat is rejected, never merged
    local bet = {
        id = id, author = author, text = text, gold = gold,
        status = "open", created = created, firstSeen = time(),
        p = { [author] = "Y" }, pe = 0,
    }
    bets[id] = bet
    self:Refresh()
    return bet
end

function W:ApplyJoin(id, name, side)
    local bet = self:GetBet(id)
    if not bet or bet.status ~= "open" or self:IsExpired(bet) then return end
    bet.p[name] = side
    self:Refresh()
    return true
end

function W:ApplyLeave(id, name)
    local bet = self:GetBet(id)
    if not bet or bet.status ~= "open" then return end
    bet.p[name] = nil
    self:Refresh()
    return true
end

-- Terminal layer only (cancelled/resolved): monotonic rank adopt. The
-- open/locked axis toggles and goes through ApplyToggle instead — rank
-- would let a replayed lock beat an unlock.
function W:ApplyStatus(id, status)
    local bet = self:GetBet(id)
    if not bet then return end
    if status ~= "cancelled" and status ~= "resolved" then return end
    if W.STATUS_RANK[status] > W.STATUS_RANK[bet.status] then
        bet.status = status
        self:Refresh()
        return true
    end
end

-- Open/locked toggle: the author's highest epoch wins (DESIGN U1/U2).
-- Epochs are unique per transition (shared per-bet counter with pe), so
-- an equal epoch is the same event redelivered — apply idempotently.
function W:ApplyToggle(id, epoch, status)
    local bet = self:GetBet(id)
    if not bet then return end
    if bet.status ~= "open" and bet.status ~= "locked" then return end
    if epoch < (bet.le or 0) then return end
    bet.le = epoch
    if bet.status ~= status then
        bet.status = status
        self:Refresh()
    end
    return true
end

function W:ApplyResolve(id, win, epoch, resolvedBy)
    local bet = self:GetBet(id)
    if not bet or W.STATUS_RANK[bet.status] >= W.STATUS_RANK.resolved then return end
    bet.status = "resolved"
    bet.win = win
    bet.re = epoch
    bet.resolvedBy = resolvedBy
    bet.resolvedAt = time()
    -- Money math is only valid once we hold the author's snapshot for this
    -- exact epoch; until then the bet renders as "payment plan syncing".
    bet.incomplete = (bet.pe ~= epoch) or nil
    self:Refresh()
    return true
end

function W:ReplaceParticipants(id, epoch, p)
    local bet = self:GetBet(id)
    if not bet or epoch < (bet.pe or 0) then return end
    if epoch == (bet.pe or 0) or epoch < (bet.le or 0) then
        -- Non-authoritative snapshot: same epoch = no fresher than mine;
        -- epoch < le = recorded before the last unlock, so it may miss
        -- joins made since. Either way union without deleting (DESIGN U4).
        -- My own entry: once I have locally acted on this bet (bet.my), a
        -- mirror must neither flip nor revive it — but on a bet I have no
        -- record of acting on (SavedVariables wipe), the mirror is the only
        -- way to learn my own membership, so adopt it.
        local me = self:Me()
        for name, side in pairs(p) do
            if name ~= me or not bet.my then
                bet.p[name] = side
            end
        end
    else
        bet.p, bet.pe = p, epoch
    end
    if bet.re and bet.pe == bet.re then bet.incomplete = nil end
    self:Refresh()
    return true
end

--------------------------------------------------------------- user actions

function W:NewBetId()
    local c = self.db.char
    c.counter = c.counter + 1
    return self:Me() .. "-" .. c.nonce .. "-" .. c.counter
end

-- Returns (text, gold) on success, (nil, errorMessage) otherwise.
function W:ValidateBetInput(rawText, rawGold)
    local text = W.SanitizeText(rawText)
    if text == "" then return nil, "Text sazky je prazdny." end
    if W.TextCost(text) > W.TEXT_COST_MAX then
        return nil, "Text sazky je moc dlouhy."
    end
    local gold = tonumber(rawGold)
    if not gold or gold ~= math.floor(gold)
            or gold < W.GOLD_MIN or gold > W.GOLD_MAX then
        return nil, "Vklad musi byt cele cislo ve zlatych (1-1000000)."
    end
    return text, gold
end

function W:DoCreate(rawText, rawGold)
    local text, goldOrErr = self:ValidateBetInput(rawText, rawGold)
    if not text then
        self:Print(goldOrErr)
        return
    end
    local bet = self:ApplyNew(self:NewBetId(), self:Me(), text, goldOrErr, time())
    if not bet then
        self:Print("Sazku se nepovedlo vytvorit (kolize id).")
        return
    end
    bet.my = true
    self:SendNew(bet)
    return bet
end

-- bet.my = this character has locally created/joined/left this bet; while
-- set, sync mirrors may never alter my own p entry (protects a local leave
-- from being revived). Absent after a SavedVariables wipe — exactly when a
-- mirror SHOULD hand my membership back.

function W:DoJoin(id, side)
    local bet = self:GetBet(id)
    if not bet or bet.status ~= "open" or self:IsExpired(bet) then return end
    local me = self:Me()
    if bet.p[me] == side then return self:DoLeave(id) end
    if self:ApplyJoin(id, me, side) then
        bet.my = true
        self:SendJoin(id, side)
    end
end

function W:DoLeave(id)
    if self:ApplyLeave(id, self:Me()) then
        local bet = self:GetBet(id)
        if bet then bet.my = true end
        self:SendLeave(id)
    end
end

local function copyParticipants(bet)
    local snap = {}
    for name, side in pairs(bet.p) do snap[name] = side end
    return snap
end

-- One shared per-bet counter for snapshot AND toggle epochs: every K/U/R
-- event gets a unique number, so peers can order them without a clock.
local function nextEpoch(bet)
    local pe, le = bet.pe or 0, bet.le or 0
    return (pe > le and pe or le) + 1
end

function W:DoLock(id)
    local bet = self:GetBet(id)
    if not bet or bet.author ~= self:Me() or bet.status ~= "open" then return end
    local e = nextEpoch(bet)
    local snap = copyParticipants(bet)
    self:ApplyToggle(id, e, "locked")
    self:ReplaceParticipants(id, e, snap)
    self:BroadcastSnapshot(bet)
    return true
end

-- Unlock reopens joining; the list the lock froze simply goes live again,
-- so U carries no participant payload (DESIGN U1).
function W:DoUnlock(id)
    local bet = self:GetBet(id)
    if not bet or bet.author ~= self:Me() or bet.status ~= "locked" then return end
    local e = nextEpoch(bet)
    self:ApplyToggle(id, e, "open")
    self:SendUnlock(id, e)
    return true
end

function W:DoCancel(id)
    local bet = self:GetBet(id)
    if not bet or bet.author ~= self:Me() then return end
    if bet.status ~= "open" and bet.status ~= "locked" then return end
    if self:ApplyStatus(id, "cancelled") then
        self:SendCancel(id)
        self:PruneHistory()
    end
end

function W:DoResolve(id, win, announce)
    local bet = self:GetBet(id)
    if not bet or bet.author ~= self:Me() then return end
    if bet.status ~= "open" and bet.status ~= "locked" then return end
    local y, n = self:CountCamps(bet)
    if y == 0 or n == 0 then
        self:Print("Obe strany potrebuji aspon jednoho hrace - sazku radsi zrus.")
        return
    end
    -- A fresh authoritative snapshot rides with every resolve so peers with
    -- a lost join/leave still compute the same payment plan.
    local e = nextEpoch(bet)
    local snap = copyParticipants(bet)
    self:ApplyToggle(id, e, "locked")
    self:ReplaceParticipants(id, e, snap)
    self:BroadcastSnapshot(bet)
    self:ApplyResolve(id, win, e, self:Me())
    self:SendResolve(id, win, e)
    if announce then self:AnnounceResolve(id) end
    self:PruneHistory()
    return true
end

------------------------------------------------------------------- pot math

-- Deterministic across clients: byte-sorted names, integer gold, remainder
-- to the first winners in sort order.
local function planFromParticipants(participants, gold, win)
    local winners, losers = {}, {}
    for name, side in pairs(participants) do
        if side == win then
            winners[#winners + 1] = name
        else
            losers[#losers + 1] = name
        end
    end
    table.sort(winners, W.ByteLess)
    table.sort(losers, W.ByteLess)
    local plan = { payments = {}, winners = winners, losers = losers, share = {} }
    if #winners == 0 or #losers == 0 then
        plan.pot = 0
        return plan
    end
    local pot = gold * #losers
    plan.pot = pot
    local base = math.floor(pot / #winners)
    local rem = pot % #winners
    local quota = {}
    for i, name in ipairs(winners) do
        quota[i] = base + (i <= rem and 1 or 0)
        plan.share[name] = quota[i]
    end
    local wi, filled = 1, 0
    for _, loser in ipairs(losers) do
        local owe = gold
        while owe > 0 and wi <= #winners do
            local space = quota[wi] - filled
            local pay = owe < space and owe or space
            if pay > 0 then
                plan.payments[#plan.payments + 1] =
                    { from = loser, to = winners[wi], gold = pay }
                owe, filled = owe - pay, filled + pay
            end
            if filled >= quota[wi] then wi, filled = wi + 1, 0 end
        end
    end
    return plan
end

-- Returns nil while the authoritative participant snapshot is missing.
function W:ComputePlan(bet)
    if bet.status ~= "resolved" or bet.incomplete then return nil end
    return planFromParticipants(bet.p, bet.gold, bet.win)
end

-- Hypothetical plan for the resolve-confirm dialog (bet not yet resolved).
function W:PreviewPlan(bet, win)
    return planFromParticipants(bet.p, bet.gold, win)
end

----------------------------------------------------------------- settlement

-- Payment handshake, guild-shared (user decision 2026-08-18, replaces the
-- earlier private per-character checkboxes):
--   0 = unpaid, 1 = payer says paid ("ohlaseno"), 2 = receiver confirmed.
-- State lives ON the bet as bet.ps = { [paymentIndex] = 1|2 }, aligned to
-- the DETERMINISTIC payment order of ComputePlan, and is only meaningful
-- for the resolve epoch stamped in bet.psE (== bet.re). States only ever
-- rise (per-position max), so replays and stale mirrors are harmless.

function W:PayState(bet, idx)
    if bet.psE ~= bet.re or not bet.ps then return 0 end
    return bet.ps[idx] or 0
end

-- Shared by local clicks and the network handler; validates identity:
-- only the payer may claim (1), only the receiver may confirm (2).
function W:ApplyPayState(id, idx, v, who)
    local bet = self:GetBet(id)
    if not bet then return end
    local plan = self:ComputePlan(bet)
    if not plan then return end
    local pay = plan.payments[idx]
    if not pay then return end
    if v == 1 and who ~= pay.from then return end
    if v == 2 and who ~= pay.to then return end
    if bet.psE ~= bet.re then bet.ps, bet.psE = {}, bet.re end
    bet.ps = bet.ps or {}
    if v > (bet.ps[idx] or 0) then
        bet.ps[idx] = v
        self:Refresh()
        return true
    end
end

function W:DoPay(id, idx, v)
    if self:ApplyPayState(id, idx, v, self:Me()) then
        self:SendPay(id, idx, v)
    end
end

-- Mirror merge (S sync): per-position max, no identity check - the state
-- only rises and a wrong claim costs play money in a trust-based toy.
function W:MergePayStates(id, str)
    local bet = self:GetBet(id)
    if not bet or type(str) ~= "string" then return end
    local plan = self:ComputePlan(bet)
    if not plan then return end -- not resolved/complete yet; caller may retry
    if bet.psE ~= bet.re then bet.ps, bet.psE = {}, bet.re end
    bet.ps = bet.ps or {}
    local changed
    for i = 1, math.min(#str, #plan.payments) do
        local v = tonumber(str:sub(i, i))
        if v and v > (bet.ps[i] or 0) and v <= 2 then
            bet.ps[i] = v
            changed = true
        end
    end
    if changed then self:Refresh() end
    return true
end

-- Compact wire form for S mirrors: one digit per payment ("0120"), nil
-- when nothing is marked yet (saves mirror bytes).
function W:PayStateString(bet)
    local plan = self:ComputePlan(bet)
    if not plan or bet.psE ~= bet.re or not bet.ps then return nil end
    local out, any = {}, false
    for i = 1, #plan.payments do
        local v = bet.ps[i] or 0
        out[i] = tostring(v)
        if v > 0 then any = true end
    end
    return any and table.concat(out) or nil
end

function W:CountMyUnsettled()
    local me, count = self:Me(), 0
    for _, bet in pairs(self.db.global.bets) do
        if bet.status == "resolved" and bet.p[me] then
            local plan = self:ComputePlan(bet)
            if plan then
                for i, pay in ipairs(plan.payments) do
                    if (pay.from == me or pay.to == me)
                            and self:PayState(bet, i) < 2 then
                        count = count + 1
                        break
                    end
                end
            end
        end
    end
    return count
end

-- Debt ledger: my unconfirmed payments folded per counterparty+direction.
-- dir "owe" = I pay them, "owed" = they pay me. items carry the exact
-- (betId, index) pairs so the bulk buttons hit precisely these payments.
function W:GetDebts()
    local me = self:Me()
    local buckets, list = {}, {}
    for _, bet in pairs(self.db.global.bets) do
        if bet.status == "resolved" then
            local plan = self:ComputePlan(bet)
            if plan then
                for i, pay in ipairs(plan.payments) do
                    local st = self:PayState(bet, i)
                    if st < 2 then
                        local other, dir
                        if pay.from == me then
                            other, dir = pay.to, "owe"
                        elseif pay.to == me then
                            other, dir = pay.from, "owed"
                        end
                        if other then
                            local key = dir .. other
                            local e = buckets[key]
                            if not e then
                                e = { name = other, dir = dir, total = 0,
                                      claimed = 0, items = {} }
                                buckets[key] = e
                                list[#list + 1] = e
                            end
                            e.total = e.total + pay.gold
                            if st == 1 then e.claimed = e.claimed + pay.gold end
                            e.items[#e.items + 1] =
                                { id = bet.id, idx = i, gold = pay.gold, state = st }
                        end
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b)
        if a.dir ~= b.dir then return a.dir == "owe" end -- my debts on top
        if a.total ~= b.total then return a.total > b.total end
        return W.ByteLess(a.name, b.name)
    end)
    return list
end

-- Bulk action from the Dluhy tab: raise every listed payment to v
-- (DoPay validates identity per payment, so a wrong v is a no-op).
function W:DoPayAll(entry, v)
    for _, item in ipairs(entry.items) do
        if item.state < v then self:DoPay(item.id, item.idx, v) end
    end
end

---------------------------------------------------------------------- stats

local function statBucket(t, name)
    local b = t[name]
    if not b then
        b = { net = 0, wins = 0, losses = 0, best = 0 }
        t[name] = b
    end
    return b
end

local function foldPlan(t, bet, plan)
    for _, name in ipairs(plan.winners) do
        local b = statBucket(t, name)
        local share = plan.share[name] or 0
        b.net = b.net + share
        b.wins = b.wins + 1
        if share > b.best then b.best = share end
    end
    for _, name in ipairs(plan.losers) do
        local b = statBucket(t, name)
        b.net = b.net - bet.gold
        b.losses = b.losses + 1
    end
end

-- Stats are derived, never accumulated: late participant corrections and
-- duplicate resolve deliveries can then never double-count (DESIGN: F6).
function W:ComputeStats()
    local stats = {}
    for name, agg in pairs(self.db.global.aggregate) do
        local b = statBucket(stats, name)
        b.net, b.wins, b.losses, b.best = agg.net, agg.wins, agg.losses, agg.best
    end
    for _, bet in pairs(self.db.global.bets) do
        local plan = self:ComputePlan(bet)
        if plan and plan.pot > 0 then
            foldPlan(stats, bet, plan)
        end
    end
    return stats
end

--------------------------------------------------------------------- pruning

function W:PruneHistory()
    local done = {}
    local now = time()
    for _, bet in pairs(self.db.global.bets) do
        if bet.status == "resolved" or bet.status == "cancelled" then
            done[#done + 1] = bet
        elseif self:IsExpired(bet)
                and now - (bet.firstSeen or 0) > W.EXPIRY_SECONDS + 4 * 86400 then
            -- long-dead expired bets become prunable too (a week past
            -- creation); until then they stay so a very late resolve from
            -- the author still finds its bet
            done[#done + 1] = bet
        end
    end
    if #done <= W.HISTORY_KEEP then return end
    table.sort(done, function(a, b)
        return (a.resolvedAt or a.firstSeen or 0) > (b.resolvedAt or b.firstSeen or 0)
    end)
    local me = self:Me()
    for i = W.HISTORY_KEEP + 1, #done do
        local bet = done[i]
        local keep = false
        if bet.p[me] then
            local plan = self:ComputePlan(bet)
            if plan then
                for pi, pay in ipairs(plan.payments) do
                    if (pay.from == me or pay.to == me)
                            and self:PayState(bet, pi) < 2 then
                        keep = true
                        break
                    end
                end
            elseif bet.incomplete then
                keep = true -- can't judge my payments until the snapshot lands
            end
        end
        if not keep then
            local plan = self:ComputePlan(bet)
            if plan and plan.pot > 0 then
                foldPlan(self.db.global.aggregate, bet, plan)
            end
            self.db.global.bets[bet.id] = nil
        end
    end
end

------------------------------------------------------------------ UI feeds

function W:GetActiveBets()
    local list = {}
    for _, bet in pairs(self.db.global.bets) do
        if (bet.status == "open" or bet.status == "locked")
                and not self:IsExpired(bet) then
            list[#list + 1] = bet
        end
    end
    table.sort(list, function(a, b)
        return (a.firstSeen or 0) > (b.firstSeen or 0)
    end)
    return list
end

function W:GetHistoryBets()
    local list = {}
    for _, bet in pairs(self.db.global.bets) do
        if bet.status == "resolved" or bet.status == "cancelled"
                or self:IsExpired(bet) then
            list[#list + 1] = bet
        end
    end
    table.sort(list, function(a, b)
        return (a.resolvedAt or a.firstSeen or 0) > (b.resolvedAt or b.firstSeen or 0)
    end)
    return list
end

function W:ActiveBetCount()
    local n = 0
    for _, bet in pairs(self.db.global.bets) do
        if (bet.status == "open" or bet.status == "locked")
                and not self:IsExpired(bet) then
            n = n + 1
        end
    end
    return n
end

------------------------------------------------------------------- announce

-- Public chat voice rules (DESIGN/USER-STORIES): one line, playful, winners
-- and pot only, never loser names, no slash commands. Rotating templates so
-- it doesn't read like bot spam. Czech - cz/sk guild (user 2026-08-18).
local CREATE_LINES = {
    function(a, t, g)
        return ('SoTBookie: %s hazi na stul %dg a tvrdi: "%s". Kdo ma odvahu jit proti?'):format(a, g, t)
    end,
    function(a, t, g)
        return ('SoTBookie: cerstva sazka! %s: "%s" - v banku %dg. Ber, nebo do smrti lituj.'):format(a, t, g)
    end,
    function(a, t, g)
        return ('SoTBookie: %s si veri: "%s". Vklad %dg. Je tu nekdo tak chytry, aby to vyvratil?'):format(a, t, g)
    end,
    function(a, t, g)
        return ('SoTBookie: pozor pozor, %s vyhlasuje "%s" za %dg. Skeptici, hlaste se.'):format(a, t, g)
    end,
}
local RESOLVE_LINES = {
    function(t, side, pot)
        return ('SoTBookie: dohrano! "%s" - pravdu mela strana %s a bere bank %dg. GG.'):format(t, side, pot)
    end,
    function(t, side, pot)
        return ('SoTBookie: "%s"? Vyreseno. Strana %s si trha %dg. Porazeni plati s usmevem.'):format(t, side, pot)
    end,
    function(t, side, pot)
        return ('SoTBookie: bank %dg meni majitele - "%s" vyhrala strana %s. Nekdo to proste vedel.'):format(pot, t, side)
    end,
}

function W:AnnounceChannel()
    if GetNumRaidMembers() > 0 then return "RAID" end
    if GetNumPartyMembers() > 0 then return "PARTY" end
    if IsInGuild() then return "GUILD" end
end

function W:AnnounceCreate(id)
    local bet = self:GetBet(id)
    if not bet then return end
    local ch = self:AnnounceChannel()
    if not ch then return end
    self.announceIdx = (self.announceIdx or 0) + 1
    local line = CREATE_LINES[(self.announceIdx % #CREATE_LINES) + 1]
    SendChatMessage(line(bet.author, bet.text, bet.gold), ch)
end

function W:AnnounceResolve(id)
    local bet = self:GetBet(id)
    if not bet or bet.status ~= "resolved" then return end
    local plan = self:ComputePlan(bet)
    if not plan or plan.pot == 0 then return end
    local ch = self:AnnounceChannel()
    if not ch then return end
    self.announceIdx = (self.announceIdx or 0) + 1
    local line = RESOLVE_LINES[(self.announceIdx % #RESOLVE_LINES) + 1]
    SendChatMessage(line(bet.text, bet.win == "Y" and "ANO" or "NE", plan.pot), ch)
end
