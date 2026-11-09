local _, ns = ...
local L = ns.L
local ART = "Interface\\AddOns\\Shadowflare\\Art\\"
local BACKDROP = BackdropTemplateMixin and "BackdropTemplate" or nil

local floor, ceil, abs, sin, cos, min, max = math.floor, math.ceil, math.abs, math.sin, math.cos, math.min, math.max
local GetTime = GetTime

-- How the alert comes and goes (seconds). The fade follows a smooth curve both ways,
-- so a proc that comes back while the alert is fading picks up where it was.
-- (0.23.0: the ways in and out are per animation, see D.Enter and D.Exit)

local D = {}
ns.Display = D

ns.COLORS = {
    { key = "violet", r = 0.66, g = 0.36, b = 1.00 },
    { key = "fel",    r = 0.42, g = 1.00, b = 0.22 },
    { key = "shadow", r = 0.45, g = 0.16, b = 0.80 },
    { key = "fire",   r = 1.00, g = 0.48, b = 0.12 },
    { key = "frost",  r = 0.36, g = 0.72, b = 1.00 },
    { key = "blood",  r = 0.95, g = 0.18, b = 0.12 },
}

-- Color of a proc's alert (the chosen proc's when none is given)
local function Color(cfg)
    cfg = cfg or ns.Cur()
    local cu = cfg.custom
    if cfg.color == "custom" and type(cu) == "table" and cu[1] then return cu[1], cu[2], cu[3] end
    for _, c in ipairs(ns.COLORS) do
        if c.key == cfg.color then return c.r, c.g, c.b end
    end
    local c = ns.COLORS[1]
    return c.r, c.g, c.b
end
D.Color = Color

-- Plain loading. Never ask for "TRILINEAR" smoothing here: on the Forever client it crashes
-- the game at launch (fatal error "flags.m_filter <= GxTex_Linear"), and pcall can't catch it.
local function art(t, path)
    t:SetTexture(path)
end

local SHADE_LIFT, SHADE_SCALE, Darken   -- the shadow under each alert (0.21.1), set further down
local function Light(r, g, b) return r + (1 - r) * 0.55, g + (1 - g) * 0.55, b + (1 - b) * 0.55 end
D.Light = Light

-- Procs with stacks (0.18.0): below the maximum the alert is dimmer, from 40% at one stack
-- up to full at the maximum.
function D.StackK(n, maxN, noDim)
    if noDim or not (n and maxN) or n >= maxN or maxN <= 1 then return 1 end
    if n < 1 then n = 1 end
    return 0.4 + 0.6 * (n - 1) / (maxN - 1)
end
-- Whether a proc shows its number of stacks
local function StackShown(key, cfg)
    local p = ns.PROC_BY[key]
    return p and p.stacks and cfg.stackNum and true or false
end
D.StackShown = StackShown

----------------------------------------------------------------------
-- How a proc with stacks looks below its maximum (0.21.0, asked on Reddit), per proc:
--   dim      : the whole alert, dimmer (0.18.0, the default)
--   fillup   : a part per stack, from the bottom; the rest of the alert stays faint
--   fillleft : the same, from the left
--   dots     : the whole alert, with one dot per stack under it
-- The fill is a copy of the style in color, inside a frame that cuts what it holds to the
-- part reached, over the style itself made faint. It works the same for every style, and
-- for the frames the game shows itself (AuraShow.lua: each stack frame holds its own part).
----------------------------------------------------------------------
-- (0.23.15: the "sides" look, one side at the first stack of Fingers of Frost, is gone: every
-- two-sided style now has its own Sides choice, Both, Left or Right, decided by Ben.)
local LOOKS = { dim = true, fillup = true, fillleft = true, dots = true }
D.STACK_LOOKS = { "dim", "fillup", "fillleft", "dots" }
D.FAINT = 0.16
-- 0.23.15 (Ben): "Hide the part not reached yet": the rest of a filling alert fully hidden
function D.FaintOf(cfg) return (cfg and cfg.fillHide) and 0 or D.FAINT end
-- Whether a style is drawn on two sides (its left and right parts can show on their own)
function D.TwoSided(styleKey)
    if styleKey == "arcs" then return true end
    local def = ns.BY_KEY[styleKey]
    return def and def.file and (def.layout or "sides") == "sides" or false
end
-- Which sides of a two-sided style show (0.23.15, asked on CurseForge): both, left or right
D.SIDES = { "both", "left", "right" }
function D.SideOf(cfg, styleKey)
    local v = cfg and cfg.side
    if (v == "left" or v == "right") and D.TwoSided(styleKey) then return v end
    return "both"
end
-- Spacing (0.23.15): how far each half of a two-sided style moves out (or in) from where it
-- sits, without changing its size
D.SPACING_MIN, D.SPACING_MAX = -30, 200
function D.SpacingOf(cfg)
    local v = tonumber(cfg and cfg.spacing) or 0
    if v < D.SPACING_MIN then v = D.SPACING_MIN elseif v > D.SPACING_MAX then v = D.SPACING_MAX end
    return v
end
-- Whether a look can be picked for a proc with the style it has now
-- 0.23.19 (seen by Ben): Fills from the left splits the alert into one part per stack, from left
-- to right; with only one side of a two-sided style shown, that cut the side in the middle. It
-- needs both sides: greyed out then, and Fills up takes its place (the player's choice is kept
-- for when both sides come back).
function D.OneSide(key)
    local cfg = ns.Cfg(key)
    return D.SideOf(cfg, D.EffectiveStyle(cfg)) ~= "both"
end
function D.LookFits(key, look)
    local p = ns.PROC_BY[key]
    if not (p and p.stacks and LOOKS[look]) then return false end
    if look == "fillleft" and D.OneSide(key) then return false end
    -- 0.23.30: no picture to fill with the None style
    if (look == "fillup" or look == "fillleft") and D.NoArt(ns.Cfg(key)) then return false end
    return true
end
function D.StackLook(key)
    local p = ns.PROC_BY[key]
    if not (p and p.stacks) then return "dim" end
    local cfg = ns.Cfg(key)
    if D.NoArt(cfg) then return (cfg.noneDots ~= false) and "dots" or "dim" end   -- 0.23.32
    local v = cfg.stackLook
    if v and D.LookFits(key, v) then return v end
    if v == "fillleft" and D.LookFits(key, "fillup") then return "fillup" end
    return "dim"
end
-- Shows the left and right parts of a two-sided style (both when the style has no sides)
function D.ShowSides(s, left, right)
    if s and s.shade then D.ShowSides(s.shade, left, right) end
    if s then s.side = (left and right) and "both" or (left and "left") or "right" end
    local sd = s and s.sides
    if not sd then return end
    for _, t in ipairs(sd[1]) do t:SetShown(left and true or false) end
    for _, t in ipairs(sd[2]) do t:SetShown(right and true or false) end
end
-- The sides the player picked for this alert, on a built style (and its shadow)
function D.ApplySides(s, cfg)
    if not s then return end
    local side = D.SideOf(cfg, s.key)
    D.ShowSides(s, side ~= "right", side ~= "left")
end
-- Where each style is visible, in alert units around its centre, before it is turned
-- (measured on the textures: their empty margins left out)
local INK = {
    arcs = { -124, -86, 124, 86 }, crescent = { -106, 9, 106, 96 }, ring = { -54, -54, 54, 54 },
    shockwave = { -48, -48, 48, 48 }, sigil = { -74, -74, 74, 74 }, brackets = { -55, -55, 55, 55 },
    icon = { -30, -30, 30, 30 }, procglow = { -36, -36, 36, 36 }, bar = { -115, -14, 115, 14 },
    text = { -120, -22, 120, 28 }, sides = { -145, -100, 145, 100 }, top = { -110, 14, 110, 120 },
    none = { -24, -14, 24, 14 },   -- the time left: the dots sit right under it
}
-- Two-sided styles: where the inner edge of each half is, from the centre
local INNER = { arcs = 34, sides = 40 }
function D.InkBox(s)
    local def = ns.BY_KEY[s.key]
    local b = INK[s.key] or (def and def.file and INK[def.layout or "sides"]) or INK.arcs
    local inner = INNER[s.key] or (def and def.file and (def.layout or "sides") == "sides" and INNER.sides)
    if inner then
        local sp = s.spread or 0
        local x0, x1 = b[1] - sp, b[3] + sp
        if s.side == "left" then x1 = -(inner + sp) elseif s.side == "right" then x0 = inner + sp end
        b = { x0, b[2], x1, b[4] }
    end
    local a = s.angle or 0
    if a == 0 or not s.rot then return b[1], b[2], b[3], b[4] end   -- round styles don't turn
    local c, sn = cos(a), sin(a)
    local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
    for i = 1, 4 do
        local px = (i <= 2) and b[1] or b[3]
        local py = (i % 2 == 1) and b[2] or b[4]
        local x, y = px * c - py * sn, px * sn + py * c
        if x < x0 then x0 = x end
        if x > x1 then x1 = x end
        if y < y0 then y0 = y end
        if y > y1 then y1 = y end
    end
    return x0, y0, x1, y1
end
-- Cuts the clip frame to the part of the style between lo and hi (0 to 1), in the fill's
-- direction. The outer sides go well past the style, so its glow is not cut there.
local PAD = 90
function D.PlaceClip(clip, ref, s, look, lo, hi)
    local x0, y0, x1, y1 = D.InkBox(s)
    clip:ClearAllPoints()
    if look == "fillleft" then
        local a, b = x0 + (x1 - x0) * lo, x0 + (x1 - x0) * hi
        if lo <= 0 then a = x0 - PAD end
        if hi >= 1 then b = x1 + PAD end
        clip:SetPoint("BOTTOMLEFT", ref, "CENTER", a, y0 - PAD)
        clip:SetSize(max(0.01, b - a), (y1 - y0) + 2 * PAD)
    else
        local a, b = y0 + (y1 - y0) * lo, y0 + (y1 - y0) * hi
        if lo <= 0 then a = y0 - PAD end
        if hi >= 1 then b = y1 + PAD end
        clip:SetPoint("BOTTOMLEFT", ref, "CENTER", x0 - PAD, a)
        clip:SetSize((x1 - x0) + 2 * PAD, max(0.01, b - a))
    end
end
-- The frame that cuts, and the color copy of a style inside it (built once per style)
function D.Clip(host, parent, level)
    local clip = host.clip
    if not clip then
        clip = CreateFrame("Frame", nil, parent)
        pcall(clip.SetClipsChildren, clip, true)
        host.clip = clip
    end
    if level then pcall(clip.SetFrameLevel, clip, level) end
    return clip
end
function D.FillCopy(host, ref, base, cfg, P)
    host.copies = host.copies or {}
    local c = host.copies[base.key]
    if not c then
        local f = CreateFrame("Frame", nil, host.clip)
        f:SetAllPoints(ref)
        c = D.Build(f, base.key, P)
        host.copies[base.key] = c
    end
    for _, o in pairs(host.copies) do o.frame:SetShown(o == c) end
    if c.Refresh then c.Refresh() end
    local r, g, b = Color(cfg)
    c.SetColor(r, g, b, cfg.tintClassic)
    D.Rotate(c, cfg.rotation, D.SpacingOf(cfg))
    D.ApplySides(c, cfg)
    D.ApplyFont(c, cfg.font)
    return c
end
-- Dots under the alert: up to 5, lit from litFrom to litTo; rings: the empty ones show too
function D.Dots(host, parent)
    local d = host.dots
    if d then return d end
    d = CreateFrame("Frame", nil, parent)
    d:SetSize(1, 1)
    d.items = {}
    for i = 1, 5 do
        local ring = d:CreateTexture(nil, "BORDER"); art(ring, ART .. "ring"); ring:SetBlendMode("ADD"); ring:SetSize(15, 15)
        local glow = d:CreateTexture(nil, "ARTWORK"); art(glow, ART .. "glow"); glow:SetBlendMode("ADD"); glow:SetSize(32, 32)
        local core = d:CreateTexture(nil, "OVERLAY"); art(core, ART .. "glow"); core:SetBlendMode("ADD"); core:SetSize(14, 14)
        d.items[i] = { ring = ring, glow = glow, core = core }
    end
    host.dots = d
    return d
