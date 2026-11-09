-- How every ForeverPlus window looks: color tokens, font sizes, and the two
-- mechanisms that let a change reach what is already on screen.
--
-- Scope is our own windows. Blizzard frames are not touched -- skinning them
-- breaks on every patch, and this client is still moving.
--
-- Written by hand rather than with LibSharedMedia-3.0: that library's license
-- contradicts itself and is unshippable here, and a registry this small is not
-- worth a dependency anyway.
--
-- Two mechanisms, because color and size reach the screen differently:
--
--   Color is baked into a texture when it is created, so a texture has to be
--   repainted to change. Every texture we make is therefore remembered, along
--   with the table it took its color from, and a scheme change walks that
--   list. The tables themselves are overwritten *in place* and never replaced,
--   so that a reference taken years ago still points at the live color.
--
--   Size is not baked in. A FontString follows its font object, so changing
--   the object changes every string using it at once, with nothing to walk.
--   That is why fonts are derived once and then edited rather than rebuilt.

local ADDON, FP = ...
local L = FP.L

-- ---------------------------------------------------------------------------
-- Colors
-- ---------------------------------------------------------------------------

-- The live tokens. Overwritten in place by ApplyTheme, never reassigned.
FP.colors = {
    bg     = { 0.055, 0.055, 0.075, 0.96 },
    border = { 0.26, 0.26, 0.32, 1 },
    on     = { 0.19, 0.74, 0.35, 1 },
    off    = { 0.24, 0.24, 0.28, 1 },
    hover  = { 1, 1, 1, 0.07 },
    btn    = { 0.16, 0.16, 0.20, 1 },

    tabOn  = { 0.20, 0.20, 0.26, 1 },
    tabOff = { 0.10, 0.10, 0.13, 1 },

    textOn  = { 1.00, 1.00, 1.00 },
    textOff = { 0.55, 0.55, 0.60 },
}

