-- A checkbox on every zone header of the quest log that tracks or untracks
-- every quest under it at once.
--
-- Asked for on CurseForge on 2026-09-30 and gated with the owner the same day.
-- **The client already has it, behind a right click**: the header opens a menu
-- with Track All and Untrack All. The owner tried that in game and found two
-- clicks through a menu too many, so the box is the same thing in one click,
-- and the menu stays exactly as it is.
--
-- His answers, which are the design:
--
--   - **the look is the quest rows' own checkbox**, the same square and the
--     same yellow checkmark, checked while every quest of the zone is tracked;
--   - a zone where only some are tracked is unchecked, and **a click tracks the
--     rest**; only a checked box untracks them all;
--   - it **works on a collapsed header** as well, his condition;
--   - on by default.
--
-- ---------------------------------------------------------------------------
-- How it sits in the client's quest log
-- ---------------------------------------------------------------------------
--
-- Read in the client's interface code, Blizzard_UIPanels_Game, builds 70009
-- to 70124. The quest log is the one inside the world map on this client, and
-- `QuestLogQuests_Update` is the one global that redraws it: it hands every
-- header back to `QuestScrollFrame.headerFramePool` and takes them out again
-- in the new order. So a hook after it finds this moment's headers among the
-- pool's active frames, and a header is a zone only until the next redraw.
-- The box therefore reads `questLogIndex` off its header at the click, and
-- remembers nothing about which zone it once belonged to.
--
-- **A collapsed header still has its quests.** C_QuestLog lists every quest
-- under a collapsed header and the client merely does not draw them; a header
-- is only drawn at all when a quest follows it in that list, which is why the
-- collapsed ones are visible. So walking from the header's index to the next
-- header finds the same quests either way.
--
-- **The watch calls are made here, not through the client's function.**
-- `QuestMapFrame:SetHeaderQuestsTracked` is what the menu runs, and it writes
-- a flag onto QuestMapFrame and redraws the map from inside itself. Called
-- from an addon, both of those would happen tainted. `AddQuestWatch` and
-- `RemoveQuestWatch` are plain calls, and the client redraws the log and the
-- objective tracker by itself on QUEST_WATCH_LIST_CHANGED.
--
-- Nothing is written into Blizzard's frames beyond one anchor, see
-- *The zone name* below: the boxes are kept in a table of our own, keyed by
-- header, rather than as fields on the headers.

local ADDON, FP = ...
local L = FP.L

local M = FP:RegisterModule("QuestZoneTracking", {
    title   = L["Track Zones in the Quest Log"],
    default = true,
    desc    = L["Adds a checkbox to every zone in the quest log to track or "
           .. "untrack all its quests with one click."],
    group   = "display",
    order   = 45,
})

local boxes = {}    -- [header] = our checkbox on it

-- ---------------------------------------------------------------------------
-- The quests under a header
-- ---------------------------------------------------------------------------

local function Truth(value) return FP:Truth(value) == true end

local function IsTracked(id)
    local log = C_QuestLog
    if not (log and log.GetQuestWatchType) then return false end
    local ok, kind = pcall(log.GetQuestWatchType, id)
    -- The quest rows' own test: any watch type at all is a checked box.
    return ok and kind ~= nil
end

--- Whether the client lets this character untrack, which is its own rule for
--- its own menu: not during the new player experience.
local function CanUntrack()
    local util = _G.QuestUtil
    if type(util) ~= "table" or type(util.CanRemoveQuestWatch) ~= "function" then
        return true
    end
    local ok, can = pcall(util.CanRemoveQuestWatch)
    return not ok or can ~= false
end

--- A quest the log would draw under an open header: the client's own
--- conditions, without the search box and without the header's collapsed
--- state. A hidden quest or a bonus objective cannot be ticked in the log, so
--- counting one would leave the box unchecked for good.
local function Listed(info)
    if Truth(info.isHidden) or Truth(info.isTask) then return false end
    local log, id = C_QuestLog, info.questID
    if Truth(info.isBounty) then
        local ok, done = pcall(log.IsComplete, id)
        if not (ok and Truth(done)) then return false end
    end
    if log.IsQuestDisabledForSession then
        local ok, off = pcall(log.IsQuestDisabledForSession, id)
        if ok and Truth(off) then return false end
    end
    return true
end

