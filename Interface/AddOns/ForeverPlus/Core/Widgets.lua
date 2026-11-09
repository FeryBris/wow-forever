-- Shared widget helpers for every panel the addon draws.
--
-- Deliberately without Blizzard templates (UICheckButtonTemplate,
-- UIPanelDialogTemplate and friends): instantiating one runs Blizzard's OnLoad
-- inside our tainted execution and spreads taint into shared tables. Four
-- textures and a button always work, and taint nothing.
--
-- Colors and fonts come from Core/Theme.lua. Nothing here holds a color of
-- its own beyond the few literals that are not part of the scheme.

local ADDON, FP = ...
local L = FP.L

FP.PANEL_PAD    = 14
FP.PANEL_HEADER = 44

--- A flat colored texture.
--
-- Registered with the theme on the way out. A texture keeps the color it was
-- painted with, so changing a scheme means repainting every one of them, and
-- the theme cannot repaint what it does not know about.
function FP:Texture(frame, layer, color, w, h)
    local t = frame:CreateTexture(nil, layer or "ARTWORK")
    t:SetColorTexture(unpack(color))
    if w and h then t:SetSize(w, h) end
    self:TrackTexture(t, color)
    return t
end

-- ---------------------------------------------------------------------------
-- Structure
--
-- Two elements, and deliberately not one element with a flag on it. Calling
-- both of them a heading is what cost a whole round of questions: they look
-- alike and they do different jobs.
--
--   SectionHeading      a fixed label with a rule, dividing a page into parts.
--                       **Never collapses.** A part of a page that somebody
--                       folded away and forgot comes back later as "the
--                       setting is gone", which is the reason the owner gave
--                       when he chose fixed labels for the module list.
--   CollapsibleHeading  a block that opens and closes, for a list long enough
--                       that folding is navigation rather than hiding. The nine
--                       classes on the Buffs page are the case it exists for,
--                       and they sit *under* a fixed section heading rather
--                       than instead of one.
--
-- Both take a color, because a class block has to carry its class color while
-- looking like everything else in the window.
--
-- Three levels of text across the whole addon, and nothing invents a fourth:
--
--   section heading   role "button", white, with a rule
--   a thing with a switch   role "normal", the font object's own color
--   anything under it       role "body", white, smaller
-- ---------------------------------------------------------------------------

--- Puts a row at one of the two levels a setting can sit at.
--
-- The levels are named for what they mean, never for what they look like:
--
--   primary  a setting that stands on its own
--   sub      a setting that only qualifies the one above it
--
-- The owner drew that line on 2026-09-20, and it is sharper than the one it
-- replaced. "Your own buffs" is not quiet because it happens to be an option,
-- it is quiet because it narrows "Warn about buffs". "Show the remaining time"
-- answers to nothing above it, so it is loud. Being an option is not a level.
--
-- **A level picks a font role and the color arrives with the role.** Nothing
-- here sets a color: that would be a third place a look is decided, after the
-- scheme and the role, and the first of the three to go stale when either of
-- the others moves. It is also what lets the whole scheme be restyled later
-- without hunting for hardcoded gold.
--
-- **Every row given a level is remembered**, since 2026-09-30. The color is
-- copied onto its string below, where it stays, so a scheme that brings text
-- colors of its own has to hand each row its role's color again: the listener
-- after this function does. Keyed by the row, because a row is never
-- destroyed and is leveled once or twice.
local leveled = {}

function FP:ApplyLevel(row, level)
    local text = row and row.text
    if not text or row.isHeading then return end
    row.fpLevel = level
    leveled[row] = true

    local sub  = (level == "sub")
    local role = sub and "body" or "normal"
    local font = self:Font(role)
        or _G[sub and "GameFontHighlightSmall" or "GameFontNormal"]
    if not font then return end

    text:SetFontObject(font)
    if font.GetTextColor then
        local r, g, b = font:GetTextColor()
        if r then text:SetTextColor(r, g, b) end
    end
end

-- Registered here, at load, so it runs before any page redraws itself: the
-- menu's own listener comes later and refreshes rows that color themselves.
FP:OnThemeChanged(function()
    for row in pairs(leveled) do
        FP:ApplyLevel(row, row.fpLevel)
    end
end)

-- **One column for every label in the window.**
--
-- A row's left edge is a gutter with room for two controls, and the text starts
-- after it whether or not either control is there. Before this, a row with a
-- checkbox began its text 22 units in and a row with a stepper began at 1, so
-- "Icon size" sat left of everything around it: the indent described how the
-- row was built rather than what it meant.
--
-- The space is reserved even when it is empty, which is the part that costs
-- something and the part that makes it work. A fold handle appearing in front
-- of a switch must not push that switch's label out of line with its
-- neighbors, and it is exactly that handle which made the misalignment
-- impossible to fix row by row.
--
-- The numbers are the module list's, which the owner had already accepted by
-- eye before any of this was written down.
-- **One width for every control block at the right edge of a row.**
--
-- A stepper is a minus, a number and a plus; a dropdown is one box. They sat at
-- 120 and 130, which is close enough to look like a mistake rather than a
-- choice, and it was one. Derived from the stepper's own parts now, so the two
-- cannot drift apart when a part changes.
--
-- Fixed units rather than a fraction of the row, deliberately: both are
-- anchored to the right edge, so they track together at any resolution, and a
-- label on the left has whatever room is left over.
FP.STEP_BTN   = 22   -- the minus and the plus
FP.STEP_VALUE = 64   -- the number between them
FP.STEP_GAP   = 6
FP.CONTROL_W  = FP.STEP_BTN * 2 + FP.STEP_VALUE + FP.STEP_GAP * 2

FP.ROW_ARROW_X = 3    -- a fold arrow, when the row has one
FP.ROW_BOX_X   = 14   -- a checkbox, when the row has one
FP.ROW_TEXT_X  = 37   -- the label, always

FP.SECTION_H  = 26
FP.COLLAPSE_H = 22

--- Keeps a label inside its row. **Text never leaves its row.**
--
-- A hard rule since 2026-09-27, the owner's words after two labels on the
-- Chat page did both things at once: one ran under a stepper, the other past
-- the edge of the window. *This should never happen anywhere in the addon.*
--
-- So every label built here ends before the control beside it, or at the
-- row's right side when there is none, on one line. A label longer than that
-- is cut short with the client's own ellipsis, and the hover still names it in
-- full. The cut is the safety net, not the design: a label that needs it is a
-- label to shorten, and AGENTS.md says so under *How a page looks*.
--
-- @param edge  the control the label must stop short of, or nil for the row
function FP:FitLabel(text, row, edge, gap)
    if not (text and row) then return end
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    if edge then
        text:SetPoint("RIGHT", edge, "LEFT", -(gap or 8), 0)
    else
        text:SetPoint("RIGHT", row, "RIGHT", -(gap or 4), 0)
    end
end

--- A fixed section label with a rule running out to the right edge.
-- @param color  optional; defaults to the theme's own text color
-- @return the frame, and its height
function FP:SectionHeading(parent, label, color)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetHeight(self.SECTION_H)

    local text = self:FontString(holder, "OVERLAY", "button")
    text:SetPoint("BOTTOMLEFT", 0, 5)
    -- Every widget here translates what it is given to draw, see
    -- Core/Locale.lua: a label marked while its file loaded is still English.
    text:SetText(self:T(label) or "")

    local rule = self:Texture(holder, "ARTWORK", self.colors.border)
    rule:SetPoint("BOTTOMLEFT", text, "BOTTOMRIGHT", 8, 4)
    rule:SetPoint("BOTTOMRIGHT", 0, 4)
    rule:SetHeight(1)

    -- A real Refresh, not an empty one. FP:Texture keeps the color table and
    -- follows a scheme change by itself; a text color is copied at the call
    -- and stays where it was until something puts it back.
    holder.Refresh = function()
        text:SetTextColor(unpack(color or FP.colors.textOn))
    end
    holder:Refresh()

    -- Marked, because it hands out a `text` like a row does and is otherwise
    -- indistinguishable from one. Without this FP:ApplyLevel re-fonted every
    -- heading on a page to the primary role: the headings grew, the class
    -- blocks beside them did not, and it read as the classes having shrunk.
    holder.isHeading = true
    holder.text = text
    return holder, self.SECTION_H
end

--- A block that opens and closes.
--
-- No rule on this one, on purpose: the rule belongs to the fixed heading above
-- it, and repeating it here would make the two look like the same thing again.
--
-- @param isOpen  function, whether the block is open right now
-- @param toggle  function, called on a click before the block is redrawn
-- @return the frame, and its height
function FP:CollapsibleHeading(parent, label, color, isOpen, toggle)
    local holder = CreateFrame("Button", nil, parent)
    holder:SetHeight(self.COLLAPSE_H)

    local hl = self:Texture(holder, "HIGHLIGHT", self.colors.hover)
    hl:SetAllPoints()

    local arrow = self:FontString(holder, "OVERLAY", "faint")
    arrow:SetPoint("LEFT", self.ROW_ARROW_X, 0)

    -- The primary role, not the section one. A block you open sits at the level
    -- of a setting that stands on its own, not at the level of the label that
    -- divides the page: "Druid" reads as large as "Warn in a rested area" and
    -- smaller than neither. Only the color is the exception a class gets.
    local text = self:FontString(holder, "OVERLAY", "normal")
    text:SetPoint("LEFT", self.ROW_TEXT_X, 0)
    self:FitLabel(text, holder)
    text:SetText(self:T(label) or "")

    holder:SetScript("OnClick", function()
        toggle()
        holder:Refresh()
        if holder.OnToggled then holder.OnToggled() end
    end)

    -- No color given means the role decides, which is the rule everywhere else
    -- in the window: a level picks a font role and the color arrives with it.
    -- FP.colors.textOn was standing in for that and is white, so a block with
    -- no class behind it sat at the primary level wearing the sub level's
    -- color. The class blocks were the only callers until the coating list
    -- arrived, and they always pass a color, so nothing gave it away.
    local function RoleColor()
        local font = FP:Font("normal") or _G.GameFontNormal
        if font and font.GetTextColor then
            local r, g, b = font:GetTextColor()
            if r then return r, g, b end
        end
        return unpack(FP.colors.textOn)
    end

    holder.Refresh = function()
        arrow:SetText(isOpen() and "-" or "+")
        if color then
            text:SetTextColor(unpack(color))
        else
            text:SetTextColor(RoleColor())
        end
    end
    holder:Refresh()

    holder.text = text
    return holder, self.COLLAPSE_H
