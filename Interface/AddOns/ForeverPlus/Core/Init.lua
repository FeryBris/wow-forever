-- ForeverPlus -- personal UI customizations for WoW Forever
-- Copyright (C) 2026 Epicstrike. All rights reserved.
--
-- Free to use, but not open source. You may read this code and change your own
-- copy; you may not redistribute the addon, publish a changed version, charge
-- for it, or reuse parts of it in other addons. See the LICENSE file.
--
-- Provided as is, without warranty of any kind.

-- Entry point. Creates the namespace that every other file receives through
-- `local ADDON, FP = ...`.

local ADDON, FP = ...
local L = FP.L

-- C_AddOns is the modern form; on some builds the old global still exists as an
-- alias. Take whichever is there instead of committing to one.
local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata

FP.name    = ADDON
FP.version = (GetMeta and GetMeta(ADDON, "Version")) or "dev"
FP.modules = {}   -- [name] = module definition
FP.order   = {}   -- registration order, keeps /fplus list stable

-- Global access for macros, /run and debugging.
_G.ForeverPlus = FP

-- The groups the module list is divided into, in the order they appear on the
-- page. A module names one with `group`.
--
-- Here rather than in Menu.lua because it is a statement about what this addon
-- does, not about how a list is drawn, and because a module has to be able to
-- name one without depending on the menu existing.
--
-- `Tools` last by the owner's decision: Diagnostics is a thing he keeps rather
-- than uses, so it stays reachable and stays out of the way.
FP.moduleGroups = {
    { key = "npc",       label = L["NPC Interaction"] },
    -- Everything done at a merchant, on the owner's word of 2026-10-10 once
    -- Auto Buy, the quiver and the reagents had joined selling and repairing:
    -- Auto Buy first, then what it buys, then the rest. "Loot and Money" kept
    -- only the loot and is called that since.
    { key = "merchant",  label = L["Merchants"] },
    { key = "loot",      label = L["Loot"] },
    { key = "interrupt", label = L["Interruptions"] },
    { key = "display",   label = L["Display"] },
    -- A group for one module, made on the owner's call for what phase 6 was
    -- going to bring. Empty since 0.8.0: the chat grew a page of its own and
    -- left the list, the way the buffs and the tooltip did. Kept, so that a
    -- chat feature that ever wants a row has its heading waiting, and a
    -- heading with nothing under it is never drawn.
    { key = "chat",      label = L["Chat"] },
    { key = "tools",     label = L["Tools"] },
}

