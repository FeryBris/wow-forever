--[[
    LootWindow.lua - the candidate card

    What a council looks at when an item drops: who wants it, at what rank, whether
    the game even lets them use it, and what the officers already decided.

    The payload carries item IDs only, so everything shown here about the item itself
    comes from GetItemInfo. That call returns nil for anything not in the local cache,
    which is the normal state on a fresh login - the client has to ask the server
    first. So the window renders immediately with what it has and fills in the rest on
    GET_ITEM_INFO_RECEIVED, rather than showing a blank row and looking broken.
]]

local Raidify = _G.Raidify

-- See LootPage.lua: no global GetItemInfo on Forever, identical tuple from C_Item.
-- GetItemQualityColor moved with it and returns the same four values.
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
local GetItemQualityColor = (C_Item and C_Item.GetItemQualityColor) or _G.GetItemQualityColor

-- LootCore.lua sets this after the core/API handshake succeeds. If it did not, the
-- boundary already explained why to the player and this file must add nothing —
-- returning here leaves core untouched rather than defining half a feature against
-- a core it cannot use.
if not Raidify or not Raidify.Loot then return end
local C = Raidify.Components

local WINDOW_WIDTH = 420
local ROW_HEIGHT = 34

--[[
    How many rows are on screen at once - NOT how many candidates there are.

    This used to be a hard cut: build twelve rows, `break`, and never mention the rest.
    On a contested 40 man drop that discarded most of the raid, and the card sorts present
    listers first, so the names that fell off the bottom were the raiders with no wishlist -
    exactly the people the "unranked, not excluded" rule exists to protect.

    An officer cannot award a name the tool refuses to draw. Free rolls, "everyone who can
    use it rolls", a rank 1 who logged off - all of them need the whole list, and none of
    them can be assumed away. So every candidate gets a row and the card scrolls, which
    keeps the window the same size it has always been.
]]
local VISIBLE_ROWS = 12

--[[
    Tier colours mirror how an officer reads urgency, not item quality.

    Two problems fixed here. BiS was {1.0, 0.82, 0.0} - byte-identical to the stock Blizzard heading
    gold, so whenever the custom fonts fell back, the top-priority DATA on a
    row and the CHROME of every section heading rendered as the same pixel value.

    And the bottom three were all the same grey to within a rounding error: Pass measured
    3.20:1 against this card, under AA, and Minor against Offspec was indistinguishable. They
    are separated by lightness now, and each still carries its own word, so the tier never
    depends on telling two greys apart.
]]
local TIER_COLOR = {
    BiS = { 0.98, 0.78, 0.22 },
    Upgrade = { 0.41, 0.80, 0.94 },
    Minor = { 0.72, 0.72, 0.72 },
    Offspec = { 0.60, 0.63, 0.64 },
    Pass = { 0.50, 0.50, 0.50 },
}

local STANDING_RULE_TEXT = {
    AlwaysBank = "Guild bank",
    AlwaysDisenchant = "Disenchant",
    HardReserve = "Hard reserved",
    ClassRestricted = "Class restricted",
}

--[[
    Readable class name for a payload class token ("WARLOCK" -> "Warlock").

    NOT Raidify.ClassNames: that table is keyed by NUMERIC class id, while everything on this
    card carries the token string - which is why ClassColor works and a ClassNames lookup
    silently returned nil and rendered an empty column. A missing key in Lua is not an error,
    so the class text simply was not there and nothing said so.

    LOCALIZED_CLASS_NAMES_MALE is Blizzard's own token-keyed table, so this is correct in
    every locale for free. The manual title-case is only for a client that somehow lacks it.
]]
local function ClassDisplayName(token)
    if not token then return "" end
    local localised = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token]
    if localised then return localised end
    return token:sub(1, 1):upper() .. token:sub(2):lower()
end

--[[ Class colour for a payload class token ("WARRIOR"), falling back to white. ]]
local function ClassColor(class)
    if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
        local c = RAID_CLASS_COLORS[class]
        return c.r, c.g, c.b
    end
    return 1, 1, 1
