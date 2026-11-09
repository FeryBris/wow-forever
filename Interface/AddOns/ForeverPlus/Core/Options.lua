-- Turning an option declaration into a widget.
--
-- A module describes everything it stores as one ordered list, and this file is
-- the only place that knows how each kind is drawn. Menu.lua asks for a row and
-- gets a frame and a height back; it never learns what a "select" is.
--
-- The declaration replaced `defaults` and `labels`, which were two tables for
-- one idea: the value lived in one, its caption in the other, and the menu had
-- to guess the kind from the Lua type -- which is why it could only ever render
-- booleans, and why a number like ChatTweaks' scroll step was invisible.
--
--   options = {
--       { key = "announce", type = "toggle", default = true,
--         label = "Report the cost in chat",
--         desc  = "Prints what was spent, so it does not happen unnoticed." },
--
--       { key = "warnSeconds", type = "number", default = 300,
--         label = "Warn below", min = 60, max = 1800, step = 60,
--         format = function(v) return math.floor(v / 60) .. " min" end },
--
--       { key = "quality", type = "select", default = 0, label = "Sell up to",
--         values = { { 0, "Poor" }, { 1, "Common" } } },
--
--       { key = "keep", type = "text", default = "", label = "Never sell" },
--
--       { type = "group",  label = "Display" },
--       { type = "action", label = "Position on screen", run = function() end },
--       { type = "custom", build = function(parent, width) return height end },
--       { key = "point",   type = "store", default = "CENTER" },
--   }
--
-- The order of the list is the order on screen -- there is no `order` field,
-- because sorting by key name is exactly what used to tear related options
-- apart.
--
-- A `number` may add `bigStep`, the step while Shift is held, for a range too
-- long to walk one step at a time: the chat search bar's offsets.
--
-- A `color` is a swatch the client's own color picker sets, stored as
-- { r, g, b, a }; nothing stored stands for `fallback(mod)`, and `opacity`
-- adds the picker's opacity. The info bar's look, since 2026-10-18.
--
-- `desc` may be a function of the module that returns the hover text when it
-- is shown, for a text that names something only the client knows the name
-- of: the info bar's cooldowns name Dedicated Study as the client calls it.
--
-- `block` marks rows that move together when the player puts a page in order,
-- the rows of one entry on the Info bar page with their sub settings. Only a
-- module that declares `arrange` has them moved:
--
--       arrange = {
--           allowed = function(mod) return mod.db.reorder end,
--           order   = function(mod) return { "time", "zone", ... } end,
--           set     = function(mod, order) ... end,
--       },
--
-- `order` names the blocks, `set` keeps a new order, and while `allowed` says
-- so the first row of each block that is not a sub setting can be dragged.
-- The page lists the blocks in `order` wherever the first of them stands, so
-- they must stand together in the list. See *Blocks a page puts in order* in
-- Modules/Menu.lua.
--
-- `store` declares something the module keeps but nobody sets by hand: a window
-- position, a remembered tab. It has a default and draws nothing. Without it
-- there would be two places a default could live again.
--
-- `get` and `set` in place of a `key` keep the value outside the profile, for a
-- setting the client already stores and offers a switch for:
--
--       { type = "select", label = "Timestamps", default = "none",
--         values = { ... },
--         get = function(mod) return GetCVar("showTimestamps") end,
--         set = function(mod, value) SetCVar("showTimestamps", value) end },
--
-- `disabled = function(mod)` grays a row out while another setting makes it
-- meaningless, and **hovering it lights up what grays it out**, since
-- 2026-10-06: FP:OptionCauses works that out from `disabled` alone, by trying
-- every setting it read with the other value. `causes = function(mod)` answers
-- instead where the cause is not in the profile, as a list of keys or ids, and
-- `id` names a row that has no `key`, so such a list can point at it.
--
-- In the module list, every setting under a module that is off is grayed out
-- with it, since 2026-10-06, and points at the module's row. `whileOff = true`
-- keeps one usable that acts on its own while the module is off.

local ADDON, FP = ...
local L = FP.L

-- Anything that has to look again after any option changed.
local changeListeners = {}

-- Every row BuildOption has drawn, by module and by an option's key or `id`, so
-- a row that is grayed out can find the rows that gray it out. The latest
-- drawing of a row wins: pages are built once, and rebuilt whole.
local drawn = {}

