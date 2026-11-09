-- Bar management, and the details every entry on the Buffs and Consumables
-- pages opens.
--
-- Planned with the owner on 2026-10-14 and 15, see
-- planning/1.0.0/PLANNING-BUFFS-AND-LAYOUT.md. Both pages open the same
-- window, and it is where a bar is made, named, sized, given a growth and a
-- look, moved and deleted; the pages keep only what belongs to an entry, its
-- bar and its own warning time, in details that open under its row. The data
-- is Core/Bars.lua's, the drawing Core/Warnings.lua's.
local ADDON, FP = ...
local L, N = FP.L, FP.N
local Bars = FP.Bars

-- ---------------------------------------------------------------------------
-- What both pages need
-- ---------------------------------------------------------------------------

--- A length of time the way the pages write it: whole minutes where it is
--- whole minutes, seconds below one.
function FP.FormatDuration(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    if seconds < 60 then return L["%d s"]:format(seconds) end
    if seconds % 60 == 0 then return L["%d min"]:format(math.floor(seconds / 60)) end
    return L["%d:%02d min"]:format(math.floor(seconds / 60), seconds % 60)
end

--- The bars as a drop down lists them. **One table for every drop down on both
--- pages, refilled in place**, so a bar made, renamed or deleted in the window
--- shows up in every entry's details without a page being built again.
FP.barValues = {}

function FP:RefreshBarValues()
    local values = self.barValues
    for index = #values, 1, -1 do values[index] = nil end
    local store = Bars.Store()
    if not store then return values end
    for _, id in ipairs(Bars.Ids(store)) do
        values[#values + 1] = { id, Bars.NameOf(store, id) }
    end
    return values
end

--- The bar an entry starts on, from its key alone. Deleting a bar needs it, to
--- tell an entry moved there by hand from one that lives there.
function FP:FactoryOf(key)
    if type(key) ~= "string" then return Bars.FALLBACK end
    if key:find("^cons:") then return "consumables" end
    if key:find("^buffs:track/") then return "general" end
    local class, id = key:match("^buffs:([^/]+)/(.+)$")
    local buffs = self:GetModule("BuffExpiry")
    -- A buff of no class is kept under ALL, see FP.sharedBuffs.
    local list = (class == "ALL") and self.sharedBuffs or (self.classBuffs or {})[class]
    for _, entry in ipairs(list or {}) do
        if tostring(entry.id) == id then
            return buffs and buffs.FactoryBar and buffs.FactoryBar(entry) or "general"
        end
    end
    return Bars.FALLBACK
end

local manager   -- the window, built on first use

--- Something about the bars changed: the drop downs, the bars on screen, the
--- window and the open page all follow.
function FP:BarsChanged()
    self:RefreshBarValues()
    self:RedrawBars()
    if manager and manager:IsShown() then manager:Refresh() end
    self:NotifyOptionChanged()
end

-- ---------------------------------------------------------------------------
-- An entry's details
--
-- The owner's rounds 5 and 9: **every control that belongs to one entry sits
-- in its details**, which open under its row. The box still switches the
-- entry, the rest of the row opens and closes the details, so opening them
-- never changes what is selected, which is the window's rule for every row
-- that can fold. A closed row says that something about it was changed only
-- by a small square at its end, never by a summary of the values.
-- ---------------------------------------------------------------------------

local NOT_IN_USE = L["Not in use until another setting here allows it."]

--- A row's hover, with the sentence every grayed out row ends on: the
--- general one, or what the page says grays this one out.
local function Explained(text, blocked, why)
    return function()
        if not blocked() then return text end
        return text .. "|n|n" .. (why and why() or NOT_IN_USE)
    end
end

--- Faded with the alpha a row anywhere in the window gets when another
--- setting makes it meaningless.
local function Fade(frame, blocked)
    local paint = frame.Refresh
    frame.Refresh = function(self, ...)
        if paint then paint(self, ...) end
        self:SetAlpha(blocked() and 0.4 or 1)
    end
end

--- Five seconds under a minute, half minutes under ten, minutes above: a
--- range from nothing to half an hour in a reasonable number of clicks.
local function TimeStep(current, direction)
    current = tonumber(current) or 0
    if direction < 0 then current = current - 1 end
    if current < 60 then return 5 end
    if current < 600 then return 30 end
    return 60
end

--- Makes an entry row fold its details, and mark it when it was changed.
--
-- @param spec  { key, factory, isOpen(), toggle(), onToggled() }
function FP:MakeEntryRow(row, spec)
    local arrow = self:FontString(row, "OVERLAY", "faint")
    arrow:SetPoint("LEFT", self.ROW_ARROW_X, 0)

    -- The marker: a small square in the color of a switch that is on, at the
    -- end of the row. No value beside it, the owner's word of round 9.
    local marker = self:Texture(row, "OVERLAY", self.colors.on, 6, 6)
    marker:SetPoint("RIGHT", -8, 0)
    if row.text then self:FitLabel(row.text, row, marker, 6) end

    local function Fold()
        spec.toggle()
        row:Refresh()
        if spec.onToggled then spec.onToggled() end
    end
    -- A row with a box keeps the box for switching; a row without one, a
    -- hand on the Consumables page, folds wherever it is hit.
    if row.SplitClick then row:SplitClick(Fold) else row:SetScript("OnClick", Fold) end

    local base = row.Refresh
    function row:Refresh(...)
        if base then base(self, ...) end
        arrow:SetText(spec.isOpen() and "-" or "+")
        marker:SetColorTexture(unpack(FP.colors.on))
        marker:SetShown(Bars.Customized(Bars.Store(), spec.key, spec.factory))
    end
    row:Refresh()
    return row
end

--- The rows of an entry's own details: its bar, and where it has a time, its
--- own warning time. A page puts the rows it already had for the entry after
--- these.
--
-- @param spec  {
--     key, factory           the entry, see Core/Bars.lua
--     timed                  whether a warning time means anything for it
--     inherited()            the time the page's rule gives it right now
--     inheritedHelp          what the page's rule is, for the hover
--     blocked()              grayed out and locked, the entry being off
--     blockedText            why, where the general sentence would not say:
--                            a hand on the Consumables page has no box of
--                            its own, only a coating to choose
--     causes()               what grays it out, for the light on hover
--     changed()              after a change, so the page can update
--   }
-- @return a list of rows, each with its height in `.rowHeight`
function FP:EntryDetails(holder, spec)
    -- The names before the first drop down draws, or it would show an id.
    if #self.barValues == 0 then self:RefreshBarValues() end
    local rows = {}
    local function Blocked() return spec.blocked and spec.blocked() or false end
    local function Why() return spec.blockedText or NOT_IN_USE end
    local function Changed()
        if spec.changed then spec.changed() end
        FP:RedrawBars()
    end

    -- Wider than a drop down's usual 120: a bar's name is the player's, and
    -- the defaults run long in several languages.
    local barRow = self:CreateDropdown(holder, L["Bar"], {
        values = self.barValues,
        width = 170,
        Get = function() return Bars.Dest(Bars.Store(), spec.key, spec.factory) end,
        Set = function(id)
            if Blocked() then return end
            Bars.SetDest(Bars.Store(), spec.key, id, spec.factory)
            Changed()
        end,
    })
    self:Tooltip(barRow.tooltipTargets, L["Bar"],
        Explained(L["The bar for this entry's icons. Use Manage bars to "
            .. "change its settings."], Blocked, Why))
    Fade(barRow, Blocked)
    if spec.causes then self:PointAtCause(barRow, Blocked, spec.causes) end
    barRow.rowHeight = 24
    rows[#rows + 1] = barRow

    if spec.timed then
        local function Own() return Bars.Warn(Bars.Store(), spec.key) ~= nil end
        local function TimeBlocked() return Blocked() or not Own() end

        local ownRow = self:CreateToggle(holder, L["Custom warning time"], Own,
            function(value)
                if Blocked() then return end
                if value then
                    -- It starts where the page's rule stood, so switching it on
                    -- changes nothing until the number is moved.
                    Bars.SetWarn(Bars.Store(), spec.key, spec.inherited and spec.inherited() or 0)
                else
                    Bars.SetWarn(Bars.Store(), spec.key, nil)
                end
                Changed()
            end)
        self:Tooltip(ownRow, L["Custom warning time"],
            Explained(spec.inheritedHelp
                or L["Off: follows this page's warning time, including later "
                   .. "changes."], Blocked, Why))
        Fade(ownRow, Blocked)
        if spec.causes then self:PointAtCause(ownRow, Blocked, spec.causes) end
        ownRow.rowHeight = 22
        rows[#rows + 1] = ownRow

        local timeRow = self:CreateStepper(holder, L["Warn at"], {
            Get = function()
                return Bars.Warn(Bars.Store(), spec.key)
                    or (spec.inherited and spec.inherited()) or 0
            end,
            Set = function(value)
                -- Locked while it follows the page: the number shown is the
                -- page's then, and a click must not change it unseen.
                if TimeBlocked() then return end
                Bars.SetWarn(Bars.Store(), spec.key, value)
                Changed()
            end,
            min = 0, max = 1800, step = TimeStep,
            Format = function(value) return FP.FormatDuration(value) end,
        })
        self:Tooltip(timeRow.tooltipTargets, L["Warn at"],
            Explained(L["Warns when less than this time remains. At 0, skips "
                .. "advance warnings but still warns when missing."], TimeBlocked, function()
                    if Blocked() then return Why() end
                    return NOT_IN_USE
                end))
        Fade(timeRow, TimeBlocked)
        self:PointAtCause(timeRow, TimeBlocked, function()
            if Blocked() and spec.causes then return spec.causes() end
            return { ownRow }
        end)
        timeRow.rowHeight = 24
        rows[#rows + 1] = timeRow
    end

    for _, row in ipairs(rows) do
        if row.Refresh then row:Refresh() end
    end
    return rows
end

-- ---------------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------------

local W        = 400
local LIST_H   = 22
local GAP      = 8

local GROWTH_VALUES = {
    { "center",  L["Horizontal, centered"] },
    { "vcenter", L["Vertical, centered"] },
    { "right",   L["To the right"] },
    { "left",    L["To the left"] },
    { "down",    L["Downward"] },
    { "up",      L["Upward"] },
}

local selected = Bars.FALLBACK

--- How many switched on entries each bar holds, of both pages, for the list.
local function Counts()
    local store, counts = Bars.Store(), {}
    if not store then return counts end
    for _, name in ipairs({ "BuffExpiry", "Consumables" }) do
        local mod = FP:GetModule(name)
        if mod and mod.BarEntries and FP:IsWanted(name) then
            for _, item in ipairs(mod:BarEntries()) do
                local id = Bars.Dest(store, item.key, item.factory)
                counts[id] = (counts[id] or 0) + 1
            end
        end
    end
    return counts
end

local function Selected()
    local store = Bars.Store()
    if not (store and Bars.Get(store, selected)) then selected = Bars.FALLBACK end
    return store, Bars.Get(store, selected)
end

local function AskToDelete()
    local store, bar = Selected()
    if not bar or selected == Bars.FALLBACK then return end
    local id = selected
    local name = Bars.NameOf(store, id)
    local count = Counts()[id] or 0
    FP:Ask({
        title    = FP:T(L["Delete Bar"]),
        question = FP:T(L["Delete the bar %s?"]):format(name),
        detail   = FP:Plural(count, N["%d entry will move to %s."],
                       N["%d entries will move to %s."])
                   :format(count, Bars.NameOf(store, Bars.FALLBACK)),
        yes      = FP:T(L["Delete"]),
        no       = FP:T(L["Cancel"]),
        onYes    = function()
            local ok = Bars.Delete(Bars.Store(), id, function(key) return FP:FactoryOf(key) end)
            if ok then
                selected = Bars.FALLBACK
                FP:BarsChanged()
            end
        end,
    })
end

local restore   -- the question with three boxes, built on first use

--- Restoring the default setup, with the three resets the owner agreed on in
--- round 2, each its own box and all three off to start with.
local function AskToRestore()
    if not restore then
        local PAD, HEADER = FP.PANEL_PAD, FP.PANEL_HEADER
        local width = 380
        local f = FP:CreatePanel("ForeverPlusBarsRestore", width, L["Restore Default Setup"], "")
        FP:KeepAboveSettings(f)

        local text = FP:FontString(f, "OVERLAY", "body")
        text:SetWidth(width - 2 * PAD)
        text:SetJustifyH("LEFT")
        text:SetWordWrap(true)
        text:SetPoint("TOPLEFT", PAD, -(HEADER + 4))
        text:SetText(FP:T(L["Restores General Warnings, Combat Buffs and "
            .. "Consumables with their original assignments. Custom bars are "
            .. "kept but emptied. Positions, icon sizes and warning times "
            .. "stay unchanged unless selected below."]))
        f.text = text

        f.choice = { positions = false, sizes = false, times = false }
        local boxes = {
            { "positions", L["Reset default bar positions"] },
            { "sizes",     L["Reset default bar icon sizes"] },
            { "times",     L["Reset all warning times"] },
        }
        f.rows = {}
        for index, spec in ipairs(boxes) do
            local key = spec[1]
            local row = FP:CreateToggle(f, spec[2],
                function() return f.choice[key] end,
                function(value) f.choice[key] = value end)
            -- Both top corners from the line above, so the row takes its width
            -- from it. The box sits at the text's left edge.
            if index == 1 then
                row:SetPoint("TOPLEFT", text, "BOTTOMLEFT", -FP.ROW_BOX_X, -8)
                row:SetPoint("TOPRIGHT", text, "BOTTOMRIGHT", 0, -8)
            else
                row:SetPoint("TOPLEFT", f.rows[index - 1], "BOTTOMLEFT")
                row:SetPoint("TOPRIGHT", f.rows[index - 1], "BOTTOMRIGHT")
            end
            f.rows[index] = row
        end

        local yes = FP:CreateButton(f, L["Restore"], 120, function()
            local choice = f.choice
            local store = Bars.Store()
            if store then
                Bars.RestoreDefaults(store, choice)
                -- The pages' common times are their modules' to put back.
                if choice.times then
                    for _, name in ipairs({ "BuffExpiry", "Consumables" }) do
                        local mod = FP:GetModule(name)
                        if mod and mod.ResetWarningTimes then mod:ResetWarningTimes() end
                    end
                end
                selected = Bars.FALLBACK
                FP:BarsChanged()
            end
            f:Hide()
        end)
        yes:SetPoint("BOTTOMLEFT", PAD, PAD)
        local no = FP:CreateButton(f, L["Cancel"], 120, function() f:Hide() end)
        no:SetPoint("BOTTOMRIGHT", -PAD, PAD)
        restore = f
    end

    local f = restore
    f.choice.positions, f.choice.sizes, f.choice.times = false, false, false
    -- Shown before it is measured: wrapped text cannot report its height from
    -- inside a hidden frame.
    f:Show()
    for _, row in ipairs(f.rows) do row:Refresh() end
    f:SetHeight(FP.PANEL_HEADER + 4 + f.text:GetStringHeight() + 8
        + #f.rows * 22 + 16 + 22 + FP.PANEL_PAD)
end

local function Build()
    if manager then return manager end
    local PAD, HEADER = FP.PANEL_PAD, FP.PANEL_HEADER

    local f = FP:CreatePanel("ForeverPlusBars", W, L["Bars"], "")
    FP:KeepAboveSettings(f)
    manager = f

    -- The list of bars. Clicking one selects it; the settings below are always
    -- the selected bar's.
    local list = CreateFrame("Frame", nil, f)
    list:SetPoint("TOPLEFT", PAD, -(HEADER + 2))
    list:SetPoint("TOPRIGHT", -PAD, -(HEADER + 2))
    list:SetHeight(LIST_H)
    f.list, f.listRows = list, {}

    local function ListRow(index)
        local row = f.listRows[index]
        if row then return row end
        row = CreateFrame("Button", nil, list)
        row:SetHeight(LIST_H)
        row:SetPoint("TOPLEFT", 0, -(index - 1) * LIST_H)
        row:SetPoint("TOPRIGHT", 0, -(index - 1) * LIST_H)
        row.mark = FP:Texture(row, "BACKGROUND", FP.colors.tabOn)
        row.mark:SetAllPoints()
        local hl = FP:Texture(row, "HIGHLIGHT", FP.colors.hover)
        hl:SetAllPoints()
        row.count = FP:FontString(row, "OVERLAY", "faint")
        row.count:SetPoint("RIGHT", -8, 0)
        row.name = FP:FontString(row, "OVERLAY", "normal")
        row.name:SetPoint("LEFT", 8, 0)
        FP:FitLabel(row.name, row, row.count)
        row:SetScript("OnClick", function(self)
            selected = self.id
            f:Refresh()
        end)
        FP:Tooltip(row, function() return row.name:GetText() or "" end,
            L["Number of enabled entries assigned to this bar for your "
            .. "character."])
        f.listRows[index] = row
        return row
    end

    local newBar = FP:CreateButton(f, L["New bar"], 150, function()
        local store = Bars.Store()
        if not store then return end
        selected = Bars.Create(store)
        FP:BarsChanged()
    end)
    newBar:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -GAP)
    FP:Tooltip(newBar, L["New bar"],
        L["Creates an empty bar with the default appearance. Assign entries "
        .. "to it in their details."])

    local restoreButton = FP:CreateButton(f, L["Restore default setup"], 150, AskToRestore)
    restoreButton:SetPoint("TOPRIGHT", list, "BOTTOMRIGHT", 0, -GAP)
    FP:Tooltip(restoreButton, L["Restore default setup"],
        L["Restores the three default bars and their original assignments."])

    -- Both top corners from the line above, so every row takes the width of
    -- the window between its margins.
    local heading = FP:SectionHeading(f, "")
    heading:SetPoint("TOPLEFT", newBar, "BOTTOMLEFT", 0, -GAP)
    heading:SetPoint("TOPRIGHT", restoreButton, "BOTTOMRIGHT", 0, -GAP)
    f.heading = heading

    local rows = {}
    local function Add(row, height)
        local above = rows[#rows] or heading
        row:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, 0)
        row:SetPoint("TOPRIGHT", above, "BOTTOMRIGHT", 0, 0)
        row:SetHeight(height)
        rows[#rows + 1] = row
        return row
    end

    local function Bar() local _, bar = Selected() return bar end

    local nameRow = Add(FP:CreateInput(f, L["Name"], {
        width = 170,
        Get = function()
            local store = Selected()
            return store and Bars.NameOf(store, selected) or ""
        end,
        Set = function(text)
            local store = Selected()
            if store and Bars.Rename(store, selected, text) then FP:BarsChanged() end
        end,
    }), 24)
    FP:Tooltip(nameRow.tooltipTargets, L["Name"],
        L["The name shown in bar lists and entry details. Leave blank to "
        .. "restore the default name."])

    local sizeRow = Add(FP:CreateStepper(f, L["Icon size"], {
        min = Bars.MIN_SIZE, max = Bars.MAX_SIZE, step = Bars.SIZE_STEP,
        Get = function() local bar = Bar() return bar and bar.size or 48 end,
        Set = function(value)
            local bar = Bar()
            if bar then bar.size = value FP:RedrawBars() end
        end,
    }), 24)
    FP:Tooltip(sizeRow.tooltipTargets, L["Icon size"],
        L["Sets the size of every icon on this bar."])

    local growthRow = Add(FP:CreateDropdown(f, L["Growth direction"], {
        values = GROWTH_VALUES,
        -- The six directions are short phrases rather than words, and 120 cut
        -- them short already in English.
        width = 190,
        Get = function() local bar = Bar() return bar and bar.growth or "center" end,
        Set = function(value)
            local bar = Bar()
            if bar then bar.growth = value FP:RedrawBars() end
        end,
    }), 24)
    FP:Tooltip(growthRow.tooltipTargets, L["Growth direction"],
        L["Sets the bar's growth direction. At the screen edge, icons wrap "
        .. "to a new row or column."])

    local timerRow = Add(FP:CreateToggle(f, L["Show the remaining time"],
        function() local bar = Bar() return bar and bar.timer ~= false end,
        function(value)
            local bar = Bar()
            if bar then bar.timer = value FP:RedrawBars() end
        end), 22)
    FP:Tooltip(timerRow, L["Show the remaining time"],
        L["The countdown under each icon on this bar."])

    local lookRow = Add(FP:CreateDropdown(f, L["Missing icon color"], {
        values = FP.MISSING_LOOK_VALUES,
        width = 170,
        Get = function() local bar = Bar() return bar and bar.look or "gray" end,
        Set = function(value)
            local bar = Bar()
            if bar then bar.look = value FP:RedrawBars() end
        end,
    }), 24)
    FP:Tooltip(lookRow.tooltipTargets, L["Missing icon color"],
        L["Sets how missing buffs and consumables look on this bar. Borders "
        .. "stay red."])

    local move = FP:CreateButton(f, L["Position on screen"], 150, function()
        if FP.MoveBars then FP:MoveBars(selected) end
    end)
    move:SetPoint("TOPLEFT", rows[#rows], "BOTTOMLEFT", 0, -GAP)
    FP:Tooltip(move, L["Position on screen"],
        L["Hides settings and lets you move all bars and the info bar, with "
        .. "this bar highlighted. Apply saves positions; Cancel discards "
        .. "changes."])

    local reset = FP:CreateButton(f, L["Reset position"], 150, function()
        local bar = Bar()
        if not bar then return end
        bar.positioned, bar.point, bar.relPoint, bar.x, bar.y = nil, nil, nil, nil, nil
        FP:RedrawBars()
    end)
    reset:SetPoint("TOPRIGHT", rows[#rows], "BOTTOMRIGHT", 0, -GAP)
    FP:Tooltip(reset, L["Reset position"], function()
        if Bars.IsDefault(selected) then
            return L["Restores this bar's default position."]
        end
        return L["Moves this bar to the starting position for new bars."]
    end)

    local delete = FP:CreateButton(f, L["Delete bar"], 150, function()
        if selected ~= Bars.FALLBACK then AskToDelete() end
    end)
    delete:SetPoint("TOPLEFT", move, "BOTTOMLEFT", 0, -GAP)
    FP:Tooltip(delete, L["Delete bar"], function()
        if selected == Bars.FALLBACK then
            return L["This is the fallback bar and cannot be deleted."]
        end
        return L["Asks before deleting this bar. Its entries move to the "
            .. "fallback bar."]
    end)
    f.deleteButton = delete

    function f:Refresh()
        local store = Selected()
        if not store then return end
        FP:RefreshBarValues()

        local ids, counts = Bars.Ids(store), Counts()
        for index, id in ipairs(ids) do
            local row = ListRow(index)
            row.id = id
            row.name:SetText(Bars.NameOf(store, id))
            row.count:SetText(tostring(counts[id] or 0))
            row.mark:SetShown(id == selected)
            row.mark:SetColorTexture(unpack(FP.colors.tabOn))
            row:Show()
        end
        for index = #ids + 1, #self.listRows do self.listRows[index]:Hide() end
        list:SetHeight(#ids * LIST_H)

        heading.text:SetText(Bars.NameOf(store, selected))
        heading:Refresh()
        for _, row in ipairs(rows) do
            if row.Refresh then row:Refresh() end
        end
        delete:SetAlpha(selected == Bars.FALLBACK and 0.4 or 1)

        local height = HEADER + 2 + #ids * LIST_H + GAP + 22 + GAP
            + FP.SECTION_H + 24 * 4 + 22 + GAP + 22 + GAP + 22 + PAD
        self:SetHeight(height)
    end

    f:SetScript("OnShow", function(self) self:Refresh() end)
    return f
end

--- Opens bar management, with a bar selected if one is named.
function FP:OpenBarManager(id)
    local f = Build()
    if id and Bars.Get(Bars.Store(), id) then selected = id end
    f:Show()
    f:Refresh()
end

--- What the window shows, for the positioning session to put back.
function FP:BarManagerState()
    return manager and manager:IsShown() or false, selected
end

function FP:HideBarManager()
    if manager then manager:Hide() end
end
