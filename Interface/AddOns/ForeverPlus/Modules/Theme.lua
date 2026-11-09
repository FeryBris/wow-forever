-- The look of every ForeverPlus window, and the page that sets it.
--
-- Hidden from the module list on purpose: a theme is not a feature you switch
-- on and off, it is how the rest is drawn. It is still a module, because that
-- is what gives it a branch in the profile and a place to be re-applied from
-- when the profile changes underneath it.
--
-- Presets rather than free colors. A color picker is a real widget with a
-- real cost, nothing before phase 4 needs one, and a named scheme is what
-- people actually use. The font size is a *factor* rather than an absolute, so
-- the step between large, normal and small survives being scaled.
--
-- Core/Theme.lua holds the schemes, the derived fonts and the machinery that
-- gets a change onto frames that already exist.

local ADDON, FP = ...
local L, N = FP.L, FP.N

local M = FP:RegisterModule("Theme", {
    default = true,
    hidden  = true,   -- see the header: not a switchable feature
    desc    = L["Sets the appearance of the ForeverPlus windows."],
    options = {
        -- The ForeverPlus windows only. Blizzard's own frames are left alone:
        -- skinning them breaks on every patch, and this client is still
        -- moving. The hover says the first half; the owner cut the rest from
        -- it on 2026-10-05, as reasoning rather than a description.
        { key = "scheme", type = "select", default = "midnight",
          label = L["Color scheme"],
          desc  = L["Applies to the ForeverPlus windows only."],
          values = FP:SchemeValues() },

        -- Both asked for on 2026-09-30, from a list of proposals for this page.
        -- On top of whichever scheme is picked, rather than schemes of their
        -- own: eleven schemes times a class and an opacity is not a list.
        { key = "classAccent", type = "toggle", default = false,
          label = L["Show switches in your class color"],
          desc  = L["The switches that are on and the open tab take the color "
               .. "of this character's class, in every color scheme."] },

        { key = "opacity", type = "number", default = 100,
          label = L["Background opacity"], min = 50, max = 100, step = 5,
          format = function(value) return value .. "%" end,
          desc  = L["Sets the background opacity of the ForeverPlus windows, "
               .. "the info bar and the addon's tooltips. At 100 percent, it "
               .. "matches the color scheme."] },

        -- A percentage rather than a size, so the step between headings,
        -- labels and small print stays intact, and the font itself is never
        -- named: a fixed font file renders as empty boxes on a Korean, Chinese
        -- or Russian client. Cut from the hover on 2026-10-05.
        { key = "fontScale", type = "number", default = 100,
          label = L["Text size"], min = 85, max = 130, step = 5,
          format = function(value) return value .. "%" end,
          desc  = L["Sets the text size as a percentage of the game's text "
               .. "size."] },
    },
})

--- This character's class color, or nil. By the class token, which is the
--- same on every client language, never by the class's name.
local function ClassColor()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    token = ok and FP:Plain(token)
    local colors = token and _G.RAID_CLASS_COLORS
    local color = type(colors) == "table" and colors[token]
    if type(color) ~= "table" or type(color.r) ~= "number" then return nil end
    return { color.r, color.g, color.b }
end

function M:Apply()
    FP:ApplyTheme(self.db.scheme, self.db.fontScale, {
        opacity = self.db.opacity,
        accent  = self.db.classAccent and ClassColor() or nil,
    })
end

function M:OnEnable()
    self:Apply()
end

-- Settings changed but the module stays on: an option edit, or a profile
-- switch bringing a different look with it. There is nothing to tear down --
-- applying again *is* the whole job.
function M:Reapply()
    self:Apply()
end

-- ---------------------------------------------------------------------------
-- The "Design" page
--
-- Everything here is anchored to the thing above it rather than placed at a
-- worked-out offset. That matters on this page more than anywhere else: it is
-- the page that changes the text size, wrapped text reflows when it does, and
-- an offset worked out at one size is wrong at the next. Anchors are re-solved
-- by the client; numbers are not.
-- ---------------------------------------------------------------------------

FP:RegisterTab({
    name  = N["Design"],
    order = 70,
    -- Arranges the addon itself and changes nothing in the game, so its tab
    -- has no switch.
    internal = true,

    -- Wrapped text below, so the height has to be asked for rather than
    -- remembered.
    automeasure = true,

    Build = function(_, content)
        local pad   = FP.PANEL_PAD
        local width = content:GetWidth() - 2 * pad

        local heading = FP:SectionHeading(content, L["Design"])
        heading:SetPoint("TOPLEFT", pad, 0)
        heading:SetPoint("TOPRIGHT", -pad, 0)

        -- Rendered by the same builder the module list uses. A page that hand
        -- built its own controls would drift away from them -- the Buffs page
        -- did exactly that, and lost its hover text doing it.
        -- Two rather than eight: a section heading carries its own padding,
        -- where a bare font string had none.
        local previous, gap = heading, -2
        for _, option in ipairs(M.options) do
            local row = FP:BuildOption(content, M, option, width)
            if row then
                row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, gap)
                row:SetPoint("TOPRIGHT", content, "TOPRIGHT", -pad, 0)
                previous, gap = row, -4
            end
        end

        -- No note and no reload button here. The window has a Reload UI of its
        -- own at the bottom of every page, and two of them on one page is one
        -- too many; the note explained something the page demonstrates by
        -- changing while you look at it.

        -- A starting figure only. automeasure works out the real one once the
        -- page is on screen.
        return 120
    end,

    -- The values can move without this page doing it: a profile switch.
    Refresh = function(_, content)
        for _, child in ipairs({ content:GetChildren() }) do
            if child.Refresh then child:Refresh() end
        end
    end,
})