end

function Raidify:CreateLootWindow()
    if self.lootWindow then return self.lootWindow end

    local frame = CreateFrame("Frame", "RaidifyLootWindow", UIParent, "BackdropTemplate")
    frame:SetSize(WINDOW_WIDTH, 200)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    -- The card opens BY ITSELF when a boss dies, so recentring on every reload put it
    -- back over the boss frames no matter where the officer had moved it.
    Raidify:PersistWindowPosition(frame, "lootCard")
    Raidify:RestoreWindowPosition(frame, "lootCard")
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:Hide()

    local surface = Raidify.Theme.surface1 or { 0.06, 0.07, 0.09, 0.97 }
    local border = Raidify.Theme.borderAccent or { 1, 0.85, 0.44, 0.35 }
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(surface[1], surface[2], surface[3], surface[4] or 0.97)
    frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 0.35)

    -- Header: icon + item name + source line
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetSize(32, 32)
    frame.icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -12)
    frame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    frame.itemName = frame:CreateFontString(nil, "OVERLAY", "RaidifyFontTitle")
    frame.itemName:SetPoint("TOPLEFT", frame.icon, "TOPRIGHT", 10, -2)
    frame.itemName:SetPoint("RIGHT", frame, "RIGHT", -34, 0)
    frame.itemName:SetJustifyH("LEFT")
    frame.itemName:SetWordWrap(false)

    frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "RaidifyFontCaption")
    frame.subtitle:SetPoint("TOPLEFT", frame.itemName, "BOTTOMLEFT", 0, -3)
    frame.subtitle:SetJustifyH("LEFT")

    frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    frame.close:SetScript("OnClick", function() frame:Hide() end)

    -- Hovering the icon should show the real tooltip; officers check stats constantly.
    frame.icon:EnableMouse(true)
    frame.icon:SetScript("OnEnter", function(self)
        if not frame.itemId then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(frame.itemId)
        GameTooltip:Show()
    end)
    frame.icon:SetScript("OnLeave", function() GameTooltip:Hide() end)

    --[[
        Rows live in a scrolling viewport rather than on the frame.

        Plain ScrollFrame and a mouse wheel handler, no scrollbar template: this addon loads
        on Classic Era, TBC, Wrath and Cata, and hand-rolling the two lines of scroll maths
        is cheaper than being wrong about which scroll template each of those clients has.
    ]]
    frame.scroll = CreateFrame("ScrollFrame", nil, frame)
    frame.scroll:SetWidth(WINDOW_WIDTH - 24)
    frame.scroll:EnableMouseWheel(true)

    frame.scrollChild = CreateFrame("Frame", nil, frame.scroll)
    frame.scrollChild:SetSize(WINDOW_WIDTH - 24, 1)
    frame.scroll:SetScrollChild(frame.scrollChild)

    frame.scroll:SetScript("OnMouseWheel", function(self, delta)
        local max = self.maxScroll or 0
        if max <= 0 then return end

        local target = self:GetVerticalScroll() - delta * ROW_HEIGHT
        self:SetVerticalScroll(math.max(0, math.min(max, target)))
    end)

    -- Which slice of the list is on screen. A card that silently showed twelve of
    -- twenty-seven was the original bug; a count that does not follow the scroll would be
    -- the same bug with extra steps.
    frame.scrollNote = frame:CreateFontString(nil, "OVERLAY", "RaidifyFontCaption")
    frame.scrollNote:SetPoint("BOTTOMRIGHT", frame.scroll, "TOPRIGHT", -2, 3)
    frame.scrollNote:SetJustifyH("RIGHT")

    frame.scroll:SetScript("OnVerticalScroll", function(self)
        Raidify:UpdateLootScrollNote()
    end)

    --[[
        Award this one as an offspec.

        A checkbox rather than a modifier click. Shift-clicking a name would be fewer
        pixels and the wrong trade: an invisible modifier is exactly how you end up
        recording the wrong thing about a real person, and the state has to be readable
        from across the screen while a raid waits.

        Off for every new item, deliberately. A sticky toggle would quietly mark the next
        six drops offspec, and nothing about the ledger would look wrong until someone
        checked why their standing never moved.
    ]]
    frame.offspec = false
    frame.offspecToggle = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    frame.offspecToggle:SetSize(22, 22)
    frame.offspecToggle:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 4)
    frame.offspecToggle:SetScript("OnClick", function(self)
        frame.offspec = self:GetChecked() and true or false
        Raidify:RefreshLootHint()
    end)
    frame.offspecToggle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Award as offspec")
        GameTooltip:AddLine(
            "Offspec awards do not count against the winner's loot history, so taking one "
                .. "costs them nothing next time they want a mainspec item.",
            1, 1, 1, true)
        GameTooltip:Show()
    end)
    frame.offspecToggle:SetScript("OnLeave", function() GameTooltip:Hide() end)

    --[[
        Escape closes it, like every other window this addon owns.

        MainWindow, the Dashboard, the notes window and the confirm dialog are all in
        UISpecialFrames; this one was not. So the single frame that opens by itself, mid
        raid, at DIALOG strata, was also the only one that ignored the key every WoW player
        presses to make something go away.
    ]]
    _G["RaidifyLootWindow"] = frame
    local registered = false
    for _, name in ipairs(UISpecialFrames) do
        if name == "RaidifyLootWindow" then registered = true break end
    end
    if not registered then tinsert(UISpecialFrames, "RaidifyLootWindow") end

    frame.rows = {}
    self.lootWindow = frame

    -- Item data arrives asynchronously. Without this the first view of an uncached
    -- item shows "item:12345" and never corrects itself.
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    watcher:SetScript("OnEvent", function(_, _, receivedId)
        if frame:IsShown() and frame.itemId and receivedId == frame.itemId then
            Raidify:RefreshLootWindowHeader()
        end
    end)

    return frame