end

--- A border made of four thin textures -- needs no backdrop mixin.
function FP:AddBorder(frame, color, size)
    color = color or self.colors.border
    size  = size or 1

    -- A line one unit thick at a frame edge can round away to nothing, and
    -- which edge loses depends on where the frame happens to land on the pixel
    -- grid. The owner reported the settings window missing its bottom border
    -- while the other three showed, which is exactly that.
    --
    -- PixelUtil snaps a size to whole pixels and exists for this. Asked for
    -- rather than assumed: if this build has no such thing, the plain setter is
    -- used and the line is as fragile as it was, which is no worse than before.
    local function Thickness(texture, vertical)
        local util = _G.PixelUtil
        local fn = util and (vertical and util.SetHeight or util.SetWidth)
        if fn and pcall(fn, texture, size, size) then return end
        if vertical then texture:SetHeight(size) else texture:SetWidth(size) end
    end

    local sides = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = self:Texture(frame, "BORDER", color)
        if side == "TOP" or side == "BOTTOM" then
            t:SetPoint(side .. "LEFT"); t:SetPoint(side .. "RIGHT")
            Thickness(t, true)
        else
            t:SetPoint("TOP" .. side); t:SetPoint("BOTTOM" .. side)
            Thickness(t, false)
        end
        sides[#sides + 1] = t
    end

    -- For a border that means something rather than one that is merely chrome:
    -- BuffExpiry turns it red for a buff that is missing.
    --
    -- A scheme change repaints these with the color they were created in, so
    -- anything using this has to set it again afterwards. That is not a
    -- problem for the one caller there is, which redraws every second anyway,
    -- and making the theme aware of per frame overrides would be a lot of
    -- machinery for one red square.
    function frame:SetBorderColor(r, g, b, a)
        for _, t in ipairs(sides) do t:SetColorTexture(r, g, b, a or 1) end
    end

    return sides
end

function FP:CreateButton(parent, label, width, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, 22)
    local bg = self:Texture(b, "BACKGROUND", self.colors.btn); bg:SetAllPoints()
    self:AddBorder(b)
    local hl = self:Texture(b, "HIGHLIGHT", self.colors.hover); hl:SetAllPoints()
    -- Inside the button, by the rule in FitLabel: a caption too long for its
    -- button is cut short rather than drawn across the border.
    local fs = FP:FontString(b, "OVERLAY", "button")
    fs:SetPoint("LEFT", 4, 0)
    fs:SetPoint("RIGHT", -4, 0)
    fs:SetJustifyH("CENTER")
    fs:SetWordWrap(false)
    fs:SetText(self:T(label))
    b:SetScript("OnClick", onClick)
    -- Exposed so a reused button can be relabeled: the export and import
    -- windows are the same window with a different verb on the button.
    b.label = fs
    return b
end

-- ---------------------------------------------------------------------------
-- The addon's own icon, on the title bar
--
-- Taken from the TOC rather than written out again. `## IconTexture` is
-- already the one place that decides what this addon looks like in the addon
-- list, and a second copy of the path here would be a second thing to keep in
-- step. Asked for on 2026-09-20, in front of the name.
--
-- It points at `Media/Icon.tga`, the project's own logo. The client reads BLP
-- and TGA and never PNG, so the picture in `assets/` cannot be handed to it
-- directly; the TGA is that file at 128 pixels, which is a power of two as
-- the client insists, and it ships inside the addon folder so it travels with
-- the zip. No extension on the path: the client resolves that itself, and
-- naming one would tie the line to a format.
--
-- No texture coordinates are trimmed off it either. That trim exists for
-- Blizzard's icon files, which have a border baked into the picture; our own
-- art fills its own square.
--
-- It sizes itself from the heading font, so it still matches the title after
-- somebody moves the text size slider, and it is left out entirely when the
-- client will not hand the path over: a title with no picture reads fine,
-- where an icon frame with no texture is an invisible hole.
-- ---------------------------------------------------------------------------

local function AddonIcon()
    local get = C_AddOns and C_AddOns.GetAddOnMetadata
    if not get then return nil end

    local ok, path = pcall(get, ADDON, "IconTexture")
    if ok and type(path) == "string" and path ~= "" then return path end
    return nil
end

--- The same path for other files: the minimap button wears the icon too.
function FP:AddonIcon()
    return AddonIcon()
end

--- How tall the title text is, which is what the icon matches.
local function HeadingSize()
    local font = FP:Font("heading")
    if font and font.GetFont then
        local ok, _, size = pcall(font.GetFont, font)
        if ok and type(size) == "number" and size > 0 then return size end
    end
    return 14
end

-- Every panel icon drawn so far. A text size change moves the font under
-- them, and a texture does not follow a font on its own.
local panelIcons = {}

FP:OnThemeChanged(function()
    local side = HeadingSize() + 4
    for _, icon in ipairs(panelIcons) do
        pcall(icon.SetSize, icon, side, side)
    end
end)

--- Lifts a window above the settings window, for good.
--
-- Every panel is DIALOG and toplevel, so a click on one raises it over the
-- others. A question opened from the settings window went behind it at the
-- next click there, reported by the owner on 2026-10-08 with the reload
-- question after picking a language: it could only be reached by closing
-- the settings first. A question, the fill question at a merchant and the
-- export and import window sit a stratum higher, under the drop-down lists
-- and tooltips, and stay in front until they are answered or closed.
function FP:KeepAboveSettings(f)
    f:SetFrameStrata("FULLSCREEN")
    f:HookScript("OnShow", function(self) self:Raise() end)
end

--- A movable, bordered panel with a title bar, a close button and Escape
--- support. The caller fills it and sets its final height.
-- @param globalName  needed for UISpecialFrames, so Escape can close it
-- @param onMoved     called with (point, relPoint, x, y) after a drag
function FP:CreatePanel(globalName, width, title, subtitle, onMoved)
    local PAD, HEADER = self.PANEL_PAD, self.PANEL_HEADER

    local f = CreateFrame("Frame", globalName, UIParent)
    f:SetWidth(width)
    -- Centered here and not left to the caller. A frame without a point has no
    -- position and is simply not drawn -- it does not error, it does not warn,
    -- it is just never there. That has now cost this project two invisible
    -- features, so the default is given out rather than expected back. A
    -- caller with a stored position of its own overrides it, as the settings
    -- window does.
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        if onMoved then
            local point, _, relPoint, x, y = frame:GetPoint()
            onMoved(point, relPoint, x, y)
        end
    end)
    f:Hide()

    local bg = self:Texture(f, "BACKGROUND", self.colors.bg); bg:SetAllPoints()
    self:AddBorder(f)

    local heading = FP:FontString(f, "OVERLAY", "heading")
    heading:SetText(self:T(title))

    local iconPath = AddonIcon()
    if iconPath then
        local side = HeadingSize() + 4
        local icon = f:CreateTexture(nil, "ARTWORK")
        icon:SetSize(side, side)
        icon:SetPoint("TOPLEFT", PAD, -12)
        icon:SetTexture(iconPath)
        panelIcons[#panelIcons + 1] = icon
        f.icon = icon

        heading:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    else
        heading:SetPoint("TOPLEFT", PAD, -13)
    end

    -- Always created, even when empty: a panel that is reused for more than one
    -- purpose has to be able to change its subtitle later.
    local sub = FP:FontString(f, "OVERLAY", "faint")
    sub:SetPoint("LEFT", heading, "RIGHT", 7, -1)
    sub:SetText(self:T(subtitle) or "")

    f.heading, f.subtitle = heading, sub

    local close = CreateFrame("Button", nil, f)
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", -6, -6)
    local hl = self:Texture(close, "HIGHLIGHT", self.colors.hover); hl:SetAllPoints()
    local x = FP:FontString(close, "OVERLAY", "heading")
    x:SetPoint("CENTER"); x:SetText("X")
    close:SetScript("OnClick", function() f:Hide() end)

    local sep = self:Texture(f, "ARTWORK", self.colors.border)
    sep:SetPoint("TOPLEFT", PAD, -(HEADER - 6))
    sep:SetPoint("TOPRIGHT", -PAD, -(HEADER - 6))
    sep:SetHeight(1)

    -- Let Escape close the panel.
    if globalName and type(UISpecialFrames) == "table" then
        local known = false
        for i = 1, #UISpecialFrames do
            if UISpecialFrames[i] == globalName then known = true end
        end
        if not known then table.insert(UISpecialFrames, globalName) end
    end

    return f
end

--- A checkbox row for a tab page.
--
-- Menu.lua has a richer variant of its own for the module list, which also
-- carries a description and an indent level. This is the plain one for pages
-- that just need a switch.
function FP:CreateToggle(parent, label, get, set)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(22)

    local hl = self:Texture(row, "HIGHLIGHT", self.colors.hover)
    hl:SetAllPoints()

    local box = self:Texture(row, "ARTWORK", self.colors.off, 13, 13)
    box:SetPoint("LEFT", self.ROW_BOX_X, 0)
    row.box = box

    local text = FP:FontString(row, "OVERLAY", "body")
    row.text = text
    -- To the row, not to the box. A label hung off the box would move whenever
    -- the box did, which is the opposite of what a shared column is for.
    text:SetPoint("LEFT", self.ROW_TEXT_X, 0)
    self:FitLabel(text, row)
    text:SetText(self:T(label))

    function row:Refresh()
        box:SetColorTexture(unpack(get() and FP.colors.on or FP.colors.off))
    end

    row:SetScript("OnClick", function(self)
        set(not get())
        self:Refresh()
    end)

    --- Splits the row in two: the box keeps the switch, the rest does `onRow`.
    --
    -- The house rule, and it holds everywhere in the window: **a row that can
    -- fold gives its click to folding, and only the box still switches. A row
    -- that cannot fold switches wherever you hit it.** Two things worth doing
    -- to one row, neither of them hidden behind a modifier key, and the same
    -- gesture meaning the same thing on every page.
    function row:SplitClick(onRow)
        if not self.boxHit then
            local hit = CreateFrame("Button", nil, self)
            hit:SetSize(19, 19)
            hit:SetPoint("LEFT", FP.ROW_BOX_X - 3, 0)
            local mark = FP:Texture(hit, "HIGHLIGHT", FP.colors.hover)
            mark:SetAllPoints()
            hit:SetScript("OnClick", function()
                set(not get())
                row:Refresh()
            end)
            self.boxHit = hit
        end
        self:SetScript("OnClick", function() onRow() end)
    end

    row:Refresh()
    return row
end

--- The client's own color picker, in whichever of its two shapes this build
--- has, with or without opacity.
--
-- Moved here from ChatLines.lua on 2026-10-18 for the info bar's colors, the
-- second user. The picker keeps what it is given in fields of its own, as it
-- does for every caller; it guards nothing protected.
-- @param onChange  called with r, g, b, a as the player moves the picker, and
--                  with the values it opened with on Cancel
-- @param onCancel  optional, called on Cancel instead, with those values
function FP:PickColor(r, g, b, a, opacity, onChange, onCancel)
    local picker = _G.ColorPickerFrame
    if type(picker) ~= "table" then return end
    a = a or 1

    local function Alpha()
        if not opacity then return 1 end
        if type(picker.GetColorAlpha) == "function" then
            local ok, value = pcall(picker.GetColorAlpha, picker)
            if ok and tonumber(value) then return tonumber(value) end
        end
        return a
    end
    local function Current()
        local ok, nr, ng, nb = pcall(picker.GetColorRGB, picker)
        if ok and nr then onChange(nr, ng, nb, Alpha()) end
    end
    local function Cancel(previous)
        local back = onCancel or onChange
        if type(previous) == "table" then
            back(previous.r or previous[1] or r, previous.g or previous[2] or g,
                 previous.b or previous[3] or b, previous.a or a)
        else
            back(r, g, b, a)
        end
    end

    if type(picker.SetupColorPickerAndShow) == "function" then
        pcall(picker.SetupColorPickerAndShow, picker, {
            r = r, g = g, b = b, opacity = a, hasOpacity = opacity and true or false,
            swatchFunc = Current, opacityFunc = opacity and Current or nil,
            cancelFunc = Cancel,
        })
    else
        picker.func, picker.cancelFunc = Current, Cancel
        picker.opacityFunc = opacity and Current or nil
        picker.hasOpacity = opacity and true or false
        picker.opacity = a
        picker.previousValues = { r = r, g = g, b = b, a = a }
        pcall(picker.SetColorRGB, picker, r, g, b)
        picker:Hide()
        picker:Show()
    end
end

--- A row with a label and a swatch at its end that opens the color picker.
--
-- @param opts  { opacity, Get(), Set(r, g, b, a), IsSet(), Clear() }: Get
--              answers r, g, b, a, the stored color or the default it stands
--              for; Cancel on a color never set clears it again rather than
--              keeping the default as a color of its own
function FP:CreateColorRow(parent, label, opts)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(22)

    local hl = self:Texture(row, "HIGHLIGHT", self.colors.hover)
    hl:SetAllPoints()

    -- A checker under the color, so an opacity below full reads as one.
    local swatch = CreateFrame("Frame", nil, row)
    swatch:SetSize(28, 14)
    swatch:SetPoint("RIGHT", -4, 0)
    local under = swatch:CreateTexture(nil, "BACKGROUND")
    under:SetAllPoints()
    under:SetColorTexture(0.5, 0.5, 0.5, 1)
    local fill = swatch:CreateTexture(nil, "ARTWORK")
    fill:SetAllPoints()
    self:AddBorder(swatch)

    local text = FP:FontString(row, "OVERLAY", "body")
    row.text = text
    text:SetPoint("LEFT", self.ROW_TEXT_X, 0)
    self:FitLabel(text, row, swatch)
    text:SetText(self:T(label))

    function row:Refresh()
        local r, g, b, a = opts.Get()
        fill:SetColorTexture(r or 1, g or 1, b or 1, opts.opacity and (a or 1) or 1)
    end

    row:SetScript("OnClick", function(self)
        local r, g, b, a = opts.Get()
        local wasSet = not opts.IsSet or opts.IsSet()
        FP:PickColor(r or 1, g or 1, b or 1, a or 1, opts.opacity,
            function(nr, ng, nb, na)
                opts.Set(nr, ng, nb, na)
                self:Refresh()
            end,
            function(pr, pg, pb, pa)
                if wasSet or not opts.Clear then
                    opts.Set(pr, pg, pb, pa)
                else
                    opts.Clear()
                end
                self:Refresh()
            end)
    end)

    row:Refresh()
    return row
end

--- A box alone, without a row around it: the square a toggle draws, on a
--- button a little larger than itself so it is easy to hit.
--
-- For a switch that sits beside something else rather than heading a row of
-- its own: Auto Buy's tick in front of a reagent's amount, and beside a
-- button at the merchant (2026-10-10).
function FP:CreateBox(parent, get, set)
    local hit = CreateFrame("Button", nil, parent)
    hit:SetSize(19, 19)
    local mark = self:Texture(hit, "HIGHLIGHT", self.colors.hover)
    mark:SetAllPoints()
    local box = self:Texture(hit, "ARTWORK", self.colors.off, 13, 13)
    box:SetPoint("CENTER")
    hit.box = box

    function hit:Refresh()
        box:SetColorTexture(unpack(get() and FP.colors.on or FP.colors.off))
    end
    hit:SetScript("OnClick", function(self)
        set(not get())
        self:Refresh()
    end)
    hit:Refresh()
    return hit
end

--- A label with a value between a minus and a plus button.
--
-- The menu renders boolean options on its own, but numbers need this: a
-- checkbox cannot express "five minutes".
-- @param opts  { min, max, step, bigStep, Format(value), Get(), Set(value) };
--              `bigStep` is the step while Shift is held, for a stepper whose
--              range is many steps wide, the reagents' amounts first
--              (2026-10-09). Without it Shift changes nothing.
function FP:CreateStepper(parent, label, opts)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(24)

    local text = FP:FontString(row, "OVERLAY", "body")
    row.text = text
    text:SetPoint("LEFT", FP.ROW_TEXT_X, 0)
    text:SetText(FP:T(label))

    local value = FP:FontString(row, "OVERLAY", "normal")
    value:SetPoint("RIGHT", -(FP.STEP_BTN + FP.STEP_GAP), 0)
    value:SetWidth(FP.STEP_VALUE)
    value:SetJustifyH("CENTER")

    local function Refresh()
        local current = opts.Get()
        value:SetText(opts.Format and opts.Format(current) or tostring(current))
    end

    -- A limit may be a function, asked at the moment it is needed: the chat's
    -- history is capped by how many lines a window holds, which is the
    -- client's number rather than ours.
    local function Limit(limit)
        if type(limit) == "function" then return tonumber(limit()) end
        return limit
    end

    local function Nudge(direction)
        local current = tonumber(opts.Get()) or 0
        -- A step may depend on where the value is, for a range too wide for one
        -- step size: a warning time of its own goes by five seconds under a
        -- minute and by whole minutes above ten (2026-10-15).
        local size = opts.step or 1
        if type(size) == "function" then size = size(current, direction) end
        if opts.bigStep and IsShiftKeyDown and IsShiftKeyDown() then
            size = opts.bigStep
        end
        local next = current + direction * size
        local low, high = Limit(opts.min), Limit(opts.max)
        if low then next = math.max(low, next) end
        if high then next = math.min(high, next) end
        opts.Set(next)
        Refresh()
    end

    local minus = self:CreateButton(row, "-", FP.STEP_BTN, function() Nudge(-1) end)
    minus:SetPoint("RIGHT", value, "LEFT", -FP.STEP_GAP, 0)
    -- Its hover text opens to the left, so it covers neither the number it
    -- changes nor the plus: the owner's request of 2026-10-06.
    minus.tipSide = "LEFT"

    local plus = self:CreateButton(row, "+", FP.STEP_BTN, function() Nudge(1) end)
    plus:SetPoint("RIGHT", 0, 0)

    self:FitLabel(text, row, minus)

    -- Both buttons sit in front of the row and would eat the hover.
    row.tooltipTargets = { minus, plus }

    row.Refresh = Refresh
    Refresh()
    return row
end

-- The fields holding the keyboard right now. Only one can have focus, but each
-- answers for itself: in which order the client reports focus moving from one
-- field straight to another is not read anywhere.
local keyHolders = {}

--- Keeps key bindings silent while a text field has focus, in a fight as well.
--- Every field in the addon goes through this and FP:ReleaseKeys.
--
-- **In a fight too**, the owner's word of 2026-11-05: whoever opens a window in a
-- fight can close it before opening the character sheet, and that sheet coming up
-- beside the export window feels wrong. SetPropagateKeyboardInput is restricted in
-- a fight, so it is only called outside one and never set back: a field keeps it
-- off, and EnableKeyboard alone decides whether the field holds the keyboard.
-- EnableKeyboard is not restricted, as far as can be read: the API documentation
-- for build 70790 marks it as it marks Show and Hide, which an addon calls on its
-- own frames in a fight all the time. Not measured.
function FP:HoldKeys(box)
    box:EnableKeyboard(true)
    if box.SetPropagateKeyboardInput and not InCombatLockdown() then
        pcall(box.SetPropagateKeyboardInput, box, false)
    end
    keyHolders[box] = true
end

--- Gives the keyboard back when the field lost focus. A frame that holds it
--- without focus stops the player moving entirely.
function FP:ReleaseKeys(box)
    keyHolders[box] = nil
    box:EnableKeyboard(false)
end

-- A fight starting must not find the keyboard held, or the player could neither
-- move nor cast until they thought of Escape. The field lets go; its window and
-- its text stay, and a click into it holds the keys again.
local keyWatch = CreateFrame("Frame")
keyWatch:RegisterEvent("PLAYER_REGEN_DISABLED")
keyWatch:SetScript("OnEvent", function()
    for box in pairs(keyHolders) do box:ClearFocus() end
end)

--- A selectable, effectively read-only text field.
--
-- WoW addons cannot open a browser -- there is no API for it. The universal
-- workaround is a field the user can select and copy with Ctrl+C, which is
-- what this builds.
function FP:CreateCopyBox(parent, text, width)
    -- A Button rather than a Frame, so the HIGHLIGHT layer lights up on hover
    -- by itself. The field has to look clickable, or nobody clicks it.
    local holder = CreateFrame("Button", nil, parent)
    holder:SetSize(width, 22)
    local bg = self:Texture(holder, "BACKGROUND", { 0, 0, 0, 0.45 }); bg:SetAllPoints()
    local hl = self:Texture(holder, "HIGHLIGHT", self.colors.hover); hl:SetAllPoints()
    self:AddBorder(holder)

    local box = CreateFrame("EditBox", nil, holder)
    box:SetPoint("TOPLEFT", 6, 0)
    box:SetPoint("BOTTOMRIGHT", -6, 0)
    box:SetFontObject(self:Font("body") or "GameFontHighlightSmall")
    box:SetAutoFocus(false)   -- never steal focus on its own: a focused edit
                              -- box swallows WASD and stops the player moving
    box:SetText(text)
    box:SetCursorPosition(0)

    -- Clicking the padding around the text selects it too.
    holder:SetScript("OnClick", function()
        box:SetFocus()
        box:HighlightText()
    end)

    -- Focus explicitly on click. Without it, Ctrl+C reaches the game instead of
    -- the field and fires whatever C is bound to -- the character sheet.
    box:EnableMouse(true)
    box:SetScript("OnMouseDown", function(self) self:SetFocus() end)
    box:SetScript("OnMouseUp", function(self) self:HighlightText() end)

    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed",  function(self) self:ClearFocus() end)

    -- Swallow keyboard input while the field is active, so key bindings stay
    -- silent. Strictly scoped to the focused state: a frame that captures the
    -- keyboard without focus would stop the player moving entirely.
    box:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
        FP:HoldKeys(self)
    end)

    box:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        FP:ReleaseKeys(self)
    end)

    -- Safety net: if the panel closes while the field still has focus, the
    -- keyboard would stay captured and the character would stop responding.
    holder:SetScript("OnHide", function() box:ClearFocus() end)

    -- Keep the content fixed. userInput is false for our own SetText, so this
    -- restores the value without recursing.
    box:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(text)
            self:HighlightText()
        end
    end)

    --- Shows other text, for a field reused for more than one thing.
    function holder:SetCopyText(new)
        text = new
        box:SetText(new)
        box:SetCursorPosition(0)
    end

    holder.editBox = box
    return holder
