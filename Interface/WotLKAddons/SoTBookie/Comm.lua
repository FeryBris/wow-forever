--========================================================================--
-- SoTBookie / Comm.lua
-- Wire protocol: hidden addon messages over GUILD + whisper sync bursts.
-- Contract: Docs/DESIGN.md ("Wire protocol" / "Login sync"). Invariants:
--  * every payload stays single-part (<= MAX_PAYLOAD after serialization);
--    an oversized send would multipart and corrupt the per-sender spool
--  * unknown message types are ignored (forward compatibility)
--  * handlers never trust payload fields; authority checks use `sender`
--  * own GUILD echoes are consumed as a delivery confirmation only
--========================================================================--

local W = LibStub("AceAddon-3.0"):GetAddon("SoTBookie")

local PREFIX = "Bkie"
local MAX_PAYLOAD = 245        -- 255 - #PREFIX - separator, minus safety margin
local TIME_BASE = 1754000000   -- timestamps travel as small offsets
local CHUNK_NAMES = 6          -- participants per P chunk (byte budget)

local STATUS_CHAR = { open = "o", locked = "l", cancelled = "c", resolved = "r" }
local CHAR_STATUS = { o = "open", l = "locked", c = "cancelled", r = "resolved" }

-- Runtime-only comm state (never SavedVariables).
local state = {
    buffers = {},       -- [betId] = {sender, e, n, m, chunks, got}
    pending = {},       -- [target] = timer (scheduled sync reply)
    answered = {},      -- [target] = GetTime() of our last snapshot burst
    qAsked = {},        -- [betId]  = GetTime() we last whispered Q
    qAnswered = {},     -- [betId]  = GetTime() we last re-broadcast a snapshot
    pendingPs = {},     -- [betId]  = pay-state string from a mirror that
                        --            arrived before the bet was computable
    lastInbound = 0,
    helloRetries = 0,
    wdRetries = 0,
}

------------------------------------------------------------------ low level

