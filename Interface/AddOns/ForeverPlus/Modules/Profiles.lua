-- The "Profiles" page.
--
-- A page rather than a block on the module list, so that Delete is not sitting
-- above the switches somebody came here to flip.
--
-- Everything acts on the *selected* row rather than on the active profile.
-- Selection and activity are separate on purpose: deleting or resetting what
-- you are currently using is the easiest mistake to make here, and making the
-- target explicit removes it. Selection follows the active profile until the
-- user clicks something else.
--
-- Nothing on this page can destroy a profile without two clicks, and nothing
-- can overwrite one at all -- an import always lands on a new name.

local ADDON, FP = ...
local L, N = FP.L, FP.N

local MAX_ROWS   = 10
local ROW_H      = 20
local CONFIRM_FOR = 4   -- seconds an armed button stays armed

local selected          -- the profile name the buttons act on
local rows, nameBox, note, target = {}, nil, nil, nil

local function Selected()
    -- The selection can go stale: the profile it named may have been deleted
    -- or renamed from a command line while this page sat open.
    if selected and FP.global.profiles[selected] then return selected end
    return FP.profileName
end

--- Reports on the page, and in chat when it matters.
--
-- The page line is the last thing on a page that now scrolls, so it can sit
-- below the visible edge -- which is how an import failure went unseen and got
-- reported as "no message at all". Anything that went wrong, and anything that
-- changed stored data, goes to chat as well, where it cannot scroll away.
local function Say(text, bad, alsoChat)
    if note then
        note:SetText(text or "")
        note:SetTextColor(unpack(bad and { 1, 0.45, 0.45 } or { 0.6, 0.6, 0.65 }))
    end

    if text and text ~= "" and (bad or alsoChat) then
        if bad then FP:Warn("%s", text) else FP:Print("%s", text) end
    end
end

--- Makes a button as wide as its caption needs, never narrower than `min`.
--
-- German runs longer than English, and a caption cut short with an ellipsis is
-- what AGENTS.md rules out. `other` is a second caption the button can wear,
-- the question of a two-step button, so it fits both. The page is on screen
-- while it is built, so the widths are real.
local function Fit(button, min, other)
    local first = button.label:GetText()
    local width = math.max(min, math.ceil(button.label:GetStringWidth()) + 16)
    if other then
        button.label:SetText(other)
        width = math.max(width, math.ceil(button.label:GetStringWidth()) + 16)
        button.label:SetText(first)
    end
    button:SetWidth(width)
    return button
end

--- Turns a button into a two-step one: the first click asks, the second acts.
--
-- Deleting a profile cannot be undone, and this page is the only place it
-- happens. A confirmation dialog would be heavier than the action deserves; a
-- button that changes its own caption is enough. It disarms itself after a few
-- seconds, so an armed button that was forgotten cannot be hit later by
-- somebody who came back to the page for something else.
local function Confirming(button, label, question, act)
    local armed = false

    local function Disarm()
        armed = false
        button.label:SetText(label)
    end

    button:SetScript("OnClick", function()
        if armed then
            Disarm()
            act()
            return
        end
        armed = true
        button.label:SetText(question)
        if C_Timer and C_Timer.After then
            C_Timer.After(CONFIRM_FOR, function() if armed then Disarm() end end)
        end
    end)

    button.Disarm = Disarm
    return button
end

-- ---------------------------------------------------------------------------
-- The list
-- ---------------------------------------------------------------------------

