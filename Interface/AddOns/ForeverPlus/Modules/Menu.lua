-- Settings window. /fplus or /fplus menu.
--
-- The window is a host for tabs, not a page of its own. Anything that wants a
-- page calls FP:RegisterTab and shows up here without this file changing --
-- the same arrangement the module list already uses for options.
--
-- On resolutions: WoW's UI coordinates are virtual, not pixels, so a panel
-- keeps its proportions across displays. Two things still need handling, and
-- both are handled below: a page can be taller than the screen (it scrolls),
-- and a position saved on a large display can land outside a smaller one (it
-- gets pulled back).
--
-- The panel chrome comes from Core/Widgets.lua.

local ADDON, FP = ...
local L, N = FP.L, FP.N

local M = FP:RegisterModule("Menu", {
    default  = true,
    hidden   = true,   -- this window itself is not a switchable feature
    desc     = L["This window."],
    options  = {
        -- None of this is set by hand. It is window state that belongs to the
        -- profile, so it travels with an export like everything else.
        -- Centered until the user drags it somewhere else.
        { key = "point",     type = "store", default = "CENTER" },
        { key = "relPoint",  type = "store", default = "CENTER" },
        { key = "x",         type = "store", default = 0 },
        { key = "y",         type = "store", default = 0 },
        -- Remembered by name: the tab order can change under it.
        { key = "activeTab", type = "store", default = "Gameplay" },
        -- Which modules are open in the list is *not* here. See `expanded`
        -- below: it is view state, and it lives for as long as the interface
        -- does.
    },
})

-- 460 since 2026-10-11, the owner's wish, from 400: three tabs a row in every
-- language, where the French, Russian and Spanish captions had made it two.
-- The longest are the Spanish "Barra de información" and "Experiencia de
-- juego", about 105 wide, measured off the owner's screenshots by the French
-- and English ones. Seen in game by the owner the same day, in every
-- language, and kept.
local W      = 460
-- For a page that sizes something by the window before its own frames have a
-- width: the Consumables page's search box was sized by a 400 written into it
-- and stood 60 units too far right from the day the window grew.
FP.WINDOW_W  = W
local TAB_H  = 24
local ROW_H  = 26
local FOOTER = 42

local SCROLL_STEP  = 26
local MIN_VIEWPORT = 120
local SCREEN_SHARE = 0.8    -- never take more than this much of the screen
local EDGE_MARGIN  = 40     -- this much of the window has to stay reachable

local TAB_GAP = 3

-- Three a row in every language, the owner's word of 2026-10-11: never four,
-- and never two, which the bar fell back to whenever a caption was too wide.
local TABS_PER_ROW = 3

--- Where the content starts, which depends on how many rows of tabs there are.
--
-- It was a constant until the sixth page arrived and the last two tabs were
-- drawn outside the window, over the playfield. A constant was always going to
-- be wrong here: the number of tabs grows with the addon, and the text size is
-- something the player sets.
local function ContentTop()
    local rows = M.tabRows or 1
    return FP.PANEL_HEADER + rows * TAB_H + (rows - 1) * TAB_GAP + 6
end

-- ---------------------------------------------------------------------------
-- The "Gameplay" page, called "Modules" until 0.7.0
--
-- A flat list, one entry per module, each expandable to show its options. Flat
-- rather than a page per module because the window is sized to its tallest
-- page: a second level of navigation would throw that calculation out, and a
-- window that jumps when you click a tab reads as a glitch.
--
-- Expanding does not resize the window either. It makes the content taller and
-- the page scrolls, which is the same rule.
--
-- Nothing here knows what an option looks like. Core/Options.lua builds the
-- widget and hands back its height; this file only places it.
-- ---------------------------------------------------------------------------

local HEADER_H  = 32
local INDENT    = 20

-- Every row on the page in display order, so that filtering and collapsing are
-- a single pass over one list.
--   { kind = "section"|"header"|"option", name = <module>, frame, height, text }
-- A section is a heading between two groups of modules. It has no module and
-- no search text of its own; it appears when anything under it appears.
-- `text` is what the search box matches against, lowercased once at build time.
local rows = {}

--- Which group a module belongs to, as an index into FP.moduleGroups.
local function GroupIndex(mod)
    for i, group in ipairs(FP.moduleGroups) do
        if group.key == mod.group then return i end
    end
    -- Unknown or missing goes to the last group rather than nowhere. A module
    -- somebody forgot to place is then merely late, and a row in the wrong
    -- place is a bug you can see; a row that vanished is one you cannot.
    return #FP.moduleGroups
end

-- Modules that opt out of the list. Otherwise you could switch the window off
-- from the inside and would only get back in through the command line.
--
-- Sorted by group, then by the module's own order, then by name. **Not** by
-- FP.order, which is the order the TOC loads the files in: that is a technical
-- order with technical reasons, and letting it decide what the player sees
-- meant the next technical constraint would silently rearrange the page.
local function ListedModules()
    local out = {}
    for _, name in ipairs(FP.order) do
        local mod = FP.modules[name]
        if not mod.hidden then out[#out + 1] = name end
    end

    table.sort(out, function(a, b)
        local ma, mb = FP.modules[a], FP.modules[b]
        local ga, gb = GroupIndex(ma), GroupIndex(mb)
        if ga ~= gb then return ga < gb end
        local oa, ob = ma.order or 100, mb.order or 100
        if oa ~= ob then return oa < ob end
        -- By name last, so two modules that forgot to say never swap places
        -- between sessions. An order that is merely wrong can be fixed; one
        -- that changes on its own cannot be trusted at all.
        return a < b
    end)
    return out
end

-- Which modules are open, for as long as this interface lives.
--
-- Deliberately not in the profile. It is view state rather than a setting:
-- nobody configures which rows are open, and storing it would mean every
-- exported profile carried "AutoRepair is expanded" to the next character.
-- Closing and reopening the window keeps it, a /reload does not, and that is
-- the same lifetime the frames themselves have.
local expanded = {}

local function IsExpanded(name)
    return expanded[name]
end

-- Which group headings are shut, with the same lifetime and for the same
-- reason as `expanded` above: it is view state, not a setting.
--
-- Keyed by module and heading rather than by the option table, so that a
-- heading keeps its state if the window is ever rebuilt.
local closedGroups = {}

local function GroupKey(moduleName, option)
    -- labelOn as well: a master switch that reports its state carries no plain
    -- label, and two of those would otherwise share the key "nil".
    return moduleName .. "/"
        .. tostring(option.label or option.labelOn or option.key)
end

local function SetExpanded(name, open)
    expanded[name] = open or nil
end

--- Does this module show anything when it is opened?
--
-- Known before the header is built, because the header says so: without it the
-- arrow would point at nothing and the hover text would promise settings that
-- are not there.
local function HasVisibleOptions(mod)
    for _, option in ipairs(mod.options or {}) do
        if (option.type or "toggle") ~= "store" then return true end
    end
    return false
end

--- The row for a module: a switch, a name, and somewhere to click to open it.
--- The caption of a module's own tab. Its name unless it asked for another.
local function PageName(mod)
    return (type(mod.page) == "string") and mod.page or mod.name
end

local function CreateModuleHeader(parent, name, hasOptions)
    local mod = FP:GetModule(name)
    -- A module with a page keeps its row, but the row no longer opens
    -- anything: its settings are a tab away.
    local paged = mod.page and true or false

    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)
    -- So a setting grayed out because this module is off can point at it.
    FP:RegisterModuleRow(mod, row)

    local hl = FP:Texture(row, "HIGHLIGHT", FP.colors.hover)
    hl:SetAllPoints()

    local arrow = FP:FontString(row, "OVERLAY", "faint")
    arrow:SetPoint("LEFT", 3, 0)

    -- The switch is a button of its own inside the row. Clicking the row opens
    -- the module, clicking the box turns it on and off -- one row, two things
    -- worth doing to it, and neither hidden behind a modifier key.
    local switch = CreateFrame("Button", nil, row)
    switch:SetSize(18, 18)
    switch:SetPoint("LEFT", 14, 0)
    local box = FP:Texture(switch, "ARTWORK", FP.colors.off, 13, 13)
    box:SetPoint("CENTER")
    local switchHL = FP:Texture(switch, "HIGHLIGHT", FP.colors.hover)
    switchHL:SetAllPoints()

    local label = FP:FontString(row, "OVERLAY", "normal")
    label:SetPoint("LEFT", switch, "RIGHT", 7, 0)
    FP:FitLabel(label, row)
    -- A module that only ever does something for some characters says so
    -- after its name, in the gray and the size of "(you)" beside your own
    -- class on the Buffs page, asked for by the owner on 2026-09-28 for the
    -- ammunition count.
    label:SetText(FP:ModuleTitle(mod)
        .. (mod.note and ("  |cff888888(" .. FP:T(mod.note) .. ")|r") or ""))

    -- No description beside the name any more. It had to be one line and was
    -- clipped whenever it did not fit, which is most of them -- and the hover
    -- text now says the same thing with room to say it properly. The list reads
    -- as a list again.
    --
    -- It is still searchable: the row's search text below keeps the
    -- description, whether or not it is on screen.

    switch:SetScript("OnClick", function()
        FP:ToggleModule(name)
        M:Refresh()
    end)

    row:SetScript("OnClick", function()
        -- Clicking still does the obvious thing, it is just a different
        -- obvious thing: a row whose settings live on a tab takes you there
        -- rather than expanding into nothing.
        if paged then return M:SelectTabByName(PageName(mod)) end

        -- Nothing to open, so the row is not a fold and the house rule sends
        -- the click to the switch. Before this it called for an expansion that
        -- could never happen, and the row simply felt dead.
        if not hasOptions then
            FP:ToggleModule(name)
            return M:Refresh()
        end

        SetExpanded(name, not IsExpanded(name))
        M:LayoutModules()
        M:Refresh()
    end)

    -- Two targets and two texts. The switch is a button in front of the row, so
    -- the row never sees a hover over it -- and the two do different things,
    -- which is worth saying rather than leaving to be discovered.
    -- Translated in pieces, here rather than when drawn: each part is a key of
    -- its own, and the parts joined are not.
    local title = FP:ModuleTitle(mod)
    local description = FP:T(mod.desc or "")
    FP:Tooltip(switch, title,
        description .. "|n|n" .. L["Click the box to turn it on and off."])
    local rowHint
    if paged then
        rowHint = L["Its settings have a tab of their own: |cffffffff%s|r. "
            .. "Click to go there."]:format(FP:T(PageName(mod)))
    elseif hasOptions then
        rowHint = L["Click the row to show its settings."]
    else
        rowHint = L["This module has nothing to set."]
    end
    FP:Tooltip(row, title, description .. "|n|n" .. rowHint)

    -- Drives the arrow and the expand-all button. A paged module is never
    -- open, so it must not count as closed either.
    row.hasOptions = hasOptions and not paged

    function row:Refresh()
        box:SetColorTexture(unpack(FP:IsEnabled(name) and FP.colors.on or FP.colors.off))
        -- Nothing to open means nothing to point at.
        arrow:SetText(row.hasOptions and (IsExpanded(name) and "-" or "+") or " ")
    end

    return row
