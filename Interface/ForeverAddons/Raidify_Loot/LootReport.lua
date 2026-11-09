--[[
    LootReport.lua - the diagnostic a volunteer can actually send back.

    WHY THIS EXISTS. This addon is about to run in other people's raids, on clients nobody
    here can inspect, in front of guilds who will lose real loot if it goes wrong. The
    person who sees a failure will be tanking at the time. They will not read a stack
    trace, they cannot reproduce anything on request, and by the time anyone asks, the chat
    line is a thousand messages up.

    So the report has to be one command, produce something copyable, and carry the context
    the reporter should not have to know to include: client build, addon versions, whether
    the two halves match, the session's shape, and every error retained since the last time
    it was cleared.

    It deliberately reports NO player names and no wishlist contents. A diagnostic that
    contains a guild's loot decisions is one somebody will hesitate to paste into a
    Discord, and a diagnostic nobody pastes is worth nothing.
]]

local Raidify = _G.Raidify
if not Raidify or not Raidify.Loot then return end

local Loot = Raidify.Loot

--[[
    Environment. Every line here answers a question that would otherwise cost a round trip.
]]
local function BuildEnvironment()
    local lines = {}

    local version, build, _, tocVersion = GetBuildInfo()
    table.insert(lines, string.format("client      %s (build %s, toc %s)",
        tostring(version), tostring(build), tostring(tocVersion)))
    table.insert(lines, string.format("locale      %s", GetLocale()))
    table.insert(lines, string.format("loot addon  %s", tostring(Loot.version)))
    table.insert(lines, string.format("core addon  %s", tostring(Raidify.version)))

    -- The mismatch that produces the strangest bug reports: two halves of the same addon
    -- at different versions, which happens whenever someone updates one and not the other.
    table.insert(lines, string.format("core API    v%s (loot needs v%s)",
        tostring(Raidify.APIVersion), tostring(Loot.requiredApi or Raidify.APIVersion)))

    --[[
        API availability. These are the calls the trade path depends on, and a client
        missing any of them fails in a way that looks like "the addon does nothing" rather
        than an error. Cheaper to state than to diagnose.
    ]]
    local apis = {
        { "C_Container", C_Container ~= nil },
        { "UseContainerItem", (C_Container and C_Container.UseContainerItem or _G.UseContainerItem) ~= nil },
        { "GetContainerItemID", (C_Container and C_Container.GetContainerItemID or _G.GetContainerItemID) ~= nil },
        { "BIND_TRADE_TIME_REMAINING", BIND_TRADE_TIME_REMAINING ~= nil },
        { "ITEM_SOULBOUND", ITEM_SOULBOUND ~= nil },
        { "C_Timer.NewTicker", (C_Timer and C_Timer.NewTicker) ~= nil },
    }
    local missing = {}
    for _, api in ipairs(apis) do
        if not api[2] then table.insert(missing, api[1]) end
    end
    table.insert(lines, string.format("apis        %s",
        #missing == 0 and "all present" or ("MISSING: " .. table.concat(missing, ", "))))

    -- Whether the addon is rendering its own type or Blizzard's. A screenshot attached to a
    -- bug report looks like a design complaint when it is actually a failed font load, and
    -- the two need completely different answers.
    table.insert(lines, string.format("fonts       %s",
        Raidify.hasCustomFonts and "custom" or "FALLBACK (Blizzard) - needs a full client restart"))

    -- Which copy of an item an award is tied to depends on this, and it is absent on
    -- some Classic flavours. "The wrong item was traded" has a very different diagnosis
    -- depending on which mode the client was in.
    table.insert(lines, string.format("item guids  %s",
        (Raidify.UsesGuidTracking and Raidify:UsesGuidTracking())
            and "tracked" or "unavailable (falling back to trade clock)"))

    return lines
end

--[[ The session's shape, with no names and no items — counts only. ]]
local function BuildSessionSummary()
    local lines = {}
    local session = Raidify.lootSession

    if not session then
        table.insert(lines, "session     none")
    else
        table.insert(lines, string.format("session     active=%s started=%s ended=%s exported=%s test=%s",
            tostring(session.active),
            session.startedAt and date("!%H:%M", session.startedAt) or "-",
            session.endedAt and date("!%H:%M", session.endedAt) or "-",
            session.exportedAt and "yes" or "no",
            session.isTest and "YES" or "no"))
        -- present is keyed by name, not an array, so # on it is always 0 - which made the
        -- one number meant to sanity-check attendance sampling read zero in every report
        -- anyone ever sent.
        local presentCount = 0
        for _ in pairs(session.present or {}) do presentCount = presentCount + 1 end

        table.insert(lines, string.format("            queued=%d awarded=%d present=%d",
            #(session.queue or {}), #(session.awards or {}), presentCount))
    end

    local data = Raidify.lootData
    table.insert(lines, string.format("loot data   %s",
        not data and "none imported"
            or string.format("%d chars, wishlists=%s, prios=%s, test=%s",
                data.chars and #data.chars or 0,
                data.wishlists and "yes" or "no",
                data.prios and "yes" or "no",
                data.isTestData and "YES" or "no")))

    table.insert(lines, string.format("settings    threshold=%s announce=%s autoTrade=%s",
        tostring(Loot:GetSetting("lootQualityThreshold")),
        tostring(Loot:GetSetting("announceLootAwards")),
        tostring(Loot:GetSetting("autoFillTrades"))))

    return lines
end

--[[ Build the whole report as one copyable block. ]]
function Raidify:BuildLootReport()
    local out = { "=== Raidify Loot report ===" }

    for _, line in ipairs(BuildEnvironment()) do table.insert(out, line) end
    table.insert(out, "")
    for _, line in ipairs(BuildSessionSummary()) do table.insert(out, line) end

    local errors = Loot:Db().errors or {}
    table.insert(out, "")
    table.insert(out, string.format("=== errors (%d) ===", #errors))

    if #errors == 0 then
        table.insert(out, "none recorded")
    else
        for index, entry in ipairs(errors) do
            table.insert(out, string.format("%d. [%s] %s",
                index, date("!%Y-%m-%d %H:%M", entry.at), entry.label))
            table.insert(out, "   " .. entry.message)
            table.insert(out, "   " .. (entry.state or ""))
            if entry.stack then
                -- One line per frame, indented, so the block stays readable when pasted
                -- into a Discord message.
                for frame in entry.stack:gmatch("[^\n]+") do
                    table.insert(out, "     " .. frame)
                end
            end
        end
    end

    return table.concat(out, "\n")
end

--[[
    Show it in a window that can be selected and copied.

    Same shape as the export window, so an officer who has copied an export string already
    knows how this works.
]]
function Raidify:ShowLootReport()
    local AceGUI = LibStub("AceGUI-3.0")

    if self.lootReportFrame then
        self.lootReportFrame:Release()
        self.lootReportFrame = nil
    end

    local report = self:BuildLootReport()
    local errorCount = #(Loot:Db().errors or {})

    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Raidify Loot - report")
    frame:SetStatusText(errorCount == 0
        and "No errors recorded. Send this if something looked wrong anyway."
        or string.format("%s recorded - please send this to us.", Raidify:Plural(errorCount, "error")))
    frame:SetLayout("Flow")
    frame:SetWidth(640)
    frame:SetHeight(420)
    frame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
        Raidify.lootReportFrame = nil
    end)

    local box = AceGUI:Create("MultiLineEditBox")
    box:SetLabel("Copy all of this and send it to us:")
    box:SetFullWidth(true)
    box:SetFullHeight(true)
    box:SetText(report)
    box:DisableButton(true)
    frame:AddChild(box)

    local editBox = box.editBox
    if editBox then
        editBox:HighlightText()
        editBox:SetFocus()
    end

    self.lootReportFrame = frame
end

--[[
    Clear the log.

    Separate command rather than clearing on read: a volunteer may well paste the report,
    be asked a question, and need to paste it again. Losing it on first read would be a
    small betrayal at the worst moment.
]]
function Raidify:ClearLootReport()
    local db = Loot:Db()
    local count = #(db.errors or {})
    db.errors = {}
    Loot._reported = {}
    self:Print(string.format("Cleared %s.", Raidify:Plural(count, "recorded error")))
end