end

--- How far the lowest thing inside a frame reaches below its top.
--
-- Pages work out their own height while they build, from numbers that were
-- true at the time. Text size can change afterwards, wrapped text reflows, and
-- those numbers stop being true -- so a page that has grown needs to be asked
-- again rather than remembered.
--
-- Only meaningful while the frame is shown and anchored: an unresolved anchor
-- has no position, and GetBottom answers nil.
function FP:MeasureExtent(frame)
    local top = frame:GetTop()
    if not top then return nil end

    local lowest = 0
    local function consider(thing)
        if not (thing and thing.GetBottom and thing.IsShown and thing:IsShown()) then return end
        local bottom = thing:GetBottom()
        if bottom then lowest = math.max(lowest, top - bottom) end
    end

    -- Font strings and textures are regions; widgets are children. A page is
    -- made of both.
    for _, region in ipairs({ frame:GetRegions() }) do consider(region) end
    for _, child  in ipairs({ frame:GetChildren() }) do consider(child) end

    return lowest
end

-- ---------------------------------------------------------------------------
-- Text on one of the game's icons
--
-- White, outlined in black, on a hard shadow. The rule in AGENTS.md that a color
-- arrives with its font role covers rows in our own window, where the scheme
-- decides; text on a game icon of unknown brightness needs contrast rather than
-- a palette. First written for the number on the backpack, and shared since the
-- bag buttons and the ammunition count write on icons too.
--
-- **Outlined since 2026-09-28**, after the owner's screenshot of an ammo pouch:
-- the count in red on the pouch's brown could hardly be read, and a shadow
-- alone was not enough for any of the numbers on the bags. The font is the
-- client's own number font, the one its stack counts use, with an outline of
-- its own; the path is read off that font object rather than written here, so
-- a client in another language keeps its own letters. It follows the client's
-- size rather than the addon's text size setting, as the stack counts do.
--
-- Drawn at the top of the overlay layer, above the highlight the client lays
-- over a bag button while that bag is open.
-- ---------------------------------------------------------------------------

