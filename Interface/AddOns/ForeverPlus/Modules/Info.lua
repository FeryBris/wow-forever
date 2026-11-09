-- The "Info" page of the settings window: who made this, under which license,
-- and how to reach the developer.
--
-- Not a module -- there is nothing here to switch on or off. It is a tab, so
-- it registers with FP:RegisterTab and the menu picks it up.
--
-- On the word "link": WoW addons cannot open a browser. There is no API for
-- it, by design -- otherwise an addon could send you anywhere. The URL
-- therefore sits in a field you select and copy.

local ADDON, FP = ...
local L, N = FP.L, FP.N

local AUTHOR      = "Epicstrike"
local PROJECT_URL = "https://www.curseforge.com/wow/addons/foreverplus"
local LICENSE     = N["All rights reserved"]

-- The air under a section heading, the owner's request of 2026-10-06, when the
-- lines here sat right under the rule. The rows of every other page stand
-- about this far below their heading, since a row there is taller than its
-- text, where the lines here are only as tall as theirs.
local HEADING_GAP = 8

local function AddRow(parent, y, label, value)
    local pad = FP.PANEL_PAD

    local left = FP:FontString(parent, "OVERLAY", "faint")
    left:SetPoint("TOPLEFT", pad, y)
    left:SetWidth(70)
    left:SetJustifyH("LEFT")
    left:SetText(label)

    local right = FP:FontString(parent, "OVERLAY", "body")
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 6, 0)
    right:SetPoint("RIGHT", parent, "RIGHT", -pad, 0)
    right:SetJustifyH("LEFT")
    right:SetText(value)

    return y - 18
end

--- The line that says what the link under it does, wrapped rather than
--- run past the window's edge when a language makes it long.
local function AddLead(parent, y, text)
    local pad = FP.PANEL_PAD
    local fs = FP:FontString(parent, "OVERLAY", "body")
    fs:SetPoint("TOPLEFT", pad, y)
    fs:SetWidth(parent:GetWidth() - 2 * pad)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    fs:SetText(text)
    return y - math.max(fs:GetStringHeight(), 14) - 6
end

local function AddParagraph(parent, y, text, role)
    local pad = FP.PANEL_PAD
    local fs = FP:FontString(parent, "OVERLAY", role or "faint")
    fs:SetPoint("TOPLEFT", pad, y)
    -- An explicit width rather than a second anchor: GetStringHeight only
    -- reports the wrapped height once the width is actually known, and the
    -- page's height is computed from these values right away.
    fs:SetWidth(parent:GetWidth() - 2 * pad)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    fs:SetText(text)
    return y - fs:GetStringHeight() - 6
end

FP:RegisterTab({
    name  = N["Info"],
    order = 90,   -- last, unless something deliberately sorts after it
    -- Says who made the addon and changes nothing in the game, so its tab has
    -- no switch.
    internal = true,

    -- Built from wrapped paragraphs, whose height is only true for the text
    -- size they were measured at.
    automeasure = true,

    Build = function(_, content)
        local pad = FP.PANEL_PAD
        local y = -4

        local about = FP:SectionHeading(content, L["About"])
        about:SetPoint("TOPLEFT", pad, y)
        about:SetPoint("TOPRIGHT", -pad, y)
        y = y - FP.SECTION_H - HEADING_GAP

        y = AddRow(content, y, L["Author"],  AUTHOR)
        y = AddRow(content, y, L["License"], FP:T(LICENSE))
        y = AddRow(content, y, L["Client"],  "WoW Forever 1.60.1")
        y = y - 12

        -- State the outcome, not the mechanism: people decide whether to copy
        -- a link by what it does, not by what it is.
        local heading = FP:SectionHeading(content, L["Contact"])
        heading:SetPoint("TOPLEFT", pad, y)
        heading:SetPoint("TOPRIGHT", -pad, y)
        y = y - FP.SECTION_H - HEADING_GAP

        -- The project page, asked for by the owner on 2026-10-06: its
        -- comments are where ideas and bug reports reach him. The line that
        -- says what the link does keeps its own place under the heading.
        -- "Contact" names the section; this names the action, and people
        -- decide whether to copy a link by what it does.
        y = AddLead(content, y, L["Leave ideas and bug reports in the comments on CurseForge"])

        -- No "press Ctrl+C" instructions here. Selecting and copying a field is
        -- not something a WoW player needs explaining, and the line above the
        -- field already says where the link leads.
        local projectBox = FP:CreateCopyBox(content, PROJECT_URL, content:GetWidth() - 2 * pad)
        projectBox:SetPoint("TOPLEFT", pad, y)
        y = y - 34 - 12

        -- A section of its own, the owner's choice of 2026-10-06: under
        -- "Contact" the terms read as part of it, which they are not.
        local terms = FP:SectionHeading(content, L["License"])
        terms:SetPoint("TOPLEFT", pad, y)
        terms:SetPoint("TOPRIGHT", -pad, y)
        y = y - FP.SECTION_H - HEADING_GAP

        y = AddParagraph(content, y,
            L["Free to use, but not open source. You may not redistribute "
            .. "it, publish modified versions or reuse it in other addons. "
            .. "Provided without warranty. See the LICENSE file for the full "
            .. "terms."])

        return -y
    end,
})