end

--- Places the rows that should be on screen and sizes the page to them.
--
-- Called on every expand, collapse and keystroke in the search box. Cheap
-- enough to redo wholesale: it moves a few dozen frames, and anything
-- incremental would first have to work out what changed.
function M:LayoutModules()
    local content = self.modulesContent
    if not content then return 0 end

    local pad    = FP.PANEL_PAD
    local filter = self.filter or ""

    -- A module shows when it matches itself, and also when one of its options
    -- does -- otherwise searching for an option would hide the module it
    -- belongs to, and there would be nothing left to switch on.
    local hitHeader, hitOption = {}, {}
    if filter ~= "" then
        for _, row in ipairs(rows) do
            -- A section has no module behind it, so a match on it would land
            -- under a nil key and quietly do nothing.
            if row.kind ~= "section" and row.text:find(filter, 1, true) then
                if row.kind == "header" then hitHeader[row.name] = true
                else hitOption[row.name] = true end
            end
        end
    end

    -- Which headings still have something under them. A heading over nothing
    -- is worse than no heading: it says a group is there and then shows a gap.
    local liveSection = {}
    if filter ~= "" then
        for _, row in ipairs(rows) do
            if row.kind == "header" and (hitHeader[row.name] or hitOption[row.name]) then
                liveSection[row.section] = true
            end
        end
    end

    local y = 0
    for _, row in ipairs(rows) do
        local show
        if row.kind == "section" then
            show = (filter == "") or liveSection[row.section] == true
        elseif filter == "" then
            show = (row.kind == "header")
                or (IsExpanded(row.name) and not (row.group and closedGroups[row.group]))
        elseif row.kind == "header" then
            show = hitHeader[row.name] or hitOption[row.name]
        else
            -- While searching, a module opens itself. Hiding the very option
            -- that was searched for behind a collapsed row would be absurd.
            show = hitHeader[row.name] or row.text:find(filter, 1, true) ~= nil
        end

        if show then
            row.frame:ClearAllPoints()
            row.frame:SetPoint("TOPLEFT", pad + (row.kind == "option" and INDENT or 0), y)
            row.frame:SetPoint("TOPRIGHT", -pad, y)
            row.frame:Show()
            -- A custom entry may have resized itself since it was built -- the
            -- buff list is as tall as there are buffs.
            y = y - ((row.frame.liveHeight and row.frame:GetHeight()) or row.height)
        else
            row.frame:Hide()
        end
    end

    local height = math.max(-y, 1)
    content:SetHeight(height)
    self:UpdateScrollIndicator()
    return height
end

--- Is anything still closed? Decides which way the button works.
local function AnythingClosed()
    for _, row in ipairs(rows) do
        if row.kind == "header" and row.frame.hasOptions and not IsExpanded(row.name) then
            return true
        end
    end
    return false
end