local iconFont

--- The font for text on icons: the client's number font, outlined.
local function IconFont()
    if iconFont then return iconFont end
    local base = _G.NumberFontNormal
    if not base then return nil end
    local ok, path, size = pcall(base.GetFont, base)
    if not ok or type(path) ~= "string" or not CreateFont then return base end
    local font = CreateFont("ForeverPlusIconFont")
    if not pcall(font.SetFont, font, path, tonumber(size) or 14, "OUTLINE") then
        return base
    end
    iconFont = font
    return font
end

function FP:StyleIconText(fs)
    if not fs then return end
    -- The font first: setting a font object brings its color and shadow along,
    -- so everything after it would otherwise be undone.
    local font = IconFont()
    if font then pcall(fs.SetFontObject, fs, font) end
    pcall(fs.SetTextColor, fs, 1, 1, 1)
    if fs.SetShadowColor then
        pcall(fs.SetShadowColor, fs, 0, 0, 0, 1)
        pcall(fs.SetShadowOffset, fs, 1, -1)
    end
end

--- A font string on an icon, at one of its edges, styled for it.
-- @param point  "TOP" or "BOTTOM", which is also the edge it keeps to
function FP:IconText(parent, point, x, y)
    local fs = self:FontString(parent, "OVERLAY", "body")
    pcall(fs.SetDrawLayer, fs, "OVERLAY", 7)
    fs:SetPoint(point, parent, point, x or 0, y or 0)
    self:StyleIconText(fs)
    return fs
end

-- ---------------------------------------------------------------------------
-- The addon's own tooltip
--
-- Asked for by the owner on 2026-09-26: every tooltip ForeverPlus shows, in the
-- addon's own design rather than Blizzard's. **Only what the addon says
-- itself.** The unit and item tooltips the game draws stay the game's,
-- including the lines the Tooltip module adds to them, and so does any tooltip
-- in a ForeverPlus window that shows one of the game's own objects, an item on
-- the consumables page for one: the owner drew that line the same day. This is
-- for the explanations, labels and notes the addon writes.
--
-- One frame, reused, like the drop-down list: two can never be open at once. It
-- takes no mouse, so it can never swallow a click, and it hides itself when the
-- thing it describes disappears from under the pointer. GameTooltip does that
-- by itself; a frame of our own has to be told, because a window closed under
-- the pointer sends no OnLeave.
-- ---------------------------------------------------------------------------

local TIP_PAD   = 8
local TIP_WIDTH = 280   -- the widest a wrapped line may grow
local TIP_GAP   = 16    -- between the two halves of a double line
local TIP_SPACE = 2     -- between lines, and twice that under the title
local TIP_SIDE  = 8     -- between the tooltip and its owner, beside it

local tip

local function TipFrame()
    if tip then return tip end

    local f = CreateFrame("Frame", "ForeverPlusTooltip", UIParent)
    f:SetFrameStrata("TOOLTIP")
    f:SetClampedToScreen(true)
    f:EnableMouse(false)
    f:Hide()

    local bg = FP:Texture(f, "BACKGROUND", FP.colors.bg)
    bg:SetAllPoints()
    FP:AddBorder(f)

    f.rows = {}
    f:SetScript("OnUpdate", function(self)
        local owner = self.owner
        if not owner or not owner:IsVisible() then self:Hide() end
    end)

    tip = f
    return f
end

local function TipRow(f, index)
    local row = f.rows[index]
    if row then return row end
    row = {
        left  = FP:FontString(f, "OVERLAY", "body"),
        right = FP:FontString(f, "OVERLAY", "body"),
    }
    row.left:SetJustifyH("LEFT")
    row.right:SetJustifyH("RIGHT")
    f.rows[index] = row
    return row
end

-- A role's font and, unless the line brings its own, the role's color: the
-- rule from *How a page looks*, where the color arrives with the role.
local function Paint(fs, role, color)
    local font = FP:Font(role)
    if font then fs:SetFontObject(font) end
    if type(color) == "table" and color[1] then
        -- A line's own color, a class or a warning, made readable on the
        -- tooltip's ground like the roles are, see FP:Readable.
        fs:SetTextColor(FP:Readable(color[1], color[2], color[3]))
    elseif font and font.GetTextColor then
        local r, g, b = font:GetTextColor()
        if r then fs:SetTextColor(r, g, b) end
    end
end

local HANG_GAP = 4      -- between a hanging frame and its figure, see FP:HangSteady