end
function D.SetDots(d, ref, s, count, litFrom, litTo, rings, cfg)
    local _, y0 = D.InkBox(s)
    local gap = 20
    local start = -(count - 1) * gap / 2
    d:ClearAllPoints()
    d:SetPoint("CENTER", ref, "CENTER", 0, y0 - 16)
    local r, g, b = Color(cfg)
    local lr, lg, lb = Light(r, g, b)
    for i = 1, 5 do
        local it = d.items[i]
        local on = i <= count
        local lit = on and i >= litFrom and i <= litTo
        local x = start + (i - 1) * gap
        it.ring:ClearAllPoints(); it.ring:SetPoint("CENTER", d, "CENTER", x, 0)
        it.glow:ClearAllPoints(); it.glow:SetPoint("CENTER", d, "CENTER", x, 0)
        it.core:ClearAllPoints(); it.core:SetPoint("CENTER", d, "CENTER", x, 0)
        it.ring:SetShown(on and (rings or lit) and true or false)
        it.glow:SetShown(lit and true or false)
        it.core:SetShown(lit and true or false)
        it.ring:SetVertexColor(r, g, b); it.ring:SetAlpha(lit and 0.9 or 0.45)
        it.glow:SetVertexColor(r, g, b); it.glow:SetAlpha(0.85)
        it.core:SetVertexColor(lr, lg, lb)
    end
    d:Show()
end

local function Tex(parent, file, w, h, layer, blend)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    art(t, file)
    t:SetSize(w, h)
    t:SetPoint("CENTER")
    if blend then t:SetBlendMode(blend) end
    return t
end

----------------------------------------------------------------------
-- Fonts (0.23.24, asked by Ben): one font per alert for all its text (time left, the words
-- of a style, the number of stacks). The game's own fonts, plus the fonts other addons share
-- through LibSharedMedia when one is loaded (Shadowflare ships none). "game" = the font the
-- game uses in the player's language (default, as before).
----------------------------------------------------------------------
local GAME_FONTS = {
    { key = "friz", name = "Friz Quadrata", file = "Fonts\\FRIZQT__.TTF" },
    { key = "arialn", name = "Arial Narrow", file = "Fonts\\ARIALN.TTF" },
    { key = "skurri", name = "Skurri", file = "Fonts\\skurri.ttf" },
    { key = "morpheus", name = "Morpheus", file = "Fonts\\MORPHEUS.TTF" },
}
local GAME_FONT_FILE = {}
for _, f in ipairs(GAME_FONTS) do GAME_FONT_FILE[f.key] = f.file end
D.GAME_FONTS = GAME_FONTS
local function SharedMedia()
    if not LibStub then return nil end
    local ok, lsm = pcall(LibStub, "LibSharedMedia-3.0", true)
    return ok and lsm or nil
end
local function DefaultFont() return (GameFontNormal:GetFont()) end
-- The file of a font choice; the game's font when it is gone (an addon removed)
function D.FontFile(key)
    if type(key) == "string" and key:sub(1, 4) == "lsm:" then
        local lsm = SharedMedia()
        if lsm then
            local ok, file = pcall(lsm.Fetch, lsm, "font", key:sub(5), true)
            if ok and type(file) == "string" and file ~= "" then return file end
        end
    elseif GAME_FONT_FILE[key] then
        return GAME_FONT_FILE[key]
    end
    return DefaultFont()