FP:RegisterTab({
    name  = N["Gameplay"],
    order = 10,

    -- A second switch above the modules' own, see *A page's switch* in
    -- Core/Config.lua: off stops every module on this page and keeps each
    -- one's own setting.
    switch = {
        labelOn  = L["Gameplay modules are on"],
        labelOff = L["Gameplay modules are off"],
        desc     = L["Turning this page off disables every module on it, "
                .. "including the minimap button. Each module keeps its own "
                .. "setting, so turning the page back on restores the "
                .. "previous settings."],
        Get = function() return not FP:PageOff(FP.LIST_PAGE) end,
        Set = function(on) FP:SetPageOff(FP.LIST_PAGE, not on) end,
    },

    -- The search box and the button that opens everything, in the strip that
    -- does not scroll. Both act on the whole page, and a control that acts on
    -- the whole page is useless the moment it scrolls out of sight.
    Header = function(_, host)
        local pad      = FP.PANEL_PAD
        local BUTTON_W = 98
        local search   -- assigned below; the button has to be able to clear it

        local function ClearSearch()
            M.filter = ""
            search.editBox:SetText("")
            search.editBox:ClearFocus()
            M:LayoutModules()
            M:Refresh()
        end

        local toggle = FP:CreateButton(host, L["Expand all"], BUTTON_W, function()
            -- While a search is running, what you see is decided by the filter
            -- and not by which rows are open, so opening them all would do
            -- nothing visible. The button becomes the way back out instead.
            if (M.filter or "") ~= "" then return ClearSearch() end

            local opening = AnythingClosed()
            for _, row in ipairs(rows) do
                if row.kind == "header" and row.frame.hasOptions then
                    SetExpanded(row.name, opening)
                end
            end
            M:LayoutModules()
            M:Refresh()
        end)
        toggle:SetPoint("TOPRIGHT", -pad, -5)
        M.expandButton = toggle

        -- As wide as the longest of its three captions needs, at least the
        -- width it always had. German runs longer than English, and a caption
        -- cut short with an ellipsis is the thing AGENTS.md rules out. The
        -- window is shown while this runs, so the widths are real.
        local width = BUTTON_W
        for _, caption in ipairs({ L["Expand all"], L["Collapse all"], L["Clear"] }) do
            toggle.label:SetText(caption)
            width = math.max(width, math.ceil(toggle.label:GetStringWidth()) + 16)
        end
        toggle.label:SetText(L["Expand all"])
        toggle:SetWidth(width)

        search = FP:CreateInput(host, nil, {
            -- W rather than host:GetWidth(): an anchor that has not resolved
            -- yet reports zero, and zero here would become a negative width.
            width = W - 2 * pad - width - 6,
            placeholder = L["Search"],
            Get = function() return M.filter or "" end,
            Set = function(value) M.filter = FP:Fold(value) end,
            -- Live, on every keystroke. Nothing here restarts a module, so the
            -- usual reason to wait for Enter does not apply.
            OnChange = function(value)
                M.filter = FP:Fold(value)
                M:LayoutModules()
                M:Refresh()
            end,
        })
        search:SetPoint("TOPLEFT", pad, -4)
        search:SetPoint("TOPRIGHT", toggle, "TOPLEFT", -6, 1)

        return HEADER_H
    end,

    Build = function(_, content)
        M.modulesContent = content
        rows = {}

        local pad   = FP.PANEL_PAD
        local width = content:GetWidth() - 2 * pad

        local lastGroup = nil
        for _, name in ipairs(ListedModules()) do
            local mod   = FP:GetModule(name)
            local paged = mod.page and true or false

            -- A heading whenever the group changes, which also means no
            -- heading for a group nothing landed in.
            local groupIndex = GroupIndex(mod)
            if groupIndex ~= lastGroup then
                lastGroup = groupIndex
                -- FP:SectionHeading rather than one built here, so a heading
                -- on this page and a heading on any other cannot drift apart.
                local heading, headingHeight =
                    FP:SectionHeading(content, FP.moduleGroups[groupIndex].label)
                rows[#rows + 1] = {
                    kind = "section", section = groupIndex, text = "",
                    frame = heading, height = headingHeight,
                }
            end

            -- A paged module's options were folded into its row's search text
            -- for one afternoon. The first module to get a page then left the
            -- list entirely, so there was no row to fold them into, and the
            -- owner said searching them was not wanted for now. Taken out
            -- rather than left as code that cannot run.
            -- In both languages, decided at the gate of phase 7.7: a player
            -- following an English guide finds the module on a German page
            -- too. The internal name stays findable as well.
            local searchText = table.concat({ name, mod.title or "",
                FP:ModuleTitle(mod), mod.desc or "", FP:T(mod.desc or "") }, " ")

            local header = CreateModuleHeader(content, name, HasVisibleOptions(mod))
            rows[#rows + 1] = {
                kind = "header", name = name, section = groupIndex,
                frame = header, height = ROW_H,
                -- Folded once here rather than on every keystroke. These are
                -- our own strings and not game text, so the byte-based lower()
                -- the locale rule warns about is safe, and FP:Fold adds the
                -- three umlauts it would miss.
                text = FP:Fold(searchText),
            }

            -- Rows after a collapsible heading belong to it, until the next
            -- heading ends it.
            local group = nil
            for _, option in ipairs(paged and {} or (mod.options or {})) do
                local frame, height = FP:BuildOption(content, mod, option, width - INDENT, true)
                if frame then
                    frame:Hide()
                    local entry = {
                        kind = "option", name = name, frame = frame, height = height,
                        text = FP:OptionSearchText(option),
                    }

                    -- A custom entry owns its own height and can change it.
                    -- When it does, everything below has to move, or it grows
                    -- into the next row.
                    if frame.liveHeight then
                        frame.OnResized = function() M:LayoutModules() end
                    end

                    if option.type == "group" then
                        group = nil
                        if frame.collapsible then
                            local key = GroupKey(name, option)
                            entry.groupHeader, group = key, key

                            if closedGroups[key] == nil then
                                closedGroups[key] = option.collapsed and true or false
                            end

                            frame:SetScript("OnClick", function()
                                closedGroups[key] = not closedGroups[key]
                                M:LayoutModules()
                                M:Refresh()
                            end)
                            frame.Refresh = function(self)
                                self.arrow:SetText(closedGroups[key] and "+" or "-")
                            end
                        end
                    else
                        entry.group = group
                    end

                    rows[#rows + 1] = entry
                end
            end
        end

        M:Refresh()
        return M:LayoutModules()
    end,

    -- Values can move without this page being what moved them: a profile
    -- switch, or a slash command.
    Refresh = function() M:Refresh() end,
})

-- ---------------------------------------------------------------------------
-- Pages that belong to a module
--
-- Same option list, same builder, same collapsing groups as the module list:
-- the only difference is that one module has the page to itself and there are
-- no headers to scroll past.
--
-- Phase 1 removed a hand-built tab and was right to. That one declared its own
-- controls beside the ones the module already had, and the two drifted apart
-- until the hover text existed on only one of them. Nothing here is
-- hand-built, so there is still exactly one description of the module.
-- ---------------------------------------------------------------------------

local modulePages = {}   -- [module name] = { entries, content }

-- ---------------------------------------------------------------------------
-- Blocks a page puts in order
--
-- Asked for by the owner on 2026-10-13 for the Info bar page: its switches,
-- each with the settings under it, can be dragged into another order while
-- "Allow reordering" is on, and the bar follows. Plain drag and drop, his
-- word, with no key to hold, since the switch already says when it is meant.
-- A module opts in with `arrange` and marks its rows with `block`, see
-- Core/Options.lua. The page lists the blocks in the module's order at every
-- layout, so the page and the bar never disagree, which is his rule of
-- 2026-09-24 that the page lists the figures in the order the bar shows them.
-- ---------------------------------------------------------------------------

--- The module's order of its blocks, or nil for a module without one.
local function Arrangement(mod)
    local arrange = mod and mod.arrange
    if type(arrange) ~= "table" or type(arrange.order) ~= "function" then
        return nil
    end
    local ok, order = pcall(arrange.order, mod)
    if ok and type(order) == "table" then return order end
    return nil
end

--- Whether the module lets its blocks be dragged right now.
local function ArrangeAllowed(mod)
    local arrange = mod and mod.arrange
    if type(arrange) ~= "table" or type(arrange.allowed) ~= "function" then
        return false
    end
    local ok, allowed = pcall(arrange.allowed, mod)
    return (ok and allowed) and true or false
end

--- A page's entries with its blocks in the module's order, where the first
--- block stood. A block the order does not name follows the others.
local function Arranged(mod, entries)
    local order = Arrangement(mod)
    if not order then return entries end

    local byBlock, first = {}, nil
    for index, entry in ipairs(entries) do
        if entry.block then
            first = first or index
            byBlock[entry.block] = byBlock[entry.block] or {}
            table.insert(byBlock[entry.block], entry)
        end
    end
    if not first then return entries end

    local out, placed = {}, {}
    for index = 1, first - 1 do out[#out + 1] = entries[index] end
    for _, key in ipairs(order) do
        if not placed[key] then
            placed[key] = true
            for _, entry in ipairs(byBlock[key] or {}) do out[#out + 1] = entry end
        end
    end
    for _, entry in ipairs(entries) do
        if entry.block and not placed[entry.block] then out[#out + 1] = entry end
    end
    for index = first, #entries do
        if not entries[index].block then out[#out + 1] = entries[index] end
    end
    return out
end

--- Which rows of a page a search leaves standing, as a set.
--
-- The Gameplay page's rules, for a module page with a search of its own: a
-- row stands when its text matches, and a heading only while something under
-- it stands, up to the next heading, since a heading over nothing says a part
-- is there and then shows a gap. A custom block searches itself and always
-- stands, and it ends the heading above it: on the one page with a search,
-- the Consumables page, each such block carries its own heading.
local function SearchPage(entries, filter)
    local found, heading, any = {}, nil, false
    local function Close()
        if heading and any then found[heading] = true end
        heading, any = nil, false
    end
    for _, entry in ipairs(entries) do
        if entry.heading then
            Close()
            heading = entry
        elseif entry.custom then
            Close()
            found[entry] = true
        elseif entry.text and entry.text:find(filter, 1, true) then
            found[entry], any = true, true
        end
    end
    Close()
    return found
end

--- Places the rows and sizes the page to them.
local function LayoutModulePage(name)
    local page = modulePages[name]
    if not (page and page.content) then return 0 end

    local pad, y = FP.PANEL_PAD, 0
    local available = (page.content:GetWidth() or 0) - 2 * pad

    -- Where the current line starts, and how wide the thing already on it is.
    local rowTop, rowWidth = 0, 0

    local mod = FP:GetModule(name)
    local entries = Arranged(mod, page.entries)

    -- What the module's own search box holds, folded, for a page that has one.
    -- While it holds anything, the search decides and the folding does not, as
    -- on the Gameplay page.
    local filter = mod and mod.PageSearch and mod:PageSearch() or ""
    local found = filter ~= "" and SearchPage(entries, filter) or nil

    for _, entry in ipairs(entries) do
        local hidden
        if found then
            hidden = not found[entry]
        else
            hidden = entry.group and closedGroups[entry.group]
        end
        if hidden then
            entry.frame:Hide()
        else
            -- A row that asked to share the line above it only gets to when
            -- both actually fit, margins included. Otherwise it takes a line of
            -- its own, which is what keeps two buttons out of each other on a
            -- smaller screen: the window is sized in fractions of UIParent, so
            -- its width really does change under the page.
            -- No indent on either side: both buttons sit on the page
            -- margin, so the pair needs its own widths and air between them.
            local share = entry.sameRow and available
                >= rowWidth + (entry.width or 0) + 12
            if entry.frame.SetSide then
                entry.frame:SetSide(share and "right" or "left")
            end

            local top = share and rowTop or y
            entry.frame:ClearAllPoints()
            entry.frame:SetPoint("TOPLEFT", pad + (entry.sub and INDENT or 0), top)
            entry.frame:SetPoint("TOPRIGHT", -pad, top)
            entry.frame:Show()

            if not share then
                rowTop, rowWidth = y, entry.width or 0
                -- A custom entry owns its height and can change it between
                -- layouts, so ask the frame rather than trusting what it
                -- reported when it was built.
                y = y - ((entry.frame.liveHeight and entry.frame:GetHeight()) or entry.height)
            end
        end
    end

    local height = math.max(-y, 1)
    page.content:SetHeight(height)
    M:UpdateScrollIndicator()
    return height
end

--- Lays every page out again, after something changed that pages cannot see.
--
-- A resolution or scale change is the case: the window is sized in fractions of
-- UIParent, so its width moves under a page that has already been laid out, and
-- a pair of buttons that fitted a moment ago may no longer.
function M:Relayout()
    for name in pairs(modulePages) do
        LayoutModulePage(name)
    end
    self:LayoutModules()
end

local function RefreshModulePage(name)
    local page = modulePages[name]
    if not page then return end
    for _, entry in ipairs(page.entries) do
        if entry.frame.Refresh then entry.frame:Refresh() end
    end
end

-- The dragging itself. One block moves at a time, so the state is one table.
local drag          -- { name, key, row } while a block is on the move
local dragShade     -- a tint over the block on the move
local GRIP_W = 12   -- the three bars that mark a row that can be dragged

--- The first and the last row of a block, as the page has laid them out.
local function BlockSpan(name, key)
    local page = modulePages[name]
    if not page then return nil end
    local first, last
    for _, entry in ipairs(Arranged(FP:GetModule(name), page.entries)) do
        if entry.block == key and entry.frame:IsShown() then
            first = first or entry.frame
            last = entry.frame
        end
    end
    return first, last
end

--- Tints the block on the move, from its switch to its last setting, in the
--- color of a switch that is on, read when it is shown so a scheme change
--- reaches it.
local function ShadeBlock()
    if not drag then
        if dragShade then dragShade:Hide() end
        return
    end
    local first, last = BlockSpan(drag.name, drag.key)
    if not (first and last) then return end
    if not dragShade then
        dragShade = CreateFrame("Frame", nil, first:GetParent())
        dragShade:EnableMouse(false)
        dragShade.tint = dragShade:CreateTexture(nil, "OVERLAY")
        dragShade.tint:SetAllPoints()
    end
    local on = FP.colors.on
    dragShade.tint:SetColorTexture(on[1], on[2], on[3], 0.18)
    dragShade:SetParent(first:GetParent())
    dragShade:SetFrameLevel(first:GetFrameLevel() + 5)
    dragShade:ClearAllPoints()
    dragShade:SetPoint("TOPLEFT", first, "TOPLEFT")
    dragShade:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT")
    dragShade:Show()
end

function M:EndBlockDrag()
    -- The row forgets the drag a frame later, after the release has been
    -- taken for a click it is not.
    local row = drag and drag.row
    if row then C_Timer.After(0, function() row.dragged = nil end) end
    drag = nil
    if self.dragDriver then self.dragDriver:Hide() end
    if dragShade then dragShade:Hide() end
end

--- Moves the dragged block to where the pointer is: after every other block
--- whose middle is above it. Runs every frame of a drag and acts only when
--- that place changes, so the rows move as the pointer passes their middle.
local function FollowPointer()
    if not drag then return M:EndBlockDrag() end
    -- The release can happen where no frame of ours hears it.
    if not (IsMouseButtonDown and IsMouseButtonDown("LeftButton")) then
        return M:EndBlockDrag()
    end
    local mod, page = FP:GetModule(drag.name), modulePages[drag.name]
    if not (mod and page) then return end

    -- Every block's first and last row, once per frame.
    local spans, keys = {}, {}
    for _, entry in ipairs(Arranged(mod, page.entries)) do
        local key = entry.block
        if key and entry.frame:IsShown() then
            local span = spans[key]
            if not span then
                span = {}
                spans[key] = span
                keys[#keys + 1] = key
            end
            span.first = span.first or entry.frame
            span.last = entry.frame
        end
    end
    local own = spans[drag.key]
    if not own then return end

    local _, cursorY = GetCursorPosition()
    cursorY = cursorY / own.first:GetEffectiveScale()

    local others, above = {}, 0
    for _, key in ipairs(keys) do
        if key ~= drag.key then
            others[#others + 1] = key
            local top, bottom = spans[key].first:GetTop(), spans[key].last:GetBottom()
            if top and bottom and (top + bottom) / 2 > cursorY then
                above = above + 1
            end
        end
    end
    table.insert(others, above + 1, drag.key)

    local moved = false
    for index, key in ipairs(others) do
        if keys[index] ~= key then moved = true break end
    end
    if not moved then return end

    -- The page's blocks in their new order, written into the module's whole
    -- order, where whatever the page does not show keeps its place.
    local onPage, merged, slot = {}, {}, 0
    for _, key in ipairs(keys) do onPage[key] = true end
    for _, key in ipairs(Arrangement(mod) or {}) do
        if onPage[key] then
            slot = slot + 1
            merged[#merged + 1] = others[slot]
        else
            merged[#merged + 1] = key
        end
    end
    FP:Safe(mod.name .. ":arrange", mod.arrange.set, mod, merged)
    LayoutModulePage(drag.name)
    ShadeBlock()
end

--- Makes a block's first row the handle it is dragged by.
local function WireBlockHead(mod, key, row)
    if not M.dragDriver then
        M.dragDriver = CreateFrame("Frame")
        M.dragDriver:Hide()
        M.dragDriver:SetScript("OnUpdate", function()
            FP:Safe("Menu:FollowPointer", FollowPointer)
        end)
    end

    -- Three short bars at the row's end while the module allows reordering,
    -- so the rows that can be dragged say so.
    local grip = CreateFrame("Frame", nil, row)
    grip:SetSize(GRIP_W, 10)
    grip:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    grip:EnableMouse(false)
    for line = 0, 2 do
        local bar = FP:Texture(grip, "OVERLAY", FP.colors.textOff, GRIP_W, 2)
        bar:SetPoint("TOP", 0, -line * 4)
    end
    grip:Hide()

    local base = row.Refresh
    row.Refresh = function(self, ...)
        if base then base(self, ...) end
        grip:SetShown(ArrangeAllowed(mod))
    end

    row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart", function(self)
        if not ArrangeAllowed(mod) then return end
        self.dragged = true
        drag = { name = mod.name, key = key, row = self }
        M.dragDriver:Show()
        ShadeBlock()
    end)
    row:SetScript("OnDragStop", function() M:EndBlockDrag() end)

    -- A drag ends with the button let go, often over the row it started on,
    -- which would otherwise take that for a click on its switch.
    local click = row:GetScript("OnClick")
    row:SetScript("OnClick", function(self, ...)
        if self.dragged then return end
        if click then return click(self, ...) end
    end)
end

--- Turns a module's option list into a page.
local function BuildModulePage(mod, content)
    local width = content:GetWidth() - 2 * FP.PANEL_PAD
    -- `ownedBySwitch` marks a group that came from a switch rather than from a
    -- heading. It ends at the first row that is not a sub setting, where a
    -- heading's group runs until the next heading: a switch owns the rows that
    -- qualify it and nothing else.
    local entries, group, ownedBySwitch = {}, nil, false

    for _, option in ipairs(mod.options or {}) do
        -- A sub row is narrower as well as quieter, because it is indented.
        local sub = option.sub and true or false
        -- The module's own switch is the box on the page's tab since
        -- 2026-09-30, and its entry here only lends the tab its words. See
        -- ModuleSwitch below.
        local frame, height
        if option.type ~= "module" then
            frame, height =
                FP:BuildOption(content, mod, option, width - (sub and INDENT or 0))
        end
        if frame then
            frame:Hide()
            local entry = {
                frame = frame, height = height, sub = sub,
                sameRow = option.sameRow and true or false,
                width   = frame.buttonWidth,
                block   = option.block,
                -- What a search of the page's own reads, see SearchPage.
                heading = option.type == "group",
                custom  = option.type == "custom",
                text    = FP:OptionSearchText(option),
            }

            -- The row a block is dragged by, see *Blocks a page puts in order*.
            if option.block and not sub and mod.arrange then
                WireBlockHead(mod, option.block, frame)
            end

            if frame.liveHeight then
                frame.OnResized = function() LayoutModulePage(mod.name) end
            end

            if option.type == "group" then
                group = nil
                if frame.collapsible then
                    -- Shared with the module list on purpose. A heading keeps
                    -- its state if a module ever gains or loses its page.
                    local key = GroupKey(mod.name, option)
                    entry.groupHeader, group = key, key

                    if closedGroups[key] == nil then
                        closedGroups[key] = option.collapsed and true or false
                    end

                    frame:SetScript("OnClick", function()
                        closedGroups[key] = not closedGroups[key]
                        LayoutModulePage(mod.name)
                        RefreshModulePage(mod.name)
                    end)
                    frame.Refresh = function(self)
                        self.arrow:SetText(closedGroups[key] and "+" or "-")
                    end
                end
            elseif frame.collapsible then
                local key = GroupKey(mod.name, option)
                entry.groupHeader, group, ownedBySwitch = key, key, true

                if closedGroups[key] == nil then
                    closedGroups[key] = option.collapsed and true or false
                end

                frame:SplitClick(function()
                    closedGroups[key] = not closedGroups[key]
                    LayoutModulePage(mod.name)
                    RefreshModulePage(mod.name)
                end)

                -- Chained rather than replaced. The row already has a Refresh
                -- that paints its own box, and a master switch that reports its
                -- state has another on top of that.
                local base = frame.Refresh
                frame.Refresh = function(self)
                    if base then base(self) end
                    self.foldArrow:SetText(closedGroups[key] and "+" or "-")
                end
            else
                if ownedBySwitch and not option.sub then
                    group, ownedBySwitch = nil, false
                end
                entry.group = group
            end

            entries[#entries + 1] = entry
        end
    end

    modulePages[mod.name] = { entries = entries, content = content }
    RefreshModulePage(mod.name)
    return LayoutModulePage(mod.name)
end

--- The switch on a module page's tab: the module's own on and off.
--
-- Worded by the module's `module` entry, which used to be drawn as the first
-- row of the page and now only says what the switch is called and what it
-- does. A page without one still gets a switch, in plainer words.
local function ModuleSwitch(mod)
    local words = {}
    for _, option in ipairs(mod.options or {}) do
        if option.type == "module" then words = option break end
    end
    local caption = PageName(mod)
    return {
        labelOn  = words.labelOn  or words.label
            or L["%s is on"]:format(FP:T(caption)),
        labelOff = words.labelOff or words.label
            or L["%s is off"]:format(FP:T(caption)),
        desc     = words.desc or L["Switches everything on this page on or off. "
                              .. "The settings are kept."],
        Get = function() return FP:IsEnabled(mod.name) end,
        Set = function(on)
            -- ToggleModule flips whatever is there, so ask first.
            if on ~= FP:IsEnabled(mod.name) then FP:ToggleModule(mod.name) end
        end,
    }
end

--- Registers a tab for every module that asked for one.
--
-- Called while the window is being built rather than at file scope, because
-- this file loads before the modules do: at load time there is nothing to ask.
-- Once, because a tab registered twice would be drawn twice.
function M:RegisterModulePages()
    if self.pagesRegistered then return end
    self.pagesRegistered = true

    for _, name in ipairs(FP.order) do
        local mod = FP:GetModule(name)
        if mod.page then
            FP:RegisterTab({
                name  = PageName(mod),
                order = mod.pageOrder or 20,
                -- The page is a column of rows whose heights come from the
                -- text size, so the number worked out at build time stops
                -- being true the moment that changes.
                automeasure = true,

                -- Every module page changes something in the game, so every
                -- one gets its switch without having to ask.
                switch = ModuleSwitch(mod),

                -- A module may bring a strip of its own for the controls that
                -- act on the whole page. The Gameplay page has had one since
                -- phase 1; this is the same thing, declared by the module
                -- rather than written here, so a page still describes itself
                -- in one place.
                Header = mod.PageHeader and function(_, host)
                    return mod:PageHeader(host)
                end or nil,

                Build = function(_, content)
                    return BuildModulePage(mod, content)
                end,
                Refresh = function()
                    RefreshModulePage(mod.name)
                    LayoutModulePage(mod.name)
                end,
            })
        end
    end
end

--- Opens a page by its caption. Nothing happens if there is no such tab, which
--- is the right answer for a module whose page was taken away.
function M:SelectTabByName(name)
    local index = self:IndexOfTab(name)
    if index then self:SelectTab(index) end
end

-- ---------------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------------

-- The switch on a tab: the same small square as a module's in the list, green
-- when on, in front of the caption. Its button takes the tab's full height and
-- this much of its width, so it is an easy target that never reaches the
-- caption.
local SWITCH_ROOM = 25
local SWITCH_BOX  = 13

-- How a page and its caption look while its switch is off. The page's alpha
-- is the one Core/Options.lua fades a row with that another setting has made
-- meaningless, because that is what this is, for a whole page.
local OFF_CAPTION = 0.45
local OFF_PAGE    = 0.4

--- The hover text of a tab's switch: what it is now, and what it does.
--
-- Under the whole tab rather than beside the box, where it would cover the
-- caption and the tabs next to it.
local function ShowSwitchTip(tabButton, switch)
    local ok, on = pcall(switch.Get)
    local title = (ok and on) and switch.labelOn or switch.labelOff
    FP:ShowTip(tabButton, { title or "", { switch.desc or "", wrap = true } }, "BOTTOM")
end

local function CreateTabButton(parent, label, onClick, switch, onSwitch)
    local b = CreateFrame("Button", nil, parent)

    local text = FP:FontString(b, "OVERLAY", "button")
    -- The tab's name is its identity and stays English; only the caption
    -- speaks the language in use.
    text:SetText(FP:T(label))
    -- One line, cut with an ellipsis if it must be: see PlaceCaption.
    text:SetWordWrap(false)

    -- Height only. The width comes from LayoutTabBar, which gives every button
    -- in a row the same one.
    b:SetHeight(TAB_H)

    local bg = FP:Texture(b, "BACKGROUND", FP.colors.tabOff); bg:SetAllPoints()
    -- Only the open tab is ever lit, as the cause of its own page being
    -- locked, so its light is measured against the open tab's color. The
    -- live table, which follows a change of scheme.
    b.causeBase = FP.colors.tabOn
    local hl = FP:Texture(b, "HIGHLIGHT", FP.colors.hover);   hl:SetAllPoints()

    if switch then
        -- The house rule for a row that does two things, applied to a tab: the
        -- tab opens its page wherever you hit it, except on the box, which
        -- switches. Neither is hidden behind a modifier key.
        local s = CreateFrame("Button", nil, b)
        s:SetPoint("TOPLEFT")
        s:SetPoint("BOTTOMLEFT")
        s:SetWidth(SWITCH_ROOM)
        local box = FP:Texture(s, "ARTWORK", FP.colors.off, SWITCH_BOX, SWITCH_BOX)
        box:SetPoint("LEFT", (SWITCH_ROOM - SWITCH_BOX) / 2, 0)
        local shl = FP:Texture(s, "HIGHLIGHT", FP.colors.hover); shl:SetAllPoints()

        s:SetScript("OnClick", function()
            onSwitch()
            -- The words say what it is now, so they change with the click.
            ShowSwitchTip(b, switch)
        end)
        s:SetScript("OnEnter", function() ShowSwitchTip(b, switch) end)
        s:SetScript("OnLeave", function() FP:HideTip(b) end)

        b.switch, b.switchBox = switch, box
    end

    -- Centred in the whole tab, with a switch or without, so the captions of
    -- one column sit under each other, the owner's request of 2026-09-30.
    -- PlaceCaption moves a caption right of the box where centred it would
    -- reach the box.
    text:SetPoint("CENTER")

    b.bg, b.text = bg, text
    b:SetScript("OnClick", onClick)
    return b
end

--- Whether a tab's page is switched on. A tab without a switch always is.
local function TabOn(tab)
    local switch = tab and tab.switch
    if not switch then return true end
    local ok, on = pcall(switch.Get)
    return not ok or on and true or false
end

-- ---------------------------------------------------------------------------
-- The language, at the bottom left
--
-- In the row of Reload UI, so it is there on every page, with a short word in
-- front of it: the owner's placement of 2026-10-05, over a section on the
-- Design page. One choice for the whole account, kept in FP.global beside the
-- profiles rather than inside one, so an exported profile carries no
-- language. It takes effect at the next reload, see Core/Locale.lua.
-- ---------------------------------------------------------------------------

-- Translated into the language just picked, not the one in use: a player who
-- picked their own language can read the question about it. Hence N.
local RELOAD_QUESTION = {
    title    = N["Language"],
    question = N["The language changes with the next reload. Reload now?"],
    yes      = N["Reload now"],
    no       = N["Later"],
}

local function LanguageValues()
    -- The languages in their own names, never translated: a player who cannot
    -- read the language in use still finds theirs.
    local values = { { "auto", L["Automatic"] } }
    for _, language in ipairs(FP.LANGUAGES) do
        values[#values + 1] = { language[1], language[2] }
    end
    return values
end

--- Stores a choice of language, and offers the reload that applies it.
function M:PickLanguage(value)
    FP.global.language = (value ~= "auto") and value or nil

    -- Nothing to reload when the pick changes nothing on screen: Automatic on
    -- a German client while German is in use.
    local after = FP:LanguageFor(FP.global.language)
    if after == FP.language then return end

    FP:Ask({
        title    = FP:TIn(after, RELOAD_QUESTION.title),
        question = FP:TIn(after, RELOAD_QUESTION.question),
        yes      = FP:TIn(after, RELOAD_QUESTION.yes),
        no       = FP:TIn(after, RELOAD_QUESTION.no),
        onYes    = function() ReloadUI() end,
    })
end

function M:BuildLanguagePicker(f, pad)
    local caption = FP:FontString(f, "OVERLAY", "body")
    -- On the middle line of the Reload UI button beside it, which is 22 high.
    caption:SetPoint("LEFT", f, "BOTTOMLEFT", pad, pad + 11)
    caption:SetText(L["Language"])

    local picker = FP:CreateDropdownButton(f, {
        values = LanguageValues(),
        Get = function() return FP.global.language or "auto" end,
        Set = function(value) M:PickLanguage(value) end,
    })
    -- Hung off the word rather than placed at a worked out offset, so it
    -- moves with the word when the text size or the language changes it.
    picker:SetPoint("LEFT", caption, "RIGHT", 8, 0)
    FP:Tooltip(picker, L["Language"], L["Applies to every character and "
        .. "profile. Automatic uses the game's language, or English if the "
        .. "addon does not support that language. Changes take effect after "
        .. "the next reload."])
    self.languagePicker = picker
end

function M:Build()
    if self.frame then return self.frame end

    -- Before anything reads the tab list. Modules load after this file, so
    -- this is the first moment there is anything to ask them.
    self:RegisterModulePages()

    local pad = FP.PANEL_PAD
    local f = FP:CreatePanel("ForeverPlusMenu", W, "ForeverPlus", "v" .. FP.version,
        function(point, relPoint, x, y)
            M.db.point, M.db.relPoint, M.db.x, M.db.y = point, relPoint, x, y
        end)
    self.frame = f

    -- Anchor before anything measures. A frame with no point has no position,
    -- and measurements taken there are not trustworthy.
    self:RestorePosition()

    -- The viewport. A page may be taller than the screen -- the module list
    -- grows with every module -- so the content scrolls instead of the window
    -- growing without limit.
    local scroll = CreateFrame("ScrollFrame", nil, f)
    scroll:SetPoint("TOPLEFT", 0, -ContentTop())
    scroll:SetWidth(W)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(frame, delta)
        local range = frame:GetVerticalScrollRange()
        local value = frame:GetVerticalScroll() - delta * SCROLL_STEP
        frame:SetVerticalScroll(math.max(0, math.min(range, value)))
        M:UpdateScrollIndicator()
    end)
    self.scroll = scroll

    self.tabs        = FP:SortedTabs()
    self.tabButtons  = {}
    self.tabContents = {}
    self.tabHeaders  = {}

    for index, tab in ipairs(self.tabs) do
        self.tabButtons[index] = CreateTabButton(f, tab.name,
            function() M:SelectTab(index) end,
            tab.switch,
            function() M:FlipSwitch(index) end)

        -- Said out loud rather than left to be noticed: a page that changes
        -- the game and has no switch breaks the rule without a sign of it.
        if not (tab.switch or tab.internal) then
            FP:Warn(L["The %s page has no switch on its tab. Give it a "
                .. "switch, or mark it internal if it only arranges the "
                .. "addon."], tab.name)
        end

        -- The fixed strip, outside the ScrollFrame so that it cannot scroll
        -- away. One per tab, and only the active one is shown.
        local header = CreateFrame("Frame", nil, f)
        header:SetPoint("TOPLEFT", 0, -ContentTop())
        -- Width set outright, for the same reason the content frames do it:
        -- a strip measures itself while it builds, and an unresolved anchor
        -- reports zero.
        header:SetWidth(W)
        header:SetHeight(1)
        header:Hide()
        self.tabHeaders[index] = header

        -- The content width is set explicitly rather than left to an anchor:
        -- pages measure themselves with GetWidth() while they build, and an
        -- anchor that has not resolved yet reports zero.
        local content = CreateFrame("Frame", nil, scroll)
        content:SetWidth(W)
        content:Hide()
        self.tabContents[index] = content
    end

    -- Anchored again by AnchorChrome once the bar knows how tall it is.
    local sep = FP:Texture(f, "ARTWORK", FP.colors.border)
    sep:SetHeight(1)
    self.sep = sep

    -- A thin indicator, shown only when there is something to scroll. Without
    -- it the wheel is an invisible feature.
    self.track = FP:Texture(f, "ARTWORK", { 1, 1, 1, 0.05 })
    self.track:SetWidth(3)
    self.track:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", -3, 0)
    self.track:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", -3, 0)

    self.thumb = FP:Texture(f, "OVERLAY", { 1, 1, 1, 0.22 })
    self.thumb:SetWidth(3)

    -- Laid over a page whose switch is off, from the top of its fixed strip to
    -- the bottom of the scrolling part: the page is faded behind it and takes
    -- no clicks, the owner's choice of 2026-09-30, and the hover says why. The
    -- wheel is passed on, so a page that is off can still be read to the end.
    -- Well above anything a page builds, custom entries included.
    local lock = CreateFrame("Frame", nil, f)
    lock:SetFrameLevel(scroll:GetFrameLevel() + 60)
    lock:EnableMouse(true)
    lock:EnableMouseWheel(true)
    lock:SetScript("OnMouseWheel", function(_, delta)
        local wheel = scroll:GetScript("OnMouseWheel")
        if wheel then wheel(scroll, delta) end
    end)
    lock:SetScript("OnEnter", function(self)
        local tab = M.tabs[M.activeIndex]
        FP:ShowTip(self, { tab and FP:T(tab.name) or "",
            { L["This page is switched off. The box on its tab switches it on "
           .. "again, with every setting here as you left it."], wrap = true } })
    end)
    lock:SetScript("OnLeave", function(self) FP:HideTip(self) end)
    -- The box on the tab is what locked the page, so the tab lights up while
    -- the lock is hovered, the owner's request of 2026-10-06. The whole tab
    -- rather than the box alone, which he found hard to see.
    FP:PointAtCause(lock, function() return true end, function()
        return { M.tabButtons and M.tabButtons[M.activeIndex] }
    end)
    lock:Hide()
    self.lock = lock

    local reload = FP:CreateButton(f, L["Reload UI"], 110, function() ReloadUI() end)
    reload:SetPoint("BOTTOMRIGHT", -pad, pad)

    self:BuildLanguagePicker(f, pad)

    -- Every bar and the info bar are moved from here, on every page, the
    -- owner's word of 2026-10-15: one session for all of them, with the
    -- settings out of the way. See Modules/Mover.lua.
    local move = FP:CreateButton(f, L["Move bars"], 120, function() FP:MoveBars() end)
    move:SetPoint("RIGHT", reload, "LEFT", -8, 0)
    FP:Tooltip(move, L["Move bars"],
        L["Hides settings so you can move all bars and the info bar. Apply "
        .. "saves positions; Cancel discards changes."])

    -- Measure with the window shown. Wrapped text cannot report its height
    -- from inside a hidden frame, and the tab bar needs real string widths.
    -- Show and hide happen within one frame, so nothing is ever drawn.
    f:Show()
    self:LayoutTabBar()
    self.tallest = self:BuildAllTabs()
    f:Hide()

    self:ApplySize()
    self:SelectTab(self:IndexOfTab(self.db.activeTab) or 1)

    -- A window sized and placed for one display can be wrong on the next.
    self.watcher = CreateFrame("Frame")
    self.watcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
    self.watcher:RegisterEvent("UI_SCALE_CHANGED")
    self.watcher:SetScript("OnEvent", function()
        FP:Safe("Menu:ApplySize", M.ApplySize, M)
        FP:Safe("Menu:EnsureOnScreen", M.EnsureOnScreen, M)
        FP:Safe("Menu:Relayout", M.Relayout, M)
    end)

    return f
end

--- Lays the tab buttons out three a row, and wraps the bar.
--
-- **Three a row since 2026-10-11**, the owner's word: the number used to come
-- from the widest caption, which gave the French, Russian and Spanish bars two
-- a row and would have given an English one at a small text size four. The
-- window grew to 460 for it, and the paragraphs below are the reasoning from
-- before, where the widest caption still decided.
--
-- Uniform buttons keep the bar from reflowing as pages come and go, and a tab
-- that changes width when you click it reads as a glitch. That was the whole
-- of it until the sixth page arrived: six tabs at the width of "Consumables"
-- are wider than the window, and the bar simply ran off the right edge and
-- drew the last two over the playfield.
--
-- Narrower buttons would have been the cheaper fix and the wrong one. The
-- label is what a tab is for, and the text size is the player's to set, so
-- squeezing the buttons only moves the failure to the next notch of the Design
-- page. Rows cost height instead, and height is the one thing this window can
-- give: it is sized to its tallest page anyway.
--
-- **Every row fills the width**, edge to edge with the same margin every other
-- element keeps, so the bar lines up with the rule underneath it. The widest
-- label only decides how many tabs a row can hold without clipping; once that
-- is known the buttons are stretched to share the row out between them.
--
-- The rows are balanced rather than filled: six tabs in a bar with room for
-- four become three and three, seven become three, two and two. A row holding
-- one lonely stretched button under two full ones reads as something having
-- gone wrong.
--
-- Buttons in different rows can therefore differ slightly in width, which is
-- the price of both other properties and the least visible of the three.
function M:LayoutTabBar()
    -- A caption is centred in the whole tab, so a tab with a switch keeps as
    -- much free on the right as the box takes on the left: up to the box's
    -- right edge, and 4 more so the caption never touches it.
    local boxEnd = (SWITCH_ROOM - SWITCH_BOX) / 2 + SWITCH_BOX

    local pad   = FP.PANEL_PAD
    local room  = W - 2 * pad
    local count = #self.tabButtons
    if count == 0 then
        self.tabRows = 1
        return
    end

    local rows  = math.ceil(count / TABS_PER_ROW)
    local base  = math.floor(count / rows)
    local extra = count % rows

    local index = 1
    for row = 0, rows - 1 do
        -- The remainder goes to the top rows, so any short row is the last one.
        local inRow = base + ((row < extra) and 1 or 0)
        local width = (room - (inRow - 1) * TAB_GAP) / inRow

        for column = 0, inRow - 1 do
            local button = self.tabButtons[index]
            button:SetWidth(width)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT",
                pad + column * (width + TAB_GAP),
                -(FP.PANEL_HEADER - 4 + row * (TAB_H + TAB_GAP)))
            self:PlaceCaption(button, width, boxEnd)
            index = index + 1
        end
    end

    self.tabRows = rows
    self:AnchorChrome()
end

--- Centres a tab's caption in the whole tab, the owner's request of
--- 2026-09-30, so the captions of one column sit under each other.
--
-- Where centred it would reach the switch box, it is centred in the room right
-- of the box instead, and where even that is too narrow, at a large text size,
-- the client cuts it with an ellipsis rather than the bar losing a column.
function M:PlaceCaption(button, width, boxEnd)
    local text = button.text
    local clear = button.switch and (boxEnd + 4) or 6
    text:ClearAllPoints()
    text:SetPoint("CENTER")
    local measure = text.GetUnboundedStringWidth or text.GetStringWidth
    if (width - measure(text)) / 2 >= clear then return end
    text:ClearAllPoints()
    text:SetPoint("LEFT", clear, 0)
    text:SetPoint("RIGHT", -4, 0)
end

--- Puts everything that hangs below the tab bar back where it belongs.
--
-- Called whenever the bar changes height. The separator and the fixed strips
-- are anchored to a number rather than to the bar itself, which is the one
-- place in this window where AGENTS.md's "anchor to the thing above" is not
-- followed: a strip belongs to its page and the bar belongs to the window, and
-- hanging every page off the bar would make a page move when a tab is added.
function M:AnchorChrome()
    local top = ContentTop()

    if self.sep then
        self.sep:ClearAllPoints()
        self.sep:SetPoint("TOPLEFT", FP.PANEL_PAD, -(top - 6))
        self.sep:SetPoint("TOPRIGHT", -FP.PANEL_PAD, -(top - 6))
    end

    for _, header in ipairs(self.tabHeaders or {}) do
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", 0, -top)
    end
end

--- Builds every page once and returns the tallest.
--
-- All pages are built up front rather than on first open, because the window
-- is sized to the tallest one. Each page is shown while it builds, for the
-- same measuring reason as above.
function M:BuildAllTabs()
    local tallest = 0

    for index, tab in ipairs(self.tabs) do
        local content = self.tabContents[index]

        if not tab.built then
            -- The fixed strip first: the page below it is placed underneath,
            -- and its height is part of what the window has to fit.
            tab.headerHeight = 0
            if tab.Header then
                local host = self.tabHeaders[index]
                host:Show()
                local okHeader, headerHeight = pcall(tab.Header, tab, host)
                if not okHeader then
                    FP:Warn(L["Tab %s failed to build its header: %s"],
                        tab.name, tostring(headerHeight))
                    headerHeight = 0
                end
                tab.headerHeight = tonumber(headerHeight) or 0
                host:SetHeight(math.max(tab.headerHeight, 1))
                host:Hide()
            end

            content:ClearAllPoints()
            content:SetPoint("TOPLEFT", self.scroll, "TOPLEFT", 0, 0)
            content:Show()

            -- A broken page must not take the window down with it.
            local ok, height = pcall(tab.Build, tab, content)
            if not ok then
                FP:Warn(L["Tab %s failed to build: %s"], tab.name, tostring(height))
                height = 40
            end
            tab.height = tonumber(height) or 120
            tab.built  = true

            content:SetHeight(tab.height)
            content:Hide()
        end

        -- A strip does not get its own room. It comes out of the scrolling
        -- area, so the window stays the same height whichever tab is open.
        local total = tab.height + (tab.headerHeight or 0)
        if total > tallest then tallest = total end
    end

    return tallest
end

--- Sizes the window to the tallest page -- but never past the screen.
--
-- UIParent's height is the UI's virtual height, which stays roughly constant
-- across resolutions. The user's scale setting and a small display can still
-- make a long page taller than the screen, and a window whose close button
-- sits below the bottom edge is a window you cannot close.
function M:ApplySize()
    local f = self.frame
    if not f then return end

    local room = UIParent:GetHeight() * SCREEN_SHARE - ContentTop() - FOOTER
    self.area = math.max(MIN_VIEWPORT, math.min(self.tallest or MIN_VIEWPORT, room))

    f:SetHeight(ContentTop() + self.area + FOOTER)
    self:PlaceScroll()
end

--- Puts the scrolling part under the active tab's fixed strip.
--
-- The window height is already settled by ApplySize and does not move: a strip
-- is taken out of the scrolling area rather than added to the window, so
-- switching between a tab that has one and a tab that does not never makes the
-- window jump.
function M:PlaceScroll()
    local tab    = self.tabs and self.tabs[self.activeIndex]
    local header = (tab and tab.headerHeight) or 0
    local area   = self.area or MIN_VIEWPORT

    self.scroll:ClearAllPoints()
    self.scroll:SetPoint("TOPLEFT", 0, -(ContentTop() + header))
    self.scroll:SetWidth(W)
    self.scroll:SetHeight(math.max(40, area - header))
    self:UpdateScrollIndicator()
end

--- Keeps the view inside the page after the page got shorter.
--
-- The client clamps the scroll only when it is set, so a page that shrank
-- while scrolled down went on showing the empty space below its new end:
-- "Collapse all" at the bottom of the module list left the window blank
-- until the wheel moved, reported by the owner on 2026-10-08. The view now
-- lands on the page's new end, or at its top when it fits whole. Measured
-- from the heights rather than GetVerticalScrollRange, which may not have
-- caught up with a height set a moment ago.
function M:ClampScroll()
    local scroll = self.scroll
    local content = scroll and scroll:GetScrollChild()
    if not content then return end
    local most = math.max(0, content:GetHeight() - scroll:GetHeight())
    if scroll:GetVerticalScroll() > most then
        scroll:SetVerticalScroll(most)
    end
end

-- Every change of a page's height ends here, so this is where the view is
-- kept inside it.
function M:UpdateScrollIndicator()
    self:ClampScroll()
    local scroll, track, thumb = self.scroll, self.track, self.thumb
    if not (scroll and track and thumb) then return end

    local content = scroll:GetScrollChild()
    if not content then return end

    local viewport, total = scroll:GetHeight(), content:GetHeight()
    if total <= viewport + 1 then
        track:Hide(); thumb:Hide()
        return
    end

    track:Show(); thumb:Show()
    local height = math.max(20, viewport * (viewport / total))
    thumb:SetHeight(height)

    local range    = scroll:GetVerticalScrollRange()
    local progress = (range > 0) and (scroll:GetVerticalScroll() / range) or 0
    thumb:ClearAllPoints()
    thumb:SetPoint("TOPRIGHT", track, "TOPRIGHT", 0, -progress * (viewport - height))
end

function M:RestorePosition()
    local f = self.frame
    f:ClearAllPoints()
    f:SetPoint(self.db.point or "CENTER", UIParent,
               self.db.relPoint or "CENTER", self.db.x or 0, self.db.y or 0)
end

function M:Center()
    local f = self.frame
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    self.db.point, self.db.relPoint, self.db.x, self.db.y = "CENTER", "CENTER", 0, 0
end

--- Pulls the window back to the center if its stored position is off screen.
--
-- A position saved on a large display can sit outside a smaller one, and
-- SetClampedToScreen only clamps while dragging, never on SetPoint.
function M:EnsureOnScreen()
    local f = self.frame
    if not f then return end

    local left, right  = f:GetLeft(), f:GetRight()
    local top, bottom  = f:GetTop(), f:GetBottom()
    if not (left and right and top and bottom) then return self:Center() end

    local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight()
    local reachable = right > EDGE_MARGIN and left < screenW - EDGE_MARGIN
                  and top > EDGE_MARGIN and bottom < screenH - EDGE_MARGIN

    if not reachable then
        self:Center()
        FP:Print(L["The settings window was off screen and has been moved "
              .. "back to the center."])
    end
end

function M:IndexOfTab(name)
    if not (name and self.tabs) then return nil end
    for index, tab in ipairs(self.tabs) do
        if tab.name == name then return index end
    end
    return nil
end

--- Switches pages. Nothing here touches the window size: every page shares
--- one viewport, so the window stays put.
function M:SelectTab(index)
    local tab = self.tabs and self.tabs[index]
    if not tab then return end

    for i, button in ipairs(self.tabButtons) do
        local active = (i == index)
        button.bg:SetColorTexture(unpack(active and FP.colors.tabOn or FP.colors.tabOff))
        button.text:SetTextColor(unpack(active and FP.colors.textOn or FP.colors.textOff))
        if not active then
            self.tabContents[i]:Hide()
            if self.tabHeaders[i] then self.tabHeaders[i]:Hide() end
        end
    end

    self.activeIndex = index
    if self.tabHeaders[index] then self.tabHeaders[index]:SetShown(tab.Header ~= nil) end
    self:PlaceScroll()
    -- Whether this page is locked depends on which page it is.
    self:RefreshSwitches()

    local content = self.tabContents[index]
    self.scroll:SetScrollChild(content)
    content:Show()
    self.scroll:SetVerticalScroll(0)
    self:UpdateScrollIndicator()

    self.db.activeTab = tab.name
    self:RefreshTab()
    self:RemeasureActivePage()
end

--- Works the open page's height out from what is actually in it.
--
-- Only for pages that ask for it. The module list computes its own height as
-- it lays itself out and would be measured wrongly here, because rows it has
-- deliberately hidden still have a position.
function M:RemeasureActivePage()
    local index = self.activeIndex
    local tab   = self.tabs and self.tabs[index]
    if not (tab and tab.automeasure) then return end

    local content = self.tabContents[index]
    if not (content and content:IsShown()) then return end

    local height = FP:MeasureExtent(content)
    if height and height > 0 then
        content:SetHeight(height + 6)
        self:UpdateScrollIndicator()
    end
end

--- Lets the open page update anything live before it is looked at.
--
-- Pages are built once, so whatever they showed at build time would otherwise
-- still be on screen an hour later.
function M:RefreshTab()
    local index = self.activeIndex
    local tab = self.tabs and self.tabs[index]
    if not (tab and tab.Refresh) then return end
    FP:Safe("tab " .. tab.name .. ":Refresh", tab.Refresh, tab, self.tabContents[index])
end

--- Flips the switch on a tab. It does not open the page: switching off what
--- you do not need is meant to take one click, wherever you are.
function M:FlipSwitch(index)
    local tab = self.tabs and self.tabs[index]
    if not (tab and tab.switch) then return end
    FP:Safe("tab " .. tab.name .. " switch", tab.switch.Set, not TabOn(tab))
    self:Refresh()
    self:RefreshTab()
end

--- Paints every tab's switch, fades the pages that are off, and locks the
--- open one if it is.
--
-- Asked every time rather than told: a switch can move without its box being
-- what moved it, through a profile switch, a slash command or the module list.
function M:RefreshSwitches()
    for index, button in ipairs(self.tabButtons or {}) do
        local on = TabOn(self.tabs[index])
        if button.switchBox then
            button.switchBox:SetColorTexture(unpack(on and FP.colors.on or FP.colors.off))
        end
        button.text:SetAlpha(on and 1 or OFF_CAPTION)

        local fade = on and 1 or OFF_PAGE
        if self.tabContents[index] then self.tabContents[index]:SetAlpha(fade) end
        if self.tabHeaders[index] then self.tabHeaders[index]:SetAlpha(fade) end
    end

    local lock, index = self.lock, self.activeIndex
    if not lock then return end
    if index and not TabOn(self.tabs[index]) then
        lock:ClearAllPoints()
        lock:SetPoint("TOPLEFT", self.tabHeaders[index], "TOPLEFT")
        lock:SetPoint("BOTTOMRIGHT", self.scroll, "BOTTOMRIGHT")
        lock:Show()
    else
        lock:Hide()
        FP:HideTip(lock)
    end
end

--- Brings every row on the module page back in step with what is stored.
--
-- Needed because a value can move without this page being what moved it: a
-- profile switch, a slash command, or a module changing its own setting.
function M:Refresh()
    for _, row in ipairs(rows) do
        if row.frame.Refresh then row.frame:Refresh() end
    end
    self:RefreshSwitches()

    -- One button, three jobs. Two or three of them side by side would mean one
    -- is always the wrong one to reach for, and during a search two of them
    -- would do nothing at all.
    if self.expandButton then
        local label
        if (self.filter or "") ~= "" then
            label = L["Clear"]
        else
            label = AnythingClosed() and L["Expand all"] or L["Collapse all"]
        end
        self.expandButton.label:SetText(label)
    end
end

function M:Toggle()
    local f = self:Build()
    if f:IsShown() then
        f:Hide()
    else
        -- Re-check every time: the resolution may have changed while the
        -- window was closed.
        self:ApplySize()
        self:EnsureOnScreen()
        self:Refresh()
        self:RefreshTab()
        f:Show()
    end
end

function M:OnEnable()
    -- Nothing to build up front: the window is created on first open.
    --
    -- Unless it already exists. A profile switch restarts every module, and by
    -- the time this runs the stored position belongs to the new profile -- so
    -- the window has to move, or the switch would only half apply.
    -- A leftover from when the open rows were stored in the profile. Cleared
    -- rather than left to ride along in every export from here on.
    if self.db then self.db.expanded = nil end

    if self.frame then
        self:RestorePosition()
        self:EnsureOnScreen()
        self:Refresh()
    end
end

function M:OnDisable()
    if self.frame then self.frame:Hide() end
end

-- One option can decide whether another is usable, and only the rows know how
-- they look. Refreshing the lot is cheap and needs no idea of which option
-- depended on which.
FP:OnOptionChanged(function()
    if not M.frame then return end
    M:Refresh()

    -- And the page that is open, which used to be left out. A setting can
    -- decide what a *page* shows, not only how its own row looks: the filter
    -- on the Consumables page hides most of the list, and it appeared to do
    -- nothing until something else happened to lay that list out again.
    -- Folding a block did it, which made the switch look unreliable rather
    -- than unwired.
    M:RefreshTab()
end)

-- A scheme change repaints every texture with the color it was created with.
-- For the tab bar that is wrong by definition: all of its buttons were built
-- in the inactive color, so after a repaint the active one is no longer
-- marked. Anything that decides a color at draw time rather than at creation
-- has to be asked to decide again.
FP:OnThemeChanged(function()
    if not M.frame then return end

    for index, button in ipairs(M.tabButtons or {}) do
        local active = (index == M.activeIndex)
        button.bg:SetColorTexture(unpack(active and FP.colors.tabOn or FP.colors.tabOff))
        button.text:SetTextColor(unpack(active and FP.colors.textOn or FP.colors.textOff))
    end

    -- Text size may have moved. Every label is a different width then, so the
    -- bar can gain or lose a row, and everything below it moves with that.
    M:LayoutTabBar()
    M:ApplySize()

    M:Refresh()
    M:RefreshTab()
    -- Wrapped text reflows with the text size too.
    M:RemeasureActivePage()
end)

--- Settings changed, but the window is staying open.
--
-- Without this a profile switch went through OnDisable and closed the window,
-- leaving you to type /fplus again to see the result of what you just did.
function M:Reapply()
    if not self.frame then return end
    self:RestorePosition()
    self:EnsureOnScreen()
    self:Refresh()
end