end

--[[ Header only - called again when the item cache catches up. ]]
function Raidify:RefreshLootWindowHeader()
    local frame = self.lootWindow
    if not frame or not frame.itemId then return end

    local name, link, quality, _, _, _, _, _, _, texture = GetItemInfo(frame.itemId)

    -- Kept for the confirm dialogs, which should name the item the way the game does rather
    -- than as a bare id. Nil until the client has the item cached, and every reader guards.
    frame.itemLink = link

    frame.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")

    if name then
        local r, g, b = GetItemQualityColor(quality or 1)
        frame.itemName:SetText(name)
        frame.itemName:SetTextColor(r, g, b)
        frame.resolveDeadline = nil
    elseif frame.resolveGaveUp then
        -- The client has no data for this id and never will - a Wrath item id in a
        -- TBC client, or simply a bad id. "Loading..." forever is a lie; say what is
        -- actually true so nobody waits on it.
        frame.itemName:SetText("Unknown item " .. frame.itemId)
        local bad = Raidify.Theme.error
        frame.itemName:SetTextColor(bad[1], bad[2], bad[3])
    else
        -- Honest placeholder rather than a blank row: the client is still fetching.
        frame.itemName:SetText("Loading item " .. frame.itemId .. "...")
        local dim = Raidify.Theme.textMuted
        frame.itemName:SetTextColor(dim[1], dim[2], dim[3])
    end

    local bits = {}

    --[[
        Lead with whether this card writes.

        First on the line, before the standing rule and the ruleset, because it is the only
        thing on the card that changes what a click MEANS. An officer who opened this to look
        an item up needs to know that before they read a single name.
    ]]
    if frame.isQueued then
        local queued = self.lootSession and #self.lootSession.queue or 0
        table.insert(bits, string.format("|cff72B68Fitem %d of %d|r",
            frame.queuePosition or 1, queued))
    else
        table.insert(bits, Raidify:WarningText("not queued - nothing here will record"))
    end

    local rule = self:GetItemStandingRule(frame.itemId)
    if rule then
        table.insert(bits, "|cffD3A96F" .. (STANDING_RULE_TEXT[rule] or rule) .. "|r")
    end
    if self.lootData and self.lootData.rulesetLabel then
        table.insert(bits, self.lootData.rulesetLabel)
    end
    frame.subtitle:SetText(table.concat(bits, "  |cff535D60|||r  "))