local function RowKey(mod, id)
    return tostring(mod and mod.name) .. "/" .. tostring(id)
end

--- The row drawn for one of a module's options, by its key or its `id`.
function FP:OptionRow(mod, id)
    return drawn[RowKey(mod, id)]
end

-- The id a module's own row in the module list is kept under, which no option
-- key can take.
local MODULE_ROW = "@module"

--- The module list's row for a module, so a setting grayed out because the
--- module is off can point at it.
function FP:RegisterModuleRow(mod, row)
    drawn[RowKey(mod, MODULE_ROW)] = row
end

--- Whether an option is grayed out because its whole module is off.
--
-- The owner's rule of 2026-10-06: in the module list, every setting under a
-- module that is switched off is grayed out with it, since none of them does
-- anything then. Not on a module's own page, which the switch on its tab
-- locks whole, and not for an option declaring `whileOff`, which acts on its
-- own: Looting's button for the client's auto loot. Headings are not grayed,
-- since they do nothing either way.
local function ModuleOff(mod, option)
    if option.whileOff or option.type == "group" or option.type == "store" then
        return false
    end
    if type(mod) ~= "table" or mod.page or not FP.IsEnabled then return false end
    return not FP:IsEnabled(mod.name)
end

function FP:OnOptionChanged(fn)
    changeListeners[#changeListeners + 1] = fn
end

--- Tells the listeners that a module's settings changed without a row being
--- set: the Info bar's order, which its button puts back to the default.
function FP:NotifyOptionChanged(mod, option)
    for index = 1, #changeListeners do
        FP:Safe("option listener", changeListeners[index], mod, option)
    end
end

-- Kinds that hold a value under `key`. The rest are furniture.
local VALUED = {
    toggle = true, number = true, select = true, text = true, store = true,
    color = true,
}

--- The initial values a module's options declare.
--
-- Used by Config when a profile is bound, so a new profile starts filled in and
-- an existing one picks up options added since it was made.
--
-- An option with its own `get` stores nothing, so it has nothing to fill in:
-- see OptionGet.
function FP:OptionDefaults(mod)
    local out = {}
    for _, option in ipairs(mod.options or {}) do
        if option.key and option.default ~= nil and not option.get
           and VALUED[option.type or "toggle"] then
            out[option.key] = option.default
        end
    end
    return out
end

--- Is this option unable to do anything at the moment?
--
-- `disabled` is a function on the option, because the answer depends on other
-- settings: ErrorFilter's individual errors mean nothing while it is told to
-- hide every error.
function FP:OptionDisabled(mod, option)
    if ModuleOff(mod, option) then return true end
    if not option.disabled then return false end
    local ok, answer = pcall(option.disabled, mod)
    return ok and answer and true or false
end

--- Why an option is grayed out, as a text still to translate, or nil while
--- it is not.
function FP:WhyDisabled(mod, option)
    if not self:OptionDisabled(mod, option) then return nil end
    if ModuleOff(mod, option) then return L["Not in use until you switch the "
                                       .. "module on."] end
    -- A function, for a row two settings can gray out, each with its own way
    -- back: the search bar's fading since 2026-10-18.
    if type(option.disabledText) == "function" then
        local ok, text = pcall(option.disabledText, mod)
        if ok and text then return text end
    end
    return (type(option.disabledText) == "string" and option.disabledText)
        or L["Not in use until another setting here allows it."]
end

--- `disabled`'s answer with `mod.db` behind a stand-in that notes every key
--- asked for, and may answer one of them differently.
local function AnswerWith(mod, option, key, value)
    local real = mod.db
    local read = {}
    mod.db = setmetatable({}, {
        __index = function(_, asked)
            read[#read + 1] = asked
            if asked == key then return value end
            return real[asked]
        end,
        __newindex = real,
    })
    local ok, answer = pcall(option.disabled, mod)
    mod.db = real
    return ok and answer and true or false, read
end

--- What a setting that grays a row out would have to read for the row to
--- work: the other answer of a switch, and for anything else no value.
local function Flipped(value)
    if type(value) == "boolean" then return not value end
    if value == nil then return true end
    return nil
end

--- The keys or ids of the options that gray this one out right now.
--
-- For the owner's light on what grays a row out, 2026-10-06. Worked out rather
-- than declared, so a new option needs no second list kept in step with its
-- `disabled`: every setting the answer read is tried with its other value, and
-- the ones that would let the row work are its causes. Of two switches joined
-- by `and`, that is the one that is off. When no single setting would do,
-- every setting the answer read is a cause together.
--
-- `causes = function(mod)` on an option answers instead, for a cause that is
-- not in the profile at all: the chat's timestamp format, which is the
-- client's own setting.
function FP:OptionCauses(mod, option)
    if ModuleOff(mod, option) then return { MODULE_ROW } end
    if option.causes then
        local ok, out = pcall(option.causes, mod)
        return (ok and type(out) == "table") and out or {}
    end
    if not option.disabled or type(mod) ~= "table" or type(mod.db) ~= "table" then
        return {}
    end

    local blocked, read = AnswerWith(mod, option)
    if not blocked then return {} end

    local out, seen = {}, {}
    for _, key in ipairs(read) do
        if not seen[key] then
            seen[key] = true
            if not AnswerWith(mod, option, key, Flipped(mod.db[key])) then
                out[#out + 1] = key
            end
        end
    end
    if #out == 0 then
        for key in pairs(seen) do out[#out + 1] = key end
        table.sort(out, function(a, b) return tostring(a) < tostring(b) end)
    end
    return out
end

--- Reads an option's current value.
--
-- **An option may keep its value somewhere else**, with a `get` and a `set` of
-- its own instead of a key. Added for the chat in phase 6, where several
-- settings are console variables the client's own options write as well: the
-- timestamp format, the style of the input line. Storing a copy in the profile
-- would make two switches for one value and leave the player unable to tell
-- which wins, which is the rule under *Decisions already made* in ROADMAP.md.
-- Reading the client's value every time makes this page a second view of the
-- one switch instead of a second switch.
function FP:OptionGet(mod, option)
    if option.get then
        local ok, value = pcall(option.get, mod)
        if ok and value ~= nil then return value end
        return option.default
    end
    local value = mod.db and mod.db[option.key]
    if value == nil then return option.default end
    return value
end

--- Writes an option and lets the module act on it.
--
-- The default route is RefreshModule, which restarts the module so OnEnable
-- reads the new value. An option that needs something cheaper, or something
-- else entirely, carries its own `apply`. One with its own `set` writes
-- nothing into the profile at all; see OptionGet.
function FP:OptionSet(mod, option, value)
    if not mod.db then return end
    -- A grayed-out row still takes a click; it just must not act on one.
    if self:OptionDisabled(mod, option) then return end

    if option.set then
        FP:Safe(mod.name .. ":" .. tostring(option.label or option.key) .. " set",
            option.set, mod, value)
    else
        mod.db[option.key] = value
    end

    if option.set then
        -- Nothing of the module's own moved, so nothing restarts: the set
        -- already did whatever the value needed.
    elseif option.apply then
        FP:Safe(mod.name .. ":" .. tostring(option.key) .. " apply", option.apply, mod, value)
    else
        FP:RefreshModule(mod.name)
    end

    -- One option can decide whether another is usable, so the rows around it
    -- have to look again. A list rather than a call into the menu: Core does
    -- not get to know what a menu is.
    self:NotifyOptionChanged(mod, option)
end

-- ---------------------------------------------------------------------------
-- Building
-- ---------------------------------------------------------------------------

local BUILDERS = {}

BUILDERS.toggle = function(parent, mod, option)
    local row = FP:CreateToggle(parent, option.label or option.key,
        function() return FP:OptionGet(mod, option) and true or false end,
        function(value) FP:OptionSet(mod, option, value) end)
    return row, 22
end

--- The module's own on and off, as a row like any other.
--
-- For a module that has left the list: its switch went with it, and a feature
-- you can only turn off from the command line is a feature you cannot turn off.
-- Holds no value of its own, so it is furniture rather than a setting, and a
-- profile never stores it: whether a module is on already lives in the profile
-- under its own name.
BUILDERS.module = function(parent, mod, option)
    local row = FP:CreateToggle(parent,
        option.label or option.labelOn or L["Enable %s"]:format(FP:ModuleTitle(mod)),
        function() return FP:IsEnabled(mod.name) end,
        function(value)
            -- ToggleModule flips whatever is there, so ask first. A refresh
            -- can set the same value back and must not switch it off.
            if value ~= FP:IsEnabled(mod.name) then
                FP:ToggleModule(mod.name)
            end
        end)
    -- A label that reports the state instead of naming the switch, when the
    -- schema asks for it with labelOn and labelOff. For a master switch, where
    -- "Buff warnings enabled" says in one line what a checkbox and a noun say
    -- in two.
    if option.labelOn and option.labelOff and row.text then
        local base = row.Refresh
        row.Refresh = function(self)
            if base then base(self) end
            row.text:SetText(FP:T(FP:IsEnabled(mod.name) and option.labelOn or option.labelOff))
        end
        row:Refresh()
    end

    return row, 22
end

BUILDERS.number = function(parent, mod, option)
    -- `min` and `max` may be functions of the module, asked when the value
    -- moves rather than when the page is built.
    local function Bound(limit)
        if type(limit) == "function" then return function() return limit(mod) end end
        return limit
    end
    local row = FP:CreateStepper(parent, option.label or option.key, {
        min = Bound(option.min), max = Bound(option.max), step = option.step,
        bigStep = option.bigStep,
        Format = option.format,
        Get = function() return FP:OptionGet(mod, option) end,
        Set = function(value) FP:OptionSet(mod, option, value) end,
    })
    return row, 26
end

BUILDERS.select = function(parent, mod, option)
    local row = FP:CreateDropdown(parent, option.label or option.key, {
        values = option.values or {},
        Get = function() return FP:OptionGet(mod, option) end,
        Set = function(value) FP:OptionSet(mod, option, value) end,
    })
    return row, 26
end

BUILDERS.text = function(parent, mod, option)
    local row = FP:CreateInput(parent, option.label or option.key, {
        width = option.width,
        placeholder = option.placeholder,
        Get = function() return FP:OptionGet(mod, option) end,
        Set = function(value) FP:OptionSet(mod, option, value) end,
    })
    return row, 26
end

--- A color the client's color picker sets, kept as { r, g, b, a }. Nothing
--- stored stands for `fallback(mod)`, which answers the color in use then,
--- the scheme's own as a rule; `opacity` adds the picker's opacity.
BUILDERS.color = function(parent, mod, option)
    local row = FP:CreateColorRow(parent, option.label or option.key, {
        opacity = option.opacity,
        Get = function()
            local color = FP:OptionGet(mod, option)
            if type(color) == "table" and color[1] then
                return color[1], color[2], color[3], color[4] or 1
            end
            if option.fallback then return option.fallback(mod) end
            return 1, 1, 1, 1
        end,
        Set = function(r, g, b, a)
            FP:OptionSet(mod, option, { r, g, b, option.opacity and a or 1 })
        end,
        IsSet = function()
            local color = FP:OptionGet(mod, option)
            return type(color) == "table" and color[1] ~= nil
        end,
        Clear = function() FP:OptionSet(mod, option, nil) end,
    })
    return row, 22
end

BUILDERS.action = function(parent, mod, option)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetHeight(28)

    local width = option.width or 150
    local button = FP:CreateButton(holder, option.label or L["Do it"], width,
        function()
            -- Grayed out, it must not act, like any other row: see OptionSet.
            if FP:OptionDisabled(mod, option) then return end
            FP:Safe(mod.name .. " action", option.run, mod)
        end)

    -- Which side it sits on is the page's decision rather than the schema's,
    -- because only the page knows how much room there is. A button asks to
    -- share a line with `sameRow`; whether it gets to is settled at layout.
    -- Both edges on the page margin, which is where the rule under every
    -- section heading begins and ends. A button is not a row with a label in
    -- it, so there is nothing for it to line up with in the label column, and
    -- the two indents it used to have made a pair of 150 wide buttons two
    -- units too wide for the window: they stacked, every time, on every page.
    function holder:SetSide(side)
        button:ClearAllPoints()
        if side == "right" then
            button:SetPoint("RIGHT", 0, 0)
        else
            button:SetPoint("LEFT", 0, 0)
        end
    end
    holder:SetSide("left")
    holder.buttonWidth = width

    -- The button covers the part of the row worth hovering, and it sits in
    -- front, so the frame behind it would never see an OnEnter.
    holder.tooltipTargets = { button }

    holder.Refresh = function() end
    return holder, 28
end

-- A heading, and optionally a switch for everything under it.
--
-- `collapsible` makes the heading clickable; `collapsed` starts it shut. What
-- being shut *means* is the page's business, not this file's -- only the page
-- knows how to lay itself out again -- so the button is built here and wired
-- there. A page that renders a collapsible group without wiring it gets an
-- inert heading rather than a broken one.
BUILDERS.group = function(parent, mod, option)
    -- A heading that does not collapse is the shared one, so a group inside a
    -- module and a section on a page are the same element and stay that way.
    -- The collapsible variant keeps its own body below: the menu wires its
    -- click and its arrow from outside, which the shared one does not expect.
    if not option.collapsible then
        return FP:SectionHeading(parent, option.label)
    end

    local collapsible = true
    local holder = CreateFrame(collapsible and "Button" or "Frame", nil, parent)
    holder:SetHeight(24)

    local text = FP:FontString(holder, "OVERLAY", "button")
    text:SetPoint("BOTTOMLEFT", collapsible and 12 or 0, 4)
    text:SetText(FP:T(option.label) or "")
    text:SetTextColor(unpack(FP.colors.textOn))

    if collapsible then
        local hl = FP:Texture(holder, "HIGHLIGHT", FP.colors.hover)
        hl:SetAllPoints()

        local arrow = FP:FontString(holder, "OVERLAY", "faint")
        arrow:SetPoint("BOTTOMLEFT", 1, 4)
        arrow:SetText("+")
        holder.arrow = arrow
    end
    holder.collapsible = collapsible

    local rule = FP:Texture(holder, "ARTWORK", FP.colors.border)
    rule:SetPoint("BOTTOMLEFT", text, "BOTTOMRIGHT", 8, 3)
    rule:SetPoint("BOTTOMRIGHT", 0, 3)
    rule:SetHeight(1)

    -- Same reason as the section headings in the module list: a texture made by
    -- FP:Texture follows a scheme change on its own, a text color set once
    -- does not. This was empty since phase 1, so every option heading kept the
    -- old color after a switch.
    holder.Refresh = function() text:SetTextColor(unpack(FP.colors.textOn)) end
    return holder, 24
end

BUILDERS.custom = function(parent, mod, option, width)
    local holder = CreateFrame("Frame", nil, parent)

    -- The module owns everything inside. It gets a frame and a width and hands
    -- back the height it needs -- this is the way out for anything that is not
    -- a setting at all, such as BuffExpiry's list of the buffs on you now.
    local ok, height = pcall(option.build, holder, width, mod)
    if not ok then
        FP:Warn(L["%s: custom option failed to build: %s"], mod.name, tostring(height))
        height = 0
    end

    height = tonumber(height) or 0
    holder:SetHeight(math.max(height, 1))

    -- The module owns this frame, so it may resize it. The page therefore asks
    -- the frame how tall it is when it lays out, rather than trusting the
    -- number that came back from here once.
    holder.liveHeight = true

    --- Changes the height and tells the page, if the page asked to be told.
    --
    -- Silent when nothing moved, because the caller is usually a refresh
    -- running once a second and a page that laid itself out that often would
    -- shift rows under the pointer.
    function holder:Resize(newHeight)
        newHeight = math.max(tonumber(newHeight) or 0, 1)
        if math.abs(self:GetHeight() - newHeight) < 0.5 then return end
        self:SetHeight(newHeight)
        if self.OnResized then
            FP:Safe(mod.name .. " custom resize", self.OnResized, self)
        end
    end
    holder.Refresh = option.refresh and function() FP:Safe(mod.name .. " custom refresh", option.refresh, holder, mod) end
                  or function() end
    return holder, height
end

--- Builds the widget for one option entry.
--
-- @return frame, height -- or nil for an entry that draws nothing
-- @param nested  true while rendering inside the module list, where every row
--                already sits under the module's own name and nothing can be
--                primary however the schema describes it. A page has no such
--                row above it, so there the schema decides.
function FP:BuildOption(parent, mod, option, width, nested)
    local kind = option.type or "toggle"
    if kind == "store" then return nil end

    local builder = BUILDERS[kind]
    if not builder then
        FP:Warn(L["%s: option %s has an unknown type %q"],
            mod.name, tostring(option.key or option.label), tostring(kind))
        return nil
    end

    local row, height = builder(parent, mod, option, width)
    if not row then return nil end

    -- Not a heading: those carry their own role and a level would overwrite it.
    if kind ~= "group" then
        self:ApplyLevel(row, (nested or option.sub) and "sub" or "primary")
    end

    -- A switch that has settings under it gets a handle to fold them away.
    -- The click cannot go on the row, because the row is the switch, so it
    -- goes on a small button in front of it and the box moves aside.
    --
    -- Wired by the page rather than here, exactly like a collapsible heading:
    -- which rows belong to it and where the state is kept are the page's
    -- business, and this file has never owned view state.
    if option.collapsible and kind ~= "group" and row.box then
        -- An arrow and nothing else. The click belongs to the whole row, which
        -- the page wires with row:SplitClick, so there is no handle to hit and
        -- no small target to miss.
        local arrow = self:FontString(row, "OVERLAY", "faint")
        arrow:SetPoint("LEFT", self.ROW_ARROW_X, 0)
        arrow:SetText("+")

        -- Nothing moves aside to make room. The gutter reserves it on every
        -- row, which is the only reason a switch that folds can line up with
        -- one that does not.
        row.foldArrow = arrow
        row.collapsible = true
    end

    -- labelOn as well: a switch that reports its state has no fixed label, and
    -- a nil title would take the hover text down with it.
    local title = option.label or option.labelOn or option.key
    -- A function is asked when the hover is shown: see `desc` above.
    local function Desc()
        local desc = option.desc
        if type(desc) == "function" then return desc(mod) end
        return desc
    end
    local describe = (type(option.desc) == "function") and Desc or option.desc

    -- Grayed out by another setting, or by its module being off in the list.
    local grayable = option.disabled
        or (not option.whileOff and option.type ~= "group" and option.type ~= "store"
            and not mod.page)

    if grayable then
        -- Faded, not removed. A setting that vanishes when another is turned on
        -- leaves you wondering whether you imagined it -- and it keeps its
        -- hover text, because "why is this grayed out" is exactly the question
        -- hover text exists for.
        --
        -- Translated in pieces: the two texts are keys of their own, and the
        -- two of them joined are not.
        describe = function()
            local desc = Desc()
            local why = FP:WhyDisabled(mod, option)
            if not why then return desc end
            return (desc and (FP:T(desc) .. "|n|n") or "")
                .. FP:T(why)
        end

        local function Fade(self)
            self:SetAlpha(FP:OptionDisabled(mod, option) and 0.4 or 1)
        end

        local inner = row.Refresh
        row.Refresh = function(self, ...)
            if inner then inner(self, ...) end
            Fade(self)
        end
        Fade(row)
    end

    FP:Tooltip(row, title, describe)
    -- And on whatever the widget says would otherwise swallow the hover.
    FP:Tooltip(row.tooltipTargets, title, describe)

    local id = option.key or option.id
    if id ~= nil then drawn[RowKey(mod, id)] = row end

    -- A row grayed out lights up what grays it out while it is hovered. After
    -- the tooltip, whose SetScript would otherwise replace the hook.
    if grayable then FP:PointOptionAtCause(row, mod, option) end
    return row, height
end

--- Lights up what grays `option` out while `frame` is hovered: for the row
--- drawn here, and for a control a custom option draws inside its own frame,
--- which the hover of that frame does not reach.
function FP:PointOptionAtCause(frame, mod, option)
    self:PointAtCause(frame,
        function() return FP:OptionDisabled(mod, option) end,
        function()
            local frames = {}
            for _, cause in ipairs(FP:OptionCauses(mod, option)) do
                frames[#frames + 1] = FP:OptionRow(mod, cause)
            end
            return frames
        end)
end

--- The text a search box matches an option against, in English and in the
--- language in use: a player following an English guide finds the setting
--- on a German page too.
function FP:OptionSearchText(option)
    local label = option.label
    local desc = option.desc
    if type(desc) == "function" then
        local ok, text = pcall(desc)
        desc = ok and text or nil
    end
    return FP:Fold(table.concat({
        tostring(option.key or ""), tostring(label or ""),
        tostring(desc or ""), tostring(FP:T(label) or ""),
        tostring(FP:T(desc) or ""),
    }, " "))
end