local function trimUtf8Tail(s)
    -- never end on a partial multibyte char (Czech diacritics)
    while #s > 0 do
        local b = string.byte(s, #s)
        if b >= 128 and b < 192 then s = s:sub(1, #s - 1) else break end
    end
    if #s > 0 and string.byte(s, #s) >= 192 then
        s = s:sub(1, #s - 1) -- dangling lead byte
    end
    return s
end

function W:CommSend(tbl, dist, target, prio)
    local payload = self:Serialize(tbl)
    if #payload > MAX_PAYLOAD then
        self:Print(("Interni chyba: zprava (%s B) neodesla - nahlas to prosim."):format(#payload))
        return false
    end
    self:SendCommMessage(PREFIX, payload, dist, target, prio or "NORMAL")
    if dist == "GUILD" then self:ArmEchoWatchdog() end
    return true
end

function W:Broadcast(tbl, prio)
    if not IsInGuild() then return false end
    return self:CommSend(tbl, "GUILD", nil, prio)
end

-- Own echo never returning = our rank can't speak/listen on guild chat.
-- This is the only detection 3.3.5 offers, so use it (DESIGN: F20).
function W:ArmEchoWatchdog()
    if state.echoOK or state.echoWarned or state.echoTimer then return end
    state.echoTimer = self:ScheduleTimer(function()
        state.echoTimer = nil
        state.echoWarned = true
        self:Print("Tvoje addon zpravy do guildy nechodi - popros officera, at zkontroluje prava tveho ranku na guild chat.")
    end, 5)
end

-------------------------------------------------------------------- senders

function W:SendNew(bet)
    self:Broadcast({ t = "N", i = bet.id, x = bet.text, g = bet.gold,
        c = (bet.created or 0) - TIME_BASE })
end

function W:SendJoin(id, side) self:Broadcast({ t = "J", i = id, s = side }) end
function W:SendLeave(id) self:Broadcast({ t = "L", i = id }) end
function W:SendCancel(id) self:Broadcast({ t = "C", i = id }) end
function W:SendUnlock(id, e) self:Broadcast({ t = "U", i = id, e = e }) end

function W:SendResolve(id, win, epoch)
    self:Broadcast({ t = "R", i = id, w = win, e = epoch })
end

function W:SendPay(id, idx, v)
    self:Broadcast({ t = "T", i = id, x = idx, v = v })
end

function W:SendSnapshotChunks(bet, dist, target, prio)
    local names = {}
    for name, side in pairs(bet.p) do
        names[#names + 1] = name .. "=" .. side
    end
    table.sort(names, W.ByteLess)
    local q = 0
    for i = 1, #names, CHUNK_NAMES do
        q = q + 1
        local pp = {}
        for j = i, math.min(i + CHUNK_NAMES - 1, #names) do
            pp[#pp + 1] = names[j]
        end
        self:CommSend({ t = "P", i = bet.id, e = bet.pe, q = q, pp = pp },
            dist, target, prio)
    end
end

-- K + P chunks over GUILD: the author's authoritative participant snapshot.
function W:BroadcastSnapshot(bet)
    local n = self:ParticipantCount(bet)
    local m = math.ceil(n / CHUNK_NAMES)
    self:Broadcast({ t = "K", i = bet.id, e = bet.pe, n = n, m = m })
    if m > 0 then self:SendSnapshotChunks(bet, "GUILD") end
end

---------------------------------------------------------------- chunk intake

function W:BeginBuffer(id, sender, e, n, m)
    if m <= 0 then
        state.buffers[id] = nil
        self:ReplaceParticipants(id, e, {})
        return
    end
    local buf = { sender = sender, e = e, n = n, m = m, chunks = {}, got = 0 }
    state.buffers[id] = buf
    -- a buffer whose chunks never complete would pin its sender+epoch forever
    self:ScheduleTimer(function()
        if state.buffers[id] == buf and buf.got < buf.m then
            state.buffers[id] = nil
        end
    end, 30)
end

local function finishBuffer(self, id, buf)
    local p, count = {}, 0
    for q = 1, buf.m do
        for _, entry in ipairs(buf.chunks[q]) do
            if type(entry) == "string" then
                local name, side = entry:match("^([^=]+)=([YN])$")
                if name then
                    p[name] = side
                    count = count + 1
                end
            end
        end
    end
    state.buffers[id] = nil
    if count == buf.n then
        self:ReplaceParticipants(id, buf.e, p)
        -- a mirror's pay states may have been waiting for these chunks
        local ps = state.pendingPs[id]
        if ps and self:MergePayStates(id, ps) then
            state.pendingPs[id] = nil
        end
    end
end

------------------------------------------------------------------- handlers

local HANDLERS = {}

HANDLERS.N = function(self, m, sender)
    if type(m.i) ~= "string" or #m.i > 40 then return end
    -- the id must be the sender's own namespace; nobody creates bets as others
    if m.i:sub(1, #sender + 1) ~= sender .. "-" then return end
    local text = W.SanitizeText(m.x)
    if text == "" or W.TextCost(text) > W.TEXT_COST_MAX then return end
    local gold = tonumber(m.g)
    if not gold or gold ~= math.floor(gold)
            or gold < W.GOLD_MIN or gold > W.GOLD_MAX then return end
    local bet = self:ApplyNew(m.i, sender, text, gold, (tonumber(m.c) or 0) + TIME_BASE)
    if bet then
        self:Print(('%s vyhlasuje: "%s" (%dg) - stranu vyberes pres /bet.')
            :format(sender, W.EscapeText(text), gold))
        if self.db.profile.newBetSound and not InCombatLockdown() then
            -- AuctionWindowOpen: audible coin-flavored cue; the checkbox
            -- click sound used before was too quiet to notice
            PlaySound("AuctionWindowOpen")
        end
    end
end

HANDLERS.J = function(self, m, sender)
    if m.s ~= "Y" and m.s ~= "N" then return end
    if type(m.i) ~= "string" then return end
    self:ApplyJoin(m.i, sender, m.s)
end

HANDLERS.L = function(self, m, sender)
    if type(m.i) ~= "string" then return end
    self:ApplyLeave(m.i, sender)
end

HANDLERS.K = function(self, m, sender)
    if type(m.i) ~= "string" then return end
    local bet = self:GetBet(m.i)
    if not bet or bet.author ~= sender then return end
    local e, n, chunks = tonumber(m.e), tonumber(m.n), tonumber(m.m)
    if not e or not n or not chunks then return end
    -- toggle layer: a K older than a seen unlock must not re-lock (U2);
    -- the chunk intake below still runs (Q repair resends old snapshots)
    self:ApplyToggle(m.i, e, "locked")
    if e >= (bet.pe or 0) then
        self:BeginBuffer(m.i, sender, e, n, chunks)
    end
end

-- Unlock: author-only, epoch-ordered (DESIGN U1). Terminal states immune.
HANDLERS.U = function(self, m, sender)
    if type(m.i) ~= "string" then return end
    local bet = self:GetBet(m.i)
    if not bet or bet.author ~= sender then return end
    local e = tonumber(m.e)
    if not e then return end
    self:ApplyToggle(m.i, e, "open")
end

HANDLERS.P = function(self, m, sender)
    if type(m.i) ~= "string" or type(m.pp) ~= "table" then return end
    local buf = state.buffers[m.i]
    if not buf or buf.sender ~= sender or buf.e ~= tonumber(m.e) then return end
    local q = tonumber(m.q)
    if not q or q < 1 or q > buf.m or buf.chunks[q] then return end
    buf.chunks[q] = m.pp
    buf.got = buf.got + 1
    if buf.got == buf.m then finishBuffer(self, m.i, buf) end
end

HANDLERS.C = function(self, m, sender)
    if type(m.i) ~= "string" then return end
    local bet = self:GetBet(m.i)
    if not bet or bet.author ~= sender then return end
    self:ApplyStatus(m.i, "cancelled")
end

HANDLERS.R = function(self, m, sender)
    if type(m.i) ~= "string" then return end
    local bet = self:GetBet(m.i)
    if not bet or bet.author ~= sender then return end
    if m.w ~= "Y" and m.w ~= "N" then return end
    local e = tonumber(m.e)
    if not e then return end
    if self:ApplyResolve(m.i, m.w, e, sender) then
        self:Print(('Rozhodnuto: "%s" - vyhrava strana %s.')
            :format(W.EscapeText(bet.text), m.w == "Y" and "ANO" or "NE"))
        local ps = state.pendingPs[m.i]
        if ps and self:MergePayStates(m.i, ps) then
            state.pendingPs[m.i] = nil
        end
        if bet.incomplete then
            -- our participant list is stale; ask the author for a fresh snapshot
            local id = m.i
            self:ScheduleTimer(function() self:RequestSnapshot(id) end, 3)
        end
        self:PruneHistory()
    end
end

-- Payment handshake: payer claims (v=1), receiver confirms (v=2).
-- ApplyPayState validates sender identity against the deterministic plan.
HANDLERS.T = function(self, m, sender)
    if type(m.i) ~= "string" then return end
    local x, v = tonumber(m.x), tonumber(m.v)
    if not x or (v ~= 1 and v ~= 2) then return end
    self:ApplyPayState(m.i, x, v, sender)
end

HANDLERS.Q = function(self, m, _sender, dist)
    if dist ~= "WHISPER" or type(m.i) ~= "string" then return end
    local bet = self:GetBet(m.i)
    if not bet or bet.author ~= self:Me() then return end
    local last = state.qAnswered[m.i]
    if last and GetTime() - last < 30 then return end
    state.qAnswered[m.i] = GetTime()
    self:BroadcastSnapshot(bet)
end

HANDLERS.H = function(self, m, sender)
    local v = tonumber(m.v) or 0
    if v > self:VersionNumber() and not state.versionHinted then
        state.versionHinted = true
        self:Print("Existuje novejsi verze SoTBookie - vyzadej si ji v guilde.")
    end
    if not self:HaveAnythingToSync() then return end
    local last = state.answered[sender]
    if last and GetTime() - last < 600 then return end
    if state.pending[sender] then self:CancelTimer(state.pending[sender]) end
    state.pending[sender] = self:ScheduleTimer(function()
        state.pending[sender] = nil
        self:DoSyncReply(sender)
    end, 2 + math.random() * 4)
end

HANDLERS.A = function(self, m, _sender)
    local target = m.p
    if type(target) ~= "string" then return end
    -- someone claimed this target: defer (not cancel) our own reply so a
    -- claimer that disconnects mid-burst doesn't strand the target
    local timer = state.pending[target]
    if timer then
        self:CancelTimer(timer)
        state.pending[target] = self:ScheduleTimer(function()
            state.pending[target] = nil
            self:DoSyncReply(target)
        end, 20)
    end
    if target == self:Me() then self:ArmSyncWatchdog() end
end

HANDLERS.D = function(self, m, _sender)
    local target = m.p
    if type(target) ~= "string" then return end
    local timer = state.pending[target]
    if timer then
        self:CancelTimer(timer)
        state.pending[target] = nil
    end
    if target == self:Me() then self:CancelSyncWatchdog() end
end

HANDLERS.S = function(self, m, sender, dist)
    if dist ~= "WHISPER" then return end
    if type(m.i) ~= "string" or #m.i > 40 or type(m.a) ~= "string" then return end
    -- the id must live in the claimed author's namespace, same rule as N
    if m.i:sub(1, #m.a + 1) ~= m.a .. "-" then return end
    local status = CHAR_STATUS[m.st]
    if not status then return end
    local gold = tonumber(m.g)
    if not gold or gold ~= math.floor(gold)
            or gold < W.GOLD_MIN or gold > W.GOLD_MAX then return end
    if status == "resolved" and m.w ~= "Y" and m.w ~= "N" then return end
    local e = tonumber(m.e) or 0
    local bets = self.db.global.bets
    local bet = bets[m.i]
    if not bet then
        local text = W.SanitizeText(m.x)
        if text == "" then text = "(statement lost in sync)" end
        bet = {
            id = m.i, author = m.a, text = text, gold = gold,
            status = "open", created = (tonumber(m.c) or 0) + TIME_BASE,
            firstSeen = time(), p = { [m.a] = "Y" }, pe = 0,
        }
        bets[m.i] = bet
    end
    if status == "cancelled" or status == "resolved" then
        if W.STATUS_RANK[status] > W.STATUS_RANK[bet.status] then
            bet.status = status
            if status == "resolved" then
                bet.win = m.w
                -- the resolve epoch travels separately from the mirror's own
                -- participant epoch: a mirror that is itself incomplete must
                -- not infect us with a false "complete" flag
                bet.re = tonumber(m.re) or e
                bet.resolvedAt = (tonumber(m.rt) or 0) + TIME_BASE
                bet.resolvedBy = type(m.rb) == "string" and m.rb or bet.author
                bet.incomplete = (bet.pe ~= bet.re) or nil
            end
        end
    elseif bet.status == "open" or bet.status == "locked" then
        -- open/locked axis: the highest author toggle epoch wins, never rank
        -- — a locked mirror recorded before the unlock must not re-lock (U3)
        local mle = tonumber(m.le) or 0
        if mle > (bet.le or 0) then
            bet.status = status
            bet.le = mle
        end
    end
    -- participants may be replaced by an equal-or-newer author epoch even
    -- when the status didn't move (heals stale lists after resolve)
    if e >= (bet.pe or 0) then
        self:BeginBuffer(m.i, sender, e, tonumber(m.n) or 0, tonumber(m.m) or 0)
    end
    -- pay states ride along; if the bet isn't computable yet (chunks or the
    -- resolve still in flight), park them and retry from those handlers
    if type(m.y) == "string" and #m.y <= 64 then
        if not self:MergePayStates(m.i, m.y) then
            state.pendingPs[m.i] = m.y
        end
    end
    state.sawSync = true
    self:CancelSyncWatchdog()
    -- once the burst settles, ask authors for snapshots of anything that
    -- arrived resolved-but-incomplete (chunks lost); rate-limited per bet
    if not state.repairTimer then
        state.repairTimer = self:ScheduleTimer(function()
            state.repairTimer = nil
            for id, b in pairs(self.db.global.bets) do
                if b.incomplete then self:RequestSnapshot(id) end
            end
        end, 8)
    end
    self:Refresh()
end

--------------------------------------------------------------------- receive

function W:OnCommReceived(prefix, message, dist, sender)
    if prefix ~= PREFIX then return end
    if sender == self:Me() then
        state.echoOK = true
        if state.echoTimer then
            self:CancelTimer(state.echoTimer)
            state.echoTimer = nil
        end
        return
    end
    local ok, tbl = self:Deserialize(message)
    if not ok or type(tbl) ~= "table" or type(tbl.t) ~= "string" then return end
    state.lastInbound = GetTime()
    local handler = HANDLERS[tbl.t]
    if handler then handler(self, tbl, sender, dist) end
end

------------------------------------------------------------------ sync logic

function W:HaveAnythingToSync()
    local now = time()
    for _, bet in pairs(self.db.global.bets) do
        -- expired bets must never travel: a peer inserting one with a fresh
        -- firstSeen would resurrect it as an active bet
        if (bet.status == "open" or bet.status == "locked")
                and not self:IsExpired(bet) then
            return true
        end
        if (bet.status == "resolved" or bet.status == "cancelled")
                and (bet.resolvedAt or bet.firstSeen or 0) > now - W.SYNC_RESOLVED_WINDOW then
            return true
        end
    end
    return false
end

function W:SelectSyncBets(target)
    local now = time()
    local list = {}
    for _, bet in pairs(self.db.global.bets) do
        if (bet.status == "open" or bet.status == "locked") then
            if not self:IsExpired(bet) then list[#list + 1] = bet end
        elseif (bet.resolvedAt or bet.firstSeen or 0) > now - W.SYNC_RESOLVED_WINDOW then
            list[#list + 1] = bet
        end
    end
    -- bets the target participates in first: those carry their debts, and
    -- a plain "newest 15" would hide exactly the ones that matter
    table.sort(list, function(a, b)
        local pa, pb = a.p[target] and 1 or 0, b.p[target] and 1 or 0
        if pa ~= pb then return pa > pb end
        return (a.resolvedAt or a.firstSeen or 0) > (b.resolvedAt or b.firstSeen or 0)
    end)
    while #list > 15 do table.remove(list) end
    return list
end

function W:DoSyncReply(target)
    state.answered[target] = GetTime()
    self:Broadcast({ t = "A", p = target })
    for _, bet in ipairs(self:SelectSyncBets(target)) do
        local n = self:ParticipantCount(bet)
        local m = math.ceil(n / CHUNK_NAMES)
        local msg = { t = "S", i = bet.id, a = bet.author, x = bet.text,
            g = bet.gold, st = STATUS_CHAR[bet.status], e = bet.pe or 0,
            n = n, m = m }
        if bet.status == "resolved" then
            msg.w = bet.win
            msg.re = bet.re
            msg.rt = (bet.resolvedAt or 0) - TIME_BASE
            msg.rb = bet.resolvedBy
            msg.y = self:PayStateString(bet) -- nil when nothing marked
        else
            msg.c = (bet.created or 0) - TIME_BASE
            -- toggle epoch rides along so the receiver can order this
            -- mirror against any unlock it has seen (open/locked only —
            -- terminal mirrors are rank-merged and stay within budget)
            if bet.status ~= "cancelled" and (bet.le or 0) > 0 then
                msg.le = bet.le
            end
        end
        -- the mirror text is display-only (authoritative text traveled with
        -- N); shave it down rather than ever exceeding one part
        local payload = self:Serialize(msg)
        while #payload > MAX_PAYLOAD and #msg.x > 0 do
            msg.x = trimUtf8Tail(msg.x:sub(1, math.max(0, #msg.x - 10)))
            payload = self:Serialize(msg)
        end
        if #payload <= MAX_PAYLOAD then
            self:SendCommMessage(PREFIX, payload, "WHISPER", target, "BULK")
            if m > 0 then self:SendSnapshotChunks(bet, "WHISPER", target, "BULK") end
        end
    end
    self:Broadcast({ t = "D", p = target })
end

function W:RequestSnapshot(id)
    local bet = self:GetBet(id)
    if not bet or not bet.incomplete then return end
    local last = state.qAsked[id]
    if last and GetTime() - last < 30 then return end
    state.qAsked[id] = GetTime()
    self:CommSend({ t = "Q", i = id }, "WHISPER", bet.author)
end

function W:ArmSyncWatchdog()
    if state.watchdog or state.sawSync then return end
    state.watchdog = self:ScheduleTimer(function()
        state.watchdog = nil
        if not state.sawSync and state.wdRetries < 2 then
            state.wdRetries = state.wdRetries + 1
            self:SendHello()
        end
    end, 15)
end

function W:CancelSyncWatchdog()
    if state.watchdog then
        self:CancelTimer(state.watchdog)
        state.watchdog = nil
    end
end

--------------------------------------------------------------- login / hello

function W:CommOnEnable()
    self:RegisterComm(PREFIX)
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "CommWorldEntered")
    self:RegisterEvent("GUILD_ROSTER_UPDATE", "CommRosterUpdate")
    GuildRoster()
end

function W:CommWorldEntered()
    state.worldSeen = true
    self:MaybeScheduleHello()
end

function W:CommRosterUpdate()
    state.rosterSeen = true
    self:MaybeScheduleHello()
end

-- HELLO waits for the world AND a roster update: a GUILD send before the
-- guild channel exists server-side fails silently (DESIGN: F19).
function W:MaybeScheduleHello()
    if state.helloScheduled then return end
    if not (state.worldSeen and state.rosterSeen and IsInGuild()) then return end
    state.helloScheduled = true
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    self:UnregisterEvent("GUILD_ROSTER_UPDATE") -- high-frequency, job done
    self:ScheduleTimer(function() self:SendHello(true) end, 10)
end

function W:SendHello(isLogin)
    if not IsInGuild() then return end
    state.sawSync = false
    self:Broadcast({ t = "H", v = self:VersionNumber(), k = self:ActiveBetCount() })
    if isLogin and state.helloRetries < 2 then
        self:ScheduleTimer(function()
            if state.lastInbound == 0 and state.helloRetries < 2 then
                state.helloRetries = state.helloRetries + 1
                self:SendHello(true)
            end
        end, 30)
    end
    if isLogin and not state.noticeArmed then
        state.noticeArmed = true
        self:ScheduleTimer(function()
            local n = self:CountMyUnsettled()
            if n > 0 then
                self:Print(("Nevyrizene platby u rozhodnutych sazek: %d - mrkni na kartu Dluhy (/bet)."):format(n))
            end
        end, 30)
    end
end

function W:RequestSync()
    if state.syncAt and GetTime() - state.syncAt < 10 then return end
    state.syncAt = GetTime()
    self:SendHello(false)
end