--- Hangs a frame centered on a figure: under it, or above it when the screen
--- leaves no room under it and more above, and **fixed to the screen** from then
--- on rather than to the figure.
--
-- For the info bar, the owner's report of 2026-11-06, a tooltip that moved all the
-- time. A figure's width changes whenever its digits do, which moves its middle,
-- a bar anchored by its own middle moves every figure on it as well, and a frame
-- anchored to the figure followed each of those steps. The side depends on the
-- height, so a frame whose size comes later calls this again then.
--
-- @param keep  a frame that is already up stays where it is, unless its side no
--              longer has the room
function FP:HangSteady(f, owner, keep)
    local center, top, bottom = owner:GetCenter(), owner:GetTop(), owner:GetBottom()
    if not (center and top and bottom) then
        -- Not laid out yet, so nothing can be measured: on the figure for now.
        if not keep then
            f:ClearAllPoints()
            f:SetPoint("TOP", owner, "BOTTOM", 0, -HANG_GAP)
        end
        return
    end
    -- In the frame's own units, since the figure may sit in a frame of another scale.
    local scale = owner:GetEffectiveScale() / f:GetEffectiveScale()
    local side = self:SideThatFits(f:GetHeight() + HANG_GAP,
        bottom * scale, UIParent:GetHeight() - top * scale)
    if keep and f.hungOn == side then return end
    f.hungOn = side
    f:ClearAllPoints()
    if side == "TOP" then
        f:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", center * scale, top * scale + HANG_GAP)
    else
        f:SetPoint("TOP", UIParent, "BOTTOMLEFT", center * scale, bottom * scale - HANG_GAP)
    end
end

-- Hangs the tooltip on one side of its owner, see FP:ShowTip.
local function Place(f, owner, anchor)
    f:ClearAllPoints()
    if anchor == "BOTTOM" then
        f:SetPoint("TOP", owner, "BOTTOM", 0, -4)
    elseif anchor == "TOP" then
        f:SetPoint("BOTTOM", owner, "TOP", 0, 4)
    elseif anchor == "LEFT" then
        f:SetPoint("TOPRIGHT", owner, "TOPLEFT", -TIP_SIDE, 0)
    else
        f:SetPoint("TOPLEFT", owner, "TOPRIGHT", TIP_SIDE, 0)
    end
end

-- Whether the tooltip fits between the screen's left edge and its owner. In
-- the tooltip's own units, since the owner may sit in a window of another
-- scale.
local function FitsLeft(f, owner)
    local left = owner:GetLeft()
    if not left then return true end
    local x = left * owner:GetEffectiveScale() / f:GetEffectiveScale()
    return x - TIP_SIDE - f:GetWidth() >= 0
end

--- Shows the addon's tooltip for a frame.
--
-- @param owner   the frame being hovered
-- @param lines   a list; a line is a string or a table
--                { text, right = text, color = { r, g, b },
--                  rightColor = { r, g, b }, wrap = true }.
--                The first line is the title, in the primary role; the rest
--                are in the body role, as on every page of the window.
--                `minWidth` on the list is the width a "STEADY" one starts from,
--                for lines that come and go while it is up.
-- @param anchor  "RIGHT", beside the owner, which is the default, "LEFT" on
--                its other side while the screen leaves room there,
--                "BOTTOM", under it, "TOP", above it, or "STEADY", for a figure
--                on the info bar: see FP:HangSteady, and drawn again for the
--                same owner it stays where it is and only grows, so that text
--                changing under it cannot move it
function FP:ShowTip(owner, lines, anchor)
    if not owner or type(lines) ~= "table" or #lines == 0 then return end
    local f = TipFrame()
    local steady = anchor == "STEADY"
    local again = steady and f.owner == owner and f:IsShown()
    f.owner = owner

    -- Placed and shown before anything is measured, which is two pitfalls in
    -- AGENTS.md at once: a frame without a point has no position to measure
    -- from, and wrapped text reports its height only on a visible frame.
    if not again then
        f:SetSize(TIP_WIDTH + 2 * TIP_PAD, 40)
        if steady then self:HangSteady(f, owner) else Place(f, owner, anchor) end
        f:Show()
    end

    -- First pass: the text, and how wide each line wants to be.
    local width = steady and lines.minWidth or 0
    for index, line in ipairs(lines) do
        local spec = type(line) == "table" and line or { line }
        local row  = TipRow(f, index)
        local role = (index == 1) and "normal" or "body"
        row.spec = spec

        Paint(row.left, role, spec.color)
        row.left:SetWordWrap(spec.wrap and true or false)
        row.left:SetWidth(0)
        row.left:SetText(FP:T(spec[1]) or "")
        row.left:Show()

        local wanted = row.left:GetStringWidth()
        if spec.right then
            Paint(row.right, role, spec.rightColor)
            row.right:SetText(FP:T(spec.right))
            row.right:Show()
            wanted = wanted + TIP_GAP + row.right:GetStringWidth()
        else
            row.right:SetText("")
            row.right:Hide()
        end
        if spec.wrap then wanted = math.min(wanted, TIP_WIDTH) end
        width = math.max(width, wanted)
    end
    for index = #lines + 1, #f.rows do
        f.rows[index].left:Hide()
        f.rows[index].right:Hide()
    end
    if again then width = math.max(width, f.heldWidth or 0) end
    f.heldWidth = width

    -- Second pass: wrapped lines take the final width, then everything is
    -- stacked under the title.
    local y = TIP_PAD
    for index = 1, #lines do
        local row = f.rows[index]
        if row.spec.wrap then row.left:SetWidth(width) end
        row.left:ClearAllPoints()
        row.left:SetPoint("TOPLEFT", f, "TOPLEFT", TIP_PAD, -y)
        row.right:ClearAllPoints()
        row.right:SetPoint("TOPRIGHT", f, "TOPRIGHT", -TIP_PAD, -y)
        local height = row.left:GetStringHeight()
        if row.spec.right then
            height = math.max(height, row.right:GetStringHeight())
        end
        y = y + height + ((index == 1) and 2 * TIP_SPACE or TIP_SPACE)
    end

    local tall = y - TIP_SPACE + TIP_PAD
    if again then tall = math.max(tall, f:GetHeight()) end
    f:SetSize(width + 2 * TIP_PAD, tall)
    if steady then self:HangSteady(f, owner, again) end

    -- Clamped to the screen, a tooltip with no room on the left would slide
    -- back over the very frame it was moved away from, so it takes the right.
    if anchor == "LEFT" and not FitsLeft(f, owner) then Place(f, owner, "RIGHT") end
end

--- Hides the addon's tooltip, if it is showing for this frame.
--
-- By owner, so a frame the pointer is leaving cannot take down a tooltip that
-- the frame it is arriving at has already put up.
function FP:HideTip(owner)
    if tip and (owner == nil or tip.owner == owner) then tip:Hide() end
end

--- Attaches hover text to a frame, or to several.
--
-- The only place an option can say more than its label. Before this, a
-- description was squeezed onto one line beside the name and clipped.
--
-- Several, because a mouse-enabled child takes the pointer before the frame
-- behind it ever sees it: a stepper row hands its hover to the plus and minus
-- buttons, a drop-down to its button, a module row to its switch. Attaching to
-- the row alone means the text appears over the label and vanishes the moment
-- the pointer reaches the thing being labeled.
--
-- Drawn by the addon's own tooltip since 2026-09-26, see FP:ShowTip; it was
-- the GameTooltip before. `text` may be a function, worked out when the pointer
-- arrives rather than when the row was built: an option that is grayed out has
-- something extra to say, and only while it is grayed out. `title` may be one
-- as well, for a row named by an item whose name the client loads later.
--
-- A frame may carry `tipSide`, the side the text opens on, see FP:ShowTip: a
-- stepper's minus opens to the left, so the number it changes stays readable.
function FP:Tooltip(frame, title, text)
    if not text or not frame then return end

    -- A list: attach to each, same text.
    if frame[1] ~= nil and not frame.SetScript then
        for index = 1, #frame do self:Tooltip(frame[index], title, text) end
        return
    end

    -- A Frame takes no mouse input by default, so OnEnter would never fire.
    -- Buttons already do, and turning it on twice is harmless.
    frame:EnableMouse(true)

    frame:SetScript("OnEnter", function(self)
        -- Not `and text() or text`: a function answering nothing would hand
        -- itself on as the text, which SetText refuses. The reagent list was
        -- the first row in the module list with no hover text of its own, and
        -- the owner's error log of 2026-10-09 showed it nine times.
        local body = text
        if type(text) == "function" then body = text() end
        if type(body) ~= "string" or body == "" then return end
        local head = title
        if type(title) == "function" then head = title() end
        -- The explanation wraps; a long one would otherwise run off the side
        -- of the screen.
        FP:ShowTip(self, { head or "", { body, wrap = true } }, self.tipSide)
    end)
    frame:SetScript("OnLeave", function(self) FP:HideTip(self) end)
end

-- How strongly a cause is lit: the share of the switches' own color the open
-- tab carries over its background as well.
local CAUSE_ALPHA = 0.25

-- A frame with a color of its own may carry it as `causeBase`. Where lighting
-- it would move no channel by this much, it is darkened by CAUSE_DARKEN
-- instead: Jade's open tab, whose green is the light's own, barely changed,
-- found by the owner on 2026-10-06, while every other scheme moves at least
-- 0.11 and stays lit.
local CAUSE_MIN_STEP = 0.09
local CAUSE_DARKEN   = 0.35

local function LightShows(base, color)
    for i = 1, 3 do
        if math.abs((color[i] - base[i]) * CAUSE_ALPHA) >= CAUSE_MIN_STEP then
            return true
        end
    end
    return false
end