-- Named sets, in the order they appear in the list. The first is the one the
-- addon has always looked like, and stays the default.
FP.SCHEMES = {
    {
        id = "midnight", label = L["Midnight"],
        colors = {
            bg     = { 0.055, 0.055, 0.075, 0.96 },
            border = { 0.26, 0.26, 0.32, 1 },
            on     = { 0.19, 0.74, 0.35, 1 },
            off    = { 0.24, 0.24, 0.28, 1 },
            hover  = { 1, 1, 1, 0.07 },
            btn    = { 0.16, 0.16, 0.20, 1 },
            tabOn  = { 0.20, 0.20, 0.26, 1 },
            tabOff = { 0.10, 0.10, 0.13, 1 },
            textOn  = { 1.00, 1.00, 1.00 },
            textOff = { 0.55, 0.55, 0.60 },
        },
    },
    {
        id = "slate", label = L["Slate"],
        colors = {
            bg     = { 0.10, 0.10, 0.11, 0.96 },
            border = { 0.34, 0.34, 0.36, 1 },
            on     = { 0.30, 0.70, 0.40, 1 },
            off    = { 0.30, 0.30, 0.32, 1 },
            hover  = { 1, 1, 1, 0.08 },
            btn    = { 0.20, 0.20, 0.22, 1 },
            tabOn  = { 0.26, 0.26, 0.28, 1 },
            tabOff = { 0.15, 0.15, 0.16, 1 },
            textOn  = { 1.00, 1.00, 1.00 },
            textOff = { 0.62, 0.62, 0.64 },
        },
    },
    {
        -- For a bright room or a small screen: a darker ground, brighter
        -- edges, and no gray text pretending to be readable.
        id = "contrast", label = L["High contrast"],
        colors = {
            bg     = { 0.02, 0.02, 0.03, 0.99 },
            border = { 0.55, 0.55, 0.62, 1 },
            on     = { 0.25, 0.90, 0.40, 1 },
            off    = { 0.32, 0.32, 0.36, 1 },
            hover  = { 1, 1, 1, 0.14 },
            btn    = { 0.22, 0.22, 0.26, 1 },
            tabOn  = { 0.32, 0.32, 0.38, 1 },
            tabOff = { 0.08, 0.08, 0.10, 1 },
            textOn  = { 1.00, 1.00, 1.00 },
            textOff = { 0.80, 0.80, 0.84 },
        },
    },

    -- The rest came on 2026-09-30, at the owner's request. Gilded, Horde and
    -- Alliance are drawn from the game, Jade, Azure and Sunset from the dark
    -- look of three messengers, and Arctic and Autumn from color sets in wide
    -- use around the world, the two of seven he kept after testing them. None
    -- is named after its source. All of them dark: class colors such as the
    -- Priest's white and the Rogue's yellow, and the white inline text across
    -- the addon, would not read on a light ground.
    --
    -- **Sorted by color**, asked for the same day so the list reads as one
    -- run: after the three neutral ones, once round the color wheel from red
    -- to purple. A scheme added later goes where its colors belong rather
    -- than at the end.
    --
    -- A scheme may bring text colors of its own, by font role, see Recolor
    -- below. Gilded, Horde and Alliance do not and keep the client's gold and
    -- white.
    {
        -- Dark red and embers.
        id = "horde", label = L["Horde"],
        colors = {
            bg     = { 0.08, 0.04, 0.035, 0.96 },
            border = { 0.40, 0.16, 0.12, 1 },
            on     = { 0.93, 0.42, 0.13, 1 },
            off    = { 0.25, 0.14, 0.12, 1 },
            hover  = { 1, 0.85, 0.70, 0.07 },
            btn    = { 0.20, 0.08, 0.06, 1 },
            tabOn  = { 0.42, 0.10, 0.07, 1 },
            tabOff = { 0.13, 0.06, 0.05, 1 },
            textOn  = { 1.00, 0.93, 0.85 },
            textOff = { 0.70, 0.55, 0.50 },
        },
    },
    {
        -- Black with gold edges, gold switches and red buttons: the game's
        -- own panels.
        id = "gilded", label = L["Gilded"],
        colors = {
            bg     = { 0.03, 0.03, 0.03, 0.97 },
            border = { 0.62, 0.50, 0.26, 1 },
            on     = { 1.00, 0.82, 0.00, 1 },
            off    = { 0.22, 0.20, 0.17, 1 },
            hover  = { 1, 0.90, 0.60, 0.08 },
            btn    = { 0.45, 0.06, 0.03, 1 },
            tabOn  = { 0.24, 0.19, 0.11, 1 },
            tabOff = { 0.10, 0.08, 0.05, 1 },
            textOn  = { 1.00, 0.96, 0.86 },
            textOff = { 0.65, 0.58, 0.45 },
        },
    },
    {
        -- Warm brown gray with orange, yellow and olive.
        id = "autumn", label = L["Autumn"],
        colors = {
            bg     = { 0.157, 0.157, 0.157, 0.96 },
            border = { 0.314, 0.286, 0.271, 1 },
            on     = { 0.722, 0.733, 0.149, 1 },
            off    = { 0.486, 0.435, 0.392, 1 },
            hover  = { 1, 0.95, 0.85, 0.06 },
            btn    = { 0.235, 0.220, 0.212, 1 },
            tabOn  = { 0.314, 0.286, 0.271, 1 },
            tabOff = { 0.196, 0.188, 0.184, 1 },
            textOn  = { 0.922, 0.859, 0.698 },
            textOff = { 0.659, 0.600, 0.518 },
        },
        text = {
            heading = { 0.996, 0.502, 0.098 },
            normal  = { 0.980, 0.741, 0.184 },
            button  = { 0.557, 0.753, 0.486 },
            body    = { 0.922, 0.859, 0.698 },
            faint   = { 0.573, 0.514, 0.455 },
        },
    },
    {
        -- Deep teal gray with green: a messenger's dark look.
        id = "jade", label = L["Jade"],
        colors = {
            bg     = { 0.067, 0.106, 0.129, 0.96 },
            border = { 0.231, 0.290, 0.329, 1 },
            on     = { 0.000, 0.659, 0.518, 1 },
            off    = { 0.216, 0.278, 0.310, 1 },
            hover  = { 1, 1, 1, 0.06 },
            btn    = { 0.125, 0.173, 0.200, 1 },
            tabOn  = { 0.000, 0.361, 0.294, 1 },
            tabOff = { 0.125, 0.173, 0.200, 1 },
            textOn  = { 0.914, 0.929, 0.937 },
            textOff = { 0.525, 0.588, 0.627 },
        },
        text = {
            heading = { 0.024, 0.812, 0.612 },
            normal  = { 0.914, 0.929, 0.937 },
            button  = { 0.024, 0.812, 0.612 },
            body    = { 0.682, 0.729, 0.757 },
            faint   = { 0.525, 0.588, 0.627 },
        },
    },
    {
        -- Cool blue gray with frosted blue.
        id = "arctic", label = L["Arctic"],
        colors = {
            bg     = { 0.180, 0.204, 0.251, 0.96 },
            border = { 0.298, 0.337, 0.416, 1 },
            on     = { 0.533, 0.753, 0.816, 1 },
            off    = { 0.380, 0.431, 0.533, 1 },
            hover  = { 1, 1, 1, 0.06 },
            btn    = { 0.231, 0.259, 0.322, 1 },
            tabOn  = { 0.263, 0.298, 0.369, 1 },
            tabOff = { 0.231, 0.259, 0.322, 1 },
            textOn  = { 0.925, 0.937, 0.957 },
            textOff = { 0.482, 0.533, 0.631 },
        },
        text = {
            heading = { 0.561, 0.737, 0.733 },
            normal  = { 0.533, 0.753, 0.816 },
            button  = { 0.533, 0.753, 0.816 },
            body    = { 0.847, 0.871, 0.914 },
            faint   = { 0.482, 0.533, 0.631 },
        },
    },
    {
        -- Graphite with a bright blue: a messenger's dark look.
        id = "azure", label = L["Azure"],
        colors = {
            bg     = { 0.094, 0.098, 0.102, 0.96 },
            border = { 0.243, 0.251, 0.259, 1 },
            on     = { 0.000, 0.518, 1.000, 1 },
            off    = { 0.227, 0.231, 0.235, 1 },
            hover  = { 1, 1, 1, 0.06 },
            btn    = { 0.227, 0.231, 0.235, 1 },
            tabOn  = { 0.050, 0.270, 0.550, 1 },
            tabOff = { 0.141, 0.145, 0.149, 1 },
            textOn  = { 0.894, 0.902, 0.922 },
            textOff = { 0.690, 0.702, 0.722 },
        },
        text = {
            heading = { 0.200, 0.600, 1.000 },
            normal  = { 0.894, 0.902, 0.922 },
            button  = { 0.200, 0.600, 1.000 },
            body    = { 0.690, 0.702, 0.722 },
            faint   = { 0.541, 0.553, 0.569 },
        },
    },
    {
        -- Navy and royal blue with gold edges.
        id = "alliance", label = L["Alliance"],
        colors = {
            bg     = { 0.035, 0.055, 0.11, 0.96 },
            border = { 0.55, 0.45, 0.22, 1 },
            on     = { 0.25, 0.55, 0.95, 1 },
            off    = { 0.18, 0.21, 0.30, 1 },
            hover  = { 0.80, 0.90, 1, 0.07 },
            btn    = { 0.09, 0.13, 0.25, 1 },
            tabOn  = { 0.10, 0.20, 0.42, 1 },
            tabOff = { 0.06, 0.09, 0.17, 1 },
            textOn  = { 1.00, 1.00, 1.00 },
            textOff = { 0.62, 0.68, 0.82 },
        },
    },
    {
        -- Black with purple, pink and orange: a messenger's dark look, and
        -- the gradient it is known for, spread across the window.
        id = "sunset", label = L["Sunset"],
        colors = {
            bg     = { 0.020, 0.020, 0.020, 0.96 },
            border = { 0.212, 0.212, 0.212, 1 },
            on     = { 0.627, 0.200, 1.000, 1 },
            off    = { 0.212, 0.212, 0.212, 1 },
            hover  = { 1, 1, 1, 0.07 },
            btn    = { 0.149, 0.149, 0.149, 1 },
            tabOn  = { 0.240, 0.120, 0.400, 1 },
            tabOff = { 0.071, 0.071, 0.071, 1 },
            textOn  = { 0.961, 0.961, 0.961 },
            textOff = { 0.659, 0.659, 0.659 },
        },
        text = {
            heading = { 0.882, 0.188, 0.424 },
            normal  = { 0.961, 0.961, 0.961 },
            button  = { 0.969, 0.467, 0.216 },
            body    = { 0.750, 0.750, 0.750 },
            faint   = { 0.451, 0.451, 0.451 },
        },
    },
}

