-- Shadowflare: alerts shown by the game itself (0.16.0).
--
-- In combat Forever hides the player's buffs from addons, so most procs are found through
-- the spells they change (cast time, cost). Blizzard's "aura container" lets an addon hand
-- the game a frame to show while a given buff is on the player, even in combat: the game
-- shows it and hides it, with the right number of stacks and the real time left. The
-- addon never learns when (checked in game by Ben, 16 October 2026), so:
--   - the picture comes from the game (always right),
--   - the sound still comes from Shadowflare's own detection (Core.lua), unchanged,
--   - only looping animations play (breathing, classic pulse); the others hold still.
--
-- 0.23.20 (Ben: having to see a buff out of combat first looked like a broken alert, and
-- players would only report "it's bugged"):
--   - "aura" procs (only the game can show them) and procs marked "preset" (numbers seen
--     working in Forever) get the game's frame from the first login, with every number
--     given. A stacking one starts with its stacks.
--   - the others still switch once their buff has been seen out of combat, but one
--     sighting is enough, at any number of stacks.
--   - what is seen out of combat still counts (a new number, a buff that turns out not to
--     count its stacks): the game's frames follow at once, no /reload needed.
-- What is learned is kept for the whole account (ShadowflareDB.buffs).
--
-- Each proc in ns.PROCS may give:
--   buffIds      : buff numbers to look for (from the game's data, unchecked in Forever)
--   nameFromSpell: the buff may also be found by the name of the proc's own spell
--   nameFromLabel: ... or by the proc's name in Shadowflare (when no number is known)
--   stacks       : its most stacks (or charges)
--   stacksOptional: the buff may not count its charges (Fingers of Frost): one frame for
--                  any count if it is seen without a count
--   preset       : its numbers are trusted: shown by the game from the first login (0.23.20)
--   noDim        : the same brightness at every count (Fingers of Frost, decided by Ben)
--
-- How the game's stack filter works (Forever's own code, Blizzard_CustomAuraButton.lua):
-- a frame with minApplications = n shows at n stacks OR MORE, never "exactly n". So the
-- frames of a stacking proc pile up (0.18.2): the lowest one switched on (the player's
-- "Show from") carries the number of stacks (written by the game), the time left and the
-- whole look at the brightness of that count; each frame above only adds brightness, so
-- the pile looks like the brightness of the current count. The game hides every frame
-- when the buff goes.
--
-- /flare gameshow turns it off (and on again) for the account; /flare buffs lists the
-- buffs on the player, with their numbers, out of combat.
local _, ns = ...
local L = ns.L

local AS = {}
ns.AuraShow = AS

local GetTime, pcall, type, pairs, ipairs = GetTime, pcall, type, pairs, ipairs
local max = math.max