--- Lights a frame up as the reason another row is grayed out, or puts it out.
--
-- The owner's request of 2026-10-06, for the window's usability: hovering a
-- row some other setting has made meaningless lights that setting up, so
-- nobody has to guess which switch the row answers to. A soft background in
-- the color of a switch that is on, read when it is lit, so a color scheme
-- changed in between is followed.
-- @param pad  how far the light reaches past the frame
function FP:LightCause(frame, on, pad)
    if type(frame) ~= "table" or not frame.CreateTexture then return end
    local glow = frame.causeGlow
    if not on then
        if glow then glow:Hide() end
        return
    end
    -- BORDER: above a frame's own background, a tab's or a field's, and below
    -- its box and its text, which stay readable through the light.
    if not glow then
        glow = frame:CreateTexture(nil, "BORDER")
        frame.causeGlow = glow
    end
    pad = pad or 0
    glow:ClearAllPoints()
    glow:SetPoint("TOPLEFT", frame, "TOPLEFT", -pad, pad)
    glow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", pad, -pad)
    local color = self.colors.on
    local base = frame.causeBase
    if type(base) == "function" then base = base() end
    if type(base) == "table" and base[3] and not LightShows(base, color) then
        glow:SetColorTexture(0, 0, 0, CAUSE_DARKEN)
    else
        glow:SetColorTexture(color[1], color[2], color[3], CAUSE_ALPHA)
    end
    glow:Show()
end

--- While `row` is hovered and `blocked()` says it is grayed out, lights up
--- every frame `causes()` returns, and puts them out on leaving.
--
-- Hooked after the row's own hover rather than set, so its tooltip goes on
-- working; call it after FP:Tooltip, whose SetScript would replace the hook.
-- Both functions are asked at the moment of hovering, because what grays a
-- row out can change while the window is open.
function FP:PointAtCause(row, blocked, causes, pad)
    if type(row) ~= "table" then return end
    local lit = {}

    local function Leave()
        for index = #lit, 1, -1 do
            FP:LightCause(lit[index], false)
            lit[index] = nil
        end
    end

    local function Enter()
        Leave()
        local ok, yes = pcall(blocked)
        if not (ok and yes) then return end
        local found, frames = pcall(causes)
        if not found or type(frames) ~= "table" then return end
        for index = 1, #frames do
            local frame = frames[index]
            if frame then
                FP:LightCause(frame, true, pad)
                lit[#lit + 1] = frame
            end
        end
    end

    local targets = { row }
    for _, target in ipairs(row.tooltipTargets or {}) do targets[#targets + 1] = target end
    for _, target in ipairs(targets) do
        if target.HookScript then
            target:HookScript("OnEnter", Enter)
            target:HookScript("OnLeave", Leave)
            target:HookScript("OnHide", Leave)
        end
    end
end

-- ---------------------------------------------------------------------------
-- The drop-down list
--
-- One list frame, shared by every drop-down there is. Two of them can never be
-- open at once, so a second would only be a second thing to keep in step -- and
-- opening one closes whichever was open before without any bookkeeping.
--
-- It cannot live inside the settings window: the content there sits in a
-- ScrollFrame and would clip it. So it hangs off UIParent at a higher strata,
-- with a full-screen catcher behind it that closes it on the next click
-- anywhere. The catcher only exists while the list is open.
-- ---------------------------------------------------------------------------

local dropdown

local function DropdownList()
    if dropdown then return dropdown end

    local catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN")
    catcher:Hide()

    local list = CreateFrame("Frame", nil, UIParent)
    list:SetFrameStrata("FULLSCREEN_DIALOG")
    list:SetToplevel(true)
    list:EnableMouse(true)
    -- Opened under its box, which at the bottom of the screen would put it
    -- below the edge: the language picker sits at the bottom of the window.
    list:SetClampedToScreen(true)
    list:Hide()

    local bg = FP:Texture(list, "BACKGROUND", { 0.07, 0.07, 0.09, 0.98 })
    bg:SetAllPoints()
    FP:AddBorder(list)

    list.buttons = {}
    list.catcher = catcher

    local function Close()
        list:Hide()
        catcher:Hide()
    end
    list.Close = Close
    catcher:SetScript("OnClick", Close)
    list:SetScript("OnHide", function() catcher:Hide() end)

    dropdown = list
    return list
end

--- Opens the shared list under `anchor` with `values`, calling `onPick(value)`.
-- @param values  array of { value, label, right = text, onDelete = fn }
--                entries, in the order to show them. `right` is optional and
--                sits at the right edge of the open list: the color scheme's
--                colors, after its name. `onDelete` puts a red X at the very
--                end of the row, which closes the list and calls it rather
--                than picking the entry: the mail list's characters.
local function OpenDropdown(anchor, values, current, onPick)
    local list = DropdownList()
    local ROW, PAD, GAP, DELETE_W = 18, 4, 12, 18

    local widest = anchor:GetWidth()
    for index = 1, #values do
        local button = list.buttons[index]
        if not button then
            button = CreateFrame("Button", nil, list)
            button:SetHeight(ROW)
            local hl = FP:Texture(button, "HIGHLIGHT", FP.colors.hover)
            hl:SetAllPoints()
            button.text = FP:FontString(button, "OVERLAY", "body")
            button.text:SetPoint("LEFT", 6, 0)
            button.text:SetJustifyH("LEFT")
            button.right = FP:FontString(button, "OVERLAY", "body")
            button.right:SetPoint("RIGHT", -6, 0)
            button.right:SetJustifyH("RIGHT")

            -- A button of its own inside the row, so its click never reaches
            -- the row's pick. Red, because it deletes something, and in the
            -- text rather than set on the string, so a change of design that
            -- repaints the fonts keeps it.
            local delete = CreateFrame("Button", nil, button)
            delete:SetPoint("TOPRIGHT")
            delete:SetPoint("BOTTOMRIGHT")
            delete:SetWidth(DELETE_W)
            local dhl = FP:Texture(delete, "HIGHLIGHT", FP.colors.hover)
            dhl:SetAllPoints()
            local x = FP:FontString(delete, "OVERLAY", "body")
            x:SetPoint("CENTER")
            local red = _G.RED_FONT_COLOR
            local code = type(red) == "table" and type(red.GenerateHexColor) == "function"
                and select(2, pcall(red.GenerateHexColor, red))
            x:SetText("|c" .. (type(code) == "string" and code or "ffff1a1a") .. "X|r")
            button.delete = delete
            list.buttons[index] = button
        end

        local value, label = values[index][1], values[index][2]
        button.text:SetText(FP:T(label))
        -- Emptied rather than left: the buttons are shared by every list, and
        -- the next one may have nothing on the right.
        button.right:SetText(values[index].right or "")
        local onDelete = values[index].onDelete
        button.delete:SetShown(onDelete ~= nil)
        button.delete:SetScript("OnClick", onDelete and function()
            list.Close()
            onDelete(value)
        end or nil)
        button.right:ClearAllPoints()
        button.right:SetPoint("RIGHT", onDelete and -(DELETE_W + 4) or -6, 0)
        -- The active entry is marked rather than ticked: a tick column would
        -- shift every label across for one row's sake.
        button.text:SetTextColor(unpack(value == current and FP.colors.textOn or FP.colors.textOff))
        button:SetPoint("TOPLEFT", PAD, -(PAD + (index - 1) * ROW))
        button:SetPoint("TOPRIGHT", -PAD, -(PAD + (index - 1) * ROW))
        button:SetScript("OnClick", function()
            list.Close()
            onPick(value)
        end)
        button:Show()

        local right = values[index].right and (button.right:GetStringWidth() + GAP) or 0
        if onDelete then right = right + DELETE_W + GAP end
        widest = math.max(widest, button.text:GetStringWidth() + right + 2 * PAD + 12)
    end

    for index = #values + 1, #list.buttons do
        list.buttons[index]:Hide()
    end

    list:SetSize(widest, #values * ROW + 2 * PAD)
    list:ClearAllPoints()
    list:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)
    list.catcher:Show()
    list:Show()
end

--- The same list, for a module that has its own button to open it from.
--
-- The mail window's list of characters is the first user. Nothing is marked as
-- current; a label may carry color escapes of its own.
-- @param values  array of { value, label, onDelete = fn } entries, in the
--                order to show them, see OpenDropdown
function FP:OpenList(anchor, values, onPick)
    return OpenDropdown(anchor, values, nil, onPick)
end

--- The box of a drop-down on its own, without a label in front of it.
--
-- For a place that is not a row: the language picker at the bottom of the
-- window, beside Reload UI. CreateDropdown below is this box with a label.
--
-- @param opts  { values, Get(), Set(value), width }, see CreateDropdown
function FP:CreateDropdownButton(parent, opts)
    local button = CreateFrame("Button", nil, parent)
    -- Exactly the span of a stepper, from the left edge of its minus to the
    -- right edge of its plus, so a dropdown and a stepper in neighboring rows
    -- line up on both sides.
    button:SetSize(opts.width or FP.CONTROL_W, 20)
    local bg = self:Texture(button, "BACKGROUND", self.colors.btn); bg:SetAllPoints()
    self:AddBorder(button)
    local hl = self:Texture(button, "HIGHLIGHT", self.colors.hover); hl:SetAllPoints()

    local value = FP:FontString(button, "OVERLAY", "body")
    value:SetPoint("LEFT", 6, 0)
    value:SetPoint("RIGHT", -16, 0)
    value:SetJustifyH("LEFT")
    value:SetWordWrap(false)

    local arrow = FP:FontString(button, "OVERLAY", "faint")
    arrow:SetPoint("RIGHT", -5, 0)
    arrow:SetText("v")

    local function LabelFor(current)
        for _, pair in ipairs(opts.values) do
            if pair[1] == current then return FP:T(pair[2]) end
        end
        -- A stored value with no entry in the list: show it rather than an
        -- empty box, so a setting that has gone stale is visible instead of
        -- looking like nothing is selected.
        return "|cffff8866" .. tostring(current) .. "|r"
    end

    function button:Refresh()
        value:SetText(LabelFor(opts.Get()))
    end

    button:SetScript("OnClick", function(self)
        OpenDropdown(self, opts.values, opts.Get(), function(picked)
            opts.Set(picked)
            self:Refresh()
        end)
    end)

    button:Refresh()
    return button
end

--- A label with a value that opens a list of choices.
--
-- Hand-built, like everything else here. UIDropDownMenuTemplate exists on this
-- client, and instantiating it is exactly the taint vector AGENTS.md warns
-- about.
--
-- @param opts  { values = { {value, label, right = text}, ... }, Get(), Set(value) }
--              right, when given, is shown at the right edge of the open list
--              only; the closed box shows label alone.
function FP:CreateDropdown(parent, label, opts)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(24)

    local text = FP:FontString(row, "OVERLAY", "body")
    row.text = text
    text:SetPoint("LEFT", FP.ROW_TEXT_X, 0)
    text:SetText(FP:T(label))

    local button = self:CreateDropdownButton(row, opts)
    button:SetPoint("RIGHT", 0, 0)
    self:FitLabel(text, row, button)

    row.tooltipTargets = { button }

    row.Refresh = function() button:Refresh() end
    return row
end

--- A label with a single-line text field beside it.
--
-- @param opts  { Get(), Set(text), width, placeholder }
function FP:CreateInput(parent, label, opts)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(24)

    local text
    if label and label ~= "" then
        text = FP:FontString(row, "OVERLAY", "body")
        row.text = text
        text:SetPoint("LEFT", FP.ROW_TEXT_X, 0)
        text:SetText(FP:T(label))
    end

    local holder = CreateFrame("Frame", nil, row)
    holder:SetSize(opts.width or 160, 20)
    holder:SetPoint("RIGHT", 0, 0)
    if text then self:FitLabel(text, row, holder) end
    local bg = self:Texture(holder, "BACKGROUND", { 0, 0, 0, 0.45 }); bg:SetAllPoints()
    self:AddBorder(holder)

    local hint
    local box = CreateFrame("EditBox", nil, holder)
    box:SetPoint("TOPLEFT", 5, 0)
    box:SetPoint("BOTTOMRIGHT", -5, 0)
    box:SetFontObject(self:Font("body") or "GameFontHighlightSmall")
    box:SetAutoFocus(false)
    box:SetText(opts.Get() or "")
    box:SetCursorPosition(0)

    if opts.placeholder then
        hint = FP:FontString(holder, "OVERLAY", "faint")
        hint:SetPoint("LEFT", 6, 0)
        hint:SetText(FP:T(opts.placeholder))
    end

    local function ShowHint()
        if hint then hint:SetShown((box:GetText() or "") == "") end
    end
    ShowHint()

    -- Committed on Enter and on losing focus, not on every keystroke: a Set on
    -- every letter would restart the module once per character typed.
    local function Commit()
        opts.Set(box:GetText() or "")
    end

    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self)
        -- Escape abandons the edit rather than committing it.
        self:SetText(opts.Get() or "")
        self:ClearFocus()
    end)
    box:SetScript("OnTextChanged", function(self, userInput)
        ShowHint()
        if userInput and opts.OnChange then opts.OnChange(self:GetText() or "") end
    end)

    -- Same keyboard rules as everywhere else: a focused EditBox does not stop
    -- key bindings by itself, and a frame holding the keyboard without focus
    -- stops the player moving entirely.
    box:SetScript("OnEditFocusGained", function(self) FP:HoldKeys(self) end)
    box:SetScript("OnEditFocusLost", function(self)
        FP:ReleaseKeys(self)
        Commit()
    end)

    holder:EnableMouse(true)
    holder:SetScript("OnMouseDown", function() box:SetFocus() end)
    row:SetScript("OnHide", function() box:ClearFocus() end)

    function row:Refresh()
        if box:HasFocus() then return end   -- never overwrite what is being typed
        box:SetText(opts.Get() or "")
        box:SetCursorPosition(0)
        ShowHint()
    end

    row.tooltipTargets = { holder }
    row.editBox = box
    return row
