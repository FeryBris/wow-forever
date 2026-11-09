-- A probe for one question from ROADMAP.md's backlog: can the charges of
-- Lightning Shield be counted during a fight from what reaches an addon?
--
-- Scaffolding, not a feature. It records by itself while COLLECTING is on, on
-- a Shaman only, and says nothing in chat unless asked with
-- /fplus probe shield. It goes away with its file once the question is
-- answered, the way the short buff probe of 2026-09-22 did.
--
-- What is known before it runs, and why the design looks like this:
--
--   * Reading an aura in combat is refused, so the charges are only ever read
--     out of combat: the last reading before a fight and the first after it.
--   * UNIT_COMBAT reaches an addon for the player inside the lockdown with
--     plain values, measured 2026-09-27: action, flag, amount, school. It
--     names no attacker and no spell, which is the whole difficulty.
--   * The shield has an internal cooldown, confirmed by the owner. 3.5
--     seconds is what a search answered and is a hypothesis here: the report
--     simulates it next to no cooldown at all, and the file keeps every
--     timestamp so another length can be tried at a desk.
--   * UNIT_AURA fires in combat as a bare signal. Its timestamps are kept too,
--     because a spent charge may be exactly such a signal.
--
-- Each fight becomes one record: the charges before, every event with its time
-- relative to the start, and the charges after. Comparing what a rule predicts
-- with what was read after the fight is the measurement.
--
-- **On again since 2026-10-11, for Inner Fire on a priest**, which has twenty
-- charges on WoW Forever, the owner's word: every melee or ranged hit spends
-- one, a spell none, and none while a shield absorbs the hit. BuffExpiry
-- counts it by that rule from the same day, and this holds the rule against
-- the charges read after each fight. No cooldown is known, so a priest's
-- fights are replayed at none, and the rule "physical, with damage" is the
-- one Inner Fire is counted by. Its first four fights the same evening fitted
-- it in all four, once a hit of 0 damage spent nothing, and the owner settled
-- the spell hits himself: they spend none, he is certain. Off again the same
-- evening, with its priest fights kept in `innerFireProbe`.
--
-- **On again since 2026-10-16, for Water Shield.** The owner's word: on WoW
-- Forever a critical spell of the Shaman's own spends a charge too, with the
-- same 3.5 second cooldown shared with the hits, and no addon can see whose
-- crit a crit was. But every charge Water Shield spends casts 408511, which
-- gives 3 percent of the maximum mana, out of the Wowhead Forever database,
-- and a mana gain reaches UNIT_COMBAT for the player as ENERGIZE, which the
-- player frame's own feedback reads. Counting those would count the charges
-- whatever spent them. Open, and what this measures: whether the ENERGIZE
-- arrives, whether its amount is 3 percent of the maximum, and what it says
-- at full mana, where the client's own combat text expects a gain of 0. The
-- player's mana is secret, so a fight at full mana is the owner's to arrange.
-- Water Shield's fights go to a list of their own, `waterShieldProbe`, with
-- the maximum mana beside every ENERGIZE, every crit the event reports on
-- another unit, the player's own casts, and the combat text's mana gains.
-- **Off again the next day**: no Shaman of the owner's reaches Water Shield's
-- level before the beta closes, so BuffExpiry counts the mana unmeasured, his
-- choice, and this waits with its list for a measurement after the launch.

local ADDON, FP = ...

-- Step 7 of *Releasing* greps for this name. Off before a release.
local COLLECTING = false

local MAX_FIGHTS = 40
local MAX_EVENTS = 300
local PRE_WINDOW = 3     -- seconds of events kept from before a fight starts
local AFTER_READ = 1     -- seconds after a fight for the second reading

-- Every charge buff this probe follows, out of Data/Buffs.lua so the two
-- cannot drift apart: Lightning Shield and Water Shield on a Shaman, and on a
-- priest Inner Fire since 2026-10-11, where it followed the Undead's Touch of
-- Weakness from 2026-09-29, whose question is settled. Filled for the
-- player's class in Start.
local SHIELD_IDS, SHIELD_SET = {}, {}
local PROBED = { SHAMAN = "shield", PRIEST = "innerFire" }

-- Water Shield, the second line of the Shaman's entry. Its fights are kept
-- apart from Lightning Shield's, whose rule is settled.
local WATER = { [408510] = true }
local WATER_KEY = "waterShieldProbe"
local MANA = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0

