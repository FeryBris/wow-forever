--[[
    LootPage.lua - the Loot tab in the main window.

    WHAT THIS IS FOR, AND WHAT IT IS NOT.

    Three reviewers looked at this feature and split hard on whether a page should exist at
    all. The raid leader called it "a 23:15 feature wearing a 19:20 costume" - he will not
    open a window between trash pulls to read a queue count, and he is right that he
    shouldn't have to. The loot master wanted it badly, for the opposite and equally valid
    reason: a strip on a floating panel can tell him a number, and when a raider whispers
    him at 1am, "3 queued, 7 awarded" proves nothing while a list with names against items
    proves something.

    So this page is deliberately NOT the in-raid surface. That is the candidate card, which
    opens by itself, and the Dashboard strip, which is already on screen. This is the place
    you come to at the end of the night, or the next day, to see what happened and send it.

    It is also the only loot surface a guild sees before they have ever used loot - the
    Dashboard strip and the reminder are both gated on evidence of use, and this is not,
    because someone who deliberately installed the loot addon needs somewhere to find out
    how to start. Behind a click, so it costs a guild that never opens it nothing.
]]

local Raidify = _G.Raidify

-- Item lookups moved to C_Item on modern clients, and World of Warcraft: Forever — which
-- runs the retail API over Classic content — has no global GetItemInfo at all. Same shape
-- LootTrade.lua already uses for C_Container. The C_Item tuple is identical to the old
-- global's, verified against a live Forever client, so nothing below this line changes.
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo

-- Same boundary as every other file here: if core rejected us, add nothing.
if not Raidify or not Raidify.Loot then return end
local C = Raidify.Components
local T = Raidify.Theme
local S = Raidify.Spacing

local PAGE_KEY = "loot"

--[[
    One left edge for text, one for checkboxes.

    The stack chains off the element above it, which is the anchoring idiom that actually
    works here. A frame cannot take its vertical position from a sibling and its horizontal
    from the container at the same time - that is two points constraining the same edges, and
    anchoring to the page's LEFT also pins the vertical CENTRE, which collapsed the entire
    control stack into a single overlapping pile in the middle of the card.

    So the fix is not to stop chaining. It is to make the nudges consistent: every checkbox
    steps 4px left of the hint above it, every hint steps 4px back right. The drift that
    started this came from one of those being -8 instead of -4 - a typo, not a design.

    Checkboxes sit further left because UICheckButtonTemplate's art carries its own padding,
    so the DRAWN box lines up with the text column even though the frame does not.
]]
local CHECK_DX = -4
local TEXT_DX = 4

--[[
    Display text for a disposition.

    The stored value is the enum key the button carries - "FreeRoll" - and it was being
    rendered raw in three places: the chat confirmation, the "Given out tonight" list, and
    the export payload that reaches the website. So the officer clicked a button reading
    "Free roll" and every record of it afterwards said "FreeRoll".
]]
local DISPOSITION_TEXT = {
    Bank = "Bank",
    Disenchant = "Disenchant",
    FreeRoll = "Free roll",
}

Raidify.Loot.DispositionText = DISPOSITION_TEXT

--[[
    Elapsed time, in the unit a person would actually say out loud.

    "1h 20m" rather than 4800 seconds or 80 minutes. Nobody reading this page is doing
    arithmetic with it; they want to know roughly how long the night has been running.
]]
local function Elapsed(startedAt)
    if not startedAt then return "" end
    local seconds = time() - startedAt
    if seconds < 60 then return "just started" end

    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    if hours > 0 then return string.format("%dh %dm", hours, minutes) end
    return string.format("%dm", minutes)
end

--[[
    The whole phrase, so the caller does not have to guess at grammar.

    The status line used to prepend "running for " to whatever Elapsed returned, which reads
    correctly for "20m" and produces "running for just started" under a minute. The
    under-a-minute case is a complete phrase, not a duration, so the sentence has to be built
    where that is known.
]]
local function ElapsedPhrase(startedAt)
    local elapsed = Elapsed(startedAt)
    if elapsed == "" then return "" end
    if elapsed == "just started" then return elapsed end
    return "running for " .. elapsed
end