end

--- A scrollable, editable, multi-line text field.
--
-- CreateCopyBox above is the read-only single-line version. This one exists
-- because an export string is several hundred characters and has to go both
-- ways: the chat command line stops at 255, so a string can neither be shown
-- there usefully nor pasted into one.
--
-- The keyboard goes through FP:HoldKeys and FP:ReleaseKeys like every field: a
-- focused EditBox does not stop key bindings by itself, so WASD would still move
-- the character and Ctrl+C would still open the character sheet.
function FP:CreateTextArea(parent, width, height)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width, height)
    local bg = self:Texture(holder, "BACKGROUND", { 0, 0, 0, 0.45 }); bg:SetAllPoints()
    self:AddBorder(holder)

    local scroll = CreateFrame("ScrollFrame", nil, holder)
    scroll:SetPoint("TOPLEFT", 6, -5)
    scroll:SetPoint("BOTTOMRIGHT", -6, 5)
    scroll:EnableMouseWheel(true)

    -- An empty text area is a dark rectangle with nothing in it, and nothing
    -- about it says "type here". This is what it says instead.
    local hint = FP:FontString(holder, "OVERLAY", "faint")
    hint:SetPoint("TOPLEFT", 8, -7)
    hint:SetPoint("RIGHT", -8, 0)
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(true)
    hint:Hide()

    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)      -- never steal focus on its own
    box:SetFontObject(self:Font("body") or "GameFontHighlightSmall")
    box:SetWidth(width - 12)
    box:SetJustifyH("LEFT")
    -- Explicitly unlimited. A profile string runs to several hundred
    -- characters, and a field that silently keeps the first few hundred hands
    -- back something that looks right and fails its checksum.
    box:SetMaxLetters(0)
    if box.SetMaxBytes then pcall(box.SetMaxBytes, box, 0) end
    -- A profile string has no spaces, and text breaks at spaces only, so it
    -- ran off the right edge in one line. Until 2026-10-18 the export carried
    -- line breaks against that, which went into every copy: CF7 on CurseForge,
    -- a player's 82 lines. It is one string since, and the box is asked to
    -- break it wherever it has to, on the text region it draws with. Whether
    -- this client hands that region out is not measured; where it does not,
    -- the string runs on in one line and still copies whole.
    for _, region in ipairs({ box:GetRegions() }) do
        if type(region.SetNonSpaceWrap) == "function" then
            pcall(region.SetNonSpaceWrap, region, true)
        end
    end
    scroll:SetScrollChild(box)

    scroll:SetScript("OnMouseWheel", function(frame, delta)
        local range = frame:GetVerticalScrollRange()
        local value = frame:GetVerticalScroll() - delta * 20
        frame:SetVerticalScroll(math.max(0, math.min(range, value)))
    end)

    -- Clicking anywhere in the field, including the padding, starts editing.
    holder:EnableMouse(true)
    holder:SetScript("OnMouseDown", function() box:SetFocus() end)
    box:SetScript("OnMouseDown", function(self) self:SetFocus() end)

    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    box:SetScript("OnEditFocusGained", function(self) FP:HoldKeys(self) end)
    box:SetScript("OnEditFocusLost", function(self) FP:ReleaseKeys(self) end)

    -- Safety net: if the window closes while the field still has focus, the
    -- keyboard would stay captured and the character would stop responding.
    holder:SetScript("OnHide", function() box:ClearFocus() end)

    local function ShowHint()
        hint:SetShown((hint:GetText() or "") ~= "" and (box:GetText() or "") == "")
    end

    box:SetScript("OnTextChanged", function() ShowHint() end)

    --- The words shown while the field is empty.
    function holder:SetPlaceholder(text)
        hint:SetText(FP:T(text) or "")
        ShowHint()
    end

    function holder:SetContent(text)
        box:SetText(text or "")
        box:SetCursorPosition(0)
        scroll:SetVerticalScroll(0)
        ShowHint()
    end

    --- Puts the cursor in the field, for when the next thing to happen is a
    --- paste. The keyboard capture that comes with focus is released again on
    --- focus loss and on hide, as everywhere else.
    function holder:Focus()
        box:SetFocus()
    end

    function holder:GetContent()
        return box:GetText()
    end

    function holder:SelectAll()
        box:SetFocus()
        box:HighlightText()
    end

    holder.editBox = box
    return holder
end

--- A window with one large text field. Handing a long string out, or taking
--- one in.
--
-- One window, reused: there is never a reason to have two open, and building
-- it once keeps its position between uses.
--
-- @param text       pre-filled and selected, for handing a string out
-- @param onAccept   when given, a button appears and calls it with the field's
--                   contents. Without it the window is a display only.
function FP:TextWindow(title, subtitle, text, onAccept, acceptLabel)
    local WIDTH, AREA_H = 520, 240
    local PAD = self.PANEL_PAD

    local f = self.textWindow
    if not f then
        f = self:CreatePanel("ForeverPlusTextWindow", WIDTH, title, "")
        self:KeepAboveSettings(f)
        f:SetHeight(self.PANEL_HEADER + AREA_H + 56)

        f.area = self:CreateTextArea(f, WIDTH - 2 * PAD, AREA_H)
        f.area:SetPoint("TOPLEFT", PAD, -self.PANEL_HEADER)

        f.accept = self:CreateButton(f, "", 120, function()
            if f.onAccept then f.onAccept(f.area:GetContent()) end
        end)
        f.accept:SetPoint("BOTTOMLEFT", PAD, PAD)

        local selectAll = self:CreateButton(f, L["Select all"], 100, function()
            f.area:SelectAll()
        end)
        selectAll:SetPoint("BOTTOMRIGHT", -PAD, PAD)

        local close = self:CreateButton(f, L["Close"], 80, function() f:Hide() end)
        close:SetPoint("RIGHT", selectAll, "LEFT", -6, 0)

        self.textWindow = f
    end

    f.heading:SetText(self:T(title))
    f.subtitle:SetText(self:T(subtitle) or "")
    f.onAccept = onAccept
    f.area:SetPlaceholder(onAccept and
        L["Paste the text here with Ctrl+V, then press the button below."] or "")
    f.area:SetContent(text)

    if onAccept then
        f.accept:Show()
        f.accept.label:SetText(self:T(acceptLabel) or L["Apply"])
    else
        f.accept:Hide()
    end

    f:Show()

    -- Handing a string out: select it, because the next thing done is Ctrl+C.
    -- Taking one in: put the cursor in the field, because the next thing done
    -- is Ctrl+V, and a field with no cursor in it does not look like a field.
    if text and text ~= "" then
        f.area:SelectAll()
    elseif onAccept then
        f.area:Focus()
    end

    return f