function FP:GetScheme(id)
    for _, scheme in ipairs(self.SCHEMES) do
        if scheme.id == id then return scheme end
    end
    return self.SCHEMES[1]
end

--- The scheme list in the shape a select option wants.
--
-- With the scheme's main colors for the open list, asked for by the owner on
-- 2026-09-30, see FP:SchemeSwatch: after the name and flush right, his layout.
-- The closed box shows the name alone, where the colors would crowd a long
-- name into an ellipsis, and the window around it already wears the scheme.
function FP:SchemeValues()
    local out = {}
    for index, scheme in ipairs(self.SCHEMES) do
        out[index] = { scheme.id, scheme.label, right = self:SchemeSwatch(scheme) }
    end
    return out
end

-- Every texture we have made, with the table it took its color from. Never
-- pruned: a WoW frame cannot be destroyed, so nothing in here goes stale.
local painted = {}

--- Remembers a texture so that a scheme change can repaint it.
function FP:TrackTexture(texture, color)
    painted[#painted + 1] = { texture = texture, color = color }
end

local function Repaint()
    for index = 1, #painted do
        local entry = painted[index]
        -- Each in its own pcall: one texture belonging to a frame that has
        -- gone strange must not stop the rest of the window changing color.
        pcall(entry.texture.SetColorTexture, entry.texture, unpack(entry.color))
    end
end

-- ---------------------------------------------------------------------------
-- Contrast
--
-- The owner's request of 2026-10-06: always enough contrast between text and
-- the ground it stands on, on the info bar and in the addon's own tooltips.
-- Measured the way WCAG measures it, as the ratio of the two relative
-- luminances, each plus 0.05, and 4.5 is what WCAG asks of ordinary text.
-- Against a scheme's background as if it were opaque: below full opacity the
-- game world shows through, and nothing can promise contrast over snow.
-- ---------------------------------------------------------------------------

FP.READABLE = 4.5

local function Channel(c)
    if c <= 0.03928 then return c / 12.92 end
    return ((c + 0.055) / 1.055) ^ 2.4
end

local function Luminance(r, g, b)
    return 0.2126 * Channel(r) + 0.7152 * Channel(g) + 0.0722 * Channel(b)
end

local function Ratio(a, b)
    if a < b then a, b = b, a end
    return (a + 0.05) / (b + 0.05)
end

--- The contrast of two colors, from 1 for the same to 21 for black on white.
function FP:Contrast(fg, ground)
    return Ratio(Luminance(fg[1], fg[2], fg[3]),
        Luminance(ground[1], ground[2], ground[3]))
end

--- A text color that reads on a ground: the color itself where it does, or
--- the least mix of it toward white that does, toward black on a light
--- ground. The mix keeps the hue, so a red warning still reads as red.
-- @param ground  { r, g, b }; the scheme's background when left out
-- @return r, g, b
function FP:Readable(r, g, b, ground)
    ground = ground or self.colors.bg
    local back = Luminance(ground[1], ground[2], ground[3])
    if Ratio(Luminance(r, g, b), back) >= self.READABLE then return r, g, b end

    local target = (Ratio(1, back) >= Ratio(0, back)) and 1 or 0
    local low, high = 0, 1
    for _ = 1, 16 do
        local mid = (low + high) / 2
        local lum = Luminance(r + (target - r) * mid, g + (target - g) * mid,
            b + (target - b) * mid)
        if Ratio(lum, back) >= self.READABLE then high = mid else low = mid end
    end
    return r + (target - r) * high, g + (target - g) * high, b + (target - b) * high
end

-- ---------------------------------------------------------------------------
-- Fonts
--
-- The locale rule forbids naming a font file: Korean, Chinese and Russian
-- clients ship different ones, and a hardcoded path renders as empty boxes
-- there. So the path and the flags are taken from the client's own font object
-- and only the size is replaced. Measured on this client -- GetFont, SetFont
-- and CopyFontObject all answer on GameFontNormal.
-- ---------------------------------------------------------------------------

local ROLES = {
    heading = "GameFontNormalLarge",
    normal  = "GameFontNormal",
    button  = "GameFontNormalSmall",
    body    = "GameFontHighlightSmall",
    faint   = "GameFontDisableSmall",
}

local derived = {}   -- [role] = { font = <our font>, source = <client font> }
local scale   = 1

local function Derive(role)
    if derived[role] then return derived[role] end

    local sourceName = ROLES[role]
    local source     = sourceName and _G[sourceName]
    if not (source and source.GetFont and CreateFont) then return nil end

    local font = CreateFont("ForeverPlusFont" .. role)
    if not font then return nil end

    -- Copies the family, the size and the color in one go, so a role that is
    -- never scaled still looks exactly like the object it came from.
    if font.CopyFontObject then pcall(font.CopyFontObject, font, source) end

    derived[role] = { font = font, source = source }
    return derived[role]
end

local function Rescale()
    for role in pairs(ROLES) do
        local entry = Derive(role)
        if entry then
            local path, size, flags = entry.source:GetFont()
            if path and size then
                pcall(entry.font.SetFont, entry.font, path, size * scale, flags)
            end
        end
    end
end

--- Gives every role its text color: the scheme's, or the client's own where
--- the scheme names none.
--
-- A scheme could only color surfaces until 2026-09-30, and the text kept the
-- client's gold and white under any of them, which suits the game's look and
-- nothing else. The client's color is read off its font object every time
-- rather than remembered, so switching back to a scheme without colors of its
-- own restores exactly what the client has.
--
-- A string that takes its color from the font object follows at once. One
-- that had the color copied onto it is given it again by whoever copied it,
-- see the rows in FP:ApplyLevel.
--
-- Made readable on the scheme's background first, see FP:Readable: since
-- 2026-10-06 a role whose color would sink into the ground is lightened just
-- enough, which reaches the dim small print of a few schemes and nothing else.
local function Recolor(scheme)
    local text = type(scheme.text) == "table" and scheme.text or {}
    for role in pairs(ROLES) do
        local entry = Derive(role)
        local font  = entry and entry.font
        if font and font.SetTextColor then
            local color = text[role]
            if not color and entry.source.GetTextColor then
                color = { entry.source:GetTextColor() }
            end
            if color and color[1] then
                local r, g, b = FP:Readable(color[1], color[2], color[3],
                    scheme.colors.bg)
                pcall(font.SetTextColor, font, r, g, b)
            end
        end
    end
end

-- A square of one color inside a line of text: the client's plain white
-- texture, tinted by the escape's own values from 0 to 255. Twelve units, the
-- height of a row in the drop-down list less its air.
local SQUARE = "|TInterface\\Buttons\\WHITE8X8:12:12:0:0:8:8:0:8:0:8:%d:%d:%d|t"

local function Square(color)
    local function Byte(value)
        return math.floor((tonumber(value) or 0) * 255 + 0.5)
    end
    return SQUARE:format(Byte(color[1]), Byte(color[2]), Byte(color[3]))
end

--- A scheme's primary text color: its own, or the client's gold.
local function PrimaryText(scheme)
    local own = type(scheme.text) == "table" and scheme.text.normal
    if own then return own end
    local source = _G[ROLES.normal]
    if source and source.GetTextColor then
        local r, g, b = source:GetTextColor()
        if r then return { r, g, b } end
    end
    return { 1, 0.82, 0 }
end

--- Three squares in a scheme's main colors, side by side: the active tab, the
--- switch that is on, and the primary text. Derived rather than declared, so
--- a scheme added later brings its own without anybody remembering to.
function FP:SchemeSwatch(scheme)
    local colors = scheme.colors
    return Square(colors.tabOn) .. Square(colors.on) .. Square(PrimaryText(scheme))
end

--- Our font object for a role, or nil if the client would not give us one.
function FP:Font(role)
    local entry = Derive(role)
    if not entry then return nil end
    return entry.font
end

--- A font string in one of our roles.
--
-- Falls back to the client's object under its own name if deriving failed, so
-- a window still has readable text on a client that surprises us.
function FP:FontString(frame, layer, role)
    local fs = frame:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFontObject(self:Font(role) or ROLES[role] or "GameFontHighlightSmall")
    return fs
end

-- ---------------------------------------------------------------------------
-- Applying
-- ---------------------------------------------------------------------------

-- Anything that has to redraw itself when the look changes. A list rather than
-- a call into the menu, because Core does not get to know what a menu is.
local listeners = {}

function FP:OnThemeChanged(fn)
    listeners[#listeners + 1] = fn
end

-- How much of a class color the open tab takes on, over the scheme's own. A
-- quarter keeps the tab dark enough for its white caption with every class,
-- the Priest's white and the Rogue's yellow included, while the switch on it
-- takes the class color whole and stays easy to tell apart.
local ACCENT_TINT = 0.25

--- Puts a scheme and a font size into effect everywhere at once.
-- @param id       scheme id; an unknown one falls back to the first
-- @param percent  font size as a percentage, 100 being the client's own
-- @param extras   optional, both from 2026-09-30:
--                 opacity  the background's alpha as a percentage of the
--                          scheme's own
--                 accent   { r, g, b } for the switches that are on and a
--                          tint of it for the open tab, the class color
function FP:ApplyTheme(id, percent, extras)
    local scheme = self:GetScheme(id)
    extras = extras or {}

    -- In place. Replacing these tables would leave every texture and every
    -- SetTextColor call in the addon pointing at the previous look.
    for token, value in pairs(scheme.colors) do
        local live = self.colors[token]
        if live then
            for i = 1, #value do live[i] = value[i] end
        else
            self.colors[token] = { unpack(value) }
        end
    end

    -- On top of the scheme and into the same live tables, before anything is
    -- repainted from them. Both are set again from the scheme on every call,
    -- so switching either off takes nothing to undo.
    local opacity = tonumber(extras.opacity)
    if opacity then
        opacity = math.max(0, math.min(100, opacity))
        self.colors.bg[4] = (scheme.colors.bg[4] or 1) * opacity / 100
    end
    local accent = extras.accent
    if type(accent) == "table" and accent[3] then
        local on, tab, base = self.colors.on, self.colors.tabOn, scheme.colors.tabOn
        for i = 1, 3 do
            on[i]  = accent[i]
            tab[i] = base[i] + (accent[i] - base[i]) * ACCENT_TINT
        end
    end

    Repaint()

    scale = (tonumber(percent) or 100) / 100
    Rescale()
    -- Before the listeners, which copy role colors onto what they redraw.
    Recolor(scheme)

    for index = 1, #listeners do
        self:Safe("theme listener", listeners[index])
    end
end