end

--[[
    Show the candidate card for an item.

    Renders whatever is known immediately - a council waiting on a name lookup is a
    council waiting on nothing useful.
]]
function Raidify:ShowLootCandidates(itemId)
    itemId = tonumber(itemId)
    if not itemId then
        self:PrintError("Usage: /rf loot show <itemId>")
        return
    end

    -- No import is not an error. StartLootSession says so explicitly - "sessions still work,
    -- candidates will be limited to who is in the raid" - and then this refused to draw the
    -- card that would have shown them, so the documented standalone path dead-ended one step
    -- in. The card now comes from the raid, which is what that promise meant.
    if not self.lootData then
        self:PrintWarning("No loot data imported - showing the raid. Use /rf import for wishlists and prios.")
    end

    local frame = self:CreateLootWindow()
    frame.itemId = itemId

    --[[
        Is this card ARMED - will clicking a name actually record something?

        The card had exactly one appearance and two completely different meanings. Opened
        from the queue it awards the item it is showing. Opened via `/rf loot show <id>` for
        an item that never dropped - a normal way to answer "who has this on their list?" -
        clicking a name still wrote an award, against a DIFFERENT item, because
        TakeQueuedItem fell back to queue[1]. Same rows, same buttons, nothing on screen
        distinguishing the two.

        One boolean, computed here and stated in the subtitle, is what turns the card from
        "a surface that always writes" into "a surface that says whether it will write".
    ]]
    local session = self.lootSession
    frame.queuePosition = nil
    if session and type(session.queue) == "table" then
        for index, entry in ipairs(session.queue) do
            if entry.itemId == itemId then
                frame.queuePosition = index
                break
            end
        end
    end
    frame.isQueued = frame.queuePosition ~= nil

    -- Asking for it primes the cache, so GET_ITEM_INFO_RECEIVED fires for uncached items.
    if C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemId)
    end

    -- An id the client has no data for never fires GET_ITEM_INFO_RECEIVED, so without
    -- a deadline the header sits on "Loading..." indefinitely. Give the server a fair
    -- window, then say the item is unknown.
    frame.resolveGaveUp = false
    if C_Timer and C_Timer.After then
        C_Timer.After(4, function()
            if frame.itemId == itemId and not GetItemInfo(itemId) then
                frame.resolveGaveUp = true
                Raidify:RefreshLootWindowHeader()
            end
        end)
    end

    self:RefreshLootWindowHeader()

    for _, row in ipairs(frame.rows) do row:Hide() end

    local candidates = self:GetLootCandidates(itemId)

    -- The raid is always in the candidate set now, so this is no longer "which source did
    -- we fall back to" but "did anyone do the homework for this drop". When nobody did,
    -- the note tells the officer that every name below is an unranked judgement call.
    local fromRaid = true
    for _, candidate in ipairs(candidates) do
        if not candidate.fromRaid then fromRaid = false break end
    end

    local total = #candidates
    local shown = math.min(total, VISIBLE_ROWS)

    for index, candidate in ipairs(candidates) do
        local row = frame.rows[index]
        if not row then
            row = CreateFrame("Button", nil, frame.scrollChild)
            row:SetSize(WINDOW_WIDTH - 24, ROW_HEIGHT)

            -- Rows are the award control. A council decides by naming a person, so
            -- clicking the person is the shortest path from decision to record.
            row.highlight = row:CreateTexture(nil, "BACKGROUND")
            row.highlight:SetAllPoints()
            -- Signal, not gold. This sits behind a list of class-coloured names, which
            -- is the one place chrome competing with data costs a real decision.
            local sig = Raidify.Theme.signal
            row.highlight:SetColorTexture(sig[1], sig[2], sig[3], 0.10)
            row.highlight:Hide()
            row:SetScript("OnEnter", function(self) self.highlight:Show() end)
            row:SetScript("OnLeave", function(self) self.highlight:Hide() end)

            row.rank = row:CreateFontString(nil, "OVERLAY", "RaidifyFontCaption")
            row.rank:SetPoint("LEFT", row, "LEFT", 4, 0)
            row.rank:SetWidth(28)
            row.rank:SetJustifyH("RIGHT")

            row.name = row:CreateFontString(nil, "OVERLAY", "RaidifyFontHeading")
            row.name:SetPoint("LEFT", row.rank, "RIGHT", 8, 0)
            row.name:SetJustifyH("LEFT")
            row.name:SetWordWrap(false)

            --[[
                The class, as a word.

                Class colour was the ONLY carrier of class on this card, and it cannot carry
                it. Under deuteranopia Warrior, Hunter and Druid collapse into one yellow and
                Warlock and Shaman into one blue - three of the most common classes in a
                40-man, on the one screen where a misread awards the wrong person an item
                that cannot be taken back. Death Knight measures 2.61:1 and Shaman 3.16:1
                against this card; neither reaches AA on ANY background, so no amount of
                tuning rescues them and the colour has to be supplemented instead.

                Uncoloured on purpose: zero chroma cannot collide with the class colour
                beside it, and it costs nothing from the identity budget. The Roster page
                already renders exactly this column - this applies an existing decision to
                the screen that needed it most.

                It also fills the ~250px of dead gutter that sat between the name and the
                right-aligned detail column.
            ]]
            row.class = row:CreateFontString(nil, "OVERLAY", "RaidifyFontCaption")
            row.class:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
            row.class:SetJustifyH("LEFT")
            row.class:SetWordWrap(false)

            row.tier = row:CreateFontString(nil, "OVERLAY", "RaidifyFontLabel")
            row.tier:SetPoint("RIGHT", row, "RIGHT", -6, 6)
            row.tier:SetJustifyH("RIGHT")

            row.detail = row:CreateFontString(nil, "OVERLAY", "RaidifyFontCaption")
            row.detail:SetPoint("RIGHT", row, "RIGHT", -6, -8)
            row.detail:SetJustifyH("RIGHT")

            frame.rows[index] = row
        end

        --[[
            Clicking a name awards it - except when the row says Offspec.

            The word "Offspec" appears twice on this card, forty pixels apart, meaning
            opposite things: on a row it means THIS RAIDER listed the item as an offspec
            want; on the toggle it means RECORD MY AWARD as offspec. AwardCurrentItemTo reads
            only the toggle and never the candidate's tier, and the toggle resets for every
            new card - so clicking a candidate whose row plainly said Offspec recorded a
            mainspec win, which is exactly the mistake the offspec flag exists to prevent.

            First click on such a row arms the toggle instead of committing. The second
            commits. That is one extra click on the rows where getting it wrong costs a
            raider their standing, and no change at all everywhere else.
        ]]
        row:SetScript("OnClick", function()
            if candidate.tier == "Offspec" and not frame.offspec then
                frame.offspec = true
                frame.offspecToggle:SetChecked(true)
                Raidify:RefreshLootHint()
                Raidify:Print(string.format(
                    "%s wants that for their offspec - set to award as offspec. Click again to confirm.",
                    candidate.char.name))
                return
            end
            Raidify:AwardCurrentItemTo(candidate)
        end)

        row:SetPoint("TOPLEFT", frame.scrollChild, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
        row:Show()

        -- An officer prio is an explicit decision, so it outranks a wishlist position
        -- in the display exactly as it does in the sort.
        if candidate.prio then
            row.rank:SetText("|cffEAB444P" .. candidate.prio .. "|r")
        elseif candidate.rank then
            row.rank:SetText(tostring(candidate.rank))
        else
            row.rank:SetText("-")
        end

        local r, g, b = ClassColor(candidate.char.class)
        row.name:SetText(candidate.char.name)
        row.name:SetTextColor(r, g, b)

        --[[
            Guest, beside the class rather than in the detail line below it.

            The detail line carries situational facts - cannot use, not in raid, won two
            tonight - all of which change between one boss and the next. Being a guest does
            not; it is who this person is for the whole night, and it belongs with the other
            identity on the row. It also has to survive a fast read: an officer scanning a
            sorted card needs to know the top name is a stranger BEFORE they weigh the rank
            beside it, not after they have read to the end of the row.
        ]]
        local classText = ClassDisplayName(candidate.char.class)
        if candidate.char.isPug then
            classText = classText .. "  |cffD3A96FGuest|r"
        end
        row.class:SetText(classText)

        if candidate.tier then
            local color = TIER_COLOR[candidate.tier] or { 0.8, 0.8, 0.8 }
            row.tier:SetText(candidate.tier)
            row.tier:SetTextColor(color[1], color[2], color[3])
        else
            row.tier:SetText("")
        end

        -- Ineligible candidates stay visible but are marked. Hiding them makes the
        -- council wonder whether someone was skipped by accident.
        local detail = {}
        if not candidate.eligible then
            table.insert(detail, "|cffBE706Ecannot use|r")
        end
        -- Same reasoning as "cannot use": the name stays clickable because awarding to
        -- someone who just disconnected is a real thing councils do, but it has to be a
        -- decision rather than a misread of a sorted list.
        if candidate.present == false then
            table.insert(detail, "|cffD3A96Fnot in raid|r")
        end
        -- Tonight's tally, ahead of the longer-run numbers because it is the one an
        -- officer is about to be argued with about. Only drawn when it is not zero: a
        -- column of "won 0" on forty rows is noise that makes the two rows that matter
        -- harder to find.
        if (candidate.wonTonight or 0) > 0 then
            table.insert(detail, string.format("|cffD3A96Fwon %d tonight|r", candidate.wonTonight))
        end
        if (candidate.wonOffspecTonight or 0) > 0 then
            -- Kept separate and muted. An offspec award costs the winner nothing by
            -- design, so it must not read as though it counts against them here.
            table.insert(detail, string.format("|cff7F888B+%d offspec|r", candidate.wonOffspecTonight))
        end

        -- Withheld when the officer has said they are being watched. Everything else on
        -- the row stays: the decision is still visible, the ranking of people is not.
        if candidate.vars and not Raidify.Loot:GetSetting("hideStandingOnCard") then
            if candidate.vars.att then table.insert(detail, candidate.vars.att .. "% att") end
            if candidate.vars.dsl then table.insert(detail, candidate.vars.dsl .. "d since loot") end
        end
        row.detail:SetText(table.concat(detail, "  "))
    end

    if shown > 0 and fromRaid then
        if not frame.sourceNote then
            frame.sourceNote = frame:CreateFontString(nil, "OVERLAY", "RaidifyFontCaption")
            frame.sourceNote:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -50)
        end
        frame.sourceNote:SetText("|cffD3A96FNobody wishlisted this|r - showing the raid")
        frame.sourceNote:Show()
    elseif frame.sourceNote then
        frame.sourceNote:Hide()
    end

    if shown == 0 then
        if not frame.emptyText then
            frame.emptyText = frame:CreateFontString(nil, "OVERLAY", "RaidifyFontCaption")
            frame.emptyText:SetPoint("TOP", frame, "TOP", 0, -70)
        end
        local why
        if not self.lootData then
            why = "Nothing imported and nobody here can use this."
        elseif self.lootData.hasLootData then
            why = "Nobody has this on a wishlist."
        else
            why = "This guild has no loot suite, so no wishlist data was sent."
        end
        frame.emptyText:SetText(why)
        frame.emptyText:Show()
    elseif frame.emptyText then
        frame.emptyText:Hide()
    end

    if not frame.hint then
        frame.hint = frame:CreateFontString(nil, "OVERLAY", "RaidifyFontCaption")
        frame.hint:SetPoint("LEFT", frame.offspecToggle, "RIGHT", 2, 0)
    end

    -- Every new card starts mainspec. See the toggle's own note for why this is not sticky.
    frame.offspec = false
    frame.offspecToggle:SetChecked(false)
    frame.offspecToggle:SetShown(total > 0)
    self:RefreshLootHint()
    self:UpdateLootDispositionButtons(frame)

    -- Hide the rows left over from a longer previous card, or they scroll into view
    -- as ghosts of the last item's candidates.
    for index = total + 1, #frame.rows do
        frame.rows[index]:Hide()
    end

    local rowTop = fromRaid and 72 or 58
    frame.scroll:ClearAllPoints()
    frame.scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -rowTop)
    frame.scroll:SetHeight(math.max(shown, 1) * ROW_HEIGHT)
    frame.scrollChild:SetHeight(math.max(total, 1) * ROW_HEIGHT)

    -- Reset before measuring: a card left scrolled to the bottom of a 27 name list opens
    -- the next item mid-list, and the officer sees rank 14 at the top of a fresh drop.
    frame.scroll:SetVerticalScroll(0)
    frame.scroll.maxScroll = math.max(0, (total - VISIBLE_ROWS) * ROW_HEIGHT)
    frame.scroll.total = total
    self:UpdateLootScrollNote()

    -- 36, not 22: the disposition buttons sit 6..26 up from the bottom edge, so a 22px
    -- gutter left the last candidate row's clickable rect 4px underneath them - aim at
    -- the bottom name under pressure and you hit Disenchant.
    frame:SetHeight(rowTop + math.max(shown, 1) * ROW_HEIGHT + 36)
    frame:Show()