end

-- ---------------------------------------------------------------------------
-- A short red line over the playfield
--
-- The ammunition's warning, here since 2026-11-05, when the durability warning
-- came to read the same. About two seconds in all, as asked for the first one,
-- just under the client's own red error line at the top of the screen.
--
-- A frame of its own rather than UIErrorsFrame, which ErrorFilter filters: a
-- player who hid every error still sees these.
-- ---------------------------------------------------------------------------

local LINE_SHARE = 0.15
local LINE_HOLD, LINE_FADE = 1.5, 0.5
local LINE_GAP = 6

local flashLines = {}

--- One red line, built once.
--
-- The client's own error font, so it reads like the red line the game prints
-- itself; a font object, as the locale rule wants. Red on purpose: it is a
-- warning over the playfield, not a row in our window, so the scheme does not
-- decide its color. It takes no mouse, so it can never swallow a click.
local function FlashFrame(line)
    if flashLines[line] then return flashLines[line] end

    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(1, 1)
    f:SetFrameStrata("HIGH")
    f:EnableMouse(false)

    local text = f:CreateFontString(nil, "OVERLAY")
    text:SetFontObject(_G.ErrorFont or FP:Font("heading") or "GameFontNormalLarge")
    text:SetPoint("CENTER")
    text:SetTextColor(1, 0.25, 0.25)
    f.text = text

    f:SetScript("OnUpdate", function(self, elapsed)
        self.left = (self.left or 0) - elapsed
        if self.left <= 0 then
            self:Hide()
            return
        end
        self:SetAlpha(math.min(1, self.left / LINE_FADE))
    end)
    f:Hide()

    flashLines[line] = f
    return f
end

--- Shows a warning for a moment.
--
-- @param line  which line it stands on, counted from the top: 1 the ammunition,
--              2 the durability. Each warning keeps its own, so two at once
--              can both be read.
function FP:FlashLine(line, text)
    local f = FlashFrame(line)
    f.text:SetText(text)
    -- Placed every time: the screen may have changed size since the last one.
    -- By the font's size rather than the text's height, which a hidden frame
    -- does not report.
    local _, size = f.text:GetFont()
    f:ClearAllPoints()
    f:SetPoint("TOP", UIParent, "TOP", 0,
        -math.floor(UIParent:GetHeight() * LINE_SHARE)
        - (line - 1) * ((tonumber(size) or 18) + LINE_GAP))
    f.left = LINE_HOLD + LINE_FADE
    f:SetAlpha(1)
    f:Show()
end

function FP:HideFlashLine(line)
    if flashLines[line] then flashLines[line]:Hide() end
end

-- ---------------------------------------------------------------------------
-- A question with two answers
--
-- One small window, reused by every question there is: deleting a character
-- since 0.7.1, and the reload after picking a language since phase 7.7. It was
-- the forget question alone until the second one arrived, and two copies of
-- the same window would only drift apart.
-- ---------------------------------------------------------------------------

local askPanel

local function AskPanel()
    if askPanel then return askPanel end
    local PAD, HEADER = FP.PANEL_PAD, FP.PANEL_HEADER

    local WIDTH = 380
    local f = FP:CreatePanel("ForeverPlusQuestion", WIDTH, "", "")
    FP:KeepAboveSettings(f)

    -- One anchor and an explicit width, with wrapping switched on, which is
    -- how Modules/Info.lua builds its paragraphs and for the reason it gives:
    -- the wrapped height is only reported once the width is known. The first
    -- version anchored both corners instead and left wrapping to the font,
    -- and the client cut the question off with an ellipsis.
    local function Paragraph(role)
        local fs = FP:FontString(f, "OVERLAY", role)
        fs:SetWidth(WIDTH - 2 * PAD)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        return fs
    end

    f.question = Paragraph("normal")
    f.question:SetPoint("TOPLEFT", PAD, -(HEADER + 4))

    f.detail = Paragraph("body")
    f.detail:SetPoint("TOPLEFT", f.question, "BOTTOMLEFT", 0, -8)

    -- "Do not ask again", for a question that offers it: deleting a gray
    -- item from the info bar since 1.0.2, like the quiver's question in
    -- Core/Merchant.lua. Unticked whenever the question opens and handed to
    -- the yes alone, so Cancel changes nothing.
    f.skip = FP:CreateToggle(f, L["Do not ask again"],
        function() return f.dontAsk == true end,
        function(value) f.dontAsk = value end)
    f.skip:SetWidth(WIDTH - PAD)
    FP:Tooltip(f.skip, L["Do not ask again"], function() return f.skipTip end)
    f.skip:Hide()

    -- The answer first, and closing after it. The other way round, the
    -- reload after picking a language was refused on 2026-10-05, "blocked
    -- action: ADDON_ACTION_BLOCKED Reload()", while Reload UI at the bottom
    -- of the settings window, which calls the same thing straight from its
    -- click, went through. Hiding this window first was the one difference:
    -- it runs the client's own scripts in between, after which the click no
    -- longer counted as the player's.
    f.yes = FP:CreateButton(f, "", 120, function()
        local onYes = f.onYes
        local skip = f.dontAsk == true and f.skip:IsShown()
        if onYes then onYes(skip) end
        f:Hide()
    end)
    f.yes:SetPoint("BOTTOMLEFT", PAD, PAD)

    f.no = FP:CreateButton(f, "", 120, function() f:Hide() end)
    f.no:SetPoint("BOTTOMRIGHT", -PAD, PAD)

    -- The most a button may take, half the room between the margins: see
    -- FP:Ask, which sizes both to their captions.
    f.maxButton = (WIDTH - 2 * PAD - 8) / 2

    askPanel = f
    return f
end

--- Asks a question with a yes and a no, and calls onYes on the yes.
--
-- Every text arrives ready to show: the caller translates, because the
-- question after picking a language speaks the language just picked rather
-- than the one in use.
-- @param spec  { title, question, detail, yes, no, onYes, skipTip }: with
--              skipTip, the hover of "Do not ask again", the box is offered
--              and onYes is told whether it was ticked
function FP:Ask(spec)
    local f = AskPanel()
    f.heading:SetText(spec.title or "")
    f.question:SetText(spec.question or "")
    f.detail:SetText(spec.detail or "")
    f.yes.label:SetText(spec.yes or "")
    f.no.label:SetText(spec.no or "")
    f.onYes = spec.onYes

    -- The box under the text, the row one box inset to the left of the
    -- margin, as in the quiver's question.
    f.dontAsk, f.skipTip = false, spec.skipTip
    f.skip:Refresh()
    f.skip:ClearAllPoints()
    local above = (spec.detail and spec.detail ~= "") and f.detail or f.question
    f.skip:SetPoint("TOPLEFT", above, "BOTTOMLEFT", -FP.ROW_BOX_X, -6)
    f.skip:SetShown(spec.skipTip and true or false)

    -- Shown before it is measured: wrapped text cannot report its height from
    -- inside a hidden frame, and both lines here wrap.
    f:Show()

    -- Each button as wide as its caption, 120 at least: the French "Recharger
    -- maintenant" after picking a language was cut short at 120, the owner's
    -- screenshot of 2026-10-11.
    -- The unbounded width where the client has it: a caption already cut
    -- short may report only what is drawn.
    for _, button in ipairs({ f.yes, f.no }) do
        local label = button.label
        local measure = label.GetUnboundedStringWidth or label.GetStringWidth
        local need = math.ceil(measure(label)) + 16
        button:SetWidth(math.min(math.max(120, need), f.maxButton))
    end

    local detail = (spec.detail and spec.detail ~= "")
        and (8 + f.detail:GetStringHeight()) or 0
    local skip = f.skip:IsShown() and (6 + f.skip:GetHeight()) or 0
    f:SetHeight(FP.PANEL_HEADER + 4 + f.question:GetStringHeight() + detail
        + skip + 16 + 22 + FP.PANEL_PAD)
end

-- ---------------------------------------------------------------------------
-- Forgetting a character
--
-- One question for every place that can delete a character: the info bar's
-- gold list since 0.7.1, and the mail window's list of characters since
-- 2026-10-03, asked for on CurseForge. Moved here from InfoBar.lua that day so
-- both ask the same thing in the same words.
-- ---------------------------------------------------------------------------

--- Asks whether to delete everything kept about a character, and does it.
-- @param key     the character's key, see FP:CharacterKey
-- @param shown   its name as the question shows it, class color included
-- @param onDone  optional, called after a delete that went through
function FP:AskToForgetCharacter(key, shown, onDone)
    shown = shown or "?"
    self:Ask({
        title    = L["Delete Character Data"],
        question = L["Do you really want to delete the data for your character "
            .. "%s from ForeverPlus?"]:format(shown),
        detail   = L["This deletes its gold, its place in the mail list, its "
            .. "profile assignment, its Auto Buy choices, its cooldowns, the "
            .. "notices it has already been shown and the chat saved from "
            .. "its last session. Profiles are shared by all characters and "
            .. "are kept."],
        yes      = L["Delete"],
        no       = L["Cancel"],
        onYes    = function()
            local removed, why = FP:ForgetCharacter(key)
            if not removed then return FP:Warn("%s.", FP:T(why)) end
            FP:Print(L["ForeverPlus no longer keeps anything about %s."], shown)
            if onDone then onDone() end
        end,
    })
end