local function Rebuild()
    if #rows == 0 then return end

    local names  = FP:ListProfiles()
    local active = FP.profileName
    local pick   = Selected()

    for index = 1, MAX_ROWS do
        local row, name = rows[index], names[index]
        if not name then
            row:Hide()
        else
            row.name = name
            row.text:SetText(name)

            local isActive = (name == active)
            local isPicked = (name == pick)

            -- Selected rows are bright, the rest are not. Being *in use* is a
            -- separate thing and gets its own marker, because the two are
            -- deliberately not the same: the buttons act on the selection.
            row.text:SetTextColor(unpack((isActive or isPicked)
                and FP.colors.textOn or FP.colors.textOff))
            row.mark:SetText(isActive and ">" or "")
            row.tag:SetText(isActive and L["in use"] or "")
            row.selection:SetShown(isPicked)
            row.edge:SetShown(isPicked)
            row:Show()
        end
    end

    -- Spelled out rather than left to be inferred from a highlight. Which
    -- profile a button is about to act on is the one thing on this page that
    -- must never be a guess -- one of those buttons deletes.
    if target then
        target:SetText(L["The buttons below act on: |cffffffff%s|r"]:format(tostring(pick)))
    end

    -- More profiles than rows. Say so rather than quietly leaving some out --
    -- they would still be switchable from the command line and invisible here.
    if #names > MAX_ROWS then
        local last = rows[MAX_ROWS]
        last.name = nil
        last.text:SetText(L["... and %d more, see /fplus profile"]:format(
            #names - MAX_ROWS + 1))
        last.text:SetTextColor(0.6, 0.6, 0.65)
        last.mark:SetText("")
        last.tag:SetText("")
        last.selection:Hide()
    end
end

--- One row of the list. The caller anchors it: rows follow the wrapped text
--- above them, which reflows when the text size changes.
local function CreateRow(parent, width)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(width, ROW_H)

    -- Bright enough to see at a glance. The old 8% white was invisible on a
    -- dark scheme, which made selecting a row look like it had done nothing --
    -- and led to profiles being switched to just to export them.
    local selection = FP:Texture(row, "BACKGROUND", { 1, 1, 1, 0.16 })
    selection:SetAllPoints()
    selection:Hide()
    row.selection = selection

    -- And a bar down the left, so it reads as selected even at a glance and
    -- even on a scheme where the fill is subtle.
    local edge = FP:Texture(row, "ARTWORK", FP.colors.on, 3, ROW_H)
    edge:SetPoint("TOPLEFT")
    edge:SetPoint("BOTTOMLEFT")
    edge:SetWidth(3)
    edge:Hide()
    row.edge = edge

    local hl = FP:Texture(row, "HIGHLIGHT", FP.colors.hover)
    hl:SetAllPoints()

    row.mark = FP:FontString(row, "OVERLAY", "button")
    row.mark:SetPoint("LEFT", 3, 0)
    row.mark:SetTextColor(unpack(FP.colors.on))

    row.text = FP:FontString(row, "OVERLAY", "body")
    row.text:SetPoint("LEFT", 16, 0)

    row.tag = FP:FontString(row, "OVERLAY", "faint")
    row.tag:SetPoint("RIGHT", -4, 0)
    -- A long profile name stops short of the tag rather than running under it.
    FP:FitLabel(row.text, row, row.tag)

    row:SetScript("OnClick", function(self)
        if not self.name then return end
        selected = self.name
        -- Selecting is not using. Switching is the Use button, deliberately,
        -- so that a stray click on the list cannot restart every module. The
        -- row and the line above the buttons both show what was picked, so
        -- there is nothing left for the note to add.
        Say("")
        Rebuild()
    end)

    row:Hide()
    return row
end

-- ---------------------------------------------------------------------------
-- The page
-- ---------------------------------------------------------------------------

FP:RegisterTab({
    name  = N["Profiles"],
    order = 80,
    -- Arranges the addon itself and changes nothing in the game, so its tab
    -- has no switch.
    internal = true,

    -- The blurb wraps, so the page's height stops being true the moment the
    -- text size moves. Everything below it is anchored to what is above rather
    -- than placed at a worked-out offset, for the same reason.
    automeasure = true,

    Build = function(_, content)
        local pad   = FP.PANEL_PAD
        local width = content:GetWidth() - 2 * pad

        local heading = FP:SectionHeading(content, L["Profiles"])
        heading:SetPoint("TOPLEFT", pad, 0)
        heading:SetPoint("TOPRIGHT", -pad, 0)

        -- No explanatory paragraph. The page shows the profiles, the active
        -- one is marked, and the rows say what they do: a paragraph saying so
        -- again is the kind of text people stop reading and then have to
        -- scroll past for ever.

        -- The list. A hidden row still has a position, so the chain holds even
        -- when there are fewer profiles than rows.
        rows = {}
        local previous, gap = heading, -4
        for index = 1, MAX_ROWS do
            local row = CreateRow(content, width)
            row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, gap)
            rows[index] = row
            previous, gap = row, 0
        end

        target = FP:FontString(content, "OVERLAY", "faint")
        target:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -8)
        target:SetPoint("RIGHT", content, "RIGHT", -pad, 0)
        target:SetJustifyH("LEFT")

        -- Buttons that act on the selected row.
        local use = FP:CreateButton(content, L["Use"], 84, function()
            local name = Selected()
            local ok, why = FP:SetProfile(name)
            Say(ok and L["Now using %s."]:format(name) or why, not ok)
            Rebuild()
        end)
        Fit(use, 84)
        use:SetPoint("TOPLEFT", target, "BOTTOMLEFT", 0, -6)

        local reset = Confirming(
            FP:CreateButton(content, L["Reset"], 84), L["Reset"], L["Sure?"],
            function()
                local name = Selected()
                local ok, why = FP:ResetProfile(name)
                Say(ok and L["%s is back to its defaults."]:format(name) or why, not ok, true)
                Rebuild()
            end)
        Fit(reset, 84, L["Sure?"])
        reset:SetPoint("LEFT", use, "RIGHT", 6, 0)

        local remove = Confirming(
            FP:CreateButton(content, L["Delete"], 84), L["Delete"], L["Sure?"],
            function()
                local name = Selected()
                local ok, why = FP:DeleteProfile(name)
                if ok then selected = nil end
                Say(ok and L["%s deleted."]:format(name) or why, not ok, true)
                Rebuild()
            end)
        Fit(remove, 84, L["Sure?"])
        remove:SetPoint("LEFT", reset, "RIGHT", 6, 0)

        -- The name field, and the three things that need one.
        nameBox = FP:CreateInput(content, nil, {
            width = width,
            placeholder = L["Name for a new or renamed profile"],
            Get = function() return "" end,
            Set = function() end,
        })
        nameBox:SetPoint("TOPLEFT", use, "BOTTOMLEFT", 0, -12)
        nameBox:SetPoint("RIGHT", content, "RIGHT", -pad, 0)

        local function TypedName()
            return nameBox.editBox:GetText() or ""
        end

        local function Clear()
            nameBox.editBox:SetText("")
            nameBox.editBox:ClearFocus()
        end

        local new = FP:CreateButton(content, L["New"], 84, function()
            local name, why = FP:CreateProfile(TypedName())
            Say(name and L["Created %s."]:format(name) or why, not name)
            if name then selected = name; Clear() end
            Rebuild()
        end)
        Fit(new, 84)
        new:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -6)

        local copy = FP:CreateButton(content, L["Copy"], 84, function()
            local from = Selected()
            local name, why = FP:CreateProfile(TypedName(), from)
            Say(name and L["%s copied from %s."]:format(name, from) or why, not name, true)
            if name then selected = name; Clear() end
            Rebuild()
        end)
        Fit(copy, 84)
        copy:SetPoint("LEFT", new, "RIGHT", 6, 0)

        local rename = FP:CreateButton(content, L["Rename"], 84, function()
            local from = Selected()
            local name, why = FP:RenameProfile(from, TypedName())
            Say(name and L["%s is now %s."]:format(from, name) or why, not name)
            if name then selected = name; Clear() end
            Rebuild()
        end)
        Fit(rename, 84)
        rename:SetPoint("LEFT", copy, "RIGHT", 6, 0)

        -- Moving a profile between characters, or out of the game entirely.
        local export = FP:CreateButton(content, L["Export"], 130, function()
            local name = Selected()
            local text, why = FP:ExportProfile(name)
            if not text then return Say(why, true) end
            FP:TextWindow(L["Export profile"],
                L["%s, %d characters"]:format(name, #text), text)
            -- Nothing said here. The window is in front of you and carries the
            -- count in its own heading; a line repeating that is noise -- and a
            -- line *asserting* that a window exists is how an invisible one
            -- went unnoticed for a week.
            Say("")
        end)
        Fit(export, 130)
        export:SetPoint("TOPLEFT", new, "BOTTOMLEFT", 0, -12)

        local import = FP:CreateButton(content, L["Import"], 130, function()
            FP:TextWindow(L["Import profile"],
                L["Paste a string, then press Import"], "",
                function(text)
                    local name, skipped, total = FP:ImportProfile(text)
                    if not name then
                        -- On failure the second return is the reason, not a list.
                        return Say(L["Import failed: %s"]:format(tostring(skipped)), true)
                    end
                    if FP.textWindow then FP.textWindow:Hide() end
                    selected = name
                    -- The count comes from the saved table itself. If it says
                    -- two and a reload leaves one, the loss is in the writing
                    -- and not in anything this page did.
                    -- Two whole sentences rather than one with a piece glued
                    -- in, so a language can word each of them its own way.
                    local first = (#skipped > 0)
                        and L["Imported as %s, %d skipped."]:format(name, #skipped)
                        or L["Imported as %s."]:format(name)
                    total = total or 0
                    Say(first .. " " .. FP:Plural(total, N["%d profile now."],
                        N["%d profiles now."]):format(total), false, true)
                    Rebuild()
                end, L["Import"])
        end)
        Fit(import, 130)
        import:SetPoint("LEFT", export, "RIGHT", 6, 0)

        note = FP:FontString(content, "OVERLAY", "faint")
        note:SetPoint("TOPLEFT", export, "BOTTOMLEFT", 0, -10)
        note:SetWidth(width)
        note:SetJustifyH("LEFT")
        note:SetWordWrap(true)
        -- Two lines of room, reserved whether or not anything is being said,
        -- so that saying something does not move the page under the pointer.
        note:SetHeight(28)

        Rebuild()
        -- A starting figure. automeasure works the real one out once the page
        -- is on screen and the blurb has wrapped.
        return 420
    end,

    -- The list goes stale as soon as anything changes it elsewhere -- a slash
    -- command, or another character's profile being renamed.
    Refresh = function()
        Say("")
        Rebuild()
    end,
})