end


--[[
    "13-24 of 27", or nothing when everyone already fits.

    Worth saying out loud on every card that scrolls: the officer needs to know both that
    there are more names and roughly where they are, and a bare "scroll for more" answers
    only the first of those.
]]
--[[
    The line next to the offspec box.

    It is the only thing on screen that says what the next click will record, so when the
    toggle is on it stops being a hint and starts being a warning.
]]
function Raidify:RefreshLootHint()
    local frame = self.lootWindow
    if not frame or not frame.hint then return end

    if not frame.offspecToggle:IsShown() then
        frame.hint:SetText("")
    elseif frame.offspec then
        frame.hint:SetText("|cffD3A96FAwarding as OFFSPEC|r")
    else
        -- "Award as offspec", not "Offspec". The bare word is also the tier shown on
        -- candidate rows a few pixels away, where it means the opposite thing - that the
        -- RAIDER wants it for their offspec, not that the officer is recording one.
        frame.hint:SetText("Award as offspec")
    end
end


function Raidify:UpdateLootScrollNote()
    local frame = self.lootWindow
    if not frame or not frame.scrollNote then return end

    local total = frame.scroll.total or 0
    if total <= VISIBLE_ROWS then
        frame.scrollNote:SetText("")
        return
    end

    local first = math.floor(frame.scroll:GetVerticalScroll() / ROW_HEIGHT + 0.5) + 1
    local last = math.min(total, first + VISIBLE_ROWS - 1)

    frame.scrollNote:SetText(string.format(
        "|cffD3A96F%d–%d of %d|r — scroll for the rest",
        first, last, total))