local container, broken = nil, false
local slots = {}        -- per proc key: { p, skey, id, button, built, content, edges, cd, styles, s }
local subs = {}         -- per proc key: the frames below the maximum, by stack count (0.18.0)
local failed = {}       -- procs whose slot could not be made this session
local spare = {}        -- per proc key: frames below the maximum, switched off (the buff
                        -- turned out not to count its stacks; the game can't remove a frame)
AS.slots, AS.subs, AS.spare = slots, subs, spare

-- Every game frame of a proc: the one at its maximum, then the ones below
local function Each(key, fn)
    local main = slots[key]
    if main then fn(main) end
    local l = subs[key]
    if l then for _, slot in pairs(l) do fn(slot) end end
end

local function InCombat()
    if InCombatLockdown then
        local ok, v = pcall(InCombatLockdown)
        if ok and v then return true end
    end
    return ns.state and ns.state.inCombat or false
end
-- "Only in combat" (0.22.0): 0 out of combat for a proc with the setting, else 1.
-- Held (0.23.5): 0 while Shadowflare holds the frame back (Victory Rush on cooldown: its buff
-- stays, but it can't be cast).
local function Gate(cfg, slot)
    if slot and slot.held then return 0 end
    if cfg.onlyCombat and not InCombat() then return 0 end
    return 1
end

local function Saved()
    local d = ns.db.buffs
    if type(d) ~= "table" then d = {}; ns.db.buffs = d end
    return d
end

local function Off() return not ns.db or ns.db.noGameShow end



-- Diagnosis (0.23.6): what went wrong with the game's frames, kept for /flare gstest and
-- printed at once with /flare debug. Before, these errors were dropped without a word.
AS.errors = {}
local function Note(where, err)
    local t = AS.errors
    t[#t + 1] = ("%s: %s"):format(where, tostring(err))
    if #t > 12 then table.remove(t, 1) end
    if ns.debug then ns.Print("|cffff4040game frame|r " .. where .. ": " .. tostring(err)) end
end
local function Try(where, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then Note(where, err) end
    return ok, err
end

-- Whether a proc can use it at all
local function Eligible(p)
    return p.buffIds ~= nil or p.nameFromSpell or p.nameFromLabel or p.buffNames ~= nil or p.enchantSpell ~= nil
end

local function Seen(p)
    local e = ns.db and type(ns.db.buffs) == "table" and ns.db.buffs[p.key]
    if type(e) == "table" then return e end
end

-- Shown by the game from the first login, without its buff seen first (0.23.20)
local function Preset(p)
    if type(p.buffIds) ~= "table" or #p.buffIds == 0 then return false end
    return p.mode == "aura" or p.preset == true
end
AS.Preset = Preset

-- The game can show it: its numbers are trusted, or its buff has been seen out of combat.
-- A stacking proc with its own detection whose buff turned out not to count its stacks
-- stays with Shadowflare's own alert (one frame at any count would show too early).
local function Ready(p)
    local e = Seen(p)
    local known = e and type(e.id) == "number"
    if not known and not Preset(p) then return false end
    if p.stacks and not p.stacksOptional and not Preset(p) and e and e.flat then return false end
    return true
end
AS.Ready = Ready

-- Whether the game's frames of a proc follow its stacks: yes, unless its buff has been
-- seen without a count (0.23.20; before, only once 2 stacks had been seen)
local function Stacking(p)
    if not p.stacks then return false end
    local e = Seen(p)
    return not (e and e.flat)
end
AS.Stacking = Stacking

-- The buff numbers the game's frames answer to: the ones seen, and for a preset proc or a
-- proc with two buffs, every number given (a wrong number does nothing)
local function Ids(p)
    local ids, e = {}, Seen(p)
    if e and type(e.id) == "number" then ids[e.id] = true end
    if p.multiBuff and e and type(e.ids) == "table" then
        for sid in pairs(e.ids) do if type(sid) == "number" then ids[sid] = true end end
    end
    if p.multiBuff or Preset(p) then
        for _, sid in ipairs(p.buffIds or {}) do ids[sid] = true end
    end
    return ids
end

local function SameIds(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k in pairs(a) do if not b[k] then return false end end
    for k in pairs(b) do if not a[k] then return false end end
    return true
end

-- The stack count a frame stands for: its own, the most for the main frame, none if not stacking
local function SlotN(slot)
    if slot.n then return slot.n end
    if slot.stacking then return slot.p.stacks end
end

-- The number of stacks written by the game itself, as a plain whole number
local countFmt
local function CountFormatter()
    if countFmt == nil then
        countFmt = false
        local ok, f = pcall(function()
            local f = C_StringUtil.CreateNumericRuleFormatter()
            f:SetBreakpoints({ { threshold = 0, step = 1, rounding = Enum.NumericRuleFormatRounding.Down, format = "%.0f" } })
            return f
        end)
        if ok and f then countFmt = f end
    end
    return countFmt or nil
end

-- The real length of the buff, once seen (seconds), for the time shown by the old way
-- 0.23.26: only for a proc that follows a buff (Cutthroat's old 10 s stayed on Ghostly Strike)
function AS.Dur(key)
    local p = ns.PROC_BY[key]
    if not p or not Eligible(p) then return nil end
    local e = ns.db and type(ns.db.buffs) == "table" and ns.db.buffs[key]
    if type(e) == "table" and type(e.dur) == "number" and e.dur > 0 then return e.dur end
end

-- Whether the game shows this proc's alert (then Shadowflare's own one stays for tests
-- and placing only)
function AS.Owns(key)
    if Off() or broken then return false end
    local slot = slots[key]
    return slot ~= nil and slot.skey ~= nil
end

----------------------------------------------------------------------
-- Learning the buff numbers, out of combat only
----------------------------------------------------------------------
local cand = {}         -- per proc: { ids = {}, names = {} }
local function Candidates(p)
    local c = cand[p.key]
    if c then return c end
    c = { ids = {}, names = {} }
    for _, id in ipairs(p.buffIds or {}) do
        c.ids[id] = true
        local n = ns.SpellName(id)
        if n then c.names[n] = true end
    end
    if p.nameFromSpell and p.spell then
        local n = ns.SpellName(p.spell)
        if n then c.names[n] = true end
    end
    if p.nameFromLabel then
        local n = L["P_" .. p.key]
        if n then c.names[n] = true end
    end
    for _, n in ipairs(p.buffNames or {}) do c.names[n] = true end   -- names given as they are
    -- An enchant (0.20.0): its buff has the enchant's name without "Enchant Weapon - "
    if p.enchantSpell then
        local n = ns.GearName(p)
        if n then c.names[n] = true end
    end
    -- Kept once the names are known (the game may not have them loaded at the very start)
    if next(c.names) then cand[p.key] = c end
    return c
end

local function Learn(p, sid, apps, dur, icon)
    local d = Saved()
    local e = d[p.key]
    if type(e) ~= "table" then e = {}; d[p.key] = e end
    local was = Ready(p)
    -- A proc with two buffs (Deadly Aspects): every one seen is kept, the first stays the main one
    if p.multiBuff then
        if type(e.ids) ~= "table" then e.ids = {} end
        e.ids[sid] = true
        if not e.id then e.id = sid end
    end
    if e.id ~= sid and not p.multiBuff then e.id, e.apps, e.flat = sid, nil, nil end
    if apps then
        if apps > (e.apps or -1) then e.apps = apps end
        -- Seen without a count: the buff doesn't count its stacks (0.23.20)
        if p.stacks then e.flat = (apps == 0) or nil end
    end
    e.dur = dur
    -- Weapons and enchants show their buff's own icon (0.20.0)
    if p.gear and icon and e.icon ~= icon then
        e.icon = icon
        if ns.UpdateInfo then ns.UpdateInfo() end
    end
    if slots[p.key] then
        AS.Update(p)   -- a new number, or the stacks: the game's frames follow at once
    elseif Ready(p) then
        AS.Setup(p)
        if slots[p.key] and not was then ns.Print(L.GS_LEARNED:format(ns.Info(p.key).name, sid)) end
    end
end

local GetByIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
local function ReadOne(i)
    return GetByIndex("player", i, "HELPFUL")
end

-- A proc with two buffs (Deadly Aspects): every one seen, so no need to look any more (0.20.1)
local function AllSeen(p)
    local e = ns.db and type(ns.db.buffs) == "table" and ns.db.buffs[p.key]
    if type(e) ~= "table" or type(e.ids) ~= "table" then return false end
    local n = 0
    for _ in pairs(e.ids) do n = n + 1 end
    return n >= #(p.buffNames or {}) and n >= 2
end

-- One look at the player's buffs. A proc's buff lasts a few seconds (not a long buff
-- such as a 30 minute self-buff, nor a talent's hidden passive with no end).
function AS.Scan()
    if Off() or not GetByIndex or not ns.playerClass or InCombat() then return end
    local want
    for _, p in ipairs(ns.PROCS) do
        local e = Seen(p)
        -- 0.23.28: an alert switched off is not looked for (no frame for it: see AS.Setup)
        if ns.Mine(p) and Eligible(p) and not failed[p.key] and ns.Cfg(p.key).enabled
            and (not Ready(p) or not slots[p.key] or not (e and type(e.id) == "number")
                or (p.stacks and not (type(e.apps) == "number" and e.apps >= 1))
                or (p.multiBuff and not AllSeen(p))) then
            want = want or {}
            want[#want + 1] = p
        end
    end
    if not want then return end
    -- Learned already, slot not made yet (left combat, or just logged in)
    for _, p in ipairs(want) do
        if Ready(p) and not slots[p.key] then AS.Setup(p) end
    end
    for i = 1, 40 do
        local ok, a = pcall(ReadOne, i)
        if not ok or type(a) ~= "table" then break end
        local sid, name = ns.num(a.spellId), ns.str(a.name)
        local dur, apps = ns.num(a.duration), ns.num(a.applications)
        if sid then
            for _, p in ipairs(want) do
                -- A few seconds to a minute; longer, or no end at all, only where the proc allows it
                -- (Reckoning's stored attacks have no end; Revelation's length is unknown)
                local fits = (dur and dur > 0 and dur >= (p.minDur or 0) and dur <= (p.maxDur or 60)) or (p.noEnd and (not dur or dur == 0))
                if fits then
                    local c = Candidates(p)
                    if c.ids[sid] or (name and c.names[name]) then Learn(p, sid, apps, dur or 0, ns.clean(a.icon)) end
                end
            end
        end
    end
end

-- Buff changes come in bursts: one look a moment after the last one
local scanQueued = false
function AS.QueueScan()
    if scanQueued or Off() then return end
    scanQueued = true
    C_Timer.After(0.25, function()
        scanQueued = false
        pcall(AS.Scan)
    end)
end

----------------------------------------------------------------------
-- The game's frame for each proc
----------------------------------------------------------------------
local function Container()
    if container or broken then return container end
    local load = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
    if load then pcall(load, "Blizzard_AuraContainer") end
    local ok, c = pcall(CreateFrame, "AuraContainer", "ShadowflareAuraContainer", UIParent, "CustomAuraContainerTemplate")
    if not ok or not c then
        broken = true
        Note("container", c)
        return nil
    end
    Try("container place", c.SetAllPoints, c, UIParent)
    Try("container strata", c.SetFrameStrata, c, "MEDIUM")
    Try("container unit", c.SetUnit, c, "player")
    Try("container on", c.SetEnabled, c, true)
    container = c
    return c
end

local ART = "Interface\\AddOns\\Shadowflare\\Art\\"

-- The time left drawn by the game, rounded down like the game's buff timer and like
-- Shadowflare's own alerts (0.18.1): whole seconds from 3 s, tenths below. Uses the game's
-- number formatter (Forever API: C_StringUtil.CreateNumericRuleFormatter and
-- Cooldown:SetCountdownFormatter). If the client lacks it, the game's default stays.
local roundDown   -- the formatter, false when the client can't make one
local function RoundDownFormatter()
    if roundDown == nil then
        roundDown = false
        local ok, f = pcall(function()
            local R = Enum.NumericRuleFormatRounding
            local f = C_StringUtil.CreateNumericRuleFormatter()
            f:SetBreakpoints({
                { threshold = 0, step = 0.1, rounding = R.Down, format = "%.1f" },
                { threshold = 3, step = 1, rounding = R.Down, format = "%.0f" },
            })
            return f
        end)
        if ok and f then roundDown = f end
    end
    return roundDown or nil
end

-- Shown by the game from this frame's number of stacks (any number when not stacking).
-- The frame for 1 stack shows with the buff whatever count it gives (0.23.20): the same for
-- a buff that counts, and still shown if it doesn't.
local function SetBar(slot, b)
    local bar, p = b.bar, slot.p
    local mn, mx = 0, 1
    if slot.stacking then
        mn = SlotN(slot)
        mx = p.stacks
        if mn <= 1 then mn = 0 end
        if bar.SetFillStyle and Enum and Enum.StatusBarFillStyle and Enum.StatusBarFillStyle.StandardNoRangeFill then
            bar:SetFillStyle(Enum.StatusBarFillStyle.StandardNoRangeFill)
        end
    end
    b:SetApplicationBar(bar, { minApplications = mn, maxApplications = mx })
end

-- The number of stacks: written by the game itself (it changes with the stacks), shown
-- with the frame. If the client can't, this frame's own number stands in.
local function MakeCount(slot, b, content)
    if slot.num or not slot.stacking then return end
    local nf = CreateFrame("Frame", nil, b.bar)
    nf:SetSize(60, 44)
    pcall(nf.SetFrameLevel, nf, content:GetFrameLevel() + 22)
    local fs = nf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("CENTER")
    pcall(fs.SetFont, fs, (GameFontNormal:GetFont()), 24, "OUTLINE")
    fs:SetText(tostring(SlotN(slot)))
    nf.text = fs
    slot.num = nf
    if b.SetApplicationCount then
        local okN, errN = pcall(b.SetApplicationCount, b, fs, { formatter = CountFormatter() })
        slot.gameCount = okN
        if not okN and ns.debug then ns.Print("stack count " .. slot.key .. ": " .. tostring(errN)) end
    end
end

-- What Shadowflare draws inside the game's frame: the alert, the screen edges, the time left
local function Build(slot, b)
    if slot.built and slot.button == b then return end
    local bar = b.bar
    if not bar then
        Note("build " .. slot.key, "the game's frame has no part \"bar\" (Shadowflare's template not applied)")
        return
    end
    slot.button = b
    pcall(b.EnableMouse, b, false)
    if type(b.GetIcon) == "function" then
        local ok, icon = pcall(b.GetIcon, b)
        if ok and icon and icon.Hide then pcall(icon.Hide, icon) end
    end
    local okApp, errApp = pcall(SetBar, slot, b)
    if not okApp then
        if ns.debug then ns.Print("stacks filter " .. slot.key .. ": " .. tostring(errApp)) end
        if slot.n then
            -- A frame below the maximum: only this stack count goes without
            slot.dead = true
            if slot.skey and container and container.SetAuraSlotEnabled then pcall(container.SetAuraSlotEnabled, container, slot.skey, false) end
            return
        end
        if slot.stacking then
            -- Without the stacks filter it would show from the first stack: the proc goes
            -- back to Shadowflare's own alert for this session
            AS.Drop(slot.key)
            return
        end
        bar:Show()   -- the game still shows and hides the whole frame with the buff
    end
    local content = CreateFrame("Frame", nil, bar)
    content:SetSize(260, 220)
    content:SetPoint("CENTER", b, "CENTER", 0, 0)
    slot.content = content
    -- Entry animations (0.19.0): the game plays them itself when it shows the frame
    -- (AddAuraShownAnimation, Forever's Blizzard_CustomAuraButton.lua). They move their own
    -- frame (the game locks it once handed over), so the styles sit inside it.
    local holder = CreateFrame("Frame", nil, content)
    holder:SetAllPoints(content)
    slot.holder = holder
    slot.entry = {}
    -- The white-hot flare of Impact and Flash: a light copy of the style (made in ApplySlot),
    -- in a frame that is see-through except while its animation plays
    local hotFrame = CreateFrame("Frame", nil, holder)
    hotFrame:SetAllPoints(holder)
    pcall(hotFrame.SetFrameLevel, hotFrame, holder:GetFrameLevel() + 20)
    hotFrame:SetAlpha(0)
    slot.hotFrame = hotFrame
    -- The ways in (0.23.0), the same as Shadowflare's own alert (Display.lua, D.Enter)
    local function scale(ag, from, to, dur, order, smooth)
        local sc = ag:CreateAnimation("Scale")
        if not sc.SetScaleFrom then return false end
        sc:SetScaleFrom(from, from); sc:SetScaleTo(to, to)
        sc:SetDuration(dur); sc:SetOrder(order)
        if smooth and sc.SetSmoothing then sc:SetSmoothing(smooth) end
        return true
    end
    local function alpha(ag, from, to, dur, order, smooth)
        local a = ag:CreateAnimation("Alpha")
        a:SetFromAlpha(from); a:SetToAlpha(to); a:SetDuration(dur); a:SetOrder(order)
        if smooth and a.SetSmoothing then a:SetSmoothing(smooth) end
    end
    local STEPS = { 0.07, 0.06, 0.07, 0.06, 0.07, 0.06 }   -- Flash: on, off, on, off, on, off
    pcall(function()   -- Breathing: fades in from 92%
        local ag = holder:CreateAnimationGroup()
        scale(ag, 0.92, 1, 0.25, 1, "OUT")
        alpha(ag, 0, 1, 0.25, 1, "OUT")
        slot.entry.breath = { ag }
    end)
    pcall(function()   -- Classic pulse: pops from 60% with a small bounce
        local ag = holder:CreateAnimationGroup()
        if scale(ag, 0.6, 1.04, 0.2, 1, "OUT") then scale(ag, 1.04, 1, 0.1, 2, "OUT") end
        alpha(ag, 0, 1, 0.12, 1)
        slot.entry.classic = { ag }
    end)
    pcall(function()   -- Impact: lands from 150% with a white-hot flare
        local ag = holder:CreateAnimationGroup()
        if not scale(ag, 1.5, 0.94, 0.11, 1, "IN") then
            local sc = ag:CreateAnimation("Scale"); sc:SetScale(1 / 1.5, 1 / 1.5); sc:SetDuration(0.16); sc:SetOrder(1)
        else
            scale(ag, 0.94, 1, 0.09, 2, "OUT")
        end
        local hg = hotFrame:CreateAnimationGroup()
        alpha(hg, 0.9, 0, 0.22, 1)
        slot.entry.impact = { ag, hg }
        slot.entry.impactpulse = slot.entry.impact   -- same way in, then it swells (0.23.2)
    end)
    pcall(function()   -- Flash: three hard flashes
        local ag = holder:CreateAnimationGroup()
        local hg = hotFrame:CreateAnimationGroup()
        for i, d in ipairs(STEPS) do
            local on = i % 2 == 1
            alpha(ag, on and 1 or 0.08, on and 1 or 0.08, d, i)
            alpha(hg, on and 0.5 or 0, on and 0.5 or 0, d, i)
        end
        slot.entry.flash = { ag, hg }
    end)
    -- (0.23.0 watched this frame's OnHide to play the way out when the game took the frame
    -- away. Forever refuses it, "blocked by secret aspects", and that stopped the whole frame
    -- from being built: nothing showed. Removed in 0.23.7: the game's frames go at once.)
    -- The glow on the screen edges
    local e = CreateFrame("Frame", nil, bar)
    e:SetAllPoints(UIParent)
    pcall(e.SetFrameStrata, e, "BACKGROUND")
    local el = e:CreateTexture(nil, "ARTWORK")
    el:SetTexture(ART .. "edge"); el:SetBlendMode("ADD")
    el:SetPoint("TOPLEFT", UIParent, "TOPLEFT"); el:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT"); el:SetWidth(170)
    local er = e:CreateTexture(nil, "ARTWORK")
    er:SetTexture(ART .. "edge"); er:SetBlendMode("ADD"); er:SetTexCoord(1, 0, 0, 1)
    er:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT"); er:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT"); er:SetWidth(170)
    e.l, e.r = el, er
    e:Hide()
    slot.edges = e
    -- The time left, counted by the game itself (numbers only, no swipe)
    local okC, cd = pcall(CreateFrame, "Cooldown", nil, bar, "CooldownFrameTemplate")
    if okC and cd then
        pcall(cd.SetDrawSwipe, cd, false)
        pcall(cd.SetDrawEdge, cd, false)
        pcall(cd.SetDrawBling, cd, false)
        pcall(cd.SetHideCountdownNumbers, cd, true)
        pcall(cd.SetFrameLevel, cd, content:GetFrameLevel() + 20)
        -- Before handing it to the game (it may lock the frame afterwards)
        local fmt = RoundDownFormatter()
        if fmt and cd.SetCountdownFormatter then
            local okF, errF = pcall(cd.SetCountdownFormatter, cd, fmt)
            if not okF and ns.debug then ns.Print("time left format: " .. tostring(errF)) end
        end
        Try("time left " .. slot.key, b.SetDurationCooldown, b, cd)
        slot.cd = cd
        slot.handed = cd
    end
    -- 0.23.8: the time left placed apart, written by the game itself (SetDurationText), used
    -- when the style's own swipe takes the game's cooldown (see ApplySlot)
    local tf = CreateFrame("Frame", nil, bar)
    tf:SetSize(80, 40)
    pcall(tf.SetFrameLevel, tf, content:GetFrameLevel() + 21)
    local tfs = tf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tfs:SetPoint("CENTER")
    tf.text = tfs
    tf:Hide()
    slot.tf = tf
    MakeCount(slot, b, content)
    slot.styles = {}
    slot.built = true
    AS.Apply(slot.key)
end

-- Below the maximum (0.18.0): one frame per stack count. Out of combat only.
local function AddSubs(p, slot)
    if not (p.stacks and p.stacks > 1) or subs[p.key] then return end
    -- Frames made before and switched off since: used again (0.23.20)
    if spare[p.key] then
        subs[p.key], spare[p.key] = spare[p.key], nil
        return
    end
    local c = container
    local l = {}
    subs[p.key] = l
    for n = 1, p.stacks - 1 do
        local sub = { key = p.key, p = p, ids = slot.ids, skey = slot.skey .. "_" .. n, n = n, stacking = true }
        l[n] = sub
        local okS, resS = pcall(c.AddAuraSlot, c, sub.skey, "HELPFUL", {
            templateNames = { "ShadowflareAuraTemplate" },
            initializeFrame = function(b) Try("build " .. sub.skey, Build, sub, b) end,
            candidateFilters = { includeSpellIDs = slot.ids },
        })
        if not okS then
            l[n] = nil
            if ns.debug then ns.Print("aura container slot " .. sub.skey .. ": " .. tostring(resS)) end
        elseif type(resS) == "table" and not sub.built then
            Try("build " .. sub.skey, Build, sub, resS)
        end
    end
end

-- Makes the game's frame for a proc the game can show (see Ready). Out of combat only.
-- 0.23.28 (CurseForge, Clearcasting and Missile Barrage shown while switched off): an alert
-- switched off gets no frame; ticking it makes one (see ns.SetEnabled, and the scan after a fight)
function AS.Setup(p)
    if slots[p.key] or failed[p.key] or Off() or InCombat() or not Ready(p) then return end
    if not ns.Cfg(p.key).enabled then return end
    local c = Container()
    if not c or not c.AddAuraSlot then return end
    local ids = Ids(p)
    if not next(ids) then return end
    local skey = "shadowflare_" .. p.key
    local slot = { key = p.key, p = p, ids = ids, skey = skey, stacking = Stacking(p) }
    slots[p.key] = slot   -- before the call: the game may build the frame right away
    local ok, res = pcall(c.AddAuraSlot, c, skey, "HELPFUL", {
        templateNames = { "ShadowflareAuraTemplate" },
        initializeFrame = function(b) Try("build " .. slot.key, Build, slot, b) end,
        candidateFilters = { includeSpellIDs = ids },
    })
    if not ok then
        slots[p.key] = nil
        failed[p.key] = true
        Note("slot " .. p.key, res)
        return
    end
    slot.returned = type(res)
    if slots[p.key] == slot and type(res) == "table" and not slot.built then Try("build " .. p.key, Build, slot, res) end
    if slots[p.key] ~= slot then   -- given back (no stacks filter): the game's frame stays off
        if c.SetAuraSlotEnabled then pcall(c.SetAuraSlotEnabled, c, skey, false) end
        return
    end
    if slot.stacking then AddSubs(p, slot) end
    AS.Apply(p.key)
    AS.Run()
    if ns.Refresh then ns.Refresh() end   -- Shadowflare's own alert for it steps aside
end

-- At login (and after a loading screen): the frames of the procs the game can show
function AS.Init()
    if Off() or not ns.playerClass then return end
    for _, p in ipairs(ns.PROCS) do
        if ns.Mine(p) and Eligible(p) and Ready(p) then AS.Setup(p) end
    end
    AS.QueueScan()
end

-- 0.23.28: noted only once the game took it. Before, a call refused (or made while the game
-- was still setting the frame up) was noted all the same and never made again: a frame
-- switched off stayed on (Redoubt in October, Clearcasting and Missile Barrage in November).
-- Read back when the game says; asked again at the next check otherwise.
local function SetSlotOn(slot, on)
    if slot.onSet == on or not (container and container.SetAuraSlotEnabled) then return end
    local ok, err = pcall(container.SetAuraSlotEnabled, container, slot.skey, on)
    if ok and container.IsAuraSlotEnabled then
        local okR, now = pcall(container.IsAuraSlotEnabled, container, slot.skey)
        if okR and type(now) == "boolean" and now ~= on then ok, err = false, "still " .. tostring(now) end
    end
    if ok then
        slot.onSet, slot.onFails = on, nil
    else
        slot.onSet = nil
        slot.onFails = (slot.onFails or 0) + 1
        if slot.onFails == 1 or slot.onFails == 10 then Note("on/off " .. slot.skey, err) end
        if ns.WakeAt then ns.WakeAt(GetTime() + 0.5) end
    end
end

-- Whether a game frame should be on: the alert is on, and for a frame below the maximum,
-- its stack count is at least the player's "Show from"
local function WantOn(slot, cfg)
    if Off() or slot.dead or not cfg.enabled then return false end
    -- 0.23.7: "Only in combat" and Victory Rush's cooldown switch the game's frame off, as the
    -- frame itself can't be touched in a fight (Forever: "forbidden object")
    if Gate(cfg, slot) == 0 then return false end
    local n = SlotN(slot)
    if not n then return true end
    local from = ns.FromStacks(slot.key) or slot.p.stacks
    if n < from then return false end
    -- One frame, the same look at every count (Fingers of Frost), unless the player picked a
    -- look that changes with the stacks (fill or dots, 0.21.0)
    if slot.p.noDim and ns.Display.StackLook(slot.key) == "dim" then return n == from end
    return true
end

-- The lowest frame switched on: it carries the number, the time left and the edges
local function Lowest(slot)
    local n = SlotN(slot)
    return not n or n == (ns.FromStacks(slot.key) or slot.p.stacks)
end

-- How much this frame adds, so the pile shows the brightness of the current count:
-- the lowest frame alone gives T(from); with the frames up to n on, 1 - prod(1 - a) = T(n)
local function LayerAlpha(slot)
    local n = SlotN(slot)
    if not n or slot.p.noDim then return 1 end
    if ns.Display.StackLook(slot.key) ~= "dim" then return 1 end
    if ns.Display.NoArt(ns.Cfg(slot.key)) then return 1 end   -- 0.23.30: None, nothing to dim   -- fill and dots: each frame its own part
    local D, m = ns.Display, slot.p.stacks
    local T = D.StackK(n, m)
    if Lowest(slot) then return T end
    local below = D.StackK(n - 1, m)
    if below >= 1 then return 0 end
    return 1 - (1 - T) / (1 - below)
end
AS.LayerAlpha = LayerAlpha

-- Gives a proc back to Shadowflare's own alert for this session
function AS.Drop(key)
    local slot = slots[key]
    if not slot then return end
    if slot.skey then SetSlotOn(slot, false) end
    local l = subs[key]
    if l then for _, sub in pairs(l) do if sub.skey then SetSlotOn(sub, false) end end end
    subs[key] = nil
    slots[key] = nil
    failed[key] = true
    AS.Run()
    if ns.Refresh then C_Timer.After(0, ns.Refresh) end
end

-- "Show this alert" follows the option (cheap: called with every refresh)
function AS.SyncEnabled()
    for key, main in pairs(slots) do   -- runs with every refresh: no function made here
        local cfg = ns.Cfg(key)
        if main.skey then SetSlotOn(main, WantOn(main, cfg)) end
        local l = subs[key]
        if l then for _, slot in pairs(l) do if slot.skey then SetSlotOn(slot, WantOn(slot, cfg)) end end end
    end
end

-- What was seen out of combat changes the game's frames at once, no /reload (0.23.20):
-- a new buff number joins the ones they answer to; a buff that turns out not to count its
-- stacks (or to count them after all) changes the frames for the stacks. Out of combat only.
function AS.Update(p)
    local slot = slots[p.key]
    local c = container
    if not (slot and slot.skey and c) or Off() or InCombat() then return end
    local ids = Ids(p)
    if next(ids) and not SameIds(ids, slot.ids) then
        slot.ids = ids
        if c.SetAuraSlotCandidateFilters then
            local function set(s)
                s.ids = ids
                Try("numbers " .. s.skey, c.SetAuraSlotCandidateFilters, c, s.skey, { includeSpellIDs = ids })
            end
            set(slot)
            for _, l in ipairs({ subs[p.key] or {}, spare[p.key] or {} }) do
                for _, sub in pairs(l) do if sub.skey then set(sub) end end
            end
        else
            Note("numbers " .. p.key, "this client can't change a frame's buff numbers: /reload")
        end
    end
    local st = Stacking(p)
    if st ~= (slot.stacking or false) then
        slot.stacking = st
        if st then
            AddSubs(p, slot)
        else
            local l = subs[p.key]
            if l then
                for _, sub in pairs(l) do if sub.skey then SetSlotOn(sub, false) end end
                spare[p.key], subs[p.key] = l, nil
            end
        end
        if slot.built and slot.button then
            local ok = Try("stacks " .. p.key, SetBar, slot, slot.button)
            if ok and slot.content then Try("stacks " .. p.key, MakeCount, slot, slot.button, slot.content) end
        end
        AS.Apply(p.key)
        AS.Run()
    end
end

-- Puts the proc's look (style, color, size, place, edges, time left) into the game's frame
local function ApplySlot(slot, key, cfg)
    if slot.skey then SetSlotOn(slot, WantOn(slot, cfg)) end
    local b, D = slot.button, ns.Display
    if not (b and slot.built and D) then return end
    slot.pv, slot.ev = nil, nil   -- the loop sets the brightness again from these new settings
    Try("place " .. key, b.ClearAllPoints, b)
    Try("place " .. key, b.SetPoint, b, "CENTER", UIParent, "CENTER", cfg.x, cfg.y)
    Try("size " .. key, b.SetSize, b, 260 * cfg.scale, 220 * cfg.scale)
    local content = slot.content
    content:SetScale(cfg.scale)
    slot.k = nil
    local skey = D.EffectiveStyle(cfg)
    local s = slot.styles[skey]
    if not s then
        local f = CreateFrame("Frame", nil, slot.holder or content)
        f:SetAllPoints(content)
        s = D.Build(f, skey, ns.Info(key))
        slot.styles[skey] = s
    end
    for _, o in pairs(slot.styles) do o.frame:SetShown(o == s) end
    slot.s = s
    if s.Refresh then s.Refresh() end
    local r, g, bl = D.Color(cfg)
    s.SetColor(r, g, bl, cfg.tintClassic)
    D.Rotate(s, cfg.rotation, D.SpacingOf(cfg))
    D.ApplySides(s, cfg)
    D.ApplyFont(s, cfg.font)
    -- The game counts the time left: the style's own text stays empty
    if s.SetTime then s.SetTime("") elseif s.timer then s.timer:SetText("") end
    if s.OnAppear then pcall(s.OnAppear) end
    -- The way in of the player's animation, played by the game when it shows the frame
    -- 0.23.10 (Ben's choice): no way in handed to the game. The game plays it itself each time it
    -- rebuilds its frames (several times when a fight ends), and doesn't let an addon watch or
    -- stop it (0.23.9's guard never ran): the alert popped in and out. It now appears at once.
    local want = nil
    if want ~= slot.shownAnim then
        if slot.shownAnim and b.RemoveAuraShownAnimation then
            for _, ag in ipairs(slot.shownAnim) do pcall(b.RemoveAuraShownAnimation, b, ag) end
        end
        slot.shownAnim = nil
        if want and b.AddAuraShownAnimation then
            local okAll = true
            for _, ag in ipairs(want) do
                local okA, errA = pcall(b.AddAuraShownAnimation, b, ag)
                if not okA then okAll = false; if ns.debug then ns.Print("entry animation " .. key .. ": " .. tostring(errA)) end end
            end
            if okAll then slot.shownAnim = want end
        end
    end
    -- The light copy for the flare (Impact, Flash)
    if want and (cfg.anim == "impact" or cfg.anim == "impactpulse" or cfg.anim == "flash") and slot.hotFrame then
        local h = D.HotCopy(slot, slot.hotFrame, s, ns.Info(key))
        h.frame:SetAlpha(1)   -- the frame around it does the flaring
        slot.hot = h
    end
    -- Below the maximum: dimmer (0.18.0), built up frame by frame (see the top of this file)
    local lowest = Lowest(slot)
    slot.sk = LayerAlpha(slot)
    -- Fill or dots (0.21.0): the game shows the frames from "Show from" up to the current
    -- count, piled up. The lowest one carries the faint alert (fill) or the whole alert and
    -- every dot (dots), and its own part; each frame above adds only its own part.
    local look = slot.stacking and D.StackLook(key) or "dim"
    local n, m = SlotN(slot), slot.p.stacks
    local fill = (look == "fillup" or look == "fillleft") and n and m
    slot.copy, slot.cpv = nil, nil
    if fill then
        local lo, hi = lowest and 0 or (n - 1) / m, n / m
        if lowest and hi >= 1 then
            s.frame:SetAlpha(1)
            if slot.clip then slot.clip:Hide() end
        else
            s.frame:SetAlpha(lowest and D.FaintOf(cfg) or 0)
            local clip = D.Clip(slot, slot.holder or content, content:GetFrameLevel() + 6)
            slot.copy = D.FillCopy(slot, content, s, cfg, ns.Info(key))
            if slot.copy.SetTime then slot.copy.SetTime("") elseif slot.copy.timer then slot.copy.timer:SetText("") end
            D.PlaceClip(clip, content, s, look, lo, hi)
            clip:Show()
        end
    else
        s.frame:SetAlpha((look == "dots" and not lowest) and 0 or 1)
        if slot.clip then slot.clip:Hide() end
    end
    -- The sides picked for this alert (0.23.15; the "sides" look of Fingers of Frost is gone)
    D.ApplySides(s, cfg)
    if look == "dots" and n and m then
        local d = D.Dots(slot, slot.holder or content)
        pcall(d.SetFrameLevel, d, content:GetFrameLevel() + 40)
        if lowest then D.SetDots(d, content, s, m, 1, n, true, cfg) else D.SetDots(d, content, s, m, n, n, false, cfg) end
    elseif slot.dots then
        slot.dots:Hide()
    end
    slot.selfHide = true   -- hidden by Shadowflare, not by the game: no way out to play
    content:SetShown(not (cfg.edges and cfg.edgesOnly))
    slot.selfHide = false
    -- Only in combat and held back: the game's frame is switched off instead (see WantOn)
    local gate = 1
    slot.gate = Gate(cfg, slot)
    content:SetAlpha(cfg.alpha * slot.sk * gate)
    local e = slot.edges
    e.l:SetVertexColor(r, g, bl); e.r:SetVertexColor(r, g, bl)
    e:SetShown(cfg.edges and true or false)
    e:SetAlpha(cfg.alpha * 0.8 * slot.sk * gate)
    -- The number of stacks, where the player put it
    local nf = slot.num
    if nf then
        local size = cfg.stackSize or 24
        nf:ClearAllPoints()
        nf:SetPoint("CENTER", UIParent, "CENTER", cfg.x + (cfg.sox or 0), cfg.y + (cfg.soy or 55))
        nf:SetSize(max(40, size * 2), size * 2)
        pcall(D.SetFontSafe, nf.text, D.FontFile(cfg.font), size, "OUTLINE")
        nf.text:SetTextColor(D.Light(r, g, bl))
        nf:SetAlpha(cfg.alpha * gate)
        -- Only the lowest frame shows it; without the game's count it is that frame's own
        -- number, right only when nothing piles above it
        local from = ns.FromStacks(key) or slot.p.stacks
        local ok = slot.gameCount or from == slot.p.stacks
        if not slot.gameCount then nf.text:SetText(tostring(SlotN(slot))) end
        nf:SetShown((cfg.stackNum and lowest and ok and slot.stacking) and true or false)
    end
    -- Time left (0.23.8). A style with its own swipe (Ring, Icon) gets the game's cooldown:
    -- the game turns it with the buff's real time, and writes the numbers on it when they sit
    -- in the style. Placed apart, the numbers are written by the game in their own text. A
    -- style without a swipe: the numbers only, on Shadowflare's plain cooldown (as before).
    -- 0.23.32: the None style has its own choice (Style tab): its time sits on the alert
    local apart = D.TimeApart(cfg)
    local size
    if apart then
        size = cfg.timerSize
    elseif s.timer then
        local okF, _, fsz = pcall(s.timer.GetFont, s.timer)
        size = ((okF and type(fsz) == "number") and fsz or 20) * cfg.scale
    else
        size = 16 * cfg.scale
    end
    local showNum = D.TimeShown(cfg) and lowest and true or false
    local swipe = s.swipe
    local want = swipe or slot.cd
    if want and slot.handed ~= want then
        if want.SetCountdownFormatter then
            local fmt = RoundDownFormatter()
            if fmt then pcall(want.SetCountdownFormatter, want, fmt) end
        end
        local okH = Try("time left " .. key, b.SetDurationCooldown, b, want)
        if okH then
            if slot.handed and slot.handed ~= want then
                pcall(slot.handed.SetHideCountdownNumbers, slot.handed, true)
                pcall(slot.handed.SetAlpha, slot.handed, 0)
            end
            slot.handed = want
        end
    end
    local handed = slot.handed
    if handed then pcall(handed.SetAlpha, handed, 1) end
    if slot.cd and slot.cd ~= handed then   -- put aside: nothing of it shows
        pcall(slot.cd.SetHideCountdownNumbers, slot.cd, true)
        pcall(slot.cd.SetAlpha, slot.cd, 0)
    end
    -- numbers on the handed cooldown: on the swipe's middle (in the style), or Shadowflare's
    -- own cooldown placed where they go
    local onCd = showNum and not (handed == swipe and swipe and apart)
    if handed then pcall(handed.SetHideCountdownNumbers, handed, not onCd) end
    local cd = slot.cd
    if cd and handed == cd then
        cd:ClearAllPoints()
        if apart then
            cd:SetPoint("CENTER", UIParent, "CENTER", cfg.x + cfg.tox, cfg.y + cfg.toy)
        elseif s.timer then
            cd:SetPoint("CENTER", s.timer, "CENTER", 0, 0)
        else
            cd:SetPoint("CENTER", content, "CENTER", 0, -40 * cfg.scale)
        end
        cd:SetSize(apart and D.TimerBoxW(size) or max(40, size * 3), max(20, size * 2))
    end
    if handed and handed.GetCountdownFontString then
        local okS, fs = pcall(handed.GetCountdownFontString, handed)
        if okS and fs then
            pcall(D.SetFontSafe, fs, D.FontFile(cfg.font), size, "OUTLINE")
            pcall(fs.SetTextColor, fs, D.Light(r, g, bl))
            -- Shadowflare's own cooldown: its numbers aligned like the time placed apart (0.23.23)
            if handed == cd then pcall(D.AlignTimer, fs, cd, apart and cfg.timerAlign or "center") end
        end
    end
    -- apart, with a swipe in the style: the game's own duration text
    local tf = slot.tf
    if tf then
        local wantText = showNum and swipe ~= nil and handed == swipe and apart
        if wantText and not slot.textBound and b.SetDurationText then
            local fmt = RoundDownFormatter()
            local okT = Try("time text " .. key, b.SetDurationText, b, tf.text, fmt and { textFormatter = fmt } or nil)
            if not okT and fmt then okT = Try("time text " .. key, b.SetDurationText, b, tf.text) end
            slot.textBound = okT and true or false
        end
        if wantText and slot.textBound then
            tf:ClearAllPoints()
            tf:SetPoint("CENTER", UIParent, "CENTER", cfg.x + cfg.tox, cfg.y + cfg.toy)
            tf:SetSize(D.TimerBoxW(size), max(20, size * 2))
            pcall(D.SetFontSafe, tf.text, D.FontFile(cfg.font), size, "OUTLINE")
            pcall(D.AlignTimer, tf.text, tf, cfg.timerAlign)
            tf.text:SetTextColor(D.Light(r, g, bl))
            tf:Show()
        else
            tf:Hide()
        end
    end
end

-- In a fight the game's frames can't be touched: the look is put in place after it (0.23.7)
function AS.Apply(key)
    if not slots[key] then return end
    if InCombat() then AS.pending = true; AS.SyncEnabled(); return end
    local cfg = ns.Cfg(key)
    Each(key, function(slot) ApplySlot(slot, key, cfg) end)
    AS.Run()
end

-- Holds a proc's frames back, or lets them show again (0.23.5, Victory Rush's cooldown)
function AS.Hold(key, on)
    on = on and true or false
    local main = slots[key]
    if not main or (main.held or false) == on then return end
    Each(key, function(slot) slot.held = on end)
    AS.SyncEnabled()
end

function AS.ApplyAll()
    if InCombat() then AS.pending = true; AS.SyncEnabled(); return end
    AS.pending = nil
    for key in pairs(slots) do Try("apply " .. key, AS.Apply, key) end
end

----------------------------------------------------------------------
-- Looping animations. Shadowflare can't know when the game shows the alert, so the
-- moving parts move all the time, 30 times a second (a few textures per proc).
----------------------------------------------------------------------
local ticker
local TickSlot
function AS.Tick()
    local D = ns.Display
    if not D then return end
    local now = GetTime()
    -- No function is made here: this runs 30 times a second
    for key, main in pairs(slots) do
        local cfg = ns.Cfg(key)
        TickSlot(main, cfg, D, now)
        local l = subs[key]
        if l then for _, slot in pairs(l) do TickSlot(slot, cfg, D, now) end end
    end
end

TickSlot = function(slot, cfg, D, now)
    -- A frame switched off (proc turned off, or below "Show from"): the game never shows it,
    -- nothing to move (0.20.1)
    if slot.onSet == false then return end
    do
        local s = slot.s
        if s and slot.built then
            local p, k = 1, 1
            if cfg.anim == "breath" then
                p = D.AnimLook("breath", 0, now, nil)
            elseif cfg.anim == "classic" or cfg.anim == "impactpulse" then
                local _
                _, k = D.AnimLook("classic", now, now, nil)
            end
            if k ~= slot.k then slot.k = k; slot.content:SetScale(cfg.scale * k) end
            -- Brightness set only when it changes (Still, Impact, Flash: never after the first time)
            if s.pulse then
                local v = s.pA + s.pB * p
                if v ~= slot.pv then slot.pv = v; s.pulse:SetAlpha(v) end
            end
            if s.Animate then s.Animate(now, nil, p, nil) end
            local c = slot.copy   -- the color part of a filling alert moves with it (0.21.0)
            if c then
                if c.pulse then
                    local v = c.pA + c.pB * p
                    if v ~= slot.cpv then slot.cpv = v; c.pulse:SetAlpha(v) end
                end
                if c.Animate then c.Animate(now, nil, p, nil) end
            end
            if cfg.edges then
                local v = cfg.alpha * p * 0.8 * (slot.sk or 1) * (slot.gate or 1)
                if v ~= slot.ev then slot.ev = v; slot.edges:SetAlpha(v) end
            end
            if s.OnAppear and (not slot.loopAt or now - slot.loopAt > 1) then
                slot.loopAt = now
                pcall(s.OnAppear)
            end
        end
    end
end

-- The loop runs only in combat and for 20 s after (a proc's buff can outlast the fight):
-- nothing runs between fights (0.19.0, after a Reddit question about resources)
local AFTER_COMBAT = 20
local combatEndedAt
function AS.CombatChanged(inCombat)
    if not inCombat then
        combatEndedAt = GetTime()
        C_Timer.After(AFTER_COMBAT + 0.1, function() AS.Run() end)
    end
    AS.Run()
end
local function Window()
    if InCombat() then return true end
    return combatEndedAt ~= nil and GetTime() - combatEndedAt < AFTER_COMBAT
end

-- When the loop stops: every frame back to its resting look (full brightness, normal size)
local function Rest()
    for key, main in pairs(slots) do
        local cfg = ns.Cfg(key)
        local function one(slot)
            if not (slot.built and slot.s) then return end
            slot.k, slot.pv, slot.ev, slot.cpv = 1, nil, nil, nil
            slot.content:SetScale(cfg.scale)
            local s = slot.s
            if s.pulse then s.pulse:SetAlpha(s.pA + s.pB) end
            local c = slot.copy
            if c and c.pulse then c.pulse:SetAlpha(c.pA + c.pB) end
            if cfg.edges then slot.edges:SetAlpha(cfg.alpha * 0.8 * (slot.sk or 1) * (slot.gate or 1)) end
        end
        one(main)
        local l = subs[key]
        if l then for _, slot in pairs(l) do one(slot) end end
    end
end

-- 0.23.7: no looping animation in the game's frames any more. Forever doesn't let an addon
-- touch them in a fight (seen with /flare gstest), so the loop could only fail there. They keep
-- the way in the game plays itself, then their resting look.
function AS.Run()
    if ticker then ticker:Cancel(); ticker = nil end
    if not InCombat() then pcall(Rest) end
end
AS.Running = function() return ticker ~= nil end

-- /flare gameshow
function AS.Toggle()
    ns.db.noGameShow = not ns.db.noGameShow or nil
    AS.SyncEnabled()
    AS.Run()
    if not ns.db.noGameShow then AS.Init() end
    ns.Print(ns.db.noGameShow and L.GS_OFF or L.GS_ON)
    if ns.Refresh then ns.Refresh() end
end

-- /flare gstest (0.23.6, diagnosis): what Shadowflare knows about its frames in the game's
-- aura container, for each proc of this character that can be shown by the game
local function V(v)
    if v == nil then return "nil" end
    if issecretvalue then
        local ok, sec = pcall(issecretvalue, v)
        if ok and sec then return "secret" end
    end
    if type(v) == "number" then return (("%.2f"):format(v):gsub("%.?0+$", "")) end
    return tostring(v)
end
local function Ask(obj, method, ...)
    if not obj then return "no frame" end
    local f = obj[method]
    if type(f) ~= "function" then return "n/a" end
    local res = { pcall(f, obj, ...) }
    if not res[1] then return "error (" .. tostring(res[2]):sub(1, 60) .. ")" end
    local out = {}
    for i = 2, math.max(2, #res) do out[#out + 1] = V(res[i]) end
    return table.concat(out, " x ")
end
function AS.Report()
    local P = function(t) ns.Print("|cff80c0ffgstest|r " .. t) end
    P(("version %s - game frames %s - in combat %s - debug %s"):format(ns.version, Off() and "OFF (/flare gameshow)" or "on",
        V(InCombat()), V(ns.debug)))
    if broken then P("container: could not be made") elseif not container then P("container: not made yet")
    else
        P(("container: shown %s - visible %s - enabled %s - unit %s - size %s"):format(Ask(container, "IsShown"),
            Ask(container, "IsVisible"), Ask(container, "IsEnabled"), Ask(container, "GetUnit"), Ask(container, "GetSize")))
    end
    local any = false
    for _, p in ipairs(ns.PROCS) do
        if ns.Mine(p) and Eligible(p) then
            any = true
            local e = Saved()[p.key]
            local learned = type(e) == "table" and e.id and ("buff " .. V(e.id) .. ", " .. V(e.dur) .. " s, stacks seen " .. V(e.apps)) or "buff not seen yet"
            P(("|cffffd100%s|r: %s - preset %s - ready %s - stacks %s - failed %s"):format(p.key, learned, V(Preset(p)), V(Ready(p)),
                V(slots[p.key] and slots[p.key].stacking), V(failed[p.key])))
            Each(p.key, function(slot)
                local b = slot.button
                P(("  frame %s: given back %s - built %s - bar %s - content %s - on %s - held %s - gate %s - dead %s"):format(
                    slot.skey or "?", V(slot.returned), V(slot.built), V(b and b.bar ~= nil), V(slot.content ~= nil),
                    V(slot.onSet), V(slot.held), V(slot.gate), V(slot.dead)))
                P(("  timer on %s"):format(V(slot.handed and (slot.handed == (slot.s and slot.s.swipe) and "style swipe" or "plain"))))
                if container and slot.skey then
                    P(("  game: slot on %s - same frame %s"):format(Ask(container, "IsAuraSlotEnabled", slot.skey),
                        (function() local ok, f = pcall(container.GetAuraSlotFrame, container, slot.skey)
                            if not ok then return "error" end; return V(f ~= nil and f == b) end)()))
                end
                if b then
                    P(("  button: shown %s - visible %s - alpha %s - size %s - points %s - parent ok %s"):format(Ask(b, "IsShown"),
                        Ask(b, "IsVisible"), Ask(b, "GetAlpha"), Ask(b, "GetSize"), Ask(b, "GetNumPoints"),
                        V((pcall(b.GetParent, b)))))
                end
                if b and b.bar then
                    P(("  bar: shown %s - visible %s - value %s"):format(Ask(b.bar, "IsShown"), Ask(b.bar, "IsVisible"), Ask(b.bar, "GetValue")))
                end
                if slot.content then
                    P(("  content: shown %s - alpha %s - scale %s - style %s"):format(Ask(slot.content, "IsShown"),
                        Ask(slot.content, "GetAlpha"), Ask(slot.content, "GetScale"), V(slot.s and slot.s.key)))
                end
            end)
            local known = slots[p.key] or (type(e) == "table" and e.id)
            if known and not slots[p.key] then P("  no frame in the game's container") end
            local cfg = ns.Cfg(p.key)
            local st = ns.procState and ns.procState[p.key] or {}
            local g = ns.engine and ns.engine[p.key] or {}
            if known then P(("  settings: on %s - x %s y %s - size %s - opacity %s - only in combat %s - Shadowflare sees it %s - cooldown wait %s"):format(
                V(cfg.enabled), V(cfg.x), V(cfg.y), V(cfg.scale), V(cfg.alpha), V(cfg.onlyCombat), V(st.active), V(g.wait))) end
        end
    end
    if not any then P("no proc of this class can be shown by the game") end
    if #AS.errors == 0 then P("errors: none") else
        P("errors (" .. #AS.errors .. "):")
        for _, t in ipairs(AS.errors) do P("  " .. t) end
    end
end

-- /flare buffs: the player's buffs with their numbers (out of combat), and what is learned
function AS.ListBuffs()
    if InCombat() then ns.Print(L.GS_COMBAT) return end
    local lines = 0
    if GetByIndex then
        for i = 1, 40 do
            local ok, a = pcall(ReadOne, i)
            if not ok or type(a) ~= "table" then break end
            local sid, name = ns.num(a.spellId), ns.str(a.name)
            local dur, apps = ns.num(a.duration), ns.num(a.applications)
            ns.Print(("%s - %s - %s s - x%s"):format(tostring(sid), tostring(name), tostring(dur and math.floor(dur * 10 + 0.5) / 10), tostring(apps)))
            lines = lines + 1
        end
    end
    if lines == 0 then ns.Print(L.GS_NONE) end
    for _, p in ipairs(ns.PROCS) do
        if ns.Mine(p) and Eligible(p) then
            local e = ns.db.buffs and ns.db.buffs[p.key]
            local state = (AS.Owns(p.key) and L.GS_STATE_GAME) or (Ready(p) and L.GS_STATE_READY) or L.GS_STATE_WAIT
            ns.Print(("%s: %s%s"):format(ns.Info(p.key).name, state,
                (type(e) == "table" and e.id) and (" (" .. tostring(e.id) .. (p.stacks and (", x" .. tostring(e.apps)) or "") .. ")") or ""))
        end
    end
end