--[[ Item link if the client has it cached, the id if not. Never a blank row. ]]
local function ItemLabel(entry)
    if entry.link then return entry.link end

    -- GetItemInfo's SECOND return is the link, and it was being thrown away on this line -
    -- so the queue (which stores a link at drop time) rendered quality-coloured brackets
    -- while the owed and awarded lists, built from the same items, rendered plain white
    -- text. Same item, same screen, two different treatments.
    local name, link = GetItemInfo(entry.itemId)
    if link then return link end
    if name then return name end

    -- Uncached. Asking is what makes it resolve; without this the row stayed a bare number
    -- for the rest of the session no matter how many times the page redrew, because
    -- GetItemInfo never populates a cache nobody requested. The page refreshes on a timer
    -- while it is open, so the name appears on its own once the server answers.
    if C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(entry.itemId)
    end
    return "item " .. tostring(entry.itemId)
end

local function CreateLootPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    local padding = S.lg

    -- ── header ───────────────────────────────────────────────────────────────
    local title = page:CreateFontString(nil, "OVERLAY", "RaidifyFontTitle")
    title:SetPoint("TOPLEFT", page, "TOPLEFT", padding, -padding)
    title:SetText("Loot")

    local statusText = page:CreateFontString(nil, "OVERLAY", "RaidifyFontBody")
    statusText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -S.sm)
    statusText:SetPoint("RIGHT", page, "RIGHT", -padding, 0)
    statusText:SetJustifyH("LEFT")

    -- ── the two controls that belong here ────────────────────────────────────
    --
    -- Start and Stop only. No "start force": that command exists to override the
    -- raid-authority check AND the guard that stops a new session burying an unexported
    -- one, and typing the word `force` is a deliberate act that a button would erase. A
    -- circuit breaker should not be a light switch.
    local sessionBtn = C:CreateNativeButton(page, "Start tracking loot", Raidify.ButtonTier.PRIMARY, {
        width = 150,
    })
    sessionBtn:SetPoint("TOPLEFT", statusText, "BOTTOMLEFT", 0, -S.md)

    --[[
        The export, and it is deliberately unavailable until tracking has stopped.

        Exporting mid-session is not merely premature, it writes something wrong: the
        payload stamps `endedAt` as the moment the string is generated, so a half-finished
        night arrives at the website looking complete, and `exportedAt` flips the Dashboard
        to "sent" while more awards are still landing.

        The button is therefore the safe path and refuses while a session is running. The
        command stays unrestricted — an officer who genuinely wants a mid-raid safety copy
        can still run /rf loot export, exactly as `start force` keeps its escape hatch
        behind something you have to type on purpose.
    ]]
    local sendBtn = C:CreateNativeButton(page, "Export String", Raidify.ButtonTier.SECONDARY, {
        width = 130,
    })
    sendBtn:SetPoint("LEFT", sessionBtn, "RIGHT", S.sm, 0)

    -- Says why it is unavailable, rather than leaving a greyed-out button to be guessed at.
    local sendHint = page:CreateFontString(nil, "OVERLAY", "RaidifyFontCaption")
    sendHint:SetPoint("TOPLEFT", sessionBtn, "BOTTOMLEFT", 0, -S.xs)
    sendHint:SetPoint("RIGHT", page, "RIGHT", -padding, 0)
    sendHint:SetJustifyH("LEFT")

    --[[
        Auto-trade toggle.

        Here rather than on the candidate card, deliberately. The card is a decision
        surface that opens mid-fight and has to stay fast to read; a settings control sat
        among the candidate rows is one misclick from being flipped by someone reaching for
        a name. This page is where the session is managed, so this is where its behaviour
        is configured.

        Stored in the loot addon's own saved variables, so it survives a reload and follows
        the officer rather than the raid.
    ]]
    local autoTrade = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    autoTrade:SetSize(22, 22)
    autoTrade:SetPoint("TOPLEFT", sendHint, "BOTTOMLEFT", CHECK_DX, -S.sm)

    local autoTradeLabel = page:CreateFontString(nil, "OVERLAY", "RaidifyFontBodySmall")
    autoTradeLabel:SetPoint("LEFT", autoTrade, "RIGHT", 2, 0)
    autoTradeLabel:SetText("Put awarded items into the trade window automatically")

    local autoTradeHint = page:CreateFontString(nil, "OVERLAY", "RaidifyFontCaption")
    autoTradeHint:SetPoint("TOPLEFT", autoTrade, "BOTTOMLEFT", TEXT_DX, -2)
    autoTradeHint:SetPoint("RIGHT", page, "RIGHT", -padding, 0)
    autoTradeHint:SetJustifyH("LEFT")
    --[[
        Says what the setting does and what the other state costs. Nothing about the
        feature's age.

        This used to read "Off by default while this is new", which tells an officer the
        thing they are about to rely on is not finished - and it is the wrong frame anyway:
        the reason to leave it off is that it moves real property, not that it was written
        recently. A hint that apologises for the product teaches the reader to distrust it.
    ]]
    autoTradeHint:SetText(Raidify:MutedText(
        "Opening a trade with someone who is owed loot puts those items straight into the "
            .. "window. You still press Accept - the addon cannot. With this off, Raidify "
            .. "still tells you who is owed what whenever a trade opens."))

    autoTrade:SetScript("OnClick", function(self)
        Raidify.Loot:SetSetting("autoFillTrades", self:GetChecked() and true or false)
    end)

    --[[
        Screenshare guard. Sits next to the trade toggle because both are answers to
        "what should this addon do without being asked".
    ]]
    local hideStanding = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    hideStanding:SetSize(22, 22)
    hideStanding:SetPoint("TOPLEFT", autoTradeHint, "BOTTOMLEFT", CHECK_DX, -S.sm)

    local hideStandingLabel = page:CreateFontString(nil, "OVERLAY", "RaidifyFontBodySmall")
    hideStandingLabel:SetPoint("LEFT", hideStanding, "RIGHT", 2, 0)
    -- Named for the moment it is needed. "Hide attendance and loot history" is a
    -- description of the mechanism, and an officer only goes looking for it after they
    -- have already shown the raid's standing to the raid. "Streamer mode" is a phrase
    -- somebody reaches for BEFORE they start streaming, which is the only time the
    -- setting can still help them.
    hideStandingLabel:SetText("Streamer mode")

    local hideStandingHint = page:CreateFontString(nil, "OVERLAY", "RaidifyFontCaption")
    hideStandingHint:SetPoint("TOPLEFT", hideStanding, "BOTTOMLEFT", TEXT_DX, -2)
    hideStandingHint:SetPoint("RIGHT", page, "RIGHT", -padding, 0)
    hideStandingHint:SetJustifyH("LEFT")
    -- Ticking is the deliberate act now that the numbers show by default, so this says what
    -- ticking it hides and, more importantly, when you would want to.
    hideStandingHint:SetText(Raidify:MutedText(
        "Hides attendance and days-since-last-win on the drop card. Turn this on if you "
            .. "stream or screenshare: those numbers rank the whole raid against each other, "
            .. "and everyone watching can read them. Names, items and your decision still show."))

    hideStanding:SetScript("OnClick", function(self)
        Raidify.Loot:SetSetting("hideStandingOnCard", self:GetChecked() and true or false)
    end)

    --[[
        Announce awards to raid chat.

        The setting has existed since the feature was written, defaults OFF, and had no
        control on any screen - so an officer could award twelve items believing the raid had
        been told, and it never was. A setting nobody can find is not a default, it is a
        secret.
    ]]
    local announce = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    announce:SetSize(22, 22)
    announce:SetPoint("TOPLEFT", hideStandingHint, "BOTTOMLEFT", CHECK_DX, -S.sm)

    local announceLabel = page:CreateFontString(nil, "OVERLAY", "RaidifyFontBodySmall")
    announceLabel:SetPoint("LEFT", announce, "RIGHT", 2, 0)
    announceLabel:SetText("Announce each award in raid chat")

    local announceHint = page:CreateFontString(nil, "OVERLAY", "RaidifyFontCaption")
    announceHint:SetPoint("TOPLEFT", announce, "BOTTOMLEFT", TEXT_DX, -2)
    announceHint:SetPoint("RIGHT", page, "RIGHT", -padding, 0)
    announceHint:SetJustifyH("LEFT")
    announceHint:SetText(Raidify:MutedText(
        "On. Posts one line to raid chat for each award, naming the item and the winner, so "
            .. "the raid sees the decision as it is made. Untick it if your raid chat is busy "
            .. "enough during a pull."))

    announce:SetScript("OnClick", function(self)
        Raidify.Loot:SetSetting("announceLootAwards", self:GetChecked() and true or false)
    end)

    --[[
        Announce the import, and with it that lists are fixed.

        Separate from the award announcer above and defaulted the other way, because it is a
        different kind of message: one line, once, carrying a fact a raider cannot learn any
        other way. Everything else this addon says is aimed at the officer holding it.

        It gets a control anyway. An officer whose guild announces this in Discord already, or
        who pastes a fresh string between every pull, should be able to stop it - a default is
        only defensible when it can be turned off.
    ]]
    local announceImport = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    announceImport:SetSize(22, 22)
    announceImport:SetPoint("TOPLEFT", announceHint, "BOTTOMLEFT", CHECK_DX, -S.sm)

    local announceImportLabel = page:CreateFontString(nil, "OVERLAY", "RaidifyFontBodySmall")
    announceImportLabel:SetPoint("LEFT", announceImport, "RIGHT", 2, 0)
    announceImportLabel:SetText("Announce in raid chat when loot lists are imported")

    local announceImportHint = page:CreateFontString(nil, "OVERLAY", "RaidifyFontCaption")
    announceImportHint:SetPoint("TOPLEFT", announceImport, "BOTTOMLEFT", TEXT_DX, -2)
    announceImportHint:SetPoint("RIGHT", page, "RIGHT", -padding, 0)
    announceImportHint:SetJustifyH("LEFT")
    announceImportHint:SetText(Raidify:MutedText(
        "One line when you paste tonight's string, telling the raid their lists are loaded "
            .. "and locked. It is the only notice a raider gets that editing has stopped "
            .. "counting."))

    announceImport:SetScript("OnClick", function(self)
        Raidify.Loot:SetSetting("announceLootImport", self:GetChecked() and true or false)
    end)

    autoTrade:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText("Automatic trades")
        GameTooltip:AddLine("Turned off, Raidify still tells you who is owed what when a "
            .. "trade opens - it just will not touch the window.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    autoTrade:SetScript("OnLeave", function() GameTooltip:Hide() end)

    --[[
        Recovery, for when the officer running loot has gone and is not coming back.

        Hidden unless a mirror exists, because it is meaningless otherwise and a button
        that does nothing is a button people click to find out.
    ]]
    local adoptBtn = C:CreateNativeButton(page, "Take over session", Raidify.ButtonTier.SECONDARY, {
        width = 150,
        onClick = function()
            Raidify:AdoptLootMirror()
            page.Refresh()
        end,
    })
    -- On the button row, not below sendHint: that anchor already carries the settings
    -- stack, and a second frame hanging off it would sit on top of the first checkbox.
    -- Whose session it is belongs in the status line and the confirmation, not the label.
    --[[
        Work the queue, from the page that lists it.

        The queue was readable here and actionable nowhere. An officer who loots three
        bosses before sitting down to award anything ends up with a dozen queued items, sees
        them listed on this page, and has no control on it that opens one — the only paths
        were `/rf loot next` typed into chat, or the dashboard icon, which reopens the card
        that was last on screen rather than advancing the queue.

        That is precisely the loot-later workflow this addon encourages, so the page that
        represents it should be able to drive it.
    ]]
    local nextBtn = C:CreateNativeButton(page, "Next item", Raidify.ButtonTier.SECONDARY, {
        width = 110,
        onClick = function()
            Raidify:ShowNextLootItem()
        end,
    })
    nextBtn:SetPoint("LEFT", sendBtn, "RIGHT", S.sm, 0)

    -- After nextBtn, so the rare recovery button is the one that moves when it appears
    -- rather than the control an officer uses every night.
    adoptBtn:SetPoint("LEFT", nextBtn, "RIGHT", S.sm, 0)
    adoptBtn:Hide()

    --[[
        The three lists scroll; the controls above them do not.

        They were font strings anchored straight onto the page, chained top to bottom, which
        is fine right up until a real night fills them. A 25-man clearing a raid produces far
        more than fits: the text simply ran off the bottom of the frame with no way to reach
        it, so the awards an officer most wanted to check - the recent ones - were the ones
        they could not see. Nothing indicated anything was missing either, which is the same
        failure the candidate card had and was fixed for.

        Plain ScrollFrame and a hand-rolled wheel handler, matching LootWindow and for the
        same reason: this loads on Classic Era, TBC, Wrath and Cata, and two lines of scroll
        maths beat being wrong about which scroll template each client ships.
    ]]
    local scroll = CreateFrame("ScrollFrame", nil, page)
    -- Anchored below the LAST control on the page, which is now the import announcer. Left
    -- pointing at announceHint, the new checkbox and this frame would occupy the same space.
    scroll:SetPoint("TOPLEFT", announceImportHint, "BOTTOMLEFT", 0, -S.md)
    scroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -padding, padding)
    scroll:EnableMouseWheel(true)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    scroll:SetScript("OnSizeChanged", function(self, width)
        content:SetWidth(width)
    end)

    local SCROLL_STEP = 28

    scroll:SetScript("OnMouseWheel", function(self, delta)
        local max = self.maxScroll or 0
        if max <= 0 then return end
        local target = self:GetVerticalScroll() - delta * SCROLL_STEP
        self:SetVerticalScroll(math.max(0, math.min(max, target)))
    end)

    -- Says there is more, because content running off the bottom with no indication is how
    -- an officer concludes the addon lost something.
    -- Above the viewport, in the gap the scroll frame is already offset by. Inside it would
    -- sit on top of whichever row happened to be at that corner.
    local scrollNote = page:CreateFontString(nil, "OVERLAY", "RaidifyFontCaption")
    scrollNote:SetPoint("BOTTOMRIGHT", scroll, "TOPRIGHT", 0, 2)
    scrollNote:SetJustifyH("RIGHT")
    scrollNote:Hide()

    -- ── the three lists ──────────────────────────────────────────────────────
    local queueHeader = content:CreateFontString(nil, "OVERLAY", "RaidifyFontHeading")
    queueHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)

    local queueBody = content:CreateFontString(nil, "OVERLAY", "RaidifyFontBodySmall")
    queueBody:SetPoint("TOPLEFT", queueHeader, "BOTTOMLEFT", 0, -S.xs)
    queueBody:SetPoint("RIGHT", content, "RIGHT", 0, 0)
    queueBody:SetJustifyH("LEFT")
    queueBody:SetSpacing(3)

    -- Who is still carrying somebody else's loot. Above the awards list on purpose: it
    -- is the only thing on this page that is a job rather than a record.
    local owedHeader = content:CreateFontString(nil, "OVERLAY", "RaidifyFontHeading")
    owedHeader:SetPoint("TOPLEFT", queueBody, "BOTTOMLEFT", 0, -S.lg)

    local owedBody = content:CreateFontString(nil, "OVERLAY", "RaidifyFontBodySmall")
    owedBody:SetPoint("TOPLEFT", owedHeader, "BOTTOMLEFT", 0, -S.xs)
    owedBody:SetPoint("RIGHT", content, "RIGHT", 0, 0)
    owedBody:SetJustifyH("LEFT")
    owedBody:SetSpacing(3)

    local awardsHeader = content:CreateFontString(nil, "OVERLAY", "RaidifyFontHeading")
    awardsHeader:SetPoint("TOPLEFT", owedBody, "BOTTOMLEFT", 0, -S.lg)

    local awardsBody = content:CreateFontString(nil, "OVERLAY", "RaidifyFontBodySmall")
    awardsBody:SetPoint("TOPLEFT", awardsHeader, "BOTTOMLEFT", 0, -S.xs)
    awardsBody:SetPoint("RIGHT", content, "RIGHT", 0, 0)
    awardsBody:SetJustifyH("LEFT")
    awardsBody:SetSpacing(3)

    --[[
        Size the scroll child to whatever the text actually came out as.

        Measured from the font strings rather than counted from the data: the bodies wrap, so
        "twelve awards" is not a height. Anchor geometry (GetTop/GetBottom) is exact but only
        once the frame has been laid out, so it is used when available and the summed string
        heights stand in when the page is hidden or on the very first draw.
    ]]
    local function ResizeContent()
        local height
        local top, bottom = content:GetTop(), awardsBody:GetBottom()
        if top and bottom and top > bottom then
            height = top - bottom
        else
            height = 0
            for _, fs in ipairs({ queueHeader, queueBody, owedHeader, owedBody,
                                  awardsHeader, awardsBody }) do
                height = height + math.max(fs:GetStringHeight() or 0, 1)
            end
            height = height + (S.xs * 3) + (S.lg * 2)
        end

        height = height + padding
        content:SetHeight(height)

        local viewport = scroll:GetHeight() or 0
        local max = math.max(0, height - viewport)
        scroll.maxScroll = max

        if scroll:GetVerticalScroll() > max then scroll:SetVerticalScroll(max) end

        if max > 0 then
            scrollNote:SetText(Raidify:MutedText("scroll for more"))
            scrollNote:Show()
        else
            scrollNote:Hide()
        end
    end

    --[[
        Redraw from the session, every time the page is shown.

        No caching and no incremental updates: this page is opened a handful of times a
        night, and a stale awards list here is exactly the kind of thing an officer would
        read out to a raider and be wrong about.
    ]]
    function page.Refresh()
        -- Read on every refresh rather than only at creation: the setting can also be
        -- changed by another character on the same account between visits.
        autoTrade:SetChecked(Raidify.Loot:GetSetting("autoFillTrades") == true)
        hideStanding:SetChecked(Raidify.Loot:GetSetting("hideStandingOnCard") == true)
        announce:SetChecked(Raidify.Loot:GetSetting("announceLootAwards") == true)
        announceImport:SetChecked(Raidify.Loot:GetSetting("announceLootImport") ~= false)

        local session = Raidify.lootSession
        local active = session ~= nil and session.active == true
        local queue = session and session.queue or {}
        local awards = session and session.awards or {}

        -- ── status line ──────────────────────────────────────────────────────
        if active then
            statusText:SetText(string.format("%s  %s",
                Raidify:GetColorCode(T.success) .. "Tracking loot|r",
                Raidify:MutedText(ElapsedPhrase(session.startedAt))))
        elseif session and #awards > 0 and not session.exportedAt then
            -- The state nothing else would ever mention. A finished night sitting in
            -- saved variables, which stays there until somebody sends it.
            statusText:SetText(Raidify:WarningText("Finished, but not sent to the website yet."))
        elseif session and #awards > 0 then
            statusText:SetText(Raidify:MutedText("Last session sent. Start a new one when you pull."))
        elseif Raidify.lootMirror then
            -- Somebody else is running it. Worth saying loudly, because the officer
            -- reading this page is one command away from starting a second session and
            -- splitting the night's record in two.
            local mirror = Raidify.lootMirror
            statusText:SetText(string.format("%s  %s",
                Raidify:GetColorCode(T.info) .. mirror.from .. " is tracking loot|r",
                Raidify:MutedText(string.format("%d awarded, %d queued - you are seeing a copy",
                    #mirror.awards, #mirror.queue))))
        else
            statusText:SetText(Raidify:MutedText("Not tracking. Nothing that drops will be recorded."))
        end

        -- ── the session button ───────────────────────────────────────────────
        if active then
            sessionBtn:SetText("Stop tracking loot")
            sessionBtn:SetScript("OnClick", function()
                Raidify:ShowConfirmDialog({
                    title = "Stop tracking loot?",
                    message = string.format(
                        "%s awarded so far.\n\nYou can still copy the night to the "
                            .. "website afterwards.", Raidify:Plural(#awards, "item")),
                    confirmText = "Stop",
                    cancelText = "Keep going",
                    onConfirm = function()
                        Raidify:EndLootSession()
                        page.Refresh()
                    end,
                })
            end)
        else
            sessionBtn:SetText("Start tracking loot")
            sessionBtn:SetScript("OnClick", function()
                Raidify:StartLootSession(false)
                page.Refresh()
            end)
        end

        -- Taking over is only offered when there is something to take over and nothing of
        -- our own to lose.
        if Raidify.lootMirror and not active then
            adoptBtn:Show()
        else
            adoptBtn:Hide()
        end

        -- Only useful when there is something in the queue, and the count means an officer
        -- can see how much work is left without reading the list below.
        --[[
            Its own reason, on its own control.

            This sat disabled directly above sendHint, which explains why EXPORT is
            unavailable - so an officer read the export's reason as the reason both were
            dead. A hint per control, or none of them mean anything.
        ]]
        if #queue > 0 then
            nextBtn:Enable()
            nextBtn:SetText(string.format("Next item (%d)", #queue))
            Raidify:AddTooltip(nextBtn, "Next item",
                "Open the card for the next drop waiting on a decision.")
        else
            nextBtn:Disable()
            nextBtn:SetText("Next item")
            Raidify:AddTooltip(nextBtn, "Next item",
                active and "Nothing is waiting on a decision - items appear here as they drop."
                    or "Start tracking loot first; nothing is being queued.")
        end

        --[[
            Three reasons it may be unavailable, and the hint names whichever applies.
            A disabled control with no explanation is read as a bug.
        ]]
        if active then
            sendBtn:Disable()
            sendHint:SetText(Raidify:MutedText(
                "Stop tracking first - exporting now would send the night as finished."))
        elseif #awards == 0 then
            sendBtn:Disable()
            sendHint:SetText(Raidify:MutedText("Nothing awarded yet, so there is nothing to send."))
        else
            sendBtn:Enable()
            sendBtn:SetScript("OnClick", function()
                Raidify:ExportLootSession()
                page.Refresh()
            end)
            if session.exportedAt then
                sendHint:SetText(Raidify:MutedText(
                    "Already shown once. Press again if you need the string back."))
            else
                sendHint:SetText(Raidify:MutedText(
                    "Opens a window with the string. Copy it into Loot -> Raid day on the site."))
            end
        end

        -- ── waiting ──────────────────────────────────────────────────────────
        queueHeader:SetText(string.format("Not decided yet (%d)", #queue))
        if #queue == 0 then
            queueBody:SetText(Raidify:MutedText(
                active and "Nothing waiting." or "Nothing waiting - no session is running."))
        else
            local lines = {}
            for _, entry in ipairs(queue) do
                table.insert(lines, "  " .. ItemLabel(entry))
            end
            queueBody:SetText(table.concat(lines, "\n"))
        end

        -- ── still to hand out ────────────────────────────────────────────────
        local owedBy, owedOrder = {}, {}
        if Raidify.GetOwedSummary then owedBy, owedOrder = Raidify:GetOwedSummary() end

        local owedCount = 0
        for _, name in ipairs(owedOrder) do owedCount = owedCount + #owedBy[name] end

        owedHeader:SetText(string.format("Owed - still in your bags (%d)", owedCount))
        if owedCount == 0 then
            owedBody:SetText(Raidify:MutedText(
                #awards > 0 and "Everything awarded has been traded." or "Nothing owed."))
        else
            local lines = {}
            for _, name in ipairs(owedOrder) do
                local items = {}
                for _, award in ipairs(owedBy[name]) do
                    local label = ItemLabel(award)

                    --[[
                        The clock, where an officer will actually see it.

                        A bind-on-pickup item can only be handed over for two hours after
                        it drops. Colour rather than a number alone, because the whole
                        point is that a glance should tell you which row is a problem:
                        caution under fifteen minutes, negative once it is gone.
                    ]]
                    local left = Raidify.GetTradeTimeRemaining
                        and Raidify:GetTradeTimeRemaining(award.itemId, award.itemGuid)

                    if left == nil then
                        label = label .. Raidify:MutedText(" (not in your bags)")
                    elseif left ~= math.huge then
                        local text = Raidify:FormatTradeTime(left)
                        local colour = (left <= 0 and T.error)
                            or (left <= 15 * 60 and T.warning)
                            or T.textMuted
                        label = label .. " " .. Raidify:GetColorCode(colour) .. "(" .. text .. ")|r"
                    end

                    table.insert(items, label)
                end
                table.insert(lines, string.format("  %s  %s",
                    Raidify:GetColorCode(T.textPrimary) .. name .. "|r",
                    table.concat(items, ", ")))
            end
            owedBody:SetText(table.concat(lines, "\n"))
        end

        -- ── tonight ──────────────────────────────────────────────────────────
        --
        -- Read-only, on purpose. There is no in-game undo and there should not be: a
        -- correction after the night has been sent cannot retract the chat announcement,
        -- cannot reopen the raider's wishlist entry, and cannot touch the server record -
        -- so it would not be a correction, it would be a second, disconnected story about
        -- the same item. The website edits the award and names who did it in the audit log.
        awardsHeader:SetText(string.format("Given out tonight (%d)", #awards))
        if #awards == 0 then
            awardsBody:SetText(Raidify:MutedText("Nothing yet."))
        else
            local lines = {}
            for i = #awards, 1, -1 do
                local award = awards[i]
                local who = award.winnerName
                    or (award.disposition and (DISPOSITION_TEXT[award.disposition] or award.disposition))
                    or "-"
                local note = ""
                if award.offspec then note = Raidify:MutedText("  offspec") end
                -- Same rule as GetOwedItems, so this note and the "still to hand out" list
                -- can never disagree about the same award. Test rows count when the whole
                -- session is a test, and never otherwise.
                local countsAsOwed = session and (session.isTest == true or not award.isTest)
                if award.winner and not award.tradedAt and countsAsOwed then
                    note = note .. Raidify:WarningText("  not handed over")
                end
                if award.absent then note = note .. Raidify:WarningText("  not in raid") end
                table.insert(lines, string.format("  %s  %s%s",
                    ItemLabel(award), Raidify:GetColorCode(T.textPrimary) .. who .. "|r", note))
            end
            awardsBody:SetText(table.concat(lines, "\n"))
        end

        -- Last, because it measures what everything above just produced.
        ResizeContent()
    end

    --[[
        The countdown, and only the countdown.

        Everything that CHANGES the session — a drop queueing, an award, a disposition, a
        trade completing, a takeover — now redraws this page the moment it happens, through
        NotifyLootChanged. This ticker used to carry that job as well, which meant an officer
        could award an item and watch the page disagree with them for ten seconds.

        What events cannot cover is time passing. Leave the tab open for twenty minutes and
        the trade timers are twenty minutes wrong with nothing having happened to announce
        it, which is worse than showing nothing at all — an officer reads "43m left" off a
        stale screen and believes it.

        Safe to run on a ticker because Refresh only sets text on font strings that already
        exist. It creates no frames, unlike RefreshDashboard, which is why that one has to
        mark itself dirty and skip instead.

        Stopped on hide so a closed window is not scanning bags every ten seconds for the
        rest of the night.
    ]]
    local ticker

    page:SetScript("OnShow", function()
        if ticker then ticker:Cancel() end
        if C_Timer and C_Timer.NewTicker then
            ticker = C_Timer.NewTicker(10, function()
                if page:IsShown() then page.Refresh() end
            end)
        end
    end)

    page:SetScript("OnHide", function()
        if ticker then
            ticker:Cancel()
            ticker = nil
        end
    end)

    return page
end

--[[
    Register with core.

    Both calls are guarded: core may predate this API, and a sub-addon must never be the
    reason the main window fails to open. A guild on an older core simply gets no Loot tab
    and keeps every command it had.
]]
if Raidify.RegisterPage then
    Raidify:RegisterPage(PAGE_KEY, CreateLootPage, "Loot")
end

if Raidify.RegisterNavItem then
    Raidify:RegisterNavItem({
        key = PAGE_KEY,
        label = "Loot",
        icon = "Interface\\MINIMAP\\Tracking\\Banker",
    })
end

--[[
    Sample data for the loot screens.

    Three actions, because the loot surfaces have three distinct empty states and one
    button could only ever fill one of them: a session with nothing in it, a session with a
    history behind it, and a card waiting on a drop.

    Registered rather than drawn — the status bar has room and the page does not: the queue
    and awards lists both grow downward, so anything anchored to the bottom of this page is
    one long raid away from being sat on.
]]
if Raidify.RegisterPageTestAction then
    Raidify:RegisterPageTestAction(PAGE_KEY, {
        {
            label = "Load sample loot",
            tooltip = "Starts a session, awards a few items to mock raiders (one of them "
                .. "twice, one as offspec) and queues some drops.",
            onClick = function()
                Raidify:SeedTestLootSession()
                Raidify:RefreshCurrentPage()
            end,
        },
        {
            label = "Simulate a drop",
            tooltip = "Queues another item as though a boss had just died, so the candidate "
                .. "card opens on its own.",
            onClick = function()
                Raidify:SimulateLootDrop(nil)
                Raidify:RefreshCurrentPage()
            end,
        },
        {
            label = "Clear samples",
            tooltip = "Removes everything the sample buttons created. Anything imported for "
                .. "real is left alone.",
            onClick = function()
                if Raidify.ClearTestData then Raidify:ClearTestData() end
                Raidify:RefreshCurrentPage()
            end,
        },
    })
end