end


--[[
    Bank / Disenchant / Free roll.

    Plenty of drops never go to a person, and a card that only offers names cannot
    record those - the officer would either skip the item (losing the record) or award
    it to someone who did not get it (corrupting the record). Both are worse than a
    button.

    Rebuilt against the current standing rule each time: an item marked AlwaysBank
    should lead with Bank rather than make the officer find it.
]]
function Raidify:UpdateLootDispositionButtons(frame)
    frame.dispositions = frame.dispositions or {}

    local options = {
        { key = "Bank", label = "Bank" },
        { key = "Disenchant", label = "Disenchant" },
        { key = "FreeRoll", label = "Free roll" },
    }

    local rule = frame.itemId and self:GetItemStandingRule(frame.itemId)
    local highlight = (rule == "AlwaysBank" and "Bank")
        or (rule == "AlwaysDisenchant" and "Disenchant")
        or nil

    for index, option in ipairs(options) do
        local button = frame.dispositions[index]
        if not button then
            button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
            --[[
                Skinned like the rest of the addon.

                These were the only widgets in either addon that never went through
                StyleNativeButton*, so they rendered as Blizzard red stone with gold Friz
                Quadrata text - three saturated red plates inside a flat teal-bordered UI,
                and the loudest thing on the highest-stakes screen in the product.

                Red on all three also said the wrong thing. Red reads as destructive, so
                "Bank" - which PRESERVES the item - carried the same alarm as "Disenchant",
                which destroys it. Neutral by default; Disenchant is marked separately below.

                84 wide, not 76: "Disenchant" was running edge to edge over the bevel while
                its two neighbours had slack.
            ]]
            button:SetSize(84, 20)
            Raidify:StyleNativeButtonSecondary(button)
            frame.dispositions[index] = button
        end

        button:SetText(option.label)
        button:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8 - (index - 1) * 88, 6)

        if option.key == "Disenchant" then
            -- The only irreversible one on the card. Marked, and it asks first: every other
            -- disposition can be corrected on the website, and this one cannot be corrected
            -- anywhere because the item no longer exists.
            Raidify:StyleNativeButtonDanger(button)
            button:SetScript("OnClick", function()
                local link = frame.itemLink or (frame.itemId and ("item " .. frame.itemId)) or "this item"
                Raidify:ShowConfirmDialog({
                    title = "Disenchant?",
                    message = string.format(
                        "%s will be recorded as disenchanted.\n\nNothing else on this card "
                            .. "destroys an item - the others can be corrected later.", link),
                    confirmText = "Disenchant",
                    cancelText = "Cancel",
                    dangerous = true,
                    onConfirm = function() Raidify:DisposeCurrentItem(option.key) end,
                })
            end)
        else
            Raidify:StyleNativeButtonSecondary(button)
            button:SetScript("OnClick", function()
                Raidify:DisposeCurrentItem(option.key)
            end)
        end

        -- The guild already decided this one; make that the obvious click. Both branches
        -- set the font object: setting it only on the highlight branch left the previous
        -- card's larger font stuck on that button for the rest of the session.
        if highlight == option.key then
            button:SetNormalFontObject("RaidifyFontLabel")
            button:SetText("|cffEAB444" .. option.label .. "|r")
        else
            button:SetNormalFontObject("RaidifyFontBodySmall")
        end

        button:Show()
    end
end

--[[
    Show the card, or put the next queued item on screen.

    The last branch used to print "use /rf loot show <itemId>", which answered a question
    nobody had: an officer clicking this has a queue and wants to work it, not to go and
    look up an id. Advancing the queue is what the click means in every case where there is
    a queue, so it does that instead, and the message is now only for the genuinely empty
    case.

    Reopening the last card still wins over advancing. Closing a card by accident mid
    decision is the common mistake this button exists for, and skipping to the next item
    would quietly abandon the one being discussed.
]]
function Raidify:ToggleLootWindow()
    if self.lootWindow and self.lootWindow:IsShown() then
        self.lootWindow:Hide()
        return
    end

    if self.lootWindow and self.lootWindow.itemId then
        self.lootWindow:Show()
        return
    end

    local session = self.lootSession
    if session and type(session.queue) == "table" and #session.queue > 0 then
        self:ShowNextLootItem()
        return
    end

    self:Print("Nothing waiting. Items appear here as they drop, once a session is running.")
end