local function CollectIds(class)
    for _, entry in ipairs((FP.classBuffs or {})[class] or {}) do
        if entry.id == PROBED[class] then
            for _, line in ipairs(entry.lines or {}) do
                for _, id in ipairs(line) do
                    SHIELD_IDS[#SHIELD_IDS + 1] = id
                    SHIELD_SET[id] = true
                end
            end
        end
    end
end

-- Where the fights are kept: one list per class, so a Shaman's three charges
-- and a priest's one never meet in the same replay.
local storeKey = "shieldProbe"

-- `icd` is the cooldown the report replays at: the Shaman shields' 3.5
-- seconds, and none for a priest's Inner Fire, set in Start.
local P = { collecting = COLLECTING, icd = 3.5 }
FP.ShieldProbe = P

local function Now() return GetTime and GetTime() or 0 end

--- A number that can be handled, or nil. A secret one raises on arithmetic.
local function Number(value)
    local ok, n = pcall(function() return value + 0 end)
    return ok and n or nil
end

--- A string that can be handled, the word "secret", or nil.
local function Text(value)
    if value == nil then return nil end
    local plain = FP:Plain(value)
    if plain then return plain end
    local ok, empty = pcall(function() return value == "" end)
    if ok and empty then return "" end
    return "secret"
end

local function Store(key)
    key = key or storeKey
    local store = FP.global and FP.global[key]
    if type(store) ~= "table" then
        store = {}
        if FP.global then FP.global[key] = store end
    end
    if type(store.fights) ~= "table" then store.fights = {} end
    if type(store.errors) ~= "table" then store.errors = {} end
    return store
end

local function Quietly(what, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        local store = Store()
        if store.errors[what] == nil then store.errors[what] = tostring(err) end
    end
end

--- Each distinct way the aura has looked: its raw stack count and the
--- duration the client reports, which for Touch of Weakness is the open
--- question in the backlog, since its tooltip prints none.
local function NoteLook(id, aura, charges)
    local duration = Number(aura.duration)
    local key = table.concat({ tostring(id), tostring(charges), tostring(duration) }, "|")
    local store = Store()
    if type(store.looks) ~= "table" then store.looks = {} end
    if store.looks[key] then return end
    store.looks[key] = {
        spell = id, applications = charges, duration = duration,
        expires = Number(aura.expirationTime) and Number(aura.expirationTime) - Now(),
        stamp = date("%Y-%m-%d %H:%M:%S"),
    }
end

--- The player's maximum mana, which reads plainly where the mana does not.
local function MaxMana()
    if not UnitPowerMax then return nil end
    local ok, value = pcall(UnitPowerMax, "player", MANA)
    return ok and Number(value) or nil
end

--- The shield on the player right now: spell id and charges, or a reason.
--
-- By id rather than by enumeration, like BuffExpiry: a refusal costs one
-- answer rather than the pass. In combat this returns "refused" or "none" and
-- the two cannot be told apart, which is why nothing in combat relies on it.
local function ReadShield()
    local get = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
    if type(get) ~= "function" then return nil, nil, "no reader" end
    for _, id in ipairs(SHIELD_IDS) do
        local ok, aura = pcall(get, id)
        if not ok then return nil, nil, "refused" end
        if type(aura) == "table" then
            local charges = Number(aura.applications)
            NoteLook(id, aura, charges)
            if charges == nil then return id, nil, "charges secret" end
            -- An aura with one charge usually shows no stack at all and says
            -- 0 here. Present is one charge; absent is the "none" below.
            if charges == 0 then charges = 1 end
            return id, charges, "ok"
        end
    end
    return nil, nil, "none"
end

local fight        -- the record being written, while in combat
local known        -- the last reading out of combat: { spell, charges, t }
local recent = {}  -- events from the last PRE_WINDOW seconds out of combat
local inCombat = false

local function Note(kind, fields)
    local t = Now()
    fields.t = t
    fields.kind = kind
    if fight then
        if #fight.events < MAX_EVENTS then
            fields.t = t - fight.start
            fight.events[#fight.events + 1] = fields
        else
            fight.dropped = (fight.dropped or 0) + 1
        end
    else
        recent[#recent + 1] = fields
        while recent[1] and t - recent[1].t > PRE_WINDOW do table.remove(recent, 1) end
    end
end

local function ReadOutOfCombat(why)
    if inCombat then return end
    local spell, charges, verdict = ReadShield()
    if verdict == "ok" or verdict == "none" then
        known = { spell = spell, charges = verdict == "ok" and charges or 0,
                  t = Now(), why = why }
    end
end

local function StartFight()
    inCombat = true
    local start = Now()
    fight = {
        stamp  = date("%Y-%m-%d %H:%M:%S"),
        start  = start,
        before = known and { spell = known.spell, charges = known.charges,
                             age = start - known.t, why = known.why } or nil,
        events = {},
    }
    -- A hit can arrive before the client says the fight began. Those events
    -- are kept with a negative time rather than lost.
    for _, e in ipairs(recent) do
        e.t = e.t - start
        fight.events[#fight.events + 1] = e
    end
    recent = {}
    -- One read inside the lockdown, to confirm the refusal on this build
    -- rather than assume it.
    local _, _, verdict = ReadShield()
    fight.readInCombat = verdict
end

local function AfterReading(record, field)
    local spell, charges, verdict = ReadShield()
    record[field] = { spell = spell, charges = charges, verdict = verdict,
                      at = Now() - record.start }
end

local function EndFight()
    inCombat = false
    local record = fight
    fight = nil
    if not record then return end
    record.length = Now() - record.start
    AfterReading(record, "after")
    if C_Timer and C_Timer.After then
        C_Timer.After(AFTER_READ, function()
            Quietly("late read", AfterReading, record, "afterLate")
            Quietly("late read", ReadOutOfCombat, "after fight")
        end)
    end

    -- Only fights with a shield on at either end say anything. The rest are
    -- kept out of the file rather than filling it.
    local had = (record.before and record.before.charges or 0) > 0
    local water = WATER[record.before and record.before.spell or 0]
                  or WATER[record.after.spell or 0]
    for _, e in ipairs(record.events) do
        if e.kind == "cast" then
            had = true
            if WATER[e.spell or 0] then water = true end
        end
    end
    if not had and not record.after.spell then return end

    local fights = Store(water and WATER_KEY or nil).fights
    fights[#fights + 1] = record
    while #fights > MAX_FIGHTS do table.remove(fights, 1) end
    ReadOutOfCombat("after fight")
end

local function OnEvent(_, event, ...)
    if event == "UNIT_COMBAT" then
        local unit, action, flag, amount, school = ...
        local who = FP:Plain(unit)
        if who ~= "player" then
            -- A crit somewhere else, which may be one of the player's own
            -- spells: the event never says whose.
            if inCombat and Text(flag) == "CRITICAL" then
                Note("crit", { unit = who or "secret", action = Text(action),
                               amount = Number(amount), school = Number(school) })
            end
            return
        end
        local fields = { action = Text(action), flag = Text(flag),
                         amount = Number(amount), school = Number(school) }
        if fields.action == "ENERGIZE" then fields.maxMana = MaxMana() end
        Note("combat", fields)
    elseif event == "COMBAT_TEXT_UPDATE" then
        -- The combat text's mana gains, a second channel. Its amount comes
        -- from a call the API documentation marks secret, so it may be nil.
        local kind = Text((...))
        if not (kind and kind:find("ENERGIZE", 1, true)) then return end
        local data, power
        if C_CombatText and C_CombatText.GetCurrentEventInfo then
            local ok, a, b = pcall(C_CombatText.GetCurrentEventInfo)
            if ok then data, power = Number(a), Text(b) end
        end
        Note("text", { type = kind, amount = data, power = power,
                       maxMana = MaxMana() })
    elseif event == "UNIT_AURA" then
        if FP:Plain((...)) ~= "player" then return end
        if inCombat then
            Note("aura", {})
        else
            ReadOutOfCombat("aura")
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spell = ...
        if FP:Plain(unit) ~= "player" then return end
        spell = Number(spell)
        if not spell then return end
        if not SHIELD_SET[spell] then
            -- Every other cast of the player's own, for setting a crit beside
            -- the cast it may have come from.
            if inCombat then Note("spell", { spell = spell }) end
            return
        end
        Note("cast", { spell = spell })
        if not inCombat and C_Timer and C_Timer.After then
            C_Timer.After(0.2, function() Quietly("cast read", ReadOutOfCombat, "cast") end)
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        StartFight()
    elseif event == "PLAYER_REGEN_ENABLED" then
        EndFight()
    end
end

local function Start()
    if not COLLECTING then return end
    local _, class = UnitClass("player")
    if not PROBED[class] then return end
    -- Its own list, so Touch of Weakness's fights of 2026-09-29 never meet
    -- Inner Fire's twenty charges in one replay.
    if class == "PRIEST" then storeKey, P.icd = "innerFireProbe", 0 end
    CollectIds(class)
    if #SHIELD_IDS == 0 then return end

    local frame = CreateFrame("Frame")
    for _, event in ipairs({ "UNIT_COMBAT", "UNIT_AURA", "UNIT_SPELLCAST_SUCCEEDED",
                             "COMBAT_TEXT_UPDATE",
                             "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
        if not pcall(frame.RegisterEvent, frame, event) then
            Store().errors["register " .. event] = "unknown event"
        end
    end
    frame:SetScript("OnEvent", function(self, event, ...)
        Quietly(event, OnEvent, self, event, ...)
    end)
    P.running = true
    ReadOutOfCombat("login")
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    if C_Timer and C_Timer.After then
        C_Timer.After(1, function() Quietly("start", Start) end)
    else
        Quietly("start", Start)
    end
end)

-- ---------------------------------------------------------------------------
-- The report
--
-- Four rules are replayed over every fight, each predicting the charges left,
-- and the prediction is held against what was read after the fight:
--
--   wound     a WOUND spends a charge, at most one per cooldown
--   physical  the same, but only a physical WOUND, school 1
--   any       every hit the event reports, misses and dodges included
--   aura      every UNIT_AURA in the fight spends one, except the one a cast
--             of the shield causes itself
--
-- The first run of twelve fights, 2026-09-29, fitted wound, physical and any
-- for a cooldown between 3.2 and 3.6 seconds and aura in every fight, and it
-- showed UNIT_AURA arriving before the hit that spent the charge, mostly 0.3
-- to 0.4 seconds and once 1.3. What it could not say is whether a miss, a
-- dodge or a spell spends one, because every such hit fell inside a cooldown
-- or on an empty shield.
-- The report therefore counts the fights where the rules disagree, since only
-- those decide anything, and lists every hit by kind with whether an aura
-- signal came just before it.
-- ---------------------------------------------------------------------------

local AURA_LEAD = 1.5   -- how long before a hit its aura signal may arrive
local SCAN_TO, SCAN_STEP = 6, 0.05

local function IsWound(e) return e.action == "WOUND" end
local function IsPhysicalWound(e) return e.action == "WOUND" and e.school == 1 end
local function IsAnyHit(e) return e.action ~= "HEAL" and e.action ~= "ENERGIZE" end
-- Inner Fire's rule: a physical hit that did damage, so none a shield took,
-- flagged ABSORB with 0, and none of 0 beside another hit, which spent
-- nothing in the first fights of 2026-10-11.
local function IsUnshieldedHit(e)
    return e.action == "WOUND" and e.school == 1 and e.flag ~= "ABSORB"
        and (e.amount or 0) > 0
end

--- Whether an aura event is the shield's own recast rather than a spent charge.
local function AtCast(record, t)
    for _, e in ipairs(record.events) do
        if e.kind == "cast" and math.abs(e.t - t) < 0.05 then return true end
    end
    return false
end

--- The charges a rule predicts are left after the fight.
--
-- A hit the rule counts spends a charge when the shield has one and at least
-- `icd` seconds have passed since the last charge it spent. A recast fills the
-- shield to `full` without restarting that wait. The aura rule ignores the
-- cooldown: the client only sends the signal when a charge actually went.
local function Predict(record, rule, icd, full)
    icd = rule.icd or icd
    local charges = record.before and record.before.charges or 0
    local last = -math.huge
    for _, e in ipairs(record.events) do
        if e.kind == "cast" then
            -- A recast fills the shield and leaves the cooldown running,
            -- measured in the second run of 2026-09-29.
            charges = full
        elseif charges > 0 then
            if rule.aura then
                if e.kind == "aura" and not AtCast(record, e.t) then
                    charges = charges - 1
                end
            elseif e.kind == "combat" and rule.counts(e) and e.t - last >= icd then
                charges, last = charges - 1, e.t
            end
        end
    end
    return charges
end

local RULES = {
    { name = "wound",    counts = IsWound },
    { name = "physical", counts = IsPhysicalWound },
    { name = "any",      counts = IsAnyHit },
    { name = "physical, with damage", counts = IsUnshieldedHit },
    { name = "aura",     aura = true },
}

--- Whether a mana gain is the size Water Shield's 408511 gives, 3 percent of
--- the maximum, rounded either way; or nothing at all, which full mana may
--- report.
local function IsShieldMana(e)
    if e.action ~= "ENERGIZE" or not e.amount then return false end
    if e.amount == 0 then return true end
    return e.maxMana ~= nil and math.abs(e.amount - e.maxMana * 0.03) < 1
end

-- Water Shield's rules. The mana ones replay at no cooldown, since the game
-- gives the mana only when it spends a charge, its own cooldown applied.
local WATER_RULES = {
    { name = "wound",       counts = IsWound },
    { name = "mana",        counts = function(e) return e.action == "ENERGIZE" end, icd = 0 },
    { name = "mana 3%",     counts = IsShieldMana, icd = 0 },
    { name = "aura",        aura = true },
}

--- The charges read after a fight, or nil when neither reading answered.
local function Observed(record)
    for _, field in ipairs({ "after", "afterLate" }) do
        local r = record[field]
        if r and r.verdict == "ok" then return r.charges end
        if r and r.verdict == "none" then return 0 end
    end
    return nil
end

--- The most charges ever seen, which is what a recast gives.
local function FullCharges(fights)
    local full = 1
    for _, f in ipairs(fights) do
        local b = f.before and f.before.charges
        if b and b > full then full = b end
    end
    return full
end

--- How many judged fights a rule gets right at one cooldown.
local function Fits(fights, rule, icd, full)
    local right, judged = 0, 0
    for _, f in ipairs(fights) do
        local observed = Observed(f)
        if observed ~= nil then
            judged = judged + 1
            if Predict(f, rule, icd, full) == observed then right = right + 1 end
        end
    end
    return right, judged
end

--- The cooldowns at which a rule fits every judged fight, as "3.20-3.60".
--
-- Several stretches are possible in principle and are all listed. When no
-- cooldown fits everything, the best one is named with its score instead.
local function CooldownRange(fights, rule, full)
    local spans, from, prev = {}, nil, nil
    local best, bestAt, judged = -1, 0, 0
    for step = 0, math.floor(SCAN_TO / SCAN_STEP + 0.5) do
        local icd = step * SCAN_STEP
        local right, n = Fits(fights, rule, icd, full)
        judged = n
        if right > best then best, bestAt = right, icd end
        if right == n and n > 0 then
            from = from or icd
            prev = icd
        elseif from then
            spans[#spans + 1] = string.format("%.2f-%.2f", from, prev)
            from = nil
        end
    end
    if from then spans[#spans + 1] = string.format("%.2f-%.2f", from, prev) end
    if #spans > 0 then return "fits all at " .. table.concat(spans, ", ") .. " s" end
    return string.format("fits nothing; best %d/%d at %.2f s", best, judged, bestAt)
end

--- A hit's kind for the tally: its action, and whether it was physical.
local function HitKind(e)
    local school = e.school == 1 and "physical" or ("school " .. tostring(e.school))
    return tostring(e.action) .. " " .. school
end

--- Every hit by kind that could have spent a charge, that is while the wound
--- rule says the shield still had one and was off its cooldown, and how many
--- of those had an aura signal just before them.
local function HitTally(fights, full)
    local tally, order = {}, {}
    for _, f in ipairs(fights) do
        local charges = f.before and f.before.charges or 0
        local last = -math.huge
        for i, e in ipairs(f.events) do
            if e.kind == "cast" then
                charges = full
            elseif e.kind == "combat" and IsAnyHit(e)
                   and charges > 0 and e.t - last >= P.icd then
                local key = HitKind(e)
                local row = tally[key]
                if not row then
                    row = { open = 0, signalled = 0 }
                    tally[key] = row
                    order[#order + 1] = key
                end
                row.open = row.open + 1
                for j = i - 1, 1, -1 do
                    local p = f.events[j]
                    if e.t - p.t > AURA_LEAD then break end
                    if p.kind == "aura" and not AtCast(f, p.t) then
                        row.signalled = row.signalled + 1
                        break
                    end
                end
                if IsWound(e) then charges, last = charges - 1, e.t end
            end
        end
    end
    table.sort(order)
    return tally, order
end

local function Say(fmt, ...)
    DEFAULT_CHAT_FRAME:AddMessage("  |cffffffff" .. string.format(fmt, ...) .. "|r")
end

local function Quiet(fmt, ...)
    DEFAULT_CHAT_FRAME:AddMessage("     |cff888888" .. string.format(fmt, ...) .. "|r")
end

--- In how many judged fights two rules disagree, and how often each was right.
local function Decided(fights, a, b, full)
    local count, forA, forB = 0, 0, 0
    for _, f in ipairs(fights) do
        local observed = Observed(f)
        local pa, pb = Predict(f, a, P.icd, full), Predict(f, b, P.icd, full)
        if observed ~= nil and pa ~= pb then
            count = count + 1
            if pa == observed then forA = forA + 1 end
            if pb == observed then forB = forB + 1 end
        end
    end
    return count, forA, forB
end

--- What Water Shield's fights say: each fight's mana gains with their share of
--- the maximum, the crits seen elsewhere, and the rules' predictions.
local function WaterReport()
    local store = FP.global and FP.global[WATER_KEY]
    local fights = type(store) == "table" and store.fights or {}
    if #fights == 0 then
        return FP:Warn("no fight with Water Shield recorded yet. Put it on and "
            .. "fight something.")
    end
    local full = FullCharges(fights)
    local first = math.max(1, #fights - 5)
    FP:Print("Water Shield probe, %d fights, the last %d: before -> after, "
        .. "then each rule's prediction.", #fights, #fights - first + 1)
    for i = first, #fights do
        local f = fights[i]
        local wounds, crits, spells, mana, text = 0, 0, 0, {}, {}
        for _, e in ipairs(f.events) do
            if e.kind == "combat" and e.action == "WOUND" then
                wounds = wounds + 1
            elseif e.kind == "combat" and e.action == "ENERGIZE" then
                mana[#mana + 1] = string.format("%.1fs %s of %s", e.t,
                    tostring(e.amount), tostring(e.maxMana))
            elseif e.kind == "text" then
                text[#text + 1] = string.format("%.1fs %s %s", e.t,
                    tostring(e.type), tostring(e.amount or "secret"))
            elseif e.kind == "crit" then
                crits = crits + 1
            elseif e.kind == "spell" then
                spells = spells + 1
            end
        end
        local observed = Observed(f)
        local parts = {}
        for _, rule in ipairs(WATER_RULES) do
            local predicted = Predict(f, rule, P.icd, full)
            parts[#parts + 1] = string.format("%s %d%s", rule.name, predicted,
                observed == nil and "" or (predicted == observed and " ok" or " x"))
        end
        Say("%d. %s -> %s, %.0fs, %d wounds, %d own casts, %d crits elsewhere", i,
            tostring(f.before and f.before.charges or "?"), tostring(observed or "?"),
            f.length or 0, wounds, spells, crits)
        Quiet("mana: %s", #mana > 0 and table.concat(mana, ", ") or "none")
        if #text > 0 then Quiet("combat text: %s", table.concat(text, ", ")) end
        Quiet("%s", table.concat(parts, ", "))
    end
    FP:Print("All fights:")
    for _, rule in ipairs(WATER_RULES) do
        local right, judged = Fits(fights, rule, P.icd, full)
        Say("%s: %d/%d", rule.name, right, judged)
    end
    FP:Print("Every timestamp is in the file. |cff888888/fplus probe shield "
        .. "forget|r clears Lightning Shield's fights, |cff888888water forget|r "
        .. "Water Shield's.")
end

function P:Report(arg)
    arg = (arg or ""):lower()
    if arg == "water forget" then
        local n = FP.global and FP.global[WATER_KEY]
            and #(FP.global[WATER_KEY].fights or {}) or 0
        if FP.global then FP.global[WATER_KEY] = nil end
        return FP:Print("%d recorded fight%s cleared.", n, n == 1 and "" or "s")
    end
    if arg == "water" then
        if not COLLECTING then return FP:Warn("the shield probe is off in this build.") end
        return WaterReport()
    end
    if arg == "forget" then
        local n = FP.global and FP.global[storeKey]
            and #(FP.global[storeKey].fights or {}) or 0
        if FP.global then FP.global[storeKey] = nil end
        return FP:Print("%d recorded fight%s cleared.", n, n == 1 and "" or "s")
    end
    if not COLLECTING then return FP:Warn("the shield probe is off in this build.") end

    local store = FP.global and FP.global[storeKey]
    local fights = type(store) == "table" and store.fights or {}
    if #fights == 0 then
        if not self.running then
            return FP:Warn("the shield probe only records on a Shaman or a "
                .. "priest with Inner Fire.")
        end
        return FP:Warn("no fight with a shield recorded yet. Put Lightning Shield "
            .. "or Inner Fire on and fight something.")
    end
    local full = FullCharges(fights)

    -- What the aura reported about itself, for Touch of Weakness above all.
    for _, look in pairs(type(store.looks) == "table" and store.looks or {}) do
        FP:Print("Aura %s: stack %s, duration %s s", tostring(look.spell),
            tostring(look.applications), tostring(look.duration))
    end

    -- The last few fights one by one, the rest only in the totals.
    local first = math.max(1, #fights - 5)
    FP:Print("Shield probe, %d fights, the last %d: before -> after, then each "
        .. "rule's prediction at %.1f s.", #fights, #fights - first + 1, P.icd)
    for i = first, #fights do
        local f = fights[i]
        local wounds, others, auras, casts = 0, 0, 0, 0
        for _, e in ipairs(f.events) do
            if e.kind == "combat" then
                if e.action == "WOUND" then wounds = wounds + 1
                elseif IsAnyHit(e) then others = others + 1 end
            elseif e.kind == "aura" then auras = auras + 1
            elseif e.kind == "cast" then casts = casts + 1 end
        end
        local observed = Observed(f)
        local parts = {}
        for _, rule in ipairs(RULES) do
            local predicted = Predict(f, rule, P.icd, full)
            parts[#parts + 1] = string.format("%s %d%s", rule.name, predicted,
                observed == nil and "" or (predicted == observed and " ok" or " x"))
        end
        Say("%d. %s -> %s, %.0fs, %d wounds, %d other, %d aura, %d cast", i,
            tostring(f.before and f.before.charges or "?"), tostring(observed or "?"),
            f.length or 0, wounds, others, auras, casts)
        Quiet("%s", table.concat(parts, ", "))
    end

    -- The totals, and for the hit rules the cooldowns that fit everything.
    FP:Print("All fights:")
    for _, rule in ipairs(RULES) do
        local right, judged = Fits(fights, rule, P.icd, full)
        if rule.aura then
            Say("%s: %d/%d", rule.name, right, judged)
        else
            Say("%s: %d/%d at %.1f s, %s", rule.name, right, judged, P.icd,
                CooldownRange(fights, rule, full))
        end
    end

    -- Only a fight where two rules disagree says anything about the difference
    -- between them.
    local wound, physical, any = RULES[1], RULES[2], RULES[3]
    local n, a, b = Decided(fights, wound, any, full)
    Say("misses and dodges decided in %d fight%s: they do not spend %d, they spend %d",
        n, n == 1 and "" or "s", a, b)
    n, a, b = Decided(fights, physical, wound, full)
    Say("spell hits decided in %d fight%s: they do not spend %d, they spend %d",
        n, n == 1 and "" or "s", a, b)
    n, a, b = Decided(fights, RULES[4], physical, full)
    Say("absorbed hits decided in %d fight%s: they do not spend %d, they spend %d",
        n, n == 1 and "" or "s", a, b)

    local tally, order = HitTally(fights, full)
    local rows = {}
    for _, key in ipairs(order) do
        local row = tally[key]
        rows[#rows + 1] = string.format("%s %d/%d", key, row.signalled, row.open)
    end
    Say("hits that could spend, with an aura signal just before:")
    Quiet("%s", table.concat(rows, ", "))

    if next(store.errors or {}) then
        FP:Warn("the probe itself failed somewhere; the file says where.")
    end
    FP:Print("Every timestamp is in the file. |cff888888/fplus probe shield forget|r clears it.")
end