end
-- Sets a font; if the client refuses the file, the fallback (the game's font) instead, so the
-- text never goes blank
function D.SetFontSafe(fs, file, size, flags, fallback)
    local ok, res = pcall(fs.SetFont, fs, file, size, flags or "")
    if ok and res ~= false then return true end
    pcall(fs.SetFont, fs, fallback or DefaultFont(), size, flags or "")
    return false
end
-- The choices for the menu: the game's font, the game's other fonts this client has, then the
-- fonts shared by other addons (the game's own ones they also list are left out)
local probe
function D.FontList()
    local list = { { value = "game", text = L.FONT_GAME } }
    probe = probe or UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local seen = {}
    for _, f in ipairs(GAME_FONTS) do
        local ok, res = pcall(probe.SetFont, probe, f.file, 12, "")
        if ok and res ~= false then list[#list + 1] = { value = f.key, text = f.name } end
        seen[f.file:lower()] = true
    end
    local lsm = SharedMedia()
    if lsm then
        local ok, names = pcall(lsm.List, lsm, "font")
        if ok and type(names) == "table" then
            for _, name in ipairs(names) do
                local okF, file = pcall(lsm.Fetch, lsm, "font", name, true)
                if okF and type(file) == "string" and not seen[file:lower()] and #name <= 60 then
                    seen[file:lower()] = true
                    list[#list + 1] = { value = "lsm:" .. name, text = name }
                end
            end
        end
    end
    return list
end
-- Every text of a built style takes the alert's font (kept at its own size)
function D.ApplyFont(s, key)
    if not s or not s.fonts then return end
    key = key or "game"
    if s.fontKey == key then return end
    s.fontKey = key
    local file = D.FontFile(key)
    for _, e in ipairs(s.fonts) do
        D.SetFontSafe(e[1], key == "game" and e[4] or file, e[2], e[3], e[4])
    end
end

local fontLog   -- the texts made while a style is built
local function Font(parent, size, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY", "GameFontNormal")
    local file = GameFontNormal:GetFont()
    fs:SetFont(file, size, "OUTLINE")
    fs:SetTextColor(1, 1, 1)
    fs:SetPoint("CENTER")
    if fontLog then fontLog[#fontLog + 1] = { fs, size, "OUTLINE", file } end
    return fs
end
-- A text made from one of the game's font objects (the Bar style): noted with its own size
local function Track(fs)
    if not fontLog then return fs end
    local ok, file, size, flags = pcall(fs.GetFont, fs)
    if ok and file then fontLog[#fontLog + 1] = { fs, size or 10, flags or "", file } end
    return fs
end

local function Cooldown(parent)
    local ok, cd = pcall(CreateFrame, "Cooldown", nil, parent, "CooldownFrameTemplate")
    if not ok or not cd then return nil end
    pcall(cd.SetHideCountdownNumbers, cd, true)
    pcall(cd.SetDrawEdge, cd, false)
    pcall(cd.SetDrawBling, cd, false)
    return cd
end

----------------------------------------------------------------------
-- Time left. Each value shown ("7", "2.4") is written once and kept, so the frame loop
-- never builds text: it only changes the text when the shown value changes.
----------------------------------------------------------------------
local TEXT = {}
-- Rounded down, like the game's own buff timer (Forever's aura code truncates: with 14.6 s
-- left it shows 14). Up to 0.18.0 this rounded up, so the alert showed one second more
-- than the buff (reported for Omen of Clarity, 19 October 2026).
local function TimeKey(rem)
    if not rem then return false end
    if rem < 3 then return floor(rem * 10) end          -- tenths under 3 s
    return 1000 + floor(rem)                            -- whole seconds above
end
local function TimeText(key)
    if not key then return "" end
    local t = TEXT[key]
    if not t then
        if key >= 1000 then t = tostring(key - 1000) else t = ("%.1f"):format(key / 10) end
        TEXT[key] = t
    end
    return t
end
D.TimeText, D.TimeKey = TimeText, TimeKey

-- The breathing of the alert: slow and soft, then quicker for the last 3 seconds
local function Pulse(now, rem)
    if rem and rem < 3 then return 0.55 + 0.45 * abs(sin(now * 6)) end
    return 0.8 + 0.2 * sin(now * 3.5)
end

----------------------------------------------------------------------
-- Animations, chosen per proc (0.15.0). Since 0.23.0 (asked by Ben: Impact and Still felt
-- soft) each one has its own way in, its own life on screen and its own way out:
--   breath : fades in from 92% (0.25 s), breathes slowly (quicker for the last 3 s), fades out
--   classic: pops from 60% with a small bounce (0.2 s), swells every second, grows out
--   impact : on at once, lands from 150% with a white-hot flare (0.2 s), holds still
--   flash  : on at once, three hard flashes (0.4 s), holds still
--   still  : on at once, holds still
-- The way out depends on how the proc ended: used (its spell cast) is a quick burst, run out
-- is a fade. Impact, Flash and Still go in 0.08 s (a hard cut looked like a glitch).
-- A proc that comes again while shown, or reaches its maximum of stacks, plays an accent:
-- the punch of its entrance without fading from nothing.
-- Each function returns the alert's opacity (a), size (k), white-hot flare (h), and for the
-- way out and the accent whether they are over.
----------------------------------------------------------------------
-- Impact pulse (0.23.2, asked by Ben): Impact's way in, accent and way out, then the Classic
-- pulse swell while on screen. Default of Fingers of Frost.
ns.ANIMS = { "breath", "classic", "impact", "impactpulse", "flash", "still" }
-- The animation whose way in / out / accent an animation uses, and the one whose life it uses
local MOVE = { impactpulse = "impact" }
local LIFE = { impactpulse = "classic" }
D.MOVE, D.LIFE = MOVE, LIFE
local TWO_PI = 2 * math.pi
local CLASSIC_POP = 0.3   -- the classic swell starts once the pop is over
local function clamp(x) if x < 0 then return 0 elseif x > 1 then return 1 end return x end
local function easeOut(x) local u = 1 - x; return 1 - u * u * u end
local function easeIn(x) return x * x * x end
local FLASHES = { 0.07, 1, 0.13, 0.08, 0.20, 1, 0.26, 0.08, 0.33, 1, 0.39, 0.08 }   -- until, opacity
local function Flashes(t)
    for i = 1, #FLASHES, 2 do if t < FLASHES[i] then return FLASHES[i + 1] end end
    return 1
end
-- How long each way in lasts (for the previews)
local ENTER_LEN = { breath = 0.25, classic = 0.3, impact = 0.22, impactpulse = 0.22, flash = 0.4, still = 0, instant = 0 }
function D.FadeIn(anim) return ENTER_LEN[anim] or 0.25 end

-- 0.23.13 (asked by Ben): "No way in or out", set alert by alert under its animation. The
-- alert then comes and goes as Still does (at once in, a quick fade out, no burst, no punch
-- when it comes again); its animation keeps moving while shown (AnimLook is not touched).
-- 0.23.16 (asked by Ben): alerts that follow the target (Execute, Hammer of Wrath, Conflagrate:
-- onTarget in Core.lua) come and go at once, with no fade at all, whatever the animation: on a
-- target change they must be right away. Their animation still moves while shown.
function D.InOut(cfg, key)
    local p = key and ns.PROC_BY[key]
    if p and p.onTarget then return "instant" end
    if cfg and cfg.noEntrance then return "still" end
    return cfg and cfg.anim
end

function D.Enter(anim, t)
    anim = MOVE[anim] or anim
    if anim == "classic" then
        local k
        if t < 0.2 then k = 0.6 + 0.44 * easeOut(t / 0.2)
        elseif t < CLASSIC_POP then k = 1.04 - 0.04 * easeOut((t - 0.2) / 0.1)
        else k = 1 end
        return clamp(t / 0.12), k, 0
    elseif anim == "impact" then
        local k
        if t < 0.11 then k = 1.5 - 0.56 * easeIn(t / 0.11)
        elseif t < 0.2 then k = 0.94 + 0.06 * easeOut((t - 0.11) / 0.09)
        else k = 1 end
        return 1, k, 0.9 * clamp(1 - t / 0.22)
    elseif anim == "flash" then
        local a = Flashes(t)
        return a, 1, (t < 0.4 and a == 1) and 0.5 or 0
    elseif anim == "still" or anim == "instant" then
        return 1, 1, 0
    end
    local x = clamp(t / 0.25)   -- breath
    return easeOut(x), 0.92 + 0.08 * easeOut(x), 0
end

function D.Exit(anim, t, used)
    anim = MOVE[anim] or anim
    if anim == "instant" then return 0, 1, 0, true end   -- gone at once (onTarget)
    if anim == "impact" or anim == "still" or anim == "flash" then
        local t0 = 0
        if anim == "flash" then   -- one quick blink first
            if t < 0.05 then return 0, 1, 0, false end
            if t < 0.1 then return 1, 1, used and 0.4 or 0, false end
            t0 = 0.1
        end
        local x = clamp((t - t0) / 0.08)
        local k = (used and anim == "impact") and 1 + 0.1 * x or 1
        return 1 - x, k, (used and anim == "impact") and 0.4 * (1 - x) or 0, x >= 1
    end
    if used then   -- a quick burst
        local x = clamp(t / 0.18)
        return 1 - x, 1 + (anim == "classic" and 0.2 or 0.12) * easeOut(x), 0.3 * (1 - x), x >= 1
    end
    if anim == "classic" then
        local x = clamp(t / 0.3)
        return 1 - x, 1 + 0.15 * easeOut(x), 0, x >= 1
    end
    local x = clamp(t / 0.4)   -- breath
    return 1 - easeIn(x), 1 - 0.03 * x, 0, x >= 1
end

function D.AccentLook(anim, t)
    anim = MOVE[anim] or anim
    if anim == "classic" then
        if t < 0.15 then return 1, 0.85 + 0.19 * easeOut(t / 0.15), 0, false end
        if t < 0.25 then return 1, 1.04 - 0.04 * easeOut((t - 0.15) / 0.1), 0, false end
        return 1, 1, 0, true
    elseif anim == "impact" then
        local k
        if t < 0.11 then k = 1.35 - 0.41 * easeIn(t / 0.11)
        elseif t < 0.2 then k = 0.94 + 0.06 * easeOut((t - 0.11) / 0.09)
        else k = 1 end
        return 1, k, 0.9 * clamp(1 - t / 0.22), t >= 0.22
    elseif anim == "flash" then
        local a = Flashes(t)
        return a, 1, (t < 0.4 and a == 1) and 0.5 or 0, t >= 0.4
    elseif anim == "still" or anim == "instant" then
        return 1, 1, 0, true
    end
    return 1, 1, 0.35 * clamp(1 - t / 0.3), t >= 0.3   -- breath: brightens for a moment
end

-- Life on screen once in: how bright its breathing part is (p), its size (k), its opacity (a)
function D.AnimLook(anim, t, now, rem)
    anim = LIFE[anim] or anim
    if anim == "classic" then
        local u = t - CLASSIC_POP
        if u < 0 then u = 0 end
        return 1, 1 + 0.08 * (0.5 - 0.5 * cos(u * TWO_PI)), 1
    elseif anim == "breath" then
        return Pulse(now, rem), 1, 1
    end
    return 1, 1, 1
end

-- The white-hot copy of a style (Impact, Flash, accents): built the first time it is needed
local HOT_R, HOT_G, HOT_B = 1, 0.95, 0.85
function D.HotCopy(host, ref, base, P)
    host.hots = host.hots or {}
    local c = host.hots[base.key]
    if not c then
        local f = CreateFrame("Frame", nil, ref)
        f:SetAllPoints(ref)
        pcall(f.SetFrameLevel, f, ref:GetFrameLevel() + 20)
        c = D.Build(f, base.key, P)
        host.hots[base.key] = c
        f:SetAlpha(0)
    end
    for _, o in pairs(host.hots) do if o ~= c then o.frame:SetAlpha(0) end end
    c.SetColor(HOT_R, HOT_G, HOT_B, true)
    D.ApplyFont(c, base.fontKey)
    if c.shadeHost then c.shadeHost:Hide() end   -- light only, no shadow
    if c.pulse then c.pulse:SetAlpha(c.pA + c.pB) end
    D.Rotate(c, base.angle and base.angle * 180 / math.pi or 0, base.spread)
    D.ShowSides(c, base.side ~= "right", base.side ~= "left")
    if c.SetTime then c.SetTime("") elseif c.timer then c.timer:SetText("") end
    return c
end

----------------------------------------------------------------------
-- Styles. Each style is drawn on stacked layers inside its frame f:
--   pulse : what breathes. One alpha change per frame moves all of it.
--   over  : what stays still on top (icons)
--   top   : the time left
-- A style returns:
--   SetColor(r, g, b), Refresh() (names), pulse, pA/pB (pulse alpha = pA + pB * p),
--   timer (font string) or SetTime(text), Animate(now, rem, p) for moving parts,
--   SetExpiry(exp, dur) for cooldown swipes, OnAppear() when it shows.
----------------------------------------------------------------------
local B = {}

local function Layers(f)
    local base = f:GetFrameLevel() + (f.sfLift or 0)   -- the style sits above its shadow (0.21.1)
    local pulse = CreateFrame("Frame", nil, f); pulse:SetAllPoints(f); pulse:SetFrameLevel(base + 1)
    local over = CreateFrame("Frame", nil, f); over:SetAllPoints(f); over:SetFrameLevel(base + 2)
    local top = CreateFrame("Frame", nil, f); top:SetAllPoints(f); top:SetFrameLevel(base + 10)
    return pulse, over, top
end

local function ArcPair(parent, anchorTo, file, w, h, gap, blend)
    local l = parent:CreateTexture(nil, "ARTWORK")
    art(l, file); l:SetSize(w, h); l:SetPoint("RIGHT", anchorTo, "CENTER", -gap, 0)
    local r = parent:CreateTexture(nil, "ARTWORK")
    art(r, file); r:SetSize(w, h); r:SetPoint("LEFT", anchorTo, "CENTER", gap, 0)
    r:SetTexCoord(1, 0, 0, 1)
    if blend then l:SetBlendMode(blend); r:SetBlendMode(blend) end
    return l, r
end

function B.arcs(f, P)
    local pulse, _, top = Layers(f)
    local l1, r1 = ArcPair(pulse, f, ART .. "arc", 96, 192, 34, "ADD")
    local l2, r2 = ArcPair(pulse, f, ART .. "arc", 96, 192, 34, "ADD")
    l2:SetAlpha(0.35); r2:SetAlpha(0.35)
    return {
        rot = { { l1, -82, 0 }, { r1, 82, 0 }, { l2, -82, 0 }, { r2, 82, 0 } },
        sides = { { l1, l2 }, { r1, r2 } },
        pulse = pulse,
        timer = Font(top, 20),
        SetColor = function(r, g, b)
            l1:SetVertexColor(r, g, b); r1:SetVertexColor(r, g, b)
            local lr, lg, lb = Light(r, g, b)
            l2:SetVertexColor(lr, lg, lb); r2:SetVertexColor(lr, lg, lb)
        end,
    }
end

function B.ring(f, P)
    local pulse, over, top = Layers(f)
    local cd = Cooldown(f)
    if cd then
        cd:SetFrameLevel(f:GetFrameLevel() + (f.sfLift or 0) + 3)
        cd:SetSize(112, 112); cd:SetPoint("CENTER")
        if not (cd.SetSwipeTexture and pcall(cd.SetSwipeTexture, cd, ART .. "ring")) then
            cd:Hide(); cd = nil
        end
    end
    local glow = Tex(pulse, ART .. "glow", 180, 180, "BACKGROUND", "ADD")
    glow:SetAlpha(0.7)
    -- With a swipe the ring stays faint and still; without one it breathes with the glow
    local base = Tex(cd and over or pulse, ART .. "ring", 112, 112, "BORDER", "ADD")
    if cd then base:SetAlpha(0.35) end
    local icon = Tex(over, P.icon, 62, 62, "ARTWORK")
    pcall(function()
        local mask = over:CreateMaskTexture()
        local ok = mask:SetTexture("Interface\\Masks\\CircleMaskScalable", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        if ok == false then
            mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        end
        mask:SetAllPoints(icon)
        icon:AddMaskTexture(mask)
    end)
    return {
        pulse = pulse,
        timer = Font(top, 22),
        SetColor = function(r, g, b)
            glow:SetVertexColor(r, g, b); base:SetVertexColor(r, g, b)
            if cd then pcall(cd.SetSwipeColor, cd, Light(r, g, b)) end
        end,
        SetExpiry = cd and function(exp, dur) cd:SetCooldown(exp - dur, dur) end,
        swipe = cd,   -- 0.23.8: given to the game for alerts it shows itself
    }
end

function B.icon(f, P)
    local pulse, over, top = Layers(f)
    local glow = Tex(pulse, ART .. "glow", 140, 140, "BACKGROUND", "ADD")
    local border = over:CreateTexture(nil, "BORDER")
    border:SetColorTexture(0, 0, 0, 1); border:SetSize(60, 60); border:SetPoint("CENTER")
    local icon = Tex(over, P.icon, 56, 56, "ARTWORK")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local cd = Cooldown(f)
    if cd then cd:SetFrameLevel(f:GetFrameLevel() + (f.sfLift or 0) + 3); cd:SetAllPoints(icon); pcall(cd.SetReverse, cd, true) end
    return {
        pulse = pulse,
        timer = Font(top, 22),
        SetColor = function(r, g, b) glow:SetVertexColor(r, g, b) end,
        SetExpiry = cd and function(exp, dur) cd:SetCooldown(exp - dur, dur) end,
        swipe = cd,
    }
end

function B.sigil(f, P)
    local pulse, _, top = Layers(f)
    local glow = Tex(pulse, ART .. "glow", 210, 210, "BACKGROUND", "ADD")
    local outer = Tex(pulse, ART .. "sigil", 150, 150, "ARTWORK", "ADD")
    local inner = Tex(pulse, ART .. "sigil", 96, 96, "ARTWORK", "ADD")
    glow:SetAlpha(0.45); inner:SetAlpha(0.45)
    return {
        pulse = pulse,
        timer = Font(top, 20),
        SetColor = function(r, g, b)
            glow:SetVertexColor(r, g, b); outer:SetVertexColor(r, g, b)
            inner:SetVertexColor(Light(r, g, b))
        end,
        Animate = function(now)
            outer:SetRotation(now * 0.5)
            inner:SetRotation(-now * 0.8)
        end,
    }
end

function B.bar(f, P)
    local _, over = Layers(f)
    local box = CreateFrame("Frame", nil, over, BACKDROP)
    box:SetSize(230, 28); box:SetPoint("CENTER", f, "CENTER")
    if box.SetBackdrop then
        box:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        box:SetBackdropColor(0, 0, 0, 0.75)
        box:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    end
    local icon = box:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(P.icon); icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetSize(20, 20); icon:SetPoint("LEFT", 4, 0)
    local bar = CreateFrame("StatusBar", nil, box)
    bar:SetPoint("LEFT", icon, "RIGHT", 3, 0); bar:SetPoint("RIGHT", -4, 0); bar:SetHeight(20)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    -- The spark rides on the end of the fill by itself: no re-anchoring every frame
    local spark = bar:CreateTexture(nil, "OVERLAY")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark"); spark:SetBlendMode("ADD"); spark:SetSize(20, 38)
    local fill = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if fill then spark:SetPoint("CENTER", fill, "RIGHT", 0, 0) else spark:SetPoint("CENTER", bar, "RIGHT", 0, 0) end
    spark:Hide()
    local name = Track(bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
    name:SetPoint("LEFT", 5, 0)
    local timer = Track(bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
    timer:SetPoint("RIGHT", -5, 0)
    local lastV, sparkOn
    local s = {
        timer = timer,
        Refresh = function() name:SetText(P.name) end,
        SetColor = function(r, g, b)
            bar:SetStatusBarColor(r, g, b)
            bg:SetVertexColor(r * 0.25, g * 0.25, b * 0.25, 0.8)
        end,
        Animate = function(_, rem, _, dur)
            local v = (rem and dur and dur > 0) and min(1, rem / dur) or 1
            if v ~= lastV then
                lastV = v
                bar:SetValue(v)
                local on = v > 0 and v < 1
                if on ~= sparkOn then sparkOn = on; spark:SetShown(on) end
            end
        end,
    }
    s.Refresh()
    return s
end

function B.text(f, P)
    local pulse, over = Layers(f)
    local glow = Tex(pulse, ART .. "glow", 300, 110, "BACKGROUND", "ADD")
    glow:SetAlpha(0.4)
    local title = Font(over, 28)
    title:SetPoint("CENTER", 0, 10)
    local sub = Font(over, 14)
    sub:ClearAllPoints()
    sub:SetPoint("TOP", title, "BOTTOM", 0, -4)
    local lines = {}   -- "Instant Shadow Bolt - 7", built once per value
    local s = {
        pulse = pulse,
        Refresh = function() title:SetText((P.name):upper()) end,
        SetColor = function(r, g, b)
            glow:SetVertexColor(r, g, b)
            title:SetTextColor(Light(r, g, b))
            sub:SetTextColor(1, 1, 1)
        end,
        SetTime = function(t)
            if t == "" then sub:SetText(P.label) return end
            local line = lines[t]
            if not line then line = P.label .. " - " .. t; lines[t] = line end
            sub:SetText(line)
        end,
    }
    s.Refresh()
    sub:SetText(P.label)
    return s
end

function B.crescent(f, P)
    local pulse, _, top = Layers(f)
    local t1 = Tex(pulse, ART .. "top", 230, 115, "ARTWORK", "ADD")
    local t2 = Tex(pulse, ART .. "top", 230, 115, "ARTWORK", "ADD")
    t1:SetPoint("CENTER", 0, 48); t2:SetPoint("CENTER", 0, 48)
    t2:SetAlpha(0.35)
    local timer = Font(top, 20)
    timer:SetPoint("CENTER", 0, -6)
    return {
        rot = { { t1, 0, 48 }, { t2, 0, 48 } },
        pulse = pulse,
        timer = timer,
        SetColor = function(r, g, b) t1:SetVertexColor(r, g, b); t2:SetVertexColor(Light(r, g, b)) end,
    }
end

function B.shockwave(f, P)
    local pulse, over, top = Layers(f)
    local glow = Tex(pulse, ART .. "glow", 120, 120, "BACKGROUND", "ADD")
    glow:SetAlpha(0.6)
    local core = Tex(pulse, ART .. "ring", 56, 56, "ARTWORK", "ADD")
    local waves = {}
    for i = 1, 3 do waves[i] = Tex(over, ART .. "ring", 60, 60, "ARTWORK", "ADD") end
    return {
        pulse = pulse,
        timer = Font(top, 20),
        SetColor = function(r, g, b)
            glow:SetVertexColor(r, g, b); core:SetVertexColor(Light(r, g, b))
            for i = 1, 3 do waves[i]:SetVertexColor(r, g, b) end
        end,
        Animate = function(now, rem)
            local speed = (rem and rem < 3) and 1.6 or 0.8
            for i = 1, 3 do
                local w = waves[i]
                local ph = (now * speed + (i - 1) / 3) % 1
                local sz = 56 + 150 * ph
                w:SetSize(sz, sz)
                w:SetAlpha((1 - ph) ^ 1.5)
            end
        end,
    }
end

function B.brackets(f, P)
    local pulse, over, top = Layers(f)
    local glow = Tex(pulse, ART .. "glow", 150, 150, "BACKGROUND", "ADD")
    glow:SetAlpha(0.6)
    local border = over:CreateTexture(nil, "BORDER")
    border:SetColorTexture(0, 0, 0, 1); border:SetSize(48, 48); border:SetPoint("CENTER")
    local icon = Tex(over, P.icon, 44, 44, "ARTWORK")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local corners, coords = {}, { { 0, 1, 0, 1 }, { 1, 0, 0, 1 }, { 0, 1, 1, 0 }, { 1, 0, 1, 0 } }
    local signs = { { -1, 1 }, { 1, 1 }, { -1, -1 }, { 1, -1 } }
    for i = 1, 4 do
        local c = Tex(pulse, ART .. "corner", 40, 40, "OVERLAY", "ADD")
        c:SetTexCoord(unpack(coords[i]))
        corners[i] = c
    end
    local timer = Font(top, 18)
    timer:SetPoint("CENTER", 0, -48)
    local lastD, lastA
    local s
    s = {
        pulse = pulse,
        timer = timer,
        SetColor = function(r, g, b)
            glow:SetVertexColor(r, g, b)
            local lr, lg, lb = Light(r, g, b)
            for i = 1, 4 do corners[i]:SetVertexColor(lr, lg, lb) end
        end,
        -- The corners breathe in and out; they move by half pixels, only when the step changes
        Animate = function(_, _, p)
            local d = floor((30 + 6 * p) * 2 + 0.5) / 2
            local a = s.angle or 0
            if d == lastD and a == lastA then return end
            lastD, lastA = d, a
            local c, sn = cos(a), sin(a)
            for i = 1, 4 do
                local x, y = signs[i][1] * d, signs[i][2] * d
                corners[i]:SetPoint("CENTER", f, "CENTER", x * c - y * sn, x * sn + y * c)
                corners[i]:SetRotation(a)
            end
        end,
    }
    return s
end

-- None (0.23.30, asked twice on CurseForge for Arcane Blast): no picture at all, only the time
-- left and, for procs with stacks, the dots. Both are switched on or off apart (Style tab).
function B.none(f, P)
    local _, _, top = Layers(f)
    return {
        timer = Font(top, 24),
        SetColor = function() end,
    }
end
-- Whether the None style leaves something to show for this alert: a time left or stacks
-- (Execute, Hammer of Wrath... have neither: None is greyed out for them, and never used)
function D.NoneFits(key)
    local p = ns.PROC_BY[key]
    return p and (p.stacks or not p.noTimer) and true or false
end

-- The game's modern proc glow (animated), around the icon of the spell to cast
local PROC_LOOP = "UI-HUD-ActionBar-Proc-Loop-Flipbook"
local function HasAtlas(name)
    local ok, info = pcall(function() return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) end)
    return ok and info ~= nil
end

-- 0.23.29 (CurseForge, Niklas_Ky; drani21 in October): the glow is 30 pictures on one sheet,
-- played one after the other. When the animation doesn't run (a frame the game shows itself,
-- where nothing can be animated in a fight), the game drew the whole sheet: a grid of yellow
-- squares over the icon. Now, whenever it doesn't play, only its first picture is shown.
function B.procglow(f, P)
    local _, over, top = Layers(f)
    local border = over:CreateTexture(nil, "BORDER")
    border:SetColorTexture(0, 0, 0, 1); border:SetSize(56, 56); border:SetPoint("CENTER")
    local icon = Tex(over, P.icon, 52, 52, "ARTWORK")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local loop = over:CreateTexture(nil, "OVERLAY")
    loop:SetSize(52 * 1.4, 52 * 1.4); loop:SetPoint("CENTER")
    local ag
    -- 0.23.32 (seen by Ben when the settings open the first time): the first picture cut out of
    -- the sheet came out wrong in game. Now, while the glow doesn't play, it is simply hidden:
    -- the icon and its border stay. It shows again as soon as its animation plays.
    local function still() loop:SetAlpha(0) end
    pcall(function()
        loop:SetAtlas(PROC_LOOP)
        ag = loop:CreateAnimationGroup()
        ag:SetLooping("REPEAT")
        local fb = ag:CreateAnimation("FlipBook")
        fb:SetFlipBookRows(6); fb:SetFlipBookColumns(5); fb:SetFlipBookFrames(30)
        fb:SetDuration(1)
        ag:SetScript("OnStop", still)
        ag:SetScript("OnFinished", still)
    end)
    still()
    local function play()
        if not ag then return end
        local okP, playing = pcall(ag.IsPlaying, ag)
        if not (okP and playing) then
            -- the whole sheet back first: the animation cuts it into its 30 pictures itself
            pcall(loop.SetAtlas, loop, PROC_LOOP)
            pcall(ag.Play, ag)
            okP, playing = pcall(ag.IsPlaying, ag)
        end
        if okP and playing then loop:SetAlpha(1) else still() end
    end
    -- 0.23.29: refused in a frame the game shows itself ("blocked by secret aspects"). Before, the
    -- refusal stopped the build half way: the icon and the whole sheet stayed on screen, out of
    -- Shadowflare's reach (even after picking another style), until a /reload.
    pcall(f.HookScript, f, "OnShow", play)
    -- 0.23.33 (seen by Ben): a glow built already on screen (the settings, opened the first time)
    -- gets no OnShow, so its animation never started until another tab was opened. Started now,
    -- and once more on the next frame, when everything is in place.
    play()
    if C_Timer and C_Timer.After then C_Timer.After(0, play) end
    return {
        timer = Font(top, 22),
        SetColor = function() end,  -- keeps the game's gold
        OnAppear = play,
    }
end

-- Classic: the game's own proc art (spell activation overlays), by file ID
local probeFrame
local function FileExists(file)
    if not probeFrame then
        probeFrame = CreateFrame("Frame")
        probeFrame:Hide()
        probeFrame.t = probeFrame:CreateTexture()
    end
    local ok, res = pcall(probeFrame.t.SetTexture, probeFrame.t, file)
    probeFrame.t:SetTexture(nil)
    return ok and res ~= false
end

local function Overlay(f, def)
    local pulse, _, top = Layers(f)
    local tex, rot = {}, nil
    if def.layout == "top" then
        local t = pulse:CreateTexture(nil, "ARTWORK")
        art(t, def.file); t:SetSize(230, 115); t:SetPoint("BOTTOM", f, "CENTER", 0, 10)
        tex[1] = t
        rot = { { t, 0, 67.5 } }
    else
        local l, r = ArcPair(pulse, f, def.file, 110, 220, 40)
        tex[1], tex[2] = l, r
        rot = { { l, -95, 0 }, { r, 95, 0 } }
    end
    for _, t in ipairs(tex) do t:SetBlendMode("ADD") end
    return {
        rot = rot,
        sides = (def.layout ~= "top") and { { tex[1] }, { tex[2] } } or nil,
        pulse = pulse, pA = 0.6, pB = 0.4,
        timer = Font(top, 20),
        SetColor = function(r, g, b, tint)
            for _, t in ipairs(tex) do
                if tint then t:SetVertexColor(r, g, b) else t:SetVertexColor(1, 1, 1) end
            end
        end,
    }
end

----------------------------------------------------------------------
-- The catalog: modern styles drawn by the addon, classic ones are the game's own art.
-- File IDs of the game's proc art: public client listfile.
----------------------------------------------------------------------
local MODERN = { "arcs", "crescent", "ring", "shockwave", "sigil", "brackets", "icon", "procglow", "bar", "text" }
local CLASSIC = {
    -- 0.23.15: Backlash and Blood Surge are wide pictures (256 x 128, read from their files):
    -- drawn on top, as the game does, no longer squeezed on the sides
    { 449492, "Nightfall" }, { 460830, "Backlash", "top" }, { 801266, "Backlash (green)", "top" },
    { 458741, "Molten Core" }, { 801268, "Molten Core (green)" }, { 449491, "Imp Empowerment" },
    { 801267, "Imp Empowerment (green)" }, { 2851787, "Demonic Core" }, { 592058, "Surge of Darkness" },
    { 627609, "Shadow of Death" }, { 656728, "Shadow Word: Insanity" }, { 461878, "Dark Transformation" },
    { 449493, "Sudden Death" }, { 449494, "Sword and Board" }, { 449487, "Blood Surge", "top" },
    { 627610, "Ultimatum" }, { 962497, "Raging Blow" },
    { 460831, "Fury of Stormrage", "top" }, { 449490, "Hot Streak" }, { 450913, "Art of War" },
    { 469752, "Serendipity", "top" }, { 450914, "Eclipse (moon)" }, { 450915, "Eclipse (sun)" },
    -- Added in 0.15.0 (the iconic Fingers of Frost art first)
    { 449489, "Frozen Fingers" }, { 449486, "Arcane Missiles" }, { 449488, "Brain Freeze", "top" },
    { 457658, "Impact", "top" }, { 450930, "Rime", "top" }, { 450926, "Lock and Load", "top" },
    { 450928, "Master Marksman", "top" }, { 450927, "Maelstrom Weapon", "top" },
    { 467696, "Fulmination", "top" }, { 463452, "Shooting Stars", "top" },
    { 450929, "Nature's Grace" }, { 510823, "Omen of Clarity (feral)" }, { 450933, "Surge of Light" },
    { 459313, "Daybreak" }, { 458740, "Killing Machine" }, { 450932, "Sudden Doom" },
    { 450917, "Arc 1" }, { 450918, "Arc 2" }, { 450919, "Arc 3" }, { 450920, "Arc 4" },
    { 450921, "Arc 5" }, { 450922, "Arc 6" },
    { 450923, "Top 1", "top" }, { 450924, "Top 2", "top" },
}

-- Retail (0.23.15, asked on CurseForge): the game's newer proc art, from the public client
-- listfile. Tall pictures (128 x 256) go on the sides, wide ones (256 x 128) on top; sizes
-- read from the files where they could be found, the others guessed from the name (marked ?).
-- The ones this client lacks are not listed (as for the classic ones).
local RETAIL = {
    -- Numbered series are the steps of one picture building up (seen by Ben in game): only the
    -- full one is kept (Arcane Missiles 3, Maelstrom Weapon 4, Thrill of the Hunt 3, Ox 3)
    { 1027133, "Arcane Missiles" }, { 1028139, "Maelstrom Weapon", "top" }, { 1029140, "Thrill of the Hunt" },
    { 450916, "Focus Fire" },                 -- ?
    { 774420, "Tooth and Claw" }, { 898423, "Predatory Swiftness", "top" },
    { 1518303, "Predatory Swiftness (green)", "top" }, { 510822, "Berserk" },   -- ? (green, Berserk)
    { 450925, "Grand Crusader" }, { 459314, "Hand of Light" }, { 511469, "Denounce" },   -- ?
    { 1057288, "Echo of the Elements" }, { 2851788, "High Tide", "top" },
    { 450931, "Slice and Dice" }, { 1030393, "Bandit's Guile" },              -- ? (Slice and Dice)
    { 511104, "Blood Boil" }, { 511105, "Necropolis" },                      -- ?
    { 2888300, "Demonic Core (vertical)" },                                  -- ?
    { 1028092, "Ox" },                                                       -- ?
    { 623951, "Serpent" }, { 623952, "Tiger" }, { 603338, "Dark Tiger" }, { 603339, "White Tiger" },   -- ? (Tiger, Dark Tiger)
    { 1001511, "Blackout Kick" }, { 1001512, "Tiger Palm" },                 -- ?
}

ns.CATALOG, ns.BY_KEY = {}, {}
local function OverlayBuilder(def) return function(f) return Overlay(f, def) end end
for _, key in ipairs(MODERN) do
    local def = { key = key, family = "modern", build = B[key] }
    if key == "procglow" then def.available = function() return HasAtlas(PROC_LOOP) end end
    table.insert(ns.CATALOG, def)
    ns.BY_KEY[key] = def
end
-- Shadowflare's own HD pictures (0.23.17, asked by Ben): drawn for Shadowflare at 256 x 512,
-- twice the size of the game's pictures, so they stay sharp. Drawn on two sides exactly like the
-- game's pictures (Sides, Spacing, Rotation and the stack looks work the same), in the Modern
-- group, with their own colors unless "Color ... too" is ticked. Files in Art\ (32-bit TGA).
D.HD = { "umbra", "hellfire", "wildgrowth", "rend", "stormcall" }
for _, key in ipairs(D.HD) do
    local def = { key = key, family = "modern", file = ART .. key, name = L["S_" .. key] or key, layout = "sides", hd = true }
    def.build = OverlayBuilder(def)
    table.insert(ns.CATALOG, def)
    ns.BY_KEY[key] = def
end
-- None (0.23.30): last of the Modern group, after the HD pictures
do
    local def = { key = "none", family = "modern", build = B.none }
    table.insert(ns.CATALOG, def)
    ns.BY_KEY.none = def
end
for _, fam in ipairs({ { "classic", CLASSIC }, { "retail", RETAIL } }) do
    for _, c in ipairs(fam[2]) do
        local def = { key = "blz" .. c[1], family = fam[1], file = c[1], name = c[2], layout = c[3] or "sides" }
        def.build = OverlayBuilder(def)
        def.available = function() return FileExists(def.file) end
        table.insert(ns.CATALOG, def)
        ns.BY_KEY[def.key] = def
    end
end

-- Sharp size (0.23.17, asked by Ben): the size where one pixel of the game's picture is one pixel
-- of the screen, for the game's own pictures (Classic, Retail). A side is 110 x 220 units for a
-- 128 x 256 file, a top piece 230 x 115 for 256 x 128. One unit is (screen height / 768) x the
-- UI's scale in screen pixels. Nil when it can't be worked out or the style is not a game picture.
function D.SharpScale(cfg)
    local def = ns.BY_KEY[D.EffectiveStyle(cfg)]
    if not (def and def.file and not def.hd and (def.family == "classic" or def.family == "retail")) then return nil end
    if not GetPhysicalScreenSize then return nil end
    local ok, _, ph = pcall(GetPhysicalScreenSize)
    if not ok or type(ph) ~= "number" or ph <= 0 then return nil end
    local ok2, es = pcall(UIParent.GetEffectiveScale, UIParent)
    if not ok2 or type(es) ~= "number" or es <= 0 then return nil end
    local ppu = ph / 768 * es
    local ratio = (def.layout == "top") and (256 / 230) or (128 / 110)
    local v = ratio / ppu
    if v < 0.4 then v = 0.4 elseif v > 3 then v = 3 end
    return v
end

function D.StyleName(def)
    if def.file then return def.name end   -- classic and retail: the game's art, by its name
    return L["S_" .. def.key] or def.key
end

-- Whether this client has a style's art. The answer is kept per game build, so the
-- game's files are looked up once, not each time the options open.
function D.Available(def)
    if not def.available then return true end
    if def.isAvail == nil then
        local cache = ns.db and ns.db.artCache
        local build = select(2, GetBuildInfo())
        if cache and cache.build == build and cache.ok[def.key] ~= nil then
            def.isAvail = cache.ok[def.key]
        else
            local ok, v = pcall(def.available)
            def.isAvail = ok and v and true or false
            if ns.db then
                if not (cache and cache.build == build) then
                    cache = { build = build, ok = {} }
                    ns.db.artCache = cache
                end
                cache.ok[def.key] = def.isAvail
            end
        end
    end
    return def.isAvail
end

----------------------------------------------------------------------
-- The shadow under each alert (0.21.1, asked by Ben: on bright ground the alerts could barely
-- be seen). The game's art and Shadowflare's are drawn by adding light, which shows little
-- on a bright floor. A dark copy of the same style, a little bigger, is drawn under it: the
-- floor gets darker where the alert is, and the alert shows in its own color. On dark ground
-- it changes nothing. Strength per proc (Shadow, 0 turns it off).
----------------------------------------------------------------------
SHADE_LIFT, SHADE_SCALE = 14, 1.06
D.SHADE = 0.6
-- Every picture of a built style turned black and drawn normally; texts and swipes hidden
function Darken(frame)
    local regions = { frame:GetRegions() }
    for _, r in ipairs(regions) do
        local kind = r.GetObjectType and r:GetObjectType()
        if kind == "Texture" then
            pcall(r.SetBlendMode, r, "BLEND")
            r:SetVertexColor(0, 0, 0)
            pcall(r.SetDesaturated, r, false)
        elseif kind == "FontString" then
            r:Hide()
            r.Show = r.Hide   -- a name set later stays hidden too
        end
    end
    local kids = { frame:GetChildren() }
    for _, c in ipairs(kids) do
        local kind = c.GetObjectType and c:GetObjectType()
        if kind == "Cooldown" then c:Hide(); c.Show = c.Hide
        elseif kind == "StatusBar" then
            pcall(c.SetStatusBarColor, c, 0, 0, 0)
            c.SetStatusBarColor = function() end
            Darken(c)
        else
            Darken(c)
        end
    end
end
function D.SetShade(s, P)
    local host = s and s.shadeHost
    if not host then return end
    local cfg = P and P.key and ns.PROC_BY[P.key] and ns.Cfg(P.key)
    local v = cfg and cfg.shadow
    if type(v) ~= "number" then v = D.SHADE end
    host:SetAlpha(v)
    host:SetShown(v > 0.001)
end

-- Builds a style into any frame (the alert, or a preview card in the options),
-- for one proc (P: its icon, name and short line)
function D.Build(f, key, P)
    local def = ns.BY_KEY[key]
    if not def or not D.Available(def) then def = ns.BY_KEY.arcs end
    P = P or ns.Info(ns.Selected())
    -- The shadow (0.21.1): made first, so the style itself is drawn above it
    local host = CreateFrame("Frame", nil, f)
    host:SetAllPoints(f)
    f.sfLift = SHADE_LIFT
    fontLog = {}
    local okB, s = pcall(def.build, f, P)
    local made = fontLog
    fontLog = nil
    if not okB then
        pcall(f.Hide, f)   -- 0.23.29: nothing half built left on screen
        error(s, 0)
    end
    s.fonts = made
    s.frame, s.key = f, def.key
    s.pA, s.pB = s.pA or 0, s.pB or 1
    local ok, sh = pcall(def.build, host, P)
    if ok and type(sh) == "table" then
        sh.frame, sh.key = host, def.key
        host:SetScale(SHADE_SCALE)
        Darken(host)
        s.shade, s.shadeHost = sh, host
        -- It moves, turns and changes with the style
        local anim, refresh, appear, setColor = s.Animate, s.Refresh, s.OnAppear, s.SetColor
        if sh.Animate then
            local sa = sh.Animate
            s.Animate = function(...) if anim then anim(...) end; sa(...) end
        end
        if sh.Refresh then
            local sr = sh.Refresh
            s.Refresh = function(...) if refresh then refresh(...) end; sr(...); Darken(host) end
        end
        if sh.OnAppear then
            local so = sh.OnAppear
            s.OnAppear = function(...) if appear then appear(...) end; so(...) end
        end
        s.SetColor = function(...) setColor(...); D.SetShade(s, P) end
        D.SetShade(s, P)
    else
        host:Hide()
    end
    return s
end

-- Turns a style around its centre (degrees). Round styles look the same at any angle and
-- have nothing to turn; the time left and the icons always stay upright.
-- 0.23.15: spread moves the two halves of a two-sided style apart (each by that much), before
-- the turn, so they stay on their line whatever the angle.
function D.Rotate(s, deg, spread)
    if s.shade then D.Rotate(s.shade, deg, spread) end
    local a = (deg or 0) * math.pi / 180
    spread = tonumber(spread) or 0
    if a == (s.angle or 0) and spread == (s.spread or 0) and s.rotated then return end
    s.angle, s.spread, s.rotated = a, spread, true
    if not s.rot then return end
    local c, sn = cos(a), sin(a)
    for _, e in ipairs(s.rot) do
        local t, x, y = e[1], e[2], e[3]
        if x < 0 then x = x - spread elseif x > 0 then x = x + spread end
        t:ClearAllPoints()
        t:SetPoint("CENTER", s.frame, "CENTER", x * c - y * sn, x * sn + y * c)
        pcall(t.SetRotation, t, a)
    end
end

local function SetTime(s, text)
    if s.SetTime then s.SetTime(text) elseif s.timer then s.timer:SetText(text) end
end

-- A still or breathing preview of a style, for the options page
function D.Preview(s, p, now)
    if s.pulse then s.pulse:SetAlpha(s.pA + s.pB * p) end
    if s.Animate then s.Animate(now or GetTime(), 7, p, 10) end
    SetTime(s, "7")
end

----------------------------------------------------------------------
-- The alerts on screen: one per proc, each with its own place and settings.
--   anchor : position and size (never moves on its own)
--   fader  : the fade in and out, times the opacity setting
-- One shared driver runs the frame loop, and only while an alert is on screen or fading.
----------------------------------------------------------------------
local driver = CreateFrame("Frame")
driver:Hide()
local alerts, order = {}, {}
D.alerts = alerts
-- The alerts being placed (0.22.0: several at once with "Place all")
D.placingSet = {}
function D.IsPlacing(a) return D.placingSet[a] or false end

local A = {}
A.__index = A

-- 0.23.32 (Ben): the None style has its own two choices, set in the Style tab (time left, stack
-- dots), apart from the settings of the other styles. Its time always sits on the alert.
function D.TimeOnAlert(cfg)
    if D.NoArt(cfg) then return cfg.noneTime ~= false end
    return (cfg.timer and not cfg.timerFree) and true or false
end
function D.TimeApart(cfg)
    if D.NoArt(cfg) then return false end
    return (cfg.timer and cfg.timerFree) and true or false
end
function D.TimeShown(cfg) return D.TimeOnAlert(cfg) or D.TimeApart(cfg) end
local function FreeTimer(cfg) return D.TimeApart(cfg) end

-- The time left placed apart (0.23.23, asked by Soothx on CurseForge): its box stays where the
-- player put it, and the text keeps its left (or right) edge still inside it, so it doesn't
-- shift as the digits change width ("9.9", "10", "8"). Centered by default, as before.
function D.TimerBoxW(size) return max(60, size * 3) end
local ALIGN = { left = "LEFT", right = "RIGHT" }
function D.AlignPoint(align) return ALIGN[align] or "CENTER" end
function D.AlignTimer(fs, box, align)
    local P = ALIGN[align] or "CENTER"
    fs:ClearAllPoints()
    fs:SetPoint(P, box, P, 0, 0)
    if fs.SetJustifyH then fs:SetJustifyH(P) end
end

function D:Init()
    -- Proc art the game itself showed for Shadow Trance, if it isn't in the catalog yet
    local seen = ns.db.blizzTex
    if seen and not ns.BY_KEY["blz" .. tostring(seen)] then
        local def = { key = "blz" .. tostring(seen), family = "classic", file = seen, name = L.GAME_ART, layout = "sides" }
        def.build = OverlayBuilder(def)
        table.insert(ns.CATALOG, def)
        ns.BY_KEY[def.key] = def
    end
    driver:SetScript("OnUpdate", function(_, elapsed) D:Tick(elapsed) end)
end

-- The alert of a proc, built the first time it is needed
function D:Get(key)
    local a = alerts[key]
    if a then return a end
    a = setmetatable({ key = key, frames = {}, vis = 0, target = 0, fade = 0, stackK = 1 }, A)
    a.P = ns.Info(key)
    local an = CreateFrame("Frame", nil, UIParent)
    an:SetSize(260, 220)
    an:SetFrameStrata("MEDIUM")
    an:SetMovable(true)
    an:SetClampedToScreen(true)
    a.anchor = an
    local fader = CreateFrame("Frame", nil, an)
    fader:SetAllPoints(an)
    fader:SetAlpha(0)
    fader:Hide()
    a.fader = fader
    alerts[key] = a
    order[#order + 1] = a
    a:ApplyPosition()
    a:ApplyLook()
    return a
end

-- At login: the alerts of the player's class are built now, so a proc never waits
function D:Prepare(class)
    for _, p in ipairs(ns.PROCS) do
        if (p.class == class or p.gear) and ns.Cfg(p.key).enabled and ns.Knows(p.key) then self:Get(p.key) end
    end
    for _, a in ipairs(order) do
        local s = a.cur
        if s and s.Refresh then s.Refresh() end   -- names in the player's language
    end
end

function A:C() return ns.Cfg(self.key) end

-- Built the first time they are needed ---------------------------------------
function A:Edges()
    local e = self.edges
    if e then return e end
    e = CreateFrame("Frame", nil, UIParent)
    e:SetAllPoints(UIParent)
    e:SetFrameStrata("BACKGROUND")
    e:Hide()
    local el = e:CreateTexture(nil, "ARTWORK")
    art(el, ART .. "edge"); el:SetBlendMode("ADD")
    el:SetPoint("TOPLEFT"); el:SetPoint("BOTTOMLEFT"); el:SetWidth(170)
    local er = e:CreateTexture(nil, "ARTWORK")
    art(er, ART .. "edge"); er:SetBlendMode("ADD"); er:SetTexCoord(1, 0, 0, 1)
    er:SetPoint("TOPRIGHT"); er:SetPoint("BOTTOMRIGHT"); er:SetWidth(170)
    e.l, e.r = el, er
    self.edges = e
    local r, g, b = Color(self:C())
    el:SetVertexColor(r, g, b); er:SetVertexColor(r, g, b)
    return e
end

function A:TimerFrame()
    local tf = self.timerFrame
    if tf then return tf end
    local cfg = self:C()
    tf = CreateFrame("Frame", nil, UIParent)
    tf:SetSize(90, 44)
    tf:SetFrameStrata(D.IsPlacing(self) and "FULLSCREEN_DIALOG" or "MEDIUM")
    tf:SetMovable(true)
    tf:SetClampedToScreen(true)
    tf:Hide()
    tf.text = Font(tf, cfg.timerSize)   -- its font is set in ApplyPosition
    self.timerFrame = tf
    self:ApplyPosition()
    tf.text:SetTextColor(Light(Color(cfg)))
    return tf
end

-- The number of stacks (procs with stacks, 0.18.0): its own frame, which follows the alert
function A:StackFrame()
    local sf = self.stackFrame
    if sf then return sf end
    local cfg = self:C()
    sf = CreateFrame("Frame", nil, UIParent)
    sf:SetSize(60, 44)
    sf:SetFrameStrata(D.IsPlacing(self) and "FULLSCREEN_DIALOG" or "MEDIUM")
    sf:SetMovable(true)
    sf:SetClampedToScreen(true)
    sf:Hide()
    sf.text = Font(sf, cfg.stackSize or 24)
    self.stackFrame = sf
    self:ApplyPosition()
    sf.text:SetTextColor(Light(Color(cfg)))
    return sf
end

-- The number written: the stacks of the proc, the maximum while placing or testing
function A:StackText()
    local p = ns.PROC_BY[self.key]
    if not (p and p.stacks) then return "" end
    if D.IsPlacing(self) then return tostring(p.stacks) end
    if p.noOwnCount then return "" end   -- the count can't be known here (Fingers of Frost)
    local n = (self.active and self.stacks) or p.stacks
    return tostring(n)
end

-- Grid shown while placing an alert, drawn like the game's Edit Mode grid (as in Travelcraft):
-- a line every GRID units from the screen centre, the centre lines in gold. The dragged frame
-- snaps to a line by its middle first (so centring is easy), otherwise by one of its edges.
local GRID, SNAP = 32, 8
local grid
local function BuildGrid()
    grid = CreateFrame("Frame", nil, UIParent)
    grid:SetAllPoints(UIParent)
    grid:SetFrameStrata("FULLSCREEN_DIALOG")
    grid:SetFrameLevel(1)
    grid:Hide()
    local function line(vertical, off, center)
        local t = grid:CreateTexture(nil, "BACKGROUND")
        if center then t:SetColorTexture(1, 0.82, 0, 0.45) else t:SetColorTexture(1, 1, 1, 0.1) end
        if vertical then
            t:SetWidth(1); t:SetPoint("TOP", grid, "TOP", off, 0); t:SetPoint("BOTTOM", grid, "BOTTOM", off, 0)
        else
            t:SetHeight(1); t:SetPoint("LEFT", grid, "LEFT", 0, off); t:SetPoint("RIGHT", grid, "RIGHT", 0, off)
        end
    end
    local w, h = UIParent:GetWidth() or 1920, UIParent:GetHeight() or 1080
    for x = 0, w / 2 + GRID, GRID do line(true, x, x == 0); if x > 0 then line(true, -x) end end
    for y = 0, h / 2 + GRID, GRID do line(false, y, y == 0); if y > 0 then line(false, -y) end end
    -- The line the frame is holding on to, brighter
    grid.hv = grid:CreateTexture(nil, "ARTWORK"); grid.hv:SetColorTexture(1, 0.82, 0, 0.9); grid.hv:SetWidth(2); grid.hv:Hide()
    grid.hh = grid:CreateTexture(nil, "ARTWORK"); grid.hh:SetColorTexture(1, 0.82, 0, 0.9); grid.hh:SetHeight(2); grid.hh:Hide()
end

local function ShowGrid(on)
    if on and not grid then BuildGrid() end
    if grid then grid:SetShown(on and true or false) end
end

local function MarkSnap(xLine, yLine)
    if not grid then return end
    grid.hv:ClearAllPoints(); grid.hh:ClearAllPoints()
    if xLine then grid.hv:SetPoint("TOP", grid, "TOP", xLine, 0); grid.hv:SetPoint("BOTTOM", grid, "BOTTOM", xLine, 0) end
    if yLine then grid.hh:SetPoint("LEFT", grid, "LEFT", 0, yLine); grid.hh:SetPoint("RIGHT", grid, "RIGHT", 0, yLine) end
    grid.hv:SetShown(xLine ~= nil); grid.hh:SetShown(yLine ~= nil)
end

local function SnapAxis(c, half)
    local l0 = floor(c / GRID + 0.5) * GRID
    if abs(c - l0) <= SNAP then return l0, l0 end
    local best, bestD, lineAt
    for _, edge in ipairs({ -half, half }) do
        local v = c + edge
        local l = floor(v / GRID + 0.5) * GRID
        local d = abs(v - l)
        if d <= SNAP and (not bestD or d < bestD) then best, bestD, lineAt = l - edge, d, l end
    end
    if best then return best, lineAt end
    return c, nil
end

local function CursorUI()
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    local ux, uy = UIParent:GetCenter()
    return x / s - ux, y / s - uy
end

local function CenterUI(f)
    local cx, cy = f:GetCenter()
    local ux, uy = UIParent:GetCenter()
    local k = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return cx * k - ux, cy * k - uy
end

-- A gold frame over something that can be dragged on the grid; the mouse wheel resizes it.
-- place(x, y) receives the new centre, in screen units from the screen centre.
function D.MakeMover(target, labelText, place, onWheel)
    local m = CreateFrame("Frame", nil, target, BACKDROP)
    m:SetAllPoints()
    m:SetFrameLevel(target:GetFrameLevel() + 30)
    if m.SetBackdrop then
        m:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        m:SetBackdropColor(0, 0, 0, 0.3)
        m:SetBackdropBorderColor(1, 0.82, 0, 1)
    end
    local label = m:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOP", m, "BOTTOM", 0, -4)
    label:SetText(labelText)
    m.label = label
    m:EnableMouse(true)
    local dx, dy
    local function stop()
        m:SetScript("OnUpdate", nil)
        MarkSnap(nil, nil)
    end
    local function drag()
        local mx2, my2 = CursorUI()
        local k = target:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local x, lx = SnapAxis(mx2 + dx, target:GetWidth() * k / 2)
        local y, ly = SnapAxis(my2 + dy, target:GetHeight() * k / 2)
        place(floor(x + 0.5), floor(y + 0.5))
        MarkSnap(lx, ly)
    end
    m:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        local cx, cy = CenterUI(target)
        local mx, my = CursorUI()
        dx, dy = cx - mx, cy - my
        m:SetScript("OnUpdate", drag)
    end)
    m:SetScript("OnMouseUp", stop)
    m:SetScript("OnHide", stop)
    m:EnableMouseWheel(true)
    m:SetScript("OnMouseWheel", function(_, delta) onWheel(delta) end)
    m:Hide()
    return m
end

function A:ApplyPosition()
    local cfg = self:C()
    local an, sc = self.anchor, cfg.scale
    an:SetScale(sc)
    an:ClearAllPoints()
    an:SetPoint("CENTER", UIParent, "CENTER", cfg.x / sc, cfg.y / sc)
    local tf = self.timerFrame
    if tf then
        tf:ClearAllPoints()
        tf:SetPoint("CENTER", UIParent, "CENTER", cfg.x + cfg.tox, cfg.y + cfg.toy)   -- follows the alert
        D.SetFontSafe(tf.text, D.FontFile(cfg.font), cfg.timerSize, "OUTLINE")
        tf:SetSize(D.TimerBoxW(cfg.timerSize), cfg.timerSize * 2)
        D.AlignTimer(tf.text, tf, cfg.timerAlign)
    end
    local sf = self.stackFrame
    if sf then
        local size = cfg.stackSize or 24
        sf:ClearAllPoints()
        sf:SetPoint("CENTER", UIParent, "CENTER", cfg.x + (cfg.sox or 0), cfg.y + (cfg.soy or 55))   -- follows the alert
        D.SetFontSafe(sf.text, D.FontFile(cfg.font), size, "OUTLINE")
        sf:SetSize(max(40, size * 2), size * 2)
    end
    if ns.AuraShow then pcall(ns.AuraShow.Apply, self.key) end   -- the game's frame follows
end

-- The style really shown: the chosen one, or Arcs when this client lacks its art
function D.EffectiveStyle(cfg)
    local key = cfg.style
    local def = ns.BY_KEY[key]
    if not def or not D.Available(def) then key = "arcs" end
    -- 0.23.30: None on an alert with nothing to show (copied from another one): Arcs
    if key == "none" then
        local k = ns.CFG_KEY and ns.CFG_KEY[cfg]
        if k and not D.NoneFits(k) then key = "arcs" end
    end
    return key
end
function D.NoArt(cfg) return D.EffectiveStyle(cfg) == "none" end

function A:Style()
    local key = D.EffectiveStyle(self:C())
    local s = self.frames[key]
    if not s then
        local f = CreateFrame("Frame", nil, self.fader)
        f:SetAllPoints()
        f:Hide()
        s = D.Build(f, key, self.P)
        self.frames[key] = s
    end
    return s
end

-- "Edges only": the glow on the screen edges without the alert itself. While placing,
-- the alert still shows so the time left can be placed next to it.
local function MainShown(a, cfg)
    return not (cfg.edges and cfg.edgesOnly) or D.IsPlacing(a)
end

-- Shows what this alert needs: its style, the screen edges, the time left apart
function A:ShowParts()
    local s, cfg = self.cur, self:C()
    for _, o in pairs(self.frames) do if o ~= s then o.frame:Hide() end end
    s.frame:SetShown(MainShown(self, cfg))
    self.fader:Show()
    if cfg.edges then self:Edges():Show() elseif self.edges then self.edges:Hide() end
    if FreeTimer(cfg) then self:TimerFrame():Show() elseif self.timerFrame then self.timerFrame:Hide() end
    if StackShown(self.key, cfg) then
        local sf = self:StackFrame()
        sf.text:SetText(self:StackText())
        sf:Show()
    elseif self.stackFrame then self.stackFrame:Hide() end
    if s.OnAppear then s.OnAppear() end
    self.timeKey = nil   -- write the time on the next frame
    self:ApplyStack()
end

function A:HideParts()
    self.fader:Hide()
    self.fader:SetScale(1); self.k = 1
    if self.hot then self.hot.frame:SetAlpha(0) end
    self.hotOn = false
    if self.edges then self.edges:Hide() end
    if self.timerFrame then self.timerFrame:Hide() end
    if self.stackFrame then self.stackFrame:Hide() end
end

-- The look below the maximum (0.21.0): when the stacks, the style, the look or placing change
function A:ApplyStack()
    local s = self.cur
    if not s then return end
    local cfg, p = self:C(), ns.PROC_BY[self.key]
    local m = p and p.stacks
    local look = D.StackLook(self.key)
    local n = m and ((D.IsPlacing(self)) and m or (self.stacks or m)) or nil
    local partial = m and n and n < m
    -- Dimmer: the whole alert, brightness from the number of stacks (0.18.0)
    self.stackK = (partial and look == "dim" and not D.NoArt(cfg)) and D.StackK(n, m, p.noDim) or 1
    self.alphaSet = nil
    local main = MainShown(self, cfg)
    local fill = partial and (look == "fillup" or look == "fillleft")
    s.frame:SetAlpha(fill and D.FaintOf(cfg) or 1)
    -- The sides picked for this alert (0.23.15)
    D.ApplySides(s, cfg)
    if fill then
        local clip = D.Clip(self, self.fader, self.fader:GetFrameLevel() + 6)
        self.copy = D.FillCopy(self, self.fader, s, cfg, self.P)
        D.PlaceClip(clip, self.fader, s, look, 0, n / m)
        clip:SetShown(main)
        self.timeKey, self.expSet, self.cpv = nil, nil, nil   -- the copy gets the time and brightness next frame
    else
        self.copy = nil
        if self.clip then self.clip:Hide() end
    end
    if m and look == "dots" and main then
        local d = D.Dots(self, self.fader)
        pcall(d.SetFrameLevel, d, self.fader:GetFrameLevel() + 40)
        D.SetDots(d, self.fader, s, m, 1, n, true, cfg)
    elseif self.dots then
        self.dots:Hide()
    end
end

function A:ApplyLook()
    local cfg = self:C()
    local s = self:Style()
    self.cur = s
    if s.Refresh then s.Refresh() end
    local r, g, b = Color(cfg)
    s.SetColor(r, g, b, cfg.tintClassic)
    D.Rotate(s, cfg.rotation, D.SpacingOf(cfg))
    D.ApplySides(s, cfg)
    D.ApplyFont(s, cfg.font)
    -- Built ahead when switched on, so the first proc has nothing to build
    if cfg.edges then self:Edges() end
    if FreeTimer(cfg) then self:TimerFrame() end
    if self.edges then self.edges.l:SetVertexColor(r, g, b); self.edges.r:SetVertexColor(r, g, b) end
    if self.timerFrame then self.timerFrame.text:SetTextColor(Light(r, g, b)) end
    if StackShown(self.key, cfg) then self:StackFrame() end
    if self.stackFrame then self.stackFrame.text:SetTextColor(Light(r, g, b)) end
    self.fader:SetAlpha(cfg.alpha * self.fade)
    self.alphaSet = nil
    self.expSet = nil
    if self.vis > 0 or self.target > 0 then self:ShowParts() end
    for _, o in pairs(self.frames) do if o ~= s then o.frame:Hide() end end
    self:ApplyStack()
    if ns.AuraShow then pcall(ns.AuraShow.Apply, self.key) end   -- the game's frame follows
end

-- What is on screen now: the proc, or the placing preview
function A:UpdateTarget()
    local want = self.active or D.IsPlacing(self)
    local was = self.target
    self.target = want and 1 or 0
    if want then
        if self.vis == 0 then self:ShowParts() end
        if self.vis == 0 or was == 0 then
            self.exitUsed = nil
            self:Tick(0)   -- everything in place before the first frame is drawn
        end
        self.running = true
        driver:Show()
    elseif self.vis > 0 then
        if was == 1 then self.hideAt = GetTime() end   -- the way out starts now
        self.running = true
        driver:Show()
    else
        self:HideParts()
        self.running = false
    end
    if self.timerFrame and not FreeTimer(self:C()) then self.timerFrame:Hide() end
    if self.stackFrame and not StackShown(self.key, self:C()) then self.stackFrame:Hide() end
end

-- Called by the detection for every proc; an alert is only built when it has to show.
-- When the game itself shows a proc's alert (AuraShow.lua), Shadowflare's own one only
-- shows for a test (fromTest) or while placing.
-- used (0.23.0): when the proc ends, whether its spell was cast (a burst) or it ran out (a fade)
function D:Set(key, active, exp, dur, fromTest, stacks, used)
    if active and not fromTest and ns.AuraShow and ns.AuraShow.Owns(key) then active, exp = false, nil end
    local a = alerts[key]
    if not a then
        if not active then return end
        a = self:Get(key)
    end
    dur = dur or ns.DURATION
    -- Stacks: a new count only changes the number and how bright the alert is
    local newCount = false
    if active and stacks ~= a.stacks then
        a.stacks = stacks
        a:ApplyStack()   -- brightness, fill or dots for this number of stacks (0.21.0)
        newCount = true
    end
    if active == a.active and exp == a.exp and dur == a.dur then
        if newCount and a.stackFrame then a.stackFrame.text:SetText(a:StackText()) end
        return
    end
    if active and not a.active then a.shownAt, a.accentAt = GetTime(), nil end
    if not active and a.active then a.exitUsed = used and true or false end
    a.active, a.exp, a.dur = active, exp, dur
    -- the number once the alert knows it is on (an alert coming back during its way out
    -- keeps its parts, and would show the maximum)
    if a.stackFrame then a.stackFrame.text:SetText(a:StackText()) end
    if not exp then a.rem = nil end   -- no time left (a state such as Execute)
    a.expSet = nil
    a:UpdateTarget()
end

-- 0.23.27: Overpower or Revenge seen in another stance: the stance to take, under the alert,
-- with its icon and its name in the player's language (from the game)
function D:SetHint(key, stance)
    local a = alerts[key]
    if not a then
        if not stance then return end
        a = self:Get(key)
    end
    if a.hintStance == stance then return end
    a.hintStance = stance
    local h = a.hint
    if not stance then
        if h then h:Hide() end
        return
    end
    if not h then
        h = a.fader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        h:SetPoint("TOP", a.anchor, "CENTER", 0, -96)
        a.hint = h
    end
    local name = ns.SpellName(stance) or L["STANCE_" .. stance] or ""
    local icon = ns.SpellIcon(stance)
    h:SetText((icon and ("|T" .. icon .. ":18:18:0:0|t ") or "") .. name)
    h:Show()
end

-- A proc that comes again while shown, or reaches its maximum of stacks: the punch of its
-- entrance again (0.23.0)
function D:Accent(key)
    local a = alerts[key]
    if a and a.active and a.target == 1 and a.vis > 0 then
        a.accentAt = GetTime()
        if not a.running then a.running = true; driver:Show() end
    end
end

-- The way out only, for an alert the game showed itself and just took away (0.23.0): the
-- game removes its frame at once, Shadowflare's own alert plays the way out in its place
function A:PlayExit(used)
    if self.vis > 0 or self.target == 1 then return end
    self.stacks = nil
    self:ShowParts()
    self.vis, self.target = 1, 0
    self.hideAt, self.exitUsed = GetTime(), used and true or false
    self.running = true
    driver:Show()
    self:Tick(0)
end

-- The chosen proc's alert
function D:Cur() return self:Get(ns.Selected()) end

function D:ApplyPosition() self:Cur():ApplyPosition() end
function D:ApplyLook() self:Cur():ApplyLook() end

function D:Center()
    local key = ns.Selected()
    local cfg, p = ns.Cfg(key), ns.PROC_BY[key]
    cfg.x, cfg.y = 0, (p.defaults and p.defaults.y) or 120
    cfg.tox, cfg.toy = 0, -80
    if p.stacks then cfg.sox, cfg.soy = ns.STACK_DEFAULTS.sox, ns.STACK_DEFAULTS.soy end
    self:Cur():ApplyPosition()
    if ns.AuraShow then pcall(ns.AuraShow.Apply, key) end   -- the game's frame follows
    if ns.Options.Refresh then ns.Options:Refresh() end
end

-- The frame loop: only runs while an alert is on screen or fading out
function D:Tick(elapsed)
    local any = false
    for i = 1, #order do
        local a = order[i]
        if a.running then
            a:Tick(elapsed)
            if a.running then any = true end
        end
    end
    if not any then driver:Hide() end
end

function A:Tick(elapsed)
    local now = GetTime()
    local cfg = self:C()
    local target = self.target
    local s = self.cur
    local dur = self.dur or ns.DURATION
    -- The way in, the accent, the way out (0.23.0)
    local anim = D.InOut(cfg, self.key)   -- the way in and out (Still with "No way in or out", at once for onTarget)
    local ma, mk, mh
    if target == 1 then
        local ta = now - (self.shownAt or now)
        if D.IsPlacing(self) then ta = ta % dur end   -- while placing: again each cycle
        ma, mk, mh = D.Enter(anim, ta)
        local at = self.accentAt
        if at then
            local aa, ak, ah, over = D.AccentLook(anim, now - at)
            if over then self.accentAt = nil
            else ma, mk = ma * aa, mk * ak; if ah > mh then mh = ah end end
        end
        self.vis = 1
    else
        local done
        ma, mk, mh, done = D.Exit(anim, now - (self.hideAt or now), self.exitUsed)
        if done then
            self.vis = 0
            self:HideParts()
            self.running = false
            return
        end
        self.vis = max(0.001, ma)
    end
    self.fade = ma
    local rem, exp = self.rem, nil
    if target == 1 then   -- while fading out, the last values stay as they were
        if self.active and self.exp then
            rem = max(0, self.exp - now)
            exp = self.exp
        elseif D.IsPlacing(self) then
            local since = now - (self.shownAt or now)
            local cycle = floor(since / dur)
            rem = dur - (since - cycle * dur)
            exp = (self.shownAt or now) + (cycle + 1) * dur
        end
        self.rem = rem
        if exp ~= self.expSet and s.SetExpiry and exp then
            self.expSet = exp
            s.SetExpiry(exp, dur)
            local c = self.copy
            if c and c.SetExpiry then c.SetExpiry(exp, dur) end
        end
    end
    -- The animation: from the moment the proc showed (while placing, again each cycle)
    local since = now - (self.shownAt or now)
    if D.IsPlacing(self) then since = since % dur end
    local p, k, fa = D.AnimLook(cfg.anim, since, now, rem)
    k = k * mk
    if k ~= self.k then self.k = k; self.fader:SetScale(k) end
    -- The white-hot flare (Impact, Flash, the burst when a proc is used)
    if mh > 0 then
        local h = D.HotCopy(self, self.fader, s, self.P)
        self.hot = h
        h.frame:SetAlpha(mh)
        if h.Animate then h.Animate(now, rem, 1, dur) end
        self.hotOn = true
    elseif self.hotOn then
        self.hotOn = false
        if self.hot then self.hot.frame:SetAlpha(0) end
    end
    local sk = (D.IsPlacing(self)) and 1 or (self.stackK or 1)   -- dimmer below the maximum
    local alpha = cfg.alpha * self.fade * fa * sk
    if alpha ~= self.alphaSet then self.alphaSet = alpha; self.fader:SetAlpha(alpha) end
    -- Brightness set only when it changes (0.20.1): with Still or Impact, nothing moves
    local pu = s.pulse
    if pu then
        local v = s.pA + s.pB * p
        if v ~= self.pv or pu ~= self.pvo then self.pv, self.pvo = v, pu; pu:SetAlpha(v) end
    end
    if s.Animate then s.Animate(now, rem, p, dur) end
    -- The color copy of a filling alert moves with it (0.21.0)
    local c = self.copy
    if c then
        local cp = c.pulse
        if cp then
            local v = c.pA + c.pB * p
            if v ~= self.cpv then self.cpv = v; cp:SetAlpha(v) end
        end
        if c.Animate then c.Animate(now, rem, p, dur) end
    end

    local key = TimeKey(rem)
    if key ~= self.timeKey then
        self.timeKey = key
        local text = TimeText(key)
        SetTime(s, D.TimeOnAlert(cfg) and text or "")
        if c then SetTime(c, D.TimeOnAlert(cfg) and text or "") end
        local tf = self.timerFrame
        if tf and tf:IsShown() then tf.text:SetText(text) end
    end
    local a = cfg.alpha * self.fade
    local e = self.edges
    if cfg.edges and e then
        local v = a * p * 0.8 * sk
        if v ~= self.ev or e ~= self.evo then self.ev, self.evo = v, e; e:SetAlpha(v) end
    end
    local tf = self.timerFrame
    if tf and tf:IsShown() then
        local v = (rem and rem < 3) and a * p or a
        if v ~= self.tv or tf ~= self.tvo then self.tv, self.tvo = v, tf; tf:SetAlpha(v) end
    end
    local sf = self.stackFrame
    if sf and sf:IsShown() and (a ~= self.sv or sf ~= self.svo) then self.sv, self.svo = a, sf; sf:SetAlpha(a) end
end

-- Placing mode. The options window closes so nothing covers the screen; a small dialog
-- at the top says what to do, with Center and Done. Done (or Escape) ends it and, when
-- placing was started from the options, opens them again on Shadowflare's page.
-- Only the chosen proc's alert is placed.
local function SettingsShown()
    return SettingsPanel and SettingsPanel:IsShown()
        or InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown()
        or (ns.Settings and ns.Settings.IsShown and ns.Settings:IsShown())
end

local function CloseSettings()
    pcall(function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then HideUIPanel(InterfaceOptionsFrame) end
    end)
    if ns.Settings and ns.Settings.Hide then pcall(ns.Settings.Hide, ns.Settings) end
end

function D:BuildPlacingDialog()
    local f = CreateFrame("Frame", "ShadowflarePlacingDialog", UIParent, BACKDROP)
    f:SetSize(380, 112)
    f:SetPoint("TOP", UIParent, "TOP", 0, -110)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(100)
    f:SetClampedToScreen(true)
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if f.SetBackdrop then
        f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 } })
    end
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -20)
    title:SetText("Shadowflare")
    f.title = title
    f.help = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.help:SetPoint("TOP", title, "BOTTOM", 0, -8)
    f.help:SetWidth(340)
    local center = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    center:SetSize(120, 22); center:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 18)
    center:SetText(L.CENTER)
    center:SetScript("OnClick", function() D:Center() end)
    local done = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    done:SetSize(120, 22); done:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 18)
    done:SetText(DONE or L.DONE)
    done:SetScript("OnClick", function() f:Hide() end)
    -- 0.23.16 (seen by Ben): hidden BEFORE its OnHide is set. A new frame is shown, so hiding
    -- it after ran SetMoving(false) the first time: the settings window came back at once and
    -- did not come back after Done
    f:Hide()
    f:SetScript("OnHide", function() D:SetMoving(false) end)
    table.insert(UISpecialFrames, "ShadowflarePlacingDialog") -- Escape ends placing
    self.dialog = f
end

-- keys (0.22.0): several alerts placed together, title: what the dialog says they are
function D:StartPlacing(fromOptions, keys, title)
    if InCombatLockdown and InCombatLockdown() then
        ns.Print(L.NOT_IN_COMBAT)
        return
    end
    if not self.dialog then self:BuildPlacingDialog() end
    self.reopenOptions = fromOptions or SettingsShown()
    CloseSettings()
    local list
    if keys then
        list = {}
        for _, k in ipairs(keys) do list[#list + 1] = self:Get(k) end
        if #list == 0 then list = nil end
    end
    self.placingTitle = title
    self:SetMoving(true, list)
end

-- The gold frames you drag: built the first time this alert is placed
function A:Movers()
    if self.mover then return end
    local key = self.key
    local function cfg() return ns.Cfg(key) end
    -- The wheel changes this alert, the one under the mouse (0.22.0: several are placed at once,
    -- and the chosen one in the settings may be another)
    local function set(k, v)
        cfg()[k] = v
        self:ApplyPosition()
        self:ApplyLook()
        if ns.Options.Refresh then ns.Options:Refresh() end
    end
    self.mover = D.MakeMover(self.anchor, L.DRAG, function(x, y)
        cfg().x, cfg().y = x, y
        self:ApplyPosition()
    end, function(delta)
        if IsShiftKeyDown and IsShiftKeyDown() then   -- Shift + wheel turns it
            set("rotation", ((cfg().rotation or 0) + delta * 15) % 360)
            return
        end
        local v = floor((cfg().scale + delta * 0.05) * 100 + 0.5) / 100
        set("scale", max(0.4, min(3, v)))
    end)
    local tf = self:TimerFrame()
    self.timerMover = D.MakeMover(tf, L.DRAG_TIMER, function(x, y)
        cfg().tox, cfg().toy = x - cfg().x, y - cfg().y
        self:ApplyPosition()
    end, function(delta)
        set("timerSize", max(10, min(60, cfg().timerSize + delta * 2)))
    end)
    if ns.PROC_BY[key].stacks then
        local sf = self:StackFrame()
        self.stackMover = D.MakeMover(sf, L.DRAG_STACKS, function(x, y)
            cfg().sox, cfg().soy = x - cfg().x, y - cfg().y
            self:ApplyPosition()
        end, function(delta)
            set("stackSize", max(10, min(60, (cfg().stackSize or 24) + delta * 2)))
        end)
    end
end

-- One alert in or out of placing: its movers, above the grid, shown at its maximum
local function PlaceOne(a, on)
    if on then a:Movers() end
    local cfg = a:C()
    if a.mover then
        a.mover:SetShown(on)
        a.timerMover:SetShown((on and FreeTimer(cfg)) and true or false)
        if a.stackMover then a.stackMover:SetShown((on and StackShown(a.key, cfg)) and true or false) end
    end
    -- Above the grid while placing, back to normal after
    local strata = on and "FULLSCREEN_DIALOG" or "MEDIUM"
    a.anchor:SetFrameStrata(strata)
    if a.timerFrame then a.timerFrame:SetFrameStrata(strata) end
    if a.stackFrame then a.stackFrame:SetFrameStrata(strata) end
    if on then
        a.anchor:SetFrameLevel(20)
        -- The time left above the alert, so it can be grabbed even where they overlap
        if a.timerFrame then a.timerFrame:SetFrameLevel(60) end
        if a.mover then a.mover:SetFrameLevel(50) end
        if a.timerMover then a.timerMover:SetFrameLevel(90) end
        if a.stackFrame then a.stackFrame:SetFrameLevel(60) end
        if a.stackMover then a.stackMover:SetFrameLevel(90) end
        a.shownAt = GetTime()
        a.expSet = nil
    end
    a:UpdateTarget()
    a:ApplyStack()   -- placing shows the maximum
    -- Already on screen: the alert shows while placing, even with "edges only"
    if a.cur and a.vis > 0 then a.cur.frame:SetShown(MainShown(a, cfg)) end
end

-- Placing on or off. list: the alerts to place together (0.22.0, "Place all"); without it,
-- the chosen proc's alert.
function D:SetMoving(on, list)
    on = on and true or false
    if on then
        list = list or { self:Cur() }
        if next(self.placingSet) then   -- already placing others: stop them first, quietly
            local reopen = self.reopenOptions
            self.reopenOptions = false
            self:SetMoving(false)
            self.reopenOptions = reopen
        end
        for _, a in ipairs(list) do self.placingSet[a] = true end
        self.placing = list[1]
        ns.moving = true
        for _, a in ipairs(list) do PlaceOne(a, true) end
        ShowGrid(true)
    else
        local was = {}
        for a in pairs(self.placingSet) do was[#was + 1] = a end
        for a in pairs(self.placingSet) do self.placingSet[a] = nil end
        self.placing = nil
        ns.moving = false
        for _, a in ipairs(was) do PlaceOne(a, false) end
        ShowGrid(false)
    end
    if self.dialog then
        if on then
            local a = list[1]
            local cfg = a:C()
            if #list > 1 then
                self.dialog.title:SetText("Shadowflare - " .. (self.placingTitle or ""))
                self.dialog.help:SetText(L.PLACING_HELP_ALL)
            else
                self.dialog.title:SetText("Shadowflare - " .. a.P.name)
                local help = FreeTimer(cfg) and L.PLACING_HELP_TIMER or L.PLACING_HELP
                if StackShown(a.key, cfg) then help = help .. " " .. L.PLACING_HELP_STACKS end
                self.dialog.help:SetText(help)
            end
            local okH, hh = pcall(self.dialog.help.GetStringHeight, self.dialog.help)
            self.dialog:SetHeight(max(112, 82 + ((okH and type(hh) == "number") and hh or 24)))
            self.dialog:Show()
        elseif self.dialog:IsShown() then
            self.dialog:Hide()
        end
    end
    if not on and self.reopenOptions then
        self.reopenOptions = false
        if C_Timer then C_Timer.After(0, function() ns.Options:Open() end) else ns.Options:Open() end
    end
    if ns.Options.Refresh then ns.Options:Refresh() end
end