--- Registers a module.
-- @param name  Unique name, shown in /fplus list.
-- @param def   Table with optional fields:
--                default   (bool)   on or off out of the box (default: true)
--                title     (string) the name the module list shows, marked
--                                   with L. The internal name stays what
--                                   commands such as /fplus list print; a
--                                   readable title in both languages was the
--                                   owner's decision of 2026-10-05.
--                desc      (string) description shown in the menu
--                note      (string) a short remark after the name in the
--                                   list, in gray: "Hunters only"
--                hidden    (bool)   keep it off the module list
--                group     (string) which entry of FP.moduleGroups the row
--                                   belongs under. An unknown or missing one
--                                   lands in the last group, so a module
--                                   somebody forgot is late rather than
--                                   invisible: a bug you can see.
--                order     (number) sort key inside that group, ties broken by
--                                   name. Deliberately separate from the TOC,
--                                   which is a *load* order with technical
--                                   reasons of its own (Data before the module
--                                   reading it, Core before Boot). The list
--                                   used to inherit that order, which meant the
--                                   next technical constraint would quietly
--                                   have moved a row on screen.
--                page      (bool or string, marked with N, like a tab's
--                                   name) give this module a tab of its own
--                                   instead of rows inside the module list.
--                                   Its options are rendered there by the same
--                                   builder, so there is still only one place
--                                   the module describes itself. A string is
--                                   the caption; true uses the module's name.
--                                   The module keeps its row in the list, with
--                                   the switch and nothing else, so that
--                                   turning it off stays where turning
--                                   everything else off is.
--                                   For a module whose settings have outgrown
--                                   a row. Judge it when the size is known;
--                                   this is not a thing to claim early.
--                pageOrder (number) sort key for that tab (default 20)
--                options   (table)  ordered list describing everything the
--                                   module stores -- its values, their kinds,
--                                   captions and hover text. Core/Options.lua
--                                   documents the entries and is the only file
--                                   that knows how each kind is drawn.
--                OnEnable  (func)   called when the module is enabled
--                OnDisable (func)   called when it is disabled; without it,
--                                   turning the module off needs a /reload
--                Reapply   (func)   optional. Called instead of OnDisable plus
--                                   OnEnable when settings changed but the
--                                   module stays on -- an option edit or a
--                                   profile switch. A module holding a window
--                                   wants this: being torn down and rebuilt
--                                   would close it.
-- @return the module definition, for `local M = FP:RegisterModule(...)`
function FP:RegisterModule(name, def)
    assert(type(name) == "string", "module name must be a string")
    assert(not self.modules[name], "module registered twice: " .. tostring(name))

    def = def or {}
    def.name    = name
    def.enabled = false
    if def.default == nil then def.default = true end

    self.modules[name] = def
    self.order[#self.order + 1] = name
    return def
end

function FP:GetModule(name)
    return self.modules[name]
end

--- What a module is called on screen, in the language in use.
function FP:ModuleTitle(mod)
    if type(mod) ~= "table" then return tostring(mod) end
    return self:T(mod.title or mod.name)
end

--- Does the Gameplay page's switch stop this module?
--
-- Every row of the module list without a page of its own. A module with a
-- page answers to that page's switch, even when it keeps a row in the list
-- that leads there, and a hidden one without a page, the window itself,
-- answers to none.
function FP:IsListed(mod)
    return type(mod) == "table" and not mod.hidden and not mod.page
end

-- ---------------------------------------------------------------------------
-- Tabs in the settings window.
--
-- Separate from modules on purpose: a module is a feature you switch on and
-- off, a tab is a page of the window. Some modules want a tab, some tabs
-- belong to no module at all.
-- ---------------------------------------------------------------------------

FP.tabs = {}

--- Registers a page in the settings window.
-- @param def  Table with:
--               name  (string) caption on the tab button, marked with N. It is
--                              the tab's identity as well, which is why it
--                              stays the English text: the window remembers
--                              the last tab by it, and only the button
--                              translates it. See FP.N in Core/Locale.lua.
--               order (number) sort key, lower comes first (default 100)
--               Build (func)   called once with (def, content) the first time
--                              the tab is shown. Fills the content frame and
--                              returns the height it needs, in pixels.
--               Refresh (func) optional, called with (def, content) every time
--                              the page is opened. For anything that shows
--                              live state and would otherwise go stale.
--               automeasure    optional. When true, the window works the page's
--                              height out from its contents every time the page
--                              is opened and whenever the text size changes,
--                              instead of trusting the number Build returned.
--                              For any page containing wrapped text, whose
--                              height stops being true the moment the text
--                              reflows.
--               Header (func)  optional, called once with (def, host). Fills a
--                              strip that sits above the scrolling part and
--                              stays put while it scrolls, and returns its
--                              height. For controls that act on the whole page
--                              -- a search box, an expand-all button -- which
--                              are useless the moment they scroll out of
--                              sight. The window does not grow to make room:
--                              the strip comes out of the scrolling area.
--               switch (table) the page's on and off, drawn as a box on its
--                              tab: { Get = func() -> bool, Set = func(bool),
--                              labelOn, labelOff, desc }. **Every page that
--                              changes something in the game has one**, the
--                              owner's rule of 2026-09-30, so a player can
--                              switch off what they do not need in one click.
--                              A module's own page gets it without asking: the
--                              module's switch, worded by the `module` entry
--                              in its options. A hand-built page declares it.
--               internal (bool) the page only arranges the addon itself, like
--                              Design, Profiles and Info, and has no switch. A
--                              page with neither this nor a switch is named in
--                              a warning when the window is built, so a new
--                              page cannot quietly go without one.
function FP:RegisterTab(def)
    assert(type(def) == "table", "tab definition must be a table")
    assert(type(def.name) == "string", "tab needs a name")
    assert(type(def.Build) == "function", "tab needs a Build function")

    def.order = def.order or 100
    self.tabs[#self.tabs + 1] = def
    return def
end

--- Tabs in display order. Ties break by name, so the order stays stable
--- regardless of which file happened to load first.
function FP:SortedTabs()
    local list = {}
    for i = 1, #self.tabs do list[i] = self.tabs[i] end
    table.sort(list, function(a, b)
        if a.order == b.order then return a.name < b.name end
        return a.order < b.order
    end)
    return list
end