--- The quest ids under the header at `index`, down to the next header.
-- Nil when `index` is not a header any more, which a quest taken or dropped
-- between the last redraw and a click could cause.
local function QuestsUnder(index)
    local log = C_QuestLog
    if not (log and log.GetInfo and log.GetNumQuestLogEntries) then return nil end
    if type(index) ~= "number" then return nil end

    local head = log.GetInfo(index)
    if type(head) ~= "table" or not Truth(head.isHeader) then return nil end

    local ids = {}
    local count = log.GetNumQuestLogEntries()
    for i = index + 1, FP:PlainNumber(count) or 0 do
        local info = log.GetInfo(i)
        if type(info) == "table" then
            if Truth(info.isHeader) then break end
            local id = FP:PlainNumber(info.questID)
            if id and Listed(info) then ids[#ids + 1] = id end
        end
    end
    return ids
end

--- How many of `ids` are tracked.
local function CountTracked(ids)
    local n = 0
    for _, id in ipairs(ids) do
        if IsTracked(id) then n = n + 1 end
    end
    return n
end

-- ---------------------------------------------------------------------------
-- The click
-- ---------------------------------------------------------------------------

local function Play(name)
    local id = FP:SoundKitId(name)
    if id and PlaySound then PlaySound(id) end
end

-- ---------------------------------------------------------------------------
-- A full tracker
--
-- The owner's report of 2026-10-13: at the limit a click on the box did
-- nothing and said nothing, so nobody could tell why. The client tracks 25
-- quests at most, Constants.QuestWatchConsts.MAX_QUEST_WATCHES, and its own
-- track option says so in red when one more will not fit,
-- QuestMapQuestOptions_TrackQuest in its interface code for build 70338. The
-- box does the same with the same words: it tracks what still fits and then
-- shows that message.
--
-- **Past the error filter**, FP:ShowError: the first version showed nothing
-- for the owner, whose "Hide every error" took it like any red error, while
-- the ammunition warning, on a frame of its own, showed. **And by the client's
-- own answer as well as by the count**: AddQuestWatch says whether it watches
-- the quest, so a cap below 25 on WoW Forever's server stops the box too.
-- ---------------------------------------------------------------------------

local function MaxWatches()
    local consts = rawget(_G, "Constants")
    local watch = type(consts) == "table" and consts.QuestWatchConsts
    return (type(watch) == "table" and FP:PlainNumber(watch.MAX_QUEST_WATCHES)) or 25
end

--- How many more quests the tracker takes, or nil while the client will not say.
local function Room()
    local log = C_QuestLog
    if not (log and log.GetNumQuestWatches) then return nil end
    local ok, watched = pcall(log.GetNumQuestWatches)
    watched = ok and FP:PlainNumber(watched)
    if not watched then return nil end
    return MaxWatches() - watched
end

local function TrackerFull()
    local text = FP:Plain(rawget(_G, "OBJECTIVES_WATCH_TOO_MANY"))
    if not text then return end
    if FP.ShowError then return FP:ShowError(text) end
    local frame = rawget(_G, "UIErrorsFrame")
    if frame and frame.AddMessage then
        pcall(frame.AddMessage, frame, text, 1.0, 0.1, 0.1, 1.0)
    end
end

--- Whether the client answered no, read without trusting the answer to be
--- plain: a refusal is false, and nothing at all is not one.
local function Refused(ok, answer)
    if not ok then return false end
    local readable, no = pcall(function() return answer == false end)
    return readable and no
end

--- Tracks every quest under the header, or untracks them all when every one
--- already is. The owner's rule for a zone tracked in part: the rest joins.
local function Toggle(header)
    local ids = QuestsUnder(header.questLogIndex)
    if not ids or #ids == 0 then return end

    local track = CountTracked(ids) < #ids
    if not track and not CanUntrack() then return end

    -- Counted down here rather than asked again after every call, so nothing
    -- depends on how soon the client's own count follows.
    local room = track and Room() or nil
    if room and room <= 0 then return TrackerFull() end

    -- The quest rows' own sounds, on for tracking and off for untracking.
    Play(track and "IG_MAINMENU_OPTION_CHECKBOX_ON" or "IG_MAINMENU_OPTION_CHECKBOX_OFF")
    local log = C_QuestLog
    for _, id in ipairs(ids) do
        if track and not IsTracked(id) then
            if room and room <= 0 then return TrackerFull() end
            if Refused(pcall(log.AddQuestWatch, id)) then return TrackerFull() end
            if room then room = room - 1 end
        elseif not track and IsTracked(id) then
            pcall(log.RemoveQuestWatch, id)
        end
    end
end

-- ---------------------------------------------------------------------------
-- The box
-- ---------------------------------------------------------------------------

--- The hover text: the zone as the title, and what a click will do with how
--- many are tracked now. The words are the client's own menu entries, so they
--- read as the menu does in any language.
local function ShowTip(box)
    local header = box:GetParent()
    local ids = QuestsUnder(header.questLogIndex)
    if not ids or #ids == 0 then return end

    local tracked = CountTracked(ids)
    local action
    if tracked < #ids then
        action = _G.QUEST_LOG_TRACK_ALL or L["Track All"]
    elseif CanUntrack() then
        action = _G.QUEST_LOG_UNTRACK_ALL or L["Untrack All"]
    else
        return
    end
    FP:ShowTip(box, {
        FP:Plain(header:GetText()) or "",
        { action, right = tracked .. "/" .. #ids },
    })
end

--- Draws the box onto a header, once per header frame.
--
-- Built by hand from the atlases of the quest rows' checkbox,
-- QuestLogTrackCheckboxTemplate in QuestMapFrame.xml: the square, the yellow
-- checkmark one unit up and right of centre, and the square again as the
-- highlight, added at 0.4. Not from the template, like every frame here.
local function Build(header)
    local box = CreateFrame("Button", nil, header)
    box:SetSize(14, 14)
    -- Beside the collapse button, 20 wide and 6 in from the right edge. The
    -- hit area is the header's height and stops where the collapse button's
    -- begins, so neither can take the other's click.
    local collapse = header.CollapseButton
    if collapse then
        box:SetPoint("RIGHT", collapse, "LEFT", -2, 0)
    else
        box:SetPoint("RIGHT", header, "RIGHT", -28, 0)
    end
    box:SetHitRectInsets(-6, -2, -4, -4)
    box:RegisterForClicks("LeftButtonUp")
    -- The header keeps its hover while the pointer is on the box, the way the
    -- quest rows keep theirs over their checkbox.
    --
    -- **Refused in combat**, like SetPropagateKeyboardInput: the owner got a
    -- blocked action on 2026-09-30 after looting a quest item in a fight,
    -- when the log drew a header it had no box on yet. A box built in a
    -- fight works at once and gets this when the fight is over; until then
    -- the header only loses its hover while the pointer is on the box.
    if box.SetPropagateMouseMotion then
        FP:OutOfCombat("QuestZoneTracking:hover", function()
            box:SetPropagateMouseMotion(true)
        end)
    end

    local square = box:CreateTexture(nil, "BACKGROUND")
    square:SetAtlas("questlog-icon-ticksquare", true)
    square:SetPoint("CENTER")

    local check = box:CreateTexture(nil, "ARTWORK")
    check:SetAtlas("questlog-icon-checkmark-yellow", true)
    check:SetPoint("CENTER", 1, 1)
    box.check = check

    local glow = box:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAtlas("questlog-icon-ticksquare", true)
    glow:SetPoint("CENTER")
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0.4)

    box:SetScript("OnClick", function(self)
        FP:Safe("QuestZoneTracking:Toggle", Toggle, self:GetParent())
        -- The redraw that follows repaints the box; the hover text is ours to
        -- bring up to date.
        if self:IsMouseOver() then FP:Safe("QuestZoneTracking:Tip", ShowTip, self) end
    end)
    box:SetScript("OnEnter", function(self)
        FP:Safe("QuestZoneTracking:Tip", ShowTip, self)
    end)
    box:SetScript("OnLeave", function(self) FP:HideTip(self) end)

    boxes[header] = box
    return box
end

-- ---------------------------------------------------------------------------
-- The zone name
--
-- The header's name runs up to the collapse button, and the box now sits in
-- the last stretch of that. So the name ends at the box instead, which is the
-- same anchor with the box as its neighbour, and it goes back when the module
-- is switched off. A name too long for that is cut by the client's own rule,
-- which then names it in full on hover, the way it always has.
-- ---------------------------------------------------------------------------

local function NameEndsAt(header, frame)
    local name = header.ButtonText
    if not (name and name.SetPoint and frame) then return end
    name:SetPoint("RIGHT", frame, "LEFT", -4, 0)
end

-- ---------------------------------------------------------------------------
-- Keeping every header's box current
-- ---------------------------------------------------------------------------

local function Pool()
    local scroll = _G.QuestScrollFrame
    local pool = type(scroll) == "table" and scroll.headerFramePool
    if type(pool) == "table" and pool.EnumerateActive then return pool end
    return nil
end

--- One header: its box, checked while every quest under it is tracked, and
--- hidden when there is nothing under it to track.
local function Decorate(header)
    local box = boxes[header] or Build(header)
    local ids = QuestsUnder(header.questLogIndex)
    if not ids or #ids == 0 then
        -- Headers are reused for other zones, so the name may still end at a
        -- box this zone does not have.
        box:Hide()
        if header.CollapseButton then NameEndsAt(header, header.CollapseButton) end
        return
    end
    box.check:SetShown(CountTracked(ids) == #ids)
    box:Show()
    NameEndsAt(header, box)
end

function M:Refresh()
    if not self.enabled then return end
    local pool = Pool()
    if not pool then return end
    for header in pool:EnumerateActive() do
        FP:Safe("QuestZoneTracking:Decorate", Decorate, header)
    end
end

function M:OnEnable()
    -- Once for the life of the session: a hook cannot be taken back, so it
    -- asks whether the module is on each time instead.
    if not self.hooked and _G.QuestLogQuests_Update and hooksecurefunc then
        self.hooked = pcall(hooksecurefunc, "QuestLogQuests_Update", function()
            if M.enabled then M:Refresh() end
        end)
        if not self.hooked then
            FP:Warn(L["QuestZoneTracking: could not hook QuestLogQuests_Update, "
                .. "so the quest log gets no checkboxes."])
        end
    elseif not _G.QuestLogQuests_Update then
        FP:Warn(L["QuestZoneTracking: this client has no QuestLogQuests_Update, "
            .. "so the quest log gets no checkboxes."])
    end
    -- For a quest log that is already open when the module is switched on.
    self:Refresh()
end

function M:OnDisable()
    for header, box in pairs(boxes) do
        box:Hide()
        FP:HideTip(box)
        if header.CollapseButton then NameEndsAt(header, header.CollapseButton) end
    end
end
